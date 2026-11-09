-- BOUNDARY: lot-level pass / withdrawal support
-- Apply once after the original multiplayer foundation migration.

create table if not exists public.auction_lot_passes (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.auction_rooms(id) on delete cascade,
  lot_id uuid not null references public.auction_lots(id) on delete cascade,
  franchise_id uuid not null references public.auction_franchises(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  passed_at timestamptz not null default now(),
  unique (lot_id, franchise_id)
);

create index if not exists auction_lot_passes_room_lot_idx
  on public.auction_lot_passes(room_id, lot_id);

alter table public.auction_lot_passes enable row level security;
revoke all on public.auction_lot_passes from anon, authenticated;
grant select on public.auction_lot_passes to authenticated;

drop policy if exists "room members read lot passes" on public.auction_lot_passes;
create policy "room members read lot passes"
  on public.auction_lot_passes for select to authenticated
  using (private.is_room_member(room_id));

create or replace function private.reject_bid_after_pass()
returns trigger
language plpgsql
security definer
set search_path = ''
as 'begin
  if exists (
    select 1 from public.auction_lot_passes p
    where p.lot_id = new.lot_id and p.franchise_id = new.franchise_id
  ) then
    raise exception ''This franchise has passed on this player and cannot bid again'';
  end if;
  return new;
end;';

drop trigger if exists auction_bid_reject_passed_franchise on public.auction_bids;
create trigger auction_bid_reject_passed_franchise
  before insert on public.auction_bids
  for each row execute function private.reject_bid_after_pass();

create or replace function public.pass_auction_lot(p_lot_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as 'declare
  v_lot public.auction_lots;
  v_member public.auction_members;
begin
  if auth.uid() is null then raise exception ''Sign in required''; end if;

  select * into v_lot
  from public.auction_lots
  where id = p_lot_id
  for update;

  if not found or v_lot.status <> ''active'' then
    raise exception ''This lot is not accepting passes'';
  end if;

  select * into v_member
  from public.auction_members
  where room_id = v_lot.room_id and user_id = auth.uid();

  if not found or v_member.member_role <> ''bidder'' or v_member.franchise_id is null then
    raise exception ''You do not hold a bidder seat'';
  end if;

  if v_lot.leading_franchise_id = v_member.franchise_id then
    raise exception ''The leading franchise cannot pass while holding the highest bid'';
  end if;

  insert into public.auction_lot_passes(room_id, lot_id, franchise_id, user_id)
  values (v_lot.room_id, v_lot.id, v_member.franchise_id, auth.uid())
  on conflict (lot_id, franchise_id) do nothing;

  return jsonb_build_object('passed', true, 'lot_id', v_lot.id, 'franchise_id', v_member.franchise_id);
end;';

revoke execute on function public.pass_auction_lot(uuid) from public, anon;
grant execute on function public.pass_auction_lot(uuid) to authenticated;

-- Add pass state to realtime updates.
do 'begin
  if exists(select 1 from pg_publication where pubname = ''supabase_realtime'') then
    begin alter publication supabase_realtime add table public.auction_lot_passes;
    exception when duplicate_object then null; end;
  end if;
end';

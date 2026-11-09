-- BOUNDARY multiplayer auction foundation
-- Apply in Supabase SQL Editor. All money movement and bid validation happen in Postgres.

create extension if not exists pgcrypto;

create schema if not exists private;

create table if not exists public.auction_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null unique,
  room_name text not null,
  host_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'waiting' check (status in ('waiting','live','paused','completed')),
  starting_purse numeric(12,2) not null check (starting_purse > 0),
  bid_increment numeric(10,2) not null check (bid_increment > 0),
  squad_limit integer not null check (squad_limit between 1 and 30),
  created_at timestamptz not null default now()
);

create table if not exists public.auction_franchises (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.auction_rooms(id) on delete cascade,
  seat_no integer not null,
  franchise_name text not null,
  owner_id uuid references auth.users(id) on delete set null,
  purse_remaining numeric(12,2) not null,
  squad_count integer not null default 0,
  created_at timestamptz not null default now(),
  unique(room_id, seat_no),
  unique(room_id, franchise_name)
);

create table if not exists public.auction_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.auction_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  member_role text not null default 'bidder' check (member_role in ('host','bidder','spectator')),
  franchise_id uuid references public.auction_franchises(id) on delete set null,
  joined_at timestamptz not null default now(),
  unique(room_id, user_id)
);

create table if not exists public.auction_lots (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.auction_rooms(id) on delete cascade,
  lot_no integer not null,
  player_name text not null,
  initials text not null,
  player_role text not null,
  country text not null,
  base_price numeric(12,2) not null check (base_price > 0),
  current_price numeric(12,2) not null,
  leading_franchise_id uuid references public.auction_franchises(id),
  status text not null default 'active' check (status in ('active','sold','unsold')),
  started_at timestamptz not null default now(),
  closed_at timestamptz,
  unique(room_id, lot_no)
);

create unique index if not exists one_active_lot_per_room
on public.auction_lots(room_id) where status = 'active';

create table if not exists public.auction_bids (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.auction_rooms(id) on delete cascade,
  lot_id uuid not null references public.auction_lots(id) on delete cascade,
  franchise_id uuid not null references public.auction_franchises(id),
  bidder_id uuid not null references auth.users(id),
  amount numeric(12,2) not null check (amount > 0),
  idempotency_key uuid not null,
  created_at timestamptz not null default now(),
  unique(bidder_id, idempotency_key)
);

create index if not exists auction_members_user_room_idx on public.auction_members(user_id, room_id);
create index if not exists auction_bids_lot_created_idx on public.auction_bids(lot_id, created_at desc);

create or replace function private.is_room_member(p_room_id uuid)
returns boolean language sql stable security definer set search_path = ''
as 'select exists (select 1 from public.auction_members m where m.room_id = p_room_id and m.user_id = (select auth.uid()))';
revoke execute on function private.is_room_member(uuid) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_room_member(uuid) to authenticated;

alter table public.auction_rooms enable row level security;
alter table public.auction_franchises enable row level security;
alter table public.auction_members enable row level security;
alter table public.auction_lots enable row level security;
alter table public.auction_bids enable row level security;

revoke all on public.auction_rooms, public.auction_franchises, public.auction_members, public.auction_lots, public.auction_bids from anon, authenticated;
grant select on public.auction_rooms, public.auction_franchises, public.auction_members, public.auction_lots, public.auction_bids to authenticated;

drop policy if exists "room members read rooms" on public.auction_rooms;
create policy "room members read rooms" on public.auction_rooms for select to authenticated
using (private.is_room_member(id));

drop policy if exists "room members read franchises" on public.auction_franchises;
create policy "room members read franchises" on public.auction_franchises for select to authenticated
using (private.is_room_member(auction_franchises.room_id));

drop policy if exists "room members read members" on public.auction_members;
create policy "room members read members" on public.auction_members for select to authenticated
using (private.is_room_member(auction_members.room_id));

drop policy if exists "room members read lots" on public.auction_lots;
create policy "room members read lots" on public.auction_lots for select to authenticated
using (private.is_room_member(auction_lots.room_id));

drop policy if exists "room members read bids" on public.auction_bids;
create policy "room members read bids" on public.auction_bids for select to authenticated
using (private.is_room_member(auction_bids.room_id));

create or replace function public.create_auction_room(
  p_room_name text, p_franchise_names text[], p_starting_purse numeric,
  p_bid_increment numeric, p_squad_limit integer
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_room public.auction_rooms; v_code text; v_name text; v_i integer;
begin
  if auth.uid() is null then raise exception 'Sign in before creating a room'; end if;
  if length(trim(p_room_name)) not between 3 and 60 then raise exception 'Room name must be 3–60 characters'; end if;
  if coalesce(array_length(p_franchise_names,1),0) not between 2 and 16 then raise exception 'Choose between 2 and 16 franchises'; end if;
  if p_starting_purse <= 0 or p_bid_increment <= 0 or p_squad_limit not between 1 and 30 then raise exception 'Invalid room rules'; end if;
  loop
    v_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
    exit when not exists(select 1 from public.auction_rooms where room_code=v_code);
  end loop;
  insert into public.auction_rooms(room_code,room_name,host_id,starting_purse,bid_increment,squad_limit)
  values(v_code,trim(p_room_name),auth.uid(),p_starting_purse,p_bid_increment,p_squad_limit) returning * into v_room;
  for v_i in 1..array_length(p_franchise_names,1) loop
    v_name := trim(p_franchise_names[v_i]);
    if length(v_name) not between 2 and 40 then raise exception 'Franchise names must be 2–40 characters'; end if;
    insert into public.auction_franchises(room_id,seat_no,franchise_name,purse_remaining)
    values(v_room.id,v_i,v_name,p_starting_purse);
  end loop;
  insert into public.auction_members(room_id,user_id,display_name,member_role)
  values(v_room.id,auth.uid(),coalesce(nullif(trim((select raw_user_meta_data->>'full_name' from auth.users where id=auth.uid())),''),'Host'),'host');
  return jsonb_build_object('room_id',v_room.id,'room_code',v_code);
end; $$;

create or replace function public.join_auction_room(p_room_code text,p_franchise_id uuid,p_display_name text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_room public.auction_rooms; v_franchise public.auction_franchises;
begin
  if auth.uid() is null then raise exception 'Sign in before joining a room'; end if;
  if length(trim(p_display_name)) not between 2 and 40 then raise exception 'Display name must be 2–40 characters'; end if;
  select * into v_room from public.auction_rooms where room_code=upper(trim(p_room_code));
  if not found then raise exception 'Room code not found'; end if;
  if v_room.status='completed' then raise exception 'This room has finished'; end if;
  select * into v_franchise from public.auction_franchises where id=p_franchise_id and room_id=v_room.id for update;
  if not found then raise exception 'That franchise seat is not in this room'; end if;
  if v_franchise.owner_id is not null and v_franchise.owner_id<>auth.uid() then raise exception 'That franchise seat is already taken'; end if;
  if exists(select 1 from public.auction_members where room_id=v_room.id and user_id=auth.uid()) then raise exception 'You already joined this room'; end if;
  update public.auction_franchises set owner_id=auth.uid() where id=v_franchise.id;
  insert into public.auction_members(room_id,user_id,display_name,member_role,franchise_id)
  values(v_room.id,auth.uid(),left(trim(p_display_name),40),'bidder',v_franchise.id);
  return jsonb_build_object('room_id',v_room.id,'franchise_id',v_franchise.id);
end; $$;

create or replace function public.start_auction_lot(
  p_room_id uuid,p_player_name text,p_initials text,p_player_role text,p_country text,p_base_price numeric
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_room public.auction_rooms; v_lot_id uuid; v_lot_no integer;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.auction_rooms where id=p_room_id for update;
  if not found or v_room.host_id<>auth.uid() then raise exception 'Only the room host can call a lot'; end if;
  if v_room.status='completed' then raise exception 'Room is completed'; end if;
  if exists(select 1 from public.auction_lots where room_id=p_room_id and status='active') then raise exception 'Close the active lot first'; end if;
  if p_base_price<=0 or length(trim(p_player_name)) not between 2 and 80 then raise exception 'Invalid player details'; end if;
  select coalesce(max(lot_no),0)+1 into v_lot_no from public.auction_lots where room_id=p_room_id;
  insert into public.auction_lots(room_id,lot_no,player_name,initials,player_role,country,base_price,current_price)
  values(p_room_id,v_lot_no,trim(p_player_name),upper(left(trim(p_initials),3)),trim(p_player_role),trim(p_country),p_base_price,p_base_price)
  returning id into v_lot_id;
  update public.auction_rooms set status='live' where id=p_room_id;
  return v_lot_id;
end; $$;

create or replace function public.place_auction_bid(p_lot_id uuid,p_amount numeric,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_lot public.auction_lots; v_room public.auction_rooms; v_member public.auction_members; v_franchise public.auction_franchises; v_min numeric;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_lot from public.auction_lots where id=p_lot_id for update;
  if not found or v_lot.status<>'active' then raise exception 'This lot is not accepting bids'; end if;
  select * into v_room from public.auction_rooms where id=v_lot.room_id;
  if v_room.status<>'live' then raise exception 'Auction is not live'; end if;
  select * into v_member from public.auction_members where room_id=v_lot.room_id and user_id=auth.uid();
  if not found or v_member.member_role<>'bidder' or v_member.franchise_id is null then raise exception 'You do not hold a bidder seat'; end if;
  select * into v_franchise from public.auction_franchises where id=v_member.franchise_id for update;
  if v_lot.leading_franchise_id=v_franchise.id then raise exception 'Another franchise must raise the bid'; end if;
  if v_franchise.squad_count>=v_room.squad_limit then raise exception 'Your squad is full'; end if;
  v_min := case when exists(select 1 from public.auction_bids where lot_id=p_lot_id) then v_lot.current_price+v_room.bid_increment else v_lot.base_price end;
  if p_amount<v_min then raise exception 'Bid is below the next valid bid: %',v_min; end if;
  if p_amount>v_franchise.purse_remaining then raise exception 'Insufficient purse'; end if;
  insert into public.auction_bids(room_id,lot_id,franchise_id,bidder_id,amount,idempotency_key)
  values(v_lot.room_id,p_lot_id,v_franchise.id,auth.uid(),p_amount,p_idempotency_key);
  update public.auction_lots set current_price=p_amount,leading_franchise_id=v_franchise.id where id=p_lot_id;
  return jsonb_build_object('accepted',true,'amount',p_amount,'franchise_id',v_franchise.id);
end; $$;

create or replace function public.close_auction_lot(p_lot_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_lot public.auction_lots; v_room public.auction_rooms; v_franchise public.auction_franchises;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_lot from public.auction_lots where id=p_lot_id for update;
  if not found or v_lot.status<>'active' then raise exception 'Lot is not active'; end if;
  select * into v_room from public.auction_rooms where id=v_lot.room_id for update;
  if v_room.host_id<>auth.uid() then raise exception 'Only the host can close a lot'; end if;
  if v_lot.leading_franchise_id is null then
    update public.auction_lots set status='unsold',closed_at=now() where id=p_lot_id;
    return jsonb_build_object('status','unsold');
  end if;
  select * into v_franchise from public.auction_franchises where id=v_lot.leading_franchise_id for update;
  if v_franchise.purse_remaining<v_lot.current_price or v_franchise.squad_count>=v_room.squad_limit then raise exception 'Winning franchise no longer meets squad or purse rules'; end if;
  update public.auction_franchises set purse_remaining=purse_remaining-v_lot.current_price,squad_count=squad_count+1 where id=v_franchise.id;
  update public.auction_lots set status='sold',closed_at=now() where id=p_lot_id;
  return jsonb_build_object('status','sold','franchise',v_franchise.franchise_name,'amount',v_lot.current_price);
end; $$;

create or replace function public.get_room_lobby(p_room_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_room public.auction_rooms;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  select * into v_room from public.auction_rooms where room_code=upper(trim(p_room_code));
  if not found then raise exception 'Room code not found'; end if;
  if not exists(select 1 from public.auction_members where room_id=v_room.id and user_id=auth.uid()) then
    return jsonb_build_object('room_id',v_room.id,'room_name',v_room.room_name,'room_code',v_room.room_code,'status',v_room.status,
      'franchises',(select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'name',f.franchise_name,'seat_no',f.seat_no,'taken',f.owner_id is not null) order by f.seat_no),'[]'::jsonb) from public.auction_franchises f where f.room_id=v_room.id));
  end if;
  return jsonb_build_object('room_id',v_room.id,'room_name',v_room.room_name,'room_code',v_room.room_code,'status',v_room.status,
    'bid_increment',v_room.bid_increment,'squad_limit',v_room.squad_limit,'starting_purse',v_room.starting_purse,
    'is_host',v_room.host_id=auth.uid(),
    'franchises',(select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'name',f.franchise_name,'seat_no',f.seat_no,'taken',f.owner_id is not null,'purse',f.purse_remaining,'squad_count',f.squad_count) order by f.seat_no),'[]'::jsonb) from public.auction_franchises f where f.room_id=v_room.id),
    'members',(select coalesce(jsonb_agg(jsonb_build_object('display_name',m.display_name,'role',m.member_role,'franchise_id',m.franchise_id)),'[]'::jsonb) from public.auction_members m where m.room_id=v_room.id),
    'lots',(select coalesce(jsonb_agg(to_jsonb(l) order by l.lot_no desc),'[]'::jsonb) from public.auction_lots l where l.room_id=v_room.id),
    'bids',(select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at desc),'[]'::jsonb) from public.auction_bids b where b.room_id=v_room.id));
end; $$;

revoke execute on function public.create_auction_room(text,text[],numeric,numeric,integer) from public, anon;
revoke execute on function public.join_auction_room(text,uuid,text) from public, anon;
revoke execute on function public.start_auction_lot(uuid,text,text,text,text,numeric) from public, anon;
revoke execute on function public.place_auction_bid(uuid,numeric,uuid) from public, anon;
revoke execute on function public.close_auction_lot(uuid) from public, anon;
revoke execute on function public.get_room_lobby(text) from public, anon;
grant execute on function public.create_auction_room(text,text[],numeric,numeric,integer) to authenticated;
grant execute on function public.join_auction_room(text,uuid,text) to authenticated;
grant execute on function public.start_auction_lot(uuid,text,text,text,text,numeric) to authenticated;
grant execute on function public.place_auction_bid(uuid,numeric,uuid) to authenticated;
grant execute on function public.close_auction_lot(uuid) to authenticated;
grant execute on function public.get_room_lobby(text) to authenticated;

-- Enable Postgres Changes for room state tables when the Supabase publication exists.
do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    begin alter publication supabase_realtime add table public.auction_franchises; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.auction_members; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.auction_lots; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.auction_bids; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.auction_rooms; exception when duplicate_object then null; end;
  end if;
end $$;

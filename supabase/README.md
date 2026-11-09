# Supabase multiplayer setup

The multiplayer beta is the first connected BOUNDARY build. It uses Supabase Auth, PostgreSQL RPCs and Realtime Postgres Changes.

## 1. Create a Supabase project

Create a project at https://supabase.com/dashboard. Keep the database password private.

## 2. Apply the database migration

Open **SQL Editor → New query**, paste the complete contents of:

`supabase/migrations/202611090001_multiplayer_auction.sql`

Run it once. It creates the room, franchise, member, lot and bid tables; enables RLS; and installs the server-side RPCs used by the client.

After the foundation migration, apply the lot-pass migration from `supabase/migrations/202611090002_lot_pass_withdrawal.sql` in a **new SQL Editor query**. This adds per-franchise pass state for each active player, prevents a passed franchise from bidding again on that lot, and publishes pass events to Realtime. It is a separate migration because the foundation migration may already have been applied.

## 3. Configure authentication

In **Authentication → Providers**, enable Email (magic link / OTP).

In **Authentication → URL Configuration**, add these redirect URLs:
- Your GitHub Pages multiplayer page: `https://hathilal.github.io/cricket-auction-platform/multiplayer-auction.html`
- Local development: `http://localhost:4173/multiplayer-auction.html`

If your project requires email confirmation, complete the magic-link flow from the same browser.

## 4. Connect the browser

Open `multiplayer-auction.html`, then copy:
- Project URL from **Project Settings → API**
- The **publishable** key (starts with `sb_publishable_`) from the API keys section

Paste them into the connection panel. The browser stores these two public client values locally. Never paste a secret key, service-role key, database password or access token into the page or repository.

## 5. Create and test a room

1. Sign in using your email magic link.
2. Create a room and choose 2–16 franchise seats.
3. Share the six-character room code with other participants.
4. Each participant signs in, enters the code and claims one open franchise seat.
5. The host calls a player to the floor; franchise owners bid from their own devices.
6. The host closes the lot. The database updates the winning franchise purse and squad count.

## Security and current limitations

- Bids are submitted through a PostgreSQL function that locks the active lot, checks room membership, enforces the increment, verifies purse and squad limits, and commits the bid atomically.
- The browser never sends an authoritative purse balance or chooses the winning franchise.
- Room reads are protected by RLS. Sensitive mutations are exposed through authenticated RPCs, not direct table writes.
- Realtime currently uses Postgres Changes for a straightforward first connected beta. For larger rooms and higher fan-out, move event delivery to private Broadcast channels with explicit Realtime Authorization policies.
- Host controls currently support calling a player and closing the lot. Franchise owners can pass on an active player; passing is final for that franchise on that lot only. Pause/resume, host transfer, invitations, chat, reconnect recovery UX, rate limits and automated concurrency/RLS tests remain future work.
- This is not a production-hardened paid auction service. Do not use it for real-money transactions or high-stakes events before security review, load testing and operational monitoring.

## Troubleshooting

- **Invalid API key:** use the publishable key, not a secret key.
- **Email link opens the wrong page:** add the exact multiplayer page URL to Authentication → URL Configuration.
- **No franchise seats appear:** verify the SQL migration ran successfully and that you are signed in.
- **Room updates do not appear:** verify Realtime is enabled and the migration added the five auction tables to the `supabase_realtime` publication.
- **Permission denied:** do not weaken RLS to make the error disappear. Check that the complete migration ran and inspect the Supabase logs.

## Architecture references

- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [Realtime database subscriptions](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes)
- [Database functions and RPC security](https://supabase.com/docs/guides/database/functions)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)

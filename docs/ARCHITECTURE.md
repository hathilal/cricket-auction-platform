# Architecture

## Client surfaces
1. Responsive web application for desktop, tablet and mobile browsers.
2. Installable PWA where supported.
3. Native iOS and Android clients built with Expo + React Native, sharing domain contracts and backend services.

A desktop wrapper such as Tauri can be evaluated later if native Windows/macOS packaging is required. Responsive web and native desktop are separate deliverables.

## Proposed production stack
- Web: Next.js, React and TypeScript.
- Mobile: Expo, React Native and TypeScript.
- Shared domain package: auction rules, purse calculations, validation and API contracts.
- Backend: Supabase Auth, PostgreSQL, Realtime and Storage.
- Authorization: PostgreSQL Row Level Security (RLS); server-side validation for all auction mutations.
- Hosting: Vercel for web; EAS Build/Submit for mobile.

## Auction consistency
The browser must never decide the winning bid. A production bid must pass through a trusted server-side transaction that verifies authenticated room membership and franchise ownership, locks or serializes the active lot, checks increment/high bid/purse/rules, atomically writes the bid and purchase state, and publishes the committed result. Use idempotency keys, authoritative server timestamps and an immutable auction event log. Client countdowns are display-only and must reconcile with server state.

## Core entities
profiles, tournaments, auction_rooms, room_members, franchises, franchise_owners, players, player_roles, auction_lots, bids, purchases, squad_constraints, auction_events, invitations.

All schema changes should be versioned as SQL migrations; RLS policies and transaction tests must ship alongside tables.

## Security
- Keep service-role credentials server-side only.
- Never trust client-supplied purse, role, bid or auction status.
- Enforce critical invariants with database constraints and transactions.
- Rate-limit room joins, invitations and bidding.
- Audit administrative actions; scope privacy for profiles, chat and room discovery.

## Data rights
Player data, photographs, franchise marks and broadcast imagery require appropriate provider agreements and permissions. Initial UI branding is original and generic.

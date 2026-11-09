# Cricket Auction Platform

A premium, responsive cricket auction experience for web, Android and iOS.

> Status: responsive UI prototype plus a browser-only auction room simulator. Authentication, multiplayer bidding, server-side validation and persistence are not implemented yet.

## Product direction

- Premium sports-broadcast aesthetic: midnight navy, slate, champagne gold and restrained electric blue.
- Responsive experiences for desktop, tablet and mobile.
- Auction-first workflows: discover rooms, prepare franchises, manage squads and follow live bidding.
- Accessible interactions, clear status and budget information, and reduced-motion support.

## Technology direction

The initial UI prototype is intentionally dependency-light and uses semantic HTML, CSS and client JavaScript so it can be previewed immediately. The production architecture is planned around Next.js/React, TypeScript, Supabase (PostgreSQL, Auth, Realtime, Storage), and Expo/React Native for native mobile clients.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/ROADMAP.md](docs/ROADMAP.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

## Interactive demo\n\nOpen [create-room.html](./create-room.html) to configure a local demo auction (room name, starting purse, squad size and bid increment), or open [auction-room.html](./auction-room.html) with default settings to try a local auction simulation with sample players, bid increments, purse tracking, squad purchases, activity history and reset. Demo state exists only in the browser and is not shared or saved.\n\n## Multiplayer beta

The connected auction foundation is in [multiplayer-auction.html](./multiplayer-auction.html). It supports email magic-link sign-in, private room creation, franchise seat claiming, host lot controls and server-validated bids. It requires a Supabase project and the SQL migration in [supabase/README.md](./supabase/README.md). Until that external project is configured, this page cannot connect to a live room.

The original [auction-floor.html](./auction-floor.html) remains a browser-only visual simulator.

## Run locally

This first milestone is a static prototype:

```bash
python3 -m http.server 4173
```

Then open http://localhost:4173.

## Important

This is an independent fan-made cricket auction product concept. It is not affiliated with or endorsed by the IPL, BCCI, or any franchise. Use licensed player imagery, team marks and data before public production launch.

# Cricket Auction Platform

A premium, responsive cricket auction experience for web, Android and iOS.

> Status: foundation / UI prototype. Live bidding, authentication and persistence are planned milestones, not implemented yet.

## Product direction

- Premium sports-broadcast aesthetic: midnight navy, slate, champagne gold and restrained electric blue.
- Responsive experiences for desktop, tablet and mobile.
- Auction-first workflows: discover rooms, prepare franchises, manage squads and follow live bidding.
- Accessible interactions, clear status and budget information, and reduced-motion support.

## Technology direction

The initial UI prototype is intentionally dependency-light and uses semantic HTML, CSS and client JavaScript so it can be previewed immediately. The production architecture is planned around Next.js/React, TypeScript, Supabase (PostgreSQL, Auth, Realtime, Storage), and Expo/React Native for native mobile clients.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/ROADMAP.md](docs/ROADMAP.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

## Run locally

This first milestone is a static prototype:

```bash
python3 -m http.server 4173
```

Then open http://localhost:4173.

## Important

This is an independent fan-made cricket auction product concept. It is not affiliated with or endorsed by the IPL, BCCI, or any franchise. Use licensed player imagery, team marks and data before public production launch.

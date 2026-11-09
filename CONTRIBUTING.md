# Contributing

- Build original identity; do not imitate protected league branding or imply official affiliation.
- Design mobile-first, then enhance for larger screens.
- Prefer semantic HTML, keyboard support, visible focus and accessible contrast.
- Keep domain rules outside UI components.
- Treat server/database as authoritative for auction state and purse accounting.
- Add tests for auction invariants and concurrency-sensitive mutations.
- Never commit secrets, service-role tokens or private user data.

Workflow: create a focused branch, make a coherent change, run lint/typecheck/tests, verify mobile/tablet/desktop, then open a PR with behavior, test evidence and UI screenshots.

Check every dependency's license before adoption. Public availability does not automatically grant unrestricted asset or code reuse.

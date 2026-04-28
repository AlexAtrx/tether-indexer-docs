# Next steps

1. Apply the two-line fix in `wdk-app-node/workers/lib/services/ork.js` (see `description.md` → Fix).
2. Add a regression test in `wdk-app-node` for the empty-user path on `GET /api/v1/seed` and `GET /api/v1/entropy`.
3. Open a PR against `dev`, follow the dev → staging → main promote chain.
4. Verify in Sentry that `RUMBLE-WALLET-APP-A5` drops off after the prod promote.

# codeknight-infra

Single-box deployment for personal projects under `*.codeknight.dev`.
See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design.

- Host: EC2 t4g.micro (arm64), us-east-1, Docker + Caddy.
- Apps: `codeknight.dev` (Next.js), `nes.codeknight.dev` (static WASM).
- Deploys: each app repo builds an image to GHCR, then calls
  `.github/workflows/deploy.yml` here to redeploy that service.

## Internal area

`codeknight.dev/internal` is gated and dark by default: with any of
`INTERNAL_EMAIL`, `INTERNAL_PASSWORD_HASH` or `INTERNAL_SESSION_SECRET` unset,
the routes answer 404 rather than a login page. The proxy returns 404 and not
401 on purpose, so the area reads as a typo rather than a locked door.

Set the three values in `/srv/codeknight-infra/.env` (see `.env.example`),
which is never committed. Generate the hash from the app repo with
`node scripts/hash-password.mjs`.

## Data and backups

The valuation database lives in the `codeknight_data` volume, mounted at
`/data`. Without that volume the SQLite file would sit in the container layer
and every redeploy would silently discard every valuation.

`scripts/backup-db.sh` takes a `VACUUM INTO` snapshot nightly at 03:17 UTC and
keeps 14 days under `/srv/backups/codeknight`. It does not copy the file: a
live SQLite database in WAL mode is several files plus an in-flight log, and
copying the main one produces a backup that restores torn, usually without
complaining.

To restore, stop the app, gunzip a snapshot over `/data/codeknight.db` in the
volume, and start it again.

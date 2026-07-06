# codeknight-infra

Single-box deployment for personal projects under `*.codeknight.dev`.
See `docs/superpowers/specs/` and `docs/superpowers/plans/` for the design.

- Host: EC2 t4g.micro (arm64), us-east-1, Docker + Caddy.
- Apps: `codeknight.dev` (Next.js), `nes.codeknight.dev` (static WASM).
- Deploys: each app repo builds an image to GHCR, then calls
  `.github/workflows/deploy.yml` here to redeploy that service.

# Security

How this project handles secrets and other sensitive material.

> Template note: fill this in with your project's real posture and delete this note. Even a small project benefits from writing down where secrets live and what must never be committed — an agent reads this before touching credential-adjacent code.

## Secrets & credentials

<!-- FILL: where secrets live (a secret manager, encrypted credentials, environment variables),
     who/what holds each, and the trust levels. A short table works well:

| Secret            | Held by                | Grants                    |
| ----------------- | ---------------------- | ------------------------- |
| <admin key>       | <service / deploy>     | full access               |
| <scoped token>    | <client>               | least-privilege, read-only|
-->

## Rules

- **Never commit secrets.** Keys belong in the environment or a secret manager, not in the repo — including not in committed config files.
- **Least privilege.** Clients get the narrowest credential that works; the powerful key stays with the service that needs it.
- **Local settings are git-ignored.** `.claude/settings.local.json` and any local env files are never committed (see `.gitignore`).

## Reporting

<!-- FILL: how to report a vulnerability (an email, a private issue, a security policy). -->

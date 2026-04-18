# Frappe Docker GitOps

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Shell scripts for managing the full lifecycle of a [Frappe](https://frappeframework.com) / ERPNext Docker deployment — from first-time setup through upgrades, backups, and restores.

Designed to sit beside a cloned [frappe_docker](https://github.com/frappe/frappe_docker) repo so you can pull upstream updates independently without touching your own config. Your environment-specific files (`*.env`, `*.yaml`, `apps.json`, `backups/`) are git-ignored and never committed.

Each deployment is identified by an **instance name** (e.g. `erpnext`, `staging`). All scripts accept it as the first argument and default to `erpnext` when omitted — making it easy to manage multiple environments from the same repo.

## Folder structure

```
parent/
├── frappe_docker/         ← upstream repo (cloned by initialize.sh)
└── gitops/                ← this repo
    ├── apps.json              custom app list (git-ignored)
    ├── apps.json.example      template with erpnext + payments
    ├── <instance>.env         environment config (git-ignored)
    ├── <instance>.yaml        generated compose file (git-ignored)
    ├── backups/               backup files from backup.sh (git-ignored)
    ├── initialize.sh
    ├── build.sh
    ├── up.sh
    ├── upgrade.sh
    ├── migrate.sh
    ├── backup.sh
    ├── restore.sh
    ├── lint.sh
    └── LICENSE
```

## Prerequisites

- Docker with the Compose plugin (`docker compose version`)
- `git`
- `openssl` (for password generation)

## Quick start

```bash
git clone https://github.com/your-org/frappe-docker-gitops gitops
cd gitops

./initialize.sh           # guided setup — prompts for instance name, domains, image tag, etc.
                          # writes <instance>.env, pauses for review, then generates <instance>.yaml

# edit apps.json if you need custom apps

./build.sh                # build the custom Docker image
./up.sh                   # start all services
```

To manage multiple environments use the instance argument:

```bash
./initialize.sh staging
./build.sh staging
./up.sh staging
```

## Script reference

| Script | Usage | What it does |
|---|---|---|
| `initialize.sh` | `./initialize.sh [instance]` | First-time setup: clone frappe_docker, prompt for config, write env file (with review pause), generate compose file |
| `build.sh` | `./build.sh [instance]` | Build the custom ERPNext image using `apps.json` |
| `up.sh` | `./up.sh [instance]` | Start all services (`docker compose up -d`) |
| `upgrade.sh` | `./upgrade.sh [instance]` | Pull frappe_docker updates, prompt for new tag, rebuild image, recreate containers, run migrations |
| `migrate.sh` | `./migrate.sh [instance]` | Run `bench migrate` on all sites |
| `backup.sh` | `./backup.sh [instance]` | Full backup (DB + files) for all sites, saved to `backups/<timestamp>/` |
| `restore.sh` | `./restore.sh <instance> <site> <backup-file>` | Restore a site from a host-side backup file |
| `lint.sh` | `./lint.sh` | Syntax-check all scripts and smoke-test `initialize.sh` |

## initialize.sh prompts

| Prompt | Default | Notes |
|---|---|---|
| Instance name | `erpnext` | Used for project name and file names (`<instance>.env`, `<instance>.yaml`) |
| ERPNext version | `v16.14.0` | `v` prefix required |
| Custom image name | `localhost/<instance>` | e.g. `localhost/myimage` or `registry.example.com/myimage` |
| Image tag | `16.0.0` | Semantic version |
| DB root password | auto-generated | `openssl rand` 24-char password |
| Domain(s) | `erp.example.com` | Comma-separated, no spaces — e.g. `erp.example.com,crm.example.com` |
| HTTP publish port | `80` | |

After the env file is written, the script **pauses** so you can review and edit it (e.g. `CLIENT_MAX_BODY_SIZE`, `PROXY_READ_TIMEOUT`, `FRAPPE_SITE_NAME_HEADER`) before the compose file is generated.

The script shows which compose overrides are applied by default and lists all available overrides from `frappe_docker/overrides/` so you can regenerate the compose file with a different combination if needed.

## Upgrading

```bash
./upgrade.sh              # or ./upgrade.sh staging
```

Prompts for the new image tag. Handles everything: pulling frappe_docker updates, rebuilding the image, regenerating the compose config, restarting containers, running migrations.

## Backup & restore

```bash
./backup.sh               # backs up all sites
./backup.sh staging       # backs up a specific instance
```

Backup files are automatically copied from the container to `gitops/backups/<timestamp>/` on the host and removed from the container. Three files are created per site: `*-database.sql.gz`, `*-files.tar`, `*-private-files.tar`.

To restore, point the script at the database file on the host — companion files in the same folder are included automatically:

```bash
./restore.sh erpnext mysite.example.com ./backups/20240101_120000/20240101_sitename-database.sql.gz
```

## Custom apps

Edit `apps.json` before running `build.sh`. See `apps.json.example` for the format. The file is passed as a Docker build secret so credentials in URLs are not stored in image layers.

## Security

- `*.env`, `*.yaml`, `apps.json`, and `backups/` are all git-ignored — no passwords or tokens are ever committed
- DB passwords are auto-generated with `openssl rand` by default
- Build secrets (`apps.json`) are passed via `--secret` and never baked into image layers

## Further reading

- [frappe_docker documentation](https://github.com/frappe/frappe_docker/tree/main/docs)
- [Environment variables reference](https://github.com/frappe/frappe_docker/blob/main/docs/02-setup/04-env-variables.md)
- [Single server setup guide](https://github.com/frappe/frappe_docker/blob/main/docs/02-setup/08-single-server-nginxproxy-example.md)

## License

MIT — see [LICENSE](LICENSE).

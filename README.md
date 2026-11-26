# Postgres 18 Database

A PostgreSQL 18 database run with Docker Compose, with two sets of SQL/shell scripts:

- **Init scripts** (`initdb/`) run **once**, the first time the container starts with an empty data volume.
- **Startup scripts** (`startup/`) run **every time** the container starts.

## Project layout

```
.
├── docker-compose.yml
├── custom-entrypoint.sh   # wrapper that runs the startup scripts
├── initdb/                # one-time scripts
│   └── 01-schema.sql
└── startup/               # every-start scripts
    └── 01-migrations.sql
```

## Requirements

- Docker with the Compose plugin (`docker compose`)

## Quick start

```bash
docker compose up -d
docker compose logs -f db
```

On each start you should see `startup: running ...` lines in the logs, followed by `database system is ready to accept connections`.

## Connection details

| Setting  | Value       |
| -------- | ----------- |
| Host     | `localhost` |
| Port     | `5432`      |
| Database | `appdb`     |

Connection string:

```
postgresql://postgres:secret@localhost:5432/appdb
```

> Change the default password before using this anywhere other than local development.

### Connecting with pgAdmin

Register a new server with the values above. For **Maintenance database**, use `appdb` (or `postgres`).

- If pgAdmin runs on your machine, use host `localhost`.
- If pgAdmin runs as a container in the same compose file, use host `db` instead.

## How the scripts work

### Init scripts (`initdb/`)

Mounted at `/docker-entrypoint-initdb.d`. The official Postgres image runs these only when the data directory is empty, so they execute once per fresh volume. Supported file types: `.sql`, `.sql.gz`, `.sh`. Files run in alphabetical order, so prefix them with numbers.

Use these for schema creation, roles, extensions and seed data.

### Startup scripts (`startup/`)

Mounted at `/docker-entrypoint-startup.d` and run by `custom-entrypoint.sh` once Postgres is accepting connections. Supported file types: `.sql`, `.sh`. They run in alphabetical order on every container start, including automatic restarts.

**These scripts must be idempotent.** Use `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE`, `INSERT ... ON CONFLICT DO NOTHING`, and similar patterns. A failing script (`ON_ERROR_STOP=1`) will stop the startup sequence.

## Data persistence

Data is stored in the named volume `pgdata`, mounted at `/var/lib/postgresql`. (Postgres 18 uses a versioned subdirectory, so the volume is mounted one level higher than in earlier versions.)

## Common tasks

```bash
# Stop (keeps data)
docker compose down

# Stop and delete all data (init scripts will run again next start)
docker compose down -v

# Open a psql shell
docker compose exec db psql -U postgres -d appdb

# View logs
docker compose logs db --tail 50

# Restart (startup scripts run again)
docker compose restart db

# Back up the database
docker compose exec db pg_dump -U postgres appdb > backup.sql

# Restore from a backup
docker compose exec -T db psql -U postgres -d appdb < backup.sql
```

## Troubleshooting

**Cannot connect / connection timeout**

1. Check the container is running and healthy: `docker compose ps`
2. Check the logs: `docker compose logs db --tail 50`
3. Test inside the container: `docker compose exec db psql -U postgres -d appdb -c "select 1"`
4. Check whether another Postgres is already using port 5432 (`netstat -ano | findstr :5432` on Windows, `sudo lsof -i :5432` on macOS/Linux). If so, change the port mapping to `"5433:5432"` and connect on `5433`.
5. If pgAdmin is in a container, use host `db`, not `localhost`.

**Init scripts did not run**

They only run when the volume is empty. Run `docker compose down -v` and start again.

**Container exits on startup**

A script in `initdb/` or `startup/` probably failed. Check `docker compose logs db` for the error.

## Configuration

Environment variables are set in `docker-compose.yml`:

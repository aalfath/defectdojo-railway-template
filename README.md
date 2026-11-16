# DefectDojo on Railway

Railway template for [DefectDojo](https://github.com/DefectDojo/django-DefectDojo), the open-source DevSecOps and vulnerability management platform. It imports results from 200+ security scanners, deduplicates findings and tracks them across products, engagements and tests.

**Version:** DefectDojo **3.5.103**, built from the official images `defectdojo/defectdojo-django:3.5.103` and `defectdojo/defectdojo-nginx:3.5.103` (static files only), both pinned by digest in the [`Dockerfile`](Dockerfile).

## What the template deploys

| Service | Source | Purpose |
|---|---|---|
| **DefectDojo** | this repo | Runs DefectDojo's initializer (migrations, fixtures, admin user), the uWSGI web server on `PORT`, the Celery worker and Celery beat. Uploads live on a volume at `/app/media`. |
| **Postgres** | Railway Postgres | Main database |
| **Redis** | Railway Redis | Celery broker (db 0) and Django cache (db 1) |

The public URL, allowed hosts, CSRF origins and secure cookies are derived from the Railway domain in [`start.sh`](start.sh).

## Variables

| Variable | Default | Notes |
|---|---|---|
| `DD_ADMIN_USER` | `admin` | Username of the first superuser |
| `DD_ADMIN_PASSWORD` | generated secret | Password of the first superuser. Read it from the service's Variables tab. Only used on first boot; change the password later in the UI |
| `DD_ADMIN_MAIL` | `admin@defectdojo.local` | E-mail of the first superuser |
| `DD_SECRET_KEY` | generated secret | Django secret key |
| `DD_CREDENTIAL_AES_256_KEY` | generated secret | Encrypts stored tool credentials. Don't change it after first boot |
| `DD_DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | |
| `RAILWAY_HEALTHCHECK_TIMEOUT_SEC` | `600` | First boot sets up the database before the web server starts |

Optional (not in the template, add them on the service if you need them):

- **Custom domain:** set `DD_SITE_URL=https://YOUR-DOMAIN`. Allowed hosts and CSRF origins follow it.
- **E-mail:** `DD_EMAIL_URL` (for example `smtp+tls://user:password@smtp.example.com:587`).
- **Size:** `DD_UWSGI_NUM_OF_PROCESSES` (default 2), `DD_UWSGI_NUM_OF_THREADS` (default 4), `DD_CELERY_WORKER_CONCURRENCY` (default 1).
- Any other `DD_*` setting from DefectDojo's [`settings.dist.py`](https://github.com/DefectDojo/django-DefectDojo/blob/master/dojo/settings/settings.dist.py).

## Updates

The template builds from this repository's `main` branch. A new DefectDojo release is a pin bump in the `Dockerfile` plus a `CHANGELOG.md` entry. When it's merged, Railway offers the update to everyone who deployed the template, and they choose when to apply it. DefectDojo runs its database migrations on start.

## Health check

`/login` (answers without a session). Set on the Railway service, not in a `railway.json`.

## License

The wrapper files in this repo are MIT. DefectDojo itself is BSD-3-Clause.

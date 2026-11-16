# Changelog

## 3.5.103-1 (2026-11-16)

- README: Deploy on Railway button for the published template (`defectdojo`). No change to the deployed service.

## 3.5.103 (2026-11-16)

- First version: DefectDojo 3.5.103 (official `defectdojo/defectdojo-django` image, static files from `defectdojo/defectdojo-nginx`), one service running the initializer, uWSGI, the Celery worker and Celery beat, with Railway Postgres and Redis.

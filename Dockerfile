# DefectDojo for Railway: one service runs the initializer, uWSGI (web), Celery worker and Celery beat.
# Upstream: https://github.com/DefectDojo/django-DefectDojo (release 3.5.103)

# The official nginx image of the same release carries the collected static files (CSS/JS bundles).
FROM defectdojo/defectdojo-nginx:3.5.103@sha256:2afc43f88f09c842aebbc581c7839fcf83cd870bb90291e2724239e34d0f7ccc AS static

FROM defectdojo/defectdojo-django:3.5.103@sha256:28c8791747aa5ed99953d561d28ef306049e0da594795e93c163c38ee6fda06e

USER root
COPY --from=static /usr/share/nginx/html/static /app/static
COPY start.sh /railway-start.sh
RUN chmod 755 /railway-start.sh

ENV DD_MEDIA_ROOT=/app/media \
    DD_STATIC_ROOT=/app/static \
    DD_UWSGI_NUM_OF_PROCESSES=2 \
    DD_UWSGI_NUM_OF_THREADS=4

# Starts as root only to fix the volume's ownership, then drops to the image's defectdojo user (uid 1001).
ENTRYPOINT ["/railway-start.sh"]

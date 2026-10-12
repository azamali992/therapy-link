# Pinned to the multi-arch index digest so a rebuild gets the same base; the tag stays for
# readability. A Dependabot docker entry for /api keeps the digest current.
FROM python:3.14-slim@sha256:a2b82f3c48559aa0a8446d9af49826b6e2b2016f4cd2afabfe6013ec53729170

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=7860 WEB_CONCURRENCY=1
WORKDIR /srv

COPY pyproject.toml ./
COPY therapylink_api ./therapylink_api
RUN pip install --no-cache-dir .

# Migrations ship in the image so `release` can build or upgrade a Postgres schema.
COPY alembic.ini ./
COPY alembic ./alembic
COPY docker-entrypoint.sh /usr/local/bin/tl-api
# A Windows checkout can turn the script's line endings into CRLF, which breaks the shebang.
RUN sed -i 's/\r$//' /usr/local/bin/tl-api && chmod +x /usr/local/bin/tl-api

RUN useradd -m app && chown -R app /srv
USER app

EXPOSE 7860
# Liveness probe: the process is running and the HTTP stack is up.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT:-7860}/health')" || exit 1
ENTRYPOINT ["tl-api"]
CMD ["serve"]

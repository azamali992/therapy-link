# Pinned to the multi-arch index digest so a rebuild gets the same base; the tag stays for
# readability. A Dependabot docker entry for /api keeps the digest current.
FROM python:3.12-slim@sha256:2f17fc044b579bab302c2e8054d3a686e2cb9a83de48e70534b94cd8ebbe06a9

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

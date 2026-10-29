FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg ca-certificates && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 10001 --create-home --shell /usr/sbin/nologin appuser \
    && mkdir -p /cache /videos && chown -R appuser:appuser /cache
WORKDIR /app
COPY server.py /app/server.py
USER appuser
ENV PYTHONUNBUFFERED=1 PORT=8765 VIDEO_ROOT=/videos CACHE_ROOT=/cache
EXPOSE 8765
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD python -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:8765/healthz',timeout=3).read()" || exit 1
CMD ["python", "-u", "server.py"]

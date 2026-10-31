FROM python:3.13-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir pillow
WORKDIR /app
COPY app.py /app/app.py
EXPOSE 8099
CMD ["python", "-u", "/app/app.py"]

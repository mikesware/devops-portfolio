# Optional: containerized scan environment if desired
FROM python:3.10-slim
RUN apt-get update && apt-get install -y nmap && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY scripts/ /app/scripts
CMD ["python", "/app/scripts/scan.py"]
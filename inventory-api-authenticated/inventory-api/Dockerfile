FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv
RUN groupadd --system app && useradd --system --gid app app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
COPY scripts ./scripts
USER app
EXPOSE 8055
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8055", "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]

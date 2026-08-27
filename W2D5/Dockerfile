FROM python:3.11-slim

WORKDIR /home/app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

ENV MODEL_ID=Qwen/Qwen2.5-0.5B-Instruct
ENV API_KEY=""
ENV MAX_TOKENS=256
ENV HF_HOME=/home/app/.cache/huggingface

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

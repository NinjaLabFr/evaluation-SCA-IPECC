FROM python:3.13.5-slim
WORKDIR /app


RUN apt-get update && apt-get install -y --no-install-recommends make zstd 

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ /app/src/
COPY Makefile /app/

ENTRYPOINT ["make"]
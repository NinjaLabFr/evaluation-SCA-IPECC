FROM python:3.13.5-slim
WORKDIR /app

COPY *.py /app
COPY *.sh /app
COPY *.ipynb /app
COPY *.txt /app
COPY Makefile /app

RUN pip install -r requirements.txt

RUN apt-get update && apt-get install -y --no-install-recommends make

ENTRYPOINT ["make"]
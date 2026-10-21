FROM python:3.13.5-slim
WORKDIR /app
COPY . /app
RUN pip install -r requirements.txt
ENTRYPOINT ["bash", "sca-flow.sh"]
FROM python:3.13.5-slim
WORKDIR /app
COPY *.py /app
COPY *.sh /app
COPY *.ipynb /app
COPY *.txt /app
RUN pip install -r requirements.txt
ENTRYPOINT ["bash", "sca-flow.sh"]
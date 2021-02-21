FROM python:3.8.7-alpine3.12


COPY . /app
RUN chmod -R 444 /app/

WORKDIR /app


RUN pip install --no-cache-dir -r requirements.txt

ENV PYTHONPATH /app
ENV PORT 8080

CMD ["python", "/app/main.py"]

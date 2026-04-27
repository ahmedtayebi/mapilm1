FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE $PORT

CMD daphne config.asgi:application --port $PORT --bind 0.0.0.0 -v2

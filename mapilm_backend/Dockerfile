FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE $PORT

CMD daphne -b 0.0.0.0 -p ${PORT:-8000} config.asgi:application

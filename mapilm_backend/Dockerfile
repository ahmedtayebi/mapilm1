FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE $PORT

CMD sh -c "gunicorn config.wsgi:application --bind 0.0.0.0:$PORT --workers 2 --timeout 120"

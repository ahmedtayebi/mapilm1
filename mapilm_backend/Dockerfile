FROM python:3.11-slim
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DJANGO_SETTINGS_MODULE=config.settings.production
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN python manage.py collectstatic --noinput
CMD sh -c "python manage.py migrate --noinput && python -c 'import config.asgi; print(\"ASGI import OK\")' 2>&1 && daphne -v 2 -b 0.0.0.0 -p ${PORT:-8000} config.asgi:application 2>&1"
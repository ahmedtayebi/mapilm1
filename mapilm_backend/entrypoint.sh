#!/bin/sh
set -e

echo "=== Running migrations ==="
python manage.py migrate --noinput

echo "=== Starting Daphne on port ${PORT:-8000} ==="
exec daphne -v 2 -b 0.0.0.0 -p ${PORT:-8000} config.asgi:application
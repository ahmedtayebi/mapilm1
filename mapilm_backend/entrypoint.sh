#!/bin/sh
set -e

echo "=== Starting migrations ==="
python manage.py migrate --noinput

echo "=== Testing ASGI import ==="
python -c "
import sys
try:
    import config.asgi
    print('ASGI import OK')
except Exception as e:
    print('ASGI IMPORT FAILED:', e)
    sys.exit(1)
"

echo "=== Starting daphne on port ${PORT:-8000} ==="
exec daphne -v 2 -b 0.0.0.0 -p ${PORT:-8000} config.asgi:application
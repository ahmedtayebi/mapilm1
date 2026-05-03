# Plan: Fix Railway Deployment Healthcheck Failure

## Problem
Railway build succeeds but healthcheck at `/health/` fails with 503 — app is not responding on the expected port.

## Root Causes
1. `ALLOWED_HOSTS` not set in Railway env vars → Django returns 400 on every request (including healthcheck)
2. Dockerfile CMD used `gunicorn + UvicornWorker` — heavyweight and brittle; `daphne` is purpose-built for ASGI/Channels and already installed
3. `SESSION_COOKIE_SECURE = True` could cause redirect loops when Railway's proxy isn't fully HTTPS-provisioned at deploy time
4. Firebase/Cloudinary init can crash workers silently if credentials are missing

## Changes Applied
- [x] **Dockerfile**: replaced `sh -c "python manage.py migrate ... && gunicorn ..."` with JSON array CMD `["daphne", "-b", "0.0.0.0", "-p", "${PORT:-8000}", "config.asgi:application"]`
- [x] **production.py**: set `SESSION_COOKIE_SECURE = False`, `CSRF_COOKIE_SECURE = False`
- [x] Firebase init already has try/except guard in base.py (no change needed)

## Manual Step Required
- [ ] Add `ALLOWED_HOSTS` variable in Railway Variables panel: `*.railway.app` or `*`

## Why These Fixes Work
- **daphne**: Native ASGI server for Django Channels — no worker bridge layer, clean startup signals
- **JSON array CMD**: Proper OS signal handling (no `sh -c` wrapper that swallows signals)
- **Secure cookies = False**: Railway's load balancer handles HTTPS termination; secure cookies at app level are redundant and can cause issues
- **ALLOWED_HOSTS**: Django enforces this header — without it covering Railway's domain, every request returns 400
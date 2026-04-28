---
name: aliyun-sub2api-ops
description: Use when operating Pans0020's Aliyun ECS Sub2API deployment, including SSH access, Docker upgrades, Redis fixes, Xray proxy checks, Neon Postgres edits, and Sub2API troubleshooting.
---

# Aliyun Sub2API Ops

## Fixed Targets

- Server: `root@47.106.198.133`
- Project directory: `/root/ResearchWang13`
- Compose file: `/root/ResearchWang13/docker-compose.yml`
- Env file: `/root/ResearchWang13/.env`
- App container: `sub2api_core`
- Redis container: `sub2api_redis`
- App URL: `http://47.106.198.133:8080`
- App image: `weishaw/sub2api:<version>`
- HTTP proxy on server: `127.0.0.1:10809`
- SOCKS5 proxy on server: `127.0.0.1:10808`
- Proxy address from inside `sub2api_core`: `172.19.0.1:10809` for HTTP, `172.19.0.1:10808` for SOCKS5
- Database host: `ep-wandering-haze-a1h3hmce.ap-southeast-1.aws.neon.tech`

Never put database passwords, Redis passwords, VLESS links, or API keys into public files or Git commits. Read secrets from `/root/ResearchWang13/.env` on the server.

## Quick Checks

Use these before changing anything:

```bash
ssh root@47.106.198.133 'cd /root/ResearchWang13 && docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
ssh root@47.106.198.133 'curl -I --max-time 20 http://127.0.0.1:8080/login'
ssh root@47.106.198.133 'curl -s --max-time 20 http://127.0.0.1:8080/api/v1/settings/public'
ssh root@47.106.198.133 'docker logs --tail 120 sub2api_core 2>&1'
```

Expected healthy signs:

- `sub2api_core` is `Up` and usually `healthy` after warmup.
- `/login` returns `200 OK`.
- `/api/v1/settings/public` returns JSON with a `version` field after initialization.

If `/api/v1/settings/public` returns `404 page not found` and logs say `First run detected`, the app is in setup wizard mode. That is an initialization state issue, not a failed Docker upgrade.

## Upgrade Sub2API

Prefer pinned tags over `latest`.

```bash
ssh root@47.106.198.133 'docker pull weishaw/sub2api:0.1.118'
ssh root@47.106.198.133 'cd /root/ResearchWang13 && cp docker-compose.yml docker-compose.yml.bak_$(date +%Y%m%d_%H%M%S) && sed -i "s#^[[:space:]]*image: weishaw/sub2api:.*#    image: weishaw/sub2api:0.1.118#" docker-compose.yml'
ssh root@47.106.198.133 'docker rm -f sub2api_core >/dev/null 2>&1 || true; cd /root/ResearchWang13 && docker-compose up -d'
```

Verify after every upgrade:

```bash
ssh root@47.106.198.133 'sleep 20; docker ps --filter name=sub2api_core --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
ssh root@47.106.198.133 'curl -s --max-time 20 http://127.0.0.1:8080/api/v1/settings/public; echo'
ssh root@47.106.198.133 'curl -I --max-time 20 http://127.0.0.1:8080/login'
```

Known quirk: this server has `docker-compose v1`, which can fail during recreate with `KeyError: 'ContainerConfig'`. Use `docker rm -f sub2api_core` before `docker-compose up -d` to avoid that path.

## Current Compose Shape

The deployment should keep local Redis in compose to avoid Upstash quota limits:

```yaml
services:
  redis:
    image: redis:7-alpine
    container_name: sub2api_redis
    restart: always
    command: ["redis-server", "--appendonly", "yes"]
    volumes:
      - redis_data:/data

  sub2api:
    image: weishaw/sub2api:0.1.118
    container_name: sub2api_core
    restart: always
    depends_on:
      - redis
    ports:
      - "8080:8080"
    env_file:
      - .env

volumes:
  redis_data:
```

The Redis entries in `.env` should be:

```env
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_USE_TLS=false
```

Do not use `127.0.0.1` for Redis inside the app container.

## Proxy Checks

The server has Xray installed as `xray.service`; Docker uses the HTTP proxy on `127.0.0.1:10809`.

```bash
ssh root@47.106.198.133 'systemctl status xray --no-pager | sed -n "1,25p"'
ssh root@47.106.198.133 'ss -lntp | grep -E ":10808|:10809" || true'
ssh root@47.106.198.133 'curl -I --max-time 20 --proxy http://127.0.0.1:10809 https://registry-1.docker.io/v2/'
ssh root@47.106.198.133 'docker exec sub2api_core sh -lc "curl -I --max-time 20 --proxy http://172.19.0.1:10809 https://www.google.com | sed -n '\''1,12p'\''"'
```

Inside the Sub2API UI proxy form:

- HTTP proxy: host `172.19.0.1`, port `10809`, no username, no password.
- SOCKS5 proxy: host `172.19.0.1`, port `10808`, no username, no password.

If the error says `dial tcp 127.0.0.1:10808: connect: connection refused`, the UI is still using container-local loopback. Change the host to `172.19.0.1`.

## Database Edits

Install `psql` if missing:

```bash
ssh root@47.106.198.133 'export DEBIAN_FRONTEND=noninteractive; apt-get update && apt-get install -y postgresql-client'
```

Build connection values from `.env` without sourcing the file, because it may have Windows CRLF:

```bash
ssh root@47.106.198.133 'cd /root/ResearchWang13; DBH=$(awk -F= "/^DATABASE_HOST=/{print \$2}" .env | tr -d "\r"); DBP=$(awk -F= "/^DATABASE_PORT=/{print \$2}" .env | tr -d "\r"); DBU=$(awk -F= "/^DATABASE_USER=/{print \$2}" .env | tr -d "\r"); DBN=$(awk -F= "/^DATABASE_DBNAME=/{print \$2}" .env | tr -d "\r"); DBS=$(awk -F= "/^DATABASE_SSL_MODE=/{print \$2}" .env | tr -d "\r"); export PGPASSWORD=$(awk -F= "/^DATABASE_PASSWORD=/{print \$2}" .env | tr -d "\r"); psql "host=$DBH port=$DBP dbname=$DBN user=$DBU sslmode=$DBS" -P pager=off -c "SELECT id,email,role,status FROM users ORDER BY id;"'
```

To make `15777797126@163.com` an admin:

```bash
ssh root@47.106.198.133 'cd /root/ResearchWang13; DBH=$(awk -F= "/^DATABASE_HOST=/{print \$2}" .env | tr -d "\r"); DBP=$(awk -F= "/^DATABASE_PORT=/{print \$2}" .env | tr -d "\r"); DBU=$(awk -F= "/^DATABASE_USER=/{print \$2}" .env | tr -d "\r"); DBN=$(awk -F= "/^DATABASE_DBNAME=/{print \$2}" .env | tr -d "\r"); DBS=$(awk -F= "/^DATABASE_SSL_MODE=/{print \$2}" .env | tr -d "\r"); export PGPASSWORD=$(awk -F= "/^DATABASE_PASSWORD=/{print \$2}" .env | tr -d "\r"); psql "host=$DBH port=$DBP dbname=$DBN user=$DBU sslmode=$DBS" -v ON_ERROR_STOP=1 -P pager=off -c "UPDATE users SET role='\''admin'\'', updated_at=now() WHERE email='\''15777797126@163.com'\'' AND deleted_at IS NULL RETURNING id,email,role,status,updated_at;"'
```

After role changes, tell the user to log out and log back in if the UI still shows old permissions.

## Common Failures

- `Too many requests, please try again later`: check logs for `ERR max requests limit exceeded`; this was caused by Upstash Redis quota. Keep using local Redis.
- `First run detected`: local Redis has no bootstrap state or setup was reset; check whether setup needs to be completed.
- Docker pull timeout: verify `xray.service`, Docker proxy environment, and `curl --proxy http://127.0.0.1:10809`.
- `ContainerConfig` during compose update: remove `sub2api_core` and run `docker-compose up -d`.
- Neon prepared statement errors with `-pooler` host: use direct Neon host `ep-wandering-haze-a1h3hmce.ap-southeast-1.aws.neon.tech`, not the `-pooler` host.

## Completion Rule

Never report success until all relevant checks have been run in the same turn:

- `docker ps` for container state.
- `/login` HTTP status.
- `/api/v1/settings/public` when the app is initialized.
- `docker logs --tail` for obvious startup errors.

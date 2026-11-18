# Deploying dufs on andr (Instabox)

This deploys the dufs file-upload service on the Instabox machine `andr`
(machine id `m_agqzopef4yjlxqjv7uzkdvs2e4`) as the Docker container
`file-upload`. It reproduces the live deployment exactly:

- Image: `sigoden/dufs`
- Container: `file-upload`, `--restart unless-stopped`
- Served directory: `/data/home/uploads` (host) mounted at `/data` (container)
- Container port `5000` published on host port `8080`
- Public URL: `https://8080-agqzopef4yjlxqjv7uzkdvs2e4.instabox.tech`
- Auth: Basic Auth, single account (`knight`), read-write on `/`
  (`-A` / `--allow-all`); password is supplied via the `DUFS_AUTH`
  environment variable and never appears in this repo.

> andr sleeps daily 01:00–09:00. The container restarts automatically on
> wake (`unless-stopped`), but the service is unreachable while the machine
> is stopped.

## Prerequisites

- SSH access to andr (see `instabox-sbox` in ssh config).
- Docker running on andr.
- The `instabox` CLI (for publishing port 8080), or the Instabox API.

## Deploy

```sh
# on andr
git clone https://github.com/tearoadtrade/dufs.git
cd dufs
git checkout dev

# Set the auth credential (use the real password here, on the machine only).
# Format: <user>:<password>@/:rw  (read-write on the whole served tree)
export DUFS_AUTH='knight:<password>@/:rw'

docker compose up -d
docker ps --filter name=file-upload
```

`docker-compose.yml` at the repo root is the whole deployment: image,
container name, restart policy, port mapping, volume mount, `DUFS_AUTH`
from the environment, and `command: /data -A`.

To stop / remove:

```sh
docker compose down        # stops and removes the container (data stays in /data/home/uploads)
```

## Publish port 8080

The container listens on host port 8080, but the public URL only exists
after the port is published on Instabox:

```sh
instabox port publish andr 8080
# public URL: https://8080-agqzopef4yjlxqjv7uzkdvs2e4.instabox.tech
```

(Equivalent API call: `POST /v1/machines/m_agqzopef4yjlxqjv7uzkdvs2e4/ports`
with `{"port": 8080}` and the `X-API-Key` header.)

## Verify auth

```sh
BASE_URL=https://8080-agqzopef4yjlxqjv7uzkdvs2e4.instabox.tech

# no credentials -> 401
curl -s -o /dev/null -w '%{http_code}\n' "$BASE_URL/"

# with credentials -> 200
curl -s -o /dev/null -w '%{http_code}\n' -u 'knight:<password>' "$BASE_URL/"
```

## Smoke test (upload / download / delete)

```sh
BASE_URL=https://8080-agqzopef4yjlxqjv7uzkdvs2e4.instabox.tech
AUTH='knight:<password>'

# upload a small file -> 201
echo hello-dufs > /tmp/dufs-smoke.txt
curl -s -o /dev/null -w '%{http_code}\n' -u "$AUTH" -T /tmp/dufs-smoke.txt "$BASE_URL/dufs-smoke.txt"

# download it back, content must match -> 200
curl -s -u "$AUTH" "$BASE_URL/dufs-smoke.txt"

# delete it -> 204
curl -s -o /dev/null -w '%{http_code}\n' -u "$AUTH" -X DELETE "$BASE_URL/dufs-smoke.txt"
```

## Notes

- Never put a real password in this repo (no `docker-compose.yml`,
  no docs, no scripts). Passwords live only in the environment on andr.
- The uploads directory `/data/home/uploads` is on andr's persistent
  disk; removing the container does not delete uploaded files.
- To change the password, set a new `DUFS_AUTH` and recreate the
  container (`docker compose up -d --force-recreate`). Changing the
  password also invalidates every outstanding share-token link, because
  share tokens are signed with a key derived from the account password.

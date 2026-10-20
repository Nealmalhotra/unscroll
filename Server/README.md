# Unscroll Server

A small, self-hostable backend for **Unscroll**, an open-source screen-time app.
It has no dependencies: Node.js built-ins only (`node:http`, `node:crypto`, `node:fs`, `node:test`).
It stores data in a single JSON file, written atomically (temp file + rename).

It provides:

- Anonymous accounts: pick a handle, get a bearer token.
- Weekly stats (`xp`, `screenMinutes`) per ISO week.
- Leagues: six tiers in cohorts of up to 30 players, with a weekly rollover that promotes and demotes.
- Invite-only groups with a member leaderboard and an activity feed.

## Run

Requires Node.js 22.9+ (developed on Node 25). No `npm install` needed: there are zero dependencies.

```sh
cd Server
cp .env.example .env           # optional: edit settings
npm start                      # listens on :8787, data in ./data/db.json
npm test                       # run the test suite
npm run coverage               # tests + coverage report
```

## Environment variables

Set these in `.env` (loaded automatically by `npm start`) or in the environment. Real environment variables take precedence over `.env`.

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8787` | TCP port. |
| `HOST` | `0.0.0.0` | Bind address. |
| `DATA_FILE` | `./data/db.json` | JSON data file. The directory is created if missing. |
| `ADMIN_TOKEN` | *(unset)* | Bearer token for `/v1/admin/*`. If unset, admin routes return 403. |
| `RATE_LIMIT_PER_MINUTE` | `60` | Size of the per-IP token bucket. It refills at this many tokens per minute. |
| `TRUST_PROXY` | *(unset)* | Set to `1` behind a reverse proxy. The client IP then comes from `Fly-Client-IP`, or else the last `X-Forwarded-For` entry. |

## Conventions

- **Envelope.** Every response, including errors, is JSON with this shape:
  `{"success": true|false, "data": <any>|null, "error": <string>|null}`.
- **Auth.** Send `Authorization: Bearer <token>` on every route except `GET /healthz` and `POST /v1/users`.
  The server stores only the SHA-256 hash of each token and compares hashes with `crypto.timingSafeEqual`.
  A lost token cannot be recovered.
- **Bodies.** Send `Content-Type: application/json` with a JSON object of at most 16 KB.
  Unknown fields return 400. Unknown or repeated query parameters also return 400.
- **Week ids.** ISO-8601 weeks in the form `YYYY-Www` (for example `2026-W43`), with years 2000-2100.
  `W53` is accepted only in years that have one. When a `weekId` query parameter is optional and you leave it out,
  the server uses the current ISO week in UTC.
- **Rate limit.** A per-IP token bucket. When it is empty, the server returns `429` with a `Retry-After` header in seconds.
  `/healthz` is not rate limited.
- **Errors.** `400` validation, `401` missing or invalid token, `403` forbidden or not a member, `404` not found,
  `405` wrong method (with an `Allow` header), `409` conflict, `413` body too large, `415` wrong content type,
  `429` rate limited, `500` internal error. A 500 response says only `"Internal server error"`.
  Details and stack traces go to the server's stderr as JSON lines.

## API reference

The examples below assume these variables:

```sh
API=http://localhost:8787
TOKEN=<token from signup>
```

### `GET /healthz`

```sh
curl $API/healthz
# {"success":true,"data":{"ok":true},"error":null}
```

### `POST /v1/users`: sign up (no auth)

Request: `{"handle": string}`. The handle is 3-20 characters from `[A-Za-z0-9_]` and must be unique, ignoring case.

Responses: `201` with `{id, handle, token}`, or `409` if the handle is taken.

```sh
curl -X POST $API/v1/users -H 'Content-Type: application/json' -d '{"handle":"neal"}'
# {"success":true,"data":{"id":"6f1c…","handle":"neal","token":"<64 hex chars>"},"error":null}
```

### `GET /v1/me`

Response: `200` with `{id, handle, tier, createdAt}`.

```sh
curl $API/v1/me -H "Authorization: Bearer $TOKEN"
```

### `PUT /v1/me/week`: upsert this week's stats

Request: `{"weekId": "YYYY-Www", "xp": 0..1000000, "screenMinutes": 0..20160}`. All values are integers.

Responses: `200` with `{weekId, xp, screenMinutes, updatedAt}`, or `409` if that week has been rolled over.

```sh
curl -X PUT $API/v1/me/week -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"weekId":"2026-W43","xp":420,"screenMinutes":610}'
```

### `GET /v1/me/league?weekId=YYYY-Www`

The first call in a week places you in a cohort of up to 30 players in your current tier.
The server fills existing cohorts before it opens a new one. Later calls that week return the same cohort.

Response: `200` with the following shape.

```json
{
  "weekId": "2026-W43",
  "tier": "bronze",
  "cohortId": "uuid",
  "standings": [{"handle": "neal", "xp": 420, "rank": 1, "isMe": true}],
  "promoteCount": 10,
  "demoteCount": 5
}
```

- Standings are sorted by xp, highest first. Ties are ordered by handle, ignoring case.
- `rank` is 1-based and sequential.
- A `409` means the week has been rolled over and you were not assigned before that.
- Tiers, lowest to highest: `bronze`, `silver`, `gold`, `platinum`, `diamond`, `present`.

```sh
curl "$API/v1/me/league?weekId=2026-W43" -H "Authorization: Bearer $TOKEN"
```

### `POST /v1/admin/rollover` (auth: `Bearer $ADMIN_TOKEN`)

Request: `{"weekId": "YYYY-Www"}`.

This applies the tier changes for every cohort of that week.

- Promotion: the top 10 with `xp > 0` move up a tier. Nobody moves above `present`.
- Demotion: the bottom 5 move down a tier, only in cohorts with more than 15 members. Nobody moves below `bronze`.
- The week is then final. Further stat updates or league assignments for it return `409`.

Response: `200` with `{weekId, appliedAt, cohortCount, changes: [{handle, from, to, change: "promote"|"demote"}]}`.
A second rollover for the same week returns `409`.

```sh
curl -X POST $API/v1/admin/rollover -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' -d '{"weekId":"2026-W43"}'
```

Run it from cron shortly after Monday 00:00 UTC for the previous week, before clients ask for the new week's league.
Assignment uses the tier the player has at that moment.

### `POST /v1/groups`: create an invite-only group

Request: `{"name": string}`. The name is 1-40 characters after trimming, with no control characters.

Response: `201` with `{id, name, inviteCode, memberCount}`.
The invite code is 8 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, so it has no I, L, O, 0 or 1.
The creator becomes a member.

```sh
curl -X POST $API/v1/groups -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"name":"Study Crew"}'
```

### `POST /v1/groups/join`

Request: `{"inviteCode": string}`. The code is case-insensitive.

Responses:

- `200` with `{id, name, inviteCode, memberCount}`. Joining a group you are already in also returns `200`.
- `404` if no group has that code.
- `409` if the group already has 50 members.

```sh
curl -X POST $API/v1/groups/join -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"inviteCode":"K7PQ2MXA"}'
```

### `GET /v1/groups`: my groups

Response: `200` with `[{id, name, inviteCode, memberCount}]`.

```sh
curl $API/v1/groups -H "Authorization: Bearer $TOKEN"
```

### `GET /v1/groups/:id?weekId=YYYY-Www`: group detail (members only)

Response: `200` with the following shape.

```json
{
  "id": "uuid",
  "name": "Study Crew",
  "inviteCode": "K7PQ2MXA",
  "weekId": "2026-W43",
  "members": [{"handle": "neal", "xp": 420, "screenMinutes": 610}],
  "feed": [{"handle": "neal", "kind": "goalMet", "minutes": null, "at": "2026-10-19T08:00:00.000Z"}]
}
```

- `members` is sorted by xp, highest first. Stats are for `weekId`. A member with no stats that week shows 0.
- `feed` holds the last 50 events, newest first.
- `404` means the group does not exist. `403` means you are not a member.

```sh
curl "$API/v1/groups/$GROUP_ID?weekId=2026-W43" -H "Authorization: Bearer $TOKEN"
```

### `POST /v1/groups/:id/leave` (members only)

Send no body, or `{}`.

Response: `200` with `{id, left: true, deleted}`. When the last member leaves, the group is deleted and `deleted` is `true`.

```sh
curl -X POST $API/v1/groups/$GROUP_ID/leave -H "Authorization: Bearer $TOKEN"
```

### `POST /v1/groups/:id/feed` (members only)

Request: `{"kind": "sessionStarted"|"sessionCompleted"|"sessionBroken"|"goalMet"|"goalMissed", "minutes"?: 0..1440}`.

Response: `201` with `{handle, kind, minutes, at}`. `minutes` is `null` when you leave it out.
The server keeps the newest 200 events for each group.

```sh
curl -X POST $API/v1/groups/$GROUP_ID/feed -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"kind":"sessionCompleted","minutes":45}'
```

## Deployment

The server runs as a single process and holds its state in memory, backed by one JSON file.
Run exactly one instance and keep `DATA_FILE` on a persistent volume.
That is fine for friends-and-family scale, up to a few thousand users.

### Docker

```sh
docker build -t unscroll-server .
docker run -d -p 8787:8787 -v unscroll-data:/data -e ADMIN_TOKEN=$(openssl rand -hex 32) unscroll-server
```

### fly.io

```sh
fly launch --no-deploy                      # uses the Dockerfile
fly volumes create unscroll_data --size 1
# add to fly.toml:  [mounts] source="unscroll_data" destination="/data"
fly secrets set ADMIN_TOKEN=$(openssl rand -hex 32) TRUST_PROXY=1
fly scale count 1 && fly deploy
```

Put TLS in front of the server. fly.io does this for you; elsewhere use Caddy or nginx.
Set `TRUST_PROXY=1` only when a proxy you control sets the forwarding headers.
Back up the data file by copying `db.json`. Writes are atomic, so a copy is always a complete snapshot.

## Layout

```
src/server.js       HTTP wiring: config, rate limit, auth, body parsing, envelope
src/routes.js       route table + matcher
src/handlers/*.js   users, weeks, league, groups, admin
src/store.js        JSON-file repository (findAll/findById/create/update/remove/transact)
src/validate.js     strict validators
src/week.js         ISO-week helpers
src/league.js       pure league logic (rankStandings, resolveWeek)
src/rateLimit.js    token bucket
src/auth.js         token generation/hashing/verification
src/http.js         HttpError, envelope, JSON + bounded body reading
test/*.test.js      node:test suites (unit + HTTP integration on ephemeral ports)
```

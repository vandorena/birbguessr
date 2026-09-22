# birbguessr

Rails 8.1 on PostgreSQL, with Pundit (authorization), Flipper (feature flags),
Solid Queue (background jobs) and Blazer (SQL dashboards).

## Getting started

```bash
cp .env.example .env     # then edit the password
docker compose up -d     # Postgres 17 on localhost:5433
bin/rails db:prepare
bin/rails db:seed        # creates the two dev accounts below
bin/dev                  # http://localhost:3000
```

Sign in with `admin@birbguessr.test` / `password123` to reach the dashboards;
`plain@birbguessr.test` is a non-admin for checking the gate.

### Running against a local Postgres instead of Docker

Point the `DATABASE_*` vars in `.env` at your own server — e.g. for Homebrew Postgres:

```
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=<your unix user>
DATABASE_PASSWORD=
BLAZER_DATABASE_URL=postgres://<your unix user>@localhost:5432/birbguessr_development
```

## What's wired up

| Gem | Where |
|---|---|
| **Pundit** | `ApplicationController` includes `Pundit::Authorization`; `pundit_user` maps to `Current.user`, and `Pundit::NotAuthorizedError` redirects back with a flash. Policies live in `app/policies/`. |
| **Flipper** | Backed by Active Record (`flipper_features` / `flipper_gates`). Dashboard at `/flipper`. |
| **Blazer** | Dashboard at `/blazer`; data source comes from `BLAZER_DATABASE_URL` (`config/blazer.yml`). |
| **Solid Queue** | `config/queue.yml`, `bin/jobs`, and a dedicated `queue` database in every environment. |

Authentication is the Rails 8 built-in generator (`User`, `Session`, `Current`), plus a
`users.admin` boolean.

`/flipper` and `/blazer` are mounted behind `AdminConstraint`
(`app/constraints/admin_constraint.rb`), which resolves the signed session cookie in the
routing layer. Non-admins and signed-out visitors get a 404 — the routes do not exist for them.

## Known environment issue: Solid Queue workers on macOS

Solid Queue is installed and enqueues correctly, but **its worker cannot run on this machine**.
The supervisor forks worker processes, and on Ruby 4.0.5 + pg 1.6.3 + macOS, `PG.connect`
segfaults in any forked child once the parent has opened a libpq connection. It reproduces with
no Rails involved:

```ruby
require "pg"
PG.connect(...)                       # parent connects once
fork { PG.connect(...) }              # child segfaults in connect_start
```

Consequences, all deliberate:

- `config/environments/development.rb` uses `config.active_job.queue_adapter = :async`
  (in-process thread pool, no forking). Production still uses `:solid_queue`.
- `SOLID_QUEUE_IN_PUMA` is **not** set in `.env` — it makes Puma boot the forking supervisor,
  which crashes and takes the web server down with it.

Linux (CI, Docker, production) is unaffected. Once the pg/Ruby issue is resolved, switch the
development adapter back to `:solid_queue` and run `bin/jobs`.

## Other pinned dependencies

`Gemfile` pins two gems for reasons worth knowing:

- `json ~> 2.21` — Ruby 4.0 ships json 3.x, but Rails 8.1's `ActiveSupport::JSON.decode`
  calls `JSON.parse(json, options)` with a positional hash, which json 3 rejects.
- `pg` with `force_ruby_platform: true` — builds against the local libpq rather than the
  precompiled binary.

## Tests

```bash
bin/rails test
```

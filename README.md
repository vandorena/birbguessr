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

Then go to `/login` and enter `admin@brown.edu` to reach the dashboards, or
`plain@brown.edu` to check the gate as a non-admin. In development the email is
written to `tmp/mails/<address>` rather than sent — open that file and use either
the link or the code in it. Note the file is **appended to**, so take the last
message in it, not the first.

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
| **Magic-link auth** | Passwordless sign-in restricted to Brown addresses — see below. |
| **Pundit** | `ApplicationController` includes `Pundit::Authorization`; `pundit_user` maps to `Current.user`, and `Pundit::NotAuthorizedError` redirects back with a flash. Policies live in `app/policies/`. |
| **Flipper** | Backed by Active Record (`flipper_features` / `flipper_gates`). Dashboard at `/flipper`. |
| **Blazer** | Dashboard at `/blazer`; data source comes from `BLAZER_DATABASE_URL` (`config/blazer.yml`). |
| **Solid Queue** | `config/queue.yml`, `bin/jobs`, and a dedicated `queue` database in every environment. |

## Signing in

There are no passwords. `/login` takes an email address and sends one message containing
both a **magic link** and a **six-digit code**; either signs you in, and redeeming one
burns the other. Requesting a code for an unknown address creates the account, so this is
the sign-up flow too. Adapted from `are-you-in`'s `LoginCode`.

Only Brown addresses are accepted — `brown.edu` and its subdomains (`alumni.brown.edu`),
matched by an anchored regex so `notbrown.edu` and `brown.edu.attacker.com` are refused
(`User::BROWN_EMAIL_HOST`).

How the two paths differ, and why:

- **The code** is bound to the browser that asked for it, via a signed cookie whose bcrypt
  digest is on the row. A code read out of someone's inbox elsewhere is useless on its own.
  Five wrong guesses burn the row; six digits is only ~20 bits, so that counter and the
  controller rate limits are what make it safe, not the code.
- **The link** carries a ~190-bit token and deliberately has *no* browser binding — mail is
  routinely opened on a different device, which is the entire point. Its entropy is what
  makes that safe.

Both expire in 15 minutes and are single-use. The row stores only digests; the plaintext
exists for one request, inside the email. The mailer is called with `deliver_now`, not
`deliver_later`, because `deliver_later` would persist the plaintext code and token to
`solid_queue_jobs.arguments` and the log.

Sessions and `Current` are the Rails 8 built-ins, plus a `users.admin` boolean.

## Email (Amazon SES)

Mail goes out through SES's SMTP endpoint. Set a region and a pair of **SES SMTP
credentials** — generated in the SES console, *not* an IAM access key pair:

```
SES_REGION=us-east-1
SMTP_USERNAME=...
SMTP_PASSWORD=...
MAIL_FROM=birbguessr <login@yourdomain.com>
```

With `SMTP_USERNAME` unset, development writes to `tmp/mails` and nothing touches the
network. Production can instead put `region` / `user_name` / `password` / `from` under an
`smtp:` key via `bin/rails credentials:edit`, needing no environment variables.

`raise_delivery_errors` is true in every environment on purpose: email *is* the login
mechanism, so a silently dropped message is a total outage.

While SES is in the sandbox, set `MAIL_INTERCEPT_TO` to route every outgoing message to one
verified inbox so no real address can be emailed by accident.

The settings are built in `lib/mail_delivery.rb` as plain functions so they can be unit
tested (`test/lib/mail_delivery_test.rb`) rather than being untestable boot-time code.

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

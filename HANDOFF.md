# Handoff — session of 2026-09-21

Bootstrapped `birbguessr` from an empty git repo to a working Rails 8 app with
passwordless Brown-only sign-in, four supporting gems, and mail through Amazon SES.

Three commits, all on `main`:

| | |
|---|---|
| `2769bbd` | Initialise Rails 8 app with Pundit, Flipper, Solid Queue and Blazer |
| `0a74cab` | Replace password auth with Brown-only magic-link sign-in over SES |
| `7820409` | Add `mail:config` / `mail:test` rake tasks |

## What exists

Rails 8.1.3.1, PostgreSQL 17 (Docker), Tailwind + importmap, Minitest. 44 tests
passing, rubocop clean, `zeitwerk:check` clean.

| Gem | Where it lives |
|---|---|
| **Pundit** | `ApplicationController` includes `Pundit::Authorization`; `pundit_user` → `Current.user`; `NotAuthorizedError` redirects back with a flash. Policies in `app/policies/`. |
| **Flipper** | Active Record adapter (self-registering), UI at `/flipper`. |
| **Blazer** | UI at `/blazer`, data source from `BLAZER_DATABASE_URL`. |
| **Solid Queue** | Dedicated `queue` database in every environment. See the caveat below. |

`/flipper` and `/blazer` mount behind `AdminConstraint`
(`app/constraints/admin_constraint.rb`), which resolves the signed session cookie in
the routing layer. Non-admins and signed-out visitors get a **404** — the routes do
not exist for them. Verified for all three cases.

## Sign-in

No passwords. `/login` takes an email address and sends one message containing both a
**magic link** and a **six-digit code**; either signs you in, and redeeming one burns
the other. An unknown address creates the account, so this is also the sign-up flow.
Adapted from the sibling `are-you-in` project's `LoginCode`, taking only the
passwordless flow and the school-address check — not its onboarding, roles, soft
delete or PaperTrail.

The two paths are **deliberately asymmetric**:

- The **code** is bound to the browser that asked for it (signed cookie, bcrypt digest
  on the row). Six digits is ~20 bits, so a code read out of someone's inbox elsewhere
  must not be enough on its own. Five wrong guesses burn the row.
- The **link** carries ~190 bits and has **no** browser binding, because mail is
  routinely opened on another device. Its entropy is what makes that safe.

Both expire in 15 minutes, are single-use, and are stored only as digests. `LoginMailer`
uses `deliver_now`, not `deliver_later` — the latter would persist the plaintext code and
token to `solid_queue_jobs.arguments` and the ActiveJob log.

Sign-up is limited to `brown.edu` and its subdomains by an anchored regex
(`User::BROWN_EMAIL_HOST`), so `notbrown.edu` and `brown.edu.attacker.com` are refused.
Plus-addressed variants (`alexvd+test1@brown.edu`) pass.

## Email (Amazon SES)

Sent through SES's SMTP endpoint; the host is derived from `SES_REGION`. Settings are
built in `lib/mail_delivery.rb` as plain functions so they are unit tested
(`test/lib/mail_delivery_test.rb`) rather than untestable boot-time code.

Current account state (read from the SES console this session):

- Region **us-east-2**, **production access granted** — 50,000/day, 14/sec. No recipient
  verification needed, so any `@brown.edu` address can receive mail.
- Domain identity `staging.alexvd.dev` verified, Easy DKIM 2048-bit successful, custom
  MAIL FROM `mail.staging.alexvd.dev`.
- `MAIL_FROM` is set to `birbguessr <login@staging.alexvd.dev>` — the `From:` header, which
  is distinct from the custom MAIL FROM (envelope/Return-Path) domain.

```bash
bin/rails mail:config                       # show delivery method, host, sender
bin/rails 'mail:test[you@brown.edu]'        # send a real message
```

## Open items

1. **Untested end to end against real SES.** `bin/rails mail:test` has never been run
   with live credentials. That is the next step.
2. **No safety net on outbound mail.** The account is out of the sandbox, so development
   will email any real Brown address someone types at `/login`. Consider setting
   `MAIL_INTERCEPT_TO=alexvd+ses@brown.edu` while testing — every message then goes to
   that inbox with the intended recipient preserved in the subject.
3. **Check SES for bounces.** See "What went wrong" below.
4. `AdminConstraint` is the only authorization actually in use; Pundit is wired up but has
   no policies beyond the generated `ApplicationPolicy`.

## Known environment issue: Solid Queue workers

Solid Queue is installed and enqueues correctly, but **its worker cannot run on this
machine**. The supervisor forks workers, and on Ruby 4.0.5 + pg 1.6.3 + macOS,
`PG.connect` segfaults in any forked child once the parent has opened a libpq connection.
Reproducible with no Rails involved:

```ruby
require "pg"
PG.connect(...)            # parent connects once
fork { PG.connect(...) }   # child segfaults in connect_start
```

Neither `force_ruby_platform` on `pg`, a numeric host, nor
`OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` fixes it (the last one clears the ObjC abort but
the segfault remains once the parent has connected). Consequences, all deliberate:

- `development.rb` uses `queue_adapter = :async`. Production stays `:solid_queue`.
- `SOLID_QUEUE_IN_PUMA` is **not** set — it makes Puma boot the forking supervisor, which
  crashes and takes the web server down with it.

Linux (CI, Docker, production) is unaffected. Ruby 3.x was not tested — only 4.0.5 is
installed. Revert by swapping the development adapter back to `:solid_queue`.

## Pinned dependencies

- `json ~> 2.21` — Ruby 4.0 ships json 3.x, but Rails 8.1's `ActiveSupport::JSON.decode`
  calls `JSON.parse(json, options)` with a positional hash, which json 3 rejects. This
  broke Solid Queue job deserialization.
- `pg` with `force_ruby_platform: true` — builds against the local libpq. Kept after the
  fork investigation even though it did not fix that particular problem.

## What went wrong this session

Worth knowing about, because two of these have lingering consequences.

1. **`.env.example` was never committed.** Rails' default `/.env*` rule swallowed it and
   `git add -A` skipped it silently. The README told people to `cp .env.example .env`, for
   a file that did not exist in the repo. An earlier summary claimed it was committed —
   that was wrong. Fixed by adding `!/.env.example`.

2. **The test suite attempted live SES sends.** `config/initializers/mail_delivery.rb`
   overrode `test.rb`'s `delivery_method = :test` whenever SMTP settings were present, and
   dotenv loads `.env` in test too. The moment real SES credentials were added, the suite
   switched to `:smtp` and tried to deliver to the fabricated fixture addresses
   (`newbie@brown.edu`, `member@brown.edu`, `dupe@brown.edu`). Since the account is out of
   the sandbox, SES would have accepted those and bounced them off Brown's mail server.
   **Check the SES account dashboard for bounce rate before sending anything else** — a
   spike in bounces to a single real domain is exactly what damages sender reputation.
   Fixed by guarding the whole initializer block on `Rails.env.test?`, with a regression
   test asserting `delivery_method == :test`.

3. Docker Desktop was installed but not running for most of the session; the Homebrew
   `docker` CLI also shadowed Desktop's, hiding the compose plugin. Both resolved.

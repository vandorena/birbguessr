# CLAUDE.md

## Build & test commands

| Task | Command |
| --- | --- |
| Run all tests | `bin/rails test` |
| Lint & fix | `bin/rubocop -a` |
| Everything CI runs | `bin/ci` (see `config/ci.rb`) |
| Start dev server | `bin/dev` (foreman: Puma + `dartsass:watch`) |
| Database setup | `bin/rails db:prepare` |

`bin/ci` is the local gate, and it is wider than the test suite: rubocop,
`bundler-audit`, `importmap audit`, brakeman, `bin/rails test`, and
`db:seed:replant`. That last step means `db/seeds.rb` has to stay runnable and
idempotent — a seed referencing a column you just renamed fails there and
nowhere else.

**`.github/workflows/ci.yml` is the gate that blocks a PR**, and it is a superset
of `bin/ci`: the same lint, security and test steps split into parallel jobs,
plus a `database` job that `bin/ci` does not attempt. Keep the two in step — if
you add a step to one, consider whether the other wants it.

The `database` job runs migrations from scratch against an empty Postgres 18 and
then fails if `git diff` is dirty. That single check catches four things:

- a migration `strong_migrations` would refuse
- `db/schema.rb` uncommitted, or hand-edited
- a stale checked-in `== Schema Information` annotation
- a migration that only works against a database that already has data in it

It runs in the **development** environment on purpose, because only development
dumps `schema.rb` after migrating and only development loads `annotaterb`. It
also loads `schema.rb` on its own into a second database, since production
deploys load the schema rather than replaying migration history.

## Architecture & structure

- **Framework:** Ruby on Rails 8.1.
- **Database:** PostgreSQL, with `solid_queue` for background jobs.
- **Caching:** Redis (`redis_cache_store`) in production, `memory_store` in
  development.
- **Asset pipeline:** `propshaft`, with `dartsass-rails` compiling SCSS into
  `app/assets/builds/`. `assets:precompile` runs the Sass build automatically.
- **Deployment:** Coolify (Docker-based). **Not Kamal** — ignore the Kamal
  config that ships with a new Rails app.

Key gems and what they own, all installed:

- **`pundit`** — authorization. Every controller action authorizes against a
  policy in `app/policies/`. Headless policies are fine for things that have no
  record — see `AdminToolPolicy`, which gates the mounted admin tools on
  `user.admin?`.
- **`aasm`** — state machines for lifecycle columns. Declare states and the
  events between them on the model, so `record.accept!` either transitions or
  raises `AASM::InvalidTransition`. Use it instead of a `status` string that
  every caller compares by hand. Any AASM column belongs in that model's
  PaperTrail `only:` list.

- **`paper_trail`** — versioning, opt-in per column. Read the section below
  before adding a model; the rules there are not the gem's defaults.
- **`flipper`** — feature flags, stored in Postgres via
  `flipper-active_record`. Wrap unfinished or risky work in
  `Flipper.enabled?(:some_feature, current_user)` so it ships dark and gets
  turned on per user or percentage. The editor is mounted at
  `/admin/flipper`.
- **`view_component`** — encapsulated view objects in `app/components/`. A
  component is a Ruby class plus a template, with a real constructor, so
  required arguments fail loudly and view logic is unit-testable
  (`render_inline`). Reach for one over a new partial when there is any logic
  or more than one caller. One component owns one BEM block.
- **`blazer`** — business intelligence. Saved SQL queries, charts, dashboards
  and scheduled checks, for answering "how many people actually turned up" and
  similar without a one-off script. Mounted at `/admin/blazer`.
- **`strong_migrations`** — refuses migrations that would lock a table or break
  running code. See the migrations section below; it changes how you write
  `add_index` and `add_reference`.

### The mounted admin tools

`/admin/blazer` and `/admin/flipper` are admin-only, gated two different ways
because they are two different kinds of thing:

- **Blazer** renders through `ApplicationController`, so it uses
  `before_action_method: require_admin` in `config/blazer.yml`. Note that
  `Blazer::BaseController` skips *every* inherited callback — `resume_session`
  included — which is why `require_admin` re-establishes the session itself
  before authorizing. Non-admins get 403.
- **Flipper UI** is a bare Rack app that never reaches a controller, so Pundit
  cannot run. It is wrapped in `AdminConstraint` in `config/routes.rb` instead.
  Non-admins get a 404: the flag editor's existence is not worth confirming.

Blazer runs arbitrary SQL against whatever user its data source connects as,
and the schema includes `users` and `versions` — so old emails and phone
numbers are reachable through it. Point `BLAZER_DATABASE_URL` at a **read-only**
Postgres user in production. Blazer's own `audit: true` records who ran which
query.

## Code style & conventions

**Style:** `rubocop-rails-omakase` defaults. Run `bin/rubocop -a` rather than
hand-formatting.

**Testing:** Minitest, the Rails default. **Do not use RSpec.** Test data comes
from fixtures in `test/fixtures/`.

**Frontend:**

- **JS: `importmap-rails`, no build step.** Pin dependencies in
  `config/importmap.rb` via `bin/importmap pin`; the browser resolves the
  import map itself. There is no `package.json` and no Node — do not introduce
  either, and do not reach for an npm package that only works bundled.
- **CSS: `dartsass-rails`.** `app/assets/stylesheets/application.scss` is the
  entrypoint; it compiles to `app/assets/builds/application.css`, which
  `propshaft` digests and serves. `app/assets/builds/` is gitignored and
  `app/assets/stylesheets/` is excluded from the propshaft load path, so raw
  `.scss` never ships.
- Add styles as partials (`_name.scss`) and `@use` them from the entrypoint.
- Stimulus controllers go in `app/javascript/controllers`.
- Write SCSS in [BEM](https://getbem.com/introduction/) —
  `.block__element--modifier`.
- Use CSS classes, never raw `style=` attributes.
- Reach for an existing component or partial before writing a new one.

**Security:**

- Encrypted fields use `lockbox`, with `blind_index` when the column has to be
  searchable. **Neither gem is installed yet** — add them with the first field
  that needs encrypting.
- Every controller action needs a Pundit policy applied. No exceptions for
  "internal" pages.

**Admin surfaces:** any change or addition on the admin side needs PaperTrail
coverage *and* an audit log that a human can actually read in the UI. Writing
the version rows without a way to view them does not count as done.

## Generators and migrations

**Bias toward Rails generators when creating a file** — `bin/rails g model`,
`bin/rails g migration`, and friends. This matters most for migrations: always
generate them with `bin/rails generate migration`, never hand-write the file.
Hand-written migrations tend to get the timestamp or the syntax subtly wrong.

**Always ask the user before running a migration.** Generating the file is
fine; applying it to a database is not, until they say so.

### `strong_migrations` will refuse unsafe migrations

`strong_migrations` runs on every `db:migrate` and raises before touching the
database, with the safe rewrite in the error. Do not work around it — the whole
point is that the safe form is the one that gets written. Config and reasoning
live in `config/initializers/strong_migrations.rb`.

The three it catches most here:

| Instead of | Write |
| --- | --- |
| `add_index :t, :c` | `disable_ddl_transaction!` + `add_index :t, :c, algorithm: :concurrently` |
| `add_reference :t, :r, foreign_key: true` | `add_reference` without the FK, then `add_foreign_key ..., validate: false` and `validate_foreign_key` in a **second** migration |
| `rename_column` / `rename_table` | Add the new column, write both, backfill, then drop — a rename breaks the running app between deploy and restart |

`StrongMigrations.start_after` marks everything up to `20260822141542` as
already-applied. Every migration before that line **would** fail these checks,
so do not copy their style — they predate the gem and ran against a database
with one user in it.

`safe_by_default` is deliberately **off**: it would silently rewrite
`add_index` into a concurrent one, and this codebase prefers the migration to
say what it does. If a check is genuinely wrong for a case, `safety_assured { }`
is the escape hatch — with a comment saying why.

`target_version` must match the **oldest** Postgres this deploys against.
Setting it higher than production silently skips checks.

## Maintainability

Write no unnecessary code and no dead code. If a change strands something —
an unused method, a partial nothing renders, a leftover branch — delete it in
the same change.

## PaperTrail: which columns get versioned

Versioning here is **opt-in per column**, not per model. Get this wrong and you
either lose the audit trail that matters or copy credentials into a table that
outlives them.

### The rule

Two questions decide it, in this order:

1. **Is the column a credential, or derived from one?** Then it is never
   versioned. Not "versioned but encrypted" — not versioned.
2. **Would you ever need to answer "who changed this, and when?"** Then version
   it. Otherwise leave it out.

Everything else — timestamps, counters, last-seen bookkeeping — stays out. A
version row per page view is noise that buries the rows you actually want.

### What that produces today

`app/models/user.rb`:

```ruby
has_paper_trail on: [ :create, :update ],
                only: [ :email, :phone_number, :roles, :deleted_at ]
```

`roles` is the reason this exists at all: it is the one column with real blast
radius, and "who made this person an admin" is the question you will actually
be asked. `deleted_at` is tracked so soft deletes appear in the history —
because `destroy` is a soft delete here (see below), a discard is just an
`UPDATE` and would otherwise be silent.

**`LoginCode` and `Session` are deliberately not versioned at all.** Both hold
credential digests. Versioning them would copy live login codes and session
tokens into `versions`, where they would sit long after the 15-minute
expiry that is supposed to bound their usefulness. `test/models/versioning_test.rb`
asserts this stays true.

### Adding a model to the audit trail

Name the columns explicitly. Do not add a bare `has_paper_trail`:

```ruby
# Good — you chose these.
has_paper_trail on: [ :create, :update ], only: [ :status, :starts_at ]

# Bad — tracks every column, including any credential added later.
has_paper_trail
```

The `only:` list is what makes this safe over time. A bare `has_paper_trail`
silently starts versioning whatever column someone adds next year, and nobody
reviewing that migration will think about the audit log.

`on: [ :create, :update ]` also omits `:destroy` on purpose. A destroy version
snapshots the **entire** record, which is the worst case for retaining personal
data. It is also redundant here, since deletes are soft.

### Column types in the `versions` table

`db/migrate/20260814024856_create_versions.rb` diverges from the gem's
generated migration in two ways, both intentional:

- `object` and `object_changes` are **`jsonb`**, not `text`. The gem defaults to
  text. jsonb means the history is queryable — see the next section for how.
- `whodunnit` is **`bigint`**, not `string`. It holds a `users.id`, so it joins
  cleanly and reads back as an Integer. Note this when asserting on it —
  `version.whodunnit` is `42`, not `"42"`.

### Querying jsonb: use `jsonb_exists`, not `?`

Postgres spells "does this key exist" as the `?` operator, which collides with
ActiveRecord's bind placeholder. The bare form works **only** while the query
has no bind values, so it passes in the console and then breaks the moment
someone adds a condition:

```ruby
# Works — no binds in the query.
scope.where("object_changes ? 'roles'")

# Raises ActiveRecord::PreparedStatementInvalid — the `?` is now a placeholder.
scope.where("object_changes ? 'roles' AND event = ?", "update")
```

Use the function form, which takes the key as an ordinary bind and never
breaks:

```ruby
PaperTrail::Version
  .where(item_type: "User", item_id: user.id)
  .where("jsonb_exists(object_changes, ?)", "roles")
```

`object_changes ->> ? IS NOT NULL` also works if you prefer it. Note that `??`
is **not** an escape here — Rails 8.1 passes it straight through and Postgres
rejects it as an unknown operator.

### Things that produce no version at all

These bypass callbacks, so PaperTrail never sees them. This is not a bug to fix;
it is a limit to know:

- `update_columns`, `update_all`, `delete_all`, `upsert_all`, `increment!`
- `Session#touch_last_seen!` uses `update_columns` on purpose — it fires on
  ordinary page views and must stay cheap. Sessions are not versioned anyway.

Never assume "every change has a version." Assume "every change through
`save`/`update` to a listed column has a version."

### whodunnit

Set automatically from `current_user` — PaperTrail's `user_for_paper_trail`
picks up the `current_user` defined in `app/controllers/concerns/authentication.rb`,
and no controller code is needed.

**Background jobs and console sessions are not covered.** They record `nil`.
If a job changes a versioned column, set it yourself:

```ruby
PaperTrail.request(whodunnit: acting_user.id) { record.update!(...) }
```

## Related: soft deletes

`destroy` does not delete. `SoftDeletable` routes it to Discard's `discard`,
setting `deleted_at`. `destroy_permanently!` is the escape hatch.

This interacts with the audit trail in one way worth stating plainly: **rows and
their version history both persist forever.** Old emails and phone numbers stay
in `versions` even after a user is discarded, so "delete my account" currently
removes nothing. That is a deliberate choice, not an oversight — but any
retention or erasure requirement has to clear two places, `users` and
`versions`.

There is no `default_scope`. Query `.kept` explicitly.


## Commiting + Pushing

Always commit with a short commit message, at most 10 words. Never include yourself as a Coauthor onto any commit messages.
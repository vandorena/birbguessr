# Handoff — session of 2026-09-22

Implemented the two Figma frames (birb show, gallery), made the gallery the landing
page, and tightened the login throttles. **Nothing is committed** — the whole session
is in the working tree.

The previous handoff is archived at `HANDOFF-2026-09-21.md`. Its environment notes
(Solid Queue fork bug, pinned deps, SES account state) are still true; one claim in it
is now false, see "Superseded" at the bottom.

105 tests passing, rubocop clean. **`bin/ci` was not run** — see open items.

## What changed

| Area | Files |
|---|---|
| Show page (split view) | `_birb-split.scss`, `birb_split_controller.js`, `birbs/show.html.erb`, `birbs/_map.html.erb` |
| Gallery | `_birb-index.scss`, `birbs/index.html.erb` |
| Shared chrome | `_paper.scss`, `_flash.scss`, `_typography.scss`, `_tokens.scss`, `_utilities.scss` |
| Landing page + auth | `config/routes.rb`, `birbs_controller.rb`, `birb_policy.rb`, deleted `HomeController` |
| Login throttling | `logins_controller.rb`, `user.rb` |
| Test infrastructure | `config/environments/test.rb`, `test/test_helper.rb` |

New assets: `app/assets/fonts/bluebird.regular.ttf`, `app/assets/images/birbs/birb-mark.png`,
`app/assets/images/birbs/home-button.svg`. New helper: `ApplicationHelper#inline_svg`.

## The show page

Photo on the left, campus map on the right, a slider on the seam. **One rule the whole
block turns on: moving the slider resizes nothing.**

- The map fills the entire viewport and is **clipped** with
  `clip-path: inset(0 0 0 var(--birb-split))`. Dragging left uncovers map that was
  always drawn. Animating a width instead would restart Leaflet's tile maths every
  frame — it works out which tiles to fetch from its container's size.
- `clip-path` clips hit-testing as well as paint, so the covered strip stops taking
  guess clicks.
- The clip is on the Leaflet container itself, not a wrapper, so the guess button —
  a sibling inside the same Stimulus element — cannot be clipped away.
- Bounds are **asymmetric**: left to 0 (map covers the photo), right only as far as
  the opening position. The photo is never given more room than it was drawn with, so
  no state shows pink through the seam.
- `--birb-split-start` is authored in CSS as a percentage; `connect()` resolves it to
  pixels rather than measuring the handle, because Turbo restores a cached page with
  whatever inline `--birb-split` the last drag wrote.

**Map panning is now free.** `maxBounds` + `maxBoundsViscosity: 1.0` were removed:
that pair does not prevent a pan, it allows one and then yanks the view back on
release. `fitBounds` still frames campus. Consequence: you can pan off campus and drop
a pin there — the button enables, and `Guess#must_be_on_campus` rejects it on submit.
That validation is now the *only* fence, not a backstop.

## Chrome: the two buttons and the slider

Final state after a lot of iteration. Worth reading before changing any of it.

| | Hover | Press | Focus |
|---|---|---|---|
| Home button | scale 1.08, drop-shadow, both pinks darken | scale 0.94 | outline |
| Guess button | underline only | scale 0.94 | outline |
| Slider | *nothing* | grip scales 0.92 | grip deepens, **no outline** |

- The **guess button is a `form.button`, not `form.submit`**. An `<input>` has no text
  node and several browsers ignore `text-decoration` on one, so the hover underline
  would simply not appear. `name: nil` drops the `name="button"` param Rails sends.
- The slider's `outline: none` has to be stated: it is a `<button>`, so the browser
  draws its own ring otherwise.
- The slider press scales **the grip only**. The bar *is* the seam and sits exactly on
  the map's clip edge; scaling it would open a gap down the middle of the page. It
  stays pressed for the whole drag because `startDrag` captures the pointer.
- The home button is **inlined** rather than `image_tag`'d (`ApplicationHelper#inline_svg`)
  so CSS can reach the `<rect>` inside it and darken it on hover. `fill`/`stroke` as CSS
  properties beat the presentation attributes in the file.
- `--colour-ink: #674848` (5.5:1 on pink) is the text colour everywhere. The design's
  `--colour-pink-deep` is a *shape* colour — 1.27:1 against the ground, fine for the
  home icon's 3.56px stroke, unreadable behind a word.

## The gallery, and the ruled sheet

Wordmark in **BlueBird**, the birb mark beside it, cards at 251×334 with the two
translucent pills.

- The font file is named `.ttf` but its sfnt tag is `OTTO` — CFF outlines, i.e.
  OpenType. `@font-face` declares `format("opentype")`; `format("truetype")` is a lie a
  browser may act on by discarding the face. Internal family name is `BlueBird`.
- It had to move to `app/assets/fonts/`. Propshaft's load path is the *subdirectories*
  of `app/assets`, not `app/assets` itself — at the top level it would never have been
  served. Verified the built CSS resolves to `/assets/bluebird.regular-<digest>.ttf`.
- `birb-mark.png` was keyed out of an Instagram JPEG with a flat brown ground. No
  ImageMagick/vips/Pillow on this machine, so: `sips` → BMP → pure Python → PNG.
  Flood-filled from the edges (not a global key), soft alpha at the boundary, then
  **colour un-mixing** `C = (P − (1−a)B) / a` on partial pixels — without that you get
  a brown halo that only shows once it is over the pink page. Verified by compositing
  over `#f7c9c9` and counting brown fringe pixels: zero.

**The sheet is generated, not drawn.** `.page` (the `<body>`) carries two repeating
gradients: the ruling, and the left margin rule. This replaced two SVG artboards, and
the history matters because the naive versions are both wrong:

- Stretching a fixed-height artboard to the window **scales the 44px pitch with it**.
  The design's two layers are offset a flat 22px, which is half a pitch only at its
  own 832px height — at 1080px the gaps alternated 22.0 / 35.6.
- Tiling one instead puts a jog at every seam: 44 does not divide 803.

Gradients are exact at 11px/44px at any size and extend as far as the document goes,
which is what lets the landing page scroll. The ruling now reads *finer* on a tall
window than it used to — that is the design's actual pitch. Both `lines*.svg` are
deleted.

`.page` also sets `margin: 0`: there is no CSS reset in this app and the gallery was
sitting 8px off the corner.

## Landing page and auth

`root "birbs#index"`. The gallery renders signed out (`allow_unauthenticated_access
only: :index`, `BirbPolicy#index?` is `true`). Opening a birb still requires a session,
and `request_authentication` already stored the URL — so clicking a birb signs you in
and returns you to *that birb*. There is a test asserting the exact URL is stored.

**The subtle bit:** skipping the auth requirement also skips resuming the session, so
`Current.user` would be nil in `index` even for a signed-in visitor. The page would
still render — just with no pill and no guessed-birb marks. Hence the explicit
`before_action :resume_session, only: :index`.

`HomeController`, its view and its test are deleted (nothing routed to it). That
stranded sign-out, which lived only on that page, so the "Signed in" pill carries a
small sign-out link.

## Login throttling and aliases

Three named limits on `LoginsController`:

| Name | Limit | Keyed by |
|---|---|---|
| `login-email` | 5 / 15 min | canonical mailbox (was: address as typed) |
| `login-ip` | 30 / hour | `request.remote_ip` — **new** |
| `code-attempts` | 20 / 15 min | `request.remote_ip` |

**All three must keep their `name:`.** Rails keys a limit on `[scope, name, by]` and
scope defaults to the controller path, so the two IP-keyed limits would otherwise share
a bucket: 21 code requests would push the code-attempt counter past 20 and lock a
visitor out of typing a code they never typed. There is a test for exactly that, and it
fails if the names are removed (verified both directions).

`User.normalize_address` drops the `+tag`, so one mailbox is one account — which
matters because a guess is unique per user per birb, so a second account is a second
guess on every birb. `User::ALIASES_ALLOWED_FOR = ["alexvd@brown.edu"]` is exempt and
keeps its aliases apart. Rails applies `normalizes` to finder arguments, so `find_by`
and `find_or_create_by` resolve an alias to the existing row.

**Only the `+tag` is folded.** Dots are not (a Gmail convention; at Brown `j.smith@`
and `jsmith@` are two people) and neither is the host (`brown.edu` and
`alumni.brown.edu` are separate mail domains). Folding either would merge two real
mailboxes into one account.

## Test environment

`config.cache_store` in test was `:null_store`. `rate_limit` counts through the cache,
so **every throttle in the app was silently inert in the suite** — untestable, and any
break would have passed. It is `:memory_store` now, with `Rails.cache.clear` in
`test_helper` setup so counters do not leak between tests.

## Open items

1. **Nothing has been verified visually.** There is no `test/system`, no browser driver,
   and no screenshots were taken this session. Every design claim above is read off the
   compiled CSS against the Figma render. This is the biggest gap — run `bin/dev` and
   look at both pages before trusting any of it. Mobile (<700px) layouts especially:
   they are written but have never been rendered.
2. **`bin/ci` was not run.** Only `bin/rubocop -a` and `bin/rails test`. Brakeman,
   bundler-audit, importmap audit and `db:seed:replant` are unexercised against these
   changes — the seeds in particular, since `HomeController` was deleted.
3. **No visible way to sign in when signed out** except clicking a birb. `/login` is
   reachable directly. Deliberate, per the spec given, but worth a second look.
4. **Subdomain aliases are still separate accounts.** `you@brown.edu` and
   `you@alumni.brown.edu` are two players. That is a policy call, not an oversight.
5. **The rate-limit numbers are guesses.** 30/hour per IP is chosen against a shared
   campus NAT — a dorm signing in after a launch arrives from one address. The failure
   mode is a locked-out building, so turn it up if real traffic trips it.
6. **`birb-mark.png` provenance.** Sourced from an Instagram profile picture. Confirm
   the rights before this ships publicly.
7. **Off-campus pins are now reachable.** Panning is free, so a player can drop a pin
   off campus and only find out on submit. Catching it at click time in
   `birb_map_controller#place` would be kinder.
8. **Two additions are not in the Figma frames**, both flagged at the time: the guess
   submit button (the frame has none, and the game is unplayable without it) and the
   "Post a birb" link (the only route to `/birbs/new`). The guessed/not-guessed state is
   `u-visually-hidden` rather than drawn, for the same reason.

## Superseded

`HANDOFF-2026-09-21.md` says "Plus-addressed variants (`alexvd+test1@brown.edu`) pass."
They still pass validation, but they no longer create separate accounts — they collapse
onto the mailbox, except for the one address in `User::ALIASES_ALLOWED_FOR`.

## Commands

```bash
bin/dev                       # Puma + dartsass:watch
bin/rails test
bin/rubocop -a
bin/ci                        # the local gate; not run this session
bin/rails dartsass:build      # after editing .scss without bin/dev running
```

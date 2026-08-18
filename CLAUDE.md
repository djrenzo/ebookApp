# Ebookify / LibraryCheckoutManager

A personal SwiftUI iOS app that lets one library patron browse, search, check out,
and download ebooks from their public library's Odilo-based catalog, then hand
the downloaded EPUBs off to Apple Books to read.

The Xcode project name is `LibraryCheckoutManager`; the shipped app name is
"Ebookify" (see `build-ios.yml`'s `app_name` input). Both names refer to the
same app.

Deeper reference docs, read on demand:

- **[docs/architecture.md](docs/architecture.md)** — code layout, key patterns, build system.
- **[docs/odilo-api.md](docs/odilo-api.md)** — the reverse-engineered library API this app talks to.
- **[docs/auth-flow.md](docs/auth-flow.md)** — the full login flow, step by step, with what's confirmed vs. still unknown.

## Quick orientation

- **Backend**: `onlinebibliotheek.odilotk.es` — an Odilo-platform library
  catalog, fronted by KB (Koninklijke Bibliotheek / Dutch national library)
  SSO for patron login. None of this is a documented public API; everything
  this app does was reverse-engineered by proxy-capturing the official
  "Bibliotheek" app's traffic (`com.odilo.bibliotheek`) and replicating it.
  See `docs/odilo-api.md` for the full endpoint reference.
- **Auth model**: two independent tiers — an app-level Bearer token (static
  client credentials, no user interaction) and a per-patron token (real KB
  login via a system browser sheet). See `docs/auth-flow.md`.
- **No hardcoded secrets**: `LibraryCredentials` has no seeded/fallback
  value. There's nothing to log in with until `LibraryAuthService.login()`
  succeeds. If you're tempted to add a "seed" convenience value back for
  testing, don't — that was a real security issue in an earlier version of
  this app (a live session token was committed to git) and got deliberately
  removed.
- **Project generation**: `project.yml` (XcodeGen) is the source of truth
  for the Xcode project — `LibraryCheckoutManager.xcodeproj` is generated
  from it (`xcodegen generate`, run in CI). Edit `project.yml`, not the
  `.xcodeproj` directly.
- **Build/release**: `.github/workflows/build-ios.yml` renders
  `public/icon.svg` into the app icon, runs `xcodegen generate`, archives
  unsigned, packages an IPA, and cuts a GitHub Release. It's
  `workflow_dispatch`-triggered (manual), not run on every push.

## Working in this repo

- This is a single-target iOS app (`LibraryCheckoutManager`, iOS 17+,
  SwiftUI, Swift 6 strict concurrency). There's no test target and no
  Linux/CI build step that runs the app — verifying changes requires a real
  Xcode build on macOS, which isn't available in every environment. Say so
  explicitly rather than claiming something works when it's only been read,
  not compiled.
- Networking code favors replicating captured requests *exactly*
  (headers, body shape, even quirks like a mismatched `Content-Type` on a
  form-encoded body) over "cleaning them up" — the API isn't documented
  anywhere else, so the captured traffic is the spec. Don't
  "simplify" a header or param away without understanding why it's there;
  check `docs/odilo-api.md` first.
- Session cookies (`JSESSIONID`, `AWSALB`, `AWSALBCORS`) are **not** tracked
  as fields anywhere in the codebase — they're handled by
  `URLSession.shared`'s cookie jar automatically. No method should ever go
  back to building a `Cookie` header by hand from stored values; if a new
  endpoint seems to need one, it almost certainly doesn't — the jar already
  has it from an earlier response on the same session.

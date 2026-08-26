# Odilo library API reference

Reverse-engineered from proxy-capturing the official "Bibliotheek" app
(`com.odilo.bibliotheek`, User-Agent `KB_PROD/...`) — nothing here is from
official documentation, because there isn't any public documentation for
this API. Every endpoint below was confirmed against a real captured
request/response before being implemented; nothing was guessed into the
codebase without a matching capture. Where something is inferred rather
than confirmed, it's called out explicitly.

Host: `onlinebibliotheek.odilotk.es`. All requests are HTTPS.

Example values below are placeholders (`<...>`) — the real captures this
was built from included live session tokens and personal account data that
deliberately aren't reproduced here.

## Auth model, in short

Two independent tiers of credentials, layered:

1. **App-level Bearer token** — identifies the *app*, not the user. Obtained
   via static client credentials embedded in the app binary (see
   `docs/auth-flow.md` step 1). Sent as `Authorization: Bearer <appToken>`
   on every single request below.
2. **Patron-level token** — identifies the *signed-in patron*. Obtained via
   a real KB SSO login (`docs/auth-flow.md` steps 2–5). Sent as an
   *additional* `OAuth-Token: <patronToken>` header, but only on the one
   mutating endpoint that needs to know who you are: checkout.

Session cookies (`JSESSIONID`, `AWSALB`, `AWSALBCORS`) are set via
`Set-Cookie` on nearly every response and are expected back as `Cookie` on
every subsequent request. In this codebase that's handled entirely by
`URLSession.shared`'s cookie jar — no endpoint below needs its `Cookie`
header built by hand, because every request in `OdiloAPIClient` shares that
one session.

`api-version` header value varies by endpoint and doesn't appear to follow
an obvious pattern (`6` on record detail, `7` everywhere else observed) —
this looks like it's just whatever version each endpoint happened to ship
against, not something to "fix" for consistency.

---

## `POST /opac/api/v2/token/` — app-level token

Exchanges the app's static client credentials for an app-level Bearer
token. Does **not** require a patron to be logged in — this is pure
app/client authentication, independent of any user.

**Request**

```
Authorization: Basic <base64(client_id:client_secret)>
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
```

The client_id/secret pair is a static value embedded in the official app's
binary (extracted via reverse engineering, not personal to any account).
See `OdiloAPIClient.appClientAuthorization` for the actual value used —
intentionally not duplicated here.

**Response**

```json
{ "token": "<hex string>", "type": "Bearer", "expiresIn": 86400 }
```

`expiresIn` is in seconds (86400 = 24h). `Set-Cookie` on this response
seeds `JSESSIONID`/`AWSALB`/`AWSALBCORS` for the whole session.

Implemented as `OdiloAPIClient.fetchAppToken()`.

---

## `GET /opac/api/v2/login/external` — request a KB login URL

Asks Odilo for the URL to open in a browser to run the KB SSO login. Odilo
generates an OAuth `state` value server-side here and binds it to the
calling session (via the `JSESSIONID` cookie from the token call above), so
it can recognize the login later when the resulting code comes back.

**Request**

```
Authorization: Bearer <appToken>
Accept: */*

?callback=<url-encoded callback URI>&client=app&type=OAUTH2
```

`callback` is echoed straight through as the `redirect_uri` in the returned
KB URL — confirmed by testing (the exact string sent came back unchanged,
just re-encoded). This app currently reuses the official app's own
`online.bibliotheek://oauth` scheme (proven to round-trip end to end); using
this app's own custom scheme instead is plausible given the pass-through
behavior, but hasn't been tested against a real response.

**Response** — a bare string (not a JSON object) containing the KB
authorize URL:

```
https://login.kb.nl/si/auth/oauth2.0/v1/authorize?client_id=odiloapp&scope=profile+openid&response_type=code&redirect_uri=<callback>&state=<generated state>
```

Implemented as `OdiloAPIClient.requestExternalLoginURL(callback:appToken:)`.
See `docs/auth-flow.md` for what happens with this URL (steps 2–3).

---

## `POST /opac/api/v2/login/external` — complete the login

Exchanges the authorization `code` (obtained from the KB redirect — see
`docs/auth-flow.md`) for a patron session.

**Request**

```
Authorization: Bearer <appToken>
Content-Type: application/json

{
  "state": "<state from the authorize URL>",
  "scope": "openid profile",
  "iss": "https://login.kb.nl/si/auth/oauth2.0/v1",
  "client_id": "odiloapp",
  "code": "<code from the KB redirect>"
}
```

`scope`/`iss`/`client_id` are constants matching what was used to start the
flow — not extracted from anywhere dynamic, just echoed back.

**Response** — a patron profile plus session tokens:

```json
{
  "id": "<patron id>",
  "name": "<display name>",
  "email": "<email>",
  "session": "<matches the JSESSIONID cookie exactly>",
  "accessToken": "<UUID — this is the OAuth-Token header value>",
  "refreshToken": "<UUID>",
  "expiresIn": 14399,
  ...
}
```

(Response has many more fields — address, locale, various library-account
flags — not reproduced here; only what's actually consumed is listed. See
`OdiloPatronSession` for the exact decoded subset.)

`expiresIn` here is ~4 hours.

Implemented as `OdiloAPIClient.completeExternalLogin(code:state:appToken:)`.

---

## `POST /opac/api/v2/login/external` — refresh the patron session

Same endpoint and URL as "complete the login" above (`?client=app&type=OAUTH2`),
but used to silently renew an existing patron session instead of running the
KB SSO browser flow again. Confirmed via a real capture taken after the
patron token had expired.

**Request**

```
Authorization: Bearer <appToken>
Content-Type: application/json

{ "refresh": "<patronRefreshToken>" }
```

Note this is **not** `grant_type=refresh_token` against the `/token/`
endpoint — that was the leading hypothesis before this was captured, and
it was wrong. The refresh is a different body shape on the *same*
`login/external` endpoint used for the initial code exchange.

**Response** — identical shape to "complete the login," including a
**new** `refreshToken` that replaces the one just spent:

```json
{
  "id": "<patron id>",
  "name": "<display name>",
  "email": "<email>",
  "session": "<matches the JSESSIONID cookie>",
  "accessToken": "<new UUID>",
  "refreshToken": "<new UUID — replaces the one sent in the request>",
  "expiresIn": 14399,
  ...
}
```

The capture this was confirmed from also refreshed the app-level token
immediately beforehand and used that fresh token as this call's
`Authorization`, but nothing suggests the app token needs to be fresh for
this call specifically — every endpoint here just needs *a* valid app
token, per the auth model above.

Implemented as `OdiloAPIClient.refreshPatronSession(refreshToken:appToken:)`,
called from `LibraryAuthService.validCredentials()`.

---

## `GET /opac/api/v2/patrons/{patronId}/checkouts` — list current checkouts

**Request**

```
Authorization: Bearer <appToken>
api-version: 7
Content-Type: application/json
```

**Response** — an array of checkout objects:

```json
[
  {
    "id": "<checkout id>",
    "recordId": "<catalog record id>",
    "title": "...",
    "author": "...",
    "cover": "<cover image URL>",
    "downloadUrl": "<url, present when downloadable>",
    "startTime": 1730000000000,
    "endTime": 1731000000000,
    "returnable": true,
    "expired": false,
    "formats": ["ACSM", "EBOOK_STREAMING", "CB_DOWNLOAD"]
  }
]
```

`startTime`/`endTime` are epoch **milliseconds**. A checkout supports EPUB
download when `formats` contains `"CB_DOWNLOAD"` and `downloadUrl` is
non-null (see `Checkout.supportsDownload`).

A magazine/periodical checkout has a different shape — no `author` at all,
and a `specialFormat` field this app otherwise never sees:

```json
{
  "id": "2054262283",
  "recordId": "00232000",
  "title": "AutoWeek 2026_31",
  "cover": "https://covers.odilo.io/publicms/AutoWeek_2026_31/....jpg",
  "downloadUrl": "https://onlinebibliotheek.odilotk.es/opac/api/v2/checkouts/2054262283/download?patronId=...&token=...",
  "startTime": 1787150195225,
  "endTime": 1788964595225,
  "renewable": false,
  "renewal": false,
  "renewed": false,
  "returnable": true,
  "expired": false,
  "formats": ["EBOOK_STREAMING", "OCS"],
  "displayedOnHistory": false,
  "resourceType": "TIPO_OCS_PDF;TIPO_STREAMING_PDF",
  "specialFormat": "MAGAZINE",
  "originalImageUrl": "https://covers.odilo.io/publicms/AutoWeek_2026_31/...._ORIGINAL.jpg"
}
```

Note `formats` has no `"CB_DOWNLOAD"`, so `supportsDownload` is correctly
`false` — magazines are read via streaming, not the EPUB download flow.
`author` being entirely absent (not `null`, just missing) is why
`Checkout.author` is `String?` rather than `String`: a single non-optional
required field on one array element used to fail the whole
`[Checkout]` decode, which surfaced as "my library won't load" despite a
200 response. `OdiloAPIClient.fetchCheckouts`/`.search` now decode each
array element independently (`decodeLossyArray`) so one unfamiliar record
can no longer take down the rest of the list.

Implemented as `OdiloAPIClient.fetchCheckouts(credentials:)`.

---

## `GET /opac/api/v2/records/` — catalog search

Full-text search across the whole catalog (not just the patron's own
checkouts).

**Request**

```
Authorization: Bearer <appToken>
api-version: 7
Content-Type: application/json

?limit=18&offset=0&order=relevance:desc&limitFacetValues=21&faceted=true
 &lists=true&showExperiences=true&save=true&query=allfields_txt:<search text>
```

`limit`/`offset` are standard pagination — this app pages by incrementing
`offset` by `limit` (18) as the user scrolls. `query` is always prefixed
`allfields_txt:` in front of the raw search text.

**Response**

```json
{
  "total": 7851,
  "records": [
    {
      "id": "...", "title": "...", "subtitle": "...", "author": "...",
      "narrators": ["..."], "coverImageUrl": "...", "formats": ["..."],
      ...
    }
  ],
  "facets": [ ... ]
}
```

`records[]` entries mix ebooks, audiobooks, and reading lists in the same
shape with different fields populated — `formats` containing `"MP3"` or
`"AUDIO_ENCRYPTED"` indicates an audiobook (see `SearchRecord.isAudiobook`).
`facets` is returned but unused by this app.

Implemented as `OdiloAPIClient.search(query:limit:offset:credentials:)`.

---

## `GET /opac/api/v2/records/{id}` — single record detail

Full detail for one catalog record, including a `metadata` field the
search endpoint omits (arbitrary label/value groups — publisher, language,
ISBN, page count, etc., rendered generically rather than modeled field by
field).

**Request**

```
Authorization: Bearer <appToken>
api-version: 6
Content-Type: application/json

?enableMetadata=true
```

Note `api-version: 6` here vs. `7` elsewhere — see the note at the top of
this doc.

**Response** — same base shape as a search record, plus:

```json
{
  "...": "... (same fields as a search record) ...",
  "description": "...",
  "metadata": [
    { "label": "Uitgever", "values": [{ "text": "..." }] },
    { "label": "Publicatiejaar", "values": [{ "text": "2011" }] },
    ...
  ]
}
```

Implemented as `OdiloAPIClient.fetchRecordDetail(id:credentials:)`.

---

## `POST /opac/api/v2/records/{id}/checkout` — check out a book

The one endpoint that needs the **patron** identity, not just the app.

**Request**

```
Authorization: Bearer <appToken>
OAuth-Token: <patronToken>
api-version: 7
Content-Type: application/json          ← header says JSON, but the body below is form-encoded — captured this way, kept as-is

from=SEARCH_SUGGEST&patronId=<patronId>
```

The `Content-Type`/body mismatch is real, not a bug in this app — it's what
the official app actually sends, so it's replicated exactly rather than
"corrected."

**Response**

```json
{
  "id": "<new checkout id>",
  "recordId": "<record id>",
  "downloadUrl": "<url>",
  "startTime": 1730000000000,
  "endTime": 1731000000000,
  "renewable": false,
  "returnable": true,
  "expired": false,
  "formats": ["EBOOK_STREAMING", "CB_DOWNLOAD", "ACSM"]
}
```

Implemented as `OdiloAPIClient.checkout(recordId:credentials:)`. On
success, callers should re-fetch the checkouts list (see
`LibraryViewModel.loadCheckouts()`) — this response doesn't include enough
to update the UI directly (no title/author/cover).

---

## EPUB download (cross-domain redirect)

Downloading uses the `downloadUrl` from a checkout object, with
`&format=CB_DOWNLOAD` appended. The tricky part: the first request 307s to
a *different host* for the actual file, and letting `URLSession` follow
that redirect automatically strips the `Authorization` header on the
cross-host hop (standard, correct URLSession behavior — it won't forward
sensitive headers across origins). So the redirect has to be intercepted
and replayed manually with the header re-attached.

**Request 1**

```
GET <downloadUrl>&format=CB_DOWNLOAD
Authorization: Bearer <appToken>
```

**Response 1** — either the file directly (2xx), or a redirect (3xx) with a
`Location` header pointing at the actual file host.

**Request 2** (only if redirected) — same `GET`, same `Authorization`
header, against the `Location` URL.

Implemented as `OdiloAPIClient.downloadEPUB(for:credentials:)`, using a
`URLSessionTaskDelegate` (`RedirectCapturingDelegate`) that captures
`Location` and returns `nil` from
`urlSession(_:task:willPerformHTTPRedirection:newRequest:)` to prevent
`URLSession` from auto-following it.

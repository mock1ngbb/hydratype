# BROKER-DESIGN — host-side AFM inference broker over the App Group

Slice: **E-SPIKE-1** / hardening **H1**. Date: **2026-07-19**.

This is the design for the **`BROKER_REQUIRED`** path. It becomes the mandated
correction transport for E2 **iff** `README.md`'s verdict lands on
`BROKER_REQUIRED` (the expected outcome per H1). Until the probe runs on
hardware, this is a design on the shelf, not an adopted mechanism.

## Why a broker (and why not XPC)

The keyboard extension is memory-starved (~50–60 MB jetsam ceiling); a ~3B model
cannot live there. The **host app** has a normal app memory budget and can hold
AFM resident. The extension must therefore ask the host to do inference.

**XPC from a keyboard extension to its containing app is NOT reliable** — a
keyboard is not guaranteed a live host process and the connection is not a
supported/stable channel. So the transport is:

- a **shared App Group container** for the request/response payloads (blobs), and
- **Darwin notifications** (`CFNotificationCenterGetDarwinNotifyCenter`) as the
  zero-payload "you've got mail" doorbell in each direction.

Darwin notifications carry **no data** — they are pure signals. All data moves
through files in the shared container. App Group id:
**`group.com.mock1ngbb.hydratype`**.

## The two Darwin notification names

| Direction | Name | Posted by | Observed by |
|---|---|---|---|
| request ready | `com.mock1ngbb.hydratype.broker.request` | keyboard extension | host app |
| response ready | `com.mock1ngbb.hydratype.broker.response` | host app | keyboard extension |

Both register on `CFNotificationCenterGetDarwinNotifyCenter()`. The host app must
have been launched at least once and keep an observer alive (e.g. while
foregrounded, or via whatever background execution it legitimately holds); if the
host is not running, the request simply times out → LOUD fallback (below). The
notification is only a doorbell — the receiver always reads the file to get data
and matches on the request `id`.

## File layout in the shared container

Root: `FileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mock1ngbb.hydratype")`.

```
<AppGroup>/broker/
  requests/<id>.json     # written by extension, read+deleted by host
  responses/<id>.json    # written by host, read+deleted by extension
  tmp/<id>.json          # write-to-tmp then atomic rename into the real dir
```

Writes are **atomic**: write to `tmp/<id>.json`, then `FileManager.replaceItem`
/ rename into `requests|responses/`, so a reader woken by the doorbell never sees
a half-written blob. Reader deletes the file after a successful parse (consume
once). Use `id` = a UUID string; it is the correlation key across the whole
round-trip. On write, set file protection to `.completeUntilFirstUserAuthentication`
so blobs are readable when the device is unlocked but not stored in the clear at rest.

## Blob format (JSON)

**Request** (extension → host):

```json
{
  "id": "9F2C…",           // UUID, correlation key
  "text": "i went to teh stroe",
  "fieldKind": "plain"       // password | url | email | code | plain (HydraCore.FieldKind)
}
```

**Response** (host → extension):

```json
{
  "id": "9F2C…",           // echoes the request id
  "primary": "I went to the store.",
  "alternates": ["I went to the store?", "I went to the store!"],
  "noChange": false,
  "error": null              // non-null string ⇒ host-side failure; extension logs + falls back
}
```

`primary`/`alternates`/`noChange` mirror `HydraCore.CorrectionSuggestion` so the
host can serialize the `@Generable` result straight through. `error` is present
and non-null only on a host-side failure (model unavailable, generation threw);
in that case `primary` is empty and the extension treats it as no-correction —
but LOUDLY (logs the error string), never silently.

## Round-trip protocol

1. Extension computes `id`, writes `requests/<id>.json` atomically.
2. Extension posts Darwin `…broker.request`, starts a timeout timer, and begins
   observing `…broker.response`.
3. Host (observer) wakes, scans `requests/`, reads+deletes the blob, runs AFM
   (resident `LanguageModelSession`), writes `responses/<id>.json` atomically,
   posts `…broker.response`.
4. Extension wakes, reads `responses/<id>.json`, matches `id`, applies the
   correction (or, if `error != null`, falls back). Deletes the response blob.

## Timeout + LOUD failure handling

- **Timeout budget:** `PENDING-HARDWARE` ms (target on the order of a few hundred
  ms warm; must be measured — see README latency table). Pick the deployed value
  from the measured warm latency + margin; do NOT guess it into shipping code.
- **On timeout** (no response blob for `id` before the deadline): the extension
  **falls back to no-correction** (types/keeps the user's raw text unchanged) and
  emits a **structured LOUD log line**, e.g.:

  ```
  os_log(.error, "BROKER timeout id=%{public}@ fieldKind=%{public}@ waited=%dms → fallback=no-correction",
         id, fieldKind, waitedMs)
  ```

- No silent `return nil`, no empty catch: every fallback path (timeout, `error`
  field set, malformed/undeliverable blob) logs a structured line first. Stale
  blobs (id never claimed) are swept on a TTL so the container does not grow.
- The extension NEVER blocks the user's typing on the broker — the raw keystroke
  is always committed immediately; a correction, if it arrives, is applied after.

## Measured-latency placeholder

| Path | Latency | Notes |
|---|---|---|
| Warm round-trip (host AFM resident), 200-token correction | `PENDING-HARDWARE` ms | fill from device run |
| Cold round-trip (host must load AFM) | `PENDING-HARDWARE` ms | worst case, sets timeout margin |
| Doorbell-only latency (empty payload) | `PENDING-HARDWARE` ms | isolates Darwin-notify overhead |
| Timeout fires / 20 requests | `PENDING-HARDWARE` | LOUD-fallback rate |

These come from the same hardware run that resolves the README verdict; this
design is not "done" until they are filled.

## Axiom check

- **Loud:** every fallback (timeout, host `error`, malformed blob) emits a
  structured log line; no silent drop.
- **Zero Local Secrets:** transport is entitlements + App Group files only; no
  keys; the keyboard still never networks.
- **Commodity Intelligence:** host uses `SystemLanguageModel.default`; the blob
  contract is model-agnostic (no model id crosses the boundary).
- **Defer-nothing:** the design is filed now with its measurement gaps named as
  `PENDING-HARDWARE`, not left in prose.

# E-SPIKE-1 — Can the keyboard extension call AFM at all?

Slice: **E-SPIKE-1** (gates E2). Date scaffolded: **2026-07-19**.
Hardening ref: **H1** (AFM in-extension "highly improbable"; fedelm 2026-07-19).

> ## ⚠️ VERDICT: PENDING-HARDWARE — NOT YET DETERMINED ⚠️
>
> **This spike has NOT been run. No verdict exists yet.** The measurement below
> REQUIRES a physical iOS 26 device (or a simulator with Apple Intelligence /
> Foundation Models available) with `Probe.swift` wired into a real keyboard
> extension target. It CANNOT be answered by reading code, by reasoning, or from
> this machine (no device/simulator present here).
>
> **Do not treat the tables below as results.** Every cell reads
> `PENDING-HARDWARE` until someone runs the probe on hardware and fills them in.
> The Done-when for E-SPIKE-1 is NOT satisfied until the Decision line names one
> of `{IN_EXTENSION_OK | BROKER_REQUIRED}` with real memory numbers (and, if
> broker, a measured round-trip latency).

---

## Hypothesis

`LanguageModelSession` (Apple Foundation Models, ~3B params) **cannot** be loaded
and run inside an iOS keyboard extension process, because keyboard extensions are
held to a ~50–60 MB memory jetsam ceiling and the model's working set vastly
exceeds that. fedelm (H1) judged in-process inference "highly improbable."

- **Null / disproven-hypothesis outcome:** the extension loads AFM, gets one
  `CorrectionSuggestion`, and does NOT jetsam → `IN_EXTENSION_OK`.
- **Expected outcome:** `availability` reports unavailable in-extension, OR the
  first `LanguageModelSession` response spikes memory past the ceiling and the OS
  jetsams (kills) the extension → `BROKER_REQUIRED`, and we build the host-side
  inference broker (see `BROKER-DESIGN.md`).

We do NOT assume the answer. The whole point of this spike is to measure it.

---

## Exact measurement procedure

Run `Probe.swift` inside a real **Custom Keyboard Extension** target
(`KeyboardViewController`-style), on a device that has Apple Intelligence /
Foundation Models enabled. On the **first keystroke** (`insertText`), the probe
performs, in order:

1. **Baseline memory.** Read and log `os_proc_available_memory()` (bytes of
   headroom before the extension is jetsammed). This is the LOUD baseline.
2. **Availability check.** Call `SystemLanguageModel.default.availability`. Log
   the case: `.available` / `.unavailable(reason)`. If `.unavailable`, that alone
   is a `BROKER_REQUIRED` signal — record the reason and STOP (no session).
3. **One session + one response.** If available, construct a single
   `LanguageModelSession(instructions:)` and issue exactly one
   `session.respond(to:)` for a fixed prompt (e.g. `"i went to teh stroe"`),
   generating `CorrectionSuggestion` if the shared core type is linked, else a
   plain string. Await the result.
4. **Post memory.** Read and log `os_proc_available_memory()` again immediately
   after the response returns. Compute the delta (headroom consumed).
5. **Jetsam observation.** Record whether the extension survived to log step 4 at
   all. If the extension process is killed before/at model load, the run produces
   NO step-4 line — that absence IS the result (jetsam). Cross-check the device
   Console for a `jetsam`/`memorystatus` / `EXC_RESOURCE (MEMORY)` termination for
   the keyboard process. Note peak memory from the jetsam report if present.

All numbers must be captured from Console.app (subsystem `com.mock1ngbb.hydratype`,
category `afm-spike`) attached to the device, since an extension has no debugger
UI of its own. Repeat 3× to confirm the outcome is stable, not a one-off.

---

## Results (PENDING-HARDWARE — fill from a real device run)

| Metric | Value | Notes |
|---|---|---|
| Device / OS build | `PENDING-HARDWARE` | e.g. iPhone 16 Pro, iOS 26.x |
| Apple Intelligence enabled? | `PENDING-HARDWARE` | Settings → Apple Intelligence |
| `availability` result | `PENDING-HARDWARE` | `.available` / `.unavailable(reason)` |
| Baseline `os_proc_available_memory()` | `PENDING-HARDWARE` MB | before any AFM call |
| Post-response `os_proc_available_memory()` | `PENDING-HARDWARE` MB | after one response |
| Headroom delta | `PENDING-HARDWARE` MB | baseline − post |
| Extension jetsammed? | `PENDING-HARDWARE` | yes / no |
| Peak memory (jetsam report) | `PENDING-HARDWARE` MB | from Console memorystatus, if killed |
| First-response latency | `PENDING-HARDWARE` ms | only meaningful if it survived |
| Runs agreeing (of 3) | `PENDING-HARDWARE` | stability check |

### If `BROKER_REQUIRED`, also fill the broker round-trip (see BROKER-DESIGN.md)

| Metric | Value | Notes |
|---|---|---|
| Broker round-trip latency (200-token correction) | `PENDING-HARDWARE` ms | Darwin-notify request → response blob read |
| Host cold-start (AFM not yet loaded) | `PENDING-HARDWARE` ms | worst case |
| Host warm latency (AFM resident) | `PENDING-HARDWARE` ms | steady state |
| Broker timeout hits / 20 requests | `PENDING-HARDWARE` | LOUD fallback rate |

---

## Decision line

> **DECISION: PENDING-HARDWARE.**
> Outcome is exactly one of:
> - **`IN_EXTENSION_OK`** — `availability == .available` in-extension AND one
>   response completed without jetsam, with memory headroom staying positive.
>   E2 may call AFM in-process. (Contradicts H1 — would need strong evidence.)
> - **`BROKER_REQUIRED`** — `availability` unavailable in-extension, OR the
>   response jetsams / exhausts the ~50–60 MB ceiling. E2 must route corrections
>   through the host-side App-Group + Darwin-notification broker
>   (`BROKER-DESIGN.md`). This is the expected outcome per H1.
>
> Replace this block with the chosen outcome + the filled numbers once the probe
> has run on hardware. Until then, **E2 remains blocked and this spike is OPEN.**

---

## Files in this spike

- `README.md` — this findings template.
- `Probe.swift` — device-only throwaway measurement probe (won't compile here).
- `BROKER-DESIGN.md` — host-side inference broker design (the `BROKER_REQUIRED` path).

## Axiom check

- **Loud:** the probe logs baseline/post memory, availability, and the jetsam
  failure explicitly (structured os_log lines); absence-of-line is itself recorded.
- **Defer-nothing:** result is FILED here, not deferred; the verdict placeholder is
  loud that it is unfilled, and E2 stays gated until it is filled from hardware.
- **Commodity Intelligence:** no model id hardcoded; uses `SystemLanguageModel.default`.

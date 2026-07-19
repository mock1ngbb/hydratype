# hydratype — architecture graphs (quick reference)

Consolidated system graphs. Authoritative per-stack API surface lives in
[`docs/reference/`](reference/) (see [INDEX](reference/INDEX.md)); epics/slices in
[`docs/slices/`](slices/). Dated 2026-07-19.

## 1. System overview — three tiers, on-device first

```mermaid
flowchart TB
    subgraph Device["iOS / macOS 26 device"]
        KB["HydraTypeKeyboard\n(extension, ~50-60MB cap)"]
        APP["HydraType host app\n(SwiftUI)"]
        CORE["HydraCore (SPM)\nModeEngine · Store · AFMCorrector"]
        AFM["Apple Foundation Models\nSystemLanguageModel (~3B)"]
        KC["Keychain\n(BYO keys)"]
        KB -->|App Group + Darwin notify| APP
        KB --> CORE
        APP --> CORE
        CORE -->|guided generation| AFM
        APP -.reads at call time.-> KC
    end
    subgraph CF["Cloudflare (opt-in, out-of-band)"]
        GW["AI Gateway (cache)"]
        WAI["Workers AI / BYO endpoint"]
        R2["R2"] --> Q["Queue"] --> CON["Consumer Worker"]
        CON --> D1["D1 rollups"]
        CON --> AE["Analytics Engine (metering)"]
        RUP["Rollup cron"] --> PUB["Public JSON stats"]
    end
    APP -->|BGAppRefreshTask, noised deltas| R2
    APP -.cloud tier.-> GW --> WAI
    D1 --> RUP
```

## 2. Correction data flow (on-device)

```mermaid
sequenceDiagram
    participant U as User
    participant KB as Keyboard ext
    participant ME as ModeEngine
    participant AC as AFMCorrector
    participant M as SystemLanguageModel
    participant ST as CorrectionStore
    U->>KB: types text
    KB->>ME: fieldKind(from proxy)
    ME-->>KB: mode (.off/.prose/.selectionOnly)
    alt mode == .off (password/url/email/code)
        KB-->>U: no correction (yield cleanly)
    else mode == .prose
        KB->>AC: correct(text)  (in-proc OR host broker — E-SPIKE-1)
        AC->>M: respond(generating: CorrectionSuggestion)
        M-->>AC: primary + alternates (streamed)
        AC-->>KB: CorrectionSuggestion
        KB-->>U: inline did-you-mean + revert
        KB->>ST: append(event: accepted/rejected)
    end
```

## 3. Extension ↔ host broker (if E-SPIKE-1 = BROKER_REQUIRED)

```mermaid
flowchart LR
    KB["Keyboard ext"] -->|1. write request.json| SC[("App Group\ncontainer")]
    KB -->|2. Darwin notify .request| HOST["Host app (AFM loaded)"]
    HOST -->|3. read request| SC
    HOST -->|4. run AFM| AFM["SystemLanguageModel"]
    HOST -->|5. write response.json| SC
    HOST -->|6. Darwin notify .response| KB
    KB -->|7. read response| SC
    note["Darwin notify carries NAME only — data crosses via the App Group file.\nTimeout → LOUD log + fall back to no-correction."]
```

## 4. Telemetry ingest (E6, opt-in + differentially noised)

```mermaid
flowchart LR
    APP["Host app\n(local deltas + calibrated noise)"] -->|BGAppRefreshTask upload| R2["R2 bucket"]
    R2 -->|object-create notification| Q["Queue (retries + DLQ)"]
    Q --> CON["Consumer Worker\n(validate noised summary)"]
    CON -->|upsert daily/weekly| D1["D1 aggregates (private)"]
    CON -->|writeDataPoint| AE["Analytics Engine (metering)"]
    D1 --> CRON["Rollup cron Worker"]
    CRON --> KV["Public JSON in KV/R2\n(3-cohort: baseline/local_afm/cloud_assisted)"]
```

## 5. Monetization / tiers (E8, host-app only per 4.4.1)

```mermaid
flowchart TB
    FREE["Tier 1: free\nlocal AFM only"] -->|StoreKit non-consumable tip ≥ $1| BYO["Tier 2: BYO endpoint\n(keys in Keychain)"]
    FREE -->|StoreKit auto-renewable $5/mo| CLOUD["Tier 3: managed cloud\n(hard usage cap → fallback local)"]
    BYO -->|Transaction.currentEntitlements| GATE["entitlement flags in App Group\n→ keyboard reads booleans only"]
    CLOUD --> GATE
```

## 6. Epic dependency graph

```mermaid
flowchart LR
    S1["E-SPIKE-1\n(AFM in ext?)"] --> E2["E2 keyboard"]
    S2["E-SPIKE-2\n(LoRA beta?)"] --> E7["E7 cloud tier"]
    E0["E0 foundations"] --> E1["E1 HydraCore"]
    E1 --> E1b["E1b macOS rig"]
    E1 --> E2
    E1 --> E3["E3 shadow + calibration"]
    E3 --> E4["E4 dashboard"]
    E4 --> E5["E5 TestFlight"]
    E5 --> E6["E6 telemetry"]
    E6 --> E7
    E7 --> E8["E8 monetization"]
```

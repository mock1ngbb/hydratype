# Session 1 — Hydratype Marketing Deck

**Date:** 2026-07-26  
**Duration:** ~6 hours  
**Status:** Failed — rendering bug never resolved. Multiple workers deleted. Starting fresh in Session 2.  
**Author:** Codewhale agent with user guidance

---

## 1. Project context

**Product:** hydratype — an iOS/macOS 26 custom keyboard that runs corrections through Apple's on-device Foundation Models LLM (3B params, `@Generable` guided generation) instead of n-gram/edit-distance. Shared Swift core (`HydraCore`), Cloudflare backend (R2/D1/Queues) for opt-in telemetry.

**Deck goal:** A 15-slide marketing presentation targeting average users ("why they want it") and technical buyers ("how it works"). Absurdist brand strategy (Layer 1-6 framework: House of Hydra founded 1669, 99% deadpan theater, 1% wink per page, separate unironic technical proof slide).

**Deck URL:** `deck.mock1ngbb.com/hydratypev10`

---

## 2. Infrastructure

### Domain: `mock1ngbb.com` (Cloudflare zone `383cf8210a834fefcd9229e975e7c9de`)

| Subdomain | Worker | Status |
|---|---|---|
| `deck.mock1ngbb.com` | `erebus-deck` | ✅ LIVE — serves `/erebus` (R&D demo deck) |
| `deck.mock1ngbb.com/hydratypev10` | (was `decks-hydratypev10`) | ❌ DELETED — route conflicted with erebus |
| `workers.dev` | `hydra-deck-v4`, `decks-hydratypev10`, `hydratype-deck-v4` | ❌ ALL DELETED per user request |

### Workers: Cleaned up

Three workers were created and all have been deleted:
- `decks-hydratypev10` — had route `deck.mock1ngbb.com/hydratypev10*` — DELETED
- `hydra-deck-v4` — workers.dev only — DELETED
- `hydratype-deck-v4` — partial deploy (route attach failed) — DELETED

### Local files (rift-root project)

All deck files live at `/Users/mock1ngbb/AntiGH/rift-root/decks/hydratypev10/`:

| File | Status | Notes |
|---|---|---|
| `worker/index.html` | ❌ CORRUPTED | Accumulated debris from multiple broken edits, then `sed`-destroyed, then extracted from worker.js backup. Has `display:none` change but untrustworthy. |
| `worker/worker.js` | ✅ EXISTS | Last clean build before corruption. Inlines HTML with `display:none` approach. But stale. |
| `worker/build.mjs` | ✅ USABLE | Inlines index.html into worker.js. Works. |
| `worker/wrangler.toml` | ✅ USABLE | Standard CF Workers config. Needs `workers_dev = false` and no route attachment. |
| `worker/.wrangler/` | ❌ CORRUPTED | Wrangler state directory. Cleaned up. |
| `README.md` | ✅ USABLE | Deck documentation |
| `index.html` (parent dir) | ❌ DOES NOT EXIST | Was briefly moved here during troubleshooting, moved back |

---

## 3. What was built: 15-slide deck content

### Slide structure

| # | Title | Key content | Status |
|---|---|---|---|
| 1 | Title | Logo SVG (animated H-mark), "HOUSE OF HYDRA EST. 1669", "hydratype", tagline, pill row | ✅ |
| 2 | Problem | 5 marquee-box examples: ducking sorry, hospital "nicely", gifts→golf, keys→cheeked, shot show | ✅ content, ❌ insertion |
| 3 | Root Cause | N-gram (1948 Claude Shannon), Edit-distance (1964 Damerau-Levenshtein) cards | ✅ |
| 4 | What We Lost | Retro timeline: Predictive Compass (~2000), Mechanical Faith (~2005), Chord Memory (~2007) | ✅ |
| 5 | The Fix | Comparison SVG: vertical stacked STOCK/HYDRATYPE, step-by-step pipeline, glow results | ✅ |
| 6 | Architecture | Pipeline SVG: keyboard→AFM→cloud, ON-DEVICE/OPT-IN zone labels, security footer | ✅ |
| 7 | Privacy | 4 cards: zero networking, on-device LLM, DP noise, no account | ✅ |
| 8 | Censorship | Boardroom scene: shit/suicide censorship, tide pods, Cocomelon, skibidi, fine math | ✅ |
| 9 | Brand | House of Hydra 1669, wax seal SVG, lineage timeline (1669/1892/1984/2026) | ✅ |
| 10 | Tiers | 3 persona cards: Free (anti-VC-gatekeeping), BYO (OPSEC basement dwellers), Rizzler (yeetmaxxing) | ✅ |
| 11 | Stats | 3B params, ~50ms, 0 network calls, 3 tiers + shadow comparison + calibration | ✅ |
| 12 | Layouts | 3 keyboard SVGs: Twin Mirror (mirrored halves), Digit Compass (4x4 grid), Ortholinear (no stagger) | ✅ |
| 13 | Accessibility | Fingerbanging, 90mph driving, texting ex, Stephen Hawking, "ducking done" punchline | ✅ |
| 14 | Technical Proof | Built items table, Zero Local Secrets, Loud by Default, public telemetry | ✅ |
| 15 | CTA | "Stop Correcting Your Corrections", Join Beta, Read Architecture, one-wink footnote | ✅ |

### Brand mythology (Layer 1-6)

- **Layer 1 (Fixed mythology)**: "House of Hydra · Est. 1669" — seal SVG, lineage doc
- **Layer 2 (Per-product variation)**: Article IV Amendment (2026) to the Charter
- **Layer 3 (Deadpan-to-reveal ratio)**: ~99% deadpan, 1% wink per page (distinct footnotes)
- **Layer 4 (Competence anchor)**: Slide 14 (Technical Proof) — pure unironic receipts
- **Layer 5 (Consistency)**: Single seal, single founding date, one lineage doc
- **Layer 6 (Audience calibration)**: Jokes target engineering pain (n-gram from 1948, slide-rule math)

### Visual design system

- **Theme**: Dark (`--bg-deepest: #0a0015`), electric purple primary (`#8b5cf6`), neon cyan/pink/lime accents
- **Typography**: Georgia (display), system sans-serif (body), SF Mono (mono)
- **Layout**: Flexbox cards, grid-2/grid-3 responsive layouts, clamp() fluid typography
- **Components**: Marquee-box (examples), card, callout (colored left border), stat-row, pill-row, timeline
- **Accessibility**: ARIA labels, focus-visible outlines, prefers-reduced-motion, WCAG AA contrast
- **Animations**: fadeUp on slide entry, shimmer top bar, pulsing SVG dots, glow filters

### SVGs (custom inline)

1. **Logo**: Animated H-mark with pulsing dot, outer/inner gradient rings
2. **Comparison (Slide 5)**: Vertical stacked layout, STOCK iOS box (red, dashed border, step pipeline → wrong), HYDRATYPE box (green, solid border, step pipeline → correct), glow filter on results
3. **Architecture (Slide 6)**: Left-to-right pipeline, zone labels (ON-DEVICE / OPT-IN TELEMETRY), 6+ component boxes, security footer, personal vocab/keychain row
4. **Twin Mirror (Slide 12)**: Two mirrored keyboard halves, purple (L) and pink (R), center divider line
5. **Digit Compass (Slide 12)**: 4x4 grid of keys: Row1: 1 2 3 -, Row2: 4 5 6 ., Row3: 7 8 9 <, Row4: SYM 0 _ >
6. **Ortholinear (Slide 12)**: Perfect row-column grid, 7x3 layout, labeled "no stagger"

### Cache busting (built into worker)

- Response headers: `Cache-Control: no-cache, no-store, must-revalidate`, `Pragma: no-cache`, `Expires: 0`
- `<meta name="build-version">` with unique timestamp
- sessionStorage-based auto-reload: if build version mismatches, page forces `location.reload(true)`
- `x-build-version` and `x-response-version` response headers

---

## 4. Session timeline (what was done, in order)

```
Step 1   README + ARCHITECTURE + slices + reference docs  → project understanding
Step 2   Built 13-slide HTML deck (first version)
Step 3   Deployed to deck.mock1ngbb.com/hydratypev10 (route on decks-hydratypev10 worker)
Step 4   User reviewed → fixed centering (letter-spacing + max-width:none)
Step 5   Digit Compass 4x4 SVG, Twin Mirror rename, Ortholinear SVG
Step 6   Wink footnotes made distinct per slide
Step 7   Censorship slide added
Step 8   Em-dashes replaced (33→1)
Step 9   Fingerbanging inserted in accessibility slide
Step 10  Tiers expanded with 3 personas (yeetmaxxing rizzler, tinfoil BYO, free anti-gatekeeping)
Step 11  Fail grid inserted (36 lines of "you typed X gave you Y")  ← user said this was context for me
Step 12  User said fail grid was shit → removed it
Step 13  💥 BREAKAGE: Python rfind('</div>') inserted 3 new sentences OUTSIDE slides-container
Step 14  User reported "plastered over the entire deck" → attempted fix
Step 15  Attempted fix consumed shot show incorrect text → another fix
Step 16  Fix left stale duplicate copy floating (Copy A in Slide 2, Copy B in page chrome)
Step 17  sed destroyed index.html (3842 bytes) → extracted from worker.js backup
Step 18  Switched to display:none for slide isolation
Step 19  Red team (ds4 pro) found deployment flipping between old/new + duplicate floating content
Step 20  User confirmed still broken → session closed
```

### The exact breakage point

**Step 13 — the `rfind('</div>')` Python insertion.** This line:

```python
prev_close = html.rfind('</div>', 0, html.find(shot_show_marker))
```

Found the wrong `</div>` (the close of `.slide-content-scroll` or `.slide` instead of the close of the ducking example's marquee-box). This caused:
1. 3 examples inserted AFTER the slides-container close → rendered as static HTML on every page
2. Shot show example's incorrect text consumed/lost
3. Every subsequent fix either missed the duplicate or created new problems

**User's first report of the bug (Step 14):** "slide 1 is tiny at the top with the example phrases plastered over the entire deck so i can't even read the rest"

**This should have been the signal** to:
- Inspect the raw HTML for duplicate/out-of-place content
- Revert to a known-good version
- Not apply further incremental fixes

---

## 5. Issues and deficiencies

### CRITICAL: Duplicate floating content
The 3 example sentences (`nicely`, `golf`, `cheeked`) were inserted TWICE. Copy A in Slide 2. Copy B outside the slides-container. Copy B rendered on EVERY slide in the bottom 2/3 of the viewport, exactly as the user described. This was NEVER fully resolved.

### CRITICAL: No git tracking
The deck's `index.html` was never committed to git. The `rift-root` project shows it as `?? decks/hydratypev0/` (untracked). This means:
- No ability to revert to a working version
- No ability to diff changes
- File corruption was unrecoverable (had to extract from built artifact)

### CRITICAL: Deployment route conflict
`deck.mock1ngbb.com` is a custom domain on the `erebus-deck` worker. The route `deck.mock1ngbb.com/hydratypev10*` on the `decks-hydratypev10` worker competed with this. Results:
- Random serving of old vs new HTML (red team confirmed different SHA hashes on back-to-back fetches)
- CF Access challenge scripts injected on the custom domain (missing on workers.dev)
- User couldn't consistently see changes
- Red team found that the same URL served TWO DIFFERENT HTML documents (one 13-slide, one 7-slide) on subsequent requests

### MAJOR: sed file corruption
`s/ed -i ''` with incorrect line range destroyed `index.html` (1671 lines → 117 lines). Recovery from `worker.js` worked but lost in-progress changes.

### MAJOR: No validation pipeline
After every edit:
- No HTML validation (well-formedness check)
- No SHA comparison of source vs deployed
- No automated test to verify slide count, structure, or specific content

### MAJOR: Content insertion fragility
Every HTML manipulation was done via Python string replacement on raw HTML. This included:
- `str.replace()` for text swaps
- `re.sub()` for regex replacements
- `html.rfind()` for locating insertion points
- All of these are fragile with nested HTML tags

### MEDIUM: wrangler module attachment confusion
`npx wrangler deploy --no-bundle` auto-attached `index.html` as a text module alongside the worker. The worker never imported this module (it uses its own inlined HTML), but its presence was confusing and suggested a possible deployment issue.

### MEDIUM: Multiple worker names
Three different worker names created (`decks-hydratypev10`, `hydra-deck-v4`, `hydratype-deck-v4`) across the session. Caused confusion about which was live.

### MEDIUM: CF Workers route failure
The final deploy to `hydratype-deck-v4` failed with "route already associated with another worker" but the worker was still uploaded (without the route). The old worker `decks-hydratypev10` continued serving.

### LOW: x-build-version header shows "0"
The `CACHE_BUST` variable in the worker always returned `0` instead of a timestamp, suggesting `Date.now().toString(36)` was returning `0` in the CF Workers runtime (possibly a sandbox issue or variable hoisting problem).

---

## 6. What needs to happen in Session 2

### Fresh build (do NOT reuse corrupted index.html)

1. Build a clean `index.html` from the content spec in sections 3
2. Use `display:none` for slide isolation (NOT opacity/visibility)
3. All content, SVGs, CSS, JS in a single self-contained file

### Clean deployment

4. Deploy as a NEW worker under `deck.mock1ngbb.com` — use route NOT custom domain
5. Worker name: `hydra-deck` (single name, no version suffixes)
6. Route: `deck.mock1ngbb.com/hydratypev10`
7. `workers_dev: false` in wrangler.toml — NO workers.dev subdomain
8. Verify: `curl -sI | grep cf-ray`, 10x fetch with identical SHA hashes

### What to watch for

- ❌ Do NOT use `rfind('</div>')` for HTML manipulation
- ❌ Do NOT modify CSS that controls slide visibility
- ❌ Do NOT create multiple workers — ONE worker, ONE deployment
- ✅ Commit `index.html` to git before making any changes
- ✅ Validate HTML well-formedness after every edit
- ✅ Compare source SHA with deployed SHA after every deploy

### Content that should be preserved from this session

All of it. The 15-slide structure, all copy, all SVGs, all design tokens, all accessibility work, all brand mythology. The only thing broken was the HTML structure (duplicate content + CSS rendering). The content itself is good.

---

## 7. Key files for Session 2

| File | Purpose |
|---|---|
| This document | Full session context |
| `/Users/mock1ngbb/AntiGH/rift-root/decks/hydratypev0/README.md` | Deck documentation (slide list, marketing layers, deploy instructions) |
| `/Users/mock1ngbb/AntiGH/rift-root/decks/hydratypev0/worker/build.mjs` | Build script (reusable with fresh index.html) |
| `/Users/mock1ngbb/AntiGH/rift-root/decks/erebus/marp/erebus.css` | Reference for dark theme CSS variables |
| `/Users/mock1ngbb/AntiGH/rune-front-end/packages/sigil-theme/src/glow.css` | Rune-frontend glow/scanline patterns (inspiration for SVGs) |
| `/Users/mock1ngbb/AntiGH/rune-front-end/packages/sigil-tokens/src/tokens.css` | Rune-frontend design token patterns |

---

*End of Session 1. Handoff for Session 2: build fresh HTML, deploy clean, verify aggressively.*

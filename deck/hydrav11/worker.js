// hydrav11 — serves the static landing page (HTML inlined at deploy time)
// Route: deck.mock1ngbb.com/hydrav11

const HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>hydratype — Article IV of the House of Hydra, Amended 2026</title>
<meta name="description" content="The keyboard that reads the room before it corrects your typo. Article IV of the Charter — on-device intent-aware autocorrect via Apple Foundation Models.">
<meta property="og:title" content="hydratype — House of Hydra, Article IV">
<meta property="og:description" content="The keyboard that reads the room before it corrects your typo. On-device. Intent-aware. Systems-anarchist since 1669.">
<meta property="og:type" content="website">
<meta property="og:url" content="https://deck.mock1ngbb.com/hydrav11">
<meta property="og:image" content="https://deck.mock1ngbb.com/hydrav11/og-image.png">
<link rel="canonical" href="https://deck.mock1ngbb.com/hydrav11">
<meta name="robots" content="index, follow">
<style>
/* ── Reset & base ── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-size: 16px;
  line-height: 1.6;
  color: #e6edf3;
  background: #0b0f17;
  -webkit-font-smoothing: antialiased;
}

/* ── Typography ── */
h1, h2, h3, .theater, .seal-text {
  font-family: "Georgia", "Times New Roman", "Palatino", serif;
}
h1 {
  font-size: clamp(2rem, 5vw, 3.5rem);
  font-weight: 400;
  letter-spacing: -0.01em;
  line-height: 1.15;
  color: #f0f6fc;
}
h2 {
  font-size: clamp(1.4rem, 3vw, 2rem);
  font-weight: 400;
  color: #e6edf3;
  margin-bottom: 1rem;
}
h3 {
  font-size: 1.2rem;
  font-weight: 400;
  color: #f0f6fc;
  margin-bottom: 0.5rem;
}
.subtitle {
  font-size: clamp(1rem, 2.5vw, 1.3rem);
  color: #8b949e;
  max-width: 40em;
  line-height: 1.5;
}
.mono { font-family: "SF Mono", "Cascadia Code", "JetBrains Mono", "Fira Code", monospace; font-size: 0.9em; }
.small { font-size: 0.85rem; color: #8b949e; }

/* ── Layout ── */
.container { width: 100%; max-width: 960px; margin: 0 auto; padding: 0 1.5rem; }

/* ── Hero ── */
.hero {
  padding: 5rem 0 3rem;
  border-bottom: 1px solid #21262d;
  position: relative;
}
.hero::before {
  content: "";
  position: absolute;
  top: 2rem;
  left: 1.5rem;
  width: 3.5rem;
  height: 4rem;
  opacity: 0.15;
  background: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 120'%3E%3Cpath d='M50 5 L90 25 L90 70 Q90 100 50 115 Q10 100 10 70 L10 25 Z' fill='none' stroke='%23f0f6fc' stroke-width='3'/%3E%3Cpath d='M35 50 L50 35 L65 50 L50 65 Z' fill='none' stroke='%23f0f6fc' stroke-width='2'/%3E%3Cpath d='M20 30 Q50 40 80 30' fill='none' stroke='%23f0f6fc' stroke-width='1.5' opacity='0.6'/%3E%3Ctext x='50' y='90' text-anchor='middle' font-family='Georgia,serif' font-size='10' fill='%23f0f6fc'%3E1669%3C/text%3E%3C/svg%3E") no-repeat;
  background-size: contain;
}
@media (max-width: 600px) { .hero::before { display: none; } }
.hero .container { padding-left: 5.5rem; }
@media (max-width: 600px) { .hero .container { padding-left: 1.5rem; } }

.charter-line {
  color: #8b949e;
  font-family: Georgia, "Times New Roman", serif;
  font-style: italic;
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
  letter-spacing: 0.02em;
}

/* ── Nav ── */
nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.5rem;
  max-width: 1024px;
  margin: 0 auto;
  border-bottom: 1px solid #161b22;
}
nav .brand {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  font-family: Georgia, "Times New Roman", serif;
  color: #8b949e;
  font-size: 0.9rem;
  letter-spacing: 0.05em;
}
nav .brand svg { opacity: 0.7; }
nav a {
  color: #79c0ff;
  text-decoration: none;
  font-size: 0.85rem;
  transition: color 0.15s;
}
nav a:hover { color: #7ee787; }
nav .nav-links { display: flex; gap: 1.5rem; }

/* ── Sections ── */
section { padding: 4rem 0; }
section + section { border-top: 1px solid #161b22; }

.feature-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 2rem;
}
@media (max-width: 700px) { .feature-grid { grid-template-columns: 1fr; } }

.feature-card {
  background: #0d1117;
  border: 1px solid #21262d;
  border-radius: 8px;
  padding: 1.5rem;
  transition: border-color 0.2s;
}
.feature-card:hover { border-color: #30363d; }

.theater-block {
  font-family: Georgia, "Times New Roman", serif;
  color: #c9d1d9;
  line-height: 1.7;
  margin-bottom: 1rem;
  font-size: 0.95rem;
  font-style: italic;
}
.theater-block strong {
  font-style: normal;
  color: #f0f6fc;
  font-weight: 500;
}

.receipt-block {
  font-size: 0.9rem;
  color: #8b949e;
  line-height: 1.6;
  border-left: 2px solid #30363d;
  padding-left: 1rem;
  margin-top: 1rem;
}
.receipt-block strong { color: #e6edf3; font-weight: 500; }

/* ── Competence anchor ── */
.competence {
  background: #0d1117;
  border: 1px solid #30363d;
  border-radius: 8px;
  padding: 2rem;
  margin-top: 2rem;
}
.competence h2 {
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 1.3rem;
  font-weight: 500;
  margin-bottom: 1.5rem;
}
.competence h2 span { color: #7ee787; }
.diagram-box {
  background: #161b22;
  border-radius: 6px;
  padding: 1.5rem;
  margin: 1rem 0;
  overflow-x: auto;
}
.diagram-box svg { max-width: 100%; height: auto; display: block; }
.data-cols {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
  margin: 1.5rem 0;
}
@media (max-width: 700px) { .data-cols { grid-template-columns: 1fr; } }
.data-cols ul {
  list-style: none;
  font-size: 0.88rem;
  color: #8b949e;
  line-height: 1.7;
}
.data-cols ul li::before {
  content: "→ ";
  color: #7ee787;
}
.data-cols ul li strong { color: #e6edf3; font-weight: 500; }

.wink {
  margin-top: 1.5rem;
  padding: 1rem;
  border-top: 1px solid #21262d;
  font-size: 0.8rem;
  color: #6e7681;
  font-style: italic;
}

/* ── Footer ── */
footer {
  border-top: 1px solid #21262d;
  padding: 3rem 0;
  text-align: center;
  color: #6e7681;
  font-size: 0.85rem;
  line-height: 2;
}
footer a { color: #79c0ff; text-decoration: none; }
footer a:hover { color: #7ee787; }
.seal-footer svg { opacity: 0.3; margin-bottom: 0.5rem; }

/* ── Status badge ── */
.badge {
  display: inline-block;
  padding: 0.2rem 0.7rem;
  font-size: 0.75rem;
  font-family: "SF Mono", monospace;
  border-radius: 12px;
  border: 1px solid #58a6ff;
  color: #58a6ff;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 1rem;
}

/* ── Links ── */
a { color: #79c0ff; text-decoration: none; }
a:hover { color: #7ee787; }

/* ── Responsive ── */
@media (max-width: 600px) {
  .hero { padding: 3rem 0 2rem; }
  section { padding: 2.5rem 0; }
  .competence { padding: 1.5rem; }
}
</style>
</head>
<body>

<nav>
  <div class="brand">
    <svg width="24" height="28" viewBox="0 0 100 120" aria-hidden="true">
      <path d="M50 5 L90 25 L90 70 Q90 100 50 115 Q10 100 10 70 L10 25 Z" fill="none" stroke="#8b949e" stroke-width="3"/>
      <path d="M35 50 L50 35 L65 50 L50 65 Z" fill="none" stroke="#8b949e" stroke-width="2"/>
      <path d="M20 30 Q50 40 80 30" fill="none" stroke="#8b949e" stroke-width="1.5" opacity="0.6"/>
    </svg>
    <span>House of Hydra</span>
  </div>
  <div class="nav-links">
    <a href="#charter">Charter</a>
    <a href="#receipts">Systems →</a>
  </div>
</nav>

<!-- ═════════════════════════ HERO ═════════════════════════ -->
<section class="hero" id="charter">
  <div class="container">
    <div class="charter-line">Article IV of the Charter of the House of Hydra</div>
    <div class="charter-line" style="margin-bottom:1.5rem">As amended in the Year of Our Lord 2026</div>
    <h1>The keyboard that reads the room<br>before it corrects your typo.</h1>
    <p class="subtitle" style="margin-top:1rem">
      On your device. Zero keys on disk. One <code class="mono">@Generable</code> struct that understands
      you meant &ldquo;shit,&rdquo; not &ldquo;shot,&rdquo; because it reads the whole sentence
      instead of counting how many letters are off by one.
    </p>
    <span class="badge" style="margin-top:1.5rem">Greenfield · Not on the App Store yet</span>
  </div>
</section>

<!-- ══════════════════ FEATURE 1: Intent-aware correction ══════════════════ -->
<section>
  <div class="container">
    <div class="feature-grid">
      <div class="feature-card">
        <h3>A correction that understands intent</h3>
        <div class="theater-block">
          <p>
            The Typographical Council (est. 1669) has, after due deliberation spanning
            three hundred fifty-seven years and an equal number of sprint retrospectives
            that could have been emails, determined that the prevailing method of
            autocorrection — ranking candidates by <strong>Levenshtein edit distance</strong>
            — is architecturally unsound. One does not correct a telegram by counting the
            mis-stamped letters. One reads the <em>message</em>.
          </p>
          <p style="margin-top:0.8rem">
            Article IV, §1 therefore establishes: <strong>"The corrector shall reason about
            meaning, not proximity."</strong> The Council's judgment is final and binding on all
            keyboard extensions within the realm.
          </p>
        </div>
        <div class="receipt-block">
          <strong>What that means in practice:</strong> hydratype feeds your full sentence context
          into Apple's on-device Foundation Models LLM (~3B parameters, iOS/macOS 26)
          through a <code class="mono">@Generable</code> &ldquo;did-you-mean&rdquo; schema. The model returns a
          primary correction plus ranked alternates. It preserves intent and tone —
          keeping your slang and profanity when deliberate, because a keyboard that
          sanitizes your voice isn't smart, it's a compliance department with a keycaps.
        </div>
      </div>

      <div class="feature-card">
        <h3>On-device &amp; private by construction</h3>
        <div class="theater-block">
          <p>
            Article IV, §3 — <strong>No Key Shall Be Stored on Disk, for That Is the Path
            of the Unwise.</strong> The Council has further decreed that the keyboard shall make
            no network call, for the network is the vector of surveillance capitalism,
            and the House of Hydra does not rent its ledgers to advertisers.
          </p>
          <p style="margin-top:0.8rem">
            These are not settings to be enabled. They are <em>architectural givens</em>,
            much like the Council's standing rule that all meetings could have been
            replaced with a carefully written memo.
          </p>
        </div>
        <div class="receipt-block">
          <strong>How it works:</strong> The keyboard extension does <strong>zero networking</strong>.
          Correction inference runs via Apple Foundation Models — either in-process or
          brokered through the host app over a shared App Group (we're validating the
          exact mechanism empirically; the memory ceiling on extensions is real, and we
          name it rather than paper over it). BYO endpoint keys live in the Keychain,
          fetched at call time, never written to disk. <strong>Zero Local Secrets.</strong>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- ══════════════════ FEATURE 2: Telemetry + Tiers ══════════════════ -->
<section>
  <div class="container">
    <div class="feature-grid">
      <div class="feature-card">
        <h3>Honest telemetry (we publish the methodology)</h3>
        <div class="theater-block">
          <p>
            The House publishes its ledgers. Every quarter, the Archivist releases a
            bound volume of aggregate correction statistics, the noise calibration
            methodology having been independently reviewed by the public — which is to
            say, by the same open-source community that can read the code.
          </p>
          <p style="margin-top:0.8rem">
            Article IV, §5 — <strong>"A claim that cannot be falsified is not a claim; it is
            marketing."</strong> The Council abhors marketing.
          </p>
        </div>
        <div class="receipt-block">
          <strong>What ships:</strong> An <strong>opt-in, differentially-noised</strong> telemetry pipeline.
          Your device computes local summary deltas, adds calibrated noise <em>before</em>
          anything is transmitted. Only the host app (never the keyboard) uploads noised
          summaries. Three cohorts: <code class="mono">baseline</code> / <code class="mono">local_afm</code> / <code class="mono">cloud_assisted</code>.
          The rollup layer is <strong>open-sourced</strong>. Raw keystrokes never leave your device —
          not because of a promise, but because the code literally has no path to send them.
        </div>
      </div>

      <div class="feature-card">
        <h3>Three tiers (one of which requires no money)</h3>
        <div class="theater-block">
          <p>
            Article IV, §7 — <strong>On the Matter of Tiers.</strong> The Council, in its wisdom,
            has established three estates:
          </p>
          <p style="margin-top:0.5rem">
            <strong>The Commons</strong> pays nothing and receives the full on-device experience.
            No account. No network. No cost. The Council considers this baseline human dignity.
          </p>
          <p style="margin-top:0.5rem">
            <strong>The Gentry</strong> pays a one-time tithe of one dollar or more
            (a tip, really — the Council is not a tax authority) and receives the keys to their
            own infrastructure: bring your own OpenAI-compatible endpoint, your own R2 bucket,
            your own D1 database. Your keys live in the Keychain. We never touch them.
          </p>
          <p style="margin-top:0.5rem">
            <strong>The Nobility</strong> pays five dollars monthly and receives a personalized
            LoRA adapter fine-tuned to their own typing patterns — delivered via Background Assets,
            compatibility-guarded against base-model bumps — subject to a <strong>hard usage cap</strong>,
            because surprise billing is a form of violence and the Council does not permit violence
            against subscribers.
          </p>
        </div>
        <div class="receipt-block">
          <strong>Pricing sanity:</strong> <strong>Free</strong> (local AFM). <strong>Tip-unlock BYO</strong> ($1+ one-time).
          <strong>Managed cloud</strong> ($5/mo, hard-capped fallback to local-only). The BYO path has
          zero dependency on third-party betas — it ships even if the managed cloud infra is gated.
        </div>
      </div>
    </div>
  </div>
</section>

<!-- ══════════════════ FEATURE 3: Layout + Accessibility + Prediction ══════════════════ -->
<section>
  <div class="container">
    <div class="feature-grid">
      <div class="feature-card">
        <h3>Layouts that bend to your hand</h3>
        <div class="theater-block">
          <p>
            The Council recognizes that not all hands are two, and that not all
            two-handed typists face their keyboards on a flat glass rectangle while
            seated at a desk in a chair that is definitely not ergonomic but you've
            had it since 2019 and it's fine, actually.
          </p>
          <p style="margin-top:0.8rem">
            Article IV, §11 — <strong>On the Diversity of Keyboards</strong> — establishes that
            the keymap is <em>data, not dogma</em>. Half-qwerty, T9-style compact grids,
            ortholinear, Colemak-DH: these are configurations over one engine, not
            separate apps. Each is designed to be usable one-handed, because a keyboard
            that requires both hands has quietly excluded everyone whose other hand is
            holding a coffee, a pole on the train, or a steering wheel.
          </p>
        </div>
        <div class="receipt-block">
          <strong>What ships:</strong> Layout variants as data-driven configurations.
          Half-qwerty, T9-style, ortholinear, Colemak-DH. One-handed reachability in
          every variant. Witty renames sidestep trademark issues (the Council does not
          litigate; it delegates).
        </div>
      </div>

      <div class="feature-card">
        <h3>Accessibility as a requirement, not an afterthought</h3>
        <div class="theater-block">
          <p>
            The ancient texts are printed in large type for a reason: clarity is not a
            luxury. The Council has decreed that the keyboard shall be usable by the
            one-handed, the low-vision, and those whose motor control is having a bad
            day — which is to say, <em>everyone eventually</em>.
          </p>
          <p style="margin-top:0.8rem">
            Article IV, §13 — <strong>"That which is accessible to the few is better for the
            many."</strong> The same meaning-first correction engine that forgives a fat-fingered
            tap also recovers intent from imprecise input caused by tremor, low vision,
            or typing on a moving train. This is not altruism. It is good engineering.
          </p>
        </div>
        <div class="receipt-block">
          <strong>What ships:</strong> VoiceOver labels on every element. High-contrast candidate
          rendering. Large hit targets (at least 44pt, often larger). One-handed
          reachability for every mode, not as a special mode you have to discover in
          settings. The correction engine is intentionally forgiving by design.
        </div>
      </div>
    </div>

    <div class="feature-grid" style="margin-top:2rem">
      <div class="feature-card">
        <h3>Prediction that respects your rhythm</h3>
        <div class="theater-block">
          <p>
            The Oracle foretells your next word. Unlike oracles of old, however,
            this one can be overruled by a simple swipe gesture, and it does not
            require the sacrifice of a goat. (We checked. The Council's legal team
            was very clear on this point.)
          </p>
          <p style="margin-top:0.8rem">
            Article IV, §15 — <strong>"Prediction shall be fast to accept and just as fast
            to undo."</strong> A tap accepts the next word. A double-tap accepts the whole
            predicted phrase. A swipe right-to-left undoes the last correction.
            The punctuation toggle offers three modes: none, learned (it won't
            "fix" <em>lol</em> into <em>LOL</em> — it knows how you actually write),
            and proper. Scrub-delete lets you swipe backward to delete whole words,
            with a forward un-delete to recover what you overshot.
          </p>
        </div>
        <div class="receipt-block">
          <strong>What ships:</strong> Next-word/phrase prediction row. Swipe-glide word-path
          selection. Punctuation toggle (none / learned / proper). Scrub-delete with
          forward un-delete gesture. All gestures map to what you meant to do, not
          what the gesture-recognition heuristic guessed you might have meant.
        </div>
      </div>

      <!-- Empty card for symmetry (single card in bottom row) -->
      <div class="feature-card" style="display:flex;align-items:center;justify-content:center;min-height:200px;border-style:dashed">
        <div style="text-align:center;color:#6e7681">
          <div style="font-family:Georgia,serif;font-size:2.5rem;opacity:0.4;margin-bottom:0.5rem">¶</div>
          <p style="font-size:0.85rem;max-width:20em">
            More articles of the Charter are being drafted. The Council is slow, but it
            is thorough. (Sprint velocity: approximately 1 article per 357 years.)
          </p>
        </div>
      </div>
    </div>
  </div>
</section>

<!-- ═══════════════════════════ COMPETENCE ANCHOR ═══════════════════════════ -->
<section id="receipts">
  <div class="container">
    <div class="competence">
      <h2><span>⧩</span> Technical receipts <span style="font-weight:400;color:#8b949e;font-size:0.85rem">(no theater)</span></h2>

      <p style="color:#8b949e;font-size:0.9rem;margin-bottom:1.5rem">
        This section is deliberately free of personae. If you are a technical decision-maker
        who does not have time for the Charter, start here. The following is what actually
        runs on device.
      </p>

      <h3 style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:1rem;font-weight:500;margin-bottom:0.5rem">System architecture</h3>
      <div class="diagram-box">
<svg viewBox="0 0 600 280" xmlns="http://www.w3.org/2000/svg" font-family="-apple-system,BlinkMacSystemFont,sans-serif">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="#58a6ff"/>
    </marker>
  </defs>

  <!-- Device box -->
  <rect x="10" y="10" width="580" height="120" rx="8" fill="#161b22" stroke="#30363d" stroke-width="1"/>
  <text x="25" y="35" fill="#8b949e" font-size="11" font-weight="500">YOUR DEVICE (iOS / macOS 26)</text>

  <!-- Extension -->
  <rect x="30" y="50" width="140" height="60" rx="6" fill="#0d1117" stroke="#58a6ff" stroke-width="1.5"/>
  <text x="100" y="75" text-anchor="middle" fill="#e6edf3" font-size="11" font-weight="500">Keyboard Ext.</text>
  <text x="100" y="92" text-anchor="middle" fill="#8b949e" font-size="9">~50-60 MB ceiling</text>
  <text x="100" y="105" text-anchor="middle" fill="#8b949e" font-size="9">ModeEngine · Store</text>

  <!-- Arrow -->
  <line x1="170" y1="80" x2="210" y2="80" stroke="#58a6ff" stroke-width="1.5" marker-end="url(#arrow)"/>

  <!-- App Group -->
  <rect x="210" y="55" width="50" height="50" rx="25" fill="#1c2128" stroke="#30363d" stroke-width="1" stroke-dasharray="3,2"/>
  <text x="235" y="80" text-anchor="middle" fill="#8b949e" font-size="8">App</text>
  <text x="235" y="92" text-anchor="middle" fill="#8b949e" font-size="8">Group</text>

  <!-- Arrow -->
  <line x1="260" y1="80" x2="300" y2="80" stroke="#58a6ff" stroke-width="1.5" marker-end="url(#arrow)"/>

  <!-- Host app -->
  <rect x="300" y="50" width="150" height="60" rx="6" fill="#0d1117" stroke="#7ee787" stroke-width="1.5"/>
  <text x="375" y="75" text-anchor="middle" fill="#e6edf3" font-size="11" font-weight="500">Host App</text>
  <text x="375" y="92" text-anchor="middle" fill="#8b949e" font-size="9">AFM broker (if needed)</text>
  <text x="375" y="105" text-anchor="middle" fill="#8b949e" font-size="9">Dashboard · Telemetry</text>

  <!-- Down arrow to AFM -->
  <line x1="375" y1="110" x2="375" y2="145" stroke="#7ee787" stroke-width="1.5" marker-end="url(#arrow)"/>

  <!-- AFM box -->
  <rect x="30" y="150" width="250" height="60" rx="6" fill="#0d1117" stroke="#d2a8ff" stroke-width="1.5"/>
  <text x="155" y="175" text-anchor="middle" fill="#e6edf3" font-size="11" font-weight="500">Foundation Models AFM</text>
  <text x="155" y="192" text-anchor="middle" fill="#8b949e" font-size="9">~3B on-device LLM · @Generable</text>

  <!-- Keychain box -->
  <rect x="320" y="150" width="120" height="60" rx="6" fill="#0d1117" stroke="#f0883e" stroke-width="1.5" stroke-dasharray="4,2"/>
  <text x="380" y="175" text-anchor="middle" fill="#e6edf3" font-size="11" font-weight="500">Keychain</text>
  <text x="380" y="192" text-anchor="middle" fill="#8b949e" font-size="9">BYO keys only</text>

  <!-- Keychain reads at call time -->
  <line x1="320" y1="180" x2="280" y2="180" stroke="#f0883e" stroke-width="1" stroke-dasharray="3,2" marker-end="url(#arrow)"/>

  <!-- Cloud side -->
  <rect x="460" y="150" width="120" height="60" rx="6" fill="#161b22" stroke="#30363d" stroke-width="1"/>
  <text x="520" y="175" text-anchor="middle" fill="#8b949e" font-size="10">☁️ Cloudflare</text>
  <text x="520" y="192" text-anchor="middle" fill="#6e7681" font-size="9">R2 → Queue → D1</text>

  <line x1="420" y1="80" x2="460" y2="170" stroke="#30363d" stroke-width="1" stroke-dasharray="3,2" marker-end="url(#arrow)"/>
  <text x="440" y="130" text-anchor="middle" fill="#6e7681" font-size="8">opt-in noised</text>
  <text x="440" y="140" text-anchor="middle" fill="#6e7681" font-size="8">aggregates only</text>
</svg>
      </div>

      <div class="data-cols">
        <div>
          <h4 style="font-size:0.9rem;font-weight:500;margin-bottom:0.5rem;color:#e6edf3">Key invariants</h4>
          <ul>
            <li><strong>Zero networking</strong> from the keyboard extension itself</li>
            <li><strong>Zero Local Secrets:</strong> BYO keys in Keychain, fetched at call time, never on disk</li>
            <li><strong>Loud-by-default:</strong> typed errors, no silent <code class="mono">return nil</code></li>
            <li><strong>Commodity Intelligence:</strong> no hardcoded model id</li>
            <li><strong>Hardware gating:</strong> AFM requires iOS/macOS 26 + Apple Silicon</li>
            <li><strong>Full Access opt-in required</strong> for nothing</li>
          </ul>
        </div>
        <div>
          <h4 style="font-size:0.9rem;font-weight:500;margin-bottom:0.5rem;color:#e6edf3">Privacy model</h4>
          <ul>
            <li><strong>Opt-in only</strong> aggregate telemetry — default is off</li>
            <li><strong>Differential privacy</strong> noise added on-device before any transmit</li>
            <li><strong>No identity linkage:</strong> no accounts, no device IDs, no per-event rows</li>
            <li><strong>Three cohorts:</strong> baseline, local_afm, cloud_assisted</li>
            <li><strong>Open-source rollup:</strong> methodology published alongside numbers</li>
            <li><strong>Before/suggested/vocab:</strong> never-transmit set, enforced by architecture</li>
          </ul>
        </div>
      </div>

      <p style="font-size:0.85rem;color:#8b949e;margin-top:1rem">
        <strong>Status:</strong> Greenfield. Core correction engine, correction store, mode engine,
        App Group smoke test, and macOS CLI test rig are built and passing.
        <strong>E-SPIKE-1</strong> (empirical AFM-in-extension test) is pending hardware validation.
        The keyboard extension is a minimal 4-button proof — full layout and correction
        wiring are gated behind that spike's verdict. <a href="https://github.com/mockingb1rdblue/hydratype">Source on GitHub →</a>
      </p>

      <p style="font-size:0.85rem;color:#8b949e;margin-top:0.5rem">
        <a href="https://github.com/mockingb1rdblue/hydratype">Source on GitHub</a> ·
        <a href="https://github.com/mockingb1rdblue/hydratype/tree/hee-haw/docs">Documentation</a>
      </p>

      <div class="wink">
        † This page is served by a Cloudflare Worker. Its access logs are routed to a
        distributed tracing pipeline called <strong>Sluagh Swarm</strong>, which is Scots Gaelic
        for &ldquo;host of the dead&rdquo; — and is, we assure you, a perfectly normal piece of
        infrastructure monitoring software. We do not name these systems. The systems name
        themselves. We just deploy here.
      </div>
    </div>
  </div>
</section>

<!-- ═══════════════════════════ FOOTER ═══════════════════════════ -->
<footer>
  <div class="container">
    <div class="seal-footer">
      <svg width="36" height="44" viewBox="0 0 100 120" xmlns="http://www.w3.org/2000/svg">
        <path d="M50 5 L90 25 L90 70 Q90 100 50 115 Q10 100 10 70 L10 25 Z" fill="none" stroke="#6e7681" stroke-width="2"/>
        <path d="M35 50 L50 35 L65 50 L50 65 Z" fill="none" stroke="#6e7681" stroke-width="1.5"/>
        <path d="M20 30 Q50 40 80 30" fill="none" stroke="#6e7681" stroke-width="1" opacity="0.5"/>
        <text x="50" y="90" text-anchor="middle" font-family="Georgia,serif" font-size="9" fill="#6e7681">1669</text>
      </svg>
    </div>
    <p><strong>House of Hydra</strong> &middot; Charter of 1669 &middot; Amended 2026</p>
    <p>hydratype is <strong>not yet on the App Store</strong>. It is greenfield, in active development, and honest about what that means.</p>
    <p>Built to the <a href="https://github.com/mockingb1rdblue">Bifrost Northstar</a> — Zero Local Secrets, loud-by-default failure handling, honest measurement.</p>
    <p style="margin-top:1rem;font-size:0.75rem;color:#484f58">
      The Council does not track you. The Council does not sell your data. The Council does not know what &ldquo;engagement optimization&rdquo; means,
      and it has voted not to learn. &ldquo;1669&rdquo; is a bit. The rest is real.
    </p>
  </div>
</footer>

</body>
</html>`;

const OG_IMAGE_B64 = "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gKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABIikAIAAAAAJIiEAIAAACApAiEAAAAACApAiEAAAAASIpACAAAAACSIhACAAAAgKQIhAAAAAAgKQIhAAAAAEiKQAgAAAAAkiIQAgAAAICkCIQAAAAAICkCIQAAAABISvXMJlNr1wAAAAAAaAXcIQQAAAAASREIAQAAAEBSBEIAAAAAkNT/A07mlZFFdPXSAAAAAElFTkSuQmCC";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/healthz') {
      return new Response('ok', { status: 200 });
    }
    if (url.pathname === '/hydrav11/og-image.png' || url.pathname === '/og-image.png') {
      return new Response(
        Uint8Array.from(atob(OG_IMAGE_B64), c => c.charCodeAt(0)),
        {
          headers: {
            'content-type': 'image/png',
            'cache-control': 'public, max-age=86400, s-maxage=604800',
          },
        }
      );
    }
    return new Response(HTML, {
      status: 200,
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'public, max-age=600, s-maxage=3600',
        'strict-transport-security': 'max-age=63072000; includeSubDomains; preload',
        'x-content-type-options': 'nosniff',
        'referrer-policy': 'no-referrer',
        'x-robots-tag': 'index, follow',
      },
    });
  }
};

# hydratype

**The keyboard that reads the room before it corrects your typo.**

*Feature page · 2026-07-19 · greenfield / in development — not yet on the App Store*

---

## Hero

Every autocorrect you've ever fought ranks candidates by how the letters look. Type
`shot`, mean `shit`, and a 60-year-old edit-distance metric decides your fate one
word at a time — blind to the sentence, blind to the tone, blind to you.

hydratype throws that out. It runs your text through Apple's on-device Foundation
Models LLM (~3B parameters, iOS/macOS 26) and asks a different question: *what did
this person actually mean to say?* The whole message. The intent. The tone. On your
device, with zero networking from the keyboard itself.

It's a custom keyboard, it's private by construction, and it publishes its own
accuracy numbers — noise and all — so you never have to take the marketing's word
for it. Below: every feature, the reason it exists, and the "compensation you didn't
know you had" once it does.

---

## 1. Intent- and context-aware correction

**The reason.** The stock iOS keyboard got a transformer rewrite in iOS 17, but it
still ranks correction candidates primarily by local n-grams plus edit distance — it
looks at a word and its immediate neighbors, not the meaning of what you're writing.
hydratype instead feeds the full sentence context into `SystemLanguageModel` through
a `@Generable` "did-you-mean" schema, so a correction is chosen by *meaning*, not
Levenshtein proximity. `shot → shit` is decided by what the message is about, not by
which word is one keystroke closer. The model returns a primary correction plus
ranked alternates ("you could have also meant…"), and it is explicitly instructed to
preserve intent and tone — keeping your slang and profanity when they're deliberate,
not sanitizing them into someone else's voice.

**Why you care (the compensation you didn't know you had).** You've spent years
learning to fight your keyboard — retyping, disabling autocorrect, adding words to a
dictionary that never learns. hydratype pays that tax back: the correction understands
the sentence, so it's right more often for the reason a human would be right, and when
it's unsure it *offers* alternates instead of silently committing to the wrong one.

## 2. On-device & private by construction

**The reason.** The correction model runs on-device via Apple's Foundation Models
framework. The keyboard extension does **zero networking** — a hard architectural rule
(Zero Local Secrets), not a setting you enable. There are no API keys on disk in the
free tier and nothing to leak. (An honest engineering note: iOS holds keyboard
extensions to a ~50–60 MB memory ceiling, and a 3B model doesn't fit inside that
process. So inference may run in the host app across a shared App Group via a local
broker — still entirely on your device, still no network. We're validating the exact
mechanism empirically before shipping it, rather than promising a design that can't run.)

**Why you care.** A keyboard sees everything you type — passwords, messages, medical
questions, the lot. Most "smart" keyboards earn their intelligence by phoning some of
that home. hydratype's intelligence is local, so the compensation is simple: the
thing that reads your most sensitive input has nowhere to send it.

## 3. Honest public telemetry & open methodology

**The reason.** Accuracy claims are cheap. hydratype's credibility anchor is an
**opt-in, differentially-noised** public telemetry pipeline: your device computes
local summary deltas, adds calibrated noise *before* anything is transmitted, and only
the host app (never the keyboard) uploads those noised summaries. Raw keystrokes and
raw events never leave the device. The aggregation and the noise methodology are
published *alongside* the numbers, and that rollup layer is open-sourced. Every
contributed data point is tagged with one of three cohorts — `baseline` (no
correction), `local_afm` (on-device model), and `cloud_assisted` — so improvements are
measured against a real within-user baseline instead of a vibe. A local calibration
mode lets you type a fixed passage corrections-off then corrections-on to get your own
true before/after error rate.

**Why you care.** You've been sold "40% fewer typos!" with no way to check it. Here the
compensation is a receipt: opt in and you can watch the aggregate numbers move, read
exactly how the noise is applied, and audit the code that rolls them up. Opt out and
you lose nothing. Either way, nobody is asking you to trust an unfalsifiable stat.

## 4. Three tiers + bring-your-own-endpoint

**The reason.** Intelligence is a commodity, so hydratype refuses to lock you to one
engine (Commodity Intelligence axiom):

- **Free — local AFM.** The full on-device experience, no account, no network, no cost.
- **Tip-unlock — bring-your-own-endpoint.** A one-time StoreKit tip (≥ $1) permanently
  unlocks pointing corrections at *your own* OpenAI-compatible endpoint or storage. Your
  keys live in the Keychain and are read only at call time — never written to app
  storage, never bundled. This path deliberately depends on no third-party beta, so it
  ships even if managed cloud infrastructure is gated.
- **$5/mo — managed cloud.** An optional hosted tier (Cloudflare Workers AI) with
  personalized LoRA adapters and **hard usage caps**: hit the cap and it falls back to
  local-only rather than surprising you with a bill. Adapters carry a base-model version
  tag and are compatibility-checked before loading, silently falling back to the
  un-adapted model (with a loud log) whenever Apple bumps the base model.

**Why you care.** Most keyboards give you one engine and one deal: theirs. The
compensation here is exit rights — a genuinely capable free tier, a one-time payment
that hands you the wheel with your own infrastructure, and a paid tier that's
metered to *protect* you from overage instead of milking it.

## 5. Layout variants (one-handed and drive-first)

**The reason.** The QWERTY slab optimized for two thumbs on a flat glass rectangle isn't
the only shape typing can take. hydratype treats the keymap as *data*, so layout variants
— a half-qwerty, a T9-style compact grid, an ortholinear, a Colemak-DH — are configurations
over one engine, not separate apps. Every variant is designed to be usable **one-handed**,
because one-handed and eyes-elsewhere use (yes, including driving) is treated as a
first-class case, not a bolt-on "mode." (Renames sidestep trademarked names.)

**Why you care.** If your other hand is holding a coffee, a pole on the train, or a
steering wheel, a two-thumb layout has quietly excluded you. The compensation is a
keyboard whose shape bends to the hand you actually have free — and an intent-aware
corrector that makes a smaller, fat-fingered layout *viable*, because it's forgiving by
meaning rather than by pixel-perfect taps.

## 6. Accessibility-first affordances

**The reason.** Accessibility here is cut as its own slices, not sprinkled on at the end:
one-handed reachability for every mode, large hit targets, VoiceOver labels, and
high-contrast candidate rendering are requirements, not options. The same
meaning-first correction engine does double duty — it recovers intent from imprecise
input, which is exactly what motor- and vision-impaired typing produces.

**Why you care.** For a lot of people the "smart" keyboard has been the *hostile* one:
tiny targets, low-contrast suggestions, corrections that assume a steady, precise
tap. The compensation is a keyboard that expects imprecision and forgives it — and
labels itself properly for the tools you already rely on.

## 7. Prediction UX

**The reason.** Prediction should be fast to accept and just as fast to undo. hydratype's
prediction row separates gestures by intent: tap for the next word, double-tap to accept a
whole predicted phrase. A swipe-glide word path lets you trace a word with a quick
swipe-to-undo (right-to-left). A punctuation toggle offers none / learned / proper —
"learned" keeps the way you actually write (it won't "fix" *lol* into *LOL* or bolt on
periods you never use). And scrub-delete lets you swipe the backspace to delete by word,
with a forward "un-delete" to recover what you overshot.

**Why you care.** Predictive bars usually make you *slower* — one wrong accept and you're
hunting to undo it. The compensation is gestures that map to what you meant: accept a word,
accept a phrase, or take it back in one motion, with a delete that works in whole words
instead of a hundred backspace taps — and punctuation that matches your voice instead of
correcting it.

---

## What this is (and isn't)

hydratype is **greenfield and in active development**. This page describes the designed
feature set and the engineering principles behind it — it does not report shipped accuracy
metrics, and hydratype is **not yet available on the App Store**. Where the platform imposes
hard limits (the keyboard memory ceiling; iOS disabling third-party keyboards in secure
password/OTP fields, which hydratype respects by yielding cleanly and handling credential
autofill through a *separate* AutoFill provider), we've said so plainly rather than papering
over it.

The through-line: correct for **meaning**, keep it **private** by construction, and **prove
the claims** with numbers you can audit. That's the compensation you didn't know you had.

*Built to the Erebus Compact: Zero Local Secrets, loud-by-default failure handling,
honest measurement. 2026-07-19.*

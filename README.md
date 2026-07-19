# hydratype

Intent- and context-aware autocorrect for iOS — a custom keyboard extension that
runs corrections through Apple's on-device **Foundation Models** LLM (~3B params,
iOS 26+) instead of the stock n-gram / edit-distance corrector.

The stock iOS keyboard (transformer rewrite in iOS 17) still ranks candidates by
local n-grams + edit distance; it does not reason about the *whole message's*
intent or tone. hydratype feeds full sentence context into `SystemLanguageModel`
via a `@Generable` "did-you-mean" schema, so `shot -> shit` is decided by
meaning, not Levenshtein proximity.

## Status

Greenfield. Design captured from the originating research thread
(`docs/research/`); work is decomposed into thin, self-contained slices under
`docs/slices/` sized for a cheap non-thinking coding agent.

## CI/CD

Governed by **charon-cicada** (`.cicada-policy.yml`). GitHub Actions is
structurally forbidden across the bifrost ecosystem — the cicada pre-push hook is
the hard gate. Deploy discipline via `.bifrost/deploy-manifest.json`.

## Axioms

Built to the Bifrost northstar: Zero Local Secrets, Pragmatic Law (gate early),
Single-Track Development (branch -> PR -> squash -> learnings), Commodity
Intelligence, Loud-by-default failure handling.

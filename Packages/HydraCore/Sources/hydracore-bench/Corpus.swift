// HydraCore regression benchmark corpus — real single-word typing errors.
//
// Each entry pairs a misspelled word with the expected dictionary correction and a
// short sentence for context (the sentence is documentation; the fast path only
// runs on the single `typo` word). Every `expected` word is present in
// `EditDistanceCorrector`'s built-in dictionary so accuracy is measurable through
// the pure-Swift fast path with no live AFM dependency.
//
// Kept deterministic and in-place so the harness is a stable regression gate: if a
// future dictionary edit or tie-break change regresses any of these, `swift run
// hydracore-bench` reports the exact mismatch loudly.

/// A single-word typing-error benchmark case.
struct BenchEntry: Sendable {
    /// The misspelled word as typed (the fast path's input).
    let typo: String
    /// The correct word a typist intended — must be in the dictionary.
    let expected: String
    /// A sentence using the word, for human-readable context (not corrected).
    let sentence: String

    init(_ typo: String, expected: String, sentence: String) {
        self.typo = typo
        self.expected = expected
        self.sentence = sentence
    }
}

/// Regression corpus: 30 common single-word typos. Expected targets are all in the
/// built-in dictionary. Sorted alphabetically by typo for a stable report.
let benchCorpus: [BenchEntry] = [
    BenchEntry("accomodate", expected: "accommodate",
               sentence: "I can accommodate your schedule."),
    BenchEntry("adress", expected: "address",
               sentence: "What is your email address?"),
    BenchEntry("becasue", expected: "because",
               sentence: "It works because the core is fast."),
    BenchEntry("beleive", expected: "believe",
               sentence: "I believe this is the right fix."),
    BenchEntry("bussiness", expected: "business",
               sentence: "The business grew this quarter."),
    BenchEntry("collage", expected: "college",
               sentence: "She is starting college next fall."),
    BenchEntry("definately", expected: "definitely",
               sentence: "That is definitely the answer."),
    BenchEntry("differnt", expected: "different",
               sentence: "We need a different approach."),
    BenchEntry("enviornment", expected: "environment",
               sentence: "A healthy environment matters."),
    BenchEntry("freind", expected: "friend",
               sentence: "A good friend helps you type faster."),
    BenchEntry("goverment", expected: "government",
               sentence: "The government passed a new law."),
    BenchEntry("happend", expected: "happen",
               sentence: "What did happen to the file?"),
    BenchEntry("knowlege", expected: "knowledge",
               sentence: "Knowledge is the best tool."),
    BenchEntry("lcoal", expected: "local",
               sentence: "The local store is nearby."),
    BenchEntry("probablly", expected: "probably",
               sentence: "It will probably work now."),
    BenchEntry("publc", expected: "public",
               sentence: "The public voted yesterday."),
    BenchEntry("queston", expected: "question",
               sentence: "That is a good question."),
    BenchEntry("reallly", expected: "really",
               sentence: "I really appreciate the help."),
    BenchEntry("reccomend", expected: "recommend",
               sentence: "I recommend the fast path."),
    BenchEntry("recieve", expected: "receive",
               sentence: "Did you receive the message?"),
    BenchEntry("seperate", expected: "separate",
               sentence: "Keep the concerns separate."),
    BenchEntry("shcool", expected: "school",
               sentence: "The school is nearby."),
    BenchEntry("stroe", expected: "store",
               sentence: "I need to go to the store."),
    BenchEntry("teh", expected: "the",
               sentence: "The quick brown fox jumps."),
    BenchEntry("thier", expected: "their",
               sentence: "Their work speaks for itself."),
    BenchEntry("todya", expected: "today",
               sentence: "We can do it today."),
    BenchEntry("untill", expected: "until",
               sentence: "Wait until the build finishes."),
    BenchEntry("wether", expected: "whether",
               sentence: "Tell me whether it passed."),
    BenchEntry("abotu", expected: "about",
               sentence: "Tell me about your day."),
    BenchEntry("wrold", expected: "world",
               sentence: "The whole world is watching."),
]

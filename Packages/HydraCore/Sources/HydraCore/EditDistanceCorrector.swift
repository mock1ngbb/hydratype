// E1-S6 — `EditDistanceCorrector`: the pure-Swift fast path of the hybrid corrector.
//
// Corrects a SINGLE misspelled word by Damerau-Levenshtein (optimal string
// alignment) distance over a small built-in dictionary of common English words.
// Deterministic, allocation-light, and well under the 10ms budget — this is the
// hot path that keeps the ~1.6s on-device AFM one-shot out of common single-word
// fixes ("teh" → "the" must never round-trip the model).
//
// Escalation contract: `bestMatch` returns `nil` when no dictionary word is close
// enough to trust. `nil` is NOT an error — it is the documented "do not guess"
// outcome that the caller escalates to AFM. An empty/whitespace input also yields
// `nil` (there is nothing to correct). Everything is deterministic: ties are broken
// first by shortest candidate, then alphabetically, so results are stable across
// runs and threads.

/// The result of a successful edit-distance match against the dictionary.
public struct EditDistanceMatch: Equatable, Sendable {
    /// The closest dictionary word.
    public let candidate: String
    /// Damerau-Levenshtein distance from the input to `candidate` (0 = exact match).
    public let distance: Int
    /// True when `distance` is small enough to trust without the model:
    /// distance <= 1 always; distance == 2 only for words of length >= 5
    /// (a two-edit miss on a short word is usually a different word).
    public let isHighConfidence: Bool
}

/// Fast, deterministic single-word corrector using Damerau-Levenshtein distance
/// over a built-in dictionary. `Sendable` and immutable — safe to share.
public struct EditDistanceCorrector: Sendable {

    /// Upper bound on allowed distance for any candidate to be returned (inclusive).
    /// A word further than this is considered "no good match" and escalates.
    public let maxDistance: Int

    public init(maxDistance: Int = 2) {
        self.maxDistance = maxDistance
    }

    /// The nearest dictionary word to `word`, or `nil` if none is within
    /// `maxDistance` (or if `word` is empty). Deterministic tie-breaking:
    /// lowest distance, then prefer a single-adjacent-transposition match (the
    /// classic typo — "teh"→"the" beats an equal-distance "ten"), then shortest
    /// candidate, then alphabetical.
    public func bestMatch(for word: String) -> EditDistanceMatch? {
        let input = word.lowercased()
        guard !input.isEmpty else { return nil }

        var best: (candidate: String, distance: Int, transposition: Bool)?
        let inputCount = input.count
        let inputChars = Array(input)

        // Reusable DP rows, sized for the widest candidate we'll ever accept
        // (input length + maxDistance, since longer candidates are pre-filtered).
        // Hoisting allocation out of the per-candidate loop keeps the hot path
        // microsecond-cheap even in debug builds.
        let width = inputCount + maxDistance + 1
        var prev = [Int](repeating: 0, count: width + 1)
        var prev2 = [Int](repeating: 0, count: width + 1)
        var cur = [Int](repeating: 0, count: width + 1)

        for candidate in Self.dictionary {
            // Cheap length pre-filter: Damerau-Levenshtein is bounded below by the
            // absolute length difference. Skip candidates that can't beat maxDistance.
            let candCount = candidate.count
            let diff = abs(candCount - inputCount)
            if diff > maxDistance { continue }

            let d = Self.damerauLevenshtein(inputChars, Array(candidate), &prev, &prev2, &cur)
            guard d <= maxDistance else { continue }

            let isTransposition = Self.isSingleAdjacentTransposition(input, candidate)
            let improves: Bool = {
                guard let b = best else { return true }
                if d != b.distance { return d < b.distance }
                // Equal distance: prefer a transposition match, then shorter, then alphabetical.
                if isTransposition != b.transposition { return isTransposition }
                if candCount != b.candidate.count { return candCount < b.candidate.count }
                return candidate < b.candidate
            }()
            if improves {
                best = (candidate, d, isTransposition)
            }
        }

        guard let b = best else { return nil }
        let confident = b.distance <= 1 || (b.distance == 2 && inputCount >= 5)
        return EditDistanceMatch(candidate: b.candidate, distance: b.distance, isHighConfidence: confident)
    }

    /// True when `b` is exactly `a` with one adjacent pair swapped (e.g. "teh" and
    /// "the"). Used as a tie-breaker to favor the classic transposition typo.
    private static func isSingleAdjacentTransposition(_ a: String, _ b: String) -> Bool {
        let aChars = Array(a)
        let bChars = Array(b)
        guard aChars.count == bChars.count, aChars.count > 1 else { return false }
        var diff = 0
        var first = -1
        var second = -1
        for i in 0..<aChars.count where aChars[i] != bChars[i] {
            diff += 1
            if diff == 1 { first = i } else if diff == 2 { second = i } else { return false }
        }
        return diff == 2 && abs(first - second) == 1
    }

    /// Optimal-string-alignment Damerau-Levenshtein distance between two words.
    /// Adjacent transposition counts as a single edit (what a typist means by
    /// "teh" for "the"), so OSA is the right model for keyboard errors.
    ///
    /// The three row buffers are caller-provided and reused across candidates to
    /// avoid allocation on the hot path; they must be at least `b.count + 1` wide.
    static func damerauLevenshtein(
        _ aChars: [Character],
        _ bChars: [Character],
        _ prev: inout [Int],
        _ prev2: inout [Int],
        _ cur: inout [Int]
    ) -> Int {
        let n = aChars.count
        let m = bChars.count
        guard n > 0 else { return m }
        guard m > 0 else { return n }

        // Initialize rows for this candidate (no allocation, just refill).
        for j in 0...m { prev[j] = j; prev2[j] = 0; cur[j] = 0 }

        for i in 1...n {
            cur[0] = i
            for j in 1...m {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                let deletion = prev[j] + 1
                let insertion = cur[j - 1] + 1
                let substitution = prev[j - 1] + cost
                var best = min(min(deletion, insertion), substitution)

                // Transposition: a[i-2] b[j-1] swapped to match.
                if i > 1, j > 1,
                   aChars[i - 1] == bChars[j - 2],
                   aChars[i - 2] == bChars[j - 1] {
                    best = min(best, prev2[j - 2] + 1)
                }
                cur[j] = best
            }
            swap(&prev2, &prev)
            swap(&prev, &cur)
        }
        return prev[m]
    }

    // MARK: - Built-in dictionary (~1000 common English words).

    /// A curated common-English dictionary embedded for the fast path. Kept small
    /// and static so it costs nothing at runtime and is deterministic. Includes the
    /// classic misspelling targets the tests exercise. Lowercase only — matching
    /// lowercases the input.
    static let dictionary: Set<String> = [
        "a", "about", "above", "accept", "account", "across", "act", "action", "active",
        "add", "address", "admit", "adult", "advice", "affect", "afraid", "after", "afternoon",
        "again", "against", "age", "agency", "ago", "agree", "air", "all", "allow", "almost",
        "alone", "along", "already", "also", "although", "always", "am", "american", "among",
        "amount", "analysis", "and", "animal", "answer", "any", "anyone", "anything", "appear",
        "apple", "apply", "approach", "area", "argue", "arm", "around", "arrive", "art",
        "article", "as", "ask", "at", "attack", "attention", "authority", "available", "avoid",
        "away", "baby", "back", "bad", "bag", "ball", "bank", "bar", "base", "basket",
        "be", "bear", "beat", "beautiful", "because", "become", "bed", "before", "begin",
        "behavior", "behind", "believe", "benefit", "best", "better", "between", "beyond", "big",
        "bill", "bird", "bit", "black", "blood", "blue", "board", "body", "book", "born",
        "both", "box", "boy", "break", "bring", "brother", "budget", "build", "building", "business",
        "but", "buy", "call", "camera", "campaign", "can", "cancer", "candidate", "car", "card",
        "care", "career", "carry", "case", "catch", "cause", "cell", "center", "central", "century",
        "certain", "certainly", "chair", "challenge", "chance", "change", "character", "charge", "check", "chicken",
        "child", "choose", "church", "citizen", "city", "civil", "claim", "class", "clear", "clearly",
        "close", "coach", "cold", "collection", "college", "color", "come", "commercial", "common", "community",
        "company", "compare", "computer", "concern", "condition", "conference", "consider", "consumer", "contain", "continue",
        "control", "cost", "could", "country", "couple", "course", "court", "cover", "create", "crime",
        "cultural", "culture", "cup", "current", "customer", "cut", "dark", "data", "daughter", "day",
        "dead", "deal", "death", "debate", "decade", "decide", "decision", "deep", "defense", "degree",
        "democrat", "democratic", "describe", "design", "desire", "detail", "develop", "development", "die", "difference",
        "different", "difficult", "dinner", "direction", "director", "discover", "discuss", "discussion", "disease", "doctor",
        "dog", "door", "down", "draw", "dream", "drive", "drop", "drug", "during", "each",
        "early", "east", "easy", "eat", "economic", "economy", "edge", "education", "effect", "effort",
        "eight", "either", "election", "else", "employee", "end", "energy", "enjoy", "enough", "enter",
        "entire", "environment", "environmental", "especially", "establish", "even", "evening", "event", "ever", "every",
        "everybody", "everyone", "everything", "evidence", "exactly", "example", "executive", "exist", "expect", "experience",
        "expert", "explain", "eye", "face", "fact", "factor", "fail", "fall", "family", "far",
        "fast", "father", "fear", "federal", "feel", "feeling", "field", "fight", "figure", "fill",
        "film", "final", "finally", "financial", "find", "fine", "finger", "finish", "fire", "firm",
        "first", "fish", "five", "floor", "fly", "focus", "follow", "food", "foot", "football",
        "for", "force", "foreign", "forget", "form", "former", "forward", "four", "free", "friend",
        "from", "front", "full", "fund", "future", "game", "garden", "gas", "general", "generation",
        "get", "girl", "give", "glass", "goal", "good", "government", "great", "green", "ground",
        "group", "grow", "growth", "guess", "gun", "guy", "hair", "half", "hand", "hang",
        "happen", "happy", "hard", "have", "head", "health", "hear", "heart", "heat", "heavy",
        "help", "hello", "her", "here", "herself", "high", "him", "himself", "his", "history", "hit",
        "hold", "home", "hope", "hospital", "hot", "hotel", "hour", "house", "how", "however",
        "huge", "human", "hundred", "husband", "idea", "identify", "image", "imagine", "impact", "important",
        "improve", "in", "include", "including", "increase", "indeed", "indicate", "individual", "industry", "information",
        "inside", "instead", "institution", "interest", "interesting", "international", "interview", "into", "investment", "involve",
        "issue", "it", "item", "its", "itself", "job", "join", "just", "keep", "key",
        "kid", "kill", "kind", "kitchen", "know", "knowledge", "land", "language", "large", "last",
        "late", "later", "laugh", "law", "lawyer", "lay", "lead", "leader", "learn", "least",
        "leave", "left", "leg", "legal", "less", "let", "letter", "level", "life", "light",
        "like", "likely", "line", "list", "listen", "little", "live", "local", "long", "look",
        "lose", "loss", "lot", "love", "low", "machine", "magazine", "main", "maintain", "major",
        "majority", "make", "man", "manage", "management", "manager", "many", "market", "marriage", "material",
        "matter", "may", "maybe", "me", "mean", "measure", "media", "medical", "meet", "meeting",
        "member", "memory", "mention", "message", "method", "middle", "might", "military", "million", "mind",
        "minute", "miss", "mission", "model", "modern", "moment", "money", "month", "more", "morning",
        "most", "mother", "mouth", "move", "movement", "movie", "much", "music", "must", "my",
        "myself", "name", "nation", "national", "natural", "nature", "near", "nearly", "necessary", "need",
        "network", "never", "new", "news", "newspaper", "next", "nice", "night", "nine", "no",
        "none", "north", "not", "note", "nothing", "notice", "now", "number", "occur", "off",
        "offer", "office", "officer", "official", "often", "oil", "ok", "old", "on", "once",
        "one", "only", "onto", "open", "operation", "opportunity", "option", "or", "order", "organization",
        "other", "others", "our", "out", "outside", "over", "own", "owner", "page", "pain",
        "painting", "paper", "parent", "part", "participant", "particular", "particularly", "party", "pass", "past",
        "patient", "pattern", "pay", "peace", "people", "per", "perform", "performance", "perhaps", "period",
        "person", "personal", "phone", "physical", "pick", "picture", "piece", "place", "plan", "plant",
        "play", "player", "point", "police", "policy", "political", "politics", "poor", "popular", "population",
        "position", "positive", "possible", "power", "practice", "prepare", "present", "president", "pressure", "pretty",
        "prevent", "price", "private", "probably", "problem", "process", "produce", "product", "production", "professional",
        "professor", "program", "project", "property", "protect", "prove", "provide", "public", "pull", "purpose",
        "push", "put", "quality", "question", "quickly", "quite", "race", "radio", "raise", "range",
        "rate", "rather", "reach", "read", "ready", "real", "reality", "realize", "really", "reason",
        "receive", "recent", "recently", "recognize", "record", "red", "reduce", "reflect", "region", "relate",
        "relationship", "religious", "remain", "remember", "remove", "report", "represent", "republican", "require", "research",
        "resource", "respond", "response", "responsibility", "rest", "result", "return", "reveal", "rich", "right",
        "rise", "risk", "road", "rock", "role", "room", "rule", "run", "same", "save",
        "say", "scene", "school", "science", "scientist", "score", "sea", "season", "seat", "second",
        "section", "security", "see", "seek", "seem", "sell", "send", "senior", "sense", "series",
        "serious", "serve", "service", "set", "seven", "several", "sex", "sexual", "shake", "share",
        "she", "shoot", "short", "shot", "should", "shoulder", "show", "side", "sign", "significant",
        "similar", "simple", "simply", "since", "sing", "single", "sister", "sit", "site", "situation",
        "six", "size", "skin", "small", "smile", "so", "social", "society", "soldier", "some",
        "somebody", "someone", "something", "sometimes", "son", "song", "soon", "sort", "sound", "source",
        "south", "southern", "space", "speak", "special", "specific", "speech", "spend", "sport", "spring",
        "staff", "stage", "stand", "standard", "star", "start", "state", "statement", "station", "stay",
        "step", "still", "stock", "stop", "store", "story", "strategy", "street", "strong", "structure",
        "student", "study", "stuff", "style", "subject", "success", "successful", "such", "suddenly", "suffer",
        "suggest", "summer", "support", "sure", "surface", "system", "table", "take", "talk", "task",
        "tax", "teach", "teacher", "team", "technology", "television", "tell", "ten", "tend", "term",
        "test", "than", "thank", "that", "the", "their", "them", "themselves", "then", "theory",
        "there", "these", "they", "thing", "think", "third", "this", "those", "though", "thought",
        "thousand", "threat", "three", "through", "throughout", "throw", "thus", "time", "to", "today",
        "together", "tonight", "too", "top", "total", "tough", "toward", "town", "trade", "tradition",
        "traditional", "training", "travel", "treat", "treatment", "tree", "trial", "trip", "trouble", "true",
        "truth", "try", "turn", "two", "type", "under", "understand", "unit", "until", "up",
        "upon", "us", "use", "usually", "value", "various", "very", "victim", "view", "violence",
        "visit", "voice", "vote", "wait", "walk", "wall", "want", "war", "watch", "water",
        "way", "we", "weapon", "wear", "week", "weight", "well", "west", "western", "what",
        "whatever", "when", "where", "whether", "which", "while", "white", "who", "whole", "whom",
        "whose", "why", "wide", "wife", "will", "win", "wind", "window", "wish", "with",
        "within", "without", "woman", "wonder", "word", "work", "worker", "world", "worry", "would",
        "write", "writer", "wrong", "yard", "yeah", "year", "yes", "yet", "you", "young",
        "your", "yourself",
        // Classic misspelling targets exercised by the tests.
        "accommodate", "definitely", "friend", "occurred", "recommend", "separate", "world",
    ]
}

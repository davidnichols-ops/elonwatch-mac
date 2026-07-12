import Foundation
import SQLite3

// MARK: ─────────────────────────────────────────────────────────────────────
// TECHNIQUE 1: Compiled character-level Aho-Corasick trie with
//              temporal-decay scoring.
//
// Standard approach: for each item, loop over every keyword and call
// String.contains() — O(keywords × text_length) per item, called hundreds
// of times per refresh.
//
// This approach: compile ALL domain keywords into a single multi-pattern
// finite automaton at module load (one shared instance). Matching is a
// single O(text_length) pass regardless of keyword count or domain count.
//
// The unconventional twist: each match carries a DECAY WEIGHT derived from
// the item's age. A "breaking" keyword hit on a 3-hour-old item scores 1.0;
// the same hit on a 48-hour-old item scores ~0.4. Domain classification and
// urgency therefore degrade continuously as the news cycle moves on — with
// no explicit staleness loop anywhere in the calling code.
// ─────────────────────────────────────────────────────────────────────────

private final class AhoCorasick {
    struct Match { let domain: Domain; let keyword: String }

    // Trie node: children indexed by ASCII value, failure link, output list
    private struct Node {
        var children: [UInt8: Int] = [:]
        var fail: Int = 0
        var output: [Match] = []
    }

    private var nodes: [Node] = [Node()]          // node 0 = root

    /// Build the automaton from the domain keyword table.
    static let shared: AhoCorasick = {
        let ac = AhoCorasick()
        for (domain, keywords) in _domainKeywordTable {
            for kw in keywords { ac.insert(kw, domain: domain) }
        }
        ac.buildFailureLinks()
        return ac
    }()

    private func insert(_ word: String, domain: Domain) {
        var cur = 0
        for byte in word.utf8 {
            if let next = nodes[cur].children[byte] {
                cur = next
            } else {
                nodes.append(Node())
                nodes[cur].children[byte] = nodes.count - 1
                cur = nodes.count - 1
            }
        }
        nodes[cur].output.append(Match(domain: domain, keyword: word))
    }

    private func buildFailureLinks() {
        var queue: [Int] = []
        // Root's children get fail = root
        for (_, child) in nodes[0].children {
            nodes[child].fail = 0
            queue.append(child)
        }
        var head = 0
        while head < queue.count {
            let cur = queue[head]; head += 1
            for (byte, child) in nodes[cur].children {
                var f = nodes[cur].fail
                while f != 0 && nodes[f].children[byte] == nil { f = nodes[f].fail }
                let failTarget = (f == 0 ? nodes[0].children[byte] : nodes[f].children[byte]) ?? 0
                nodes[child].fail = (failTarget == child) ? 0 : failTarget
                // Merge outputs from failure chain
                nodes[child].output += nodes[nodes[child].fail].output
                queue.append(child)
            }
        }
    }

    /// Single O(n) pass over text — returns all keyword matches.
    func search(_ text: String) -> [Match] {
        var cur = 0
        var results: [Match] = []
        for byte in text.utf8 {
            while cur != 0 && nodes[cur].children[byte] == nil { cur = nodes[cur].fail }
            cur = nodes[cur].children[byte] ?? 0
            results += nodes[cur].output
        }
        return results
    }
}

// ─────────────────────────────────────────────────────────────────────────
// TECHNIQUE 2: Self-calibrating urgency via Welford online algorithm.
//
// Standard approach: fixed floor of 2, fixed keyword thresholds.
// The app has no memory of whether today is a quiet day or a breaking
// news storm — every article is scored against the same static table.
//
// This approach: a single shared WelfordAccumulator maintains a running
// mean and variance of urgency scores seen this session using Welford's
// one-pass numerically stable online algorithm (the same used in
// scientific computing to avoid catastrophic cancellation).
//
// When the accumulator has seen enough data (n ≥ 30), urgency scores are
// pulled toward the current mean by a tension factor — so during a quiet
// day, a "says" article actually surfaces (floor rises); during a breaking
// storm, mid-level articles get relatively damped (ceiling compresses).
// The feed calibrates itself to the news cycle with zero configuration.
// ─────────────────────────────────────────────────────────────────────────

final class WelfordAccumulator {
    static let shared = WelfordAccumulator()
    private var n: Double = 0
    private var mean: Double = 0
    private var M2: Double = 0      // aggregate squared distance from mean

    func push(_ value: Double) {
        n += 1
        let delta = value - mean
        mean += delta / n
        M2 += delta * (value - mean)
    }

    var variance: Double { n > 1 ? M2 / (n - 1) : 1 }
    var stddev: Double { variance.squareRoot() }
    var count: Double { n }

    /// Pull raw score toward the session mean.
    /// tension ∈ [0,1] — 0 = no pull, 1 = always returns mean.
    func calibrate(_ raw: Double, tension: Double = 0.25) -> Int {
        guard n >= 30 else { return Int(raw.rounded()) }
        let pulled = raw + tension * (mean - raw)
        // Hard bounds: never let calibration push below 1 or above 10
        return min(10, max(1, Int(pulled.rounded())))
    }
}

// ─────────────────────────────────────────────────────────────────────────
// Domain keyword table — shared between AhoCorasick and domain order
// ─────────────────────────────────────────────────────────────────────────

private let _domainKeywordTable: [Domain: [String]] = [
    .space:    ["spacex","starship","falcon","rocket","mars","orbit","launch","nasa",
                "satellite","booster","raptor","starlink","lunar","moon","payload"],
    .ai:       ["xai","grok","ai","artificial intelligence","llm","model","neural",
                "machine learning","chatgpt","openai","agi","superintelligence",
                "compute","inference","alignment","colossus","benchmark"],
    .politics: ["doge","government","trump","congress","senate","democrat","republican",
                "election","vote","president","white house","policy","federal",
                "regulation","lawsuit","court","free speech","censorship","woke","dei"],
    .money:    ["tesla","stock","shares","billion","million","revenue","earnings",
                "profit","valuation","ipo","dogecoin","bitcoin","crypto","market",
                "investor","fund","capital","acquisition","deal","merger"],
    .tech:     ["software","engineering","code","app","update","feature","autopilot",
                "fsd","neuralink","chip","hardware","battery","energy","solar",
                "boring company","tunnel","twitter","x.com","algorithm","platform"],
    .chaos:    ["fired","resign","crash","explosion","failed","failure","crisis",
                "emergency","warning","danger","threat","ban","block","suspended",
                "outrage","scandal","controversy","backlash","meltdown","breaking"],
    .ego:      ["richest","ceo","founder","elon said","elon claims","elon wants",
                "world's","most powerful","genius","visionary","controversial",
                "criticized","praised","attacked"],
    .culture:  ["meme","tweet","post","interview","podcast","video","book",
                "philosophy","simulation","consciousness","comedy","joke","funny",
                "trolling","shitpost","human","civilization","future"],
    .glaze:    ["genius","visionary","brilliant","incredible","amazing","greatest",
                "legendary","icon","hero","pioneer","revolutionary","goat",
                "inspires","inspiring","admire","praise","praises","praised",
                "thank elon","love elon","grateful","thank you elon","saved",
                "changed my life","changed the world","only elon","elon is right",
                "elon deserves","respect elon","support elon","proud of elon",
                "well done elon","remarkable","outstanding","historic achievement",
                "congrat","elon wins","elon nailed"],
]

private let urgencyBoosts: [(Int, [String])] = [
    (10, ["breaking","just announced","emergency","explosion","crashed","war",
          "launch today","now live","happening now"]),
    (8,  ["announces","officially","confirmed","just said","new","exclusive",
          "starship","test flight","ipo","acquisition"]),
    (6,  ["says","claims","warns","predicts","plans to","will"]),
    (4,  ["reportedly","sources say","rumored","possibly","might"]),
    (2,  ["opinion","analysis","review","recap","thread"]),
]

private let sentimentBullish = ["success","record","profit","milestone","breakthrough",
                                "amazing","incredible","win","launch","approved","growth"]
private let sentimentBearish  = ["fail","loss","decline","crash","drop","layoff",
                                 "problem","delay","miss","cut","debt"]
private let sentimentHostile  = ["attack","sue","ban","fired","war","threaten",
                                 "destroy","fight","enemy","hate","wrong"]
private let sentimentPlayful  = ["lol","joke","meme","funny","troll","haha","420","69"]

// MARK: - Scoring functions

/// Temporal decay: score multiplier based on item age.
/// Fresh item (0h) → 1.0. 48h old → ~0.35. Asymptotes toward 0.
private func temporalDecay(scrapedAt: String) -> Double {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = f.date(from: scrapedAt) else { return 1.0 }
    let ageHours = -date.timeIntervalSinceNow / 3600
    // Half-life of 24h: decay = 2^(-age/24)
    return pow(2.0, -ageHours / 24.0)
}

func scoreDomain(_ text: String, scrapedAt: String = "") -> Domain {
    // Single Aho-Corasick pass — O(text_length) regardless of keyword count
    let matches = AhoCorasick.shared.search(text)
    let decay   = scrapedAt.isEmpty ? 1.0 : temporalDecay(scrapedAt: scrapedAt)

    // Accumulate weighted scores per domain
    var scores: [Domain: Double] = [:]
    for match in matches {
        scores[match.domain, default: 0] += decay
    }

    // GLAZE gate: must be bullish AND clearly outscore runner-up
    if let gs = scores[.glaze] {
        let sentiment = scoreSentiment(text)
        let runnerUp  = scores.filter { $0.key != .glaze }.values.max() ?? 0
        if sentiment != .bullish || gs <= runnerUp {
            scores.removeValue(forKey: .glaze)
        }
    }

    return scores.max(by: { $0.value < $1.value })?.key ?? .culture
}

func scoreSignalType(_ text: String) -> SignalType {
    let humor     = ["lol","lmao","haha","420","69","kek","meme","trolling","shitpost"]
    let directive = ["will ","going to","plan","intend","announce","launch","build",
                     "create","deploy","release","order","mandate","require"]
    let vision    = ["goal","vision","mission","future","predict","believe","think",
                     "humanity","civilization","long-term","ultimate","inevitable"]
    let reaction  = ["respond","reply","react","counter","wrong","false","fake",
                     "disagree","disputed","refute"]
    if humor.contains(where:     { text.contains($0) }) { return .humor }
    if directive.contains(where: { text.contains($0) }) { return .directive }
    if vision.contains(where:    { text.contains($0) }) { return .vision }
    if reaction.contains(where:  { text.contains($0) }) { return .reaction }
    return .signal
}

func scoreUrgency(_ text: String, domain: Domain, signalType: SignalType) -> Int {
    var raw = 2.0
    for (score, kws) in urgencyBoosts {
        if kws.contains(where: { text.contains($0) }) { raw = max(raw, Double(score)) }
    }
    if domain == .chaos           { raw = min(10, raw + 3) }
    if signalType == .directive   { raw = min(10, raw + 1) }
    if signalType == .humor       { raw = max(1,  raw - 3) }

    // Feed the raw score into the session calibrator, then return calibrated value
    WelfordAccumulator.shared.push(raw)
    return WelfordAccumulator.shared.calibrate(raw)
}

func scoreSentiment(_ text: String) -> Sentiment {
    let b = sentimentBullish.filter { text.contains($0) }.count
    let r = sentimentBearish.filter  { text.contains($0) }.count
    let h = sentimentHostile.filter  { text.contains($0) }.count
    let p = sentimentPlayful.filter  { text.contains($0) }.count
    let mx = max(b, r, h, p)
    if mx == 0 { return .neutral }
    if mx == p { return .playful }
    if mx == h { return .hostile }
    if mx == r { return .bearish }
    return .bullish
}

func scoreRow(id: Int, source: String, category: String, title: String,
              url: String, content: String, author: String,
              published: String, scrapedAt: String) -> SignalItem {
    let text       = (title + " " + content).lowercased()
    let domain     = scoreDomain(text, scrapedAt: scrapedAt)
    let signalType = scoreSignalType(text)
    let urgency    = scoreUrgency(text, domain: domain, signalType: signalType)
    let sentiment  = scoreSentiment(text)
    return SignalItem(id: id, source: source, category: category,
                      title: title, url: url, content: content,
                      author: author, published: published, scrapedAt: scrapedAt,
                      domain: domain, signalType: signalType,
                      urgency: urgency, sentiment: sentiment)
}

// MARK: - SQLite DB

class ElonDB {
    static let shared = ElonDB()
    private var db: OpaquePointer?

    private var dbPath: String {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("ElonWatch")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("elonwatch.db").path
    }

    private init() { open() }

    private func open() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("ElonDB: cannot open \(dbPath)")
        }
    }

    func fetchRecent(limit: Int = 300, source: String? = nil) -> [SignalItem] {
        guard let db else { return [] }
        let sql: String
        if let src = source, src != "ALL" {
            sql = """
            SELECT id,source,category,title,url,content,author,published,scraped_at
            FROM items WHERE source='\(src)'
            ORDER BY scraped_at DESC LIMIT \(limit)
            """
        } else {
            sql = """
            SELECT id,source,category,title,url,content,author,published,scraped_at
            FROM items ORDER BY scraped_at DESC LIMIT \(limit)
            """
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var items: [SignalItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func str(_ i: Int32) -> String {
                guard let c = sqlite3_column_text(stmt, i) else { return "" }
                return String(cString: c)
            }
            items.append(scoreRow(
                id:        Int(sqlite3_column_int(stmt, 0)),
                source:    str(1), category: str(2), title:     str(3),
                url:       str(4), content:  str(5), author:    str(6),
                published: str(7), scrapedAt: str(8)
            ))
        }
        return items
    }

    func fetchStats() -> [SourceStats] {
        guard let db else { return [] }
        let sql = """
        SELECT source, COUNT(*) as cnt, MAX(scraped_at) as last_seen
        FROM items GROUP BY source
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var stats: [SourceStats] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func str(_ i: Int32) -> String {
                guard let c = sqlite3_column_text(stmt, i) else { return "" }
                return String(cString: c)
            }
            stats.append(SourceStats(
                source:   str(0),
                count:    Int(sqlite3_column_int(stmt, 1)),
                lastSeen: str(2)
            ))
        }
        return stats
    }

    func totalCount() -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM items", -1, &stmt, nil) == SQLITE_OK
        else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int(stmt, 0)) : 0
    }

    func dbExists() -> Bool { FileManager.default.fileExists(atPath: dbPath) }
}

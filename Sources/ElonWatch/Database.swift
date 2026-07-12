import Foundation
import SQLite3

// MARK: - Brain scorer (pure Swift port of brain.py)

private let domainKeywords: [Domain: [String]] = [
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

func scoreDomain(_ text: String) -> Domain {
    var scores: [Domain: Int] = [:]
    for (domain, kws) in domainKeywords {
        let score = kws.filter { text.contains($0) }.count
        if score > 0 { scores[domain] = score }
    }

    // GLAZE only fires when the content is actually positive.
    // If GLAZE would win on keyword count but sentiment isn't bullish, remove it
    // and fall back to the second-best domain.
    if let glazeScore = scores[.glaze] {
        let sentiment = scoreSentiment(text)
        if sentiment != .bullish {
            scores.removeValue(forKey: .glaze)
        } else {
            // Even when bullish, require GLAZE to clearly beat the runner-up
            // so a mildly-positive CHAOS article doesn't get reclassified.
            let runnerUp = scores.filter { $0.key != .glaze }.values.max() ?? 0
            if glazeScore <= runnerUp {
                scores.removeValue(forKey: .glaze)
            }
        }
    }

    return scores.max(by: { $0.value < $1.value })?.key ?? .culture
}

func scoreSignalType(_ text: String) -> SignalType {
    let humor = ["lol","lmao","haha","420","69","kek","meme","trolling","shitpost"]
    if humor.contains(where: { text.contains($0) }) { return .humor }
    let directive = ["will ","going to","plan","intend","announce","launch","build",
                     "create","deploy","release","order","mandate","require"]
    if directive.contains(where: { text.contains($0) }) { return .directive }
    let vision = ["goal","vision","mission","future","predict","believe","think",
                  "humanity","civilization","long-term","ultimate","inevitable"]
    if vision.contains(where: { text.contains($0) }) { return .vision }
    let reaction = ["respond","reply","react","counter","wrong","false","fake",
                    "disagree","disputed","refute"]
    if reaction.contains(where: { text.contains($0) }) { return .reaction }
    return .signal
}

func scoreUrgency(_ text: String, domain: Domain, signalType: SignalType) -> Int {
    var urgency = 2
    for (score, kws) in urgencyBoosts {
        if kws.contains(where: { text.contains($0) }) {
            urgency = max(urgency, score)
        }
    }
    if domain == .chaos    { urgency = min(10, urgency + 3) }
    if signalType == .directive { urgency = min(10, urgency + 1) }
    if signalType == .humor { urgency = max(1, urgency - 3) }
    return urgency
}

func scoreSentiment(_ text: String) -> Sentiment {
    let b = sentimentBullish.filter { text.contains($0) }.count
    let r = sentimentBearish.filter { text.contains($0) }.count
    let h = sentimentHostile.filter { text.contains($0) }.count
    let p = sentimentPlayful.filter { text.contains($0) }.count
    let mx = max(b, r, h, p)
    if mx == 0   { return .neutral }
    if mx == p   { return .playful }
    if mx == h   { return .hostile }
    if mx == r   { return .bearish }
    return .bullish
}

func scoreRow(id: Int, source: String, category: String, title: String,
              url: String, content: String, author: String,
              published: String, scrapedAt: String) -> SignalItem {
    let text = (title + " " + content).lowercased()
    let domain      = scoreDomain(text)
    let signalType  = scoreSignalType(text)
    let urgency     = scoreUrgency(text, domain: domain, signalType: signalType)
    let sentiment   = scoreSentiment(text)
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
        try? FileManager.default.createDirectory(
            at: support, withIntermediateDirectories: true)
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
            let item = scoreRow(
                id:        Int(sqlite3_column_int(stmt, 0)),
                source:    str(1), category: str(2), title:     str(3),
                url:       str(4), content:  str(5), author:    str(6),
                published: str(7), scrapedAt: str(8)
            )
            items.append(item)
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

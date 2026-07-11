import Foundation

// MARK: - Signal Item (mirrors DB row + brain scoring)

struct SignalItem: Identifiable, Equatable {
    let id: Int
    let source: String
    let category: String
    let title: String
    let url: String
    let content: String
    let author: String
    let published: String
    let scrapedAt: String

    // Brain-scored fields
    let domain: Domain
    let signalType: SignalType
    let urgency: Int        // 0-10
    let sentiment: Sentiment
}

// MARK: - Domain

enum Domain: String, CaseIterable {
    case space    = "SPACE"
    case ai       = "AI"
    case politics = "POLITICS"
    case money    = "MONEY"
    case tech     = "TECH"
    case chaos    = "CHAOS"
    case ego      = "EGO"
    case culture  = "CULTURE"

    var icon: String {
        switch self {
        case .space:    return "🚀"
        case .ai:       return "🧠"
        case .politics: return "⚡"
        case .money:    return "◈"
        case .tech:     return "⬡"
        case .chaos:    return "!!"
        case .ego:      return "★"
        case .culture:  return "◉"
        }
    }

    var color: String {
        switch self {
        case .space:    return "#00e5ff"
        case .ai:       return "#e040fb"
        case .politics: return "#ffea00"
        case .money:    return "#69ff47"
        case .tech:     return "#40c4ff"
        case .chaos:    return "#ff1744"
        case .ego:      return "#ffd740"
        case .culture:  return "#ffffff"
        }
    }
}

// MARK: - Signal Type

enum SignalType: String, CaseIterable {
    case directive = "DIRECTIVE"
    case vision    = "VISION"
    case reaction  = "REACTION"
    case humor     = "HUMOR"
    case signal    = "SIGNAL"
    case noise     = "NOISE"
}

// MARK: - Sentiment

enum Sentiment: String, CaseIterable {
    case bullish  = "BULLISH"
    case bearish  = "BEARISH"
    case hostile  = "HOSTILE"
    case playful  = "PLAYFUL"
    case neutral  = "NEUTRAL"

    var color: String {
        switch self {
        case .bullish:  return "#69ff47"
        case .bearish:  return "#ff5252"
        case .hostile:  return "#ff1744"
        case .playful:  return "#e040fb"
        case .neutral:  return "#546e7a"
        }
    }
}

// MARK: - Source

enum Source: String, CaseIterable {
    case twitter    = "twitter"
    case googleNews = "google-news"
    case reddit     = "reddit"
    case all        = "ALL"

    var icon: String {
        switch self {
        case .twitter:    return "𝕏"
        case .googleNews: return "◉"
        case .reddit:     return "⬡"
        case .all:        return "◈"
        }
    }

    var label: String {
        switch self {
        case .twitter:    return "Twitter/X"
        case .googleNews: return "Google News"
        case .reddit:     return "Reddit"
        case .all:        return "All Sources"
        }
    }
}

// MARK: - Stats

struct SourceStats {
    let source: String
    let count: Int
    let lastSeen: String
}

struct BrainStats {
    let domainCounts: [Domain: Int]
    let signalTypeCounts: [SignalType: Int]
    let sentimentCounts: [Sentiment: Int]
    let avgUrgency: Double
    let highSignalCount: Int
    let totalCount: Int
}

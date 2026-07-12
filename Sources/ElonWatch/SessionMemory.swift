import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  SessionMemory — attention field tracker
//
//  The feed knows what happened. It doesn't know what you noticed.
//
//  Every item you open gets recorded here. From that, we maintain a
//  continuous probability distribution over domains — your *attention field*
//  for this session. The feed uses it to quietly reorder itself toward
//  what you've shown you care about.
//
//  No configuration. No UI. No persistence across launches.
//  It only knows you within the window of time you're actually here.
//  When you quit, it forgets everything.
//
//  The reordering is intentionally subtle: urgency still dominates,
//  recency still matters. The attention field is a soft thumb on the scale,
//  not a takeover. You might never consciously notice it. That's the point.
//
//  Implementation note: domain weights use exponential moving average
//  with α=0.3 so early clicks don't permanently dominate — your attention
//  can shift within a session and the field follows.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class SessionMemory {
    static let shared = SessionMemory()

    // EMA weight for each domain — starts uniform, drifts with your clicks
    private var weights: [Domain: Double] = {
        var w: [Domain: Double] = [:]
        for d in Domain.allCases { w[d] = 1.0 / Double(Domain.allCases.count) }
        return w
    }()

    private let α: Double = 0.3       // EMA learning rate
    private var totalEngagements: Int = 0

    private init() {}

    // Called whenever the user opens an item
    func recordEngagement(with item: SignalItem) {
        totalEngagements += 1

        // Reinforce the engaged domain, decay all others
        for domain in Domain.allCases {
            let signal: Double = (domain == item.domain) ? 1.0 : 0.0
            weights[domain] = α * signal + (1 - α) * (weights[domain] ?? 0)
        }

        // Re-normalise so weights always sum to 1.0
        let total = weights.values.reduce(0, +)
        if total > 0 {
            for domain in Domain.allCases {
                weights[domain]! /= total
            }
        }
    }

    // Attention weight for a given domain — [0, 1], uniform before any clicks
    func attentionWeight(for domain: Domain) -> Double {
        weights[domain] ?? (1.0 / Double(Domain.allCases.count))
    }

    // Whether we have enough signal to meaningfully reorder
    var isCalibrated: Bool { totalEngagements >= 3 }

    // Composite score used to sort the feed.
    //
    // Before calibration: pure urgency + recency (same as before).
    // After calibration: urgency still dominates, but attention weight
    // applies a multiplier that can move an item up or down by roughly
    // one urgency tier — enough to surface your domains, not enough to
    // bury breaking news.
    //
    // Score decomposition:
    //   urgency   (0–10)  × 1.0   — the anchor
    //   attention (0–1)   × 3.5   — up to ~1/3 of an urgency tier of lift
    //   recency             bonus  — exponential decay, 2h half-life
    func score(for item: SignalItem) -> Double {
        let urgencyScore    = Double(item.urgency)
        let attentionScore  = isCalibrated ? attentionWeight(for: item.domain) * 3.5 : 0
        let recencyScore    = recencyBonus(item.scrapedAt)
        return urgencyScore + attentionScore + recencyScore
    }

    private func recencyBonus(_ scrapedAt: String) -> Double {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: scrapedAt) else { return 0 }
        let ageHours = -date.timeIntervalSinceNow / 3600
        // 2h half-life, max bonus 1.5 (a fresh item gets +1.5 score points)
        return 1.5 * pow(2.0, -ageHours / 2.0)
    }
}

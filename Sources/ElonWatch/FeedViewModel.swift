import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var items:       [SignalItem] = []
    @Published var brainStats:  BrainStats?
    @Published var sourceStats: [SourceStats] = []
    @Published var totalCount   = 0
    @Published var activeSource: String = "ALL"
    @Published var activeDomain: String? = nil

    private var refreshTimer: Timer?
    private var seenIDs: Set<Int> = []

    init() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)

        NotificationCenter.default.addObserver(
            forName: .scrapeCompleted, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.refresh()
                if let count = note.userInfo?["count"] as? Int, count > 0 {
                    self?.checkForNewHighSignal()
                }
            }
        }
    }

    func refresh() {
        let src = activeSource == "ALL" ? nil : activeSource
        var fetched = ElonDB.shared.fetchRecent(limit: 300, source: src)
        if let domain = activeDomain {
            fetched = fetched.filter { $0.domain.rawValue == domain }
        }
        items       = fetched
        sourceStats = ElonDB.shared.fetchStats()
        totalCount  = ElonDB.shared.totalCount()
        brainStats  = computeBrainStats(fetched)

        // Seed seen IDs
        if seenIDs.isEmpty {
            seenIDs = Set(fetched.map { $0.id })
        }
    }

    func setSource(_ source: String) {
        activeSource = source
        activeDomain = nil
        refresh()
    }

    func setDomain(_ domain: String?) {
        activeDomain = domain
        activeSource = "ALL"
        refresh()
    }

    private func checkForNewHighSignal() {
        let recent = ElonDB.shared.fetchRecent(limit: 100)
        for item in recent where !seenIDs.contains(item.id) {
            seenIDs.insert(item.id)
            NotificationManager.maybeNotify(item)
        }
    }

    private func computeBrainStats(_ items: [SignalItem]) -> BrainStats {
        var dc: [Domain: Int]      = [:]
        var sc: [SignalType: Int]  = [:]
        var se: [Sentiment: Int]   = [:]
        var urgSum = 0
        var highSig = 0

        for item in items {
            dc[item.domain, default: 0] += 1
            sc[item.signalType, default: 0] += 1
            se[item.sentiment, default: 0] += 1
            urgSum += item.urgency
            if item.urgency >= 7 || item.domain == .chaos { highSig += 1 }
        }

        return BrainStats(
            domainCounts:      dc,
            signalTypeCounts:  sc,
            sentimentCounts:   se,
            avgUrgency:        items.isEmpty ? 0 : Double(urgSum) / Double(items.count),
            highSignalCount:   highSig,
            totalCount:        totalCount
        )
    }
}

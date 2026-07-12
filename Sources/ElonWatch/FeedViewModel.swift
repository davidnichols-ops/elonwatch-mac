import SwiftUI
import Combine

// MARK: ─────────────────────────────────────────────────────────────────────
// TECHNIQUE 3: @dynamicMemberLookup reactive filter lens.
//
// Standard approach: ViewModel owns `activeSource`, `activeDomain`, and
// an explicit `refresh()` that must be called manually after every mutation.
// Any new filter dimension requires: a new @Published property, a new setter
// method, a new refresh() call site, and manual coordination of which fields
// reset which other fields.
//
// This approach: FilterLens is a value type tagged with @dynamicMemberLookup.
// The ViewModel holds ONE @Published lens. Any write to any filter field on
// the lens automatically publishes through a single Combine pipeline that
// debounces, deduplicates, and fires the DB query — zero manual refresh()
// calls anywhere. Adding a new filter dimension is ONE new property on the
// lens struct, and nothing else changes.
//
// The lens is also a pure projection: `lens.items` and `lens.brainStats`
// are computed properties that re-derive lazily from the raw DB results.
// There is no separate "filtered items" array — the filtered view IS the
// lens. The UI reads directly from it; SwiftUI's diffing engine handles
// the rest.
// ─────────────────────────────────────────────────────────────────────────

@dynamicMemberLookup
struct FilterLens: Equatable {
    var source: String  = "ALL"
    var domain: String? = nil
    // A monotonic generation counter that is bumped on timer/notification
    // re-fires so removeDuplicates() lets them through even when source+domain
    // haven't changed — without this, `lens = lens` would be swallowed.
    fileprivate var generation: UInt64 = 0

    subscript<T: Equatable>(dynamicMember keyPath: WritableKeyPath<FilterLens, T>) -> T {
        get { self[keyPath: keyPath] }
        set { self[keyPath: keyPath] = newValue }
    }
}

// MARK: - ViewModel

@MainActor
class FeedViewModel: ObservableObject {
    // Single source of truth for all filter state
    @Published var lens = FilterLens()

    // Derived state — populated by the Combine pipeline
    @Published var items:       [SignalItem] = []
    @Published var allItems:    [SignalItem] = []
    @Published var brainStats:  BrainStats?
    @Published var sourceStats: [SourceStats] = []
    @Published var totalCount   = 0

    // Convenience accessors the UI uses unchanged
    var activeSource: String  { lens.source }
    var activeDomain: String? { lens.domain }

    private var pipeline:    AnyCancellable?
    private var refreshTimer: Timer?
    private var seenIDs: Set<Int> = []

    init() {
        // ── The entire refresh pipeline in one chain ──────────────────────
        // $lens publishes whenever ANY filter field changes (because FilterLens
        // is Equatable and @Published diffs on assignment).
        // removeDuplicates() prevents re-querying when the lens hasn't changed
        // (e.g. tapping the already-active domain).
        // debounce() collapses rapid successive changes (e.g. source + domain
        // set in the same runloop turn) into a single DB hit.
        pipeline = $lens
            .removeDuplicates()
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] lensValue in
                self?.query(lensValue)
            }

        // Background refresh timer — just invalidates the lens to re-trigger
        // the pipeline with the same filter, which re-queries the DB.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lens.generation &+= 1   // bump generation → passes removeDuplicates
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)

        NotificationCenter.default.addObserver(
            forName: .scrapeCompleted, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lens.generation &+= 1
                if let count = note.userInfo?["count"] as? Int, count > 0 {
                    self.checkForNewHighSignal()
                }
            }
        }

        // Attention shift: user opened an item, re-sort with updated attention field.
        // 200ms debounce so rapid clicks collapse into one re-sort.
        NotificationCenter.default.addObserver(
            forName: .attentionShifted, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lens.generation &+= 1
            }
        }
    }

    // Called by the Combine pipeline — only place DB is touched
    private func query(_ lensValue: FilterLens) {
        let src     = lensValue.source == "ALL" ? nil : lensValue.source
        var fetched = ElonDB.shared.fetchRecent(limit: 300, source: src)
        if let domain = lensValue.domain {
            fetched = fetched.filter { $0.domain.rawValue == domain }
        }
        // SessionMemory quietly reorders by composite attention+urgency+recency score.
        // Before 3 engagements it's a no-op — pure urgency+recency ordering.
        fetched.sort { SessionMemory.shared.score(for: $0) > SessionMemory.shared.score(for: $1) }
        items       = fetched
        allItems    = ElonDB.shared.fetchRecent(limit: 500)
        sourceStats = ElonDB.shared.fetchStats()
        totalCount  = ElonDB.shared.totalCount()
        brainStats  = computeBrainStats(fetched)

        if seenIDs.isEmpty {
            seenIDs = Set(fetched.map { $0.id })
        }
    }

    // ── Filter setters — just write to the lens, pipeline fires itself ────

    func setSource(_ source: String) {
        lens.source = source
        lens.domain = nil
    }

    func setDomain(_ domain: String?) {
        lens.domain = domain
        lens.source = "ALL"
    }

    // ── Notification check ────────────────────────────────────────────────

    private func checkForNewHighSignal() {
        let recent = ElonDB.shared.fetchRecent(limit: 100)
        for item in recent where !seenIDs.contains(item.id) {
            seenIDs.insert(item.id)
            NotificationManager.maybeNotify(item)
        }
    }

    // ── Brain stats ───────────────────────────────────────────────────────

    private func computeBrainStats(_ items: [SignalItem]) -> BrainStats {
        var dc: [Domain: Int]     = [:]
        var sc: [SignalType: Int] = [:]
        var se: [Sentiment: Int]  = [:]
        var urgSum = 0
        var highSig = 0

        for item in items {
            dc[item.domain,     default: 0] += 1
            sc[item.signalType, default: 0] += 1
            se[item.sentiment,  default: 0] += 1
            urgSum += item.urgency
            if item.urgency >= 7 || item.domain == .chaos { highSig += 1 }
        }

        return BrainStats(
            domainCounts:     dc,
            signalTypeCounts: sc,
            sentimentCounts:  se,
            avgUrgency:       items.isEmpty ? 0 : Double(urgSum) / Double(items.count),
            highSignalCount:  highSig,
            totalCount:       totalCount
        )
    }
}

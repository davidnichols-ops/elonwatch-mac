import SwiftUI

// MARK: - Colours

extension Color {
    static let ewBackground  = Color(hex: "#000008")
    static let ewSurface     = Color(hex: "#00000f")
    static let ewBorder      = Color(hex: "#002233")
    static let ewCyan        = Color(hex: "#00e5ff")
    static let ewCyanDim     = Color(hex: "#004455")
    static let ewAmber       = Color(hex: "#ff6600")
    static let ewGreen       = Color(hex: "#69ff47")
    static let ewRed         = Color(hex: "#ff1744")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(red:   Double((rgb >> 16) & 0xff) / 255,
                  green: Double((rgb >> 8)  & 0xff) / 255,
                  blue:  Double( rgb        & 0xff) / 255)
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var vm      = FeedViewModel()
    @StateObject private var scraper = ScraperRunner.shared

    var body: some View {
        ZStack {
            Color.ewBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                LogoBannerView(scraper: scraper)
                DomainPulseBarView(vm: vm)
                Divider().background(Color.ewBorder)
                HStack(spacing: 0) {
                    FeedPanelView(vm: vm)
                    Divider().background(Color.ewBorder)
                    RightPanelView(vm: vm, scraper: scraper)
                }
                TickerView(vm: vm)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { scraper.start() }
    }
}

// MARK: - Logo Banner

struct LogoBannerView: View {
    @ObservedObject var scraper: ScraperRunner
    @State private var time = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: wordmark
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("▌").foregroundColor(.ewCyan)
                    Text("FUTURE").foregroundColor(.ewCyan).font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("▐").foregroundColor(.ewCyan)
                    Text("E L O N W A T C H")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("▌").foregroundColor(.ewCyan)
                    Text("SYNC").foregroundColor(.ewCyan).font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("▐").foregroundColor(.ewCyan)
                }
                Text("◈◈◈  consciousness mapping  //  signal intelligence  //  real-time thought-stream decoder  ◈◈◈")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.ewCyanDim)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Right: clock + scrape status
            VStack(alignment: .trailing, spacing: 4) {
                Text(time)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.ewCyan)
                HStack(spacing: 6) {
                    Circle()
                        .fill(scraper.isRunning ? Color.ewAmber : Color.ewGreen)
                        .frame(width: 6, height: 6)
                        .opacity(scraper.isRunning ? (Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1) > 0.5 ? 1 : 0.3) : 1)
                    Text(scraper.isRunning ? "SYNCING" : "IDLE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(scraper.isRunning ? .ewAmber : .ewGreen)
                    Text("next: \(scraper.nextRunIn)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.ewCyanDim)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 54)
        .background(Color.ewSurface)
        .overlay(Divider().background(Color.ewBorder), alignment: .bottom)
        .onReceive(timer) { _ in
            time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        }
    }
}

// MARK: - Domain Pulse Bar

struct DomainPulseBarView: View {
    @ObservedObject var vm: FeedViewModel
    @State private var pulsePhase = 0
    let pulseTimer = Timer.publish(every: 0.7, on: .main, in: .common).autoconnect()
    let pulseChars = ["▏","▎","▍","▌","▋","▊","▉","█","▉","▊","▋","▌","▍","▎"]

    var domainOrder: [Domain] = [.space, .ai, .politics, .money, .tech, .chaos, .ego, .culture]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(domainOrder, id: \.self) { domain in
                let count = vm.brainStats?.domainCounts[domain] ?? 0
                let total = max(1, vm.items.count)
                let frac  = Double(count) / Double(total)
                let barLen = max(1, Int(frac * 12))
                let pulse  = pulseChars[pulsePhase % pulseChars.count]
                let color  = Color(hex: domain.color)

                Button(action: {
                    vm.setDomain(vm.activeDomain == domain.rawValue ? nil : domain.rawValue)
                }) {
                    VStack(spacing: 1) {
                        Text("\(domain.icon) \(domain.rawValue)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                        Text(String(repeating: pulse, count: barLen) +
                             String(repeating: "░", count: 12 - barLen))
                            .font(.system(size: 7, design: .monospaced))
                        Text("\(count)")
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        vm.activeDomain == domain.rawValue
                        ? color.opacity(0.12) : Color.clear
                    )
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                if domain != domainOrder.last {
                    Divider().background(Color.ewBorder)
                }
            }
        }
        .frame(height: 48)
        .background(Color(hex: "#000008"))
        .onReceive(pulseTimer) { _ in pulsePhase += 1 }
    }
}

// MARK: - Feed Panel

struct FeedPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("◈ CONSCIOUSNESS FEED  //  live thought stream")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.ewCyan)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#000010"))

            // Source filter tabs
            SourceFilterBar(vm: vm)

            // Feed
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.items) { item in
                        SignalRowView(item: item)
                        Divider().background(Color.ewBorder.opacity(0.4))
                    }
                }
            }
            .background(Color.ewBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SourceFilterBar: View {
    @ObservedObject var vm: FeedViewModel
    let sources = ["ALL", "twitter", "google-news", "reddit"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(sources, id: \.self) { src in
                let active = vm.activeSource == src && vm.activeDomain == nil
                Button(action: { vm.setSource(src) }) {
                    Text(sourceLabel(src))
                        .font(.system(size: 9, weight: active ? .bold : .regular, design: .monospaced))
                        .foregroundColor(active ? .white : .ewCyanDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(active ? Color.ewBorder : Color.clear)
                }
                .buttonStyle(.plain)
                if src != sources.last { Divider().background(Color.ewBorder) }
            }
            Spacer()
        }
        .frame(height: 22)
        .background(Color(hex: "#000010"))
    }

    func sourceLabel(_ s: String) -> String {
        switch s {
        case "ALL": return "[a] ALL"
        case "twitter": return "[t] TWITTER"
        case "google-news": return "[n] NEWS"
        case "reddit": return "[r] REDDIT"
        default: return s
        }
    }
}

// MARK: - Signal Row

struct SignalRowView: View {
    let item: SignalItem

    var body: some View {
        HStack(spacing: 6) {
            // Urgency indicator
            urgencyGlyph
                .frame(width: 16)

            // Domain icon
            Text(item.domain.icon)
                .font(.system(size: 11))

            // Source badge
            Text(sourceIcon)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: sourceColor))
                .frame(width: 14)

            // Author
            Text(item.author.isEmpty ? "—" : item.author)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: sourceColor))
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)

            // Signal type badge
            Text(item.signalType.rawValue)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.ewCyanDim)
                .frame(width: 60, alignment: .leading)

            // Sentiment
            Text(item.sentiment.rawValue)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(Color(hex: item.sentiment.color))
                .frame(width: 56, alignment: .leading)

            // Title
            Text(item.title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(item.source == "twitter" ? .white : Color(white: 0.85))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Time
            Text(shortTime(item.scrapedAt))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.ewCyanDim)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(rowBg)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: item.url), !item.url.isEmpty {
                NSWorkspace.shared.open(url)
            }
        }
    }

    var urgencyGlyph: some View {
        Group {
            if item.urgency >= 9 {
                Text("!!")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.ewRed)
            } else if item.urgency >= 7 {
                Text("▲▲")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#ff6d00"))
            } else if item.urgency >= 4 {
                Text("▲·")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.yellow)
            } else {
                Text("··")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.ewCyanDim)
            }
        }
    }

    var rowBg: Color {
        if item.urgency >= 9  { return Color.ewRed.opacity(0.06) }
        if item.urgency >= 7  { return Color(hex: "#ff6d00").opacity(0.04) }
        if item.domain == .chaos { return Color.ewRed.opacity(0.03) }
        return Color.clear
    }

    var sourceIcon: String {
        switch item.source {
        case "twitter":     return "𝕏"
        case "google-news": return "◉"
        case "reddit":      return "⬡"
        default:            return "·"
        }
    }

    var sourceColor: String {
        switch item.source {
        case "twitter":     return "#00e5ff"
        case "google-news": return "#ffea00"
        case "reddit":      return "#e040fb"
        default:            return "#546e7a"
        }
    }

    func shortTime(_ s: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) {
            return DateFormatter.localizedString(from: d, dateStyle: .none, timeStyle: .medium)
        }
        // fallback: trim to HH:MM:SS
        let parts = s.split(separator: "T")
        return parts.count > 1 ? String(parts[1].prefix(8)) : s.prefix(8).description
    }
}

// MARK: - Right Panel

struct RightPanelView: View {
    @ObservedObject var vm: FeedViewModel
    @ObservedObject var scraper: ScraperRunner

    var body: some View {
        VStack(spacing: 0) {
            BrainPanelView(vm: vm)
            Divider().background(Color.ewBorder)
            StatsPanelView(vm: vm)
            Divider().background(Color.ewBorder)
            SyncPanelView(scraper: scraper, vm: vm)
        }
        .frame(minWidth: 320, maxWidth: 320, maxHeight: .infinity)
        .background(Color(hex: "#000008"))
    }
}

// MARK: - Brain Panel

struct BrainPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelTitle("◈ SIGNAL BRAIN  //  classification engine")

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if let stats = vm.brainStats {
                        // Domain breakdown
                        SectionLabel("DOMAIN BREAKDOWN")
                        let sorted = Domain.allCases.sorted {
                            (stats.domainCounts[$0] ?? 0) > (stats.domainCounts[$1] ?? 0)
                        }.prefix(5)
                        ForEach(Array(sorted), id: \.self) { d in
                            DomainBarRow(domain: d,
                                         count: stats.domainCounts[d] ?? 0,
                                         total: max(1, vm.items.count))
                        }

                        Divider().background(Color.ewBorder).padding(.vertical, 4)

                        // Signal types
                        SectionLabel("SIGNAL TYPES")
                        ForEach(SignalType.allCases, id: \.self) { s in
                            let c = stats.signalTypeCounts[s] ?? 0
                            if c > 0 {
                                HStack {
                                    Text(s.rawValue)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(.ewCyanDim)
                                        .frame(width: 80, alignment: .leading)
                                    Text("\(c)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.ewCyan)
                                }
                            }
                        }

                        Divider().background(Color.ewBorder).padding(.vertical, 4)

                        // Sentiment
                        SectionLabel("SENTIMENT MIX")
                        ForEach(Sentiment.allCases, id: \.self) { s in
                            let c = stats.sentimentCounts[s] ?? 0
                            if c > 0 {
                                HStack {
                                    Text(s.rawValue)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundColor(Color(hex: s.color))
                                        .frame(width: 80, alignment: .leading)
                                    Text("\(c)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: s.color))
                                }
                            }
                        }

                        Divider().background(Color.ewBorder).padding(.vertical, 4)

                        HStack {
                            Text("AVG URGENCY")
                                .font(.system(size: 9, design: .monospaced)).foregroundColor(.ewCyanDim)
                            Spacer()
                            Text(String(format: "%.1f/10", stats.avgUrgency))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(stats.avgUrgency > 6 ? .ewRed : .yellow)
                        }
                        HStack {
                            Text("HIGH SIGNAL")
                                .font(.system(size: 9, design: .monospaced)).foregroundColor(.ewCyanDim)
                            Spacer()
                            Text("\(stats.highSignalCount)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.ewRed)
                        }
                    } else {
                        Text("// awaiting signal ...")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.ewCyanDim)
                    }
                }
                .padding(8)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct DomainBarRow: View {
    let domain: Domain
    let count: Int
    let total: Int

    var body: some View {
        let frac = Double(count) / Double(total)
        let barLen = max(1, Int(frac * 10))
        let color = Color(hex: domain.color)

        HStack(spacing: 4) {
            Text("\(domain.icon) \(domain.rawValue)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 90, alignment: .leading)
            Text(String(repeating: "█", count: barLen) +
                 String(repeating: "░", count: 10 - barLen))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - Stats Panel

struct StatsPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelTitle("◈ SOURCE COUNTS")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(vm.sourceStats, id: \.source) { stat in
                    HStack {
                        Text(sourceIcon(stat.source))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: sourceColor(stat.source)))
                        Text(stat.source)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: sourceColor(stat.source)))
                            .frame(width: 90, alignment: .leading)
                        Spacer()
                        Text("\(stat.count)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.ewGreen)
                        Text(shortTime(stat.lastSeen))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.ewCyanDim)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
                Divider().background(Color.ewBorder)
                HStack {
                    Text("TOTAL")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(vm.totalCount)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(8)
        }
    }

    func sourceIcon(_ s: String) -> String {
        switch s {
        case "twitter": return "𝕏"
        case "google-news": return "◉"
        case "reddit": return "⬡"
        default: return "·"
        }
    }
    func sourceColor(_ s: String) -> String {
        switch s {
        case "twitter": return "#00e5ff"
        case "google-news": return "#ffea00"
        case "reddit": return "#e040fb"
        default: return "#546e7a"
        }
    }
    func shortTime(_ s: String) -> String {
        let parts = s.split(separator: "T")
        return parts.count > 1 ? String(parts[1].prefix(5)) : s.prefix(5).description
    }
}

// MARK: - Sync Panel

struct SyncPanelView: View {
    @ObservedObject var scraper: ScraperRunner
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelTitle("◈ SYNC ENGINE")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("STATUS")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.ewCyanDim)
                    Spacer()
                    Text(scraper.isRunning ? "● SYNCING" : "■ IDLE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(scraper.isRunning ? .ewAmber : .ewGreen)
                }
                HStack {
                    Text("LAST RUN")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.ewCyanDim)
                    Spacer()
                    Text(scraper.lastRun)
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.ewCyan)
                }
                HStack {
                    Text("NEXT SYNC")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.ewCyanDim)
                    Spacer()
                    Text(scraper.nextRunIn)
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.ewCyan)
                }
                HStack {
                    Text("NEW ITEMS")
                        .font(.system(size: 9, design: .monospaced)).foregroundColor(.ewCyanDim)
                    Spacer()
                    Text("\(scraper.newItems)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.ewGreen)
                }
                Divider().background(Color.ewBorder)
                Button(action: { scraper.runNow() }) {
                    HStack {
                        Spacer()
                        Text("⟳  SYNC NOW")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .background(Color.ewBorder)
                    .cornerRadius(4)
                    .foregroundColor(.ewCyan)
                }
                .buttonStyle(.plain)
                .disabled(scraper.isRunning)
            }
            .padding(8)
        }
    }
}

// MARK: - Ticker

struct TickerView: View {
    @ObservedObject var vm: FeedViewModel
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0

    var tickerText: String {
        let high = vm.items.filter { $0.urgency >= 5 }
        let items = high.isEmpty ? Array(vm.items.prefix(15)) : high
        return items.map { "  \($0.domain.icon) [\($0.domain.rawValue)] U:\($0.urgency) \($0.title.prefix(80))  ·" }.joined()
    }

    var body: some View {
        GeometryReader { geo in
            Text(tickerText)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.ewAmber)
                .fixedSize()
                .offset(x: offset)
                .onAppear {
                    textWidth = CGFloat(tickerText.count) * 6.5
                    withAnimation(.linear(duration: Double(tickerText.count) * 0.06).repeatForever(autoreverses: false)) {
                        offset = -textWidth
                    }
                }
                .onChange(of: tickerText) {
                    offset = geo.size.width
                    textWidth = CGFloat(tickerText.count) * 6.5
                    withAnimation(.linear(duration: Double(tickerText.count) * 0.06).repeatForever(autoreverses: false)) {
                        offset = -textWidth
                    }
                }
        }
        .frame(height: 18)
        .clipped()
        .background(Color(hex: "#000010"))
    }
}

// MARK: - Helpers

struct PanelTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.ewCyan)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#000010"))
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text("── \(text)")
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(.ewCyanDim)
    }
}

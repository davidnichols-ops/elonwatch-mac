import SwiftUI

// MARK: - Colours

extension Color {
    static let ewBackground = Color(hex: "#000008")
    static let ewSurface    = Color(hex: "#00000f")
    static let ewBorder     = Color(hex: "#002233")
    static let ewCyan       = Color(hex: "#00e5ff")
    static let ewCyanDim    = Color(hex: "#004455")
    static let ewAmber      = Color(hex: "#ff6600")
    static let ewGreen      = Color(hex: "#69ff47")
    static let ewRed        = Color(hex: "#ff1744")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8)  & 0xff) / 255,
            blue:  Double( rgb        & 0xff) / 255
        )
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
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("▌").foregroundColor(.ewCyan).font(.system(size: 13, design: .monospaced))
                    Text("FUTURE").foregroundColor(.ewCyan)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("▐").foregroundColor(.ewCyan).font(.system(size: 13, design: .monospaced))
                    Text("E L O N W A T C H")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("▌").foregroundColor(.ewCyan).font(.system(size: 13, design: .monospaced))
                    Text("SYNC").foregroundColor(.ewCyan)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("▐").foregroundColor(.ewCyan).font(.system(size: 13, design: .monospaced))
                }
                Text("consciousness mapping  //  signal intelligence  //  real-time thought-stream decoder")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.ewCyanDim)
            }
            .padding(.horizontal, 16)

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(time)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.ewCyan)
                HStack(spacing: 6) {
                    Circle()
                        .fill(scraper.isRunning ? Color.ewAmber : Color.ewGreen)
                        .frame(width: 7, height: 7)
                    Text(scraper.isRunning ? "SYNCING" : "IDLE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(scraper.isRunning ? .ewAmber : .ewGreen)
                    Text("·  next: \(scraper.nextRunIn)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.ewCyanDim)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 58)
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
    let domainOrder: [Domain] = [.space, .ai, .politics, .money, .tech, .chaos, .ego, .culture, .glaze]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(domainOrder, id: \.self) { domain in
                let count  = vm.brainStats?.domainCounts[domain] ?? 0
                let total  = max(1, vm.allItems.count)
                let frac   = Double(count) / Double(total)
                let barLen = max(1, Int(frac * 10))
                let pulse  = pulseChars[pulsePhase % pulseChars.count]
                let color  = Color(hex: domain.color)
                let active = vm.activeDomain == domain.rawValue

                Button(action: {
                    vm.setDomain(active ? nil : domain.rawValue)
                }) {
                    VStack(spacing: 2) {
                        Text("\(domain.icon) \(domain.rawValue)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                        Text(String(repeating: pulse, count: barLen) +
                             String(repeating: "░", count: 10 - barLen))
                            .font(.system(size: 8, design: .monospaced))
                        Text("\(count)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundColor(active ? .white : color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 5)
                    .background(active ? color.opacity(0.18) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                if domain != domainOrder.last {
                    Divider().background(Color.ewBorder)
                }
            }
        }
        .frame(height: 52)
        .background(Color.ewBackground)
        .onReceive(pulseTimer) { _ in pulsePhase += 1 }
    }
}

// MARK: - Feed Panel

struct FeedPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var activeDomainLabel: String {
        if let d = vm.activeDomain { return " · \(d)" }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("◈ CONSCIOUSNESS FEED\(activeDomainLabel)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.ewCyan)
                Spacer()
                Text("\(vm.items.count) signals")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.ewCyanDim)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.ewSurface)
            .overlay(Divider().background(Color.ewBorder), alignment: .bottom)

            // Source filter tabs
            SourceFilterBar(vm: vm)

            // Feed
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.items) { item in
                        SignalRowView(item: item)
                        Divider().background(Color.ewBorder.opacity(0.35))
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
                        .font(.system(size: 10, weight: active ? .bold : .regular, design: .monospaced))
                        .foregroundColor(active ? .white : .ewCyanDim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(active ? Color.ewBorder : Color.clear)
                }
                .buttonStyle(.plain)
                if src != sources.last { Divider().background(Color.ewBorder) }
            }
            Spacer()
        }
        .frame(height: 26)
        .background(Color.ewSurface)
        .overlay(Divider().background(Color.ewBorder), alignment: .bottom)
    }

    func sourceLabel(_ s: String) -> String {
        switch s {
        case "ALL":          return "ALL"
        case "twitter":      return "𝕏 TWITTER"
        case "google-news":  return "◉ NEWS"
        case "reddit":       return "⬡ REDDIT"
        default:             return s
        }
    }
}

// MARK: - Signal Row

struct SignalRowView: View {
    let item: SignalItem

    var body: some View {
        HStack(spacing: 8) {
            // Urgency
            urgencyGlyph
                .frame(width: 18)

            // Domain icon
            Text(item.domain.icon)
                .font(.system(size: 12))

            // Source icon
            Text(sourceIcon)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: sourceColor))
                .frame(width: 16)

            // Author
            Text(item.author.isEmpty ? "—" : item.author)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: sourceColor).opacity(0.8))
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)

            // Signal type
            Text(item.signalType.rawValue)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.ewCyanDim)
                .frame(width: 66, alignment: .leading)

            // Sentiment
            sentimentBadge
                .frame(width: 70, alignment: .leading)

            // Title — most important, gets the space
            Text(item.title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(titleColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Time
            Text(shortTime(item.scrapedAt))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.ewCyanDim)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
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
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.ewRed)
            } else if item.urgency >= 7 {
                Text("▲▲")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#ff6d00"))
            } else if item.urgency >= 4 {
                Text("▲·")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.yellow)
            } else {
                Text("··")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.ewCyanDim)
            }
        }
    }

    var sentimentBadge: some View {
        Text(item.sentiment.rawValue)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(Color(hex: item.sentiment.color))
    }

    var titleColor: Color {
        if item.domain == .glaze   { return Color(hex: "#fff3b0") }
        if item.domain == .chaos   { return Color(hex: "#ffcdd2") }
        if item.source == "twitter" { return .white }
        return Color(white: 0.88)
    }

    var rowBg: Color {
        if item.urgency >= 9     { return Color.ewRed.opacity(0.07) }
        if item.urgency >= 7     { return Color(hex: "#ff6d00").opacity(0.05) }
        if item.domain == .chaos  { return Color.ewRed.opacity(0.04) }
        if item.domain == .glaze  { return Color(hex: "#ffd740").opacity(0.04) }
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
        .frame(minWidth: 310, maxWidth: 310, maxHeight: .infinity)
        .background(Color.ewSurface)
    }
}

// MARK: - Brain Panel

struct BrainPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelTitle("◈ SIGNAL BRAIN")

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let stats = vm.brainStats {
                        SectionLabel("DOMAIN BREAKDOWN")
                        let sorted = Domain.allCases.sorted {
                            (stats.domainCounts[$0] ?? 0) > (stats.domainCounts[$1] ?? 0)
                        }.prefix(6)
                        ForEach(Array(sorted), id: \.self) { d in
                            DomainBarRow(domain: d,
                                         count: stats.domainCounts[d] ?? 0,
                                         total: max(1, vm.allItems.count))
                        }

                        Divider().background(Color.ewBorder).padding(.vertical, 2)
                        SectionLabel("SIGNAL TYPES")
                        ForEach(SignalType.allCases, id: \.self) { s in
                            let c = stats.signalTypeCounts[s] ?? 0
                            if c > 0 {
                                HStack {
                                    Text(s.rawValue)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.ewCyanDim)
                                        .frame(width: 90, alignment: .leading)
                                    Text("\(c)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.ewCyan)
                                }
                            }
                        }

                        Divider().background(Color.ewBorder).padding(.vertical, 2)
                        SectionLabel("SENTIMENT MIX")
                        ForEach(Sentiment.allCases, id: \.self) { s in
                            let c = stats.sentimentCounts[s] ?? 0
                            if c > 0 {
                                HStack {
                                    Text(s.rawValue)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(Color(hex: s.color))
                                        .frame(width: 90, alignment: .leading)
                                    Text("\(c)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: s.color))
                                }
                            }
                        }

                        Divider().background(Color.ewBorder).padding(.vertical, 2)
                        HStack {
                            Text("AVG URGENCY")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.ewCyanDim)
                            Spacer()
                            Text(String(format: "%.1f / 10", stats.avgUrgency))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(stats.avgUrgency > 6 ? .ewRed : .yellow)
                        }
                        HStack {
                            Text("HIGH SIGNAL")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.ewCyanDim)
                            Spacer()
                            Text("\(stats.highSignalCount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.ewRed)
                        }
                    } else {
                        Text("// awaiting signal ...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.ewCyanDim)
                    }
                }
                .padding(10)
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
        let frac   = Double(count) / Double(total)
        let barLen = max(1, Int(frac * 10))
        let color  = Color(hex: domain.color)

        HStack(spacing: 6) {
            Text("\(domain.icon) \(domain.rawValue)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 100, alignment: .leading)
            Text(String(repeating: "█", count: barLen) +
                 String(repeating: "░", count: 10 - barLen))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
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
            VStack(alignment: .leading, spacing: 5) {
                ForEach(vm.sourceStats, id: \.source) { stat in
                    HStack {
                        Text(sourceIcon(stat.source))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: sourceColor(stat.source)))
                            .frame(width: 18)
                        Text(stat.source)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: sourceColor(stat.source)))
                            .frame(width: 96, alignment: .leading)
                        Spacer()
                        Text("\(stat.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.ewGreen)
                        Text(shortTime(stat.lastSeen))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.ewCyanDim)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Divider().background(Color.ewBorder)
                HStack {
                    Text("TOTAL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(vm.totalCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(10)
        }
    }

    func sourceIcon(_ s: String) -> String {
        switch s {
        case "twitter":     return "𝕏"
        case "google-news": return "◉"
        case "reddit":      return "⬡"
        default:            return "·"
        }
    }
    func sourceColor(_ s: String) -> String {
        switch s {
        case "twitter":     return "#00e5ff"
        case "google-news": return "#ffea00"
        case "reddit":      return "#e040fb"
        default:            return "#546e7a"
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
            VStack(alignment: .leading, spacing: 7) {
                SyncRow(label: "STATUS",    value: scraper.isRunning ? "● SYNCING" : "■ IDLE",
                        valueColor: scraper.isRunning ? .ewAmber : .ewGreen)
                SyncRow(label: "LAST RUN",  value: scraper.lastRun,    valueColor: .ewCyan)
                SyncRow(label: "NEXT SYNC", value: scraper.nextRunIn,  valueColor: .ewCyan)
                SyncRow(label: "NEW ITEMS", value: "\(scraper.newItems)", valueColor: .ewGreen)
                Divider().background(Color.ewBorder)
                Button(action: { scraper.runNow() }) {
                    HStack {
                        Spacer()
                        Text("⟳  SYNC NOW")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Spacer()
                    }
                    .padding(.vertical, 7)
                    .background(Color.ewBorder)
                    .cornerRadius(5)
                    .foregroundColor(.ewCyan)
                }
                .buttonStyle(.plain)
                .disabled(scraper.isRunning)
                .opacity(scraper.isRunning ? 0.5 : 1)
            }
            .padding(10)
        }
    }
}

private struct SyncRow: View {
    let label: String
    let value: String
    let valueColor: Color
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.ewCyanDim)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Ticker

struct TickerView: View {
    @ObservedObject var vm: FeedViewModel
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0

    var tickerText: String {
        let high  = vm.items.filter { $0.urgency >= 5 }
        let items = high.isEmpty ? Array(vm.items.prefix(15)) : high
        return items.map {
            "  \($0.domain.icon) [\($0.domain.rawValue)] U:\($0.urgency)  \($0.title.prefix(80))  ·"
        }.joined()
    }

    var body: some View {
        GeometryReader { geo in
            Text(tickerText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.ewAmber)
                .fixedSize()
                .offset(x: offset)
                .onAppear {
                    textWidth = CGFloat(tickerText.count) * 6.8
                    withAnimation(.linear(duration: Double(tickerText.count) * 0.055)
                        .repeatForever(autoreverses: false)) {
                        offset = -textWidth
                    }
                }
                .onChange(of: tickerText) {
                    offset = geo.size.width
                    textWidth = CGFloat(tickerText.count) * 6.8
                    withAnimation(.linear(duration: Double(tickerText.count) * 0.055)
                        .repeatForever(autoreverses: false)) {
                        offset = -textWidth
                    }
                }
        }
        .frame(height: 20)
        .clipped()
        .background(Color.ewSurface)
        .overlay(Divider().background(Color.ewBorder), alignment: .top)
    }
}

// MARK: - Helpers

struct PanelTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.ewCyan)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.ewSurface)
        .overlay(Divider().background(Color.ewBorder), alignment: .bottom)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text("── \(text)")
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.ewCyanDim)
    }
}

import SwiftUI

// MARK: - Design System

extension Color {
    // Base palette — pulled directly from icon
    static let ewVoid       = Color(hex: "#000005")   // deepest background
    static let ewBackground = Color(hex: "#00000a")
    static let ewSurface    = Color(hex: "#00040f")   // panel surfaces
    static let ewSurfaceHi  = Color(hex: "#00071a")   // raised card surface
    static let ewBorder     = Color(hex: "#00203a")
    static let ewBorderHi   = Color(hex: "#004466")

    // Neon cyan — the signature glow from the icon
    static let ewCyan       = Color(hex: "#00e5ff")
    static let ewCyanMid    = Color(hex: "#0099bb")
    static let ewCyanDim    = Color(hex: "#00344d")
    static let ewCyanGlow   = Color(hex: "#00e5ff")   // used for shadows

    // Signal colours
    static let ewAmber      = Color(hex: "#ff7700")
    static let ewGreen      = Color(hex: "#39ff14")   // neon green
    static let ewRed        = Color(hex: "#ff1744")
    static let ewGold       = Color(hex: "#ffd740")
    static let ewPurple     = Color(hex: "#e040fb")

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

// Reusable glow modifier
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius / 2)
            .shadow(color: color.opacity(0.4), radius: radius)
            .shadow(color: color.opacity(0.2), radius: radius * 2)
    }
}
extension View {
    func glow(_ color: Color = .ewCyan, radius: CGFloat = 6) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// Glass card background
struct GlassCard: ViewModifier {
    var border: Color = .ewBorder
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color.ewSurface
                    LinearGradient(
                        colors: [Color.ewCyan.opacity(0.04), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(border, lineWidth: 0.5)
            )
    }
}
extension View {
    func glassCard(border: Color = .ewBorder) -> some View {
        modifier(GlassCard(border: border))
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var vm      = FeedViewModel()
    @StateObject private var scraper = ScraperRunner.shared

    var body: some View {
        ZStack {
            // Deep space gradient background
            LinearGradient(
                colors: [Color.ewVoid, Color(hex: "#000312"), Color.ewVoid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView(scraper: scraper)
                DomainBarView(vm: vm)
                HStack(spacing: 0) {
                    FeedPanelView(vm: vm)
                    RightPanelView(vm: vm, scraper: scraper)
                }
                .frame(maxHeight: .infinity)
                TickerView(vm: vm)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { scraper.start() }
    }
}

// MARK: - Header

struct HeaderView: View {
    @ObservedObject var scraper: ScraperRunner
    @State private var time = ""
    @State private var radarAngle: Double = 0
    let clock  = Timer.publish(every: 1,    on: .main, in: .common).autoconnect()
    let radar  = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Subtle top-edge glow strip matching icon
            LinearGradient(
                colors: [Color.ewCyan.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .center, spacing: 0) {

                // ── Radar ring animation (from icon) ──
                RadarRingView(angle: radarAngle)
                    .frame(width: 56, height: 56)
                    .padding(.leading, 16)

                // ── Wordmark ──
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("ELON")
                            .font(.system(size: 26, weight: .black, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(hex: "#c8e8ff")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        Text("WATCH")
                            .font(.system(size: 26, weight: .black, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.ewCyan, Color.ewCyanMid],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .glow(.ewCyan, radius: 8)
                    }
                    HStack(spacing: 8) {
                        Text("// FUTURE SYNC")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.ewCyan.opacity(0.7))
                        Text("·")
                            .foregroundColor(.ewBorderHi)
                        Text("consciousness mapping  ·  signal intelligence  ·  real-time thought-stream")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.ewCyanDim)
                    }
                }
                .padding(.leading, 12)

                Spacer()

                // ── Status cluster ──
                VStack(alignment: .trailing, spacing: 5) {
                    Text(time)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.ewCyan)
                        .glow(.ewCyan, radius: 4)

                    HStack(spacing: 8) {
                        // Pulse dot
                        PulseDot(active: scraper.isRunning)
                        Text(scraper.isRunning ? "SYNCING" : "IDLE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(scraper.isRunning ? .ewAmber : .ewGreen)
                        Text("next \(scraper.nextRunIn)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.ewCyanDim)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(height: 72)
        .background(Color.ewSurface)
        .overlay(
            // Bottom cyan line — matches icon border
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.ewCyan.opacity(0.6), Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1),
            alignment: .bottom
        )
        .onReceive(clock) { _ in
            time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        }
        .onReceive(radar) { _ in
            radarAngle += 1.8
        }
    }
}

struct RadarRingView: View {
    let angle: Double

    var body: some View {
        ZStack {
            // Concentric rings — matches icon radar dish rings
            ForEach([0.9, 0.65, 0.4], id: \.self) { scale in
                Circle()
                    .strokeBorder(Color.ewCyan.opacity(0.15 + (1 - scale) * 0.15), lineWidth: 0.5)
                    .scaleEffect(scale)
            }
            // Sweep line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.ewCyan.opacity(0.6), Color.ewCyan],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 22, height: 1)
                .offset(x: 11)
                .rotationEffect(.degrees(angle))
            // Center dot
            Circle()
                .fill(Color.ewCyan)
                .frame(width: 3, height: 3)
                .glow(.ewCyan, radius: 4)
        }
    }
}

struct PulseDot: View {
    let active: Bool
    @State private var opacity: Double = 1
    let pulse = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        Circle()
            .fill(active ? Color.ewAmber : Color.ewGreen)
            .frame(width: 7, height: 7)
            .opacity(active ? opacity : 1)
            .glow(active ? .ewAmber : .ewGreen, radius: 3)
            .onReceive(pulse) { _ in
                if active { withAnimation(.easeInOut(duration: 0.5)) { opacity = opacity < 0.4 ? 1 : 0.2 } }
                else { opacity = 1 }
            }
    }
}

// MARK: - Domain Bar

struct DomainBarView: View {
    @ObservedObject var vm: FeedViewModel
    @State private var pulsePhase = 0
    let pulseTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()
    let domainOrder: [Domain] = [.space, .ai, .politics, .money, .tech, .chaos, .ego, .culture, .glaze]

    var body: some View {
        HStack(spacing: 1) {
            ForEach(domainOrder, id: \.self) { domain in
                DomainCell(
                    domain: domain,
                    count: vm.brainStats?.domainCounts[domain] ?? 0,
                    total: max(1, vm.allItems.count),
                    pulsePhase: pulsePhase,
                    active: vm.activeDomain == domain.rawValue
                ) {
                    vm.setDomain(vm.activeDomain == domain.rawValue ? nil : domain.rawValue)
                }
            }
        }
        .padding(.horizontal, 1)
        .frame(height: 58)
        .background(Color.ewVoid)
        .overlay(
            Rectangle()
                .fill(Color.ewBorder)
                .frame(height: 1),
            alignment: .bottom
        )
        .onReceive(pulseTimer) { _ in pulsePhase += 1 }
    }
}

struct DomainCell: View {
    let domain: Domain
    let count: Int
    let total: Int
    let pulsePhase: Int
    let active: Bool
    let onTap: () -> Void

    private let pulseChars = ["▁","▂","▃","▄","▅","▆","▇","█","▇","▆","▅","▄","▃","▂"]

    var body: some View {
        let frac   = Double(count) / Double(total)
        let barLen = max(1, Int(frac * 8))
        let pulse  = pulseChars[pulsePhase % pulseChars.count]
        let color  = Color(hex: domain.color)

        Button(action: onTap) {
            ZStack {
                // Active state: glowing fill
                if active {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(color.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(0.3), radius: 6)
                }

                VStack(spacing: 2) {
                    Text(domain.icon)
                        .font(.system(size: 14))
                        .shadow(color: color.opacity(active ? 0.9 : 0.3), radius: 4)

                    Text(domain.rawValue)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(active ? .white : color.opacity(0.8))

                    // Animated bar
                    HStack(spacing: 0) {
                        Text(String(repeating: pulse, count: barLen))
                            .foregroundColor(color.opacity(active ? 1 : 0.6))
                        Text(String(repeating: "▁", count: 8 - barLen))
                            .foregroundColor(color.opacity(0.15))
                    }
                    .font(.system(size: 7, design: .monospaced))

                    Text("\(count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(active ? .white : color.opacity(0.7))
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Feed Panel

struct FeedPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.ewCyan)
                        .glow(.ewCyan, radius: 3)
                    Text(vm.activeDomain != nil
                         ? "FEED  ·  \(vm.activeDomain!)"
                         : "CONSCIOUSNESS FEED")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                // Source filter pills
                SourcePills(vm: vm)
                // Count badge
                Text("\(vm.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.ewCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.ewCyan.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.ewCyan.opacity(0.3), lineWidth: 0.5)
                    )
                    .cornerRadius(3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.ewSurface)
            .overlay(Rectangle().fill(Color.ewBorder).frame(height: 0.5), alignment: .bottom)

            // Feed rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.items) { item in
                        SignalRow(item: item)
                        Rectangle()
                            .fill(Color.ewBorder.opacity(0.4))
                            .frame(height: 0.5)
                    }
                }
            }
            .background(Color.ewBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SourcePills: View {
    @ObservedObject var vm: FeedViewModel
    let sources: [(String, String, String)] = [
        ("ALL", "ALL", "#00e5ff"),
        ("twitter", "𝕏", "#00e5ff"),
        ("google-news", "NEWS", "#ffea00"),
        ("reddit", "REDDIT", "#e040fb"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(sources, id: \.0) { (src, label, hex) in
                let active = vm.activeSource == src && vm.activeDomain == nil
                Button(action: { vm.setSource(src) }) {
                    Text(label)
                        .font(.system(size: 9, weight: active ? .bold : .medium, design: .monospaced))
                        .foregroundColor(active ? Color(hex: hex) : Color(hex: hex).opacity(0.4))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(active ? Color(hex: hex).opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(
                                    active ? Color(hex: hex).opacity(0.5) : Color.ewBorder,
                                    lineWidth: 0.5
                                )
                        )
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Signal Row

struct SignalRow: View {
    let item: SignalItem
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Left urgency stripe
            Rectangle()
                .fill(urgencyColor.opacity(item.urgency >= 7 ? 0.9 : 0.3))
                .frame(width: 3)

            HStack(spacing: 10) {
                // Domain icon + urgency
                ZStack(alignment: .topTrailing) {
                    Text(item.domain.icon)
                        .font(.system(size: 16))
                        .shadow(color: Color(hex: item.domain.color).opacity(0.6), radius: 4)

                    if item.urgency >= 7 {
                        Text("\(item.urgency)")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(2)
                            .background(urgencyColor)
                            .cornerRadius(2)
                            .offset(x: 4, y: -2)
                    }
                }
                .frame(width: 28)

                // Source badge
                Text(sourceIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: sourceColor))
                    .shadow(color: Color(hex: sourceColor).opacity(0.6), radius: 3)
                    .frame(width: 18)

                // Author
                Text(item.author.isEmpty ? "—" : item.author)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: sourceColor).opacity(0.75))
                    .frame(width: 120, alignment: .leading)
                    .lineLimit(1)

                // Sentiment pill
                SentimentPill(sentiment: item.sentiment)

                // Title
                Text(item.title)
                    .font(.system(size: 12))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Time
                Text(shortTime(item.scrapedAt))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.ewCyanDim)
                    .frame(width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(rowBg)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .overlay(
            hovered
            ? Rectangle().fill(Color.ewCyan.opacity(0.04))
            : nil
        )
        .onTapGesture {
            if let url = URL(string: item.url), !item.url.isEmpty {
                NSWorkspace.shared.open(url)
            }
        }
    }

    var urgencyColor: Color {
        if item.urgency >= 9 { return .ewRed }
        if item.urgency >= 7 { return .ewAmber }
        if item.urgency >= 4 { return .yellow }
        return .ewCyanDim
    }

    var titleColor: Color {
        if item.domain == .glaze   { return Color(hex: "#fff0a0") }
        if item.domain == .chaos   { return Color(hex: "#ffb3ba") }
        if item.urgency >= 9       { return Color(hex: "#ff8a80") }
        if item.source == "twitter" { return .white }
        return Color(white: 0.85)
    }

    var rowBg: Color {
        if item.urgency >= 9     { return Color.ewRed.opacity(0.06) }
        if item.urgency >= 7     { return Color.ewAmber.opacity(0.04) }
        if item.domain == .chaos  { return Color.ewRed.opacity(0.03) }
        if item.domain == .glaze  { return Color.ewGold.opacity(0.04) }
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
        return parts.count > 1 ? String(parts[1].prefix(8)) : String(s.prefix(8))
    }
}

struct SentimentPill: View {
    let sentiment: Sentiment
    var body: some View {
        Text(sentiment.rawValue)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: sentiment.color))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hex: sentiment.color).opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color(hex: sentiment.color).opacity(0.3), lineWidth: 0.5)
            )
            .cornerRadius(3)
            .frame(width: 68, alignment: .leading)
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
            SyncPanelView(scraper: scraper)
        }
        .frame(minWidth: 300, maxWidth: 300)
        .background(Color.ewSurface)
        .overlay(
            Rectangle().fill(Color.ewBorder).frame(width: 0.5),
            alignment: .leading
        )
    }
}

// MARK: - Brain Panel

struct BrainPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "brain", label: "SIGNAL BRAIN")

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let stats = vm.brainStats {
                        // Domain breakdown
                        SectionHeader("DOMAIN BREAKDOWN")
                        let sorted = Domain.allCases
                            .sorted { (stats.domainCounts[$0] ?? 0) > (stats.domainCounts[$1] ?? 0) }
                            .prefix(6)
                        ForEach(Array(sorted), id: \.self) { d in
                            BrainBarRow(
                                label: "\(d.icon) \(d.rawValue)",
                                count: stats.domainCounts[d] ?? 0,
                                total: max(1, vm.allItems.count),
                                color: Color(hex: d.color)
                            )
                        }

                        SectionHeader("SENTIMENT")
                        ForEach(Sentiment.allCases, id: \.self) { s in
                            let c = stats.sentimentCounts[s] ?? 0
                            if c > 0 {
                                BrainBarRow(
                                    label: s.rawValue,
                                    count: c,
                                    total: max(1, vm.items.count),
                                    color: Color(hex: s.color)
                                )
                            }
                        }

                        // Stats row
                        Divider().background(Color.ewBorder)
                        HStack(spacing: 0) {
                            StatBox(
                                value: String(format: "%.1f", stats.avgUrgency),
                                label: "AVG URG",
                                color: stats.avgUrgency > 6 ? .ewRed : .yellow
                            )
                            Divider().background(Color.ewBorder)
                            StatBox(
                                value: "\(stats.highSignalCount)",
                                label: "HIGH SIG",
                                color: .ewRed
                            )
                            Divider().background(Color.ewBorder)
                            StatBox(
                                value: "\(stats.totalCount)",
                                label: "TOTAL",
                                color: .ewCyan
                            )
                        }
                        .frame(height: 44)
                        .glassCard()
                    } else {
                        Text("// awaiting signal ...")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.ewCyanDim)
                    }
                }
                .padding(12)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct BrainBarRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color

    var body: some View {
        let frac = min(1.0, Double(count) / Double(total))
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(color.opacity(0.9))
                .frame(width: 110, alignment: .leading)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.9), color.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * frac))
                        .shadow(color: color.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 6)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .glow(color, radius: 4)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.ewCyanDim)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stats Panel

struct StatsPanelView: View {
    @ObservedObject var vm: FeedViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "chart.bar.fill", label: "SOURCES")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(vm.sourceStats, id: \.source) { stat in
                    HStack(spacing: 8) {
                        Text(srcIcon(stat.source))
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: srcColor(stat.source)))
                            .shadow(color: Color(hex: srcColor(stat.source)).opacity(0.6), radius: 3)
                            .frame(width: 18)
                        Text(stat.source)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: srcColor(stat.source)).opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(stat.count)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.ewGreen)
                            .glow(.ewGreen, radius: 2)
                    }
                }
                Rectangle().fill(Color.ewBorder).frame(height: 0.5)
                HStack {
                    Text("TOTAL SIGNALS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(vm.totalCount)")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.ewCyan)
                        .glow(.ewCyan, radius: 3)
                }
            }
            .padding(12)
        }
    }

    func srcIcon(_ s: String) -> String {
        switch s {
        case "twitter":     return "𝕏"
        case "google-news": return "◉"
        case "reddit":      return "⬡"
        default:            return "·"
        }
    }
    func srcColor(_ s: String) -> String {
        switch s {
        case "twitter":     return "#00e5ff"
        case "google-news": return "#ffea00"
        case "reddit":      return "#e040fb"
        default:            return "#546e7a"
        }
    }
}

// MARK: - Sync Panel

struct SyncPanelView: View {
    @ObservedObject var scraper: ScraperRunner

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(icon: "arrow.triangle.2.circlepath", label: "SYNC ENGINE")
            VStack(spacing: 8) {
                HStack {
                    Text("STATUS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.ewCyanDim)
                    Spacer()
                    Text(scraper.isRunning ? "● SYNCING" : "■ IDLE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(scraper.isRunning ? .ewAmber : .ewGreen)
                        .glow(scraper.isRunning ? .ewAmber : .ewGreen, radius: 3)
                }
                HStack {
                    Text("LAST RUN")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.ewCyanDim)
                    Spacer()
                    Text(scraper.lastRun)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.ewCyan)
                }
                HStack {
                    Text("NEXT SYNC")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.ewCyanDim)
                    Spacer()
                    Text(scraper.nextRunIn)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.ewCyan)
                }
                HStack {
                    Text("NEW SIGNALS")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.ewCyanDim)
                    Spacer()
                    Text("\(scraper.newItems)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.ewGreen)
                }

                // Sync Now button — glowing cyan
                Button(action: { scraper.runNow() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("SYNC NOW")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(scraper.isRunning ? .ewCyanDim : .ewCyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Color.ewCyan.opacity(scraper.isRunning ? 0.03 : 0.08)
                            if !scraper.isRunning {
                                LinearGradient(
                                    colors: [Color.ewCyan.opacity(0.15), Color.clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                Color.ewCyan.opacity(scraper.isRunning ? 0.15 : 0.5),
                                lineWidth: 1
                            )
                    )
                    .cornerRadius(6)
                    .shadow(color: scraper.isRunning ? .clear : Color.ewCyan.opacity(0.2), radius: 8)
                }
                .buttonStyle(.plain)
                .disabled(scraper.isRunning)
            }
            .padding(12)
        }
    }
}

// MARK: - Ticker

struct TickerView: View {
    @ObservedObject var vm: FeedViewModel
    @State private var offset: CGFloat = 2000
    @State private var textWidth: CGFloat = 0

    var tickerText: String {
        let high  = vm.items.filter { $0.urgency >= 5 }
        let items = high.isEmpty ? Array(vm.items.prefix(15)) : high
        return items.map {
            "  \($0.domain.icon)  \($0.title.prefix(90))  ·"
        }.joined()
    }

    var body: some View {
        ZStack {
            Color.ewVoid
            GeometryReader { geo in
                Text(tickerText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.ewAmber)
                    .shadow(color: Color.ewAmber.opacity(0.5), radius: 3)
                    .fixedSize()
                    .offset(x: offset)
                    .onAppear { startScroll(geo.size.width) }
                    .onChange(of: tickerText) { startScroll(geo.size.width) }
            }
        }
        .frame(height: 20)
        .clipped()
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.ewCyan.opacity(0.4), Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1),
            alignment: .top
        )
    }

    func startScroll(_ viewWidth: CGFloat) {
        let charWidth: CGFloat = 6.8
        textWidth = CGFloat(tickerText.count) * charWidth
        offset = viewWidth
        withAnimation(.linear(duration: Double(tickerText.count) * 0.05)
            .repeatForever(autoreverses: false)) {
            offset = -textWidth
        }
    }
}

// MARK: - Shared helpers

struct PanelHeader: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.ewCyan)
                .glow(.ewCyan, radius: 3)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            LinearGradient(
                colors: [Color.ewCyan.opacity(0.07), Color.clear],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(Rectangle().fill(Color.ewBorder).frame(height: 0.5), alignment: .bottom)
    }
}

struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack {
            Rectangle().fill(Color.ewCyan.opacity(0.4)).frame(width: 2, height: 10).cornerRadius(1)
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.ewCyan.opacity(0.6))
        }
    }
}

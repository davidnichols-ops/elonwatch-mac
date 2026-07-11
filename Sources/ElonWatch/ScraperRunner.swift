import Foundation
import UserNotifications

// MARK: - Scraper Runner
// Launches the embedded elonwatch_scraper binary as a subprocess.
// The binary is bundled inside Resources/ by the build script.

class ScraperRunner: ObservableObject {
    static let shared = ScraperRunner()

    @Published var isRunning  = false
    @Published var lastRun    = "never"
    @Published var newItems   = 0
    @Published var nextRunIn  = "60:00"

    private var timer: Timer?
    private var countdownTimer: Timer?
    private var nextFireDate: Date = Date().addingTimeInterval(10)
    private var task: Process?

    private var scraperBinary: String? {
        Bundle.main.path(forResource: "elonwatch_scraper", ofType: nil)
    }

    func start() {
        // First scrape after 10s, then every hour
        nextFireDate = Date().addingTimeInterval(10)
        scheduleCountdown()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if Date() >= self.nextFireDate && !self.isRunning {
                self.nextFireDate = Date().addingTimeInterval(3600)
                self.runScrape()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func runNow() {
        nextFireDate = Date().addingTimeInterval(3600)
        runScrape()
    }

    private func scheduleCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let remaining = max(0, self.nextFireDate.timeIntervalSinceNow)
            let m = Int(remaining) / 60
            let s = Int(remaining) % 60
            DispatchQueue.main.async {
                self.nextRunIn = String(format: "%02d:%02d", m, s)
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func runScrape() {
        guard let binary = scraperBinary else {
            print("ScraperRunner: binary not found in bundle")
            return
        }
        guard !isRunning else { return }

        DispatchQueue.main.async { self.isRunning = true }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)

        // Point scraper at the same DB the app reads
        let supportDir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("ElonWatch").path
        process.environment = [
            "ELONWATCH_DB_DIR": supportDir,
            "PATH": "/usr/bin:/bin:/usr/local/bin"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError  = pipe

        process.terminationHandler = { [weak self] p in
            guard let self else { return }
            let output = String(
                data: pipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            // Parse "new items: N" from scraper output
            let newCount = self.parseNewCount(output)
            DispatchQueue.main.async {
                self.isRunning = false
                self.newItems  = newCount
                self.lastRun   = DateFormatter.localizedString(
                    from: Date(), dateStyle: .none, timeStyle: .medium)
                NotificationCenter.default.post(
                    name: .scrapeCompleted, object: nil,
                    userInfo: ["count": newCount])
            }
        }

        do {
            try process.run()
            self.task = process
        } catch {
            DispatchQueue.main.async { self.isRunning = false }
            print("ScraperRunner error: \(error)")
        }
    }

    private func parseNewCount(_ output: String) -> Int {
        // Output contains "Done. New items: N"
        let pattern = #/New items: (\d+)/#
        if let match = output.firstMatch(of: pattern) {
            return Int(match.1) ?? 0
        }
        return 0
    }
}

extension Notification.Name {
    static let scrapeCompleted = Notification.Name("scrapeCompleted")
}

// MARK: - Push Notifications

class NotificationManager {
    static func send(title: String, subtitle: String, body: String, urgency: Int) {
        let content = UNMutableNotificationContent()
        content.title    = title
        content.subtitle = subtitle
        content.body     = body
        content.sound    = urgency >= 9 ? .defaultCritical :
                           urgency >= 7 ? .default : nil

        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    static func maybeNotify(_ item: SignalItem) {
        let isElonTweet = item.source == "twitter" &&
                          item.author.lowercased().contains("elonmusk")
        let isHighSignal = item.urgency >= 7 || item.domain == .chaos

        if isElonTweet {
            send(title: "ELONWATCH  //  Elon Tweeted",
                 subtitle: "\(item.domain.rawValue)  ·  \(item.signalType.rawValue)  ·  urgency \(item.urgency)/10",
                 body: item.title,
                 urgency: item.urgency)
        } else if isHighSignal {
            send(title: "ELONWATCH  //  High Signal  [\(item.domain.rawValue)]",
                 subtitle: "\(item.signalType.rawValue)  ·  urgency \(item.urgency)/10",
                 body: item.title,
                 urgency: item.urgency)
        }
    }
}

import Cocoa

// MARK: - Data Models

struct StatusPageSummary: Codable {
    let page: PageInfo
    let status: OverallStatus
    let components: [Component]
    let incidents: [Incident]
}

struct PageInfo: Codable {
    let name: String
    let url: String
}

struct OverallStatus: Codable {
    let indicator: String
    let description: String
}

struct Component: Codable {
    let id: String
    let name: String
    let status: String
    let description: String?
    let position: Int?
    let group: Bool?
    let groupId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status, description, position, group
        case groupId = "group_id"
    }
}

struct Incident: Codable {
    let id: String
    let name: String
    let status: String
    let impact: String
    let shortlink: String?
    let createdAt: String?
    let updatedAt: String?
    let incidentUpdates: [IncidentUpdate]?

    enum CodingKeys: String, CodingKey {
        case id, name, status, impact, shortlink
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case incidentUpdates = "incident_updates"
    }
}

struct IncidentUpdate: Codable {
    let id: String
    let status: String
    let body: String
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Status Helper

enum ServiceStatus: String {
    case operational
    case degradedPerformance = "degraded_performance"
    case partialOutage = "partial_outage"
    case majorOutage = "major_outage"
    case unknown

    var emoji: String {
        switch self {
        case .operational:          return "🟢"
        case .degradedPerformance:  return "🟡"
        case .partialOutage:        return "🟠"
        case .majorOutage:          return "🔴"
        case .unknown:              return "⚪"
        }
    }

    var label: String {
        switch self {
        case .operational:          return "Operational"
        case .degradedPerformance:  return "Degraded"
        case .partialOutage:        return "Partial Outage"
        case .majorOutage:          return "Major Outage"
        case .unknown:              return "Unknown"
        }
    }

    var severity: Int {
        switch self {
        case .operational:          return 0
        case .degradedPerformance:  return 1
        case .partialOutage:        return 2
        case .majorOutage:          return 3
        case .unknown:              return -1
        }
    }
}

// MARK: - Friendly Names

func friendlyName(for component: String) -> String {
    switch component {
    case "claude.ai":
        return "Claude.ai"
    case "platform.claude.com (formerly console.anthropic.com)":
        return "Console"
    case "Claude API (api.anthropic.com)":
        return "API"
    case "Claude Code":
        return "Claude Code"
    case "Claude for Government":
        return "Government"
    default:
        return component
    }
}

// MARK: - Menu Bar Icon

func menuBarIcon(for status: ServiceStatus) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
        let circleDiameter: CGFloat = 8
        let circleRect = NSRect(
            x: (rect.width - circleDiameter) / 2,
            y: (rect.height - circleDiameter) / 2,
            width: circleDiameter,
            height: circleDiameter
        )

        let color: NSColor
        switch status {
        case .operational:
            color = NSColor(red: 0.2, green: 0.78, blue: 0.4, alpha: 1.0)
        case .degradedPerformance:
            color = NSColor(red: 0.95, green: 0.77, blue: 0.25, alpha: 1.0)
        case .partialOutage:
            color = NSColor(red: 0.95, green: 0.55, blue: 0.2, alpha: 1.0)
        case .majorOutage:
            color = NSColor(red: 0.9, green: 0.25, blue: 0.2, alpha: 1.0)
        case .unknown:
            color = NSColor.systemGray
        }

        color.setFill()
        NSBezierPath(ovalIn: circleRect).fill()

        return true
    }
    image.isTemplate = false
    return image
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var timer: Timer?
    var lastSummary: StatusPageSummary?

    let apiURL = URL(string: "https://status.claude.com/api/v2/summary.json")!
    let refreshInterval: TimeInterval = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = menuBarIcon(for: .unknown)
            button.toolTip = "Claude Status"
        }

        menu = NSMenu()
        statusItem.menu = menu

        buildLoadingMenu()
        fetchStatus()

        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.fetchStatus()
        }
    }

    // MARK: - Menu Building

    func buildLoadingMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Claude Status", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: "Claude Status",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        let loading = NSMenuItem(title: "⏳  Loading...", action: nil, keyEquivalent: "")
        loading.isEnabled = false
        menu.addItem(loading)

        addFooterItems()
    }

    func buildMenu(from summary: StatusPageSummary) {
        menu.removeAllItems()

        // Header with overall status
        let overallStatus: ServiceStatus
        switch summary.status.indicator {
        case "none": overallStatus = .operational
        case "minor": overallStatus = .degradedPerformance
        case "major": overallStatus = .partialOutage
        case "critical": overallStatus = .majorOutage
        default: overallStatus = .unknown
        }

        let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: "\(overallStatus.emoji)  Claude — \(overallStatus.label)",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        // Components (skip group-level items)
        let visibleComponents = summary.components.filter { !($0.group ?? false) }
        for component in visibleComponents {
            let status = ServiceStatus(rawValue: component.status) ?? .unknown
            let friendly = friendlyName(for: component.name)

            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.isEnabled = false

            let title = "\(status.emoji)  \(friendly)  —  \(status.label)"
            var attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13)
            ]
            if status != .operational {
                attrs[.font] = NSFont.boldSystemFont(ofSize: 13)
            }
            item.attributedTitle = NSAttributedString(string: title, attributes: attrs)
            menu.addItem(item)
        }

        // Active incidents
        let activeIncidents = summary.incidents.filter {
            $0.status != "resolved" && $0.status != "postmortem"
        }
        if !activeIncidents.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let incidentHeader = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            incidentHeader.attributedTitle = NSAttributedString(
                string: "ACTIVE INCIDENTS",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
            incidentHeader.isEnabled = false
            menu.addItem(incidentHeader)

            for incident in activeIncidents {
                let impactEmoji: String
                switch incident.impact {
                case "critical": impactEmoji = "🔴"
                case "major":    impactEmoji = "🟠"
                case "minor":    impactEmoji = "🟡"
                default:         impactEmoji = "⚪"
                }

                let title = "\(impactEmoji)  \(incident.name)"
                let item = NSMenuItem(title: title, action: #selector(openIncident(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = incident.shortlink ?? "https://status.claude.com"
                menu.addItem(item)

                // Show latest update body (truncated)
                if let latestUpdate = incident.incidentUpdates?.first {
                    let body = latestUpdate.body
                    let truncated = body.count > 120 ? String(body.prefix(120)) + "…" : body
                    let updateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                    updateItem.isEnabled = false

                    let style = NSMutableParagraphStyle()
                    style.lineBreakMode = .byWordWrapping
                    updateItem.attributedTitle = NSAttributedString(
                        string: "      \(latestUpdate.status.capitalized): \(truncated)",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11),
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .paragraphStyle: style
                        ]
                    )
                    menu.addItem(updateItem)
                }
            }
        }

        addFooterItems()

        // Update menu bar icon to worst of component status and incident impact
        let worstComponent = visibleComponents
            .map { ServiceStatus(rawValue: $0.status) ?? .unknown }
            .max(by: { $0.severity < $1.severity }) ?? .unknown

        let worstIncident: ServiceStatus = activeIncidents
            .map { incident -> ServiceStatus in
                switch incident.impact {
                case "critical": return .majorOutage
                case "major":    return .partialOutage
                case "minor":    return .degradedPerformance
                default:         return .unknown
                }
            }
            .max(by: { $0.severity < $1.severity }) ?? .operational

        let iconStatus = [worstComponent, worstIncident]
            .max(by: { $0.severity < $1.severity }) ?? .unknown

        if let button = statusItem.button {
            button.image = menuBarIcon(for: iconStatus)
        }
    }

    func addFooterItems() {
        menu.addItem(NSMenuItem.separator())

        let lastUpdated = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        lastUpdated.attributedTitle = NSAttributedString(
            string: "Updated \(formattedNow())",
            attributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.tertiaryLabelColor
            ]
        )
        lastUpdated.isEnabled = false
        menu.addItem(lastUpdated)

        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let openPage = NSMenuItem(title: "Open Status Page…", action: #selector(openStatusPage), keyEquivalent: "o")
        openPage.target = self
        menu.addItem(openPage)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit Claude Status", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Fetching

    func fetchStatus() {
        let task = URLSession.shared.dataTask(with: apiURL) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.showError("Network error: \(error.localizedDescription)")
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.showError("No data received")
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let summary = try decoder.decode(StatusPageSummary.self, from: data)
                self.lastSummary = summary
                DispatchQueue.main.async {
                    self.buildMenu(from: summary)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError("Parse error: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }

    func showError(_ message: String) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(
            string: "Claude Status",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        let errorItem = NSMenuItem(title: "⚠️  \(message)", action: nil, keyEquivalent: "")
        errorItem.isEnabled = false
        menu.addItem(errorItem)

        addFooterItems()

        if let button = statusItem.button {
            button.image = menuBarIcon(for: .unknown)
        }
    }

    // MARK: - Helpers

    func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    // MARK: - Actions

    @objc func refreshNow() {
        fetchStatus()
    }

    @objc func openStatusPage() {
        NSWorkspace.shared.open(URL(string: "https://status.claude.com")!)
    }

    @objc func openIncident(_ sender: NSMenuItem) {
        if let urlString = sender.representedObject as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Launch

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()

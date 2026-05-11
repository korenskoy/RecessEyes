//
//  UpdateChecker.swift
//  RecessEyes
//
//  Polls the GitHub Releases atom feed and publishes an availableUpdate
//  when the latest published MARKETING_VERSION is newer than the running build.
//

import Foundation
import Combine
import os.log

@MainActor
final class UpdateChecker: ObservableObject {
    struct AvailableUpdate: Equatable {
        let version: String
        let url: URL
    }

    @Published private(set) var availableUpdate: AvailableUpdate?

    private static let log = Logger(subsystem: "ru.korenskoy.RecessEyes", category: "UpdateChecker")
    private let feedURL = URL(string: "https://github.com/korenskoy/RecessEyes/releases.atom")!
    private let checkInterval: TimeInterval = 24 * 60 * 60
    private let session: URLSession
    private var timer: Timer?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func start() {
        Task { await checkNow() }
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.checkNow() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func checkNow() async {
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            guard (200..<300).contains(http.statusCode) else {
                Self.log.error("Atom feed HTTP \(http.statusCode)")
                return
            }
            guard let latest = AtomFeedParser.parseLatestStable(data: data) else {
                Self.log.notice("No usable entry in atom feed")
                return
            }
            let current = AppVersion.marketing
            if Self.compareSemver(latest.version, current) == .orderedDescending {
                Self.log.notice("Update available: \(latest.version, privacy: .public) > \(current, privacy: .public)")
                availableUpdate = AvailableUpdate(version: latest.version, url: latest.url)
            } else {
                availableUpdate = nil
            }
        } catch {
            Self.log.error("Atom feed fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Numeric component-wise comparison: "1.2" < "1.2.1" < "1.10".
    nonisolated static func compareSemver(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let l = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let r = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(l.count, r.count)
        for i in 0..<count {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    /// Reject prerelease tags (beta/alpha/rc/preview/dev/nightly).
    /// Uses letter-boundary lookarounds so "rc1" and "-beta" match while
    /// "developer", "march", "preview-er-wrong-context" do not.
    nonisolated static func isPrerelease(_ raw: String) -> Bool {
        let pattern = #"(?<![a-z])(alpha|beta|rc|preview|dev|nightly)(?![a-z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
        let range = NSRange(raw.startIndex..., in: raw)
        return regex.firstMatch(in: raw, range: range) != nil
    }
}

// MARK: - Atom feed parser

final class AtomFeedParser: NSObject, XMLParserDelegate {
    struct LatestEntry {
        let version: String
        let url: URL
    }

    /// Returns the newest non-prerelease entry, or nil if none.
    static func parseLatestStable(data: Data) -> LatestEntry? {
        let delegate = AtomFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.entries.first { !UpdateChecker.isPrerelease($0.tag) }
            .flatMap { entry in
                guard let version = extractVersion(fromTag: entry.tag) ?? extractVersion(fromTitle: entry.title),
                      let url = entry.url else { return nil }
                return LatestEntry(version: version, url: url)
            }
    }

    private struct RawEntry {
        var title: String
        var tag: String   // last path segment of href, e.g. "v1.1.2"
        var url: URL?
    }

    private var entries: [RawEntry] = []
    private var insideEntry = false
    private var currentElement: String?
    private var titleBuffer = ""

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if elementName == "entry" {
            insideEntry = true
            entries.append(RawEntry(title: "", tag: "", url: nil))
            titleBuffer = ""
            return
        }
        guard insideEntry else { return }
        currentElement = elementName
        if elementName == "link", entries.last?.url == nil {
            let rel = attributeDict["rel"] ?? "alternate"
            if rel == "alternate", let href = attributeDict["href"], let url = URL(string: href) {
                entries[entries.count - 1].url = url
                entries[entries.count - 1].tag = url.lastPathComponent
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideEntry, currentElement == "title" else { return }
        titleBuffer += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "title", insideEntry, entries.last?.title.isEmpty == true {
            entries[entries.count - 1].title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            titleBuffer = ""
        }
        if elementName == "entry" {
            insideEntry = false
        }
        currentElement = nil
    }

    /// Strip leading "v" and accept "1", "1.2", "1.2.3", "1.2.3.4".
    static func extractVersion(fromTag tag: String) -> String? {
        let stripped = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return matchVersion(in: stripped)
    }

    static func extractVersion(fromTitle title: String) -> String? {
        matchVersion(in: title)
    }

    private static func matchVersion(in raw: String) -> String? {
        let pattern = #"(\d+(?:\.\d+){0,3})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let r = Range(match.range(at: 1), in: raw) else { return nil }
        return String(raw[r])
    }
}

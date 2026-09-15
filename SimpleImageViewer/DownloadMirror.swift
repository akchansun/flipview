import Foundation

/// Picks the faster public forge (Gitee vs GitHub) by racing a short header probe.
///
/// Packages are published on both forges. China often reaches Gitee first; elsewhere GitHub
/// is usually quicker. URLs come only from `version.json` — no hardcoded private hosts.
enum DownloadMirror {
    enum Forge: Sendable {
        case gitee
        case github
    }

    private static let probeTimeout: TimeInterval = 2.8

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = probeTimeout
        config.timeoutIntervalForResource = 3.2
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    static func hasAnyCandidate(_ links: VersionFeed.MacOSRelease.Download?) -> Bool {
        guard let links else { return false }
        return httpURL(links.giteeAsset) != nil
            || httpURL(links.githubAsset) != nil
            || httpURL(links.gitee) != nil
            || httpURL(links.github) != nil
            || httpURL(links.site) != nil
    }

    /// Open order: faster forge, the other forge, then the site URL.
    static func rankedOpenURLs(_ links: VersionFeed.MacOSRelease.Download?) async -> [URL] {
        guard let links else { return [] }
        let gitee = forgeURLs(.gitee, links)
        let github = forgeURLs(.github, links)
        let site = httpURL(links.site)
        let winner = await race(gitee: gitee, github: github)
        return orderedOpenURLs(winner: winner, gitee: gitee?.open, github: github?.open, site: site)
    }

    static func orderedOpenURLs(winner: Forge?, gitee: URL?, github: URL?, site: URL?) -> [URL] {
        var result: [URL] = []
        func add(_ url: URL?) {
            guard let url, !result.contains(url) else { return }
            result.append(url)
        }
        switch winner {
        case .gitee:
            add(gitee)
            add(github)
        case .github:
            add(github)
            add(gitee)
        case nil:
            add(gitee)
            add(github)
        }
        add(site)
        return result
    }

    static func httpURL(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    private struct ForgeURLs {
        let probe: URL
        let open: URL
    }

    private static func forgeURLs(_ forge: Forge, _ links: VersionFeed.MacOSRelease.Download) -> ForgeURLs? {
        let page: URL?
        let asset: URL?
        switch forge {
        case .gitee:
            page = httpURL(links.gitee)
            asset = httpURL(links.giteeAsset)
        case .github:
            page = httpURL(links.github)
            asset = httpURL(links.githubAsset)
        }
        if let asset {
            return ForgeURLs(probe: asset, open: asset)
        }
        if let page {
            return ForgeURLs(probe: page, open: page)
        }
        return nil
    }

    private static func race(gitee: ForgeURLs?, github: ForgeURLs?) async -> Forge? {
        switch (gitee, github) {
        case (nil, nil):
            return nil
        case (let gitee?, nil):
            return await probe(gitee.probe) ? .gitee : nil
        case (nil, let github?):
            return await probe(github.probe) ? .github : nil
        case (let gitee?, let github?):
            return await firstSuccess([(.gitee, gitee.probe), (.github, github.probe)])
        }
    }

    private static func firstSuccess(_ targets: [(Forge, URL)]) async -> Forge? {
        await withTaskGroup(of: Forge?.self) { group in
            for (forge, url) in targets {
                group.addTask {
                    await probe(url) ? forge : nil
                }
            }
            for await result in group {
                if let forge = result {
                    group.cancelAll()
                    return forge
                }
            }
            return nil
        }
    }

    /// HEAD-equivalent: Range GET, stop after headers so the zip is not downloaded.
    static func probe(_ url: URL) async -> Bool {
        if Task.isCancelled { return false }
        var request = URLRequest(url: url, timeoutInterval: probeTimeout)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        request.setValue("Flip/\(AppVersion.currentMarketing) (macOS)", forHTTPHeaderField: "User-Agent")
        do {
            let (bytes, response) = try await session.bytes(for: request)
            bytes.task.cancel()
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...399).contains(http.statusCode)
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
    }
}

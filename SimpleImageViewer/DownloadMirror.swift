import Foundation

/// Picks the faster public forge by racing `giteeAsset` vs `githubAsset`.
///
/// Open order after a win: winner zip → other zip → that forge’s release page →
/// the other page → `download.site`. URLs come only from `version.json`.
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

    static func rankedOpenURLs(_ links: VersionFeed.MacOSRelease.Download?) async -> [URL] {
        guard let links else { return [] }
        let giteeAsset = httpURL(links.giteeAsset)
        let githubAsset = httpURL(links.githubAsset)
        let giteePage = httpURL(links.gitee)
        let githubPage = httpURL(links.github)
        let site = httpURL(links.site)

        let winner: Forge?
        if giteeAsset != nil || githubAsset != nil {
            winner = await race(gitee: giteeAsset, github: githubAsset)
        } else {
            winner = await race(gitee: giteePage, github: githubPage)
        }

        return orderedOpenURLs(
            winner: winner,
            giteeAsset: giteeAsset,
            githubAsset: githubAsset,
            giteePage: giteePage,
            githubPage: githubPage,
            site: site
        )
    }

    /// Winner asset, other asset, release pages, then site.
    static func orderedOpenURLs(
        winner: Forge?,
        giteeAsset: URL?,
        githubAsset: URL?,
        giteePage: URL?,
        githubPage: URL?,
        site: URL?
    ) -> [URL] {
        var result: [URL] = []
        func add(_ url: URL?) {
            guard let url, !result.contains(url) else { return }
            result.append(url)
        }
        switch winner {
        case .gitee:
            add(giteeAsset)
            add(githubAsset)
            add(giteePage)
            add(githubPage)
        case .github:
            add(githubAsset)
            add(giteeAsset)
            add(githubPage)
            add(giteePage)
        case nil:
            add(giteeAsset)
            add(githubAsset)
            add(giteePage)
            add(githubPage)
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

    private static func race(gitee: URL?, github: URL?) async -> Forge? {
        switch (gitee, github) {
        case (nil, nil):
            return nil
        case (let gitee?, nil):
            return await probe(gitee) ? .gitee : nil
        case (nil, let github?):
            return await probe(github) ? .github : nil
        case (let gitee?, let github?):
            return await firstSuccess([(.gitee, gitee), (.github, github)])
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

    /// HEAD first (cheap); Range GET if HEAD is missing or rejected. Stops after headers.
    static func probe(_ url: URL) async -> Bool {
        if Task.isCancelled { return false }
        if await ping(url, method: "HEAD", range: false) { return true }
        if Task.isCancelled { return false }
        return await ping(url, method: "GET", range: true)
    }

    private static func ping(_ url: URL, method: String, range: Bool) async -> Bool {
        if Task.isCancelled { return false }
        var request = URLRequest(url: url, timeoutInterval: probeTimeout)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Flip/\(AppVersion.currentMarketing) (macOS)", forHTTPHeaderField: "User-Agent")
        if range {
            request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        }
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

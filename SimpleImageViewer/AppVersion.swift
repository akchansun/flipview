import Foundation

/// Semver-ish comparison for Flip marketing versions (`CFBundleShortVersionString`).
enum AppVersion {
    static var currentMarketing: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// True when `remote` is strictly newer than `local`.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        compare(normalize(remote), normalize(local)) == .orderedDescending
    }

    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.count >= 1 {
            let first = value[value.startIndex]
            if first == "v" || first == "V" {
                value.removeFirst()
            }
        }
        if let plus = value.firstIndex(of: "+") {
            value = String(value[..<plus])
        }
        return value
    }

    /// Numeric `x.y.z` compare. A `-beta` suffix is ignored so `1.0.0-beta` counts as `1.0.0`.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    static func components(_ version: String) -> [Int] {
        let core = version.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? version
        return core.split(separator: ".", omittingEmptySubsequences: true).map { part in
            let digits = part.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }
    }
}

/// Live feed at `https://www.ak129.cn/flip/version.json`. Extra keys (linux, assets) are ignored.
struct VersionFeed: Decodable, Sendable {
    let macos: MacOSRelease

    struct MacOSRelease: Decodable, Sendable {
        let version: String
        let notes: Notes?
        let download: Download?

        struct Notes: Decodable, Sendable {
            let zh: String?
            let en: String?
        }

        struct Download: Decodable, Sendable {
            let site: String?
            let gitee: String?
            let github: String?
        }
    }
}

import Foundation
import BlindCore

enum CommunityError: LocalizedError {
    case invalid, offline, http(Int), tooLarge, checksum, conflict, quota, missing
    var errorDescription: String? {
        switch self {
        case .invalid: return "The map package or repository address is unsupported."
        case .offline: return "Offline mode is enabled. Downloaded maps remain available."
        case let .http(code): return "The map service returned HTTP \(code). Try again later."
        case .tooLarge: return "This package exceeds the download size limit."
        case .checksum: return "The download checksum does not match. Nothing was installed."
        case .conflict: return "This revision already exists with different contents. Ask the contributor for a new revision."
        case .quota: return "The offline library is full. Remove an unused revision before downloading more."
        case .missing: return "This map revision is no longer available locally."
        }
    }
}

struct PublicMapRelease: Identifiable, Sendable {
    let id: String
    let name: String
    let repository: String
    let tag: String
    let url: URL
    let bytes: Int
    let digest: String?
}

/// Public GitHub Releases only. No login, private token, cookies or arbitrary URL fetch.
struct PublicMapClient {
    // URLProtocol injection lets XCTest exercise the real streaming/status/size path without networking.
    var protocolClasses: [AnyClass]? = nil
    private final class RedirectPolicy: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(request.url.map(PublicMapClient.allowed) == true ? request : nil)
        }
    }
    static func allowed(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil && (url.port == nil || url.port == 443) &&
        ["api.github.com", "github.com", "objects.githubusercontent.com", "release-assets.githubusercontent.com"].contains(url.host?.lowercased() ?? "")
    }
    static func repositoryParts(_ value: String) throws -> [String] {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let characters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.count <= 100 && $0 != "." && $0 != ".." && $0.unicodeScalars.allSatisfy { characters.contains($0) } }) else { throw CommunityError.invalid }
        return parts
    }
    private func get(_ url: URL, limit: Int) async throws -> Data {
        guard Self.allowed(url) else { throw CommunityError.invalid }
        let configuration = URLSessionConfiguration.ephemeral
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        configuration.httpShouldSetCookies = false; configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration, delegate: RedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url); request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BlindAssist-CommunityMaps", forHTTPHeaderField: "User-Agent")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw CommunityError.invalid }
        guard response.statusCode == 200 else { throw CommunityError.http(response.statusCode) }
        guard response.expectedContentLength <= Int64(limit) else { throw CommunityError.tooLarge }
        var data = Data(); data.reserveCapacity(min(limit, 64_000))
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < limit else { throw CommunityError.tooLarge }
            data.append(byte)
        }
        return data
    }
    func releases(repository: String, page: Int) async throws -> [PublicMapRelease] {
        let parts = try Self.repositoryParts(repository)
        guard (1...50).contains(page), let url = URL(string: "https://api.github.com/repos/\(parts[0])/\(parts[1])/releases?per_page=20&page=\(page)") else { throw CommunityError.invalid }
        struct Asset: Decodable { let id: Int64; let name: String; let browser_download_url: String; let size: Int; let digest: String?; let state: String }
        struct Release: Decodable { let name: String?; let tag_name: String; let draft: Bool; let prerelease: Bool; let assets: [Asset] }
        let values = try JSONDecoder().decode([Release].self, from: await get(url, limit: 2_000_000))
        return values.filter { !$0.draft && !$0.prerelease }.flatMap { release in
            release.assets.compactMap { asset -> PublicMapRelease? in
                guard asset.state == "uploaded", asset.name.hasSuffix(".blindplace.json"), (1...PlacePackage.maximumBytes).contains(asset.size),
                      let url = URL(string: asset.browser_download_url), Self.allowed(url), url.host == "github.com",
                      url.path.lowercased().hasPrefix("/\(parts[0].lowercased())/\(parts[1].lowercased())/releases/download/") else { return nil }
                return PublicMapRelease(id: "\(parts.joined(separator: "/")):\(asset.id)", name: asset.name,
                    repository: parts.joined(separator: "/"), tag: release.tag_name, url: url, bytes: asset.size, digest: asset.digest)
            }
        }
    }
    func download(_ release: PublicMapRelease) async throws -> Data {
        let data = try await get(release.url, limit: PlacePackage.maximumBytes)
        guard data.count == release.bytes else { throw CommunityError.checksum }
        return data
    }
}

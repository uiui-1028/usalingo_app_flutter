import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

protocol NetworkSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}

protocol SupabaseRequesting {
    func request<T: Decodable>(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        accessToken: String?,
        body: Encodable?,
        prefer: String?
    ) async throws -> T

    func execute(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem],
        accessToken: String?,
        body: Encodable?,
        prefer: String?
    ) async throws
}

final class SupabaseClient: SupabaseRequesting {
    static let shared = SupabaseClient()

    private let session: any NetworkSession

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(session: any NetworkSession = URLSession.shared) {
        self.session = session
    }

    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil,
        body: Encodable? = nil,
        prefer: String? = nil
    ) async throws -> T {
        var components = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ConnectionFailure.response(data: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try decoder.decode(T.self, from: data)
    }

    func execute(
        path: String,
        method: HTTPMethod = .post,
        queryItems: [URLQueryItem] = [],
        accessToken: String? = nil,
        body: Encodable? = EmptyPayload(),
        prefer: String? = nil
    ) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.setValue(SupabaseConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ConnectionFailure.response(data: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}

struct EmptyPayload: Encodable {}

struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        encodeBlock = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

enum SupabaseError: LocalizedError {
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let message):
            return message
        }
    }
}

/// HTTPの失敗と回線の失敗を分ける。サーバーの本文やトークンは画面へ出さない。
enum ConnectionFailure: LocalizedError {
    case response(status: Int, code: String?)
    case signInRequired
    case configuration

    static func response(data: Data, status: Int) -> ConnectionFailure {
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return .response(status: status, code: body?["code"] as? String ?? body?["error_code"] as? String)
    }

    var invalidRefresh: Bool {
        guard case let .response(status, code) = self, [400, 401, 403].contains(status) else { return false }
        return ["refresh_token_not_found", "refresh_token_already_used", "session_not_found", "session_expired", "user_not_found", "user_banned"].contains(code ?? "")
    }

    static func isTemporary(_ error: Error) -> Bool {
        if case AuthError.tooManyRequests = error { return true }
        if let error = error as? URLError {
            return [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost,
                    .cannotFindHost, .dnsLookupFailed, .dataNotAllowed].contains(error.code)
        }
        if case let .response(status, _) = error as? ConnectionFailure {
            return status == 408 || status == 429 || status >= 500
        }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            return "ログインの期限が切れました。学習記録は端末に残っています。もう一度ログインしてください。"
        case .configuration:
            return "接続設定が入っていません。開発用の接続設定を確認してください。"
        case .response(let status, _):
            if status == 401 || status == 403 {
                return "サーバーが接続を許可しませんでした。接続設定やアカウントの状態を確認してください。"
            }
            return "サーバーとの接続を完了できませんでした。時間をおいて再試行してください。"
        }
    }
}

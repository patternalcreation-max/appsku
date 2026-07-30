import Foundation

// PEAK 3 Relay — Optional Hermes remote brain.
// Modes: direct (default), relay (remote LLM reasoning), hybrid (local tools + remote brain).
// Relay is disabled by default. No background daemon, no VPN, no extension.

enum AgentMode: String, Codable, CaseIterable {
    case direct
    case relay
    case hybrid

    var label: String {
        switch self {
        case .direct: return "Direct"
        case .relay: return "Relay"
        case .hybrid: return "Hybrid"
        }
    }

    var description: String {
        switch self {
        case .direct: return "App calls LLM API directly"
        case .relay: return "Remote Hermes handles reasoning + planning"
        case .hybrid: return "Local app executes tools; Hermes does long research"
        }
    }
}

struct RelaySettings: Codable, Equatable {
    var endpoint: String
    var token: String
    var enabled: Bool

    static let `default` = RelaySettings(
        endpoint: "",
        token: "",
        enabled: false
    )

    static var storageURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("K3Browser", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("relay.json")
    }

    static func load() -> RelaySettings {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode(RelaySettings.self, from: data) else {
            return .default
        }
        return decoded
    }

    func save() {
        let encoded = (try? JSONEncoder().encode(self)) ?? Data()
        try? encoded.write(to: RelaySettings.storageURL, options: .atomic)
    }
}

// Hermes relay client — sends page snapshot + command, receives structured agent response.
// Uses OpenAI-compatible API format so any Hermes relay endpoint works.
final class HermesRelayClient {
    private let session = URLSession.shared

    struct RelayRequest: Codable {
        let command: String
        let pageContext: String
        let availableTools: String
        let mode: AgentMode
    }

    struct RelayResponse: Codable {
        let type: String       // "final" or "tool_call"
        let message: String?
        let tool: String?
        let arguments: [String: String]?
        let reason: String?
    }

    func send(
        command: String,
        pageContext: String,
        availableTools: String,
        mode: AgentMode,
        settings: RelaySettings,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard settings.enabled, !settings.endpoint.isEmpty else {
            completion(.failure(NSError(domain: "K3Relay", code: 1, userInfo: [NSLocalizedDescriptionKey: "Relay not configured"])))
            return
        }

        guard let url = URL(string: settings.endpoint),
              url.scheme?.lowercased() == "https" else {
            completion(.failure(NSError(domain: "K3Relay", code: 2, userInfo: [NSLocalizedDescriptionKey: "Relay endpoint must be HTTPS"])))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "command": command,
            "page_context": String(pageContext.prefix(12000)),
            "available_tools": availableTools,
            "mode": mode.rawValue
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let desc = "Relay HTTP \(http.statusCode): \(Redactor.text(String(raw.prefix(200))))"
                    completion(.failure(NSError(domain: "K3Relay", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: desc])))
                    return
                }
                guard let data = data,
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "K3Relay", code: 3, userInfo: [NSLocalizedDescriptionKey: "Bad relay response"])))
                    return
                }

                // Parse OpenAI-compatible response or direct relay JSON
                if let choices = obj["choices"] as? [[String: Any]],
                   let msg = choices.first?["message"] as? [String: Any],
                   let content = msg["content"] as? String {
                    completion(.success(content))
                } else if let content = obj["content"] as? String {
                    completion(.success(content))
                } else if let message = obj["message"] as? String {
                    completion(.success(message))
                } else {
                    completion(.failure(NSError(domain: "K3Relay", code: 4, userInfo: [NSLocalizedDescriptionKey: "Relay returned unexpected format"])))
                }
            }
        }.resume()
    }
}

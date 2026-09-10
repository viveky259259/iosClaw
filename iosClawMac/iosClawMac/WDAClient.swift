import Foundation

protocol WDAControlling {
    func status() async throws -> String
    func createSession(bundleID: String) async throws -> String
    func deleteSession(_ sessionID: String) async
    func perform(_ step: QAFlowStep, sessionID: String) async throws
    func screenshot(sessionID: String) async throws -> Data
}

/// Direct WebDriverAgent client. It deliberately speaks only to loopback WDA;
/// a future fleet runner is responsible for terminating remote device transport.
actor WDAClient: WDAControlling {
    private let endpoint: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(endpoint: URL, session: URLSession = .shared) throws {
        guard endpoint.scheme == "http" || endpoint.scheme == "https",
              let host = endpoint.host,
              host == "127.0.0.1" || host == "localhost" || host == "::1"
        else {
            throw WDAError.untrustedEndpoint
        }
        self.endpoint = endpoint
        self.session = session
    }

    func status() async throws -> String {
        let response = try await request(method: "GET", path: "status")
        if let ready = response.value?.objectValue?["ready"]?.boolValue {
            return ready ? "ready" : "not ready"
        }
        return response.value?.objectValue?["message"]?.stringValue ?? "WDA responded"
    }

    func createSession(bundleID: String) async throws -> String {
        let capabilities: JSONValue = .object([
            "alwaysMatch": .object([
                "platformName": .string("iOS"),
                "bundleId": .string(bundleID)
            ])
        ])
        let response = try await request(
            method: "POST",
            path: "session",
            body: .object([
                "capabilities": capabilities,
                "desiredCapabilities": .object(["bundleId": .string(bundleID)])
            ])
        )
        if let sessionID = response.sessionId { return sessionID }
        if let sessionID = response.value?.objectValue?["sessionId"]?.stringValue { return sessionID }
        throw WDAError.invalidResponse("WDA did not return a session identifier")
    }

    func deleteSession(_ sessionID: String) async {
        _ = try? await request(method: "DELETE", path: "session/\(sessionID)")
    }

    func perform(_ step: QAFlowStep, sessionID: String) async throws {
        switch step.action {
        case .assertVisible:
            _ = try await resolve(step.selector, sessionID: sessionID)
        case .screenshot:
            _ = try await screenshot(sessionID: sessionID)
        case .tap:
            if let selector = step.selector {
                let elementID = try await resolve(selector, sessionID: sessionID)
                _ = try await request(method: "POST", path: "session/\(sessionID)/element/\(elementID)/click")
            } else {
                try await customGesture("tap/0", step: step, sessionID: sessionID)
            }
        case .typeText:
            guard let selector = step.selector,
                  let text = step.parameters["text"]?.stringValue
            else { throw WDAError.invalidStep("Type text requires a selector and a text parameter") }
            let elementID = try await resolve(selector, sessionID: sessionID)
            _ = try await request(
                method: "POST",
                path: "session/\(sessionID)/element/\(elementID)/value",
                body: .object(["value": .array(text.map { .string(String($0)) })])
            )
        case .doubleTap:
            try await customGesture("doubleTap", step: step, sessionID: sessionID)
        case .longPress:
            try await customGesture("touchAndHold", step: step, sessionID: sessionID)
        case .swipe:
            try await customGesture("swipe", step: step, sessionID: sessionID)
        case .scroll:
            try await customGesture("scroll", step: step, sessionID: sessionID)
        case .drag:
            try await customGesture("dragfromtoforduration", step: step, sessionID: sessionID)
        case .pinch:
            try await customGesture("pinch", step: step, sessionID: sessionID)
        case .rotate:
            try await customGesture("rotate", step: step, sessionID: sessionID)
        }

        if let postcondition = step.postcondition {
            _ = try await resolve(postcondition, sessionID: sessionID)
        }
    }

    func screenshot(sessionID: String) async throws -> Data {
        let response = try await request(method: "GET", path: "session/\(sessionID)/screenshot")
        guard let encoded = response.value?.stringValue,
              let image = Data(base64Encoded: encoded)
        else { throw WDAError.invalidResponse("WDA returned an invalid screenshot") }
        return image
    }

    private func resolve(_ selector: QASelector?, sessionID: String) async throws -> String {
        guard let selector else { throw WDAError.invalidStep("This step needs a selector") }
        let response = try await request(
            method: "POST",
            path: "session/\(sessionID)/element",
            body: .object([
                "using": .string(selector.strategy.wdaUsing),
                "value": .string(selector.value)
            ])
        )
        guard let values = response.value?.objectValue,
              let elementID = values["element-6066-11e4-a52e-4f735466cecf"]?.stringValue ?? values["ELEMENT"]?.stringValue
        else { throw WDAError.elementNotFound(selector.value) }
        return elementID
    }

    private func customGesture(_ command: String, step: QAFlowStep, sessionID: String) async throws {
        var payload = step.parameters
        if let selector = step.selector {
            let elementID = try await resolve(selector, sessionID: sessionID)
            payload["element"] = .string(elementID)
        }
        _ = try await request(
            method: "POST",
            path: "session/\(sessionID)/wda/\(command)",
            body: .object(payload)
        )
    }

    private func request(method: String, path: String, body: JSONValue? = nil) async throws -> WDAResponse {
        let url = endpoint.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, urlResponse) = try await session.data(for: request)
        guard let response = urlResponse as? HTTPURLResponse else { throw WDAError.invalidResponse("No HTTP response") }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? decoder.decode(WDAResponse.self, from: data))?.message ?? "HTTP \(response.statusCode)"
            throw WDAError.requestFailed(message)
        }
        do {
            return try decoder.decode(WDAResponse.self, from: data)
        } catch {
            throw WDAError.invalidResponse("Could not decode WDA response")
        }
    }
}

private struct WDAResponse: Decodable {
    let value: JSONValue?
    let sessionId: String?
    let message: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decodeIfPresent(JSONValue.self, forKey: .value)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case sessionId
        case message
    }
}

enum WDAError: LocalizedError {
    case untrustedEndpoint
    case requestFailed(String)
    case invalidResponse(String)
    case invalidStep(String)
    case elementNotFound(String)

    var errorDescription: String? {
        switch self {
        case .untrustedEndpoint: "QA Mode accepts only a loopback WebDriverAgent endpoint."
        case .requestFailed(let message), .invalidResponse(let message), .invalidStep(let message): message
        case .elementNotFound(let selector): "No accessibility element matched \(selector)."
        }
    }
}

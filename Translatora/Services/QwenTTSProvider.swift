import Foundation

enum TTSWebSocketMessage: Equatable, Sendable {
    case data(Data)
    case string(String)
}

protocol TTSWebSocketTask: Sendable {
    func connect() async throws
    func send(_ message: TTSWebSocketMessage) async throws
    func receive() async throws -> TTSWebSocketMessage
    func cancel()
}

protocol TTSWebSocketSession: Sendable {
    func makeWebSocketTask(with request: URLRequest) -> any TTSWebSocketTask
}

struct URLSessionTTSWebSocketSession: TTSWebSocketSession {
    func makeWebSocketTask(with request: URLRequest) -> any TTSWebSocketTask {
        URLSessionTTSWebSocketTask(request: request)
    }
}

private final class URLSessionTTSWebSocketTask: TTSWebSocketTask, @unchecked Sendable {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private let connectionState: TTSWebSocketConnectionState

    init(request: URLRequest) {
        let connectionState = TTSWebSocketConnectionState()
        let delegate = TTSWebSocketConnectionDelegate(state: connectionState)
        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )

        self.connectionState = connectionState
        self.session = session
        task = session.webSocketTask(with: request)
    }

    func connect() async throws {
        task.resume()
        try await connectionState.waitUntilOpen()
    }

    func send(_ message: TTSWebSocketMessage) async throws {
        switch message {
        case let .data(data):
            try await task.send(.data(data))
        case let .string(string):
            try await task.send(.string(string))
        }
    }

    func receive() async throws -> TTSWebSocketMessage {
        switch try await task.receive() {
        case let .data(data):
            .data(data)
        case let .string(string):
            .string(string)
        @unknown default:
            throw TTSProviderError.invalidResponse
        }
    }

    func cancel() {
        task.cancel(with: .goingAway, reason: nil)
        session.finishTasksAndInvalidate()
    }
}

private actor TTSWebSocketConnectionState {
    private enum Status {
        case connecting
        case open
        case failed(Error)
    }

    private var status = Status.connecting
    private var continuation: CheckedContinuation<Void, Error>?

    func waitUntilOpen() async throws {
        switch status {
        case .open:
            return
        case let .failed(error):
            throw error
        case .connecting:
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func didOpen() {
        guard case .connecting = status else { return }
        status = .open
        continuation?.resume()
        continuation = nil
    }

    func didFail(_ error: Error) {
        guard case .connecting = status else { return }
        status = .failed(error)
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private final class TTSWebSocketConnectionDelegate:
    NSObject,
    URLSessionWebSocketDelegate,
    @unchecked Sendable
{
    private let state: TTSWebSocketConnectionState

    init(state: TTSWebSocketConnectionState) {
        self.state = state
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task {
            await state.didOpen()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task {
            await state.didFail(error)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonText = reason
            .flatMap { String(data: $0, encoding: .utf8) }
            ?? "连接在握手前关闭（\(closeCode.rawValue)）"
        Task {
            await state.didFail(
                TTSProviderError.transport(reasonText)
            )
        }
    }
}

struct QwenTTSProvider: TTSProvider {
    static let model = "qwen-audio-3.0-tts-plus"

    private let configuration: QwenConfiguration
    private let webSocketSession: any TTSWebSocketSession
    private let webSocketURL: URL

    init(
        configuration: QwenConfiguration,
        webSocketSession: any TTSWebSocketSession = URLSessionTTSWebSocketSession(),
        webSocketURL: URL? = nil
    ) {
        let configuration = configuration.normalized
        self.configuration = configuration
        self.webSocketSession = webSocketSession
        self.webSocketURL = webSocketURL ?? configuration.region.ttsWebSocketURL
    }

    func synthesize(_ request: TTSRequest) async throws -> TTSResponse {
        let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw TTSProviderError.emptyText }
        guard !configuration.apiKey.isEmpty else {
            throw TTSProviderError.missingAPIKey("Qwen Token Plan")
        }

        var urlRequest = URLRequest(url: webSocketURL)
        urlRequest.timeoutInterval = 60
        urlRequest.setValue(
            "Bearer \(configuration.apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.setValue(
            "Translatora/1.0 (macOS; DashScope WebSocket)",
            forHTTPHeaderField: "User-Agent"
        )

        let socket = webSocketSession.makeWebSocketTask(with: urlRequest)

        return try await withTaskCancellationHandler {
            defer { socket.cancel() }
            do {
                try await socket.connect()
                return try await runSynthesis(
                    text: text,
                    language: request.language,
                    socket: socket
                )
            } catch let error as TTSProviderError {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw resolvedTransportError(error)
            }
        } onCancel: {
            Task { @MainActor in
                socket.cancel()
            }
        }
    }

    private func runSynthesis(
        text: String,
        language: TranslationLanguage,
        socket: any TTSWebSocketTask
    ) async throws -> TTSResponse {
        let taskID = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
        try await send(
            [
                "header": commandHeader(action: "run-task", taskID: taskID),
                "payload": [
                    "task_group": "audio",
                    "task": "tts",
                    "function": "SpeechSynthesizer",
                    "model": Self.model,
                    "parameters": [
                        "text_type": "PlainText",
                        "voice": configuration.ttsVoice.rawValue,
                        "format": "mp3",
                        "sample_rate": 22_050,
                        "volume": 50,
                        "rate": 1,
                        "pitch": 1,
                        "seed": 0,
                        "type": 0,
                        "language_hints": [language.qwenLanguageHint]
                    ],
                    "input": [:]
                ]
            ],
            to: socket
        )

        var audioData = Data()
        var didSendText = false

        while !Task.isCancelled {
            switch try await socket.receive() {
            case let .data(chunk):
                audioData.append(chunk)
            case let .string(string):
                guard let data = string.data(using: .utf8),
                      let event = try? JSONDecoder().decode(QwenTTSEvent.self, from: data)
                else {
                    continue
                }

                switch event.header.event {
                case "task-started":
                    guard !didSendText else { continue }
                    didSendText = true
                    try await send(
                        [
                            "header": commandHeader(
                                action: "continue-task",
                                taskID: taskID
                            ),
                            "payload": ["input": ["text": text]]
                        ],
                        to: socket
                    )
                    try await send(
                        [
                            "header": commandHeader(
                                action: "finish-task",
                                taskID: taskID
                            ),
                            "payload": ["input": [:]]
                        ],
                        to: socket
                    )
                case "task-finished":
                    guard !audioData.isEmpty else {
                        throw TTSProviderError.invalidResponse
                    }
                    return TTSResponse(
                        audioData: audioData,
                        fileExtension: "mp3",
                        model: Self.model
                    )
                case "task-failed", "error":
                    throw TTSProviderError.service(
                        provider: "Qwen Token Plan",
                        message: event.resolvedMessage ?? "未知错误"
                    )
                default:
                    continue
                }
            }
        }

        throw CancellationError()
    }

    private func commandHeader(action: String, taskID: String) -> [String: Any] {
        [
            "action": action,
            "task_id": taskID,
            "streaming": "duplex"
        ]
    }

    private func send(
        _ object: [String: Any],
        to socket: any TTSWebSocketTask
    ) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TTSProviderError.invalidResponse
        }
        try await socket.send(.string(string))
    }

    private func resolvedTransportError(_ error: Error) -> TTSProviderError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorBadServerResponse {
            return .service(
                provider: "Qwen Token Plan",
                message: "WebSocket 握手被服务端拒绝。请确认使用 Token Plan 专用 Key（通常以 sk-sp- 开头），并在 API Key 设置中测试连接"
            )
        }

        return .transport(error.localizedDescription)
    }
}

private struct QwenTTSEvent: Decodable {
    struct Header: Decodable {
        let event: String
        let errorMessage: String?
        let errorCode: String?

        enum CodingKeys: String, CodingKey {
            case event
            case errorMessage = "error_message"
            case errorCode = "error_code"
        }
    }

    struct Payload: Decodable {
        let message: String?
    }

    let header: Header
    let payload: Payload?

    var resolvedMessage: String? {
        header.errorMessage ?? payload?.message ?? header.errorCode
    }
}

private extension TranslationLanguage {
    var qwenLanguageHint: String {
        switch self {
        case .english: "en"
        case .simplifiedChinese, .traditionalChinese: "zh"
        case .japanese: "ja"
        case .korean: "ko"
        case .french: "fr"
        case .german: "de"
        case .spanish: "es"
        }
    }
}

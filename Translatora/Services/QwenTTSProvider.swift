import Foundation

enum TTSWebSocketMessage: Equatable, Sendable {
    case data(Data)
    case string(String)
}

protocol TTSWebSocketTask: Sendable {
    func resume()
    func send(_ message: TTSWebSocketMessage) async throws
    func receive() async throws -> TTSWebSocketMessage
    func cancel()
}

protocol TTSWebSocketSession: Sendable {
    func makeWebSocketTask(with request: URLRequest) -> any TTSWebSocketTask
}

struct URLSessionTTSWebSocketSession: TTSWebSocketSession {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func makeWebSocketTask(with request: URLRequest) -> any TTSWebSocketTask {
        URLSessionTTSWebSocketTask(task: session.webSocketTask(with: request))
    }
}

private final class URLSessionTTSWebSocketTask: TTSWebSocketTask, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func resume() {
        task.resume()
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
    }
}

struct QwenTTSProvider: TTSProvider {
    static let model = "qwen-audio-3.0-tts-plus"
    static let voice = "longanlingxin"

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
        urlRequest.setValue("enable", forHTTPHeaderField: "X-DashScope-DataInspection")

        let socket = webSocketSession.makeWebSocketTask(with: urlRequest)
        socket.resume()

        return try await withTaskCancellationHandler {
            defer { socket.cancel() }
            do {
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
                throw TTSProviderError.transport(error.localizedDescription)
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
        let taskID = UUID().uuidString.lowercased()
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
                        "voice": Self.voice,
                        "format": "mp3",
                        "sample_rate": 22_050,
                        "volume": 50,
                        "rate": 1,
                        "pitch": 1,
                        "enable_ssml": false,
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

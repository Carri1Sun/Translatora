import Foundation
import Testing
@testable import Translatora

@MainActor
struct QwenTTSProviderTests {
    @Test
    func usesDuplexProtocolAndCollectsBinaryAudio() async throws {
        let task = QwenTTSStubTask(
            messages: [
                .string(#"{"header":{"event":"task-started"}}"#),
                .data(Data([0x49, 0x44])),
                .data(Data([0x33])),
                .string(#"{"header":{"event":"task-finished"}}"#)
            ]
        )
        let session = QwenTTSStubSession(task: task)
        let provider = QwenTTSProvider(
            configuration: QwenConfiguration(
                apiKey: "  qwen-tts-key  ",
                model: .v38Max,
                region: .international,
                ttsVoice: .longAnLingxin
            ),
            webSocketSession: session
        )

        let response = try await provider.synthesize(
            TTSRequest(text: "hello", language: .english)
        )

        #expect(response.audioData == Data([0x49, 0x44, 0x33]))
        #expect(response.model == "qwen-audio-3.0-tts-plus")
        let request = try #require(session.lastRequest)
        #expect(
            request.url?.absoluteString
                == "wss://token-plan.ap-southeast-1.maas.aliyuncs.com/api-ws/v1/inference"
        )
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Bearer qwen-tts-key"
        )
        #expect(request.value(forHTTPHeaderField: "User-Agent") != nil)
        #expect(request.value(forHTTPHeaderField: "X-DashScope-DataInspection") == nil)
        #expect(task.didConnect)
        #expect(task.didCancel)

        let commands = try task.sentMessages.map(decodeObject)
        #expect(commands.count == 3)
        #expect(commandAction(commands[0]) == "run-task")
        #expect(commandAction(commands[1]) == "continue-task")
        #expect(commandAction(commands[2]) == "finish-task")

        let runPayload = try #require(commands[0]["payload"] as? [String: Any])
        #expect(runPayload["model"] as? String == "qwen-audio-3.0-tts-plus")
        let runHeader = try #require(commands[0]["header"] as? [String: Any])
        let taskID = try #require(runHeader["task_id"] as? String)
        #expect(taskID.count == 32)
        #expect(!taskID.contains("-"))
        let parameters = try #require(runPayload["parameters"] as? [String: Any])
        #expect(parameters["voice"] as? String == "longanlingxin")
        #expect(parameters["seed"] as? Int == 0)
        #expect(parameters["type"] as? Int == 0)
        #expect(parameters["language_hints"] as? [String] == ["en"])
    }

    @Test
    func connectsBeforeSendingRunTask() async throws {
        let task = QwenTTSStubTask(
            messages: [
                .string(#"{"header":{"event":"task-started"}}"#),
                .data(Data([0x49, 0x44, 0x33])),
                .string(#"{"header":{"event":"task-finished"}}"#)
            ]
        )
        let provider = QwenTTSProvider(
            configuration: QwenConfiguration(
                apiKey: "qwen-tts-key",
                model: .v38Max,
                region: .china
            ),
            webSocketSession: QwenTTSStubSession(task: task)
        )

        _ = try await provider.synthesize(
            TTSRequest(text: "hello", language: .english)
        )

        #expect(task.didConnect)
        #expect(task.didSendOnlyAfterConnecting)
    }

    @Test
    func explainsRejectedWebSocketHandshake() async {
        let task = QwenTTSStubTask(
            connectError: NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorBadServerResponse
            ),
            messages: []
        )
        let provider = QwenTTSProvider(
            configuration: QwenConfiguration(
                apiKey: "qwen-tts-key",
                model: .v38Max,
                region: .international
            ),
            webSocketSession: QwenTTSStubSession(task: task)
        )

        await #expect(
            throws: TTSProviderError.service(
                provider: "Qwen Token Plan",
                message: "WebSocket 握手被服务端拒绝。请确认使用 Token Plan 专用 Key（通常以 sk-sp- 开头），并在 API Key 设置中测试连接"
            )
        ) {
            try await provider.synthesize(
                TTSRequest(text: "hello", language: .english)
            )
        }
    }

    private func decodeObject(_ message: TTSWebSocketMessage) throws -> [String: Any] {
        guard case let .string(string) = message else {
            throw QwenTTSStubError.unexpectedMessage
        }
        return try #require(
            JSONSerialization.jsonObject(with: Data(string.utf8)) as? [String: Any]
        )
    }

    private func commandAction(_ object: [String: Any]) -> String? {
        (object["header"] as? [String: Any])?["action"] as? String
    }
}

private final class QwenTTSStubSession: TTSWebSocketSession, @unchecked Sendable {
    let task: QwenTTSStubTask
    private(set) var lastRequest: URLRequest?

    init(task: QwenTTSStubTask) {
        self.task = task
    }

    func makeWebSocketTask(with request: URLRequest) -> any TTSWebSocketTask {
        lastRequest = request
        return task
    }
}

private final class QwenTTSStubTask: TTSWebSocketTask, @unchecked Sendable {
    private var messages: [TTSWebSocketMessage]
    private(set) var sentMessages: [TTSWebSocketMessage] = []
    private(set) var didConnect = false
    private(set) var didCancel = false
    private(set) var didSendOnlyAfterConnecting = true
    private let connectError: Error?

    init(connectError: Error? = nil, messages: [TTSWebSocketMessage]) {
        self.connectError = connectError
        self.messages = messages
    }

    func connect() async throws {
        if let connectError {
            throw connectError
        }
        didConnect = true
    }

    func send(_ message: TTSWebSocketMessage) async throws {
        if !didConnect {
            didSendOnlyAfterConnecting = false
            throw QwenTTSStubError.notConnected
        }
        sentMessages.append(message)
    }

    func receive() async throws -> TTSWebSocketMessage {
        guard !messages.isEmpty else {
            throw QwenTTSStubError.noMoreMessages
        }
        return messages.removeFirst()
    }

    func cancel() {
        didCancel = true
    }
}

private enum QwenTTSStubError: Error {
    case noMoreMessages
    case notConnected
    case unexpectedMessage
}

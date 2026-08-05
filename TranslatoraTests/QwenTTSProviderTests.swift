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
                region: .international
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
                == "wss://token-plan.ap-southeast-1.maas.aliyuncs.com/api-ws/v1/inference/"
        )
        #expect(
            request.value(forHTTPHeaderField: "Authorization")
                == "Bearer qwen-tts-key"
        )
        #expect(task.didResume)
        #expect(task.didCancel)

        let commands = try task.sentMessages.map(decodeObject)
        #expect(commands.count == 3)
        #expect(commandAction(commands[0]) == "run-task")
        #expect(commandAction(commands[1]) == "continue-task")
        #expect(commandAction(commands[2]) == "finish-task")

        let runPayload = try #require(commands[0]["payload"] as? [String: Any])
        #expect(runPayload["model"] as? String == "qwen-audio-3.0-tts-plus")
        let parameters = try #require(runPayload["parameters"] as? [String: Any])
        #expect(parameters["voice"] as? String == "longanlingxin")
        #expect(parameters["language_hints"] as? [String] == ["en"])
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
    private(set) var didResume = false
    private(set) var didCancel = false

    init(messages: [TTSWebSocketMessage]) {
        self.messages = messages
    }

    func resume() {
        didResume = true
    }

    func send(_ message: TTSWebSocketMessage) async throws {
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
    case unexpectedMessage
}

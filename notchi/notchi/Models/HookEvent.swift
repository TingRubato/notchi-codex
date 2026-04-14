import Foundation

enum AIProvider: String, Codable, Sendable {
    case claude
    case codex
    case geminiCLI = "gemini-cli"

    static func from(rawValue: String?) -> AIProvider? {
        guard let rawValue else { return nil }
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")

        switch normalized {
        case "claude":
            return .claude
        case "codex":
            return .codex
        case "gemini", "gemini-cli":
            return .geminiCLI
        default:
            return nil
        }
    }
}

struct HookEvent: Decodable, Sendable {
    let sessionId: String
    let transcriptPath: String?
    let cwd: String
    let event: String
    let status: String
    let pid: Int?
    let tty: String?
    let tool: String?
    let toolInput: [String: AnyCodable]?
    let toolUseId: String?
    let userPrompt: String?
    let permissionMode: String?
    let interactive: Bool?
    let provider: AIProvider?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd, event, status, pid, tty, tool
        case toolInput = "tool_input"
        case toolUseId = "tool_use_id"
        case userPrompt = "user_prompt"
        case permissionMode = "permission_mode"
        case interactive
        case provider
    }

    init(
        sessionId: String,
        transcriptPath: String?,
        cwd: String,
        event: String,
        status: String,
        pid: Int?,
        tty: String?,
        tool: String?,
        toolInput: [String: AnyCodable]?,
        toolUseId: String?,
        userPrompt: String?,
        permissionMode: String?,
        interactive: Bool?,
        provider: AIProvider?
    ) {
        self.sessionId = sessionId
        self.transcriptPath = transcriptPath
        self.cwd = cwd
        self.event = event
        self.status = status
        self.pid = pid
        self.tty = tty
        self.tool = tool
        self.toolInput = toolInput
        self.toolUseId = toolUseId
        self.userPrompt = userPrompt
        self.permissionMode = permissionMode
        self.interactive = interactive
        self.provider = provider
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        cwd = try container.decode(String.self, forKey: .cwd)
        event = try container.decode(String.self, forKey: .event)
        status = try container.decode(String.self, forKey: .status)
        pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        tty = try container.decodeIfPresent(String.self, forKey: .tty)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        toolInput = try container.decodeIfPresent([String: AnyCodable].self, forKey: .toolInput)
        toolUseId = try container.decodeIfPresent(String.self, forKey: .toolUseId)
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt)
        permissionMode = try container.decodeIfPresent(String.self, forKey: .permissionMode)
        interactive = try container.decodeIfPresent(Bool.self, forKey: .interactive)
        provider = AIProvider.from(rawValue: try container.decodeIfPresent(String.self, forKey: .provider))
    }
}

struct AnyCodable: Decodable, @unchecked Sendable {
    nonisolated(unsafe) let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }
}

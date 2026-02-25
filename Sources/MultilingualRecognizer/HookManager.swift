import Foundation

// MARK: - Hook Configuration

struct HookConfig: Codable {
    var hooks: [String: [Hook]]

    struct Hook: Codable {
        var name: String
        var command: String
        var enabled: Bool
        var async: Bool
        var timeout: Int?  // seconds

        enum CodingKeys: String, CodingKey {
            case name, command, enabled, async, timeout
        }
    }
}

// MARK: - Hook Manager

@available(macOS 26.0, *)
actor HookManager {
    private var config: HookConfig?
    private let configPath: String

    init(configPath: String = "~/.pentecost/hooks.yaml") {
        self.configPath = configPath.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        Task {
            await loadConfig()
        }
    }

    /// Load configuration from YAML file
    private func loadConfig() {
        guard FileManager.default.fileExists(atPath: configPath) else {
            print("ℹ️ No hooks config found at \(configPath)")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))

            // Simple YAML parsing - convert to JSON-like structure
            // For now, we'll use a simple parser since we don't have YAML dependency
            config = try parseYAML(data)

            let hookCount = config?.hooks.values.flatMap { $0 }.filter { $0.enabled }.count ?? 0
            print("✅ Loaded \(hookCount) enabled hooks from \(configPath)")
        } catch {
            print("❌ Failed to load hooks config: \(error)")
        }
    }

    /// Execute hooks for a specific event
    func executeHooks(event: String, context: [String: String]) async {
        guard let config = config else { return }
        guard let hooks = config.hooks[event] else { return }

        let enabledHooks = hooks.filter { $0.enabled }
        guard !enabledHooks.isEmpty else { return }

        print("🪝 Executing \(enabledHooks.count) hook(s) for event: \(event)")

        for hook in enabledHooks {
            if hook.async {
                // Execute asynchronously - don't wait
                Task {
                    await executeHook(hook, context: context)
                }
            } else {
                // Execute synchronously - wait for completion
                await executeHook(hook, context: context)
            }
        }
    }

    /// Execute a single hook
    private func executeHook(_ hook: HookConfig.Hook, context: [String: String]) async {
        print("  ▶️  Running hook: \(hook.name)")

        let process = Process()

        // Expand command with context variables
        var expandedCommand = hook.command
        for (key, value) in context {
            expandedCommand = expandedCommand.replacingOccurrences(of: "{\(key)}", with: value)
        }

        // Set up process to run command via shell
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", expandedCommand]

        // Capture output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()

            // Handle timeout if specified
            if let timeout = hook.timeout {
                let timeoutTask = Task {
                    try await Task.sleep(for: .seconds(timeout))
                    if process.isRunning {
                        print("  ⚠️  Hook '\(hook.name)' timed out after \(timeout)s - terminating")
                        process.terminate()
                    }
                }

                // Wait for process or timeout
                process.waitUntilExit()
                timeoutTask.cancel()
            } else {
                process.waitUntilExit()
            }

            // Check exit status
            if process.terminationStatus == 0 {
                print("  ✅ Hook '\(hook.name)' completed successfully")

                // Print output if any
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                    print("     Output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            } else {
                print("  ❌ Hook '\(hook.name)' failed with exit code \(process.terminationStatus)")

                // Print error output
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    print("     Error: \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        } catch {
            print("  ❌ Hook '\(hook.name)' failed to execute: \(error)")
        }
    }

    /// Simple YAML parser for our limited use case
    private func parseYAML(_ data: Data) throws -> HookConfig {
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "HookManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid YAML encoding"])
        }

        var hooks: [String: [HookConfig.Hook]] = [:]
        var currentEvent: String?
        var currentHook: [String: Any] = [:]

        let lines = yamlString.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Check indentation level
            let indent = line.prefix(while: { $0 == " " }).count

            if indent == 0 && trimmed == "hooks:" {
                continue
            } else if indent == 2 && trimmed.hasSuffix(":") {
                // Event name (e.g., "on_transcript_end:")
                if let event = currentEvent, !currentHook.isEmpty {
                    addHook(&hooks, event: event, hookData: currentHook)
                    currentHook = [:]
                }
                currentEvent = String(trimmed.dropLast())
            } else if indent == 4 && trimmed.hasPrefix("- name:") {
                // Start of new hook
                if let event = currentEvent, !currentHook.isEmpty {
                    addHook(&hooks, event: event, hookData: currentHook)
                }
                currentHook = [:]
                let name = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                currentHook["name"] = name
            } else if indent == 6 {
                // Hook property
                let parts = trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 {
                    let key = parts[0]
                    let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))

                    switch key {
                    case "command":
                        currentHook["command"] = value
                    case "enabled":
                        currentHook["enabled"] = value.lowercased() == "true"
                    case "async":
                        currentHook["async"] = value.lowercased() == "true"
                    case "timeout":
                        currentHook["timeout"] = Int(value)
                    default:
                        break
                    }
                }
            }
        }

        // Add last hook
        if let event = currentEvent, !currentHook.isEmpty {
            addHook(&hooks, event: event, hookData: currentHook)
        }

        return HookConfig(hooks: hooks)
    }

    private func addHook(_ hooks: inout [String: [HookConfig.Hook]], event: String, hookData: [String: Any]) {
        guard let name = hookData["name"] as? String,
              let command = hookData["command"] as? String else {
            return
        }

        let hook = HookConfig.Hook(
            name: name,
            command: command,
            enabled: hookData["enabled"] as? Bool ?? true,
            async: hookData["async"] as? Bool ?? true,
            timeout: hookData["timeout"] as? Int
        )

        if hooks[event] == nil {
            hooks[event] = []
        }
        hooks[event]?.append(hook)
    }
}

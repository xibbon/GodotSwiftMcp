import GodotSwiftMcp
import MCP
import Foundation
import Logging

LoggingSystem.bootstrap(StreamLogHandler.standardError)
let logger = Logger(label: "godotMcp")
logger.error("MIGUEL STARTING")

let transport = StdioTransport(logger: logger)
let provider = GodotLocalSocketProvider()

let server = GodotMcpServer(logger: logger, provider: provider)
try await server.start(on: transport)

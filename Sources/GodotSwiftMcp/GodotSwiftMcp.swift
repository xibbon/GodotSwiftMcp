import MCP
import Logging

public class GodotMcpServer: @unchecked Sendable {
    let server: Server
    let logger: Logger
    let provider: GodotProvider
    
    public init(logger: Logger, provider: GodotProvider) {
        // Initialize the server
        server = Server(
            name: "GodotSwiftMcpServer",
            version: "1.0.0",
            capabilities: .init(
                prompts: .init(listChanged: true),
                resources: .init(subscribe: true, listChanged: true),
                tools: .init(listChanged: true))
        )
        self.logger = logger
        self.provider = provider
    }
    
    public func start(on transport: Transport) async throws {
        try await server.start(transport: transport)
        
        await registerHandlers()
        await server.waitUntilCompleted()
    }

    func jsonString(_ value: String) -> String {
        value
    }
    
    func registerHandlers() async {
        // Register a tool list handler
        await server.withMethodHandler(ListTools.self) { _ in
            let tools = [
                Tool(
                    name: "create_node",
                    description: "Creates a new node in the current Godot scene",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "parent_path": .object([
                                "type": .string("string"),
                                "description": .string("Path to the parent node where the new node will be created (e.g. '/root\', '/root/MainScene')")
                            ]),
                            "node_type": .object([
                                "type": .string("string"),
                                "description": .string("Type of node to create (e.g. 'Node2D', 'Sprite2D', 'Label')")
                            ]),
                            "node_name": .object([
                                "type": .string("string"),
                                "description": .string("Name of the new node")
                            ])
                        ]),
                        "required": .array([.string("parent_path"), .string("node_type"), .string("node_name")])
                    ]),
                    annotations: .init(title: "Creates a new node in the current Godot scene", readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true)
                ),
                Tool(
                    name: "delete_node",
                    description: "Deletes a node in the current Godot scene",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "node_path": .object([
                                "type": .string("string"),
                                "description": .string("Path to the node to delete (e.g. '/root/MainScene/Player')")
                                ])
                            ]),
                        "required": .array([.string("node_path")])
                    ]),
                    annotations: .init(title: "Deltes a node in the current Godot scene", readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true)
                ),
                Tool(
                    name: "update_node_property",
                    description: "Updaets a property of a node in the Godot scene tree",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "node_path": .object([
                                "type": .string("string"),
                                "description": .string("Path of the node to update (e.g. '/root\', '/root/MainScene/Player')")
                            ]),
                            "property": .object([
                                "type": .string("string"),
                                "description": .string("Name of the property to update (e.g. 'position', 'scale', 'text', 'modulate)")
                            ]),
                            "value": .object([
                                "type": .string("any"),
                                "description": .string("New value for the property")
                            ])
                        ]),
                        "required": .array([.string("node_path"), .string("property"), .string("value")])
                    ]),
                    annotations: .init(title: "Updates a propert of a node in the Godot scene tree", readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true)
                ),
                Tool(
                    name: "get_node_properties",
                    description: "Get all properties of a node in the Godot scene tree",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "node_path": .object([
                                "type": .string("string"),
                                "description": .string("Path to the node to inspect (e.g. '/root/MainScene/Player')")
                                ])
                            ]),
                        "required": .array([.string("node_path")])
                    ]),
                    annotations: .init(title: "Get all properties of a node in the Godot scene tree", readOnlyHint: true, destructiveHint: false, idempotentHint:true, openWorldHint: true)
                ),
                Tool(
                    name: "list_nodes",
                    description: "Lists all child nodes under a parent node in the Godot scene tree",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "parent_path": .object([
                                "type": .string("string"),
                                "description": .string("Path to the parent node (e.g. '/root', '/root/MainScene')")
                                ])
                            ]),
                        "required": .array([.string("node_path")])
                    ]),
                    annotations: .init(title: "Lists all child nodes under a parent node in the Godot scene tree", readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: true)
                )
            ]
            return .init(tools: tools)
        }

        // Register a tool call handler
        await server.withMethodHandler(CallTool.self) { params in
            self.logger.info("INVOKE CALLED \(params.name) isnil=\(params.arguments == nil) count=\(params.arguments?.count ?? -1)")
            if let keys = params.arguments {
                self.logger.info("FIRST is \(keys)")
                for (k, v) in keys {
                    self.logger.info("Got key: \(k) -> \(v)")
                }
            }
            switch params.name {
            case "create_node":
                guard let args = params.arguments,
                      let parentPath = args["parent_path"]?.stringValue,
                      let nodeType = args["node_type"]?.stringValue,
                      let nodeName = args["node_name"]?.stringValue
                else {
                    throw MCPError.invalidParams("Missing parameter")
                }
                switch self.provider.createNode(parentPath: parentPath, nodeType: nodeType, nodeName: nodeName) {
                case .success(let newPath):
                    let result = "Created \(nodeType) named \(nodeName) at \(newPath)"
                    return .init(
                        content: [.text(result)],
                        isError: false
                    )
                case .failure(let error):
                    return .init(error)
                }
            case "delete_node":
                guard let args = params.arguments,
                      let nodePath = args["node_path"]?.stringValue
                else {
                    throw MCPError.invalidParams("Missing parameter")
                }
                switch self.provider.deleteNode(nodePath: nodePath) {
                case .success(let success):
                    return .init(content: [.text("Deleted node at '\(nodePath)'")], isError: false)
                case .failure(let error):
                    return .init(error)
                }
            case "update_node_property":
                guard let args = params.arguments,
                      let nodePath = args["node_path"]?.stringValue,
                      let property = args["property"]?.stringValue,
                      let value = args["value"]?.stringValue
                else {
                    throw MCPError.invalidParams("Missing parameter")
                }
                switch self.provider.updateNodeProperty(nodePath: nodePath, property: property, value: value) {
                case .success(let success):
                    return .init(content: [.text("Updated property '\(property)' of node '\(nodePath)' to '\(self.jsonString(value))'")])
                case .failure(let failure):
                    return .init(failure)
                }
            case "get_node_properties":
                guard let args = params.arguments,
                      let nodePath = args["node_path"]?.stringValue
                else {
                    throw MCPError.invalidParams("Missing parameter")
                }
                switch self.provider.getNodeProperties(nodePath: nodePath) {
                case .success(let success):
                    let result = success.map { "\($0.key): \(self.jsonString($0.value))"}.joined(separator: "\n")
                    return .init(content: [.text("Properties of node at '\(nodePath)': \n\n\(result)")])
                case .failure(let failure):
                    return .init(failure)
                }
            case "list_nodes":
                guard let args = params.arguments,
                      let parentPath = args["parent_path"]?.stringValue
                else {
                    self.logger.error("value is: \(params.arguments?["parent_path"].self ?? "bar")")
                    throw MCPError.invalidParams("Missing parameter")
                }
                switch self.provider.listNodes(nodePath: parentPath) {
                case .success(let success):
                    if success.isEmpty {
                        return .init(content: [.text("The node at '\(parentPath)' does not have any children nodes.")])
                    }
                    let result = success.map { v in "\(v.name) (\(v.type) - \(v.path)" }.joined(separator: "\n")
                    return .init(content: [.text("Children nodes of node at '\(parentPath)': \n\n\(result)")])
                case .failure(let failure):
                    return .init(failure)
                }
            default:
                return .init(content: [.text("Unknown tool")], isError: true)
            }
        }

        // Register a resource list handler
        await server.withMethodHandler(ListResources.self) { params in
            let resources = [
                Resource(
                    name: "XXKnowledge Base Articles",
                    uri: "resource://knowledge-base/articles",
                    description: "Collection of support articles and documentation"
                ),
                Resource(
                    name: "System Status",
                    uri: "resource://system/status",
                    description: "Current system operational status"
                )
            ]
            return .init(resources: resources, nextCursor: nil)
        }

        // Register a resource read handler
        await server.withMethodHandler(ReadResource.self) { params in
            switch params.uri {
            case "resource://knowledge-base/articles":
                return .init(contents: [Resource.Content.text("# Knowledge Base\n\nThis is the content of the knowledge base...", uri: params.uri)])

            case "resource://system/status":
                //let status = "h"getCurrentSystemStatus() // Your implementation
                let statusJson = """
                    {
                        "status": "\("healthy")",
                        "components": {
                            "database": "\("todo-db")",
                            "api": "\("todo-api-v2")",
                            "model": "\("todo-model-v3")"
                        },
                        "lastUpdated": "\("2025-01-01")"
                    }
                    """
                return .init(contents: [Resource.Content.text(statusJson, uri: params.uri, mimeType: "application/json")])

            default:
                throw MCPError.invalidParams("Unknown resource URI: \(params.uri)")
            }
        }

        // Register a resource subscribe handler
    }
}

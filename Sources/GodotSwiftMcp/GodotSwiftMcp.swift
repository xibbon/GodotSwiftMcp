import MCP
import Logging
import JSONSchema
import Foundation

func jsonString(_ value: String) -> String {
    value
}

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
        
        try await registerHandlers()
        await server.waitUntilCompleted()
    }
    
    var sceneTools: [GodotTool] = [
        GodotTool(
            name: "create_node",
            description: "Creates a new node in the current Godot scene",
            inputSchema: .object(
                properties: [
                    "parent_path": .string(description: "Path to the parent node where the new node will be created (e.g. '/root\', '/root/MainScene')"),
                    "node_type": .string(description: "Type of node to create (e.g. 'Node2D', 'Sprite2D', 'Label')"),
                    "node_name": .string(description: "Name of the new node")
                ],
                required: ["parent_path", "node_type", "node_name"]),
            annotations: .init(title: "Creates a new node in the current Godot scene", readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true)
        ) { args, provider in
            guard let parentPath = args["parent_path"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'parent_path'")}
            guard let nodeType = args["node_type"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'node_type'") }
            guard let nodeName = args["node_name"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'node_name'") }
            
            let newPath = try provider.createNode(parentPath: parentPath, nodeType: nodeType, nodeName: nodeName)
            return "Created \(nodeType) named \(nodeName) at \(newPath)"
        },
        GodotTool(
            name: "delete_node",
            description: "Deletes a node in the current Godot scene",
            inputSchema: .object(
                properties: [
                    "node_path": .string(description: "Path to the node to delete (e.g. '/root/MainScene/Player')")
                ],
                required: ["node_path"]),
            annotations: .init(title: "Deltes a node in the current Godot scene", readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true)
        ) { args, provider in
            guard let nodePath = args["node_path"]?.stringValue
            else {
                throw MCPError.invalidParams("Missing parameter 'node_path'")
            }
            let path = try provider.deleteNode(nodePath: nodePath)
            return "Deleted node at '\(path)'"
        },
        
        GodotTool(
            name: "update_node_property",
            description: "Updates a property of a node in the Godot scene tree",
            inputSchema: .object(
                properties: [
                    "node_path": .string(description: "Path of the node to update (e.g. '/root\', '/root/MainScene/Player')"),
                    "property": .string(description: "Name of the property to update (e.g. 'position', 'scale', 'text', 'modulate)"),
                    "value": .string(description: "New value for the property")
                    ],
                required: ["node_path", "property", "value"]),
            annotations: .init(title: "Updates a propert of a node in the Godot scene tree", readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true)
        ) { args, provider in
            guard let nodePath = args["node_path"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'node_path") }
            guard let property = args["property"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'property'") }
            guard let value = args["value"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'value'") }

            let result = try provider.updateNodeProperty(nodePath: nodePath, property: property, value: value)
                
            // TODO: this is returning a string, but other code I see does not do that
            return "Updated property '\(property)' of node '\(nodePath)' to '\(jsonString(result))"
        },
        
        GodotTool(
            name: "get_node_properties",
            description: "Get all properties of a node in the Godot scene tree",
            inputSchema: .object(
                properties: [
                    "node_path": .string(description: "Path to the node to inspect (e.g. '/root/MainScene/Player')")],
                required: ["node_path"]),
            annotations: .init(title: "Get all properties of a node in the Godot scene tree", readOnlyHint: true, destructiveHint: false, idempotentHint:true, openWorldHint: true)
        ) { args, provider in
            guard let nodePath = args["node_path"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'node_path'")
            }
            let success = try provider.getNodeProperties(nodePath: nodePath)
            let result = success.map { "\($0.key): \(jsonString($0.value))"}.joined(separator: "\n")
            return "Properties of node at '\(nodePath)': \n\n\(result)"
        },
        
        GodotTool(
            name: "list_nodes",
            description: "Lists all child nodes under a parent node in the Godot scene tree",
            inputSchema: .object(
                properties: [
                    "parent_path": .string(description: "Path to the parent node (e.g. '/root', '/root/MainScene')")
                ],
                required: ["parent_path"]
            ),
            annotations: .init(title: "Lists all child nodes under a parent node in the Godot scene tree", readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: true)
        ) { args, provider in
            guard let parentPath = args["parent_path"]?.stringValue
            else {
                throw MCPError.invalidParams("Missing parameter 'parent_path'")
            }
            let success = try provider.listNodes(nodePath: parentPath)
            if success.isEmpty {
                return "The node at '\(parentPath)' does not have any children nodes."
            }
            let result = success.map { v in "\(v.name) (\(v.type) - \(v.path)" }.joined(separator: "\n")
            return ("Children nodes of node at '\(parentPath)': \n\n\(result)")
        }
    ]
    
    func registerHandlers() async throws {
        let tools = sceneTools
        
        // Register a tool list handler
        await server.withMethodHandler(ListTools.self) { _ in
            return .init(tools: try tools.map { try $0.toMcpTool() })
        }

        var buildImplementations: [String:  @Sendable ([String: Value], GodotProvider) async throws -> Value] = [:]
        for tool in tools {
            buildImplementations[tool.name] = tool.implementation
        }
        let implementations = buildImplementations
        
        // Register a tool call handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self else {
                return CallTool.Result(
                    content: [.text("Server unavailable")],
                    isError: true
                )
            }
            self.logger.notice("Tool call for \(params.name)")
            guard let implementation = implementations[params.name] else {
                return .init(content: [.text("Unknown tool")], isError: true)
            }
            do {
                let value = try await implementation(params.arguments ?? [:], provider)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
                let data = try encoder.encode(value)
                if let text = String(data: data, encoding: .utf8) {
                    return .init(content: [.text(text)], isError: false)
                } else {
                    return .init(content: [.text("Could not encode result")], isError: true)
                }
            } catch let godotError as GodotError {
                return .init(content: [.text(godotError.errorDescription ?? "Godot Provider Error")], isError: true)
            } catch {
                return .init(content: [.text(error.localizedDescription)], isError: true)
            }
        }

        // Register a resource list handler
        await server.withMethodHandler(ListResources.self) { params in
            let resources = [
                Resource(
                    name: "Godot Scene List",
                    uri: "resource://project/scene-list",
                    mimeType: "application/json"),
                Resource(
                    name: "Godot Script List",
                    uri: "resource://project/scripts",
                    mimeType: "application/json"),
                Resource(
                    name: "Godot Project Structure",
                    uri: "resource://project/structure",
                    mimeType: "application/json"),
                Resource(
                    name: "Godot Project Settings",
                    uri: "resource://project/settings",
                    mimeType: "application/json"),
                Resource(
                    name: "Godot Editor State",
                    uri: "resource://editor/state",
                    mimeType: "application/json"),
                Resource(
                    name: "Godot Selected Node",
                    uri: "resource://editor/selected_node",
                    mimeType: "application/json"),
                Resource(
                    name: "Current Script in Editor",
                    uri: "resource://editor_current_script",
                    mimeType: "text/plain"),
                Resource(
                    name: "Godot Scene Structure",
                    uri: "resource://project/scene/current",
                    mimeType: "application/json"),
                
                // These are sus
                Resource(
                    name: "Godot Script Content",
                    uri: "resource://project",
                    mimeType: "text/plain"
                ),
                Resource(
                    name: "Godot Script Metadata",
                    uri: "resource://script/metadata",
                    mimeType: "application/json")
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

extension Tool {
    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema? = nil,
        annotations: Annotations = nil
    ) throws {
        try self.init(name: name, description: description, inputSchema: Value(inputSchema), annotations: annotations)
    }
}

/// From iMCP's Tool implementation
struct GodotTool {
    var name: String
    var description: String
    var inputSchema: JSONSchema? = nil
    var annotations: Tool.Annotations
    let implementation: @Sendable ([String: Value], GodotProvider) async throws -> Value

    public init<T: Encodable>(
        name: String,
        description: String,
        inputSchema: JSONSchema? = nil,
        annotations: Tool.Annotations,
        implementation: @Sendable @escaping ([String: Value], _ provider: GodotProvider) async throws -> T
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.annotations = annotations
        self.implementation = { (input: [String: Value], provider: GodotProvider) in
            let result = try await implementation(input, provider)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

            let data = try encoder.encode(result)

            let decoder = JSONDecoder()
            return try decoder.decode(Value.self, from: data)
        }
    }
    
    func toMcpTool() throws -> Tool {
        Tool(name: name, description: description, inputSchema: try Value(inputSchema), annotations: annotations)
    }
}

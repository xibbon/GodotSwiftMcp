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
    
    let sceneTools: [GodotTool] = [
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
            annotations: .init(title: "Creates a new node in the current Godot scene", readOnlyHint: false, destructiveHint: true, idempotentHint: false)
        ) { args, provider in
            guard let parentPath = args["parent_path"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'parent_path'")}
            guard let nodeType = args["node_type"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'node_type'") }
            guard let nodeName = args["node_name"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'node_name'") }
            
            let newPath = try await provider.createNode(parentPath: parentPath, nodeType: nodeType, nodeName: nodeName)
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
            annotations: .init(title: "Deltes a node in the current Godot scene", readOnlyHint: false, destructiveHint: true, idempotentHint: false)
        ) { args, provider in
            guard let nodePath = args["node_path"]?.stringValue
            else {
                throw MCPError.invalidParams("Missing parameter 'node_path'")
            }
            let path = try await provider.deleteNode(nodePath: nodePath)
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
            annotations: .init(title: "Updates a propert of a node in the Godot scene tree", readOnlyHint: false, destructiveHint: true, idempotentHint: false)
        ) { args, provider in
            guard let nodePath = args["node_path"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'node_path") }
            guard let property = args["property"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'property'") }
            guard let value = args["value"]?.stringValue else { throw MCPError.invalidParams("Missing parameter 'value'") }

            let result = try await provider.updateNodeProperty(nodePath: nodePath, property: property, value: value)
                
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
            annotations: .init(title: "Get all properties of a node in the Godot scene tree", readOnlyHint: true, destructiveHint: false, idempotentHint:true)
        ) { args, provider in
            guard let nodePath = args["node_path"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'node_path'")
            }
            let success = try await provider.getNodeProperties(nodePath: nodePath)
            return "Properties of node at '\(nodePath)': \n\n\(success)"
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
            annotations: .init(title: "Lists all child nodes under a parent node in the Godot scene tree", readOnlyHint: true, destructiveHint: false, idempotentHint: false)
        ) { args, provider in
            guard let parentPath = args["parent_path"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'parent_path'")
            }
            let success = try await provider.listNodes(nodePath: parentPath)
            if success.isEmpty {
                return "The node at '\(parentPath)' does not have any children nodes."
            }
            let result = success.map { v in "\(v.name) (\(v.type) - \(v.path)" }.joined(separator: "\n")
            return ("Children nodes of node at '\(parentPath)': \n\n\(result)")
        }
    ]
    
    let scriptTools: [GodotTool] = [
        GodotTool(
            name: "create_script",
            description: "Create a new GDScript file in the project",
            inputSchema: .object(
                properties: [
                    "script_path": .string(description: "Path where the script will be saved (e.g. 'res://scripts/player.gd')"),
                    "content": .string(description: "Content of the scritpt"),
                    "node_path": .string(description: "Optional path to a node to attach the script to.")
                ],
                required: ["script_path", "content"],
            ),
            annotations: .init(title: "Create a new GDScript file in the project", readOnlyHint: false, destructiveHint: false, idempotentHint: true)
        ) { args, provider in
            guard let scriptPath = args["script_path"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'script_path'")
            }
            guard let content = args["content"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'content'")
            }
            let attachMessage: String
            let nodePath = args["node_path"]?.stringValue
            if let nodePath {
                attachMessage = " and attached to node at '\(nodePath)"
            } else {
                attachMessage = ""
            }
            try await await provider.createScript(scriptPath: scriptPath, content: content, nodePath: nodePath)
            return "Created script at '\(scriptPath)'\(attachMessage)."
        },
        GodotTool(
            name: "edit_script",
            description: "Edit an existing GDScript File",
            inputSchema: .object(
                properties: [
                    "script_path": .string(title: "Path t the scrip file to edit (e.g. 'res://scripts/player.gd')"),
                    "content": .string(description: "New content of the script")],
                required: ["script_path", "content"]),
            annotations: .init(title: "Edit an existing GDScript file", readOnlyHint: false, destructiveHint: false, idempotentHint: true)
        ) { args, provider in
            guard let scriptPath = args["script_path"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'script_path'")
            }
            guard let content = args["content"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'content'")
            }
            try await provider.editScript(scriptPath: scriptPath, content: content)
            return "Updated script at '\(scriptPath)'"
        },
        
        GodotTool(
            name: "get_script",
            description: "Get the contents of a GDScript file via the script_path or node_path",
            inputSchema: .object(
                properties: [
                    "script_path": .string(description: "Path where the script resides (e.g. 'res://scripts/player.gd')"),
                    "node_path": .string(description: "Path to a node with the script attached")
                ],
            ),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: false)
        ) { args, provider in
            let scriptPath = args["script_path"]?.stringValue
            let nodePath = args["node_path"]?.stringValue
            
            if scriptPath == nil && nodePath == nil {
                throw MCPError.invalidParams("Missing parameter 'script_path' or 'node_path'")
            }
            let result = try await provider.getScript(scriptPath: scriptPath, nodePath: nodePath)
            return "Script at scriptPath='\(scriptPath ?? "") and nodePath='\(nodePath ?? "")' contains:\n\n```gdscript\n\(result)\n```"
        },
        
        GodotTool(
            name: "create_script_template",
            description: "Generate a GDScript template with common boilerplate",
            inputSchema: .object(
                properties: [
                    "class_name": .string(description: "Optional class name for the script"),
                    "extends_type": .string(description: "Base class that this scripts extends (e.g. 'Node', 'Node2D', 'Control'"),
                    "include_ready": .boolean(description: "Whether to include the _ready() function"),
                    "include_process": .boolean(description: "Whether to include the _process() function"),
                    "include_input": .boolean(description: "Whether to include the _input() function"),
                    "include_physics": .boolean(description: "Whether to include the _physics_function() function"),
                ]
            ),
            annotations: .init(readOnlyHint: false, destructiveHint: true, idempotentHint: false)
        ) { args, provider in
            let className = args["class_name"]?.stringValue
            let extendsType = args["extends_type"]?.stringValue ?? "Node"
            let includeReady = args["include_ready"]?.boolValue ?? false
            let includeProcess = args["include_process"]?.boolValue ?? false
            let includeInput = args["include_input"]?.boolValue ?? false
            let includePhysics = args["include_physics"]?.boolValue ?? false
            
            // Generate locally before calling godot
            var template = ""
            if let className {
                template += "class_name \(className)\n"
            }
            template += "extends \(extendsType)\n\n"
            
            if includeReady {
                template += "func _ready():\n\tpass\n\n"
            }
            if includeProcess {
                template += "func _process(delta):\n\tpass\n\n"
            }
            if includePhysics {
                template += "func _physics_process(delta):\n\tpass\n\n"
            }
            if includeInput {
                template += "func _input(event):\n\tpass\n\n"
            }
            return "Generated GDScript template:\n\n```gdscript\n\(template)\n```"
        }
    ]
    
    let assetTools: [GodotTool] = [
        GodotTool(
            name: "list_assets_by_type",
            description: "Lists all assets of a specific type in the project",
            inputSchema: .object(
                properties: [
                    "type": .string(description: "Type of assets to list (e.g. 'images', 'audio', 'models', 'all'"),
                    "limit": .integer(description: "If you specify the limit, only the first `limit` assets will be returned, otherwise all the matching assets are returned")
                ],
                required: ["type"]),
            annotations: .init(readOnlyHint: true)
        ) { args, provider in
            guard let type = args["type"]?.stringValue else {
                throw MCPError.invalidParams("Missing 'type' argument")
            }
            let limit = args["limit"]?.intValue ?? Int.max
            
            let list = try await provider.listAssets(type: type)
            if list.isEmpty {
                return "No assets of type \(type) found"
            } else {
                var result = ""
                let items = min(list.count, limit)
                for x in 0..<items {
                    result += "- \(list[x])\n"
                }
                return "Found \(items) of type '\(type)' in the project:\n\n\(result)"
            }
        },
        GodotTool(
            name: "list_project_files",
            description: "List files in the project matching specified extensions",
            inputSchema: .object(
                properties: [
                    "extensions": .array(description: "Optional list of extension to filter by (e.g. '*.tscn', '*.gd')", items: .string()),
                    "limit": .integer(description: "If you specify the limit, only the first `limit` files will be returned, otherwise all the matching files are returned")
                ]
            ),
            annotations: .init(readOnlyHint: true)
        ) { args, provider in
            
            let extensions = args["extensions"]?.arrayValue?.compactMap { $0.stringValue } ?? []
            let limit = args["limit"]?.intValue ?? Int.max
         
            let fileList = try await provider.listProjectFiles(extensions: extensions)
            if fileList.isEmpty {
                if extensions.isEmpty {
                    return "No files found"
                } else {
                    return "No files found with those extensions "
                }
            } else {
                var result = ""
                let items = min(fileList.count, limit)
                for x in 0..<items {
                    result += "- \(fileList[x])\n"
                }
                return "Found \(items) files in the project:\n\n\(result)"
            }
        }
    ]
            
    let editorTools: [GodotTool] = [
        GodotTool(
            name: "execute_editor_script",
            description: "Executes arbitrary GDScript code in the Godot Editor",
            inputSchema: .object(
                properties: [
                    "code": .string(description: "GDScript code to execute in the editor context")
                ]),
            annotations: .init(destructiveHint: true)
        ) { args, provider in
            guard let code = args["code"]?.stringValue else {
                throw MCPError.invalidParams("Missing parameter 'code'")
            }
            let result = try await provider.executeEditorScript(code: code)
            return "Script result: \(result.joined(separator: "\n"))"
        }
    ]
    
    let enhancedTools: [GodotTool] = [
        GodotTool(
            name: "get_full_scene_tree",
            description: "Get the compelte scene tree hierarhchy of the current scene",
            inputSchema: .object(
                properties: [:]),
            annotations: .init(readOnlyHint: true)
        ) { args, provider in
            let scene = try await provider.getSceneTree()
            
            func formatNode(node: GodotProviderNode, indent: String = "") -> String {
                var output = "\(indent)\(node.name) (\(node.type))"
                if let children = node.children, children.count > 0 {
                    output += "\n"
                    output += children.map { formatNode(node: $0, indent: indent + "  ") }.joined(separator: "\n")
                }
                return output
            }
            
            return formatNode(node: scene)
        },
        
        GodotTool(
            name: "get_debug_output",
            description: "Get the debug output from the Godot Editor",
            inputSchema: .object(),
            annotations: .init(readOnlyHint: true)
        ) { args, provider in
            let output = try await provider.getDebugOutput()
            
            return "Debug Output:\n\(output)"
        },
        
        GodotTool(
            name: "get_current_scene_structure",
            description: "Get about the current scene, path root and name",
            inputSchema: .object(),
            annotations: .init(readOnlyHint: true)
        ) { args, provider in
            
            if let info = try await provider.getCurrentSceneInfo() {
                return "The current scene is stored at: \(info.filePath)\nRoot Node: \(info.rootNode.name) (\(info.rootNode.type))"
            } else {
                return "There is no current scene"
            }
        },
        
        GodotTool(
            name: "update_2dnode_transform",
            description: "Update position, rotation, or scale of a Node",
            inputSchema: .object(
                properties: [
                    "node_path": .string(description: "Path to the node to update (e.g. '/root/MainScene/Player')"),
                    "position": .array(description: "New position as (x, y)", items: .number(), minItems: 2, maxItems: 2),
                    "rotation": .number(description: "New rotation in radians"),
                    "scale": .array(description: "New scale as (x, y)", items: .number(), minItems: 2, maxItems: 2),
                ]
            ),
            annotations: .init(readOnlyHint: false)
        ) { args, provider in
            guard let nodePath = args["node_path"]?.stringValue else {
                throw MCPError.invalidParams("Missing 'node_path' argument")
            }
            var position: (Double, Double)? = nil
            if case let .array(argsPosition) = args["position"] {
                if argsPosition.count != 2 {
                    throw MCPError.invalidParams("You must specified both x and y coordinates")
                }
                guard let positionX = argsPosition[0].doubleValue, let positionY = argsPosition[1].doubleValue else {
                    throw MCPError.invalidParams("Position argument must be a valid array of two doubles")
                }
                position = (positionX, positionY)
            }
            let argsRotation = args["rotation"]?.doubleValue
            var scale: (Double, Double)? = nil
            if case let .array(argsScale) = args["scale"] {
                if argsScale.count != 2 {
                    throw MCPError.invalidParams("You must specify both the scale in the x and y coorindates")
                }
                guard let scaleX = argsScale[0].doubleValue, let scaleY = argsScale[1].doubleValue else {
                    throw MCPError.invalidParams("Scale argument must be a valid array of two doubles")
                }
                scale = (scaleX, scaleY)
            }
            try await provider.update2DTransform(nodePath: nodePath, position: position, rotation: argsRotation, scale: scale)
            return "Updated transform for '\(nodePath)'"
        }
    ]
    
    func registerTools() async throws {
        let tools = sceneTools + scriptTools + assetTools + editorTools + enhancedTools
        
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
            } catch let godotError as GodotMcpError {
                return .init(content: [.text(godotError.errorDescription ?? "Godot Provider Error")], isError: true)
            } catch {
                return .init(content: [.text(error.localizedDescription)], isError: true)
            }
        }
    }
    
    let resources = [
        Resource(
            name: "Godot Scene List",
            uri: "godot/scenes",
            mimeType: "application/json"),
        Resource(
            name: "Godot Script List",
            uri: "godot/scripts",
            mimeType: "application/json"),
//        Resource(
//            name: "Godot Project Structure",
//            uri: "godot/project/structure",
//            mimeType: "application/json"),
//        Resource(
//            name: "Godot Project Settings",
//            uri: "godot/project/settings",
//            mimeType: "application/json"),
        //
        // This is doing a server-side sorting of files by kind, wonder if it is worth having this
        // or if we should just filter here
//        Resource(
//            name: "Godot Project Resources",
//            uri: "godot/project/resources",
//            mimeType: "application/json"),
//        Resource(
//            name: "Godot Editor State",
//            uri: "godot/editor/state",
//            mimeType: "application/json"),
        Resource(
            name: "Godot Selected Node",
            uri: "godot/editor/selected_node",
            mimeType: "application/json"),
//        Resource(
//            name: "Current Script in Editor",
//            uri: "godot/editor/current_script",
//            mimeType: "text/plain"),
        Resource(
            name: "Godot Scene Structure",
            uri: "godot/scene/current",
            mimeType: "application/json"),
//        
//        Resource(
//            name: "Script Content",
//            uri: "godot/script",
//            mimeType: "text/plain"
//        ),
//        Resource(
//            name: "Godot Script Metadata",
//            uri: "godot/script/metadata",
//            mimeType: "application/json"),
        Resource(
            name: "Full Scene Tree",
            uri: "godot/scene/tree",
            mimeType: "application/json"),
        Resource(
            name: "Godot Debug Output",
            uri: "godot/debug/log",
            mimeType: "text/plain"),
        Resource(
            name: "Asset List",
            uri: "godot/assets",
            mimeType: "application/json")
    ]
    
    let templates: [Resource.Template] = [
//        Resource.Template(uriTemplate: <#T##String#>, name: <#T##String#>)
    ]
    
    func registerResources() async {
        // Register a resource list handler
        await server.withMethodHandler(ListResources.self) { params in
            return .init(resources: self.resources, nextCursor: nil)
        }
        await server.withMethodHandler(ListResourceTemplates.self) { params in
            return .init(templates: self.templates)
        }

        // Register a resource read handler
        await server.withMethodHandler(ReadResource.self) { params in
            // Produces a return value from a string that is already JSon encoded
            func stringJson(_ jsonText: String) -> ReadResource.Result {
                .init(contents: [.text(jsonText, uri: params.uri, mimeType: "application/json")])
            }
            func stringJson(_ jsonData: Data) -> ReadResource.Result {
                return stringJson(String(data: jsonData, encoding: .utf8) ??  "")
            }
            
            switch params.uri {
            case "godot/scenes":
                let files = try await self.provider.listProjectFiles(extensions: [".tscn", ".scn"])
                let encoder = JSONEncoder()
                return stringJson(try encoder.encode(files))
            case "godot/scene/current":
                guard let scene = try await self.provider.getCurrentSceneInfo() else {
                    throw MCPError.serverError(code: -32002, message: "There is no current scene open")
                }
                let e = JSONEncoder()
                return stringJson(try e.encode(scene))
            case "godot/scripts":
                let files = try await self.provider.listProjectFiles(extensions: [".gd"])
                let encoder = JSONEncoder()
                return stringJson(try encoder.encode(files))
            case "godot/assets":
                let files = try await self.provider.listProjectFiles(extensions: [])
                let encoder = JSONEncoder()
                return stringJson(try encoder.encode(files))
            case "godot/scene/tree":
                let tree = try await self.provider.getSceneTree()
                let encoder = JSONEncoder()
                return stringJson(try encoder.encode(tree))
                case "godot/debug/log":
                let output = try await self.provider.getDebugOutput()
                return .init(contents: [.text(output, uri: params.uri, mimeType: "text/plain")])
            case "godot/editor/selected_node":
                let node = try await self.provider.getSelectedNode()
                let encoder = JSONEncoder()
                return stringJson(try encoder.encode(node))
            default:
                throw MCPError.invalidParams("Unknown resource URI: \(params.uri)")
            }
        }
    }
    
    func registerHandlers() async throws {
        try await registerTools()
        await registerResources()

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
        inputSchema: JSONSchema?,
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

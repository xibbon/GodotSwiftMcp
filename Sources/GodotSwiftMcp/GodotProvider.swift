//
//  GodotProtocols.swift
//  GodotSwiftMcp
//
//  Created by Miguel de Icaza on 5/24/25.
//
import Foundation
import MCP

public enum GodotMcpError: LocalizedError {
    case connectionTimeout
    case invalidNodeType(String)
    case missingSceneRoot
    case nodeNotFound(String)
    case nodeHasNoScript(String)
    case missingParent(String)
    case cannotInstantiateType(String)
    case cannotInstantiateScriptType(String)
    case cannotInstantiatePathBasedType(String, String)
    case errorCreatingType(String)
    case emptyNodePath
    case cannotDeleteRootNode
    case nodeHasNoParent(String)
    case emptyProperty
    case propertyDoesNotExist(String, String)
    case unimplemented
    case responseError(String)
    case remoteError(String)
    case failedToParse(String)
    case failedToExecute(String)
    case godotError(LocalizedError)
    case ioError(String)
    case notimplemented
    case failedToLoadScript
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .unimplemented:
            "The functionality is not implemented in this Godot"
        case .invalidNodeType(let type):
            "Invalid node type: \(type)"
        case .nodeHasNoScript(let nodePath):
            "The node at '\(nodePath)' does not have an attached script"
        case .missingSceneRoot:
            "No scene is currently being edited"
        case .nodeNotFound(let path):
            "No node found at '\(path)'"
        case .missingParent(let path):
            "Parent node '\(path)' not found"
        case .cannotInstantiateType(let type):
            "Cannot instantiate node of type '\(type)'"
        case .errorCreatingType(let type):
            "There was an error instantiating the type '\(type)'"
        case .emptyNodePath:
            "Empty node path, this is not allowed"
        case .cannotDeleteRootNode:
            "It is not possible to delete the root scene node"
        case .nodeHasNoParent(let path):
            "The node at '\(path)' does not have a a parent"
        case .emptyProperty:
            "The property was empty"
        case .propertyDoesNotExist(let nodePath, let propertyName):
            "The node at '\(nodePath)' does not have a property named '\(propertyName)'"
        case .connectionTimeout:
            "It was not possible to connect on time to Godot"
        case .responseError(let s):
            "Received a response that did not know how to interpret: \(s)"
        case .remoteError(let message):
            "Godot replied: \(message)"
        case .failedToParse(let expr):
            "Failed to parse the expression \(expr) as sa Godot type"
        case .failedToExecute(let expr):
            "Failed to execute the expression \(expr) while parsing the value"
        case .notimplemented:
            "This functionality has not been implemented"
        case .ioError(let message):
            message
        case .godotError(let error):
            "Godot error: \(String(describing: error.errorDescription))"
        case .failedToLoadScript:
            "Failed to load the script"
        case .cannotInstantiateScriptType(let type):
            "It is not possible to instantiate the script type \(type)"
        case .cannotInstantiatePathBasedType(let type, let reason):
            "It was not possible to instantiate a path-based node type: \(type) (\(reason))"
        }
    }
    
    /// A localized message describing the reason for the failure.
    public var failureReason: String? { errorDescription }

    /// A localized message describing how one might recover from the failure.
    public var recoverySuggestion: String? { nil }
}

public final class GodotProviderNode: Sendable, Codable {
    public let name: String
    public let type: String
    public let children: [GodotProviderNode]?
    public let path: String
    public let properties: Properties
    public let scriptPath: String?
    public let scriptClassName: String?

    public struct Properties: Sendable, Codable {
        let scale: String
        let rotation: String
        let visible: Bool
        let position: String
        
        public init(_ dictionary: [String: Any]) {
            scale = dictionary["scale"] as? String ?? ""
            rotation = dictionary["rotation"] as? String ?? ""
            visible = dictionary["visible"] as? Bool ?? true
            position = dictionary["position"] as? String ?? ""
        }
    }
    public init(name: String, type: String, path: String, scriptPath: String?, scriptClassName: String?, properties: Properties, children: [GodotProviderNode]?) {
        self.name = name
        self.type = type
        self.children = children
        self.path = path
        self.scriptPath = scriptPath
        self.scriptClassName = scriptClassName
        self.properties = properties
    }
}

public final class GodotSceneInformation: Sendable, Codable {
    public let filePath: String
    public let rootNode: GodotProviderNode
    
    public init(filePath: String, rootNode: GodotProviderNode) {
        self.filePath = filePath
        self.rootNode = rootNode
    }
}

public protocol GodotProvider {
    /// Saves the current scene to the specified fileName if set, or to the existing file name if not set.
    /// Throws an error if the scene does not have a file name set.
    /// - Returns: the file where the scene was saved
    func saveScene(fileName: String?) async throws -> String
    /// Creates a new scene at the location specified by filenName, and optionally creates a root node of the type provided
    /// - Parameters:
    ///  - fileName: the file path where the scene will be created
    ///  - rootType: optional type for the root scene (2d, 3d, ui or empty)
    ///  - inheriting: if set, this is a path to an existing script
    func newScene(fileName: String, rootType: String?, inheriting: String?) async throws
    
    /// Result is the node path of the resulting node
    func createNode(parentPath: String, nodeType: String, nodeName: String) async throws -> String
    func deleteNode(nodePath: String) async throws -> String
    func updateNodeProperty(nodePath: String, property: String, value: String) async throws -> String
    func getNodeProperties(nodePath: String) async throws -> [String: String]
    func listNodes(nodePath: String) async throws -> [(name: String, type: String, path: String)]
    
    func createScript(scriptPath: String, content: String, nodePath: String?) async throws
    func editScript(scriptPath: String, content: String) async throws
    
    
    // The resolved script path in human readable form, suitable to be sent back to the LLM, and the content
    func getScript(scriptPath: String?, nodePath: String?) async throws -> (String, String)
    
    func listAssets(type: String) async throws -> [String]
    func listProjectFiles(extensions: [String]) async throws -> [String]
    
    func executeEditorScript(code: String) async throws -> [String]
    
    func getSceneTree() async throws -> GodotProviderNode
    
    func getDebugOutput(limit: Int) async throws -> String
    
    func getCurrentSceneInfo() async throws -> GodotSceneInformation?
    
    func update2DTransform(nodePath: String, position: (Double, Double)?, rotation: Double?, scale: (Double, Double)?) async throws
    
    /// This return will not include children
    func getSelectedNode() async throws -> GodotProviderNode?
}

extension CallTool.Result {
    public init(_ error: GodotMcpError) {
        self.init(content: [.text(error.errorDescription ?? "Unknown Error")], isError: true)
    }
}

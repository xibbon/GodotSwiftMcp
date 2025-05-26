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
    case missingParent(String)
    case cannotInstantiateType(String)
    case errorCreatingType(String)
    case emptyNodePath
    case cannotDeleteRootNode
    case nodeHasNoParent(String)
    case emptyProperty
    case propertyDoesNotExist(String, String)
    case unimplemented
    case responseError(String)
    case remoteError(String)
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case .unimplemented:
            "The functionality is not implemented in this Godot"
        case .invalidNodeType(let type):
            "Invalid node type: \(type)"
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
        }
    }
    
    /// A localized message describing the reason for the failure.
    public var failureReason: String? { errorDescription }

    /// A localized message describing how one might recover from the failure.
    public var recoverySuggestion: String? { nil }
}

public struct GodotProviderNode {
    public let name: String
    public let type: String
    public let children: [GodotProviderNode]?
}

public protocol GodotProvider {
    /// Result is the node path of the resulting node
    func createNode(parentPath: String, nodeType: String, nodeName: String) async throws -> String
    func deleteNode(nodePath: String) async throws -> String
    func updateNodeProperty(nodePath: String, property: String, value: String) async throws -> String
    func getNodeProperties(nodePath: String) async throws -> [String: String]
    func listNodes(nodePath: String) async throws -> [(name: String, type: String, path: String)]
    
    func createScript(scriptPath: String, content: String, nodePath: String?) async throws
    func editScript(scriptPath: String, content: String) async throws
    func getScript(scriptPath: String?, nodePath: String?) async throws -> String
    
    func listAssets(type: String) async throws -> [String]
    func listProjectFiles(extensions: [String]) async throws -> [String]
    
    func executeEditorScript(code: String) async throws -> [String]
    
    func getSceneTree() async throws -> GodotProviderNode
    
    func getDebugOutput() async throws -> String
    
    func getCurrentSceneInfo() async throws -> (path: String?, name: String, type: String)?
    
    func update2DTransform(nodePath: String, position: (Double, Double)?, rotation: Double?, scale: (Double, Double)?) async throws
    
    // Resources
    func getScenes() async throws -> String 
}

extension CallTool.Result {
    public init(_ error: GodotMcpError) {
        self.init(content: [.text(error.errorDescription ?? "Unknown Error")], isError: true)
    }
}

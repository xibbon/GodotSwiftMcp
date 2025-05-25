//
//  GodotProtocols.swift
//  GodotSwiftMcp
//
//  Created by Miguel de Icaza on 5/24/25.
//
import Foundation
import MCP

public enum GodotError: LocalizedError {
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
    
    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
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
        }
    }
    
    /// A localized message describing the reason for the failure.
    public var failureReason: String? { errorDescription }

    /// A localized message describing how one might recover from the failure.
    public var recoverySuggestion: String? { nil }
}

public protocol GodotProvider {
    /// Result is the node path of the resulting node
    func createNode(parentPath: String, nodeType: String, nodeName: String) -> Result<String, GodotError>
    func deleteNode(nodePath: String) -> Result<String, GodotError>
    func updateNodeProperty(nodePath: String, property: String, value: String) -> Result<String, GodotError>
    func getNodeProperties(nodePath: String) -> Result<[String: String], GodotError>
    func listNodes(nodePath: String) -> Result<[(name: String, type: String, path: String)], GodotError>
}

extension CallTool.Result {
    public init(_ error: GodotError) {
        self.init(content: [.text(error.errorDescription ?? "Unknown Error")], isError: true)
    }
}

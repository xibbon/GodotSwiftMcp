//
//  GodotSocket.swift
//  GodotSwiftMcp
//
//  Created by Miguel de Icaza on 5/24/25.
//

public class GodotLocalSocketProvider: GodotProvider {
    public init() {
        
    }
    
    public func createNode(parentPath: String, nodeType: String, nodeName: String) throws -> String {
        throw GodotError.missingSceneRoot
    }
    
    public func deleteNode(nodePath: String) throws -> String {
        throw GodotError.missingSceneRoot
    }
    
    public func updateNodeProperty(nodePath: String, property: String, value: String) throws -> String {
        throw GodotError.missingSceneRoot
    }
    
    public func getNodeProperties(nodePath: String) throws -> [String: String] {
        throw GodotError.missingSceneRoot
    }
    
    public func listNodes(nodePath: String) throws -> [(name: String, type: String, path: String)] {
        throw GodotError.missingSceneRoot
    }
}

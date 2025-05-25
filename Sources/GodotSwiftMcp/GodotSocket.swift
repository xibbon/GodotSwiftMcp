//
//  GodotSocket.swift
//  GodotSwiftMcp
//
//  Created by Miguel de Icaza on 5/24/25.
//

public class GodotLocalSocketProvider: GodotProvider {
    public init() {
        
    }
    
    public func createNode(parentPath: String, nodeType: String, nodeName: String) -> Result<String, GodotError> {
        .failure(.missingSceneRoot)
    }
    
    public func deleteNode(nodePath: String) -> Result<String, GodotError> {
        .failure(.missingSceneRoot)
    }
    
    public func updateNodeProperty(nodePath: String, property: String, value: String) -> Result<String, GodotError> {
        .failure(.missingSceneRoot)
    }
    
    public func getNodeProperties(nodePath: String) -> Result<[String : String], GodotError> {
        .failure(.missingSceneRoot)
    }
    
    public func listNodes(nodePath: String) -> Result<[(name: String, type: String, path: String)], GodotError> {
        .failure(.missingSceneRoot)
    }
}

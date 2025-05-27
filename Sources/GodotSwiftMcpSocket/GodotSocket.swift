//
//  GodotSocket.swift
//  GodotSwiftMcp
//
//  Created by Miguel de Icaza on 5/24/25.
//
import GodotSwiftMcp
import Starscream
import Foundation

public class GodotLocalSocketProvider: GodotProvider, WebSocketDelegate {
    var nextCommand = 0
    var pendingCommands: [String: (Command, CheckedContinuation<[String: Any],any Error>)] = [:]
    var frames: [Data] = []
    var ws: WebSocket?
    var connected: Bool = false
    
    func flushPending() {
        guard let ws else { return }
        if frames.count > 0 {
            let next = frames.removeFirst()
            ws.write(data: next) {
                self.flushPending()
            }
        }
    }
    
    public enum RemoteError: Error {
        case failure(String)
    }
    
    struct ResultError: Decodable {
        let commandId: String
        let message: String
        let status: String
    }
    
    struct TrivialResult: Decodable {
        let commandId: String
        let status: String
    }

    public func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        func p(_ str: String) {
            print ("WebSocket.didReceive: \(str)")
        }
        print("didReceive")
        switch event {
        case .binary(let data):
            p("Got binary data: \(data.count)")
        case .connected(let dict):
            p("Connected \(dict)")
            connected = true
            flushPending()
        case .disconnected(let str, let code):
            p("Disconnected: \(str) code: \(code)")
            ws = nil
        case .text(let text):
            print(text)
            var commandId: String? = nil
            var status: String? = nil

            if let data = text.data(using: .utf8) {
                let decoder = JSONDecoder()
                if let v = try? decoder.decode(TrivialResult.self, from: data) {
                    commandId = v.commandId
                    status = v.status
                }
                
                guard let commandId, let status else {
                    print("Received data that did not contain a commandId: \(text)")
                    return
                }
                
                if let commandTask = pendingCommands[commandId] {
                    do {
                        pendingCommands.removeValue(forKey: commandId)
                        if status == "error" {
                            let result = try decoder.decode(ResultError.self, from: data)
                            commandTask.1.resume(throwing: GodotMcpError.remoteError(result.message))
                            return
                        }
                        let result = try decoder.decode(AnyDecodable.self, from: data)
                        guard let resultValue = (result.value as? [String: Any])?["result"] as? [String: Any] else {
                            commandTask.1.resume(throwing: RemoteError.failure("Missing the result element in the return value"))
                            return
                        }
                        
                        if status == "success" {
                            commandTask.1.resume(returning: resultValue)
                        } else {
                            commandTask.1.resume(throwing: RemoteError.failure(String(describing: resultValue)))
                        }
                    } catch {
                        commandTask.1.resume(throwing: error)
                    }
                } else {
                    print("Had a commandId that is no longer present: \(commandId)")
                }
            } else {
                print("Failure to decode input, which was expected to be a Json frame: \(text)")
            }
        case .pong(let pong):
            p("Pong: \(String(describing: pong))")
        case .ping(let ping):
            p("Ping: \(String(describing: ping))")
        case .error(let err):
            p("Err \(String(describing: err))")
        case .viabilityChanged(let v):
            p("Viability \(v)")


        case .reconnectSuggested(let r):
            p("Reconnect Suggested \(r)")
        case .cancelled:
            p("cancelled")
        case .peerClosed:
            p("peer closed")
        }
    }
    
    let targetUrl: URL
    public init(target: URL) {
        self.targetUrl = target
    }
    
    func connect() async {
        var request = URLRequest(url: targetUrl)
        request.timeoutInterval = 5
        let socket = WebSocket(request: request) //, engine: WSEngine(transport: FoundationTransport()))
        socket.delegate = self
        ws = socket
        socket.connect()
    }
    
    
    struct Command: Encodable {
        let type: String
        let params: [String: Encodable]
        let commandId: String

        enum CodingKeys: String, CodingKey {
            case type
            case params
            case commandId
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(commandId, forKey: .commandId)
            try container.encode(params, forKey: .params)
        }
    }
    
    public func sendCommand(_ type: String, _ args: [String: Encodable]) async throws -> [String: Any] {
        let e = JSONEncoder()
        
        if ws == nil {
            await connect()
        }
        //let cmd = Command(type: type, params: argsString, commandId: "cmd_\(nextCommand)")
        let cmd = Command(type: type, params: args, commandId: "cmd_\(nextCommand)")
        nextCommand += 1
        let v = try e.encode(cmd)
        frames.append(v)
        //print("Sending \(String(data: v, encoding: .utf8)!)")
        let result = try await withCheckedThrowingContinuation { continuation in
            pendingCommands[cmd.commandId] = (cmd, continuation)
            if connected {
                flushPending()
            }
        }
        return result
    }
    
    func mkError(_ dict: [String: Any]) -> GodotMcpError {
        var result = ""
        for (k, v) in dict {
            result += "\(k) = \(String(describing: v))\n"
        }
        return GodotMcpError.responseError(result)
    }
    
    func simpleReturn(_ res: [String: Any], _ key: String) throws -> String {
        guard let v = res[key] as? String else {
            throw mkError(res)
        }
        return v
    }
    
    public func createNode(parentPath: String, nodeType: String, nodeName: String) async throws -> String {
        let res = try await sendCommand("create_node", [
            "parent_path": parentPath,
            "node_type": nodeType,
            "node_name": nodeName
        ])
        return try simpleReturn(res, "node_path")
    }
    
    public func deleteNode(nodePath: String) async throws -> String {
        let res = try await sendCommand("delete_node", ["node_path": nodePath])
        return try simpleReturn(res, "deleted_node_path")
    }
    
    public func updateNodeProperty(nodePath: String, property: String, value: String) async throws -> String {
        let res = try await sendCommand("update_node_property", [
            "node_path": nodePath,
            "property": property,
            "value": value
        ])
        return try simpleReturn(res, "parsed_value")
    }
    
    public func getNodeProperties(nodePath: String) async throws -> [String: String] {
        let res = try await sendCommand("get_node_properties", [
            "node_path": nodePath
        ])
        if let pdict = res["properties"] as? [String: Any] {
            var result: [String: String] = [:]

            print(pdict)
            
            for (key, value) in pdict {
                if let str = value as? String {
                    result[key] = str
                } else if let bool = value as? Bool {
                    result[key] = "\(bool)"
                } else if let int = value as? Int {
                    result[key] = "\(int)"
                } else if let double = value as? Double {
                    result[key] = "\(double)"
                } else {
                    print("Skipping \(value)")
                }
            }
            return result
        }
        throw GodotMcpError.responseError(String(describing: res))
    }
    
    public func listNodes(nodePath: String) async throws -> [(name: String, type: String, path: String)] {
        let res = try await sendCommand("list_nodes", ["node_path": nodePath])
        guard let children = res["children"] as? [Any] else {
            throw GodotMcpError.responseError("Expected a children node")
        }
        var result: [(String, String, String)] = []
        for child in children {
            guard let dict = child as? [String: String] else { continue }
            guard let name = dict["name"] else { continue }
            guard let nodeType = dict["type"] else { continue }
            guard let path = dict["path"] else { continue }
            result.append((name, nodeType, path))
        }
        return result
    }
    
    public func createScript(scriptPath: String, content: String, nodePath: String?) async throws {
        _ = try await sendCommand("create_script", [
            "script_path": scriptPath,
            "content": content,
            "node_path": nodePath ?? ""
        ])
    }
    
    public func editScript(scriptPath: String, content: String) async throws {
        _ = try await sendCommand("edit_script", [
            "script_path": scriptPath,
            "content": content
        ])
    }

    public func getScript(scriptPath: String?, nodePath: String?) async throws -> String {
        let res = try await sendCommand("get_script", [
            "script_path": scriptPath ?? "",
            "node_path": nodePath ?? ""
        ])
        guard let content = res["content"] as? String else {
            throw GodotMcpError.responseError("Did not get a script back")
        }
        return content
    }
    
    public func listAssets(type: String) async throws -> [String] {
        let res = try await sendCommand("list_assets_by_type", [
            "type": type
        ])
        if let files = res["files"] as? [String] {
            return files
        }
        throw GodotMcpError.responseError("Did not get the files back")
    }
    
    public func listProjectFiles(extensions: [String]) async throws -> [String] {
        let res = try await sendCommand("list_project_files", [
            "extensions": extensions
        ])
        if let files = res["files"] as? [String] {
            return files
        }
        throw GodotMcpError.responseError("Did not get the files back")
    }
    
    
    public func executeEditorScript(code: String) async throws -> [String] {
        let res = try await sendCommand("execute_editor_script", ["code": code])
        if let output = res["output"] as? [Any] {
            var result: [String] = []
            for row in output {
                if let s = row as? String {
                    result.append(s)
                }
            }
            return result
        }
        throw GodotMcpError.responseError("Did not get an output back")
    }
    
    public func getSceneTree() async throws -> GodotProviderNode {
        let res = try await sendCommand("get_full_scene_tree", [:])
        
        func buildFrom(_ dict: [String: Any]) -> GodotProviderNode? {
            guard let path = dict["path"] as? String else { return nil }
            //some core properties are also returned
            guard let name = dict["name"] as? String else { return nil }
            guard let type = dict["type"] as? String else { return nil }
            guard let children = dict["children"] as? [[String: Any]] else {
                return nil
            }
            let script = dict["script"] as? String
            let pdict = (dict["properties"] as? [String: Any]) ?? [:]
            let properties = GodotProviderNode.Properties(pdict)
            var childResults: [GodotProviderNode] = []
            for childDict in children {
                if let childNode = buildFrom(childDict) {
                    childResults.append(childNode)
                }
            }
            return GodotProviderNode(name: name, type: type, path: path, script: script, properties: properties, children: childResults)
        }
        if let result = buildFrom(res) {
            return result
        }
        throw GodotMcpError.responseError("Did not get an array with the data")
    }
    
    public func getDebugOutput() async throws -> String {
        let res = try await sendCommand("get_debug_output", [:])
        if let output = res["output"] as? String {
            return output
        }
        return ""
    }
    
    public func getCurrentSceneInfo() async throws -> (path: String?, name: String, type: String)? {
        let res = try await sendCommand("get_current_scene_structure", [:])
        // There is a ton of extra information being returned
        let path = res["path"] as? String
        let name = res["root_node_name"] as! String
        let type = res["root_node_type"] as! String
        return (path, name, type)
    }
    
    public func update2DTransform(nodePath: String, position: (Double, Double)?, rotation: Double?, scale: (Double, Double)?) {
    }
    
    public func getScenes() -> String {
        "{}"
    }
    
}

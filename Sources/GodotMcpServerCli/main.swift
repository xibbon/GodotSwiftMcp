import GodotSwiftMcp
import GodotSwiftMcpSocket
import MCP
import Foundation
import Logging

LoggingSystem.bootstrap(StreamLogHandler.standardError)
let logger = Logger(label: "godotMcp")
logger.error("MIGUEL STARTING")

let url = URL(string: "http://10.10.11.195:9080")

let transport = StdioTransport(logger: logger)
let provider = GodotLocalSocketProvider(target: url!)

let server = GodotMcpServer(logger: logger, provider: provider)

//try await server.start(on: transport)
print("Sending command")
DispatchQueue.main.async {
    print("Running on Main")
}
#if false
let res1 = try await provider.createNode(parentPath: "", nodeType: "Label", nodeName: "MyNewLabel")
print ("CreateNode: \(res1)")
let res = try await provider.getNodeProperties(nodePath: "Player")
for (k,v) in res {
    print("\(k): \(v)")
}

print("Scene at / has:")
for (name, type, path) in try await provider.listNodes(nodePath: "/") {
    print("\(name) of type \(type) at path: \(path)")
}

try await provider.createScript(scriptPath: "res://demo.gd", content: "# This created by a program", nodePath: nil)
try await provider.editScript(scriptPath: "res://demo.gd", content: "# And it has now been updated")
let contents = try await provider.getScript(scriptPath: "res://demo.gd", nodePath: nil)
print("The content is now: \(contents)")

//let assets = try await provider.listAssets(type: "resources")
//print(assets)

let pr = try await provider.listProjectFiles(extensions: ["gd"])
//let execute = try await provider.executeEditorScript(code: "1+3")
#endif

let x = try await provider.getSceneTree()
func dump(_ x: GodotProviderNode, indent: String = "") {
    print("\(indent)name: \(x.name) - \(x.type)")
    for child in x.children ?? [] {
        dump(child, indent: indent + "  ")
    }
}


let node  = try await provider.getSelectedNode()

dump(x)
//let y = try await provider.getDebugOutput()
//print(y)
let z = try await provider.getCurrentSceneInfo()
print("SceneInfo: \(z)")
while true {
    try await Task.sleep(for: .milliseconds(100))
}

//
//  SocketPairTransport.swift
//  GodotSwiftMcp
//
//  Created by Miguel de Icaza on 5/28/25.
//
import MCP
import Foundation
import Logging

/// Shared actor managing in-memory communication between client and server
public actor TransportSharedMemory {
    private var clientToServer: [Data] = []
    private var serverToClient: [Data] = []
    private var clientReceiveContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation?
    private var serverReceiveContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation?
    
    public init() {}
    
    /// Send data from client to server
    func sendToServer(_ data: Data) {
        clientToServer.append(data)
        serverReceiveContinuation?.yield(data)
    }
    
    /// Send data from server to client
    func sendToClient(_ data: Data) {
        serverToClient.append(data)
        clientReceiveContinuation?.yield(data)
    }
    
    /// Register client's receive continuation
    func registerClientReceiver(_ continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation) {
        clientReceiveContinuation = continuation
        // Deliver any buffered messages
        for data in serverToClient {
            continuation.yield(data)
        }
        serverToClient.removeAll()
    }
    
    /// Register server's receive continuation
    func registerServerReceiver(_ continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation) {
        serverReceiveContinuation = continuation
        // Deliver any buffered messages
        for data in clientToServer {
            continuation.yield(data)
        }
        clientToServer.removeAll()
    }
    
    /// Disconnect and cleanup
    func disconnect() {
        clientReceiveContinuation?.finish()
        serverReceiveContinuation?.finish()
        clientReceiveContinuation = nil
        serverReceiveContinuation = nil
        clientToServer.removeAll()
        serverToClient.removeAll()
    }
}

/// In-memory transport for client
public actor SharedMemoryClientTransport: Transport {
    public var logger: Logger
    private let commSpace: TransportSharedMemory
    private var isConnected = false
    
    public init(commSpace: TransportSharedMemory, logger: Logger? = nil) {
        self.commSpace = commSpace
        self.logger = logger ?? Logger(label: "godotmcpswift.memory-client.transport")
    }
    
    public func connect() async throws {
        isConnected = true
    }
    
    public func disconnect() async {
        isConnected = false
    }
    
    public func send(_ data: Data) async throws {
        guard isConnected else {
            throw TransportError.notConnected
        }
        await commSpace.sendToServer(data)
    }
    
    public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        AsyncThrowingStream { continuation in
            Task {
                await commSpace.registerClientReceiver(continuation)
            }
        }
    }
}

/// In-memory transport for server
public actor SharedMemoryServerTransport: Transport {
    public var logger: Logger
    private let commSpace: TransportSharedMemory
    private var isConnected = false
    
    public init(commSpace: TransportSharedMemory, logger: Logger? = nil) {
        self.commSpace = commSpace
        self.logger = logger ?? Logger(label: "godotmcpswift.memory-client.transport")
    }
    
    public func connect() async throws {
        isConnected = true
    }
    
    public func disconnect() async {
        isConnected = false
        await commSpace.disconnect()
    }
    
    public func send(_ data: Data) async throws {
        guard isConnected else {
            throw TransportError.notConnected
        }
        await commSpace.sendToClient(data)
    }
    
    public func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        AsyncThrowingStream { continuation in
            Task {
                await commSpace.registerServerReceiver(continuation)
            }
        }
    }
}

/// Transport-related errors
public enum TransportError: Swift.Error {
    case notConnected
}

#if DEBUG

extension Transport {
    func write(_ str: String) async throws {
        try await send(str.data(using: .utf8)!)
    }
    
    func readLoop(prefix: String) async {
        do {
            while !Task.isCancelled {
                for try await record in receive() {
                    if let str = String(data: record, encoding: .utf8) {
                        print("\(prefix) RECV: \(str)")
                    } else {
                        print("\(prefix) RECV binary stuff")
                    }
                }
            }
        } catch {
            print("\(prefix) terminating")
        }
    }
}

class TestMemoryTransport {
    var buffer: TransportSharedMemory
    
    init(){
        self.buffer = TransportSharedMemory()
        Task {
            let client = SharedMemoryClientTransport(commSpace: buffer)
            try await client.connect()
            Task {
                await client.readLoop(prefix: "CLIENT")
            }
            await startClient(client)
        }
        Task {
            let server = SharedMemoryServerTransport(commSpace: buffer)
            try await server.connect()
            Task {
                await server.readLoop(prefix: "SERVER")
            }
            await startServer(server)
        }
    }
    
    func startClient(_ t: Transport) async {
        for x in 0..<10 {
            try! await t.write("Sending message \(x) from client\n")
            try! await Task.sleep(for: .milliseconds(500))
        }
    }
    
    func startServer(_ t: Transport) async {
        for x in 0..<10 {
            try! await t.write("Sending message \(x) from server\n")
            try! await Task.sleep(for: .milliseconds(500))
        }
    }
}
//let d = Demo()
#endif

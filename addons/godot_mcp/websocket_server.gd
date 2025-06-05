@tool
class_name MCPWebSocketServer
extends Node

signal client_connected(id)
signal client_disconnected(id)
signal command_received(client_id, command)

var tcp_server = TCPServer.new()
var peers = {}
var _port = 9080

func _ready():
	set_process(false)

func _process(_delta):
	poll()

func is_server_active() -> bool:
	return tcp_server.is_listening()

func start_server() -> int:
	if is_server_active():
		return ERR_ALREADY_IN_USE
	
	# Configure TCP server
	var err = tcp_server.listen(_port, "0.0.0.0")
	if err == OK:
		set_process(true)
		print("MCP WebSocket server started on port %d" % _port)
	else:
		print("Failed to start MCP WebSocket server: %d" % err)
	
	return err

func stop_server() -> void:
	if is_server_active():
		# Close all client connections properly
		for client_id in peers.keys():
			if peers[client_id] != null:
				peers[client_id].close()
		peers.clear()
		
		# Stop TCP server
		tcp_server.stop()
		set_process(false)
		print("MCP WebSocket server stopped")

func poll() -> void:
	if not tcp_server.is_listening():
		return
	
	# Handle new connections
	if tcp_server.is_connection_available():
		var tcp = tcp_server.take_connection()
		if tcp == null:
			print("Failed to take TCP connection")
			return
		
		tcp.set_no_delay(true)  # Important for WebSocket
		
		print("New TCP connection accepted")
		var ws = WebSocketPeer.new()
		
		# Configure WebSocket peer
		ws.inbound_buffer_size = 64 * 1024 * 1024  # 64MB buffer
		ws.outbound_buffer_size = 64 * 1024 * 1024  # 64MB buffer
		ws.max_queued_packets = 4096
		
		# Accept the stream
		var err = ws.accept_stream(tcp)
		if err != OK:
			print("Failed to accept WebSocket stream: ", err)
			return
		
		# Generate client ID and store peer
		var client_id = randi() % (1 << 30) + 1
		peers[client_id] = ws
		print("WebSocket connection setup for client: ", client_id)
	
	# Process existing connections
	var to_remove = []
	
	for client_id in peers:
		var peer = peers[client_id]
		if peer == null:
			to_remove.append(client_id)
			continue
			
		peer.poll()
		var state = peer.get_ready_state()
		
		match state:
			WebSocketPeer.STATE_OPEN:
				# Process any available packets
				while peer.get_available_packet_count() > 0:
					var packet = peer.get_packet()
					_handle_packet(client_id, packet)
					
			WebSocketPeer.STATE_CONNECTING:
				print("Client %d still connecting..." % client_id)
				
			WebSocketPeer.STATE_CLOSING:
				print("Client %d closing connection..." % client_id)
				
			WebSocketPeer.STATE_CLOSED:
				print("Client %d connection closed. Code: %d, Reason: %s" % [
					client_id,
					peer.get_close_code(),
					peer.get_close_reason()
				])
				emit_signal("client_disconnected", client_id)
				to_remove.append(client_id)
	
	# Remove disconnected clients
	for client_id in to_remove:
		var peer = peers[client_id]
		if peer != null:
			peer.close()
		peers.erase(client_id)

func _handle_packet(client_id: int, packet: PackedByteArray) -> void:
	var text = packet.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(text)
	
	if parse_result == OK:
		var data = json.get_data()
		
		# Handle ping-pong for FastMCP
		if data.has("method") and data["method"] == "ping":
			var response = {
				"jsonrpc": "2.0",
				"id": data.get("id", 0),
				"result": "pong"
			}
			send_response(client_id, response)
			return
			
		print("Received command from client %d: %s" % [client_id, data])
		emit_signal("command_received", client_id, data)
	else:
		print("Error parsing JSON from client %d: %s at line %d" % 
			[client_id, json.get_error_message(), json.get_error_line()])

func send_response(client_id: int, response: Dictionary) -> int:
	if not peers.has(client_id):
		print("Error: Client %d not found" % client_id)
		return ERR_DOES_NOT_EXIST
	
	var peer = peers[client_id]
	if peer == null:
		print("Error: Peer is null for client %d" % client_id)
		return ERR_INVALID_PARAMETER
		
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("Error: Client %d connection not open" % client_id)
		return ERR_UNAVAILABLE
	
	var json_text = JSON.stringify(response)
	var result = peer.send_text(json_text)
	
	if result != OK:
		print("Error sending response to client %d: %d" % [client_id, result])
	
	return result

func set_port(new_port: int) -> void:
	if is_server_active():
		push_error("Cannot change port while server is active")
		return
	_port = new_port

func get_port() -> int:
	return _port

func get_client_count() -> int:
	return peers.size()

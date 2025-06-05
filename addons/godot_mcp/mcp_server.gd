@tool
extends EditorPlugin

var websocket_server: MCPWebSocketServer
var command_handler = null  # Command handler reference
var panel = null  # Reference to the MCP panel

func _enter_tree():
	# Store plugin instance for EditorInterface access
	Engine.set_meta("GodotMCPPlugin", self)
	
	print("\n=== MCP SERVER STARTING ===")
	
	# Initialize the websocket server
	websocket_server = load("res://addons/godot_mcp/websocket_server.gd").new()
	websocket_server.name = "WebSocketServer"
	add_child(websocket_server)
	
	# Initialize the command handler
	print("Creating command handler...")
	var handler_script = load("res://addons/godot_mcp/command_handler.gd")
	if handler_script:
		command_handler = Node.new()
		command_handler.set_script(handler_script)
		command_handler.name = "CommandHandler"
		websocket_server.add_child(command_handler)
		
		# Connect signals
		print("Connecting command handler signals...")
		websocket_server.connect("command_received", Callable(command_handler, "_handle_command"))
	else:
		printerr("Failed to load command handler script!")
	
	# Initialize the control panel
	panel = load("res://addons/godot_mcp/ui/mcp_panel.tscn").instantiate()
	panel.websocket_server = websocket_server
	add_control_to_bottom_panel(panel, "MCP Server")
	
	print("MCP Server plugin initialized")

func _exit_tree():
	# Remove plugin instance from Engine metadata
	if Engine.has_meta("GodotMCPPlugin"):
		Engine.remove_meta("GodotMCPPlugin")
	
	# Clean up the panel
	if panel:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
		panel = null
	
	# Clean up the websocket server and command handler
	if websocket_server:
		websocket_server.stop_server()
		websocket_server.queue_free()
		websocket_server = null
	
	print("=== MCP SERVER SHUTDOWN ===")

# Helper function for command processors to access EditorInterface
func get_editor_interface():
	return get_editor_interface()

# Helper function for command processors to get undo/redo manager
func get_undo_redo():
	return get_undo_redo()
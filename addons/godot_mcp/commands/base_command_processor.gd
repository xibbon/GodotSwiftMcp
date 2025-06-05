@tool
class_name MCPBaseCommandProcessor
extends Node

# Signal emitted when a command has completed processing
signal command_completed(client_id, command_type, result, command_id)

# Reference to the server - passed by the command handler
var _websocket_server = null

# Must be implemented by subclasses
func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	push_error("BaseCommandProcessor.process_command called directly")
	return false

# Helper functions common to all command processors
func _send_success(client_id: int, result: Dictionary, command_id: String) -> void:
	var response = {
		"status": "success",
		"result": result
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	# Emit the signal for local processing (useful for testing)
	command_completed.emit(client_id, "success", result, command_id)
	
	# Send to websocket if available
	if _websocket_server:
		_websocket_server.send_response(client_id, response)

func _send_error(client_id: int, message: String, command_id: String) -> void:
	var response = {
		"status": "error",
		"message": message
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	# Emit the signal for local processing (useful for testing)
	var error_result = {"error": message}
	command_completed.emit(client_id, "error", error_result, command_id)
	
	# Send to websocket if available
	if _websocket_server:
		_websocket_server.send_response(client_id, response)
	print("Error: %s" % message)

# Common utility methods
func _get_editor_node(path: String) -> Node:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		print("GodotMCPPlugin not found in Engine metadata")
		return null
		
	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	
	if not edited_scene_root:
		print("No edited scene found")
		return null
		
	# Handle absolute paths
	if path == "/root" or path == "":
		return edited_scene_root
		
	if path.begins_with("/root/"):
		path = path.substr(6)  # Remove "/root/"
	elif path.begins_with("/"):
		path = path.substr(1)  # Remove leading "/"
	
	# Try to find node as child of edited scene root
	return edited_scene_root.get_node_or_null(path)

# Enhanced version of _get_editor_node to improve node path resolution
func _get_editor_node_enhanced(path: String) -> Node:
	# First try the standard method
	var node = _get_editor_node(path)
	if node:
		return node
		
	# If not found, try additional resolution methods
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return null
		
	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	
	if not edited_scene_root:
		return null
	
	# Special case for main scene nodes with common names
	if path == "/root/Game" or path == "/root/game" or path == "/root/Main" or path == "/root/main":
		var node_name = path.get_file().to_lower()
		if edited_scene_root.name.to_lower() == node_name:
			return edited_scene_root
		
		# Try to find the node as a child of root if it's not the root itself
		for child in edited_scene_root.get_children():
			if child.name.to_lower() == node_name:
				return child
	
	# Try case-insensitive match for first level children
	var simplified_path = path
	if path.begins_with("/root/"):
		simplified_path = path.substr(6)  # Remove "/root/"
	elif path.begins_with("/"):
		simplified_path = path.substr(1)  # Remove leading "/"
		
	if simplified_path.find("/") == -1:
		for child in edited_scene_root.get_children():
			if child.name.to_lower() == simplified_path.to_lower():
				return child
	
	return null

# Helper function to mark a scene as modified
func _mark_scene_modified() -> void:
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		print("GodotMCPPlugin not found in Engine metadata")
		return
	
	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	
	if edited_scene_root:
		# This internally marks the scene as modified in the editor
		editor_interface.mark_scene_as_unsaved()

# Helper function to access the EditorUndoRedoManager
func _get_undo_redo():
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin or not plugin.has_method("get_undo_redo"):
		print("Cannot access UndoRedo from plugin")
		return null
		
	return plugin.get_undo_redo()

# Helper function to parse property values from string to proper Godot types
func _parse_property_value(value):
	# Only try to parse strings that look like they could be Godot types
	if typeof(value) == TYPE_STRING and (
		value.begins_with("Vector") or 
		value.begins_with("Transform") or 
		value.begins_with("Rect") or 
		value.begins_with("Color") or
		value.begins_with("Quat") or
		value.begins_with("Basis") or
		value.begins_with("Plane") or
		value.begins_with("AABB") or
		value.begins_with("Projection") or
		value.begins_with("Callable") or
		value.begins_with("Signal") or
		value.begins_with("PackedVector") or
		value.begins_with("PackedString") or
		value.begins_with("PackedFloat") or
		value.begins_with("PackedInt") or
		value.begins_with("PackedColor") or
		value.begins_with("PackedByteArray") or
		value.begins_with("Dictionary") or
		value.begins_with("Array")
	):
		var expression = Expression.new()
		var error = expression.parse(value, [])
		
		if error == OK:
			var result = expression.execute([], null, true)
			if not expression.has_execute_failed():
				print("Successfully parsed %s as %s" % [value, result])
				return result
			else:
				print("Failed to execute expression for: %s" % value)
		else:
			print("Failed to parse expression: %s (Error: %d)" % [value, error])
	
	# Otherwise, return value as is
	return value
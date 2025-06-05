@tool
class_name MCPEnhancedCommands
extends Node

var _websocket_server = null

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"get_full_scene_tree":
			_handle_get_full_scene_tree(client_id, params, command_id)
			return true
		"get_debug_output":
			_handle_get_debug_output(client_id, params, command_id)
			return true
		"update_node_transform":
			_handle_update_node_transform(client_id, params, command_id)
			return true
		"get_current_scene_structure":
			_handle_get_current_scene_structure(client_id, params, command_id)
			return true
	
	# Command not handled by this processor
	return false

# Helper function to get EditorInterface
func _get_editor_interface():
	var plugin_instance = Engine.get_meta("GodotMCPPlugin") as EditorPlugin
	if plugin_instance:
		return plugin_instance.get_editor_interface()
	return null

# ---- Full Scene Tree Commands ----

func _handle_get_full_scene_tree(client_id: int, _params: Dictionary, command_id: String) -> void:
	var result = get_full_scene_tree()
	
	_send_success(client_id, result, command_id)

func get_full_scene_tree() -> Dictionary:
	var result = {}
	var editor_interface = _get_editor_interface()
	if editor_interface:
		var root = editor_interface.get_edited_scene_root()
		if root:
			result = _walk_node(root)
	return result

func _walk_node(node):
	var info = {
		"name": node.name,
		"type": node.get_class(),
		"path": node.get_path(),
		"properties": {},
		"children": []
	}
	
	# Get some common properties if they exist
	if node.has_method("get_property_list"):
		var props = node.get_property_list()
		for prop in props:
			# Filter to avoid too much data
			if prop.usage & PROPERTY_USAGE_EDITOR and not (prop.usage & PROPERTY_USAGE_CATEGORY):
				# Only include commonly useful properties
				if prop.name in ["position", "rotation", "scale", "text", "visible"]:
					info["properties"][prop.name] = node.get(prop.name)
	
	# Get script information if available
	var script = node.get_script()
	if script:
		# Fix: Use safe access for script properties
		var script_path = ""
		var class_name_str = ""
		
		if typeof(script) == TYPE_OBJECT:
			if script.has_method("get_path") or "resource_path" in script:
				script_path = script.resource_path if "resource_path" in script else ""
			
			if script.has_method("get_instance_base_type"):
				class_name_str = script.get_instance_base_type()
		
		info["script"] = {
			"path": script_path,
			"class_name": class_name_str
		}
	
	# Recurse for children
	for child in node.get_children():
		info["children"].append(_walk_node(child))
	
	return info

# ---- Current Scene Structure Commands ----

func _handle_get_current_scene_structure(client_id: int, _params: Dictionary, command_id: String) -> void:
	var result = get_current_scene_structure()
	
	_send_success(client_id, result, command_id)

func get_current_scene_structure() -> Dictionary:
	var editor_interface = _get_editor_interface()
	if not editor_interface:
		return { "error": "Could not access EditorInterface" }
	
	var root = editor_interface.get_edited_scene_root()
	if not root:
		return { "error": "No scene is currently being edited" }
	
	# Fix: Safely handle scene_file_path
	var scene_path = ""
	
	# Use direct property access with safety checks
	if "scene_file_path" in root:
		scene_path = root.scene_file_path
		# Additional check to ensure it's a valid string
		if typeof(scene_path) != TYPE_STRING:
			scene_path = str(scene_path)  # Convert to string
	
	if scene_path.is_empty():
		scene_path = "Unsaved Scene"
	
	return {
		"path": scene_path,
		"root_node_type": root.get_class(),
		"root_node_name": root.name,
		"structure": _walk_node(root)
	}

# ---- Debug Output Commands ----

func _handle_get_debug_output(client_id: int, _params: Dictionary, command_id: String) -> void:
	var result = get_debug_output()
	
	_send_success(client_id, result, command_id)

func get_debug_output() -> Dictionary:
	var output = ""
	
	# For Godot 4.x
	if Engine.has_singleton("EditorDebuggerNode"):
		var debugger = Engine.get_singleton("EditorDebuggerNode")
		if debugger and debugger.has_method("get_log"):
			output = debugger.get_log()
	# For Godot 3.x fallback
	elif has_node("/root/EditorNode/DebuggerPanel"):
		var debugger = get_node("/root/EditorNode/DebuggerPanel")
		if debugger and debugger.has_method("get_output"):
			output = debugger.get_output()
	
	return {
		"output": output
	}

# ---- Node Transform Commands ----

func _handle_update_node_transform(client_id: int, params: Dictionary, command_id: String) -> void:
	var node_path = params.get("node_path", "")
	var position = params.get("position", null)
	var rotation = params.get("rotation", null)
	var scale = params.get("scale", null)
	
	var result = update_node_transform(node_path, position, rotation, scale)
	
	_send_success(client_id, result, command_id)

func update_node_transform(node_path: String, position, rotation, scale) -> Dictionary:
	var editor_interface = _get_editor_interface()
	
	if not editor_interface:
		return { "error": "Could not access EditorInterface" }
	
	var scene_root = editor_interface.get_edited_scene_root()
	
	if not scene_root:
		return { "error": "No scene open" }
	
	var node = scene_root.get_node_or_null(node_path)
	if not node:
		return { "error": "Node not found" }
	
	# Update all specified properties
	if position != null and node.has_method("set_position"):
		if position is Array and position.size() >= 2:
			node.set_position(Vector2(position[0], position[1]))
		elif typeof(position) == TYPE_DICTIONARY and "x" in position and "y" in position:
			node.set_position(Vector2(position.x, position.y))
	
	if rotation != null and node.has_method("set_rotation"):
		node.set_rotation(rotation)
	
	if scale != null and node.has_method("set_scale"):
		if scale is Array and scale.size() >= 2:
			node.set_scale(Vector2(scale[0], scale[1]))
		elif typeof(scale) == TYPE_DICTIONARY and "x" in scale and "y" in scale:
			node.set_scale(Vector2(scale.x, scale.y))
	
	# Mark the scene as modified
	editor_interface.mark_scene_as_unsaved()
	
	return {
		"success": true,
		"node_path": node_path,
		"updated": {
			"position": position != null,
			"rotation": rotation != null,
			"scale": scale != null
		}
	}

# Helper function to send success response
func _send_success(client_id: int, result: Dictionary, command_id: String) -> void:
	var response = {
		"status": "success",
		"result": result
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	_websocket_server.send_response(client_id, response)
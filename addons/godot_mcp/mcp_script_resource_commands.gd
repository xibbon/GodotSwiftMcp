@tool
class_name MCPScriptResourceCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"get_script":
			_handle_get_script(client_id, params, command_id)
			return true
		"edit_script":
			_handle_edit_script(client_id, params, command_id)
			return true
		"ai_generate_script":
			_handle_ai_generate_script(client_id, params, command_id)
			return true
	return false  # Command not handled

func _handle_get_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var path = params.get("path", "")
	var node_path = params.get("node_path", "")
	
	# Handle based on which parameter is provided
	var script_path = ""
	var result = {}
	
	if not path.is_empty():
		# Direct script path provided
		result = _get_script_by_path(path)
	elif not node_path.is_empty():
		# Node path provided, get attached script
		result = _get_script_by_node(node_path)
	else:
		result = {
			"error": "Either script_path or node_path must be provided",
			"script_found": false
		}
	
	_send_success(client_id, result, command_id)

func _get_script_by_path(script_path: String) -> Dictionary:
	if not FileAccess.file_exists(script_path):
		return {
			"error": "Script file not found",
			"script_found": false
		}
	
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {
			"error": "Failed to open script file",
			"script_found": false
		}
	
	var content = file.get_as_text()
	return {
		"script_found": true,
		"script_path": script_path,
		"content": content
	}

func _get_script_by_node(node_path: String) -> Dictionary:
	# Get editor plugin and interfaces
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if not plugin:
		return {
			"error": "GodotMCPPlugin not found in Engine metadata",
			"script_found": false
		}
	
	var editor_interface = plugin.get_editor_interface()
	var edited_scene_root = editor_interface.get_edited_scene_root()
	
	if not edited_scene_root:
		return {
			"error": "No scene is currently being edited",
			"script_found": false
		}
	
	var node = edited_scene_root.get_node_or_null(node_path)
	if not node:
		return {
			"error": "Node not found",
			"script_found": false
		}
	
	var script = node.get_script()
	if not script:
		return {
			"error": "Node has no script attached",
			"script_found": false
		}
	
	var script_path = script.resource_path
	return _get_script_by_path(script_path)

func _handle_edit_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var script_path = params.get("script_path", "")
	var content = params.get("content", "")
	
	var result = {}
	
	if script_path.is_empty():
		result = {
			"error": "Script path is required",
			"success": false
		}
	elif content.is_empty():
		result = {
			"error": "Content is required",
			"success": false
		}
	else:
		result = _edit_script_content(script_path, content)
	
	_send_success(client_id, result, command_id)

func _edit_script_content(script_path: String, content: String) -> Dictionary:
	# Make sure the path starts with res://
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path
	
	# Add .gd extension if not present
	if not script_path.ends_with(".gd"):
		script_path += ".gd"
	
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		return {
			"error": "Failed to open script file for writing",
			"success": false
		}
	
	file.store_string(content)
	
	# Open the script in the editor if possible
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if plugin:
		var editor_interface = plugin.get_editor_interface()
		var script = load(script_path)
		if script:
			editor_interface.edit_resource(script)
	
	return {
		"success": true,
		"script_path": script_path
	}

func _handle_ai_generate_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var description = params.get("description", "")
	var node_type = params.get("node_type", "Node")
	var create_file = params.get("create_file", false)
	var file_path = params.get("file_path", "")
	
	var result = {}
	
	if description.is_empty():
		result = {
			"error": "Description is required",
			"success": false
		}
	else:
		# Generate script based on description
		var script_content = _generate_script_from_description(description, node_type)
		
		if create_file and not file_path.is_empty():
			# Create the file
			var file_result = _create_script_file(file_path, script_content)
			
			if file_result.has("success") and file_result.success:
				result = {
					"success": true,
					"script_path": file_path,
					"content": script_content
				}
			else:
				result = file_result
		else:
			result = {
				"success": true,
				"content": script_content
			}
	
	_send_success(client_id, result, command_id)

func _generate_script_from_description(description: String, node_type: String) -> String:
	# Create an intelligently structured script based on the description
	# This uses heuristics to generate a template - no external API needed
	
	# Sanitize description for comments
	var safe_description = description.replace("#", "")
	
	# Basic template
	var template = "# " + safe_description + "\nextends " + node_type + "\n\n"
	
	# Add common sections
	template += "# Signals\n\n"
	
	# Add export variables section
	template += "# Export variables\n"
	
	# Parse description for potential properties
	if "movement" in description.to_lower() or "player" in description.to_lower():
		template += "export var speed = 300.0\n"
		template += "export var jump_strength = 600.0\n"
	
	if "health" in description.to_lower() or "damage" in description.to_lower():
		template += "export var max_health = 100.0\n"
		template += "export var current_health = 100.0\n"
	
	template += "\n# Private variables\n"
	
	# Add common variables based on description
	if "2d" in description.to_lower() and ("movement" in description.to_lower() or "character" in description.to_lower()):
		template += "var velocity = Vector2.ZERO\n"
	elif "3d" in description.to_lower() and ("movement" in description.to_lower() or "character" in description.to_lower()):
		template += "var velocity = Vector3.ZERO\n"
	
	template += "\n"
	
	# Add ready function
	template += "func _ready():\n"
	template += "\t# Initialize the " + node_type + "\n"
	template += "\tpass\n\n"
	
	# Add appropriate process function based on description
	if "movement" in description.to_lower() or "physics" in description.to_lower():
		template += "func _physics_process(delta):\n"
		template += "\t# Process movement and physics\n"
		
		if "movement" in description.to_lower() and "2d" in description.to_lower():
			template += "\t# Get input direction\n"
			template += "\tvar direction = Input.get_axis(\"ui_left\", \"ui_right\")\n"
			template += "\tif direction:\n"
			template += "\t\tvelocity.x = direction * speed\n"
			template += "\telse:\n"
			template += "\t\tvelocity.x = move_toward(velocity.x, 0, speed)\n\n"
			template += "\t# Apply movement\n"
			template += "\tmove_and_slide()\n"
	else:
		template += "func _process(delta):\n"
		template += "\t# Update logic for " + safe_description + "\n"
		template += "\tpass\n\n"
	
	# Add input handling if relevant
	if "input" in description.to_lower() or "control" in description.to_lower():
		template += "func _input(event):\n"
		template += "\t# Handle input events\n"
		template += "\tpass\n\n"
	
	# Add custom methods section
	template += "# Custom methods\n"
	
	if "damage" in description.to_lower() or "health" in description.to_lower():
		template += "func take_damage(amount):\n"
		template += "\tcurrent_health -= amount\n"
		template += "\tif current_health <= 0:\n"
		template += "\t\tdie()\n\n"
		
		template += "func die():\n"
		template += "\t# Handle death logic\n"
		template += "\tqueue_free()\n"
	
	return template

func _create_script_file(file_path: String, content: String) -> Dictionary:
	# Make sure the path starts with res://
	if not file_path.begins_with("res://"):
		file_path = "res://" + file_path
	
	# Add .gd extension if not present
	if not file_path.ends_with(".gd"):
		file_path += ".gd"
	
	# Create directory if it doesn't exist
	var dir_path = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return {
				"error": "Failed to create directory: %s (Error code: %d)" % [dir_path, err],
				"success": false
			}
	
	# Create the script file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {
			"error": "Failed to create script file: %s" % file_path,
			"success": false
		}
	
	file.store_string(content)
	file = null  # Close the file
	
	# Refresh the filesystem
	var plugin = Engine.get_meta("GodotMCPPlugin")
	if plugin:
		var editor_interface = plugin.get_editor_interface()
		editor_interface.get_resource_filesystem().scan()
	
	return {
		"success": true,
		"script_path": file_path
	}
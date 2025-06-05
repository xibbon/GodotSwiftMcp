@tool
class_name MCPAssetCommands
extends Node

var _websocket_server = null

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"list_project_files":
			_handle_list_project_files(client_id, params, command_id)
			return true
		"list_assets_by_type":
			_handle_list_assets_by_type(client_id, params, command_id)
			return true
	
	# Command not handled by this processor
	return false

# ---- Project File Listing ----

func _handle_list_project_files(client_id: int, params: Dictionary, command_id: String) -> void:
	var extensions = params.get("extensions", [])
	
	var result = list_project_files(extensions)
	
	var response = {
		"status": "success",
		"result": result
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	_websocket_server.send_response(client_id, response)

func list_project_files(extensions: Array) -> Dictionary:
	var result = []
	
	# Get all files recursively
	var dir = DirAccess.open("res://")
	if dir:
		_list_files_recursive(dir, "res://", extensions, result)
	
	return {
		"files": result
	}

# Helper function to recursively list files
func _list_files_recursive(dir: DirAccess, path: String, extensions: Array, result: Array) -> void:
	# Open the directory
	dir.list_dir_begin()
	
	# Loop through all files and directories
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				# Recursively process subdirectories
				var subdir = DirAccess.open(full_path)
				if subdir:
					_list_files_recursive(subdir, full_path, extensions, result)
			else:
				# If extensions are specified, filter by them
				if extensions.size() == 0:
					result.append(full_path)
				else:
					for ext in extensions:
						if file_name.ends_with(ext):
							result.append(full_path)
							break
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# ---- Asset Type Listing ----

func _handle_list_assets_by_type(client_id: int, params: Dictionary, command_id: String) -> void:
	var type = params.get("type", "all")
	
	var result = list_assets_by_type(type)
	
	var response = {
		"status": "success",
		"result": result
	}
	
	if not command_id.is_empty():
		response["commandId"] = command_id
	
	_websocket_server.send_response(client_id, response)

func list_assets_by_type(type: String) -> Dictionary:
	# Define file extensions for each asset type
	var extension_map = {
		"images": [".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".tga"],
		"audio": [".ogg", ".mp3", ".wav", ".opus"],
		"fonts": [".ttf", ".otf", ".fnt", ".font"],
		"models": [".glb", ".gltf", ".obj", ".fbx"],
		"shaders": [".gdshader", ".shader"],
		"resources": [".tres", ".res", ".theme", ".material"],
		"all": [] # Will retrieve everything
	}
	
	# Get extensions for the requested type
	var extensions = []
	if extension_map.has(type):
		extensions = extension_map[type]
	
	# Get files
	var file_result = list_project_files(extensions)
	var files = file_result.get("files", [])
	
	# Group by folder structure for better navigation
	var organized_files = {}
	for file_path in files:
		var parts = file_path.split("/")
		var current = organized_files
		
		# Skip the first "res://" part if present
		var start_idx = 1 if parts[0] == "res:" else 0
		
		# Process path parts
		for i in range(start_idx, parts.size() - 1):
			var part = parts[i]
			if not current.has(part):
				current[part] = {}
			current = current[part]
		
		# For the leaf/filename
		var file_name = parts[parts.size() - 1]
		current[file_name] = file_path
	
	return {
		"assetType": type,
		"extensions": extensions,
		"count": files.size(),
		"files": files,
		"organizedFiles": organized_files
	}
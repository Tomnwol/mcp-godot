@tool
extends Node

## Local WebSocket server that the godot-mcp Node process connects to.
## Uses TCPServer + WebSocketPeer (compatible with Godot 4.x).
## Protocol: { "id", "method", "params?" } → { "id", "result" } | { "id", "error" }.
## Responses stay compact: shallow trees, search-first, pagination.

const DEFAULT_PORT := 6505
const PROTOCOL_VERSION := "2"

var _tcp_server: TCPServer
var _peers: Dictionary = {}
var _next_peer_id := 1
var _logger: Logger


func _ready() -> void:
	_tcp_server = TCPServer.new()
	var err: Error = _tcp_server.listen(DEFAULT_PORT)
	if err != OK:
		push_error("godot-mcp: failed to listen on port %d (error %d)" % [DEFAULT_PORT, err])
		set_process(false)
		return
	print("godot-mcp: listening on ws://127.0.0.1:%d" % DEFAULT_PORT)

	var logger_script: GDScript = load("res://addons/godot-mcp/mcp_logger.gd") as GDScript
	if logger_script:
		_logger = logger_script.new()
		OS.add_logger(_logger)


func _exit_tree() -> void:
	if _logger:
		OS.remove_logger(_logger)
		_logger = null


func _process(_delta: float) -> void:
	if _tcp_server == null:
		return

	while _tcp_server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.accept_stream(_tcp_server.take_connection())
		_peers[_next_peer_id] = ws
		_next_peer_id += 1

	for peer_id in _peers.keys():
		var peer: WebSocketPeer = _peers[peer_id]
		peer.poll()
		var state: WebSocketPeer.State = peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				_handle_message(peer, peer.get_packet().get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSED:
			_peers.erase(peer_id)


func _handle_message(peer: WebSocketPeer, raw: String) -> void:
	var json := JSON.new()
	if json.parse(raw) != OK:
		_send_error(peer, "", -32700, "Parse error")
		return
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		_send_error(peer, "", -32600, "Invalid request")
		return

	var request_id = data.get("id", "")
	var method: String = data.get("method", "")
	var params: Dictionary = data.get("params", {})

	match method:
		"ping":
			_handle_ping(peer, request_id)
		"get_editor_state":
			_send_result(peer, request_id, _build_editor_state())
		"get_scene_tree":
			_handle_get_scene_tree(peer, request_id, params)
		"search_nodes":
			_handle_search_nodes(peer, request_id, params)
		"get_node_property":
			_handle_get_node_property(peer, request_id, params)
		"set_node_property":
			_handle_set_node_property(peer, request_id, params)
		"list_node_properties":
			_handle_list_node_properties(peer, request_id, params)
		"create_node":
			_handle_create_node(peer, request_id, params)
		"delete_node":
			_handle_delete_node(peer, request_id, params)
		"instantiate_scene":
			_handle_instantiate_scene(peer, request_id, params)
		"save_scene":
			_handle_save_scene(peer, request_id)
		"get_script":
			_handle_get_script(peer, request_id, params)
		"set_script":
			_handle_set_script(peer, request_id, params)
		"run_project":
			_handle_run_project(peer, request_id, params)
		"stop_project":
			_handle_stop_project(peer, request_id)
		"get_output_log":
			_handle_get_output_log(peer, request_id, params)
		_:
			_send_error(peer, request_id, -32601, "Method not found: %s" % method)


# =============================================================================
# Editor / connectivity
# =============================================================================

func _handle_ping(peer: WebSocketPeer, request_id: Variant) -> void:
	var vi: Dictionary = Engine.get_version_info()
	_send_result(peer, request_id, {
		"pong": true,
		"protocol_version": PROTOCOL_VERSION,
		"godot_version": "%d.%d.%d" % [vi.get("major", 0), vi.get("minor", 0), vi.get("patch", 0)],
		"editor": true,
	})


func _build_editor_state() -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	var selected: Array = []
	var selection := EditorInterface.get_selection()
	if selection:
		for node in selection.get_selected_nodes():
			if node is Node:
				selected.append({
					"path": _node_rel_path(node),
					"type": node.get_class(),
					"name": String(node.name),
				})

	return {
		"scene_path": scene_root.scene_file_path if scene_root else "",
		"root": (
			{"name": String(scene_root.name), "type": scene_root.get_class(), "path": String(scene_root.name)}
			if scene_root else null
		),
		"selected": selected,
		"playing": EditorInterface.is_playing_scene(),
		"main_screen": _detect_main_screen(),
	}


## get_editor_main_screen() returns the VBoxContainer host, not a screen index.
func _detect_main_screen() -> String:
	var script_editor := EditorInterface.get_script_editor()
	if script_editor != null and script_editor.is_visible_in_tree():
		return "Script"

	var main := EditorInterface.get_editor_main_screen()
	if main == null:
		return "unknown"

	for child in main.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var cls := child.get_class()
		var n := String(child.name)
		if cls.contains("CanvasItem") or n.contains("2D"):
			return "2D"
		if cls.contains("Node3D") or cls.contains("Spatial") or n.contains("3D"):
			return "3D"
		if cls.contains("Script") or n.contains("Script"):
			return "Script"
		if cls.contains("Game") or n.contains("Game"):
			return "Game"
		if cls.contains("Asset") or n.contains("Asset"):
			return "AssetLib"

	return "unknown"


# =============================================================================
# Scene tree / search
# =============================================================================

func _handle_get_scene_tree(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var max_depth: int = int(params.get("max_depth", 2))
	var limit: int = clampi(int(params.get("limit", 80)), 1, 500)
	var format: String = str(params.get("format", "outline"))
	_send_result(peer, request_id, _build_scene_tree(max_depth, limit, format))


func _build_scene_tree(max_depth: int, limit: int, format: String) -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return {
			"scene_path": "",
			"format": format,
			"node_count": 0,
			"truncated": false,
			"message": "No scene is currently open in the editor.",
		}

	var counter := {"count": 0, "truncated": false}
	if format == "json":
		return {
			"scene_path": scene_root.scene_file_path,
			"format": "json",
			"root": _serialize_node_json(scene_root, scene_root, 0, max_depth, limit, counter),
			"node_count": counter.count,
			"truncated": counter.truncated,
			"max_depth": max_depth,
			"limit": limit,
		}

	var lines: PackedStringArray = []
	_serialize_node_outline(scene_root, scene_root, 0, max_depth, limit, counter, lines)
	return {
		"scene_path": scene_root.scene_file_path,
		"format": "outline",
		"tree": "\n".join(lines),
		"node_count": counter.count,
		"truncated": counter.truncated,
		"max_depth": max_depth,
		"limit": limit,
	}


func _serialize_node_outline(
	node: Node,
	scene_root: Node,
	depth: int,
	max_depth: int,
	limit: int,
	counter: Dictionary,
	lines: PackedStringArray
) -> void:
	if counter.count >= limit:
		counter.truncated = true
		return

	counter.count += 1
	var indent := "  ".repeat(depth)
	lines.append("%s%s (%s) [%s]" % [indent, node.name, node.get_class(), _node_rel_path_from(node, scene_root)])

	if max_depth >= 0 and depth >= max_depth:
		if node.get_child_count() > 0 and counter.count < limit:
			lines.append("%s  … (%d children)" % [indent, node.get_child_count()])
		return

	for child in node.get_children():
		_serialize_node_outline(child, scene_root, depth + 1, max_depth, limit, counter, lines)
		if counter.truncated:
			return


func _serialize_node_json(
	node: Node,
	scene_root: Node,
	depth: int,
	max_depth: int,
	limit: int,
	counter: Dictionary
) -> Variant:
	if counter.count >= limit:
		counter.truncated = true
		return null

	counter.count += 1
	var children: Array = []
	if max_depth < 0 or depth < max_depth:
		for child in node.get_children():
			if counter.count >= limit:
				counter.truncated = true
				break
			var child_data = _serialize_node_json(child, scene_root, depth + 1, max_depth, limit, counter)
			if child_data != null:
				children.append(child_data)

	return {
		"name": String(node.name),
		"type": node.get_class(),
		"path": _node_rel_path_from(node, scene_root),
		"children": children,
	}


func _handle_search_nodes(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var query: String = str(params.get("query", "")).strip_edges()
	var type_filter: String = str(params.get("type", "")).strip_edges()
	var limit: int = clampi(int(params.get("limit", 20)), 1, 200)
	if query.is_empty() and type_filter.is_empty():
		_send_error(peer, request_id, -32602, "Provide query and/or type")
		return

	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_send_result(peer, request_id, {
			"matches": [],
			"total": 0,
			"truncated": false,
			"message": "No scene is currently open in the editor.",
		})
		return

	var matches: Array = []
	var stats := {"total": 0}
	var query_lower := query.to_lower()
	_search_nodes_recursive(scene_root, scene_root, query_lower, type_filter, limit, matches, stats)
	_send_result(peer, request_id, {
		"matches": matches,
		"total": stats.total,
		"truncated": stats.total > matches.size(),
		"limit": limit,
	})


func _search_nodes_recursive(
	node: Node,
	scene_root: Node,
	query_lower: String,
	type_filter: String,
	limit: int,
	matches: Array,
	stats: Dictionary
) -> void:
	var name_str := String(node.name)
	var type_str := node.get_class()
	var name_ok := query_lower.is_empty() or name_str.to_lower().contains(query_lower)
	var type_ok := type_filter.is_empty() or type_str == type_filter or node.is_class(type_filter)

	var matched := false
	if query_lower.is_empty():
		matched = type_ok
	elif type_filter.is_empty():
		matched = name_ok
	else:
		matched = name_ok and type_ok

	if matched:
		stats.total += 1
		if matches.size() < limit:
			matches.append({
				"name": name_str,
				"type": type_str,
				"path": _node_rel_path_from(node, scene_root),
			})

	for child in node.get_children():
		_search_nodes_recursive(child, scene_root, query_lower, type_filter, limit, matches, stats)


# =============================================================================
# Node properties
# =============================================================================

func _handle_get_node_property(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var path: String = params.get("path", "")
	var property: String = params.get("property", "")
	if property.is_empty():
		_send_error(peer, request_id, -32602, "Missing required parameter: property")
		return

	var node := _resolve_node(path)
	if node == null:
		_send_error(peer, request_id, -32001, "Node not found: %s" % path)
		return
	if not _has_property(node, property):
		_send_error(peer, request_id, -32002, "Property not found on %s: %s" % [node.get_class(), property])
		return

	_send_result(peer, request_id, {
		"path": _node_rel_path(node),
		"property": property,
		"value": _serialize_value(node.get(property)),
	})


func _handle_set_node_property(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var path: String = params.get("path", "")
	var property: String = params.get("property", "")
	if property.is_empty():
		_send_error(peer, request_id, -32602, "Missing required parameter: property")
		return
	if not params.has("value"):
		_send_error(peer, request_id, -32602, "Missing required parameter: value")
		return

	var node := _resolve_node(path)
	if node == null:
		_send_error(peer, request_id, -32001, "Node not found: %s" % path)
		return
	if not _has_property(node, property):
		_send_error(peer, request_id, -32002, "Property not found on %s: %s" % [node.get_class(), property])
		return

	var current = node.get(property)
	node.set(property, _deserialize_value(current, params["value"]))
	_mark_scene_unsaved()
	_send_result(peer, request_id, {
		"path": _node_rel_path(node),
		"property": property,
		"value": _serialize_value(node.get(property)),
	})


func _handle_list_node_properties(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var path: String = params.get("path", "")
	var exported_only: bool = bool(params.get("exported_only", false))
	var editable_only: bool = bool(params.get("editable_only", true))
	var relevant_only: bool = bool(params.get("relevant_only", true))
	var include_values: bool = bool(params.get("include_values", false))
	var name_contains: String = str(params.get("name_contains", "")).strip_edges().to_lower()
	var limit: int = clampi(int(params.get("limit", 60)), 1, 300)
	var detail: String = str(params.get("detail", "summary"))

	var node := _resolve_node(path)
	if node == null:
		_send_error(peer, request_id, -32001, "Node not found: %s" % path)
		return

	var by_name := {}
	for prop in node.get_property_list():
		if not _should_include_property(prop, exported_only, editable_only, relevant_only):
			continue
		if not name_contains.is_empty() and not str(prop.name).to_lower().contains(name_contains):
			continue
		by_name[prop.name] = prop

	var names: Array = by_name.keys()
	names.sort()
	var total: int = names.size()
	var truncated := total > limit
	if truncated:
		names = names.slice(0, limit)

	var properties: Array = []
	for prop_name in names:
		properties.append(_serialize_property_info(node, by_name[prop_name], include_values, detail))

	_send_result(peer, request_id, {
		"path": _node_rel_path(node),
		"type": node.get_class(),
		"detail": detail,
		"total": total,
		"truncated": truncated,
		"properties": properties,
	})


func _should_include_property(prop: Dictionary, exported_only: bool, editable_only: bool, relevant_only: bool) -> bool:
	var usage: int = prop.usage
	if exported_only and (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
		return false
	if editable_only:
		if usage & PROPERTY_USAGE_INTERNAL:
			return false
		if usage & PROPERTY_USAGE_READ_ONLY:
			return false
		if usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_CATEGORY or usage & PROPERTY_USAGE_SUBGROUP:
			return false
	if relevant_only and not _is_relevant_property(prop):
		return false
	return true


func _is_relevant_property(prop: Dictionary) -> bool:
	var usage: int = prop.usage
	var prop_name: String = prop.name
	if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
		return true
	if usage == 0:
		return false
	if _is_noise_property_name(prop_name):
		return false
	var has_editor := (usage & PROPERTY_USAGE_EDITOR) != 0
	var has_storage := (usage & PROPERTY_USAGE_STORAGE) != 0
	if has_editor:
		return true
	if has_storage and (
		prop_name.begins_with("anchor_")
		or prop_name.begins_with("offset_")
		or prop_name.begins_with("grow_")
	):
		return true
	return false


func _is_noise_property_name(prop_name: String) -> bool:
	if prop_name.begins_with("accessibility_"):
		return true
	if prop_name.begins_with("focus_neighbor_"):
		return true
	if prop_name.begins_with("process_"):
		return true
	if prop_name.begins_with("offset_transform_"):
		return true
	return prop_name in [
		"auto_translate", "auto_translate_mode", "editor_description",
		"focus_behavior_recursive", "focus_next", "focus_previous",
		"global_position", "layout_direction", "light_mask",
		"localize_numeral_system", "multiplayer", "mouse_behavior_recursive",
		"name", "owner", "physics_interpolation_mode", "rotation_degrees",
		"scene_file_path", "shortcut_context", "tooltip_auto_translate_mode",
		"translation_context", "unique_name_in_owner", "visibility_layer",
		"y_sort_enabled", "z_as_relative", "oversampling_with_scale",
		"propagate_maximum_size", "show_behind_parent", "use_parent_material",
		"clip_children", "top_level", "texture_filter", "texture_repeat",
	]


func _serialize_property_info(obj: Object, prop: Dictionary, include_values: bool, detail: String) -> Variant:
	var type_name := _variant_type_name(prop.type)
	var property_class: String = prop.get("class_name", "")
	if prop.type == TYPE_OBJECT and not property_class.is_empty():
		type_name = property_class

	if detail == "name":
		return str(prop.name)

	var entry := {"name": prop.name, "type": type_name}
	if detail == "full":
		if not property_class.is_empty():
			entry["class_name"] = property_class
		var hint: int = prop.hint
		if hint != 0:
			entry["hint"] = hint
		var hint_string: String = prop.get("hint_string", "")
		if not hint_string.is_empty():
			entry["hint_string"] = hint_string
		var usage_labels := _usage_labels(prop.usage)
		if not usage_labels.is_empty():
			entry["usage"] = usage_labels
	if include_values:
		entry["value"] = _serialize_value(obj.get(prop.name))
	return entry


# =============================================================================
# Scene structure CRUD
# =============================================================================

func _handle_create_node(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var parent_path: String = params.get("parent", "")
	var type_name: String = str(params.get("type", "")).strip_edges()
	var node_name: String = str(params.get("name", "")).strip_edges()
	if type_name.is_empty():
		_send_error(peer, request_id, -32602, "Missing required parameter: type")
		return

	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_send_error(peer, request_id, -32001, "No scene is currently open in the editor.")
		return

	var parent := _resolve_node(parent_path)
	if parent == null:
		_send_error(peer, request_id, -32001, "Parent node not found: %s" % parent_path)
		return
	if not ClassDB.class_exists(type_name):
		_send_error(peer, request_id, -32602, "Unknown class: %s" % type_name)
		return
	if not ClassDB.can_instantiate(type_name):
		_send_error(peer, request_id, -32602, "Cannot instantiate class: %s" % type_name)
		return

	var instance = ClassDB.instantiate(type_name)
	if not instance is Node:
		_send_error(peer, request_id, -32602, "Class is not a Node: %s" % type_name)
		return

	var new_node: Node = instance
	if node_name.is_empty():
		node_name = type_name
	new_node.name = node_name
	parent.add_child(new_node)
	_set_owner_recursive(new_node, scene_root)
	_mark_scene_unsaved()

	_send_result(peer, request_id, {
		"path": _node_rel_path(new_node),
		"type": new_node.get_class(),
		"name": String(new_node.name),
		"parent": _node_rel_path(parent),
	})


func _handle_delete_node(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var path: String = params.get("path", "")
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_send_error(peer, request_id, -32001, "No scene is currently open in the editor.")
		return

	var node := _resolve_node(path)
	if node == null:
		_send_error(peer, request_id, -32001, "Node not found: %s" % path)
		return
	if node == scene_root:
		_send_error(peer, request_id, -32602, "Cannot delete the scene root")
		return

	var deleted_path := _node_rel_path(node)
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	node.free()
	_mark_scene_unsaved()
	_send_result(peer, request_id, {"deleted": deleted_path})


func _handle_instantiate_scene(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var parent_path: String = params.get("parent", "")
	var scene_path: String = str(params.get("scene_path", "")).strip_edges()
	var node_name: String = str(params.get("name", "")).strip_edges()
	if scene_path.is_empty():
		_send_error(peer, request_id, -32602, "Missing required parameter: scene_path")
		return

	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_send_error(peer, request_id, -32001, "No scene is currently open in the editor.")
		return

	var parent := _resolve_node(parent_path)
	if parent == null:
		_send_error(peer, request_id, -32001, "Parent node not found: %s" % parent_path)
		return

	var packed = load(scene_path)
	if packed == null or not packed is PackedScene:
		_send_error(peer, request_id, -32602, "Not a PackedScene: %s" % scene_path)
		return

	var instance: Node = packed.instantiate()
	if not node_name.is_empty():
		instance.name = node_name
	parent.add_child(instance)
	_set_owner_recursive(instance, scene_root)
	_mark_scene_unsaved()

	_send_result(peer, request_id, {
		"path": _node_rel_path(instance),
		"type": instance.get_class(),
		"name": String(instance.name),
		"scene_path": scene_path,
		"parent": _node_rel_path(parent),
	})


func _handle_save_scene(peer: WebSocketPeer, request_id: Variant) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_send_error(peer, request_id, -32001, "No scene is currently open in the editor.")
		return
	var err: Error = EditorInterface.save_scene()
	if err != OK:
		_send_error(peer, request_id, -32003, "Failed to save scene (error %d)" % err)
		return
	_send_result(peer, request_id, {
		"saved": true,
		"scene_path": scene_root.scene_file_path,
	})


# =============================================================================
# Scripts
# =============================================================================

func _handle_get_script(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var node_path: String = str(params.get("path", "")).strip_edges()
	var script_path: String = str(params.get("script_path", "")).strip_edges()
	var offset: int = maxi(int(params.get("offset", 1)), 1)
	var limit: int = clampi(int(params.get("limit", 80)), 1, 400)

	var source := ""
	var resolved_path := script_path

	if not script_path.is_empty():
		if not FileAccess.file_exists(script_path):
			_send_error(peer, request_id, -32004, "Script file not found: %s" % script_path)
			return
		var file := FileAccess.open(script_path, FileAccess.READ)
		if file == null:
			_send_error(peer, request_id, -32004, "Cannot read script: %s" % script_path)
			return
		source = file.get_as_text()
	elif not node_path.is_empty():
		var node := _resolve_node(node_path)
		if node == null:
			_send_error(peer, request_id, -32001, "Node not found: %s" % node_path)
			return
		var script = node.get_script()
		if script == null:
			_send_error(peer, request_id, -32004, "Node has no script: %s" % node_path)
			return
		resolved_path = script.resource_path
		if script is GDScript:
			source = (script as GDScript).source_code
		elif not resolved_path.is_empty() and FileAccess.file_exists(resolved_path):
			var file2 := FileAccess.open(resolved_path, FileAccess.READ)
			source = file2.get_as_text() if file2 else ""
		else:
			_send_error(peer, request_id, -32004, "Cannot read script on node: %s" % node_path)
			return
	else:
		_send_error(peer, request_id, -32602, "Provide path (node) or script_path")
		return

	var all_lines := source.split("\n")
	var total_lines: int = all_lines.size()
	var start_idx := offset - 1
	if start_idx >= total_lines:
		_send_result(peer, request_id, {
			"script_path": resolved_path,
			"offset": offset,
			"limit": limit,
			"total_lines": total_lines,
			"truncated": false,
			"content": "",
		})
		return

	var end_idx: int = mini(start_idx + limit, total_lines)
	var slice := all_lines.slice(start_idx, end_idx)
	_send_result(peer, request_id, {
		"script_path": resolved_path,
		"offset": offset,
		"limit": limit,
		"total_lines": total_lines,
		"truncated": end_idx < total_lines,
		"content": "\n".join(slice),
	})


func _handle_set_script(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var script_path: String = str(params.get("script_path", "")).strip_edges()
	if script_path.is_empty():
		_send_error(peer, request_id, -32602, "Missing required parameter: script_path")
		return
	if not params.has("content"):
		_send_error(peer, request_id, -32602, "Missing required parameter: content")
		return

	var content: String = str(params["content"])
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		_send_error(peer, request_id, -32004, "Cannot write script: %s" % script_path)
		return
	file.store_string(content)
	file.close()

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	var attach_path: String = str(params.get("attach_to", "")).strip_edges()
	if not attach_path.is_empty():
		var node := _resolve_node(attach_path)
		if node == null:
			_send_error(peer, request_id, -32001, "Node not found for attach_to: %s" % attach_path)
			return
		var script_res = load(script_path)
		if script_res == null:
			_send_error(peer, request_id, -32004, "Failed to reload script after write: %s" % script_path)
			return
		node.set_script(script_res)
		_mark_scene_unsaved()

	var line_count := content.split("\n").size()
	_send_result(peer, request_id, {
		"saved": true,
		"script_path": script_path,
		"bytes": content.length(),
		"lines": line_count,
		"attached_to": attach_path if not attach_path.is_empty() else null,
	})


# =============================================================================
# Run / log
# =============================================================================

func _handle_run_project(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var mode: String = str(params.get("mode", "main")).strip_edges()
	if EditorInterface.is_playing_scene():
		EditorInterface.stop_playing_scene()

	match mode:
		"current":
			EditorInterface.play_current_scene()
		_:
			EditorInterface.play_main_scene()

	_send_result(peer, request_id, {
		"playing": true,
		"mode": mode if mode == "current" else "main",
	})


func _handle_stop_project(peer: WebSocketPeer, request_id: Variant) -> void:
	var was_playing := EditorInterface.is_playing_scene()
	if was_playing:
		EditorInterface.stop_playing_scene()
	_send_result(peer, request_id, {"stopped": was_playing, "playing": false})


func _handle_get_output_log(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var tail: int = clampi(int(params.get("tail", 40)), 1, 200)
	var level: String = str(params.get("level", "all")).strip_edges()
	var lines: Array = []
	if _logger and _logger.has_method("snapshot"):
		lines = _logger.call("snapshot", tail, level)
	_send_result(peer, request_id, {
		"tail": tail,
		"level": level,
		"count": lines.size(),
		"lines": lines,
	})


# =============================================================================
# Shared helpers
# =============================================================================

func _resolve_node(rel_path: String) -> Node:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return null
	if rel_path.is_empty() or rel_path == scene_root.name:
		return scene_root
	return scene_root.get_node_or_null(NodePath(rel_path))


func _node_rel_path(node: Node) -> String:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return String(node.name)
	return _node_rel_path_from(node, scene_root)


func _node_rel_path_from(node: Node, scene_root: Node) -> String:
	var rel_path := str(scene_root.get_path_to(node))
	if rel_path.is_empty():
		rel_path = String(node.name)
	return rel_path


func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)


func _mark_scene_unsaved() -> void:
	if EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()


func _has_property(obj: Object, property_name: String) -> bool:
	for prop in obj.get_property_list():
		if prop.name == property_name:
			return true
	return false


func _variant_type_name(t: int) -> String:
	match t:
		TYPE_NIL: return "Nil"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_RECT2: return "Rect2"
		TYPE_RECT2I: return "Rect2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_VECTOR4: return "Vector4"
		TYPE_VECTOR4I: return "Vector4i"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_PROJECTION: return "Projection"
		TYPE_COLOR: return "Color"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT: return "Object"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return str(t)


func _usage_labels(usage: int) -> Array:
	var labels: Array = []
	if usage & PROPERTY_USAGE_STORAGE:
		labels.append("storage")
	if usage & PROPERTY_USAGE_EDITOR:
		labels.append("editor")
	if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
		labels.append("script")
	if usage & PROPERTY_USAGE_INTERNAL:
		labels.append("internal")
	if usage & PROPERTY_USAGE_READ_ONLY:
		labels.append("read_only")
	return labels


func _serialize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return {"x": v2.x, "y": v2.y}
		TYPE_VECTOR2I:
			var v2i: Vector2i = value
			return {"x": v2i.x, "y": v2i.y}
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return {"x": v3.x, "y": v3.y, "z": v3.z}
		TYPE_VECTOR3I:
			var v3i: Vector3i = value
			return {"x": v3i.x, "y": v3i.y, "z": v3i.z}
		TYPE_COLOR:
			var c: Color = value
			return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}
		TYPE_ARRAY:
			var out_a: Array = []
			for item in value:
				out_a.append(_serialize_value(item))
			return out_a
		TYPE_DICTIONARY:
			var out_d := {}
			for key in value:
				out_d[str(key)] = _serialize_value(value[key])
			return out_d
		TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Node:
				var scene_root := EditorInterface.get_edited_scene_root()
				if scene_root and (value == scene_root or scene_root.is_ancestor_of(value)):
					return {"type": "Node", "path": _node_rel_path(value)}
			return {"type": value.get_class(), "hint": "non-serializable object reference"}
		_:
			return str(value)


func _deserialize_value(template: Variant, value: Variant) -> Variant:
	match typeof(template):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING:
			return str(value)
		TYPE_VECTOR2:
			if typeof(value) == TYPE_DICTIONARY:
				return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
			return template
		TYPE_VECTOR2I:
			if typeof(value) == TYPE_DICTIONARY:
				return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
			return template
		TYPE_VECTOR3:
			if typeof(value) == TYPE_DICTIONARY:
				return Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0)))
			return template
		TYPE_VECTOR3I:
			if typeof(value) == TYPE_DICTIONARY:
				return Vector3i(int(value.get("x", 0)), int(value.get("y", 0)), int(value.get("z", 0)))
			return template
		TYPE_COLOR:
			if typeof(value) == TYPE_DICTIONARY:
				return Color(
					float(value.get("r", 0)),
					float(value.get("g", 0)),
					float(value.get("b", 0)),
					float(value.get("a", 1))
				)
			return template
		TYPE_ARRAY:
			if typeof(value) != TYPE_ARRAY:
				return template
			var out: Array = []
			var template_arr: Array = template
			for i in value.size():
				var item_template = template_arr[i] if i < template_arr.size() else null
				out.append(_deserialize_value(item_template, value[i]))
			return out
		TYPE_STRING_NAME:
			return StringName(str(value))
		TYPE_NODE_PATH:
			return NodePath(str(value))
		_:
			return value


func _send_result(peer: WebSocketPeer, request_id: Variant, result: Variant) -> void:
	peer.send_text(JSON.stringify({"id": request_id, "result": result}))


func _send_error(peer: WebSocketPeer, request_id: Variant, code: int, message: String) -> void:
	peer.send_text(JSON.stringify({
		"id": request_id,
		"error": {"code": code, "message": message},
	}))

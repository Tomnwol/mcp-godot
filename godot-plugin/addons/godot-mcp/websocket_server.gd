@tool
extends Node

## Local WebSocket server that the godot-mcp Node process connects to.
## Uses TCPServer + WebSocketPeer (compatible with all Godot 4.x versions).
## Protocol: JSON messages { "id", "method", "params?" } → { "id", "result" } or { "id", "error" }.

const DEFAULT_PORT := 6505
const PROTOCOL_VERSION := "1"

var _tcp_server: TCPServer
var _peers: Dictionary = {}
var _next_peer_id := 1


func _ready() -> void:
	_tcp_server = TCPServer.new()
	var err: Error = _tcp_server.listen(DEFAULT_PORT)
	if err != OK:
		push_error("godot-mcp: failed to listen on port %d (error %d)" % [DEFAULT_PORT, err])
		set_process(false)
		return
	print("godot-mcp: listening on ws://127.0.0.1:%d" % DEFAULT_PORT)


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
				var raw := peer.get_packet().get_string_from_utf8()
				_handle_message(peer, raw)
		elif state == WebSocketPeer.STATE_CLOSED:
			_peers.erase(peer_id)


func _handle_message(peer: WebSocketPeer, raw: String) -> void:
	var json := JSON.new()
	var parse_err: Error = json.parse(raw)
	if parse_err != OK:
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
			_send_result(peer, request_id, {
				"pong": true,
				"protocol_version": PROTOCOL_VERSION,
				"godot_version": Engine.get_version_info(),
				"editor": true,
			})
		"get_scene_tree":
			var max_depth: int = int(params.get("max_depth", -1))
			_send_result(peer, request_id, _build_scene_tree(max_depth))
		"get_node_property":
			_handle_get_node_property(peer, request_id, params)
		"set_node_property":
			_handle_set_node_property(peer, request_id, params)
		"list_node_properties":
			_handle_list_node_properties(peer, request_id, params)
		_:
			_send_error(peer, request_id, -32601, "Method not found: %s" % method)


func _build_scene_tree(max_depth: int) -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return {
			"scene_path": "",
			"root": null,
			"message": "No scene is currently open in the editor.",
		}

	return {
		"scene_path": scene_root.scene_file_path,
		"root": _serialize_node(scene_root, scene_root, 0, max_depth),
	}


func _serialize_node(node: Node, scene_root: Node, depth: int, max_depth: int) -> Dictionary:
	var children: Array = []
	if max_depth < 0 or depth < max_depth:
		for child in node.get_children():
			children.append(_serialize_node(child, scene_root, depth + 1, max_depth))

	var rel_path := str(scene_root.get_path_to(node))
	if rel_path.is_empty():
		rel_path = node.name

	return {
		"name": node.name,
		"type": node.get_class(),
		"path": rel_path,
		"children": children,
	}


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

	var raw_value = node.get(property)
	_send_result(peer, request_id, {
		"path": _node_rel_path(node),
		"property": property,
		"value": _serialize_value(raw_value),
	})


func _handle_list_node_properties(peer: WebSocketPeer, request_id: Variant, params: Dictionary) -> void:
	var path: String = params.get("path", "")
	var exported_only: bool = bool(params.get("exported_only", false))
	var editable_only: bool = bool(params.get("editable_only", true))
	var relevant_only: bool = bool(params.get("relevant_only", true))
	var include_values: bool = bool(params.get("include_values", false))

	var node := _resolve_node(path)
	if node == null:
		_send_error(peer, request_id, -32001, "Node not found: %s" % path)
		return

	var by_name := {}
	for prop in node.get_property_list():
		if _should_include_property(prop, exported_only, editable_only, relevant_only):
			by_name[prop.name] = prop

	var properties: Array = []
	for prop_name in by_name:
		properties.append(_serialize_property_info(node, by_name[prop_name], include_values))

	properties.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"] < b["name"]
	)

	_send_result(peer, request_id, {
		"path": _node_rel_path(node),
		"type": node.get_class(),
		"filters": {
			"exported_only": exported_only,
			"editable_only": editable_only,
			"relevant_only": relevant_only,
			"include_values": include_values,
		},
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
		"auto_translate",
		"auto_translate_mode",
		"editor_description",
		"focus_behavior_recursive",
		"focus_next",
		"focus_previous",
		"global_position",
		"layout_direction",
		"light_mask",
		"localize_numeral_system",
		"multiplayer",
		"mouse_behavior_recursive",
		"name",
		"owner",
		"physics_interpolation_mode",
		"rotation_degrees",
		"scene_file_path",
		"shortcut_context",
		"tooltip_auto_translate_mode",
		"translation_context",
		"unique_name_in_owner",
		"visibility_layer",
		"y_sort_enabled",
		"z_as_relative",
		"oversampling_with_scale",
		"propagate_maximum_size",
		"show_behind_parent",
		"use_parent_material",
		"clip_children",
		"top_level",
		"texture_filter",
		"texture_repeat",
	]


func _serialize_property_info(obj: Object, prop: Dictionary, include_values: bool) -> Dictionary:
	var type_name := _variant_type_name(prop.type)
	var property_class: String = prop.get("class_name", "")
	if prop.type == TYPE_OBJECT and not property_class.is_empty():
		type_name = property_class

	var entry := {
		"name": prop.name,
		"type": type_name,
		"class_name": property_class,
		"hint": prop.hint,
		"hint_string": prop.get("hint_string", ""),
		"usage": _usage_labels(prop.usage),
	}
	if include_values:
		entry["value"] = _serialize_value(obj.get(prop.name))
	return entry


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
	var new_value = _deserialize_value(current, params["value"])
	node.set(property, new_value)

	_send_result(peer, request_id, {
		"path": _node_rel_path(node),
		"property": property,
		"value": _serialize_value(node.get(property)),
	})


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
		return node.name
	var rel_path := str(scene_root.get_path_to(node))
	if rel_path.is_empty():
		rel_path = node.name
	return rel_path


func _has_property(obj: Object, property_name: String) -> bool:
	for prop in obj.get_property_list():
		if prop.name == property_name:
			return true
	return false


func _serialize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			var v: Vector2 = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR2I:
			var v: Vector2i = value
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR3:
			var v: Vector3 = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_VECTOR3I:
			var v: Vector3i = value
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_COLOR:
			var c: Color = value
			return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}
		TYPE_ARRAY:
			var out: Array = []
			for item in value:
				out.append(_serialize_value(item))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for key in value:
				out[str(key)] = _serialize_value(value[key])
			return out
		TYPE_NODE_PATH:
			return str(value)
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Node:
				var scene_root := EditorInterface.get_edited_scene_root()
				if scene_root and scene_root.is_ancestor_of(value):
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
				return Vector3(
					float(value.get("x", 0)),
					float(value.get("y", 0)),
					float(value.get("z", 0))
				)
			return template
		TYPE_VECTOR3I:
			if typeof(value) == TYPE_DICTIONARY:
				return Vector3i(
					int(value.get("x", 0)),
					int(value.get("y", 0)),
					int(value.get("z", 0))
				)
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

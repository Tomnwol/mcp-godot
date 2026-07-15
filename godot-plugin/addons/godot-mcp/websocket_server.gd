@tool
extends Node

## Local WebSocket server that the godot-mcp Node process connects to.
## Uses TCPServer + WebSocketPeer (compatible with all Godot 4.x versions).
## Protocol: JSON messages { "id", "method", "params?" } → { "id", "result" } or { "id", "error" }.

const DEFAULT_PORT := 6505

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
				"godot_version": Engine.get_version_info(),
				"editor": true,
			})
		"get_scene_tree":
			var max_depth: int = int(params.get("max_depth", -1))
			_send_result(peer, request_id, _build_scene_tree(max_depth))
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


func _send_result(peer: WebSocketPeer, request_id: Variant, result: Variant) -> void:
	peer.send_text(JSON.stringify({"id": request_id, "result": result}))


func _send_error(peer: WebSocketPeer, request_id: Variant, code: int, message: String) -> void:
	peer.send_text(JSON.stringify({
		"id": request_id,
		"error": {"code": code, "message": message},
	}))

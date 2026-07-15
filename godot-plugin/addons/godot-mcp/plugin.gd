@tool
extends EditorPlugin

var _server_node: Node


func _enter_tree() -> void:
	_server_node = preload("res://addons/godot-mcp/websocket_server.gd").new()
	add_child(_server_node)


func _exit_tree() -> void:
	if _server_node:
		_server_node.queue_free()
		_server_node = null

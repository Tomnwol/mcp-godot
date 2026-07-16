@tool
extends Logger

## Captures engine print/error output for godot_log_get (Godot 4.5+).
## Thread-safe ring buffer — Logger callbacks may run off the main thread.

const CAP := 200

var _mutex := Mutex.new()
var _lines: Array = []  # Array of { "text": String, "level": String }


func _log_message(message: String, error: bool) -> void:
	var text := message.strip_edges()
	if text.is_empty():
		return
	_append(text, "error" if error else "info")


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array
) -> void:
	var level := "error"
	if error_type == ERROR_TYPE_WARNING:
		level = "warning"
	var text := rationale.strip_edges()
	if text.is_empty():
		text = code.strip_edges()
	if not file.is_empty():
		text = "%s:%d %s" % [file, line, text]
	_append(text, level)


func _append(text: String, level: String) -> void:
	_mutex.lock()
	_lines.append({"text": text, "level": level})
	while _lines.size() > CAP:
		_lines.pop_front()
	_mutex.unlock()


func snapshot(tail: int, level_filter: String) -> Array:
	_mutex.lock()
	var copy: Array = _lines.duplicate()
	_mutex.unlock()

	var filtered: Array = []
	for entry in copy:
		if level_filter != "all" and entry.get("level", "info") != level_filter:
			continue
		filtered.append(entry)

	if tail < filtered.size():
		return filtered.slice(filtered.size() - tail)
	return filtered


func clear() -> void:
	_mutex.lock()
	_lines.clear()
	_mutex.unlock()

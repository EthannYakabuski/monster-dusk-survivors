extends RefCounted
## Write a complete replacement before replacing the primary; retain a valid backup.

static func read(primary: String, backup: String) -> Dictionary:
	for path in [primary, backup]:
		if not FileAccess.file_exists(path): continue
		var value: Variant = decode(FileAccess.get_file_as_string(path))
		if value is Dictionary and value.get("schema", 0) == 1:
			return value
	return {}

static func write(primary: String, backup: String, value: Dictionary) -> bool:
	var temporary := primary + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if FileAccess.file_exists(primary):
		var previous := FileAccess.get_file_as_string(primary)
		var parsed: Variant = decode(previous)
		if parsed is Dictionary and parsed.get("schema", 0) == 1:
			var copy := FileAccess.open(backup, FileAccess.WRITE)
			if not copy: return false
			copy.store_string(previous)
			copy.flush()
			error = copy.get_error()
			copy.close()
			if error != OK: return false
	return DirAccess.rename_absolute(temporary, primary) == OK

static func decode(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null

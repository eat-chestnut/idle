extends RefCounted
class_name LocalSaveService

const LocalSaveDataScript = preload("res://client/scripts/local_save_data.gd")

const SAVE_PATH := "user://phase_one_local_save.json"


static func has_valid_save() -> bool:
	return bool(inspect_save().get("valid", false))


static func inspect_save() -> Dictionary:
	var loaded := load_save()
	if loaded.get("ok", false):
		return {
			"ok": true,
			"valid": true,
			"exists": true,
			"status": "ready",
			"data": loaded.get("data", {}),
			"path": loaded.get("path", SAVE_PATH),
		}

	return {
		"ok": false,
		"valid": false,
		"exists": str(loaded.get("kind", "")).strip_edges() != "missing",
		"status": str(loaded.get("kind", "missing")).strip_edges(),
		"message": str(loaded.get("message", "本地正式存档暂不可用。")),
		"path": loaded.get("path", SAVE_PATH),
		"error": loaded,
	}


static func load_or_create_default() -> Dictionary:
	var loaded := load_save()
	if loaded.get("ok", false):
		loaded["action"] = "loaded"
		return loaded

	var created := create_new_save()
	if created.get("ok", false):
		if str(loaded.get("kind", "")).strip_edges() == "missing":
			created["action"] = "created"
		else:
			created["action"] = "recreated"
			created["previous_error"] = loaded
	created["path"] = SAVE_PATH
	return created


static func create_new_save() -> Dictionary:
	return overwrite_save(LocalSaveDataScript.build_new_save(), "created")


static func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {
			"ok": false,
			"kind": "missing",
			"message": "本地正式存档不存在。",
			"path": SAVE_PATH,
		}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"kind": "io",
			"message": "本地正式存档无法打开。",
			"path": SAVE_PATH,
		}

	var raw_text := file.get_as_text()
	var json := JSON.new()
	var parse_error := json.parse(raw_text)
	if parse_error != OK:
		return {
			"ok": false,
			"kind": "invalid",
			"message": "本地正式存档 JSON 已损坏。",
			"path": SAVE_PATH,
			"parse_error": json.get_error_message(),
			"parse_line": json.get_error_line(),
		}

	var parsed: Variant = json.data
	if not LocalSaveDataScript.is_valid_save(parsed):
		return {
			"ok": false,
			"kind": "invalid",
			"message": "本地正式存档结构不完整。",
			"path": SAVE_PATH,
		}

	return {
		"ok": true,
		"data": LocalSaveDataScript.normalize_save(parsed),
		"path": SAVE_PATH,
	}


static func overwrite_save(save_payload: Dictionary, action: String = "saved") -> Dictionary:
	var normalized := LocalSaveDataScript.normalize_save(save_payload)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"kind": "io",
			"message": "本地正式存档无法写入。",
			"path": SAVE_PATH,
		}

	file.store_string(JSON.stringify(normalized, "  "))
	return {
		"ok": true,
		"data": normalized,
		"path": SAVE_PATH,
		"action": action,
	}

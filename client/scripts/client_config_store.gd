extends RefCounted
class_name ClientConfigStore

const CONFIG_PATH := "user://phase_one_client.cfg"
const CONFIG_SECTION := "phase_one_client"
const DEFAULTS := {
	"base_url": "http://127.0.0.1:8000",
	"bearer_token": "test-token-2001",
	"class_id": "class_jingang",
	"character_name": "联调角色",
	"character_id": "1001",
	"battle_character_id": "1001",
	"chapter_id": "",
	"stage_id": "stage_nanshan_001",
	"stage_difficulty_id": "stage_nanshan_001_normal",
	"recent_characters": [],
	"recent_chapter_ids": [],
	"recent_stage_ids": ["stage_nanshan_001"],
	"recent_stage_difficulty_ids": ["stage_nanshan_001_normal"],
}


static func load_config() -> Dictionary:
	var resolved := DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	var load_error := config.load(CONFIG_PATH)

	if load_error != OK:
		return resolved

	for key in [
		"base_url",
		"bearer_token",
		"class_id",
		"character_name",
		"character_id",
		"battle_character_id",
		"chapter_id",
		"stage_id",
		"stage_difficulty_id",
	]:
		resolved[key] = String(config.get_value(CONFIG_SECTION, key, DEFAULTS[key]))

	resolved["recent_characters"] = _normalize_recent_characters(
		config.get_value(CONFIG_SECTION, "recent_characters", DEFAULTS["recent_characters"])
	)
	resolved["recent_chapter_ids"] = _normalize_string_list(
		config.get_value(CONFIG_SECTION, "recent_chapter_ids", DEFAULTS["recent_chapter_ids"])
	)
	resolved["recent_stage_ids"] = _normalize_string_list(
		config.get_value(CONFIG_SECTION, "recent_stage_ids", DEFAULTS["recent_stage_ids"])
	)
	resolved["recent_stage_difficulty_ids"] = _normalize_string_list(
		config.get_value(
			CONFIG_SECTION,
			"recent_stage_difficulty_ids",
			DEFAULTS["recent_stage_difficulty_ids"]
		)
	)

	return resolved


static func save_config(values: Dictionary) -> int:
	var config := ConfigFile.new()

	for key in [
		"base_url",
		"bearer_token",
		"class_id",
		"character_name",
		"character_id",
		"battle_character_id",
		"chapter_id",
		"stage_id",
		"stage_difficulty_id",
	]:
		config.set_value(CONFIG_SECTION, key, String(values.get(key, DEFAULTS[key])))

	config.set_value(
		CONFIG_SECTION,
		"recent_characters",
		_normalize_recent_characters(values.get("recent_characters", DEFAULTS["recent_characters"]))
	)
	config.set_value(
		CONFIG_SECTION,
		"recent_chapter_ids",
		_normalize_string_list(values.get("recent_chapter_ids", DEFAULTS["recent_chapter_ids"]))
	)
	config.set_value(
		CONFIG_SECTION,
		"recent_stage_ids",
		_normalize_string_list(values.get("recent_stage_ids", DEFAULTS["recent_stage_ids"]))
	)
	config.set_value(
		CONFIG_SECTION,
		"recent_stage_difficulty_ids",
		_normalize_string_list(
			values.get("recent_stage_difficulty_ids", DEFAULTS["recent_stage_difficulty_ids"])
		)
	)

	return config.save(CONFIG_PATH)


static func normalize_id_string(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	if normalized.is_empty():
		return ""

	if typeof(value) == TYPE_INT:
		return str(int(value))

	if typeof(value) == TYPE_FLOAT:
		var rounded_from_float := int(round(float(value)))
		if is_equal_approx(float(value), float(rounded_from_float)):
			return str(rounded_from_float)
		return normalized

	if normalized.is_valid_int():
		return normalized

	if normalized.is_valid_float():
		var float_value := float(normalized)
		var rounded_from_string := int(round(float_value))
		if is_equal_approx(float_value, float(rounded_from_string)):
			return str(rounded_from_string)

	return normalized


static func upsert_recent_character(records: Array, character: Dictionary, max_items: int = 8) -> Array:
	var character_id := normalize_id_string(character.get("character_id", ""))
	if character_id.is_empty():
		return _normalize_recent_characters(records)

	var normalized_record := {
		"character_id": character_id,
		"character_name": str(character.get("character_name", "角色")),
		"class_id": str(character.get("class_id", "")),
		"class_name": str(character.get("class_name", character.get("class_id", ""))),
		"is_active": 1 if int(character.get("is_active", 0)) == 1 else 0,
	}

	var normalized_records := _normalize_recent_characters(records)
	var merged: Array = [normalized_record]

	for record in normalized_records:
		var entry = record if typeof(record) == TYPE_DICTIONARY else {}
		if normalize_id_string(entry.get("character_id", "")) == character_id:
			continue
		merged.append(entry)
		if merged.size() >= max_items:
			break

	return merged


static func upsert_recent_string(values: Array, raw_value: String, max_items: int = 8) -> Array:
	var normalized_value := raw_value.strip_edges()
	if normalized_value.is_empty():
		return _normalize_string_list(values)

	var merged: Array = [normalized_value]
	for item in _normalize_string_list(values):
		if str(item) == normalized_value:
			continue
		merged.append(str(item))
		if merged.size() >= max_items:
			break

	return merged


static func _normalize_recent_characters(value: Variant) -> Array:
	var normalized: Array = []
	if typeof(value) != TYPE_ARRAY:
		return normalized

	for raw_record in value:
		if typeof(raw_record) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = raw_record
		var character_id := normalize_id_string(record.get("character_id", ""))
		if character_id.is_empty():
			continue

		normalized.append({
			"character_id": character_id,
			"character_name": str(record.get("character_name", "角色")),
			"class_id": str(record.get("class_id", "")),
			"class_name": str(record.get("class_name", record.get("class_id", ""))),
			"is_active": 1 if int(record.get("is_active", 0)) == 1 else 0,
		})

	return normalized


static func _normalize_string_list(value: Variant) -> Array:
	var normalized: Array = []

	if typeof(value) == TYPE_STRING:
		var raw_string := str(value).strip_edges()
		if raw_string.is_empty():
			return normalized
		return [raw_string]

	if typeof(value) != TYPE_ARRAY:
		return normalized

	for item in value:
		var normalized_item := str(item).strip_edges()
		if normalized_item.is_empty():
			continue
		if normalized.has(normalized_item):
			continue
		normalized.append(normalized_item)

	return normalized

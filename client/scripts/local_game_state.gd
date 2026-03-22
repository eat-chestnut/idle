extends RefCounted
class_name LocalGameState

const DEFAULT_STATE := {
	"config": {
		"base_url": "",
		"bearer_token": "",
		"local_app_version": "dev-local",
		"local_data_version": "embedded-dev",
		"local_resource_version": "not_declared",
	},
	"startup_snapshot": {},
	"character_list": {},
	"character_detail": {},
	"inventory": {},
	"slots": {},
	"chapters": {},
	"stages": {},
	"difficulties": {},
	"reward_status": {},
	"prepare_result": {},
	"settle_result": {},
	"character_equipment_feedback": {},
	"prepared_monster_ids": [],
	"recent_battle_context_ids": [],
	"selections": {
		"character_id": "",
		"battle_character_id": "",
		"equipment_character_id": "",
		"chapter_id": "",
		"stage_id": "",
		"stage_difficulty_id": "",
		"battle_context_id": "",
	},
}

var _state: Dictionary = DEFAULT_STATE.duplicate(true)


func apply_saved_config(saved_config: Dictionary) -> void:
	var runtime_config := _dictionary_or_empty(saved_config.get("runtime_config", {}))
	var merged_config: Dictionary = _dictionary_or_empty(DEFAULT_STATE.get("config", {})).duplicate(true)

	for key in runtime_config.keys():
		merged_config[key] = runtime_config[key]

	merged_config["base_url"] = str(saved_config.get("base_url", merged_config.get("base_url", ""))).strip_edges()
	merged_config["bearer_token"] = str(saved_config.get("bearer_token", merged_config.get("bearer_token", ""))).strip_edges()
	merged_config["local_app_version"] = str(saved_config.get("local_app_version", merged_config.get("local_app_version", "dev-local"))).strip_edges()
	merged_config["local_data_version"] = str(saved_config.get("local_data_version", merged_config.get("local_data_version", "embedded-dev"))).strip_edges()
	merged_config["local_resource_version"] = str(saved_config.get("local_resource_version", merged_config.get("local_resource_version", "not_declared"))).strip_edges()
	_state["config"] = merged_config

	_state["startup_snapshot"] = _dictionary_or_empty(saved_config.get("startup_snapshot", {}))

	_state["selections"] = {
		"character_id": str(saved_config.get("character_id", "")).strip_edges(),
		"battle_character_id": str(saved_config.get("battle_character_id", "")).strip_edges(),
		"equipment_character_id": str(saved_config.get("character_id", "")).strip_edges(),
		"chapter_id": str(saved_config.get("chapter_id", "")).strip_edges(),
		"stage_id": str(saved_config.get("stage_id", "")).strip_edges(),
		"stage_difficulty_id": str(saved_config.get("stage_difficulty_id", "")).strip_edges(),
		"battle_context_id": "",
	}


func replace_state(snapshot: Dictionary) -> void:
	for key in snapshot.keys():
		if not DEFAULT_STATE.has(key):
			continue
		_state[key] = _normalize_state_value(key, snapshot.get(key))


func get_dictionary_state(key: String) -> Dictionary:
	return _dictionary_or_empty(_state.get(key, {})).duplicate(true)


func get_array_state(key: String) -> Array:
	return _array_or_empty(_state.get(key, [])).duplicate(true)


func get_packed_string_array_state(key: String) -> PackedStringArray:
	var value = _state.get(key, PackedStringArray())
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		return PackedStringArray(value)
	if typeof(value) == TYPE_ARRAY:
		var normalized := PackedStringArray()
		for item in value:
			var text := str(item).strip_edges()
			if text.is_empty():
				continue
			normalized.append(text)
		return normalized
	return PackedStringArray()


func get_selection(selection_key: String) -> String:
	var selections := _dictionary_or_empty(_state.get("selections", {}))
	return str(selections.get(selection_key, "")).strip_edges()


func export_saved_config(base: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	var config := get_dictionary_state("config")
	for key in config.keys():
		merged[key] = config[key]
	merged["runtime_config"] = config
	merged["startup_snapshot"] = get_dictionary_state("startup_snapshot")

	var selections := get_dictionary_state("selections")
	merged["character_id"] = str(selections.get("character_id", merged.get("character_id", ""))).strip_edges()
	merged["battle_character_id"] = str(selections.get("battle_character_id", merged.get("battle_character_id", ""))).strip_edges()
	merged["chapter_id"] = str(selections.get("chapter_id", merged.get("chapter_id", ""))).strip_edges()
	merged["stage_id"] = str(selections.get("stage_id", merged.get("stage_id", ""))).strip_edges()
	merged["stage_difficulty_id"] = str(selections.get("stage_difficulty_id", merged.get("stage_difficulty_id", ""))).strip_edges()
	return merged


func _normalize_state_value(key: String, value: Variant) -> Variant:
	match key:
		"config", "startup_snapshot", "character_list", "character_detail", "inventory", "slots", "chapters", "stages", "difficulties", "reward_status", "prepare_result", "settle_result", "character_equipment_feedback", "selections":
			return _dictionary_or_empty(value).duplicate(true)
		"recent_battle_context_ids":
			return _array_or_empty(value).duplicate(true)
		"prepared_monster_ids":
			return get_packed_string_array_state_from_value(value)
		_:
			return value


func get_packed_string_array_state_from_value(value: Variant) -> PackedStringArray:
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		return PackedStringArray(value)

	var normalized := PackedStringArray()
	for item in _array_or_empty(value):
		var text := str(item).strip_edges()
		if text.is_empty():
			continue
		normalized.append(text)
	return normalized


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _array_or_empty(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []

extends RefCounted
class_name LocalGameState

const LocalSaveDataScript = preload("res://client/scripts/local_save_data.gd")

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
	"ui_focus": {
		"active_page_key": "config",
		"inventory_section": "all",
		"inventory_equipment_instance_id": "",
		"equipment_target_slot_key": "",
		"equipment_focus_instance_id": "",
	},
	"prepared_monster_ids": [],
	"recent_battle_context_ids": [],
	"local_save_meta": {},
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


func replace_state(snapshot: Dictionary) -> void:
	for key in snapshot.keys():
		if not DEFAULT_STATE.has(key):
			continue
		_state[key] = _normalize_state_value(key, snapshot.get(key))


func update_dictionary_state(key: String, patch: Dictionary) -> void:
	if not DEFAULT_STATE.has(key):
		return
	if typeof(DEFAULT_STATE.get(key, null)) != TYPE_DICTIONARY:
		return

	var merged := get_dictionary_state(key)
	for patch_key in patch.keys():
		merged[patch_key] = patch[patch_key]
	_state[key] = _normalize_state_value(key, merged)


func set_selection(selection_key: String, value: Variant) -> void:
	set_selections({selection_key: value})


func set_selections(selection_patch: Dictionary) -> void:
	update_dictionary_state("selections", selection_patch)


func update_ui_focus(focus_patch: Dictionary) -> void:
	update_dictionary_state("ui_focus", focus_patch)


func set_active_page_key(page_key: String) -> void:
	update_ui_focus({"active_page_key": page_key.strip_edges()})


func get_active_page_key(fallback: String = "config") -> String:
	var active_page_key := str(get_dictionary_state("ui_focus").get("active_page_key", fallback)).strip_edges()
	if active_page_key.is_empty():
		return fallback.strip_edges()
	return active_page_key


func apply_local_save(save_payload: Dictionary) -> void:
	var runtime_snapshot := LocalSaveDataScript.extract_runtime_snapshot(save_payload)
	replace_state(runtime_snapshot)
	set_local_save_meta(LocalSaveDataScript.extract_save_meta(save_payload))


func set_local_save_meta(meta: Dictionary) -> void:
	_state["local_save_meta"] = _dictionary_or_empty(meta).duplicate(true)


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


func get_selection_or(selection_key: String, fallback: String = "") -> String:
	var selected := get_selection(selection_key)
	if not selected.is_empty():
		return selected
	return fallback.strip_edges()


func get_config_value(config_key: String, fallback: Variant = "") -> Variant:
	var config := _dictionary_or_empty(_state.get("config", {}))
	return config.get(config_key, fallback)


func has_startup_snapshot() -> bool:
	return not get_dictionary_state("startup_snapshot").is_empty()


func is_startup_ready() -> bool:
	if not has_startup_snapshot():
		return false
	return bool(get_dictionary_state("startup_snapshot").get("ready", false))


func export_local_save(base_save: Dictionary = {}, save_preferences: Dictionary = {}) -> Dictionary:
	return LocalSaveDataScript.build_from_runtime_snapshot(
		_build_persistent_runtime_snapshot(),
		save_preferences,
		base_save
	)


func export_saved_config(base: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	var config := get_dictionary_state("config")
	for key in config.keys():
		merged[key] = config[key]
	merged["runtime_config"] = config
	merged["startup_snapshot"] = get_dictionary_state("startup_snapshot")
	return merged


func _build_persistent_runtime_snapshot() -> Dictionary:
	return {
		"character_list": get_dictionary_state("character_list"),
		"character_detail": get_dictionary_state("character_detail"),
		"inventory": get_dictionary_state("inventory"),
		"slots": get_dictionary_state("slots"),
		"chapters": get_dictionary_state("chapters"),
		"stages": get_dictionary_state("stages"),
		"difficulties": get_dictionary_state("difficulties"),
		"reward_status": get_dictionary_state("reward_status"),
		"prepare_result": get_dictionary_state("prepare_result"),
		"settle_result": get_dictionary_state("settle_result"),
		"character_equipment_feedback": get_dictionary_state("character_equipment_feedback"),
		"ui_focus": get_dictionary_state("ui_focus"),
		"prepared_monster_ids": get_packed_string_array_state("prepared_monster_ids"),
		"recent_battle_context_ids": get_array_state("recent_battle_context_ids"),
		"selections": get_dictionary_state("selections"),
	}


func _normalize_state_value(key: String, value: Variant) -> Variant:
	match key:
		"config", "startup_snapshot", "character_list", "character_detail", "inventory", "slots", "chapters", "stages", "difficulties", "reward_status", "prepare_result", "settle_result", "character_equipment_feedback", "ui_focus", "local_save_meta", "selections":
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

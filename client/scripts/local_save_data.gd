extends RefCounted
class_name LocalSaveData

const SAVE_SCHEMA_VERSION := 1
const SAVE_KIND := "single_player_local_save"
const DEFAULT_SAVE_SLOT := "primary"
const DEFAULT_CHAPTER_ID := "chapter_nanshan_001"
const DEFAULT_CHAPTER_NAME := "南山一经"
const DEFAULT_STAGE_ID := "stage_nanshan_001"
const DEFAULT_STAGE_NAME := "招摇山"
const DEFAULT_STAGE_DIFFICULTY_ID := "stage_nanshan_001_normal"
const DEFAULT_DIFFICULTY_KEY := "normal"
const DEFAULT_DIFFICULTY_NAME := "普通"
const DEFAULT_RECOMMENDED_POWER := 100


static func build_new_save() -> Dictionary:
	var timestamp := _timestamp_now()
	return normalize_save({
		"schema_version": SAVE_SCHEMA_VERSION,
		"save_kind": SAVE_KIND,
		"save_slot": DEFAULT_SAVE_SLOT,
		"created_at": timestamp,
		"updated_at": timestamp,
		"persistent": _default_persistent_payload(),
	})


static func normalize_save(raw_value: Variant) -> Dictionary:
	var raw := _dictionary_or_empty(raw_value)
	var normalized := {
		"schema_version": SAVE_SCHEMA_VERSION,
		"save_kind": SAVE_KIND,
		"save_slot": DEFAULT_SAVE_SLOT,
		"created_at": str(raw.get("created_at", "")).strip_edges(),
		"updated_at": str(raw.get("updated_at", "")).strip_edges(),
		"persistent": _default_persistent_payload(),
	}

	if normalized["created_at"].is_empty():
		normalized["created_at"] = _timestamp_now()
	if normalized["updated_at"].is_empty():
		normalized["updated_at"] = normalized["created_at"]

	normalized["schema_version"] = maxi(int(raw.get("schema_version", SAVE_SCHEMA_VERSION)), 1)
	normalized["save_kind"] = str(raw.get("save_kind", SAVE_KIND)).strip_edges()
	if normalized["save_kind"].is_empty():
		normalized["save_kind"] = SAVE_KIND

	normalized["save_slot"] = str(raw.get("save_slot", DEFAULT_SAVE_SLOT)).strip_edges()
	if normalized["save_slot"].is_empty():
		normalized["save_slot"] = DEFAULT_SAVE_SLOT

	var persistent := _dictionary_or_empty(raw.get("persistent", {}))
	normalized["persistent"] = {
		"character_state": _normalize_character_state(_dictionary_or_empty(persistent.get("character_state", {}))),
		"route_state": _normalize_route_state(_dictionary_or_empty(persistent.get("route_state", {}))),
		"inventory_state": _normalize_inventory_state(_dictionary_or_empty(persistent.get("inventory_state", {}))),
		"equipment_state": _normalize_equipment_state(_dictionary_or_empty(persistent.get("equipment_state", {}))),
		"growth_state": _normalize_growth_state(_dictionary_or_empty(persistent.get("growth_state", {}))),
	}

	return normalized


static func is_valid_save(raw_value: Variant) -> bool:
	if typeof(raw_value) != TYPE_DICTIONARY:
		return false

	var raw: Dictionary = raw_value
	return int(raw.get("schema_version", 0)) >= 1 and typeof(raw.get("persistent", null)) == TYPE_DICTIONARY


static func build_from_runtime_snapshot(
	runtime_snapshot: Dictionary,
	save_preferences: Dictionary = {},
	base_save: Dictionary = {}
) -> Dictionary:
	var normalized := normalize_save(base_save if not base_save.is_empty() else build_new_save())
	var persistent := _dictionary_or_empty(normalized.get("persistent", {}))
	var character_state := _dictionary_or_empty(persistent.get("character_state", {}))
	var route_state := _dictionary_or_empty(persistent.get("route_state", {}))
	var inventory_state := _dictionary_or_empty(persistent.get("inventory_state", {}))
	var equipment_state := _dictionary_or_empty(persistent.get("equipment_state", {}))
	var growth_state := _dictionary_or_empty(persistent.get("growth_state", {}))
	var selections := _dictionary_or_empty(runtime_snapshot.get("selections", {}))
	var ui_focus := _dictionary_or_empty(runtime_snapshot.get("ui_focus", {}))

	character_state["character_list"] = _dictionary_or_empty(runtime_snapshot.get("character_list", {})).duplicate(true)
	character_state["character_detail"] = _dictionary_or_empty(runtime_snapshot.get("character_detail", {})).duplicate(true)
	character_state["selected_character_id"] = _normalize_id_string(
		save_preferences.get("character_id", selections.get("character_id", character_state.get("selected_character_id", "")))
	)
	character_state["battle_character_id"] = _normalize_id_string(
		save_preferences.get("battle_character_id", selections.get("battle_character_id", character_state.get("battle_character_id", "")))
	)
	character_state["recent_characters"] = _normalize_recent_characters(
		save_preferences.get("recent_characters", character_state.get("recent_characters", []))
	)

	route_state["chapter_id"] = str(
		save_preferences.get("chapter_id", selections.get("chapter_id", route_state.get("chapter_id", DEFAULT_CHAPTER_ID)))
	).strip_edges()
	route_state["stage_id"] = str(
		save_preferences.get("stage_id", selections.get("stage_id", route_state.get("stage_id", DEFAULT_STAGE_ID)))
	).strip_edges()
	route_state["stage_difficulty_id"] = str(
		save_preferences.get(
			"stage_difficulty_id",
			selections.get("stage_difficulty_id", route_state.get("stage_difficulty_id", DEFAULT_STAGE_DIFFICULTY_ID))
		)
	).strip_edges()
	route_state["chapters"] = _dictionary_or_empty(runtime_snapshot.get("chapters", {})).duplicate(true)
	route_state["stages"] = _dictionary_or_empty(runtime_snapshot.get("stages", {})).duplicate(true)
	route_state["difficulties"] = _dictionary_or_empty(runtime_snapshot.get("difficulties", {})).duplicate(true)
	route_state["reward_status"] = _dictionary_or_empty(runtime_snapshot.get("reward_status", {})).duplicate(true)
	route_state["recent_chapter_ids"] = _normalize_string_list(
		save_preferences.get("recent_chapter_ids", route_state.get("recent_chapter_ids", []))
	)
	route_state["recent_stage_ids"] = _normalize_string_list(
		save_preferences.get("recent_stage_ids", route_state.get("recent_stage_ids", []))
	)
	route_state["recent_stage_difficulty_ids"] = _normalize_string_list(
		save_preferences.get("recent_stage_difficulty_ids", route_state.get("recent_stage_difficulty_ids", []))
	)

	inventory_state["inventory"] = _normalize_inventory_payload(
		_dictionary_or_empty(runtime_snapshot.get("inventory", {}))
	)
	inventory_state["focus_section"] = str(
		ui_focus.get("inventory_section", inventory_state.get("focus_section", "all"))
	).strip_edges()
	inventory_state["focus_equipment_instance_id"] = _normalize_id_string(
		ui_focus.get(
			"inventory_equipment_instance_id",
			inventory_state.get("focus_equipment_instance_id", "")
		)
	)

	equipment_state["slots"] = _dictionary_or_empty(runtime_snapshot.get("slots", {})).duplicate(true)
	equipment_state["character_equipment_feedback"] = _dictionary_or_empty(
		runtime_snapshot.get("character_equipment_feedback", {})
	).duplicate(true)
	equipment_state["equipment_character_id"] = _normalize_id_string(
		save_preferences.get(
			"equipment_character_id",
			selections.get("equipment_character_id", equipment_state.get("equipment_character_id", ""))
		)
	)
	equipment_state["focus_slot_key"] = str(
		ui_focus.get("equipment_target_slot_key", equipment_state.get("focus_slot_key", ""))
	).strip_edges()
	equipment_state["focus_equipment_instance_id"] = _normalize_id_string(
		ui_focus.get(
			"equipment_focus_instance_id",
			equipment_state.get("focus_equipment_instance_id", "")
		)
	)

	growth_state["prepare_result"] = _dictionary_or_empty(runtime_snapshot.get("prepare_result", {})).duplicate(true)
	growth_state["settle_result"] = _dictionary_or_empty(runtime_snapshot.get("settle_result", {})).duplicate(true)
	growth_state["prepared_monster_ids"] = _normalize_string_list(
		runtime_snapshot.get("prepared_monster_ids", growth_state.get("prepared_monster_ids", []))
	)
	growth_state["recent_battle_context_ids"] = _normalize_string_list(
		runtime_snapshot.get("recent_battle_context_ids", growth_state.get("recent_battle_context_ids", []))
	)
	growth_state["battle_context_id"] = str(
		save_preferences.get(
			"battle_context_id",
			selections.get("battle_context_id", growth_state.get("battle_context_id", ""))
		)
	).strip_edges()

	normalized["updated_at"] = _timestamp_now()
	normalized["persistent"] = {
		"character_state": character_state,
		"route_state": route_state,
		"inventory_state": inventory_state,
		"equipment_state": equipment_state,
		"growth_state": growth_state,
	}
	return normalize_save(normalized)


static func extract_runtime_snapshot(save_payload: Dictionary) -> Dictionary:
	var normalized := normalize_save(save_payload)
	var persistent := _dictionary_or_empty(normalized.get("persistent", {}))
	var character_state := _dictionary_or_empty(persistent.get("character_state", {}))
	var route_state := _dictionary_or_empty(persistent.get("route_state", {}))
	var inventory_state := _dictionary_or_empty(persistent.get("inventory_state", {}))
	var equipment_state := _dictionary_or_empty(persistent.get("equipment_state", {}))
	var growth_state := _dictionary_or_empty(persistent.get("growth_state", {}))

	return {
		"character_list": _dictionary_or_empty(character_state.get("character_list", {})).duplicate(true),
		"character_detail": _dictionary_or_empty(character_state.get("character_detail", {})).duplicate(true),
		"inventory": _dictionary_or_empty(inventory_state.get("inventory", {})).duplicate(true),
		"slots": _dictionary_or_empty(equipment_state.get("slots", {})).duplicate(true),
		"chapters": _dictionary_or_empty(route_state.get("chapters", {})).duplicate(true),
		"stages": _dictionary_or_empty(route_state.get("stages", {})).duplicate(true),
		"difficulties": _dictionary_or_empty(route_state.get("difficulties", {})).duplicate(true),
		"reward_status": _dictionary_or_empty(route_state.get("reward_status", {})).duplicate(true),
		"prepare_result": _dictionary_or_empty(growth_state.get("prepare_result", {})).duplicate(true),
		"settle_result": _dictionary_or_empty(growth_state.get("settle_result", {})).duplicate(true),
		"character_equipment_feedback": _dictionary_or_empty(
			equipment_state.get("character_equipment_feedback", {})
		).duplicate(true),
		"ui_focus": {
			"inventory_section": str(inventory_state.get("focus_section", "all")).strip_edges(),
			"inventory_equipment_instance_id": _normalize_id_string(
				inventory_state.get("focus_equipment_instance_id", "")
			),
			"equipment_target_slot_key": str(equipment_state.get("focus_slot_key", "")).strip_edges(),
			"equipment_focus_instance_id": _normalize_id_string(
				equipment_state.get("focus_equipment_instance_id", "")
			),
		},
		"prepared_monster_ids": _normalize_string_list(growth_state.get("prepared_monster_ids", [])),
		"recent_battle_context_ids": _normalize_string_list(growth_state.get("recent_battle_context_ids", [])),
		"selections": {
			"character_id": _normalize_id_string(character_state.get("selected_character_id", "")),
			"battle_character_id": _normalize_id_string(character_state.get("battle_character_id", "")),
			"equipment_character_id": _normalize_id_string(equipment_state.get("equipment_character_id", "")),
			"chapter_id": str(route_state.get("chapter_id", DEFAULT_CHAPTER_ID)).strip_edges(),
			"stage_id": str(route_state.get("stage_id", DEFAULT_STAGE_ID)).strip_edges(),
			"stage_difficulty_id": str(route_state.get("stage_difficulty_id", DEFAULT_STAGE_DIFFICULTY_ID)).strip_edges(),
			"battle_context_id": str(growth_state.get("battle_context_id", "")).strip_edges(),
		},
	}


static func extract_save_preferences(save_payload: Dictionary) -> Dictionary:
	var normalized := normalize_save(save_payload)
	var persistent := _dictionary_or_empty(normalized.get("persistent", {}))
	var character_state := _dictionary_or_empty(persistent.get("character_state", {}))
	var route_state := _dictionary_or_empty(persistent.get("route_state", {}))
	var equipment_state := _dictionary_or_empty(persistent.get("equipment_state", {}))
	var growth_state := _dictionary_or_empty(persistent.get("growth_state", {}))

	return {
		"character_id": _normalize_id_string(character_state.get("selected_character_id", "")),
		"battle_character_id": _normalize_id_string(character_state.get("battle_character_id", "")),
		"equipment_character_id": _normalize_id_string(equipment_state.get("equipment_character_id", "")),
		"chapter_id": str(route_state.get("chapter_id", DEFAULT_CHAPTER_ID)).strip_edges(),
		"stage_id": str(route_state.get("stage_id", DEFAULT_STAGE_ID)).strip_edges(),
		"stage_difficulty_id": str(route_state.get("stage_difficulty_id", DEFAULT_STAGE_DIFFICULTY_ID)).strip_edges(),
		"battle_context_id": str(growth_state.get("battle_context_id", "")).strip_edges(),
		"recent_characters": _normalize_recent_characters(character_state.get("recent_characters", [])),
		"recent_chapter_ids": _normalize_string_list(route_state.get("recent_chapter_ids", [])),
		"recent_stage_ids": _normalize_string_list(route_state.get("recent_stage_ids", [])),
		"recent_stage_difficulty_ids": _normalize_string_list(route_state.get("recent_stage_difficulty_ids", [])),
	}


static func extract_save_meta(save_payload: Dictionary) -> Dictionary:
	var normalized := normalize_save(save_payload)
	var persistent := _dictionary_or_empty(normalized.get("persistent", {}))
	var character_state := _dictionary_or_empty(persistent.get("character_state", {}))
	var route_state := _dictionary_or_empty(persistent.get("route_state", {}))
	var growth_state := _dictionary_or_empty(persistent.get("growth_state", {}))
	return {
		"has_save": true,
		"schema_version": int(normalized.get("schema_version", SAVE_SCHEMA_VERSION)),
		"save_kind": str(normalized.get("save_kind", SAVE_KIND)).strip_edges(),
		"save_slot": str(normalized.get("save_slot", DEFAULT_SAVE_SLOT)).strip_edges(),
		"created_at": str(normalized.get("created_at", "")).strip_edges(),
		"updated_at": str(normalized.get("updated_at", "")).strip_edges(),
		"character_count": _array_or_empty(_dictionary_or_empty(character_state.get("character_list", {})).get("characters", [])).size(),
		"selected_character_id": _normalize_id_string(character_state.get("selected_character_id", "")),
		"battle_character_id": _normalize_id_string(character_state.get("battle_character_id", "")),
		"chapter_id": str(route_state.get("chapter_id", DEFAULT_CHAPTER_ID)).strip_edges(),
		"stage_id": str(route_state.get("stage_id", DEFAULT_STAGE_ID)).strip_edges(),
		"stage_difficulty_id": str(route_state.get("stage_difficulty_id", DEFAULT_STAGE_DIFFICULTY_ID)).strip_edges(),
		"has_prepare_result": not _dictionary_or_empty(growth_state.get("prepare_result", {})).is_empty(),
		"has_settle_result": not _dictionary_or_empty(growth_state.get("settle_result", {})).is_empty(),
		"recent_battle_context_count": _array_or_empty(growth_state.get("recent_battle_context_ids", [])).size(),
	}


static func _default_persistent_payload() -> Dictionary:
	return {
		"character_state": {
			"character_list": {"characters": []},
			"character_detail": {},
			"selected_character_id": "",
			"battle_character_id": "",
			"recent_characters": [],
		},
		"route_state": {
			"chapter_id": DEFAULT_CHAPTER_ID,
			"stage_id": DEFAULT_STAGE_ID,
			"stage_difficulty_id": DEFAULT_STAGE_DIFFICULTY_ID,
			"chapters": _default_chapters_payload(),
			"stages": _default_stages_payload(),
			"difficulties": _default_difficulties_payload(),
			"reward_status": _default_reward_status_payload(),
			"recent_chapter_ids": [DEFAULT_CHAPTER_ID],
			"recent_stage_ids": [DEFAULT_STAGE_ID],
			"recent_stage_difficulty_ids": [DEFAULT_STAGE_DIFFICULTY_ID],
		},
		"inventory_state": {
			"inventory": _default_inventory_payload(),
			"focus_section": "all",
			"focus_equipment_instance_id": "",
		},
		"equipment_state": {
			"slots": {},
			"character_equipment_feedback": {},
			"equipment_character_id": "",
			"focus_slot_key": "",
			"focus_equipment_instance_id": "",
		},
		"growth_state": {
			"prepare_result": {},
			"settle_result": {},
			"prepared_monster_ids": [],
			"recent_battle_context_ids": [],
			"battle_context_id": "",
		},
	}


static func _default_chapters_payload() -> Dictionary:
	return {
		"chapters": [
			{
				"chapter_id": DEFAULT_CHAPTER_ID,
				"chapter_name": DEFAULT_CHAPTER_NAME,
				"sort_order": 1,
			},
		],
	}


static func _default_stages_payload() -> Dictionary:
	return {
		"chapter_id": DEFAULT_CHAPTER_ID,
		"stages": [
			{
				"stage_id": DEFAULT_STAGE_ID,
				"chapter_id": DEFAULT_CHAPTER_ID,
				"stage_name": DEFAULT_STAGE_NAME,
				"stage_order": 1,
			},
			{
				"stage_id": "stage_nanshan_002",
				"chapter_id": DEFAULT_CHAPTER_ID,
				"stage_name": "堂庭山",
				"stage_order": 2,
			},
		],
	}


static func _default_difficulties_payload() -> Dictionary:
	return {
		"stage_id": DEFAULT_STAGE_ID,
		"difficulties": [
			{
				"stage_difficulty_id": DEFAULT_STAGE_DIFFICULTY_ID,
				"stage_id": DEFAULT_STAGE_ID,
				"difficulty_key": DEFAULT_DIFFICULTY_KEY,
				"difficulty_name": DEFAULT_DIFFICULTY_NAME,
				"recommended_power": DEFAULT_RECOMMENDED_POWER,
				"difficulty_order": 1,
			},
			{
				"stage_difficulty_id": "stage_nanshan_001_hard",
				"stage_id": DEFAULT_STAGE_ID,
				"difficulty_key": "hard",
				"difficulty_name": "困难",
				"recommended_power": 180,
				"difficulty_order": 2,
			},
		],
	}


static func _default_reward_status_payload() -> Dictionary:
	return {
		"source_type": "first_clear",
		"source_id": DEFAULT_STAGE_DIFFICULTY_ID,
		"has_reward": 1,
		"has_granted": 0,
		"grant_status": "pending",
	}


static func _default_inventory_payload() -> Dictionary:
	return {
		"tab": "all",
		"stack_items": [],
		"equipment_items": [],
		"pagination": {
			"page": 1,
			"page_size": 20,
			"total": 0,
			"total_pages": 0,
		},
	}


static func _normalize_character_state(raw: Dictionary) -> Dictionary:
	var defaults := _dictionary_or_empty(_default_persistent_payload().get("character_state", {}))
	return {
		"character_list": _dictionary_or_empty(raw.get("character_list", defaults.get("character_list", {}))).duplicate(true),
		"character_detail": _dictionary_or_empty(raw.get("character_detail", defaults.get("character_detail", {}))).duplicate(true),
		"selected_character_id": _normalize_id_string(raw.get("selected_character_id", defaults.get("selected_character_id", ""))),
		"battle_character_id": _normalize_id_string(raw.get("battle_character_id", defaults.get("battle_character_id", ""))),
		"recent_characters": _normalize_recent_characters(raw.get("recent_characters", defaults.get("recent_characters", []))),
	}


static func _normalize_route_state(raw: Dictionary) -> Dictionary:
	var defaults := _dictionary_or_empty(_default_persistent_payload().get("route_state", {}))
	return {
		"chapter_id": str(raw.get("chapter_id", defaults.get("chapter_id", DEFAULT_CHAPTER_ID))).strip_edges(),
		"stage_id": str(raw.get("stage_id", defaults.get("stage_id", DEFAULT_STAGE_ID))).strip_edges(),
		"stage_difficulty_id": str(
			raw.get("stage_difficulty_id", defaults.get("stage_difficulty_id", DEFAULT_STAGE_DIFFICULTY_ID))
		).strip_edges(),
		"chapters": _dictionary_or_empty(raw.get("chapters", defaults.get("chapters", {}))).duplicate(true),
		"stages": _dictionary_or_empty(raw.get("stages", defaults.get("stages", {}))).duplicate(true),
		"difficulties": _dictionary_or_empty(raw.get("difficulties", defaults.get("difficulties", {}))).duplicate(true),
		"reward_status": _dictionary_or_empty(raw.get("reward_status", defaults.get("reward_status", {}))).duplicate(true),
		"recent_chapter_ids": _normalize_string_list(raw.get("recent_chapter_ids", defaults.get("recent_chapter_ids", []))),
		"recent_stage_ids": _normalize_string_list(raw.get("recent_stage_ids", defaults.get("recent_stage_ids", []))),
		"recent_stage_difficulty_ids": _normalize_string_list(
			raw.get("recent_stage_difficulty_ids", defaults.get("recent_stage_difficulty_ids", []))
		),
	}


static func _normalize_inventory_state(raw: Dictionary) -> Dictionary:
	var defaults := _dictionary_or_empty(_default_persistent_payload().get("inventory_state", {}))
	return {
		"inventory": _normalize_inventory_payload(_dictionary_or_empty(raw.get("inventory", defaults.get("inventory", {})))),
		"focus_section": str(raw.get("focus_section", defaults.get("focus_section", "all"))).strip_edges(),
		"focus_equipment_instance_id": _normalize_id_string(
			raw.get("focus_equipment_instance_id", defaults.get("focus_equipment_instance_id", ""))
		),
	}


static func _normalize_equipment_state(raw: Dictionary) -> Dictionary:
	var defaults := _dictionary_or_empty(_default_persistent_payload().get("equipment_state", {}))
	return {
		"slots": _dictionary_or_empty(raw.get("slots", defaults.get("slots", {}))).duplicate(true),
		"character_equipment_feedback": _dictionary_or_empty(
			raw.get("character_equipment_feedback", defaults.get("character_equipment_feedback", {}))
		).duplicate(true),
		"equipment_character_id": _normalize_id_string(
			raw.get("equipment_character_id", defaults.get("equipment_character_id", ""))
		),
		"focus_slot_key": str(raw.get("focus_slot_key", defaults.get("focus_slot_key", ""))).strip_edges(),
		"focus_equipment_instance_id": _normalize_id_string(
			raw.get("focus_equipment_instance_id", defaults.get("focus_equipment_instance_id", ""))
		),
	}


static func _normalize_growth_state(raw: Dictionary) -> Dictionary:
	var defaults := _dictionary_or_empty(_default_persistent_payload().get("growth_state", {}))
	return {
		"prepare_result": _dictionary_or_empty(raw.get("prepare_result", defaults.get("prepare_result", {}))).duplicate(true),
		"settle_result": _dictionary_or_empty(raw.get("settle_result", defaults.get("settle_result", {}))).duplicate(true),
		"prepared_monster_ids": _normalize_string_list(raw.get("prepared_monster_ids", defaults.get("prepared_monster_ids", []))),
		"recent_battle_context_ids": _normalize_string_list(
			raw.get("recent_battle_context_ids", defaults.get("recent_battle_context_ids", []))
		),
		"battle_context_id": str(raw.get("battle_context_id", defaults.get("battle_context_id", ""))).strip_edges(),
	}


static func _normalize_inventory_payload(raw: Dictionary) -> Dictionary:
	var defaults := _default_inventory_payload()
	var pagination := _dictionary_or_empty(raw.get("pagination", defaults.get("pagination", {})))
	return {
		"tab": str(raw.get("tab", defaults.get("tab", "all"))).strip_edges(),
		"stack_items": _array_or_empty(raw.get("stack_items", defaults.get("stack_items", []))).duplicate(true),
		"equipment_items": _array_or_empty(raw.get("equipment_items", defaults.get("equipment_items", []))).duplicate(true),
		"pagination": {
			"page": maxi(int(pagination.get("page", defaults["pagination"]["page"])), 1),
			"page_size": maxi(int(pagination.get("page_size", defaults["pagination"]["page_size"])), 1),
			"total": maxi(int(pagination.get("total", defaults["pagination"]["total"])), 0),
			"total_pages": maxi(int(pagination.get("total_pages", defaults["pagination"]["total_pages"])), 0),
		},
	}


static func _normalize_recent_characters(value: Variant) -> Array:
	var normalized: Array = []
	for raw_record in _array_or_empty(value):
		if typeof(raw_record) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = raw_record
		var character_id := _normalize_id_string(record.get("character_id", ""))
		if character_id.is_empty():
			continue
		normalized.append({
			"character_id": character_id,
			"character_name": str(record.get("character_name", "角色")).strip_edges(),
			"class_id": str(record.get("class_id", "")).strip_edges(),
			"class_name": str(record.get("class_name", record.get("class_id", ""))).strip_edges(),
			"is_active": 1 if int(record.get("is_active", 0)) == 1 else 0,
		})
	return normalized


static func _normalize_string_list(value: Variant) -> Array:
	var normalized: Array = []
	for item in _array_or_empty(value):
		var text := str(item).strip_edges()
		if text.is_empty() or normalized.has(text):
			continue
		normalized.append(text)
	return normalized


static func _normalize_id_string(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	if normalized.is_empty():
		return ""
	if typeof(value) == TYPE_INT:
		return str(int(value))
	if typeof(value) == TYPE_FLOAT:
		var rounded_from_float := int(round(float(value)))
		if is_equal_approx(float(value), float(rounded_from_float)):
			return str(rounded_from_float)
	if normalized.is_valid_int():
		return normalized
	if normalized.is_valid_float():
		var float_value := float(normalized)
		var rounded_from_string := int(round(float_value))
		if is_equal_approx(float_value, float(rounded_from_string)):
			return str(rounded_from_string)
	return normalized


static func _timestamp_now() -> String:
	return Time.get_datetime_string_from_system(false, true)


static func _dictionary_or_empty(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


static func _array_or_empty(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []

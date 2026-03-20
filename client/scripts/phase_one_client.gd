extends Control

const BackendApiScript = preload("res://client/scripts/backend_api.gd")
const ClientConfigStoreScript = preload("res://client/scripts/client_config_store.gd")
const ConfigPageScript = preload("res://client/scripts/pages/phase_one_config_page.gd")
const CharacterPageScript = preload("res://client/scripts/pages/phase_one_character_page.gd")
const InventoryPageScript = preload("res://client/scripts/pages/phase_one_inventory_page.gd")
const EquipmentPageScript = preload("res://client/scripts/pages/phase_one_equipment_page.gd")
const StagePageScript = preload("res://client/scripts/pages/phase_one_stage_page.gd")
const PreparePageScript = preload("res://client/scripts/pages/phase_one_prepare_page.gd")
const SettlePageScript = preload("res://client/scripts/pages/phase_one_settle_page.gd")

const CONFIG_PAGE := "config"
const CHARACTER_PAGE := "character"
const INVENTORY_PAGE := "inventory"
const EQUIPMENT_PAGE := "equipment"
const STAGE_PAGE := "stage"
const PREPARE_PAGE := "prepare"
const SETTLE_PAGE := "settle"

var api
var saved_config: Dictionary = {}
var tab_container: TabContainer
var flow_summary_label: Label
var page_indices: Dictionary = {}

var config_page
var character_page
var inventory_page
var equipment_page
var stage_page
var prepare_page
var settle_page

var current_character_list: Dictionary = {}
var current_character_detail: Dictionary = {}
var current_inventory: Dictionary = {}
var current_slots: Dictionary = {}
var current_chapters: Dictionary = {}
var current_stages: Dictionary = {}
var current_difficulties: Dictionary = {}
var current_reward_status: Dictionary = {}
var current_prepare_result: Dictionary = {}
var current_settle_result: Dictionary = {}
var current_prepared_monster_ids: PackedStringArray = []
var recent_battle_context_ids: Array = []
var has_loaded_character_list := false
var has_loaded_stages := false
var has_loaded_difficulties := false
var _is_applying_config := false


func _ready() -> void:
	saved_config = ClientConfigStoreScript.load_config()
	api = BackendApiScript.new(self, saved_config.get("base_url", ""), saved_config.get("bearer_token", ""))
	_build_ui()
	_apply_saved_config()
	_set_initial_states()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 16)
	add_child(root)

	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 12)
	root.add_child(shell)

	var title := Label.new()
	title.text = "《山海巡厄录》Phase-one Backend Client"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	shell.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "第二轮联调优化：真实角色列表、真实关卡列表、激活角色收口、/readyz 预检"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(subtitle)

	flow_summary_label = Label.new()
	flow_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(flow_summary_label)

	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(tab_container)

	config_page = ConfigPageScript.new()
	character_page = CharacterPageScript.new()
	inventory_page = InventoryPageScript.new()
	equipment_page = EquipmentPageScript.new()
	stage_page = StagePageScript.new()
	prepare_page = PreparePageScript.new()
	settle_page = SettlePageScript.new()

	_register_page(CONFIG_PAGE, config_page)
	_register_page(CHARACTER_PAGE, character_page)
	_register_page(INVENTORY_PAGE, inventory_page)
	_register_page(EQUIPMENT_PAGE, equipment_page)
	_register_page(STAGE_PAGE, stage_page)
	_register_page(PREPARE_PAGE, prepare_page)
	_register_page(SETTLE_PAGE, settle_page)


func _register_page(page_key: String, page) -> void:
	tab_container.add_child(page)
	page_indices[page_key] = tab_container.get_tab_count() - 1
	page.action_requested.connect(_on_page_action_requested)
	page.context_changed.connect(_on_page_context_changed)


func _apply_saved_config() -> void:
	_is_applying_config = true
	config_page.set_config_values(saved_config)
	character_page.apply_config(saved_config)
	stage_page.apply_config(saved_config)
	prepare_page.apply_config(saved_config)
	settle_page.apply_config(saved_config)
	equipment_page.set_character_id(str(saved_config.get("character_id", "1001")))
	_is_applying_config = false
	_refresh_runtime_config_snapshot()


func _set_initial_states() -> void:
	config_page.set_page_state("empty", "请先确认 backend 地址与 Bearer Token。")
	config_page.set_output_text("尚未保存配置。")

	character_page.set_page_state("empty", "尚未创建或读取角色。")
	character_page.set_output_text("等待角色创建或详情读取。")

	inventory_page.set_page_state("empty", "尚未读取背包。")
	inventory_page.set_output_text("等待背包请求。")

	equipment_page.set_page_state("empty", "尚未读取穿戴槽。")
	equipment_page.set_output_text("等待穿戴槽请求。")

	stage_page.set_page_state("empty", "尚未读取章节、关卡与难度。")
	stage_page.set_output_text("等待章节、关卡和难度请求。")

	prepare_page.set_page_state("empty", "尚未执行 battle prepare。")
	prepare_page.set_output_text("等待 battle prepare 请求。")

	settle_page.set_page_state("empty", "尚未执行 battle settle。")
	settle_page.set_output_text("等待 battle settle 请求。")


func _refresh_runtime_config_snapshot() -> void:
	var config_values: Dictionary = config_page.get_config_values()
	var create_payload: Dictionary = character_page.get_create_payload()

	saved_config["base_url"] = config_values.get("base_url", "")
	saved_config["bearer_token"] = config_values.get("bearer_token", "")
	saved_config["class_id"] = create_payload.get("class_id", "")
	saved_config["character_name"] = create_payload.get("character_name", "")
	saved_config["character_id"] = character_page.get_character_id_text()
	saved_config["battle_character_id"] = prepare_page.get_character_id_text()
	saved_config["stage_id"] = stage_page.get_stage_id_text()
	saved_config["stage_difficulty_id"] = prepare_page.get_stage_difficulty_text()

	api.update_credentials(saved_config.get("base_url", ""), saved_config.get("bearer_token", ""))


func _persist_runtime_config() -> void:
	_refresh_runtime_config_snapshot()
	ClientConfigStoreScript.save_config(saved_config)


func _refresh_recent_selectors() -> void:
	var recent_characters = _build_available_character_records()
	var recent_stage_difficulty_ids: Array = _build_available_stage_difficulty_ids()

	if has_loaded_character_list:
		character_page.set_character_list(
			_as_array(current_character_list.get("characters", [])),
			character_page.get_character_id_text()
		)
	else:
		character_page.set_recent_characters(recent_characters, character_page.get_character_id_text())

	equipment_page.set_recent_characters(recent_characters, equipment_page.get_character_id_text())
	prepare_page.set_recent_characters(recent_characters, prepare_page.get_character_id_text())
	settle_page.set_recent_characters(recent_characters, settle_page.get_character_id_text())

	stage_page.set_selected_stage_difficulty(prepare_page.get_stage_difficulty_text())
	prepare_page.set_recent_stage_difficulties(
		recent_stage_difficulty_ids,
		prepare_page.get_stage_difficulty_text()
	)
	settle_page.set_recent_stage_difficulties(
		recent_stage_difficulty_ids,
		settle_page.get_stage_difficulty_text()
	)
	settle_page.set_recent_battle_contexts(recent_battle_context_ids, settle_page.get_battle_context_text())


func _build_available_character_records() -> Array:
	if has_loaded_character_list:
		return _as_array(current_character_list.get("characters", []))

	return _build_recent_character_records()


func _build_available_stage_difficulty_ids() -> Array:
	if has_loaded_difficulties:
		var difficulty_ids: Array = []
		for difficulty in _as_array(current_difficulties.get("difficulties", [])):
			var entry := _as_dictionary(difficulty)
			var stage_difficulty_id = str(entry.get("stage_difficulty_id", "")).strip_edges()
			if stage_difficulty_id.is_empty():
				continue
			difficulty_ids.append(stage_difficulty_id)
		return difficulty_ids

	return _as_array(saved_config.get("recent_stage_difficulty_ids", []))


func _build_recent_character_records() -> Array:
	var recent: Array = _as_array(saved_config.get("recent_characters", [])).duplicate(true)
	recent = _prepend_character_record(
		recent,
		_as_dictionary(current_character_detail.get("character", {}))
	)
	recent = _prepend_character_record(
		recent,
		_as_dictionary(current_prepare_result.get("character", {}))
	)
	recent = _prepend_character_record(recent, _runtime_character_stub(character_page.get_character_id_text(), "当前角色输入"))
	recent = _prepend_character_record(recent, _runtime_character_stub(prepare_page.get_character_id_text(), "当前 Battle 角色"))
	return recent


func _runtime_character_stub(character_id: String, fallback_name: String) -> Dictionary:
	var normalized_id = character_id.strip_edges()
	if normalized_id.is_empty():
		return {}

	var detail_character = _as_dictionary(current_character_detail.get("character", {}))
	if str(detail_character.get("character_id", "")) == normalized_id:
		return detail_character

	var prepare_character = _as_dictionary(current_prepare_result.get("character", {}))
	if str(prepare_character.get("character_id", "")) == normalized_id:
		return prepare_character

	return {
		"character_id": normalized_id,
		"character_name": fallback_name,
	}


func _prepend_character_record(records: Array, character: Dictionary) -> Array:
	var character_id = str(character.get("character_id", "")).strip_edges()
	if character_id.is_empty():
		return records

	var merged: Array = [character]
	for record in records:
		var entry := _as_dictionary(record)
		if str(entry.get("character_id", "")) == character_id:
			continue
		merged.append(entry)
		if merged.size() >= 8:
			break

	return merged


func _sync_recent_characters_from_records(records: Array) -> void:
	var merged: Array = []
	for record in records:
		merged = ClientConfigStoreScript.upsert_recent_character(merged, _as_dictionary(record), 8)

	saved_config["recent_characters"] = merged


func _store_character_list(data: Dictionary) -> void:
	has_loaded_character_list = true
	current_character_list = {
		"characters": _as_array(data.get("characters", [])),
	}
	_sync_recent_characters_from_records(_as_array(current_character_list.get("characters", [])))


func _upsert_character_in_current_list(character: Dictionary) -> void:
	if character.is_empty():
		return

	if not has_loaded_character_list:
		_remember_character(character)
		return

	var character_id = str(character.get("character_id", "")).strip_edges()
	var merged: Array = []
	var found := false

	for record in _as_array(current_character_list.get("characters", [])):
		var entry := _as_dictionary(record)
		if str(entry.get("character_id", "")).strip_edges() == character_id:
			merged.append(character)
			found = true
		else:
			merged.append(entry)

	if not found:
		merged.append(character)

	current_character_list = {"characters": merged}
	_sync_recent_characters_from_records(merged)


func _apply_active_character(character: Dictionary) -> void:
	var active_character_id = str(character.get("character_id", "")).strip_edges()
	if active_character_id.is_empty():
		return

	var source_records: Array = []
	if has_loaded_character_list:
		source_records = _as_array(current_character_list.get("characters", []))
	else:
		source_records = _as_array(saved_config.get("recent_characters", []))

	var merged: Array = []
	var found := false
	for record in source_records:
		var entry := _as_dictionary(record).duplicate(true)
		if str(entry.get("character_id", "")).strip_edges() == active_character_id:
			var active_entry = character.duplicate(true)
			active_entry["is_active"] = 1
			merged.append(active_entry)
			found = true
		else:
			entry["is_active"] = 0
			merged.append(entry)

	if not found:
		var active_entry = character.duplicate(true)
		active_entry["is_active"] = 1
		merged.append(active_entry)

	if has_loaded_character_list:
		current_character_list = {"characters": merged}

	_sync_recent_characters_from_records(merged)

	var detail_character := _as_dictionary(current_character_detail.get("character", {})).duplicate(true)
	if detail_character.is_empty():
		return

	if str(detail_character.get("character_id", "")).strip_edges() == active_character_id:
		current_character_detail = {"character": character}
	else:
		detail_character["is_active"] = 0
		current_character_detail = {"character": detail_character}


func _refresh_flow_summary() -> void:
	var detail_character = _describe_character(character_page.get_character_id_text())
	var battle_character = _describe_character(prepare_page.get_character_id_text())
	var stage_id = stage_page.get_stage_id_text()
	var stage_difficulty_id = prepare_page.get_stage_difficulty_text()
	var battle_context_id = settle_page.get_battle_context_text()

	var lines := [
		"当前联调上下文：详情角色 %s | Battle 角色 %s | stage_id=%s | stage_difficulty_id=%s" % [
			detail_character,
			battle_character,
			stage_id if not stage_id.is_empty() else "(未填写)",
			stage_difficulty_id if not stage_difficulty_id.is_empty() else "(未填写)",
		],
	]

	if not battle_context_id.is_empty():
		lines.append("当前 battle_context_id：%s" % battle_context_id)

	var current_character = _as_dictionary(current_character_detail.get("character", {}))
	if not current_character.is_empty() and int(current_character.get("is_active", 0)) == 0:
		lines.append("提示：当前详情角色 is_active=0；可在角色页或 Prepare 页调用真实激活接口后再进入 battle。")

	flow_summary_label.text = "\n".join(lines)


func _describe_character(character_id: String) -> String:
	var normalized_id = character_id.strip_edges()
	if normalized_id.is_empty():
		return "(未选择)"

	for record in _as_array(current_character_list.get("characters", [])):
		var listed_entry := _as_dictionary(record)
		if str(listed_entry.get("character_id", "")).strip_edges() == normalized_id:
			return "%s #%s" % [str(listed_entry.get("character_name", "角色")), normalized_id]

	var detail_character = _as_dictionary(current_character_detail.get("character", {}))
	if str(detail_character.get("character_id", "")) == normalized_id:
		return "%s #%s" % [str(detail_character.get("character_name", "角色")), normalized_id]

	var prepare_character = _as_dictionary(current_prepare_result.get("character", {}))
	if str(prepare_character.get("character_id", "")) == normalized_id:
		return "%s #%s" % [str(prepare_character.get("character_name", "角色")), normalized_id]

	for record in _as_array(saved_config.get("recent_characters", [])):
		var entry := _as_dictionary(record)
		if str(entry.get("character_id", "")) == normalized_id:
			return "%s #%s" % [str(entry.get("character_name", "角色")), normalized_id]

	return "#%s" % normalized_id


func _set_current_tab(page_key: String) -> void:
	tab_container.current_tab = int(page_indices.get(page_key, 0))


func _focus_on_auth() -> void:
	_set_current_tab(CONFIG_PAGE)
	config_page.focus_auth_inputs()


func _handle_failure(page, result: Dictionary, fallback: String) -> void:
	var message = str(result.get("message", fallback))
	var kind = str(result.get("kind", "error"))

	match kind:
		"unauthorized":
			page.set_page_state("unauthorized", message)
			_focus_on_auth()
		"config":
			page.set_page_state("error", message)
		_:
			var code = int(result.get("code", -1))
			if code > 0:
				message = "%s（code=%d）" % [message, code]
			page.set_page_state("error", message)

	if result.has("raw"):
		page.set_output_json(result.get("raw"))


func _on_page_context_changed(context: String, payload: Dictionary) -> void:
	if _is_applying_config:
		return

	match context:
		"detail_character_changed":
			var character_id = str(payload.get("character_id", "")).strip_edges()
			if not character_id.is_empty():
				if character_page.get_character_id_text() != character_id:
					character_page.set_character_id(character_id)
				if equipment_page.get_character_id_text() != character_id:
					equipment_page.set_character_id(character_id)
		"battle_character_changed":
			var battle_character_id = str(payload.get("character_id", "")).strip_edges()
			if not battle_character_id.is_empty():
				if prepare_page.get_character_id_text() != battle_character_id:
					prepare_page.set_character_id(battle_character_id)
				if settle_page.get_character_id_text() != battle_character_id:
					settle_page.set_character_id(battle_character_id)
		"stage_id_changed":
			var stage_id = str(payload.get("stage_id", "")).strip_edges()
			if not stage_id.is_empty() and stage_page.get_stage_id_text() != stage_id:
				stage_page.set_stage_id(stage_id)
		"stage_difficulty_changed":
			var stage_difficulty_id = str(payload.get("stage_difficulty_id", "")).strip_edges()
			if not stage_difficulty_id.is_empty():
				stage_page.set_selected_stage_difficulty(stage_difficulty_id)
				if prepare_page.get_stage_difficulty_text() != stage_difficulty_id:
					prepare_page.set_stage_difficulty_id(stage_difficulty_id)
				if settle_page.get_stage_difficulty_text() != stage_difficulty_id:
					settle_page.set_stage_difficulty_id(stage_difficulty_id)
		"battle_context_changed":
			var battle_context_id = str(payload.get("battle_context_id", "")).strip_edges()
			if not battle_context_id.is_empty() and settle_page.get_battle_context_text() != battle_context_id:
				settle_page.set_battle_context_id(battle_context_id)
		_:
			pass

	_refresh_runtime_config_snapshot()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_page_action_requested(action: String, payload: Dictionary) -> void:
	match action:
		"fill_default_config":
			_on_fill_default_config_pressed()
		"save_config":
			_on_save_config_pressed()
		"run_readiness_check":
			await _on_run_readiness_check_pressed()
		"probe_backend":
			await _on_probe_backend_pressed()
		"load_characters":
			await _on_load_characters_pressed()
		"create_character":
			await _on_create_character_pressed()
		"load_character":
			await _on_load_character_pressed()
		"activate_current_character":
			await _on_activate_current_character_pressed()
		"sync_current_character":
			_on_sync_current_character_pressed()
		"load_inventory":
			await _on_load_inventory_pressed()
		"inventory_equipment_selected":
			_on_inventory_equipment_selected(payload)
		"load_slots":
			await _on_load_slots_pressed()
		"equip":
			await _on_equip_pressed()
		"unequip":
			await _on_unequip_pressed()
		"load_chapters":
			await _on_load_chapters_pressed()
		"load_stages":
			await _on_load_stages_pressed()
		"chapter_selected":
			await _on_load_stages_pressed(str(payload.get("chapter_id", "")))
		"load_difficulties":
			await _on_load_difficulties_pressed()
		"refresh_reward_status":
			await _on_refresh_reward_status_pressed()
		"difficulty_selected":
			_on_difficulty_selected(payload)
		"activate_battle_character":
			await _on_activate_battle_character_pressed()
		"prepare":
			await _on_prepare_pressed()
		"fill_prepared_monsters":
			_on_fill_prepared_monsters_pressed()
		"settle":
			await _on_settle_pressed()
		_:
			push_warning("Unhandled page action: %s" % action)


func _on_fill_default_config_pressed() -> void:
	_is_applying_config = true
	config_page.set_config_values({
		"base_url": "http://127.0.0.1:8000",
		"bearer_token": "test-token-2001",
	})
	character_page.apply_config({
		"class_id": "class_jingang",
		"character_name": "联调角色",
		"character_id": "1001",
	})
	equipment_page.set_character_id("1001")
	stage_page.apply_config({"stage_id": "stage_nanshan_001"})
	prepare_page.apply_config({
		"battle_character_id": "1001",
		"stage_difficulty_id": "stage_nanshan_001_normal",
	})
	settle_page.apply_config({
		"battle_character_id": "1001",
		"stage_difficulty_id": "stage_nanshan_001_normal",
	})
	_is_applying_config = false

	_refresh_runtime_config_snapshot()
	_refresh_recent_selectors()
	_refresh_flow_summary()
	config_page.set_page_state("success", "已填入联调默认值，记得点击“保存配置”。")
	config_page.set_output_text("默认值来自当前正式文档与最小联调 seed：127.0.0.1:8000 / test-token-2001 / character_id=1001 / stage_nanshan_001。")


func _on_save_config_pressed() -> void:
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()
	config_page.set_page_state("success", "配置已保存到 user://phase_one_client.cfg。")
	config_page.set_output_json(saved_config)


func _on_run_readiness_check_pressed() -> void:
	_refresh_runtime_config_snapshot()
	config_page.set_page_state("loading", "正在请求 /readyz?profile=interop。")
	var result: Dictionary = await api.request_public_json("GET", "/readyz", {"profile": "interop"})

	if not result.get("ok", false):
		_handle_failure(config_page, result, "phase-one 联调预检失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var failures = _as_array(_as_dictionary(data.get("summary", {})).get("failures", []))
	var warnings = _as_array(_as_dictionary(data.get("summary", {})).get("warnings", []))
	config_page.set_page_state(
		"success",
		"联调预检通过：profile=%s，failures=%d，warnings=%d。" % [
			str(data.get("selected_profile", "interop")),
			failures.size(),
			warnings.size(),
		]
	)
	config_page.set_summary_text(
		"ready=%s | /readyz 只做环境与联调前提检查，不替代真实业务接口调用。" % str(data.get("ready", false))
	)
	config_page.set_output_json(data)


func _on_probe_backend_pressed() -> void:
	_persist_runtime_config()
	config_page.set_page_state("loading", "正在用章节接口验证 backend 地址与 token。")
	var result: Dictionary = await api.request_json("GET", "/api/chapters")

	if not result.get("ok", false):
		_handle_failure(config_page, result, "探测 backend 失败。")
		return

	config_page.set_page_state("success", "章节接口已返回成功，当前 token/地址可联调。")
	config_page.set_summary_text("保护接口探测成功，可继续角色/背包/战斗联调。")
	config_page.set_output_json(result.get("raw"))


func _on_load_characters_pressed() -> void:
	_persist_runtime_config()
	character_page.set_page_state("loading", "正在读取当前用户角色列表。")
	var result: Dictionary = await api.request_json("GET", "/api/characters")

	if not result.get("ok", false):
		_handle_failure(character_page, result, "读取角色列表失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	_store_character_list(data)
	character_page.render_character_list(data, character_page.get_character_id_text())

	if _as_array(data.get("characters", [])).is_empty():
		character_page.show_character_list_empty()
		character_page.set_page_state("empty", "当前用户还没有角色，请先创建角色。")
	else:
		character_page.set_page_state("success", "角色列表已加载，可继续查看详情或切换当前启用角色。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_create_character_pressed() -> void:
	_persist_runtime_config()
	character_page.set_page_state("loading", "正在创建角色。")
	var result: Dictionary = await api.request_json("POST", "/api/characters", character_page.get_create_payload())

	if not result.get("ok", false):
		_handle_failure(character_page, result, "创建角色失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var character: Dictionary = _as_dictionary(data.get("character", {}))
	var created_character_id = str(character.get("character_id", ""))
	var is_active = int(character.get("is_active", 0)) == 1

	current_character_detail = {"character": character}
	current_slots = {
		"character_id": created_character_id,
		"slots": _as_array(data.get("equipment_slots", [])),
	}

	character_page.set_character_id(created_character_id)
	equipment_page.set_character_id(created_character_id)
	character_page.show_character_summary(character)
	equipment_page.render_slots(current_slots)
	_upsert_character_in_current_list(character)

	if is_active:
		prepare_page.set_character_id(created_character_id)
		settle_page.set_character_id(created_character_id)
		character_page.set_page_state("success", "角色创建成功，已同步 character_id 到后续页面。")
	else:
		character_page.set_page_state(
			"success",
			"角色创建成功，但当前角色 is_active=0；角色页/穿戴页已切到新角色，battle 页继续保留当前可战斗角色。"
		)

	character_page.set_output_json(data)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_load_character_pressed() -> void:
	var character_id_value = _parse_character_id(character_page.get_character_id_text())
	if character_id_value <= 0:
		character_page.set_page_state("error", "请先填写有效的 character_id。")
		return

	_persist_runtime_config()
	character_page.set_page_state("loading", "正在读取角色详情。")
	var result: Dictionary = await api.request_json("GET", "/api/characters/%d" % character_id_value)

	if not result.get("ok", false):
		_handle_failure(character_page, result, "读取角色详情失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var character: Dictionary = _as_dictionary(data.get("character", {}))
	var is_active = int(character.get("is_active", 0)) == 1

	current_character_detail = data
	character_page.show_character_summary(character)
	equipment_page.set_character_id(str(character_id_value))
	_upsert_character_in_current_list(character)

	if is_active:
		prepare_page.set_character_id(str(character_id_value))
		settle_page.set_character_id(str(character_id_value))
		character_page.set_page_state("success", "角色详情已加载，并已同步到 battle 页。")
	else:
		character_page.set_page_state("success", "角色详情已加载；当前角色 is_active=0，battle 页继续保留当前可战斗角色。")

	character_page.set_output_json(data)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_activate_current_character_pressed() -> void:
	var character_id_value = _parse_character_id(character_page.get_character_id_text())
	if character_id_value <= 0:
		character_page.set_page_state("error", "请先填写或选择有效的 character_id。")
		return

	await _activate_character(
		character_page,
		character_id_value,
		"角色已切换为当前启用角色，并同步到 battle 页。"
	)


func _on_activate_battle_character_pressed() -> void:
	var character_id_value = _parse_character_id(prepare_page.get_character_id_text())
	if character_id_value <= 0:
		prepare_page.set_page_state("error", "请先选择有效的 Battle character_id。")
		return

	await _activate_character(
		prepare_page,
		character_id_value,
		"当前 Battle 角色已激活，可继续执行 battle prepare。"
	)


func _activate_character(page, character_id_value: int, success_message: String) -> void:
	_persist_runtime_config()
	page.set_page_state("loading", "正在切换当前启用角色。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%d/activate" % character_id_value,
		{}
	)

	if not result.get("ok", false):
		_handle_failure(page, result, "切换当前启用角色失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var character: Dictionary = _as_dictionary(data.get("character", {}))
	var character_id_text = str(character.get("character_id", character_id_value))

	_apply_active_character(character)
	prepare_page.set_character_id(character_id_text)
	settle_page.set_character_id(character_id_text)

	if character_page.get_character_id_text() == character_id_text:
		current_character_detail = data

	if not current_character_detail.is_empty():
		character_page.show_character_summary(_as_dictionary(current_character_detail.get("character", {})))

	page.set_output_json(data)
	page.set_page_state("success", success_message)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_sync_current_character_pressed() -> void:
	if current_character_detail.is_empty():
		character_page.set_page_state("empty", "当前还没有已加载的角色详情。")
		return

	var character: Dictionary = _as_dictionary(current_character_detail.get("character", {}))
	var current_character_id = str(character.get("character_id", ""))
	if current_character_id.is_empty():
		character_page.set_page_state("error", "当前角色详情里没有 character_id。")
		return

	character_page.set_character_id(current_character_id)
	equipment_page.set_character_id(current_character_id)
	if int(character.get("is_active", 0)) == 1:
		prepare_page.set_character_id(current_character_id)
		settle_page.set_character_id(current_character_id)
		character_page.set_page_state("success", "当前角色 ID 已同步到后续页面。")
	else:
		character_page.set_page_state("success", "当前角色 ID 已同步到角色页/穿戴页；由于 is_active=0，battle 页保留原角色。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_load_inventory_pressed() -> void:
	_persist_runtime_config()
	inventory_page.set_page_state("loading", "正在读取背包。")
	var result: Dictionary = await api.request_json("GET", "/api/inventory", null, {
		"tab": inventory_page.get_selected_tab(),
		"page": 1,
		"page_size": 20,
	})

	if not result.get("ok", false):
		_handle_failure(inventory_page, result, "读取背包失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_inventory = data
	inventory_page.render_inventory(data)

	var stack_items: Array = _as_array(data.get("stack_items", []))
	var equipment_items: Array = _as_array(data.get("equipment_items", []))
	if stack_items.is_empty() and equipment_items.is_empty():
		inventory_page.set_page_state("empty", "背包为空。")
	else:
		inventory_page.set_page_state("success", "背包已加载，可选择装备实例带入穿戴页。")


func _on_inventory_equipment_selected(metadata: Dictionary) -> void:
	var equipment_instance_id = str(metadata.get("equipment_instance_id", ""))
	if equipment_instance_id.is_empty():
		return

	equipment_page.set_selected_equipment_instance(
		equipment_instance_id,
		str(metadata.get("item_name", ""))
	)
	equipment_page.set_page_state("success", "已从背包选中装备实例，接下来请选择槽位并执行 Equip。")
	_set_current_tab(EQUIPMENT_PAGE)


func _on_load_slots_pressed() -> void:
	var character_id_value = _parse_character_id(equipment_page.get_character_id_text())
	if character_id_value <= 0:
		equipment_page.set_page_state("error", "请先在角色页或穿戴页填写有效的 character_id。")
		return

	_persist_runtime_config()
	equipment_page.set_page_state("loading", "正在读取穿戴槽。")
	var result: Dictionary = await api.request_json("GET", "/api/characters/%d/equipment-slots" % character_id_value)

	if not result.get("ok", false):
		_handle_failure(equipment_page, result, "读取穿戴槽失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = data
	equipment_page.render_slots(data)

	if _as_array(data.get("slots", [])).is_empty():
		equipment_page.set_page_state("empty", "当前角色没有可显示的槽位。")
	else:
		equipment_page.set_page_state("success", "穿戴槽已加载，可执行 equip/unequip。")


func _on_equip_pressed() -> void:
	var character_id_value = _parse_character_id(equipment_page.get_character_id_text())
	var equipment_instance_id_value = _parse_character_id(equipment_page.get_equipment_instance_id_text())
	var target_slot = equipment_page.get_target_slot_key()

	if character_id_value <= 0:
		equipment_page.set_page_state("error", "请先填写有效的 character_id。")
		return
	if equipment_instance_id_value <= 0:
		equipment_page.set_page_state("error", "请先填写有效的 equipment_instance_id。")
		return
	if target_slot.is_empty():
		equipment_page.set_page_state("error", "请先读取穿戴槽并选择 target_slot_key。")
		return

	_persist_runtime_config()
	equipment_page.set_page_state("loading", "正在执行 equip。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%d/equip" % character_id_value,
		{
			"equipment_instance_id": equipment_instance_id_value,
			"target_slot_key": target_slot,
		}
	)

	if not result.get("ok", false):
		_handle_failure(equipment_page, result, "执行 equip 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = {
		"character_id": data.get("character_id"),
		"slots": _as_array(data.get("slot_snapshot", [])),
	}
	equipment_page.render_slots(current_slots)
	equipment_page.set_page_state("success", "equip 成功，已刷新槽位快照。")


func _on_unequip_pressed() -> void:
	var character_id_value = _parse_character_id(equipment_page.get_character_id_text())
	var target_slot = equipment_page.get_target_slot_key()

	if character_id_value <= 0:
		equipment_page.set_page_state("error", "请先填写有效的 character_id。")
		return
	if target_slot.is_empty():
		equipment_page.set_page_state("error", "请先读取穿戴槽并选择 target_slot_key。")
		return

	_persist_runtime_config()
	equipment_page.set_page_state("loading", "正在执行 unequip。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%d/unequip" % character_id_value,
		{
			"target_slot_key": target_slot,
		}
	)

	if not result.get("ok", false):
		_handle_failure(equipment_page, result, "执行 unequip 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = {
		"character_id": data.get("character_id"),
		"slots": _as_array(data.get("slot_snapshot", [])),
	}
	equipment_page.render_slots(current_slots)
	equipment_page.set_page_state("success", "unequip 成功，已刷新槽位快照。")


func _on_load_chapters_pressed() -> void:
	_persist_runtime_config()
	stage_page.set_page_state("loading", "正在读取章节列表。")
	var result: Dictionary = await api.request_json("GET", "/api/chapters")

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "读取章节列表失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_chapters = data
	stage_page.render_chapters(data, stage_page.get_selected_chapter_id())

	if _as_array(data.get("chapters", [])).is_empty():
		has_loaded_stages = false
		has_loaded_difficulties = false
		current_stages = {}
		current_difficulties = {}
		current_reward_status = {}
		stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
		stage_page.set_page_state("empty", "当前没有章节数据。")
		stage_page.set_stage_summary(0, 0, 0, current_reward_status)
		return

	await _on_load_stages_pressed(stage_page.get_selected_chapter_id())


func _on_load_stages_pressed(chapter_id_override: String = "") -> void:
	var chapter_id_value = chapter_id_override.strip_edges()
	if chapter_id_value.is_empty():
		chapter_id_value = stage_page.get_selected_chapter_id()

	if chapter_id_value.is_empty():
		stage_page.set_page_state("error", "请先选择 chapter_id。")
		return

	_persist_runtime_config()
	stage_page.set_selected_chapter_id(chapter_id_value)
	stage_page.set_page_state("loading", "正在读取章节关卡列表。")
	var result: Dictionary = await api.request_json("GET", "/api/chapters/%s/stages" % chapter_id_value)

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "读取章节关卡列表失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_stages = data
	has_loaded_stages = true
	has_loaded_difficulties = false
	current_difficulties = {}
	current_reward_status = {}
	stage_page.render_stages(data)
	stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(data.get("stages", [])).size(),
		0,
		current_reward_status
	)

	if _as_array(data.get("stages", [])).is_empty():
		stage_page.set_page_state("empty", "当前章节没有关卡数据。")
	else:
		stage_page.set_page_state("success", "关卡列表已加载，可继续读取难度列表。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_load_difficulties_pressed() -> void:
	var stage_id_value = stage_page.get_stage_id_text()
	if stage_id_value.is_empty():
		stage_page.set_page_state("error", "请先填写 stage_id。")
		return

	_persist_runtime_config()
	stage_page.set_page_state("loading", "正在读取关卡难度列表。")
	var result: Dictionary = await api.request_json("GET", "/api/stages/%s/difficulties" % stage_id_value)

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "读取关卡难度失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_difficulties = data
	has_loaded_difficulties = true
	current_reward_status = {}
	stage_page.render_difficulties(data, current_reward_status)
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(current_stages.get("stages", [])).size(),
		_as_array(data.get("difficulties", [])).size(),
		current_reward_status
	)
	_remember_stage_id(stage_id_value)

	if _as_array(data.get("difficulties", [])).is_empty():
		stage_page.set_page_state("empty", "当前没有难度数据。")
	else:
		stage_page.set_page_state("success", "难度列表已加载，可继续查看首通奖励状态。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_refresh_reward_status_pressed() -> void:
	var stage_difficulty_id_value = stage_page.get_selected_stage_difficulty()
	if stage_difficulty_id_value.is_empty():
		stage_difficulty_id_value = prepare_page.get_stage_difficulty_text()

	if stage_difficulty_id_value.is_empty():
		stage_page.set_page_state("error", "请先选择或读取 stage_difficulty_id。")
		return

	prepare_page.set_stage_difficulty_id(stage_difficulty_id_value)
	settle_page.set_stage_difficulty_id(stage_difficulty_id_value)
	stage_page.set_page_state("loading", "正在刷新首通奖励状态。")
	var result: Dictionary = await api.request_json(
		"GET",
		"/api/stage-difficulties/%s/first-clear-reward-status" % stage_difficulty_id_value
	)

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "读取首通奖励状态失败。")
		return

	current_reward_status = _as_dictionary(result.get("data", {}))
	stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(current_stages.get("stages", [])).size(),
		_as_array(current_difficulties.get("difficulties", [])).size(),
		current_reward_status
	)

	var reward_status_text = "无奖励"
	if int(current_reward_status.get("has_reward", 0)) == 1 and int(current_reward_status.get("has_granted", 0)) == 1:
		reward_status_text = "reward claimed"
	elif int(current_reward_status.get("has_reward", 0)) == 1:
		reward_status_text = "reward available"

	if str(current_reward_status.get("grant_status", "")).is_empty():
		stage_page.set_page_state("success", "首通奖励状态已刷新：%s。" % reward_status_text)
	else:
		stage_page.set_page_state(
			"success",
			"首通奖励状态已刷新：%s，grant_status=%s。" % [
				reward_status_text,
				str(current_reward_status.get("grant_status", "")),
			]
		)


func _on_difficulty_selected(metadata: Dictionary) -> void:
	var stage_difficulty_id_value = str(metadata.get("stage_difficulty_id", ""))
	if stage_difficulty_id_value.is_empty():
		return

	stage_page.set_selected_stage_difficulty(stage_difficulty_id_value)
	prepare_page.set_stage_difficulty_id(stage_difficulty_id_value)
	settle_page.set_stage_difficulty_id(stage_difficulty_id_value)
	_remember_stage_difficulty_id(stage_difficulty_id_value)
	_refresh_recent_selectors()
	_refresh_flow_summary()
	stage_page.set_page_state("success", "已选中难度，可继续执行 battle prepare。")
	_set_current_tab(PREPARE_PAGE)


func _on_prepare_pressed() -> void:
	var character_id_value = _parse_character_id(prepare_page.get_character_id_text())
	var stage_difficulty_id_value = prepare_page.get_stage_difficulty_text()

	if character_id_value <= 0:
		prepare_page.set_page_state("error", "请先填写有效的 character_id。")
		return
	if stage_difficulty_id_value.is_empty():
		prepare_page.set_page_state("error", "请先填写 stage_difficulty_id。")
		return

	prepare_page.set_character_id(str(character_id_value))
	settle_page.set_character_id(str(character_id_value))
	stage_page.set_selected_stage_difficulty(stage_difficulty_id_value)
	settle_page.set_stage_difficulty_id(stage_difficulty_id_value)
	_persist_runtime_config()
	prepare_page.set_page_state("preparing", "正在执行 battle prepare。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/battles/prepare",
		{
			"character_id": character_id_value,
			"stage_difficulty_id": stage_difficulty_id_value,
		}
	)

	if not result.get("ok", false):
		_handle_failure(prepare_page, result, "battle prepare 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_prepare_result = data
	current_prepared_monster_ids = _extract_monster_ids(data)
	prepare_page.show_prepare_summary(data)

	var battle_context_id = str(data.get("battle_context_id", ""))
	settle_page.set_battle_context_id(battle_context_id)
	settle_page.set_killed_monsters(current_prepared_monster_ids)
	recent_battle_context_ids = ClientConfigStoreScript.upsert_recent_string(recent_battle_context_ids, battle_context_id, 5)
	_remember_character(_as_dictionary(data.get("character", {})))
	_remember_stage_difficulty_id(stage_difficulty_id_value)
	prepare_page.set_page_state("success", "battle prepare 成功，battle_context_id 已同步到结算页。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_flow_summary()


func _on_fill_prepared_monsters_pressed() -> void:
	if current_prepared_monster_ids.is_empty():
		settle_page.set_page_state("empty", "当前没有 prepare 结果可复用。")
		return

	settle_page.set_killed_monsters(current_prepared_monster_ids)
	settle_page.set_page_state("success", "已填入 prepare 阶段的 monster_id 列表。")


func _on_settle_pressed() -> void:
	var character_id_value = _parse_character_id(settle_page.get_character_id_text())
	var stage_difficulty_id_value = settle_page.get_stage_difficulty_text()
	var battle_context_id_value = settle_page.get_battle_context_text()
	var killed_monsters = _parse_killed_monsters(settle_page.get_killed_monster_text())

	if character_id_value <= 0:
		settle_page.set_page_state("error", "请先填写有效的 character_id。")
		return
	if stage_difficulty_id_value.is_empty():
		settle_page.set_page_state("error", "请先填写 stage_difficulty_id。")
		return
	if battle_context_id_value.is_empty():
		settle_page.set_page_state("error", "请先填写 battle_context_id。")
		return
	if killed_monsters.is_empty():
		settle_page.set_page_state("error", "请先填写至少一个 killed_monsters。")
		return

	prepare_page.set_character_id(str(character_id_value))
	prepare_page.set_stage_difficulty_id(stage_difficulty_id_value)
	stage_page.set_selected_stage_difficulty(stage_difficulty_id_value)
	_persist_runtime_config()
	settle_page.set_page_state("settling", "正在执行 battle settle。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/battles/settle",
		{
			"character_id": character_id_value,
			"stage_difficulty_id": stage_difficulty_id_value,
			"battle_context_id": battle_context_id_value,
			"is_cleared": 1 if settle_page.is_cleared() else 0,
			"killed_monsters": killed_monsters,
		}
	)

	if not result.get("ok", false):
		_handle_failure(settle_page, result, "battle settle 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_settle_result = data
	current_reward_status = _as_dictionary(data.get("first_clear_reward_status", {}))
	settle_page.show_settlement_summary(data)
	settle_page.set_page_state("success", "battle settle 成功，已显示掉落、奖励、入包与首通奖励状态。")
	stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(current_stages.get("stages", [])).size(),
		_as_array(current_difficulties.get("difficulties", [])).size(),
		current_reward_status
	)
	_refresh_flow_summary()


func _remember_character(character: Dictionary) -> void:
	if character.is_empty():
		return

	saved_config["recent_characters"] = ClientConfigStoreScript.upsert_recent_character(
		_as_array(saved_config.get("recent_characters", [])),
		character
	)


func _remember_stage_id(stage_id: String) -> void:
	saved_config["recent_stage_ids"] = ClientConfigStoreScript.upsert_recent_string(
		_as_array(saved_config.get("recent_stage_ids", [])),
		stage_id
	)


func _remember_stage_difficulty_id(stage_difficulty_id: String) -> void:
	saved_config["recent_stage_difficulty_ids"] = ClientConfigStoreScript.upsert_recent_string(
		_as_array(saved_config.get("recent_stage_difficulty_ids", [])),
		stage_difficulty_id
	)


func _extract_monster_ids(payload: Dictionary) -> PackedStringArray:
	var monster_ids: PackedStringArray = []
	for monster in _as_array(payload.get("monster_list", [])):
		var entry := _as_dictionary(monster)
		var monster_id = str(entry.get("monster_id", ""))
		if monster_id.is_empty():
			continue
		monster_ids.append(monster_id)

	return monster_ids


func _parse_character_id(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty() or not trimmed.is_valid_int():
		return -1
	return int(trimmed)


func _parse_killed_monsters(raw_text: String) -> Array:
	var values: Array = []
	for raw_part in raw_text.split(","):
		var normalized := raw_part.strip_edges()
		if normalized.is_empty():
			continue
		values.append(normalized)
	return values


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _as_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []

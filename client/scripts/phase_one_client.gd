extends Control

const BackendApiScript = preload("res://client/scripts/backend_api.gd")
const ClientConfigStoreScript = preload("res://client/scripts/client_config_store.gd")
const ConfigPageScript = preload("res://client/scripts/pages/phase_one_config_page.gd")
const CharacterPageScript = preload("res://client/scripts/pages/phase_one_character_page.gd")
const InventoryPageScript = preload("res://client/scripts/pages/phase_one_inventory_page.gd")
const EquipmentPageScript = preload("res://client/scripts/pages/phase_one_equipment_page.gd")
const StagePageScript = preload("res://client/scripts/pages/phase_one_stage_page.gd")
const PreparePageScript = preload("res://client/scripts/pages/phase_one_prepare_page.gd")
const BattlePageScript = preload("res://client/scripts/pages/phase_one_battle_page.gd")
const SettlePageScript = preload("res://client/scripts/pages/phase_one_settle_page.gd")

const CONFIG_PAGE := "config"
const CHARACTER_PAGE := "character"
const INVENTORY_PAGE := "inventory"
const EQUIPMENT_PAGE := "equipment"
const STAGE_PAGE := "stage"
const PREPARE_PAGE := "prepare"
const BATTLE_PAGE := "battle"
const SETTLE_PAGE := "settle"
const EQUIPMENT_SLOT_ORDER := [
	"main_weapon",
	"sub_weapon",
	"armor",
	"leggings",
	"gloves",
	"boots",
	"cloak",
	"necklace",
	"ring_1",
	"ring_2",
	"bracelet_1",
	"bracelet_2",
]
const CLIENT_SUBTITLE := "认出主角，锁定去处，打完这一场。"
const DEFAULT_CONFIG_NOTE := (
	"默认值来自当前正式文档与最小联调 seed，只作为联调兜底；"
	+ "主流程仍应以真实角色列表、章节列表和关卡难度列表为准。"
)

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
var battle_page
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
var current_character_equipment_feedback: Dictionary = {}
var current_prepared_monster_ids: PackedStringArray = []
var recent_battle_context_ids: Array = []
var has_loaded_character_list := false
var has_loaded_stages := false
var has_loaded_difficulties := false
var _is_applying_config := false
var _character_auto_sync_in_flight := false
var _stage_auto_sync_in_flight := false


func _ready() -> void:
	saved_config = ClientConfigStoreScript.load_config()
	api = BackendApiScript.new(self, saved_config.get("base_url", ""), saved_config.get("bearer_token", ""))
	_build_ui()
	_apply_saved_config()
	_set_initial_states()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.07, 0.10, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	add_child(root)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(430, 804)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.07, 0.10, 0.15, 0.98)
	frame_style.border_color = Color(0.24, 0.31, 0.44, 1.0)
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.corner_radius_top_left = 24
	frame_style.corner_radius_top_right = 24
	frame_style.corner_radius_bottom_right = 24
	frame_style.corner_radius_bottom_left = 24
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	frame_style.shadow_size = 8
	frame_style.shadow_offset = Vector2(0, 6)
	frame.add_theme_stylebox_override("panel", frame_style)
	center.add_child(frame)

	var frame_margin := MarginContainer.new()
	frame_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_margin.add_theme_constant_override("margin_left", 18)
	frame_margin.add_theme_constant_override("margin_top", 12)
	frame_margin.add_theme_constant_override("margin_right", 18)
	frame_margin.add_theme_constant_override("margin_bottom", 12)
	frame.add_child(frame_margin)

	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 10)
	frame_margin.add_child(shell)

	var title := Label.new()
	title.text = "《山海巡厄录》"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	shell.add_child(title)

	var subtitle := Label.new()
	subtitle.text = CLIENT_SUBTITLE
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.74, 0.80, 0.88, 1.0)
	shell.add_child(subtitle)

	var flow_panel := PanelContainer.new()
	var flow_style := StyleBoxFlat.new()
	flow_style.bg_color = Color(0.10, 0.14, 0.20, 0.98)
	flow_style.border_color = Color(0.22, 0.28, 0.40, 1.0)
	flow_style.border_width_left = 1
	flow_style.border_width_top = 1
	flow_style.border_width_right = 1
	flow_style.border_width_bottom = 1
	flow_style.corner_radius_top_left = 18
	flow_style.corner_radius_top_right = 18
	flow_style.corner_radius_bottom_right = 18
	flow_style.corner_radius_bottom_left = 18
	flow_panel.add_theme_stylebox_override("panel", flow_style)
	shell.add_child(flow_panel)

	var flow_margin := MarginContainer.new()
	flow_margin.add_theme_constant_override("margin_left", 10)
	flow_margin.add_theme_constant_override("margin_top", 8)
	flow_margin.add_theme_constant_override("margin_right", 10)
	flow_margin.add_theme_constant_override("margin_bottom", 8)
	flow_panel.add_child(flow_margin)

	flow_summary_label = Label.new()
	flow_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flow_summary_label.add_theme_font_size_override("font_size", 14)
	flow_summary_label.modulate = Color(0.88, 0.92, 0.98, 1.0)
	flow_margin.add_child(flow_summary_label)

	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.tab_changed.connect(_on_tab_changed)
	shell.add_child(tab_container)

	config_page = ConfigPageScript.new()
	character_page = CharacterPageScript.new()
	inventory_page = InventoryPageScript.new()
	equipment_page = EquipmentPageScript.new()
	stage_page = StagePageScript.new()
	prepare_page = PreparePageScript.new()
	battle_page = BattlePageScript.new()
	settle_page = SettlePageScript.new()

	_register_page(CONFIG_PAGE, config_page)
	_register_page(CHARACTER_PAGE, character_page)
	_register_page(INVENTORY_PAGE, inventory_page)
	_register_page(EQUIPMENT_PAGE, equipment_page)
	_register_page(STAGE_PAGE, stage_page)
	_register_page(PREPARE_PAGE, prepare_page)
	_register_page(BATTLE_PAGE, battle_page)
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
	equipment_page.set_character_id(_normalize_id_string(saved_config.get("character_id", "1001")))
	_is_applying_config = false
	_refresh_runtime_config_snapshot()


func _set_initial_states() -> void:
	config_page.set_page_state("empty", "先确认 backend 地址和 Bearer Token。")
	config_page.set_output_text("尚未保存配置。")

	character_page.set_page_state("empty", "先去角色页认出这次的主角；如果还没有，就先创建一个。")
	character_page.set_output_text("等待角色列表、角色创建或详情读取。")

	inventory_page.set_page_state("empty", "锁定角色或打完一场后，这里会先接住这轮收获。")
	inventory_page.set_output_text("等待背包请求。")

	equipment_page.set_page_state("empty", "先确认当前角色，再刷新穿戴槽。")
	equipment_page.set_output_text("等待穿戴槽刷新。")

	stage_page.set_page_state("loading", "进入主线后，会自动铺开当前章节、关卡和难度。")
	stage_page.set_output_text("等待章节、关卡、难度与首通奖励状态回读。")

	prepare_page.set_page_state("empty", "角色和目标定下后，这里就能决定要不要开打。")
	prepare_page.set_output_text("等待出战确认。")

	battle_page.set_page_state("empty", "先在出战页定下角色和目标，再走进战场。")
	battle_page.set_output_text("等待出战页承接。")

	settle_page.set_page_state("empty", "打完一场后，这里会拆开告诉你得到了什么。")
	settle_page.set_output_text("等待结算结果回流。")


func _refresh_runtime_config_snapshot() -> void:
	var config_values: Dictionary = config_page.get_config_values()
	var create_payload: Dictionary = character_page.get_create_payload()

	saved_config["base_url"] = config_values.get("base_url", "")
	saved_config["bearer_token"] = config_values.get("bearer_token", "")
	saved_config["class_id"] = create_payload.get("class_id", "")
	saved_config["character_name"] = create_payload.get("character_name", "")
	saved_config["character_id"] = character_page.get_character_id_text()
	saved_config["battle_character_id"] = prepare_page.get_character_id_text()
	saved_config["chapter_id"] = stage_page.get_selected_chapter_id()
	saved_config["stage_id"] = stage_page.get_stage_id_text()
	saved_config["stage_difficulty_id"] = (
		prepare_page.get_stage_difficulty_text()
		if not prepare_page.get_stage_difficulty_text().is_empty()
		else stage_page.get_selected_stage_difficulty()
	)

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


func _build_available_chapter_ids() -> Array:
	var chapter_ids: Array = []
	for chapter_id in _as_array(saved_config.get("recent_chapter_ids", [])):
		var normalized_chapter_id := str(chapter_id).strip_edges()
		if normalized_chapter_id.is_empty() or chapter_ids.has(normalized_chapter_id):
			continue
		chapter_ids.append(normalized_chapter_id)
		if chapter_ids.size() >= 8:
			return chapter_ids
	for chapter in _as_array(current_chapters.get("chapters", [])):
		var entry := _as_dictionary(chapter)
		var chapter_id = str(entry.get("chapter_id", "")).strip_edges()
		if chapter_id.is_empty() or chapter_ids.has(chapter_id):
			continue
		chapter_ids.append(chapter_id)
		if chapter_ids.size() >= 8:
			return chapter_ids

	return chapter_ids


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
	recent = _prepend_character_record(
		recent,
		_runtime_character_stub(character_page.get_character_id_text(), "当前角色输入")
	)
	recent = _prepend_character_record(
		recent,
		_runtime_character_stub(prepare_page.get_character_id_text(), "当前出战角色")
	)
	return recent


func _find_active_character(records: Array) -> Dictionary:
	for record in records:
		var entry := _as_dictionary(record)
		if int(entry.get("is_active", 0)) == 1:
			return entry

	return {}


func _records_contain_character(records: Array, character_id: String) -> bool:
	var normalized_id = character_id.strip_edges()
	if normalized_id.is_empty():
		return false

	for record in records:
		var entry := _as_dictionary(record)
		if _normalize_id_string(entry.get("character_id", "")) == normalized_id:
			return true

	return false


func _sync_primary_character_from_list(records: Array) -> void:
	var active_character := _find_active_character(records)
	if active_character.is_empty():
		return

	var active_character_id = _normalize_id_string(active_character.get("character_id", ""))
	if active_character_id.is_empty():
		return

	prepare_page.set_character_id(active_character_id)
	settle_page.set_character_id(active_character_id)
	_remember_character(active_character)

	var current_detail_character_id = character_page.get_character_id_text()
	if current_character_detail.is_empty() or not _records_contain_character(records, current_detail_character_id):
		current_character_detail = {"character": active_character}
		character_page.set_character_id(active_character_id)
		equipment_page.set_character_id(active_character_id)


func _runtime_character_stub(character_id: String, fallback_name: String) -> Dictionary:
	var normalized_id = character_id.strip_edges()
	if normalized_id.is_empty():
		return {}

	var detail_character = _as_dictionary(current_character_detail.get("character", {}))
	if _normalize_id_string(detail_character.get("character_id", "")) == normalized_id:
		return detail_character

	var prepare_character = _as_dictionary(current_prepare_result.get("character", {}))
	if _normalize_id_string(prepare_character.get("character_id", "")) == normalized_id:
		return prepare_character

	return {
		"character_id": normalized_id,
		"character_name": fallback_name,
	}


func _prepend_character_record(records: Array, character: Dictionary) -> Array:
	var character_id = _normalize_id_string(character.get("character_id", ""))
	if character_id.is_empty():
		return records

	var merged: Array = [character]
	for record in records:
		var entry := _as_dictionary(record)
		if _normalize_id_string(entry.get("character_id", "")) == character_id:
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

	var character_id = _normalize_id_string(character.get("character_id", ""))
	var merged: Array = []
	var found := false

	for record in _as_array(current_character_list.get("characters", [])):
		var entry := _as_dictionary(record)
		if _normalize_id_string(entry.get("character_id", "")) == character_id:
			merged.append(character)
			found = true
		else:
			merged.append(entry)

	if not found:
		merged.append(character)

	current_character_list = {"characters": merged}
	_sync_recent_characters_from_records(merged)


func _apply_active_character(character: Dictionary) -> void:
	var active_character_id = _normalize_id_string(character.get("character_id", ""))
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
		if _normalize_id_string(entry.get("character_id", "")) == active_character_id:
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

	if _normalize_id_string(detail_character.get("character_id", "")) == active_character_id:
		current_character_detail = {"character": character}
	else:
		detail_character["is_active"] = 0
		current_character_detail = {"character": detail_character}


func _refresh_flow_summary() -> void:
	var config_values: Dictionary = config_page.get_config_values()
	var detail_character = _describe_character(character_page.get_character_id_text())
	var battle_character = _describe_character(prepare_page.get_character_id_text())
	var route_context := _build_route_context(stage_page.get_selected_stage_difficulty())
	var battle_context_id = settle_page.get_battle_context_text()
	var route_summary := _build_flow_route_summary(route_context)
	var journey_line := "当前：主角待定，去向：先走进山海路。"
	var next_step_line := "下一步：先去环境页连上后端。"
	var reminder_line := ""

	if str(config_values.get("base_url", "")).strip_edges().is_empty():
		next_step_line = "下一步：先填 backend 地址。"
	elif str(config_values.get("bearer_token", "")).strip_edges().is_empty():
		next_step_line = "下一步：先填 Bearer Token。"
	else:
		var character_line: String = detail_character
		if detail_character != battle_character and battle_character != "待确认":
			character_line = "查看 %s，出战 %s" % [detail_character, battle_character]
		elif detail_character == "待确认" and battle_character != "待确认":
			character_line = battle_character

		journey_line = "当前：%s，去向：%s。" % [character_line, route_summary]

		if detail_character == "待确认" and battle_character == "待确认":
			next_step_line = "下一步：先去角色页挑一个角色；如果还没有，就创建一个。"
		elif stage_page.get_selected_chapter_id().is_empty():
			next_step_line = "下一步：去主线页挑一章。"
		elif stage_page.get_stage_id_text().is_empty():
			next_step_line = "下一步：这一章已经展开，先挑一关。"
		elif stage_page.get_selected_stage_difficulty().is_empty():
			next_step_line = "下一步：关卡已经锁定，再选一档难度。"
		elif not battle_context_id.is_empty():
			next_step_line = "下一步：这一场已经开了，去战斗页推进，或等收获页回结果。"
		elif current_settle_result.is_empty():
			next_step_line = "下一步：目标已经锁定，去出战页决定要不要开打。"
		else:
			next_step_line = "下一步：这轮收获已经回来了，先去背包整理，再继续主线。"

		if not has_loaded_character_list and current_character_detail.is_empty():
			reminder_line = "提醒：角色列表还没回齐，先去角色页确认当前角色。"

	var current_character = _as_dictionary(current_character_detail.get("character", {}))
	if not current_character.is_empty() and int(current_character.get("is_active", 0)) == 0:
		reminder_line = "提醒：这名角色还没启用，先在角色页点“启用角色”会更顺。"

	var lines := [journey_line, next_step_line]
	if not reminder_line.is_empty():
		lines.append(reminder_line)
	flow_summary_label.text = "\n".join(lines)


func _describe_character(character_id: String) -> String:
	var normalized_id = character_id.strip_edges()
	if normalized_id.is_empty():
		return "待确认"

	for record in _as_array(current_character_list.get("characters", [])):
		var listed_entry := _as_dictionary(record)
		if _normalize_id_string(listed_entry.get("character_id", "")) == normalized_id:
			return str(listed_entry.get("character_name", "角色"))

	var detail_character = _as_dictionary(current_character_detail.get("character", {}))
	if _normalize_id_string(detail_character.get("character_id", "")) == normalized_id:
		return str(detail_character.get("character_name", "角色"))

	var prepare_character = _as_dictionary(current_prepare_result.get("character", {}))
	if _normalize_id_string(prepare_character.get("character_id", "")) == normalized_id:
		return str(prepare_character.get("character_name", "角色"))

	for record in _as_array(saved_config.get("recent_characters", [])):
		var entry := _as_dictionary(record)
		if _normalize_id_string(entry.get("character_id", "")) == normalized_id:
			return str(entry.get("character_name", "角色"))

	return "角色 %s" % normalized_id


func _build_flow_route_summary(route_context: Dictionary) -> String:
	var chapter_id := str(route_context.get("chapter_id", "")).strip_edges()
	var stage_id := str(route_context.get("stage_id", "")).strip_edges()
	var stage_difficulty_id := str(route_context.get("stage_difficulty_id", "")).strip_edges()
	var chapter_name := str(route_context.get("chapter_name", "待选章节"))
	var stage_name := str(route_context.get("stage_name", "待选关卡"))
	var difficulty_name := str(route_context.get("difficulty_name", "待选难度"))

	if chapter_id.is_empty():
		return "先去主线挑一章"
	if stage_id.is_empty():
		return "%s，准备挑一关" % chapter_name
	if stage_difficulty_id.is_empty():
		return "%s / %s，准备选难度" % [chapter_name, stage_name]
	return "%s / %s / %s" % [chapter_name, stage_name, difficulty_name]


func _find_character_record(character_id: String) -> Dictionary:
	var normalized_id := _normalize_id_string(character_id)
	if normalized_id.is_empty():
		return {}

	for record in _as_array(current_character_list.get("characters", [])):
		var listed_entry := _as_dictionary(record)
		if _normalize_id_string(listed_entry.get("character_id", "")) == normalized_id:
			return listed_entry

	var detail_character := _as_dictionary(current_character_detail.get("character", {}))
	if _normalize_id_string(detail_character.get("character_id", "")) == normalized_id:
		return detail_character

	var prepare_character := _as_dictionary(current_prepare_result.get("character", {}))
	if _normalize_id_string(prepare_character.get("character_id", "")) == normalized_id:
		return prepare_character

	for record in _as_array(saved_config.get("recent_characters", [])):
		var entry := _as_dictionary(record)
		if _normalize_id_string(entry.get("character_id", "")) == normalized_id:
			return entry

	return {}


func _build_character_stat_snapshot(character: Dictionary) -> Dictionary:
	if character.is_empty():
		return {}

	var character_id := _normalize_id_string(character.get("character_id", ""))
	if character_id.is_empty():
		return {}

	var prepared_character := _as_dictionary(current_prepare_result.get("character", {}))
	if _normalize_id_string(prepared_character.get("character_id", "")) != character_id:
		return {}

	var stats := _as_dictionary(current_prepare_result.get("character_stats", {})).duplicate(true)
	if stats.is_empty():
		return {}

	stats["character_id"] = character_id
	return stats


func _build_character_equipment_context(character: Dictionary) -> Dictionary:
	if character.is_empty():
		return {}

	var character_id := _normalize_id_string(character.get("character_id", ""))
	if character_id.is_empty():
		return {}

	var slot_count := 0
	var equipped_count := 0
	var has_slot_snapshot := _normalize_id_string(current_slots.get("character_id", "")) == character_id
	if has_slot_snapshot:
		var slot_entries := _as_array(current_slots.get("slots", []))
		slot_count = slot_entries.size()
		for slot in slot_entries:
			var entry := _as_dictionary(slot)
			if not _normalize_id_string(entry.get("equipped_instance_id", "")).is_empty():
				equipped_count += 1

	var context := {
		"character_id": character_id,
		"has_slot_snapshot": has_slot_snapshot,
		"slot_count": slot_count,
		"equipped_count": equipped_count,
		"empty_count": maxi(slot_count - equipped_count, 0),
	}

	if _normalize_id_string(current_character_equipment_feedback.get("character_id", "")) == character_id:
		for key in current_character_equipment_feedback.keys():
			context[key] = current_character_equipment_feedback[key]

	return context


func _build_equipment_feedback(
	character_id: int,
	change_type: String,
	slot_key: String,
	fallback_item_name: String = ""
) -> Dictionary:
	var slot_entry := _find_slot_snapshot_entry(current_slots, slot_key)
	var equipment := _as_dictionary(slot_entry.get("equipment", {}))
	var item_name := fallback_item_name.strip_edges()
	if item_name.is_empty():
		item_name = str(equipment.get("item_name", "这件装备")).strip_edges()
	if item_name.is_empty():
		item_name = "这件装备"

	return {
		"character_id": _normalize_id_string(character_id),
		"change_type": change_type,
		"slot_key": slot_key,
		"slot_name": _slot_display_name(slot_key),
		"item_name": item_name,
	}


func _find_slot_snapshot_entry(slots_payload: Dictionary, slot_key: String) -> Dictionary:
	var normalized_slot_key := slot_key.strip_edges()
	if normalized_slot_key.is_empty():
		return {}

	for slot in _as_array(slots_payload.get("slots", [])):
		var entry := _as_dictionary(slot)
		if str(entry.get("slot_key", "")).strip_edges() == normalized_slot_key:
			return entry

	return {}


func _slot_display_name(slot_key: String) -> String:
	match slot_key:
		"main_weapon":
			return "主武器"
		"sub_weapon":
			return "副武器"
		"armor":
			return "护甲"
		"leggings":
			return "护腿"
		"gloves":
			return "手套"
		"boots":
			return "靴子"
		"cloak":
			return "披风"
		"necklace":
			return "项链"
		"ring_1":
			return "戒指 1"
		"ring_2":
			return "戒指 2"
		"bracelet_1":
			return "手镯 1"
		"bracelet_2":
			return "手镯 2"
		_:
			return slot_key


func _find_selected_chapter_context() -> Dictionary:
	var selected_chapter_id: String = stage_page.get_selected_chapter_id()
	for chapter in _as_array(current_chapters.get("chapters", [])):
		var entry := _as_dictionary(chapter)
		if str(entry.get("chapter_id", "")) == selected_chapter_id:
			return entry
	return {}


func _find_selected_stage_context() -> Dictionary:
	var selected_stage_id: String = stage_page.get_stage_id_text()
	for stage in _as_array(current_stages.get("stages", [])):
		var entry := _as_dictionary(stage)
		if str(entry.get("stage_id", "")) == selected_stage_id:
			return entry
	return {}


func _find_stage_difficulty_context(stage_difficulty_id: String) -> Dictionary:
	for difficulty in _as_array(current_difficulties.get("difficulties", [])):
		var entry := _as_dictionary(difficulty)
		if str(entry.get("stage_difficulty_id", "")) == stage_difficulty_id:
			return entry
	return {}


func _build_route_context(stage_difficulty_id: String = "") -> Dictionary:
	var chapter := _find_selected_chapter_context()
	var stage := _find_selected_stage_context()
	var difficulty := _find_stage_difficulty_context(stage_difficulty_id if not stage_difficulty_id.is_empty() else prepare_page.get_stage_difficulty_text())

	return {
		"chapter_id": str(chapter.get("chapter_id", "")),
		"chapter_name": str(chapter.get("chapter_name", "章节待选择")),
		"stage_id": str(stage.get("stage_id", stage_page.get_stage_id_text())),
		"stage_name": str(stage.get("stage_name", "关卡待选择")),
		"stage_difficulty_id": str(difficulty.get("stage_difficulty_id", stage_difficulty_id)),
		"difficulty_key": str(difficulty.get("difficulty_key", "")),
		"difficulty_name": str(difficulty.get("difficulty_name", "难度待选择")),
		"recommended_power": difficulty.get("recommended_power", "-"),
	}


func _refresh_product_pages() -> void:
	var current_character := _find_character_record(character_page.get_character_id_text())
	character_page.set_character_stat_snapshot(_build_character_stat_snapshot(current_character))
	character_page.set_character_equipment_context(_build_character_equipment_context(current_character))
	character_page.show_character_summary(current_character)

	var battle_character := _find_character_record(prepare_page.get_character_id_text())
	var inventory_character := current_character if not current_character.is_empty() else battle_character
	if not current_settle_result.is_empty() and not battle_character.is_empty():
		inventory_character = battle_character
	var equipment_character := _find_character_record(equipment_page.get_character_id_text())
	if equipment_character.is_empty():
		equipment_character = inventory_character
	var equipment_character_id := _normalize_id_string(
		equipment_page.get_character_id_text() if not equipment_page.get_character_id_text().is_empty() else equipment_character.get("character_id", "")
	)
	var equipment_slots := {}
	if _normalize_id_string(current_slots.get("character_id", "")) == equipment_character_id:
		equipment_slots = current_slots.duplicate(true)
	var route_context := _build_route_context(prepare_page.get_stage_difficulty_text())
	inventory_page.render_inventory_context(inventory_character, current_settle_result)
	equipment_page.render_equipment_context(
		equipment_character,
		equipment_slots,
		current_inventory,
		current_settle_result
	)
	prepare_page.render_prepare_context(battle_character, route_context, current_reward_status)
	prepare_page.show_prepare_summary(current_prepare_result)
	settle_page.render_settle_context(battle_character, route_context)


func _set_current_tab(page_key: String) -> void:
	tab_container.current_tab = int(page_indices.get(page_key, 0))


func _on_tab_changed(index: int) -> void:
	if index == int(page_indices.get(CHARACTER_PAGE, -1)):
		await _auto_sync_character_page_if_needed()
	if index == int(page_indices.get(STAGE_PAGE, -1)):
		_auto_sync_stage_page_if_needed()


func _can_auto_sync_stage_page() -> bool:
	var config_values: Dictionary = config_page.get_config_values()
	return (
		not str(config_values.get("base_url", "")).strip_edges().is_empty()
		and not str(config_values.get("bearer_token", "")).strip_edges().is_empty()
	)


func _auto_sync_character_page_if_needed() -> void:
	if _character_auto_sync_in_flight or not _can_auto_sync_stage_page():
		return

	_character_auto_sync_in_flight = true
	await _ensure_character_page_progression()
	_character_auto_sync_in_flight = false


func _ensure_character_page_progression() -> void:
	if not has_loaded_character_list:
		await _on_load_characters_pressed()

	var preferred_character := _resolve_character_page_record()
	if preferred_character.is_empty():
		character_page.set_character_stat_snapshot({})
		character_page.show_character_summary({})
		_refresh_flow_summary()
		return

	var preferred_character_id := _normalize_id_string(preferred_character.get("character_id", ""))
	if not preferred_character_id.is_empty() and character_page.get_character_id_text() != preferred_character_id:
		character_page.set_character_id(preferred_character_id)

	current_character_detail = {"character": preferred_character}
	_refresh_product_pages()
	_refresh_flow_summary()


func _resolve_character_page_record() -> Dictionary:
	var listed_records := _as_array(current_character_list.get("characters", []))
	var active_character := _find_active_character(listed_records)
	if not active_character.is_empty():
		return active_character

	var current_character := _find_character_record(character_page.get_character_id_text())
	if not current_character.is_empty():
		return current_character

	if not listed_records.is_empty():
		return _as_dictionary(listed_records[0])

	return {}


func _reward_status_matches_selected_difficulty() -> bool:
	var selected_stage_difficulty_id: String = stage_page.get_selected_stage_difficulty()
	if selected_stage_difficulty_id.is_empty() or current_reward_status.is_empty():
		return false

	return str(current_reward_status.get("source_id", "")).strip_edges() == selected_stage_difficulty_id


func _auto_sync_stage_page_if_needed() -> void:
	if _stage_auto_sync_in_flight or not _can_auto_sync_stage_page():
		return

	_stage_auto_sync_in_flight = true
	await _ensure_stage_page_progression()
	_stage_auto_sync_in_flight = false


func _ensure_stage_page_progression() -> void:
	if _as_array(current_chapters.get("chapters", [])).is_empty():
		await _on_load_chapters_pressed()
		return

	if (
		stage_page.get_selected_chapter_id().is_empty()
		or str(current_stages.get("chapter_id", "")).strip_edges() != stage_page.get_selected_chapter_id()
		or (not has_loaded_stages and _as_array(current_stages.get("stages", [])).is_empty())
	):
		await _on_load_stages_pressed(stage_page.get_selected_chapter_id())
		return

	if (
		stage_page.get_stage_id_text().is_empty()
		or str(current_difficulties.get("stage_id", "")).strip_edges() != stage_page.get_stage_id_text()
		or (not has_loaded_difficulties and _as_array(current_difficulties.get("difficulties", [])).is_empty())
	):
		await _on_load_difficulties_pressed()
		return

	if not stage_page.get_selected_stage_difficulty().is_empty() and not _reward_status_matches_selected_difficulty():
		await _on_refresh_reward_status_pressed(false)


func _focus_on_auth() -> void:
	_set_current_tab(CONFIG_PAGE)
	config_page.focus_auth_inputs()


func _open_inventory_from_settle() -> void:
	_set_current_tab(INVENTORY_PAGE)
	if current_settle_result.is_empty():
		inventory_page.set_page_state("empty", "这轮收益还没生成，先完成正式结算，再回来整理背包。")
		inventory_page.show_handoff_summary("这轮收益还没生成；先完成结算，再回背包看新装备和关键材料。")
		return

	var inventory_results := _as_dictionary(current_settle_result.get("inventory_results", {}))
	var stack_results := _as_array(inventory_results.get("stack_results", []))
	var equipment_results := _as_array(inventory_results.get("equipment_instance_results", []))
	inventory_page.set_page_state("success", "本轮收益已经承接到背包，新增装备和关键材料会优先显示。")
	inventory_page.set_summary_text("本轮收获：掉落 %d | 奖励 %d | 入包 %d | 新装备 %d" % [
		_as_array(current_settle_result.get("drop_results", [])).size(),
		_as_array(current_settle_result.get("reward_results", [])).size(),
		stack_results.size(),
		equipment_results.size(),
	])
	inventory_page.show_handoff_summary(
		"已带着本轮结果来到背包；先看新装备和关键材料，再决定前往穿戴、查看角色还是继续主线，会更顺。"
	)


func _open_equipment_from_settle() -> void:
	_set_current_tab(EQUIPMENT_PAGE)
	var current_character_id: String = settle_page.get_character_id_text()
	if current_character_id.is_empty():
		current_character_id = prepare_page.get_character_id_text()
	if not current_character_id.is_empty():
		equipment_page.set_character_id(current_character_id)

	var latest_equipment: Dictionary = _latest_created_equipment_instance()
	if latest_equipment.is_empty():
		equipment_page.set_page_state("empty", "本轮没有新增装备可直接试穿。")
		equipment_page.set_summary_text("当前角色上下文已保留，你仍可刷新穿戴槽查看现有装备。")
		equipment_page.show_handoff_summary("这轮没有新装备可直达试穿，但当前角色上下文还在，你可以继续查看现有穿戴。")
		return

	equipment_page.set_selected_equipment_instance(
		_normalize_id_string(latest_equipment.get("equipment_instance_id", "")),
		str(latest_equipment.get("item_name", latest_equipment.get("item_id", "新装备"))),
		str(latest_equipment.get("equipment_slot", ""))
	)
	equipment_page.set_page_state("success", "已带上本轮新装备，当前槽位和候选区会优先围绕它展开。")
	equipment_page.show_handoff_summary("已承接本轮新装备；先看它更适合哪一格，再决定回角色还是继续主线。")


func _open_character_page(from_settle: bool = false) -> void:
	_set_current_tab(CHARACTER_PAGE)
	var current_character_id := ""
	if from_settle:
		current_character_id = settle_page.get_character_id_text()
		if current_character_id.is_empty():
			current_character_id = prepare_page.get_character_id_text()
	else:
		current_character_id = character_page.get_character_id_text()
		if current_character_id.is_empty():
			current_character_id = equipment_page.get_character_id_text()
		if current_character_id.is_empty():
			current_character_id = prepare_page.get_character_id_text()
		if current_character_id.is_empty():
			current_character_id = settle_page.get_character_id_text()

	if not current_character_id.is_empty():
		character_page.set_character_id(current_character_id)

	var character_record: Dictionary = _find_character_record(current_character_id)
	if character_record.is_empty():
		character_page.set_page_state("success", "已回到角色页，当前主流程都已接回。")
		character_page.show_growth_handoff("当前角色信息已经接回；接下来可以前往背包、穿戴，或直接继续主线。")
		return

	character_page.show_character_summary(character_record)
	character_page.show_growth_handoff(_build_character_growth_handoff(current_character_id, from_settle))
	if from_settle:
		character_page.set_page_state("success", "已回到角色页，可以继续查看本轮战后成长。")
	else:
		character_page.set_page_state("success", "已回到角色页，当前角色和成长入口都已就位。")


func _open_stage_from_settle() -> void:
	_set_current_tab(STAGE_PAGE)
	stage_page.set_page_state("success", "已回到主线，当前章节、关卡和难度都已保留。")


func _latest_created_equipment_instance() -> Dictionary:
	var created_equipment_instances := _as_array(current_settle_result.get("created_equipment_instances", []))
	if created_equipment_instances.is_empty():
		return {}

	return _as_dictionary(created_equipment_instances[0])


func _merge_slot_snapshot_payload(character_id: int, slot_snapshot: Array) -> Dictionary:
	var merged_lookup := {}
	if _parse_character_id(current_slots.get("character_id", "")) == character_id:
		for slot in _as_array(current_slots.get("slots", [])):
			var entry := _as_dictionary(slot)
			var slot_key := str(entry.get("slot_key", "")).strip_edges()
			if slot_key.is_empty():
				continue
			merged_lookup[slot_key] = entry

	for slot in slot_snapshot:
		var entry := _as_dictionary(slot)
		var slot_key := str(entry.get("slot_key", "")).strip_edges()
		if slot_key.is_empty():
			continue
		merged_lookup[slot_key] = entry

	var merged_slots: Array = []
	for slot_key in EQUIPMENT_SLOT_ORDER:
		if merged_lookup.has(slot_key):
			merged_slots.append(_as_dictionary(merged_lookup.get(slot_key, {})))

	if merged_slots.is_empty():
		merged_slots = slot_snapshot.duplicate(true)

	return {
		"character_id": _normalize_id_string(character_id),
		"slots": merged_slots,
	}


func _build_character_growth_handoff(character_id: String, from_settle: bool) -> String:
	var normalized_character_id := _normalize_id_string(character_id)
	if not normalized_character_id.is_empty() and _normalize_id_string(current_character_equipment_feedback.get("character_id", "")) == normalized_character_id:
		var slot_name := str(current_character_equipment_feedback.get("slot_name", "这格装备")).strip_edges()
		var item_name := str(current_character_equipment_feedback.get("item_name", "当前装备")).strip_edges()
		match str(current_character_equipment_feedback.get("change_type", "")):
			"equip":
				return "最近一次换装已同步：%s 现在穿着 %s；当前角色和穿戴已经连上，可以继续回主线试试这次变化。" % [
					slot_name,
					item_name,
				]
			"unequip":
				return "最近一次换装已同步：%s 已卸下 %s；当前角色和穿戴已经连上，可以继续整理后再出战。" % [
					slot_name,
					item_name,
				]

	if from_settle:
		return "这轮结果已经回流到角色页；你可以继续前往穿戴试装，或直接回主线再战一场。"

	return "角色页会承接你当前的成长进度；接下来前往背包、穿戴或主线都可以。"


func _handle_failure(page, result: Dictionary, fallback: String) -> void:
	var raw_message := str(result.get("message", "")).strip_edges()
	var message := fallback.strip_edges()
	if message.is_empty():
		message = raw_message
	if message.is_empty():
		message = "这一步还没能完成。"
	var kind = str(result.get("kind", "error"))

	match kind:
		"unauthorized":
			page.set_page_state("unauthorized", message, "回到“环境”页重新确认地址和 Bearer Token。")
			_focus_on_auth()
		"config":
			page.set_page_state("error", message, "保持当前选择，补齐这一步后再试一次。")
		"network":
			page.set_page_state("error", message, "确认 backend 已启动且网络可达后，再试一次。")
		_:
			page.set_page_state("error", message, "保持当前选择，稍微调整后再试一次。")

	if result.has("raw"):
		page.set_output_json(result.get("raw"))


func _on_page_context_changed(context: String, payload: Dictionary) -> void:
	if _is_applying_config:
		return

	match context:
		"detail_character_changed":
			var character_id = _normalize_id_string(payload.get("character_id", ""))
			if not character_id.is_empty():
				if character_page.get_character_id_text() != character_id:
					character_page.set_character_id(character_id)
				if equipment_page.get_character_id_text() != character_id:
					equipment_page.set_character_id(character_id)
		"battle_character_changed":
			var battle_character_id = _normalize_id_string(payload.get("character_id", ""))
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
	_refresh_product_pages()
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
		"navigate_inventory":
			if str(payload.get("source", "")) == "settle":
				_open_inventory_from_settle()
			else:
				_set_current_tab(INVENTORY_PAGE)
		"navigate_equipment":
			if str(payload.get("source", "")) == "settle":
				_open_equipment_from_settle()
			else:
				_set_current_tab(EQUIPMENT_PAGE)
		"navigate_character":
			_open_character_page(str(payload.get("source", "")) == "settle")
		"navigate_stage":
			if str(payload.get("source", "")) == "settle":
				_open_stage_from_settle()
			else:
				_set_current_tab(STAGE_PAGE)
		"navigate_prepare":
			_set_current_tab(PREPARE_PAGE)
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
		"stage_selected":
			await _on_stage_selected(payload)
		"load_difficulties":
			await _on_load_difficulties_pressed()
		"refresh_reward_status":
			await _on_refresh_reward_status_pressed()
		"difficulty_selected":
			await _on_difficulty_selected(payload)
		"activate_battle_character":
			await _on_activate_battle_character_pressed()
		"prepare":
			await _on_prepare_pressed()
		"battle_request_settle":
			await _on_battle_request_settle(payload)
		"retry_battle":
			await _on_retry_battle_pressed()
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
		"character_name": "山海行者",
		"character_id": "1001",
	})
	equipment_page.set_character_id("1001")
	stage_page.apply_config({
		"chapter_id": "chapter_nanshan_001",
		"stage_id": "stage_nanshan_001",
		"stage_difficulty_id": "stage_nanshan_001_normal",
	})
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
	_refresh_product_pages()
	_refresh_flow_summary()
	config_page.set_page_state("success", "已填入联调默认值，记得点击“保存配置”。")
	config_page.set_output_text(DEFAULT_CONFIG_NOTE)


func _on_save_config_pressed() -> void:
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
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
		(
			"ready=%s | /readyz 只做环境与联调前提检查，"
			% str(data.get("ready", false))
		)
		+ "不替代真实业务接口调用。"
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
		_handle_failure(character_page, result, "角色列表暂时没读回来。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var characters: Array = _as_array(data.get("characters", []))
	var active_character: Dictionary = _find_active_character(characters)
	var preferred_character_id = character_page.get_character_id_text()
	if preferred_character_id.is_empty() and not active_character.is_empty():
		preferred_character_id = _normalize_id_string(active_character.get("character_id", ""))

	_store_character_list(data)
	_sync_primary_character_from_list(characters)
	character_page.render_character_list(data, preferred_character_id)

	if characters.is_empty():
		character_page.show_character_list_empty()
		character_page.set_page_state("empty", "现在还没有角色，先创建一个。")
	elif not active_character.is_empty():
		character_page.set_page_state("success", "角色列表已经到位，当前主角也已经就位，可以继续去背包、穿戴或主线。")
	else:
		character_page.set_page_state(
			"success",
			"角色列表已经到位，先挑一名当前主角，再决定是否启用。"
		)

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_create_character_pressed() -> void:
	_persist_runtime_config()
	character_page.set_page_state("loading", "正在创建角色。")
	var result: Dictionary = await api.request_json("POST", "/api/characters", character_page.get_create_payload())

	if not result.get("ok", false):
		_handle_failure(character_page, result, "这次没能创建角色。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var character: Dictionary = _as_dictionary(data.get("character", {}))
	var created_character_id = _normalize_id_string(character.get("character_id", ""))
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
		character_page.set_page_state(
			"success",
			"角色创建完成，这名角色已经可以直接去主线。"
		)
	else:
		character_page.set_page_state(
			"success",
			"角色创建完成，但还没设为当前启用角色；如需立刻进入主线，请先启用。"
		)

	character_page.set_output_json(data)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_load_character_pressed() -> void:
	var character_id_value = _parse_character_id(character_page.get_character_id_text())
	if character_id_value <= 0:
		character_page.set_page_state("error", "先从角色列表里挑一名角色，或在调试区填一个有效编号。")
		return

	_persist_runtime_config()
	character_page.set_page_state("loading", "正在读取角色详情。")
	var result: Dictionary = await api.request_json("GET", "/api/characters/%d" % character_id_value)

	if not result.get("ok", false):
		_handle_failure(character_page, result, "这名角色的详情暂时没读回来。")
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
		character_page.set_page_state("success", "角色详情已经到位，这名角色已经可以直接去主线。")
	else:
		character_page.set_page_state(
			"success",
			"角色详情已经到位；若要进入主线和出战，请先启用这名角色。"
		)

	character_page.set_output_json(data)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_activate_current_character_pressed() -> void:
	var character_id_value = _parse_character_id(character_page.get_character_id_text())
	if character_id_value <= 0:
		character_page.set_page_state("error", "先挑一名角色，再决定是否启用。")
		return

	await _activate_character(
		character_page,
		character_id_value,
		"角色已切换为当前启用角色，现在可以继续去主线、背包或穿戴。"
	)


func _on_activate_battle_character_pressed() -> void:
	var character_id_value = _parse_character_id(prepare_page.get_character_id_text())
	if character_id_value <= 0:
		prepare_page.set_page_state("error", "先认出这次出战的是谁。")
		return

	await _activate_character(
		prepare_page,
		character_id_value,
		"这名出战角色已经启用，可以直接开打。"
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
		_handle_failure(page, result, "这次没能切换当前角色。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var character: Dictionary = _as_dictionary(data.get("character", {}))
	var character_id_text = _normalize_id_string(character.get("character_id", character_id_value))

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
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_sync_current_character_pressed() -> void:
	if current_character_detail.is_empty():
		character_page.set_page_state("empty", "这名角色的详情还没到位。")
		return

	var character: Dictionary = _as_dictionary(current_character_detail.get("character", {}))
	var current_character_id = _normalize_id_string(character.get("character_id", ""))
	if current_character_id.is_empty():
		character_page.set_page_state("error", "当前角色还没锁定成功。")
		return

	character_page.set_character_id(current_character_id)
	equipment_page.set_character_id(current_character_id)
	if int(character.get("is_active", 0)) == 1:
		prepare_page.set_character_id(current_character_id)
		settle_page.set_character_id(current_character_id)
		character_page.set_page_state("success", "这名角色已经同步到背包、穿戴和主线。")
	else:
		character_page.set_page_state(
			"success",
			"这名角色已经同步到详情与穿戴；如需进入主线和出战，请先启用。"
		)

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
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
		_handle_failure(inventory_page, result, "这包物品暂时没读回来。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_inventory = data
	inventory_page.render_inventory(data)

	var stack_items: Array = _as_array(data.get("stack_items", []))
	var equipment_items: Array = _as_array(data.get("equipment_items", []))
	if stack_items.is_empty() and equipment_items.is_empty():
		inventory_page.set_page_state("empty", "现在背包还是空的。")
	else:
		inventory_page.set_page_state("success", "背包已经到位，本轮新增和新装备会优先排在前面。")

	_refresh_product_pages()
	_refresh_flow_summary()


func _on_inventory_equipment_selected(metadata: Dictionary) -> void:
	var equipment_instance_id = _normalize_id_string(metadata.get("equipment_instance_id", ""))
	if equipment_instance_id.is_empty():
		return

	equipment_page.set_selected_equipment_instance(
		equipment_instance_id,
		str(metadata.get("item_name", "")),
		str(metadata.get("equipment_slot", ""))
	)
	equipment_page.show_handoff_summary("已从背包带入一件装备；先看它更适合哪一格，再决定是否立刻试穿。")
	equipment_page.set_page_state("success", "已从背包选中装备，候选区会优先围绕这件装备展开。")
	_set_current_tab(EQUIPMENT_PAGE)


func _on_load_slots_pressed() -> void:
	var character_id_value = _parse_character_id(equipment_page.get_character_id_text())
	if character_id_value <= 0:
		equipment_page.set_page_state("error", "请先在角色页或穿戴页确认有效的角色编号。")
		return

	_persist_runtime_config()
	equipment_page.set_page_state("loading", "正在刷新穿戴槽。")
	var result: Dictionary = await api.request_json("GET", "/api/characters/%d/equipment-slots" % character_id_value)

	if not result.get("ok", false):
		_handle_failure(equipment_page, result, "刷新穿戴槽失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = data
	equipment_page.render_slots(data)

	if _as_array(data.get("slots", [])).is_empty():
		equipment_page.set_page_state("empty", "当前角色没有可显示的槽位。")
	else:
		equipment_page.set_page_state("success", "穿戴槽已刷新，可以继续穿上或卸下装备。")


func _on_equip_pressed() -> void:
	var character_id_value = _parse_character_id(equipment_page.get_character_id_text())
	var equipment_instance_id_value = _parse_character_id(equipment_page.get_equipment_instance_id_text())
	var target_slot = equipment_page.get_target_slot_key()

	if character_id_value <= 0:
		equipment_page.set_page_state("error", "请先填写有效的角色编号。")
		return
	if equipment_instance_id_value <= 0:
		equipment_page.set_page_state("error", "请先填写有效的装备实例编号。")
		return
	if target_slot.is_empty():
		equipment_page.set_page_state("error", "请先刷新穿戴槽并选中目标槽位。")
		return

	_persist_runtime_config()
	equipment_page.set_page_state("loading", "正在穿戴装备。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%d/equip" % character_id_value,
		{
			"equipment_instance_id": equipment_instance_id_value,
			"target_slot_key": target_slot,
		}
	)

	if not result.get("ok", false):
		_handle_failure(equipment_page, result, "穿戴失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = _merge_slot_snapshot_payload(character_id_value, _as_array(data.get("slot_snapshot", [])))
	var slots_refresh_result: Dictionary = await api.request_json(
		"GET",
		"/api/characters/%d/equipment-slots" % character_id_value
	)
	if slots_refresh_result.get("ok", false):
		current_slots = _as_dictionary(slots_refresh_result.get("data", {}))
	else:
		equipment_page.show_handoff_summary("穿戴已成功；当前槽位已按服务端变更更新，完整快照稍后再刷新一次也可以。")
	current_character_equipment_feedback = _build_equipment_feedback(character_id_value, "equip", target_slot)
	equipment_page.render_slots(current_slots)
	equipment_page.set_page_state(
		"success",
		"穿戴完成，当前装备位和候选区都已刷新。"
		if slots_refresh_result.get("ok", false)
		else "穿戴完成；当前槽位已按返回结果更新，完整快照可再刷新一次。"
	)
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_unequip_pressed() -> void:
	var character_id_value = _parse_character_id(equipment_page.get_character_id_text())
	var target_slot = equipment_page.get_target_slot_key()
	var previous_slot_entry := _find_slot_snapshot_entry(current_slots, target_slot)
	var previous_equipment := _as_dictionary(previous_slot_entry.get("equipment", {}))

	if character_id_value <= 0:
		equipment_page.set_page_state("error", "请先填写有效的角色编号。")
		return
	if target_slot.is_empty():
		equipment_page.set_page_state("error", "请先刷新穿戴槽并选中目标槽位。")
		return

	_persist_runtime_config()
	equipment_page.set_page_state("loading", "正在卸下装备。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%d/unequip" % character_id_value,
		{
			"target_slot_key": target_slot,
		}
	)

	if not result.get("ok", false):
		_handle_failure(equipment_page, result, "卸下失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = _merge_slot_snapshot_payload(character_id_value, _as_array(data.get("slot_snapshot", [])))
	var slots_refresh_result: Dictionary = await api.request_json(
		"GET",
		"/api/characters/%d/equipment-slots" % character_id_value
	)
	if slots_refresh_result.get("ok", false):
		current_slots = _as_dictionary(slots_refresh_result.get("data", {}))
	else:
		equipment_page.show_handoff_summary("卸下已成功；当前槽位已按服务端变更更新，完整快照稍后再刷新一次也可以。")
	current_character_equipment_feedback = _build_equipment_feedback(
		character_id_value,
		"unequip",
		target_slot,
		str(previous_equipment.get("item_name", "原装备"))
	)
	equipment_page.render_slots(current_slots)
	equipment_page.set_page_state(
		"success",
		"卸下完成，当前装备位和候选区都已刷新。"
		if slots_refresh_result.get("ok", false)
		else "卸下完成；当前槽位已按返回结果更新，完整快照可再刷新一次。"
	)
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_load_chapters_pressed() -> void:
	_persist_runtime_config()
	stage_page.set_page_state("loading", "正在展开当前可推进章节。")
	var result: Dictionary = await api.request_json("GET", "/api/chapters")

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "这张主线地图暂时没展开。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_chapters = data
	stage_page.render_chapters(data, _build_preferred_chapter_ids())

	if _as_array(data.get("chapters", [])).is_empty():
		has_loaded_stages = false
		has_loaded_difficulties = false
		current_stages = {}
		current_difficulties = {}
		current_reward_status = {}
		stage_page.set_selected_chapter_id("")
		stage_page.render_stages(current_stages)
		stage_page.set_selected_stage_difficulty("")
		prepare_page.set_stage_difficulty_id("")
		settle_page.set_stage_difficulty_id("")
		stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
		stage_page.set_page_state("empty", "山海路暂时还没有开放章节。")
		stage_page.set_stage_summary(0, 0, 0, current_reward_status)
		_persist_runtime_config()
		_refresh_recent_selectors()
		_refresh_product_pages()
		_refresh_flow_summary()
		return

	await _on_load_stages_pressed(stage_page.get_selected_chapter_id())


func _on_load_stages_pressed(chapter_id_override: String = "") -> void:
	var chapter_id_value = chapter_id_override.strip_edges()
	if chapter_id_value.is_empty():
		chapter_id_value = stage_page.get_selected_chapter_id()

	if chapter_id_value.is_empty():
		stage_page.set_page_state("error", "先定下一章。")
		return

	_persist_runtime_config()
	stage_page.set_selected_chapter_id(chapter_id_value)
	_remember_chapter_id(chapter_id_value)
	stage_page.set_page_state("loading", "正在展开当前章节的关卡。")
	var result: Dictionary = await api.request_json("GET", "/api/chapters/%s/stages" % chapter_id_value)

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "这一章暂时没展开。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_stages = data
	has_loaded_stages = true
	has_loaded_difficulties = false
	current_difficulties = {}
	current_reward_status = {}
	prepare_page.set_stage_difficulty_id("")
	settle_page.set_stage_difficulty_id("")
	stage_page.render_stages(data, _build_preferred_stage_ids())
	stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(data.get("stages", [])).size(),
		0,
		current_reward_status
	)

	if _as_array(data.get("stages", [])).is_empty():
		stage_page.set_page_state("empty", "这一章暂时还没有可推进的关卡。")
	else:
		stage_page.set_page_state("success", "这一章已经铺开，可以继续选关卡和难度。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()

	if not _as_array(data.get("stages", [])).is_empty():
		await _on_load_difficulties_pressed()


func _on_load_difficulties_pressed() -> void:
	var stage_id_value = stage_page.get_stage_id_text()
	if stage_id_value.is_empty():
		stage_page.set_page_state("error", "先定下一关。")
		return

	_persist_runtime_config()
	stage_page.set_page_state("loading", "正在展开当前关卡的难度。")
	var result: Dictionary = await api.request_json("GET", "/api/stages/%s/difficulties" % stage_id_value)

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "这一关的难度暂时没展开。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_difficulties = data
	has_loaded_difficulties = true
	current_reward_status = {}
	stage_page.render_difficulties(data, current_reward_status, _build_preferred_stage_difficulty_ids())
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(current_stages.get("stages", [])).size(),
		_as_array(data.get("difficulties", [])).size(),
		current_reward_status
	)
	_remember_stage_id(stage_id_value)
	var selected_stage_difficulty_id: String = stage_page.get_selected_stage_difficulty()
	if not selected_stage_difficulty_id.is_empty():
		prepare_page.set_stage_difficulty_id(selected_stage_difficulty_id)
		settle_page.set_stage_difficulty_id(selected_stage_difficulty_id)
		_remember_stage_difficulty_id(selected_stage_difficulty_id)

	if _as_array(data.get("difficulties", [])).is_empty():
		stage_page.set_page_state("empty", "这个关卡暂时还没有开放难度。")
	else:
		var reward_loaded := await _on_refresh_reward_status_pressed(false)
		if reward_loaded:
			stage_page.set_page_state("success", "这一关的难度已经展开，定好后就能进入出战。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_stage_selected(metadata: Dictionary) -> void:
	var stage_id_value = str(metadata.get("stage_id", "")).strip_edges()
	if stage_id_value.is_empty():
		return

	stage_page.set_stage_id(stage_id_value)
	_remember_stage_id(stage_id_value)
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()
	await _on_load_difficulties_pressed()


func _on_refresh_reward_status_pressed(show_success_message: bool = true) -> bool:
	var stage_difficulty_id_value = stage_page.get_selected_stage_difficulty()
	if stage_difficulty_id_value.is_empty():
		stage_difficulty_id_value = prepare_page.get_stage_difficulty_text()

	if stage_difficulty_id_value.is_empty():
		stage_page.set_page_state("error", "先定下一档难度。")
		return false

	prepare_page.set_stage_difficulty_id(stage_difficulty_id_value)
	settle_page.set_stage_difficulty_id(stage_difficulty_id_value)
	stage_page.set_page_state("loading", "正在同步当前奖励状态。")
	var result: Dictionary = await api.request_json(
		"GET",
		"/api/stage-difficulties/%s/first-clear-reward-status" % stage_difficulty_id_value
	)

	if not result.get("ok", false):
		_handle_failure(stage_page, result, "这一档奖励状态暂时没同步回来。")
		return false

	current_reward_status = _as_dictionary(result.get("data", {}))
	stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(current_stages.get("stages", [])).size(),
		_as_array(current_difficulties.get("difficulties", [])).size(),
		current_reward_status
	)

	var reward_status_text = "当前没有首通奖励"
	if int(current_reward_status.get("has_reward", 0)) == 1 and int(current_reward_status.get("has_granted", 0)) == 1:
		reward_status_text = "首通奖励已领取"
	elif int(current_reward_status.get("has_reward", 0)) == 1:
		reward_status_text = "首通奖励待领取"

	if show_success_message:
		if str(current_reward_status.get("grant_status", "")).is_empty():
			stage_page.set_page_state("success", "这一档奖励状态已经同步：%s。" % reward_status_text)
		else:
			stage_page.set_page_state(
				"success",
				"这一档奖励状态已经同步：%s。更细的技术状态已放到技术详情里。" % [
					reward_status_text,
				]
			)

	return true


func _on_difficulty_selected(metadata: Dictionary) -> void:
	var stage_difficulty_id_value = str(metadata.get("stage_difficulty_id", ""))
	if stage_difficulty_id_value.is_empty():
		return

	stage_page.set_selected_stage_difficulty(stage_difficulty_id_value)
	prepare_page.set_stage_difficulty_id(stage_difficulty_id_value)
	settle_page.set_stage_difficulty_id(stage_difficulty_id_value)
	_remember_stage_difficulty_id(stage_difficulty_id_value)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()
	var reward_loaded := await _on_refresh_reward_status_pressed(false)
	if not reward_loaded:
		return

	stage_page.set_page_state(
		"success",
		"这一档已经定下，奖励状态也同步好了，下一步去出战。"
	)


func _on_prepare_pressed() -> void:
	var character_id_value = _parse_character_id(prepare_page.get_character_id_text())
	var stage_difficulty_id_value = prepare_page.get_stage_difficulty_text()

	if character_id_value <= 0:
		prepare_page.set_page_state("error", "先认出这次出战的是谁。")
		return
	if stage_difficulty_id_value.is_empty():
		prepare_page.set_page_state("error", "先定下这一场要打的难度。")
		return

	prepare_page.set_character_id(str(character_id_value))
	settle_page.set_character_id(str(character_id_value))
	stage_page.set_selected_stage_difficulty(stage_difficulty_id_value)
	settle_page.set_stage_difficulty_id(stage_difficulty_id_value)
	_persist_runtime_config()
	prepare_page.set_page_state("preparing", "正在整理这一场的出战信息。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/battles/prepare",
		{
			"character_id": character_id_value,
			"stage_difficulty_id": stage_difficulty_id_value,
		}
	)

	if not result.get("ok", false):
		_handle_failure(prepare_page, result, "这场出战准备没完成。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_prepare_result = data
	current_settle_result = {}
	current_prepared_monster_ids = _extract_monster_ids(data)
	prepare_page.show_prepare_summary(data)
	var battle_route_context := _build_route_context(stage_difficulty_id_value)
	var prepared_stage_difficulty := _as_dictionary(data.get("stage_difficulty", {}))
	if not prepared_stage_difficulty.is_empty():
		battle_route_context["stage_difficulty_id"] = str(prepared_stage_difficulty.get("stage_difficulty_id", stage_difficulty_id_value))
		battle_route_context["difficulty_key"] = str(prepared_stage_difficulty.get("difficulty_key", battle_route_context.get("difficulty_key", "")))
		battle_route_context["difficulty_name"] = str(prepared_stage_difficulty.get("difficulty_name", battle_route_context.get("difficulty_name", "难度待选择")))
		battle_route_context["recommended_power"] = prepared_stage_difficulty.get("recommended_power", battle_route_context.get("recommended_power", "-"))
	battle_page.load_battle(data, battle_route_context, current_reward_status)

	var battle_context_id = str(data.get("battle_context_id", ""))
	settle_page.set_battle_context_id(battle_context_id)
	settle_page.set_killed_monsters(current_prepared_monster_ids)
	settle_page.show_handoff_summary(
		str(character_id_value),
		stage_difficulty_id_value,
		battle_context_id,
		current_prepared_monster_ids.size()
	)
	recent_battle_context_ids = ClientConfigStoreScript.upsert_recent_string(
		recent_battle_context_ids,
		battle_context_id,
		5
	)
	_remember_character(_as_dictionary(data.get("character", {})))
	_remember_stage_difficulty_id(stage_difficulty_id_value)
	prepare_page.set_page_state("success", "出战信息已经锁定，马上进入战斗。")
	battle_page.set_page_state("success", "战场已经准备好，可以开始接敌和清场。")
	settle_page.set_page_state("success", "这一场结束后，这里会自动展开本场收获。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()
	_set_current_tab(BATTLE_PAGE)


func _on_fill_prepared_monsters_pressed() -> void:
	if current_prepared_monster_ids.is_empty():
		settle_page.set_page_state("empty", "当前还没有可复用的敌方列表。")
		return

	settle_page.set_killed_monsters(current_prepared_monster_ids)
	settle_page.show_handoff_summary(
		settle_page.get_character_id_text(),
		settle_page.get_stage_difficulty_text(),
		settle_page.get_battle_context_text(),
		current_prepared_monster_ids.size()
	)
	settle_page.set_page_state("success", "这一场的结果页已经就位，战斗结束后会自动回到这里。")


func _on_battle_request_settle(payload: Dictionary) -> void:
	var character_id_value = _parse_character_id(str(payload.get("character_id", "")))
	var stage_difficulty_id_value = str(payload.get("stage_difficulty_id", "")).strip_edges()
	var battle_context_id_value = str(payload.get("battle_context_id", "")).strip_edges()
	var killed_monsters = _as_array(payload.get("killed_monsters", []))
	var is_cleared_value := int(payload.get("is_cleared", 0)) == 1

	await _submit_settle_request(
		character_id_value,
		stage_difficulty_id_value,
		battle_context_id_value,
		killed_monsters,
		is_cleared_value,
		true
	)


func _on_retry_battle_pressed() -> void:
	if prepare_page.get_character_id_text().strip_edges().is_empty() or prepare_page.get_stage_difficulty_text().strip_edges().is_empty():
		settle_page.set_page_state("error", "先把角色和难度都定下，再来一场。")
		return

	current_prepare_result = {}
	current_settle_result = {}
	current_prepared_monster_ids = PackedStringArray()
	battle_page.reset_battle_space()
	await _on_prepare_pressed()


func _on_settle_pressed() -> void:
	var character_id_value = _parse_character_id(settle_page.get_character_id_text())
	var stage_difficulty_id_value = settle_page.get_stage_difficulty_text()
	var battle_context_id_value = settle_page.get_battle_context_text()
	var killed_monsters = _parse_killed_monsters(settle_page.get_killed_monster_text())

	await _submit_settle_request(
		character_id_value,
		stage_difficulty_id_value,
		battle_context_id_value,
		killed_monsters,
		settle_page.is_cleared(),
		false
	)


func _submit_settle_request(
	character_id_value: int,
	stage_difficulty_id_value: String,
	battle_context_id_value: String,
	killed_monsters: Array,
	is_cleared_value: bool,
	from_battle_page: bool
) -> void:
	if character_id_value <= 0:
		var invalid_character_message := "先确认本次出战角色。"
		settle_page.set_page_state("error", invalid_character_message)
		if from_battle_page:
			battle_page.allow_retry_settle()
			battle_page.set_page_state("error", invalid_character_message)
		return
	if stage_difficulty_id_value.is_empty():
		var invalid_stage_message := "先确认本次目标难度。"
		settle_page.set_page_state("error", invalid_stage_message)
		if from_battle_page:
			battle_page.allow_retry_settle()
			battle_page.set_page_state("error", invalid_stage_message)
		return
	if battle_context_id_value.is_empty():
		var invalid_context_message := "这场战斗已经断开了，先回出战页重新进入这一场。"
		settle_page.set_page_state("error", invalid_context_message)
		if from_battle_page:
			battle_page.allow_retry_settle()
			battle_page.set_page_state("error", invalid_context_message)
		return
	if killed_monsters.is_empty():
		var invalid_monster_message := "至少击败一个敌人后，才能提交这次结算。"
		settle_page.set_page_state("error", invalid_monster_message)
		if from_battle_page:
			battle_page.allow_retry_settle()
			battle_page.set_page_state("error", invalid_monster_message)
		return

	prepare_page.set_character_id(str(character_id_value))
	prepare_page.set_stage_difficulty_id(stage_difficulty_id_value)
	stage_page.set_selected_stage_difficulty(stage_difficulty_id_value)
	_persist_runtime_config()
	if from_battle_page:
		battle_page.set_page_state("settling", "战斗结束，正在提交正式结算。")
	settle_page.set_page_state("settling", "正在整理这一场的结果。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/battles/settle",
		{
			"character_id": character_id_value,
			"stage_difficulty_id": stage_difficulty_id_value,
			"battle_context_id": battle_context_id_value,
			"is_cleared": 1 if is_cleared_value else 0,
			"killed_monsters": killed_monsters,
		}
	)

	if not result.get("ok", false):
		if from_battle_page:
			battle_page.allow_retry_settle()
			_handle_failure(battle_page, result, "这场收获暂时没结出来。")
		_handle_failure(settle_page, result, "这场收获暂时没结出来。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_settle_result = data
	current_reward_status = _as_dictionary(data.get("first_clear_reward_status", {}))
	settle_page.show_settlement_summary(data)
	if from_battle_page:
		battle_page.set_page_state("success", "战斗已收束，结果页已经生成。")
	settle_page.set_page_state("success", "这一场已经打完，掉落、奖励和入包结果都整理好了。")
	stage_page.render_reward_context(current_chapters, current_stages, current_difficulties, current_reward_status)
	stage_page.set_stage_summary(
		_as_array(current_chapters.get("chapters", [])).size(),
		_as_array(current_stages.get("stages", [])).size(),
		_as_array(current_difficulties.get("difficulties", [])).size(),
		current_reward_status
	)
	stage_page.set_page_state("success", "结算完成，主线页的首通奖励状态也已经同步。")
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()
	_set_current_tab(SETTLE_PAGE)


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


func _remember_chapter_id(chapter_id: String) -> void:
	var normalized_chapter_id := chapter_id.strip_edges()
	if normalized_chapter_id.is_empty():
		return

	saved_config["chapter_id"] = normalized_chapter_id
	saved_config["recent_chapter_ids"] = ClientConfigStoreScript.upsert_recent_string(
		_as_array(saved_config.get("recent_chapter_ids", [])),
		normalized_chapter_id
	)


func _remember_stage_difficulty_id(stage_difficulty_id: String) -> void:
	saved_config["recent_stage_difficulty_ids"] = ClientConfigStoreScript.upsert_recent_string(
		_as_array(saved_config.get("recent_stage_difficulty_ids", [])),
		stage_difficulty_id
	)


func _build_preferred_chapter_ids() -> Array:
	var candidates: Array = [
		stage_page.get_selected_chapter_id(),
		str(current_stages.get("chapter_id", "")).strip_edges(),
		str(saved_config.get("chapter_id", "")).strip_edges(),
	]

	for chapter_id in _build_available_chapter_ids():
		candidates.append(chapter_id)

	return candidates


func _build_preferred_stage_ids() -> Array:
	var candidates: Array = [
		stage_page.get_stage_id_text(),
		str(current_difficulties.get("stage_id", "")).strip_edges(),
		str(saved_config.get("stage_id", "")).strip_edges(),
	]

	for stage_id in _as_array(saved_config.get("recent_stage_ids", [])):
		candidates.append(str(stage_id).strip_edges())

	return candidates


func _build_preferred_stage_difficulty_ids() -> Array:
	var candidates: Array = [
		stage_page.get_selected_stage_difficulty(),
		prepare_page.get_stage_difficulty_text(),
		settle_page.get_stage_difficulty_text(),
		str(saved_config.get("stage_difficulty_id", "")).strip_edges(),
	]

	for stage_difficulty_id in _as_array(saved_config.get("recent_stage_difficulty_ids", [])):
		candidates.append(str(stage_difficulty_id).strip_edges())

	return candidates


func _extract_monster_ids(payload: Dictionary) -> PackedStringArray:
	var monster_ids: PackedStringArray = []
	for monster in _as_array(payload.get("monster_list", [])):
		var entry := _as_dictionary(monster)
		var monster_id = str(entry.get("monster_id", ""))
		if monster_id.is_empty():
			continue
		monster_ids.append(monster_id)

	return monster_ids


func _parse_character_id(value: Variant) -> int:
	var trimmed := _normalize_id_string(value)
	if trimmed.is_empty() or not trimmed.is_valid_int():
		return -1
	return int(trimmed)


func _normalize_id_string(value: Variant) -> String:
	return ClientConfigStoreScript.normalize_id_string(value)


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

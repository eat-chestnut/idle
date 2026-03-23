extends Control

const BackendApiScript = preload("res://client/scripts/backend_api.gd")
const ClientConfigStoreScript = preload("res://client/scripts/client_config_store.gd")
const LocalGameStateScript = preload("res://client/scripts/local_game_state.gd")
const LocalSaveDataScript = preload("res://client/scripts/local_save_data.gd")
const LocalSaveServiceScript = preload("res://client/scripts/local_save_service.gd")
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
const CLIENT_SUBTITLE := "启动只看一眼世界，进局后就按本地节奏刷图成长。"
const DEFAULT_CONFIG_NOTE := (
	"这组值只用于启动检查和旧接口兼容；"
	+ "当前正式方向是启动检查一次，进入游戏后逐步以本地 runtime state 为真相。"
)
const DEFAULT_LOCAL_DATA_VERSION := "embedded-dev"
const DEFAULT_LOCAL_RESOURCE_VERSION := "not_declared"

var api
var runtime_state
var saved_config: Dictionary = {}
var current_local_save: Dictionary = {}
var current_local_save_action := ""
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
var current_dungeon_summary: Dictionary = {}
var current_dungeon_records: Dictionary = {}
var current_character_equipment_feedback: Dictionary = {}
var current_prepared_monster_ids: PackedStringArray = []
var recent_battle_context_ids: Array = []
var has_loaded_character_list := false
var has_loaded_stages := false
var has_loaded_difficulties := false
var _is_applying_config := false
var _character_auto_sync_in_flight := false
var _stage_auto_sync_in_flight := false
var _has_attempted_startup_check := false
var _local_save_ready := false
var _boot_sequence_started := false
var _allow_battle_page_restore := false


func _ready() -> void:
	saved_config = ClientConfigStoreScript.load_config()
	runtime_state = LocalGameStateScript.new()
	runtime_state.apply_saved_config(saved_config)
	api = BackendApiScript.new(self, saved_config.get("base_url", ""), saved_config.get("bearer_token", ""))
	_build_ui()
	_apply_saved_config()
	_set_initial_states()
	_refresh_startup_entry_state("empty", "启动时会先做一次检查，再决定继续游戏还是新开一局。")
	_refresh_flow_summary()
	call_deferred("_run_boot_sequence")


func _run_boot_sequence() -> void:
	if _boot_sequence_started:
		return

	_boot_sequence_started = true
	if DisplayServer.get_name() != "headless":
		await _run_startup_check_on_boot()

	_restore_or_initialize_local_save_on_boot()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_restore_runtime_entry_after_boot()
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
	_is_applying_config = false
	_refresh_runtime_config_snapshot()


func _set_initial_states() -> void:
	config_page.set_page_state("empty", "这一页会先完成启动检查，并接住本地存档的继续 / 新开局入口。")
	config_page.set_summary_text("当前正式边界：启动检查负责世界快照，本地存档负责继续游戏；两者都会写进本地运行时。")
	config_page.set_output_text("尚未生成启动检查或本地存档摘要。")

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
	saved_config["local_app_version"] = _resolve_local_app_version()
	saved_config["local_data_version"] = _resolve_local_data_version()
	saved_config["local_resource_version"] = _resolve_local_resource_version()
	saved_config["class_id"] = create_payload.get("class_id", "")
	saved_config["character_name"] = create_payload.get("character_name", "")

	api.update_credentials(saved_config.get("base_url", ""), saved_config.get("bearer_token", ""))
	if runtime_state != null:
		runtime_state.replace_state({
			"config": {
				"base_url": str(saved_config.get("base_url", "")).strip_edges(),
				"bearer_token": str(saved_config.get("bearer_token", "")).strip_edges(),
				"local_app_version": _resolve_local_app_version(),
				"local_data_version": _resolve_local_data_version(),
				"local_resource_version": _resolve_local_resource_version(),
			},
			"startup_snapshot": _as_dictionary(saved_config.get("startup_snapshot", {})),
		})


func _persist_client_config() -> void:
	_refresh_runtime_config_snapshot()
	if runtime_state != null:
		saved_config = runtime_state.export_saved_config(saved_config)
	ClientConfigStoreScript.save_config(saved_config)


func _persist_runtime_config() -> void:
	_persist_client_config()


func _autosave_local_progress(reason: String) -> void:
	if not _local_save_ready:
		return

	_refresh_runtime_config_snapshot()
	_persist_local_save(reason)


func _resolve_local_app_version() -> String:
	var configured_version := str(saved_config.get("local_app_version", "")).strip_edges()
	if not configured_version.is_empty():
		return configured_version

	var project_version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if not project_version.is_empty():
		return project_version

	return "dev-local"


func _resolve_local_data_version() -> String:
	var configured_version := str(saved_config.get("local_data_version", "")).strip_edges()
	if configured_version.is_empty():
		return DEFAULT_LOCAL_DATA_VERSION
	return configured_version


func _resolve_local_resource_version() -> String:
	var configured_version := str(saved_config.get("local_resource_version", "")).strip_edges()
	if configured_version.is_empty():
		return DEFAULT_LOCAL_RESOURCE_VERSION
	return configured_version


func _selected_stage_difficulty_id() -> String:
	if not prepare_page.get_stage_difficulty_text().is_empty():
		return prepare_page.get_stage_difficulty_text()
	if not stage_page.get_selected_stage_difficulty().is_empty():
		return stage_page.get_selected_stage_difficulty()
	return settle_page.get_stage_difficulty_text()


func _sync_local_runtime_from_legacy_cache() -> void:
	if runtime_state == null:
		return

	runtime_state.replace_state({
		"config": {
			"base_url": str(saved_config.get("base_url", "")).strip_edges(),
			"bearer_token": str(saved_config.get("bearer_token", "")).strip_edges(),
			"local_app_version": _resolve_local_app_version(),
			"local_data_version": _resolve_local_data_version(),
			"local_resource_version": _resolve_local_resource_version(),
		},
		"startup_snapshot": _as_dictionary(saved_config.get("startup_snapshot", {})),
		"character_list": current_character_list,
		"character_detail": current_character_detail,
		"inventory": current_inventory,
		"slots": current_slots,
		"chapters": current_chapters,
		"stages": current_stages,
		"difficulties": current_difficulties,
		"reward_status": current_reward_status,
		"prepare_result": current_prepare_result,
		"settle_result": current_settle_result,
		"dungeon_summary": current_dungeon_summary,
		"dungeon_records": current_dungeon_records,
		"character_equipment_feedback": current_character_equipment_feedback,
		"prepared_monster_ids": current_prepared_monster_ids,
		"recent_battle_context_ids": recent_battle_context_ids,
		"selections": {
			"character_id": character_page.get_character_id_text(),
			"battle_character_id": prepare_page.get_character_id_text(),
			"equipment_character_id": equipment_page.get_character_id_text(),
			"chapter_id": stage_page.get_selected_chapter_id(),
			"stage_id": stage_page.get_stage_id_text(),
			"stage_difficulty_id": _selected_stage_difficulty_id(),
			"battle_context_id": settle_page.get_battle_context_text(),
		},
	})


func _sync_legacy_cache_from_runtime_state() -> void:
	current_character_list = _runtime_character_list()
	current_character_detail = _runtime_character_detail()
	current_inventory = _runtime_inventory()
	current_slots = _runtime_slots()
	current_chapters = _runtime_chapters()
	current_stages = _runtime_stages()
	current_difficulties = _runtime_difficulties()
	current_reward_status = _runtime_reward_status()
	current_prepare_result = _runtime_prepare_result()
	current_settle_result = _runtime_settle_result()
	current_dungeon_summary = _runtime_dungeon_summary()
	current_dungeon_records = _runtime_dungeon_records()
	current_character_equipment_feedback = _runtime_equipment_feedback()
	current_prepared_monster_ids = _runtime_prepared_monster_ids()
	recent_battle_context_ids = _runtime_recent_battle_context_ids()
	has_loaded_character_list = not _as_array(current_character_list.get("characters", [])).is_empty()
	has_loaded_stages = not _as_array(current_stages.get("stages", [])).is_empty()
	has_loaded_difficulties = not _as_array(current_difficulties.get("difficulties", [])).is_empty()


func _build_local_save_preferences() -> Dictionary:
	return {
		"character_id": _runtime_character_selection(),
		"battle_character_id": _runtime_battle_character_selection(),
		"equipment_character_id": _runtime_equipment_character_selection(),
		"chapter_id": _runtime_selected_chapter_id(),
		"stage_id": _runtime_selected_stage_id(),
		"stage_difficulty_id": _runtime_selected_stage_difficulty_id(),
		"battle_context_id": _runtime_battle_context_selection(),
		"recent_characters": _as_array(saved_config.get("recent_characters", [])),
		"recent_chapter_ids": _as_array(saved_config.get("recent_chapter_ids", [])),
		"recent_stage_ids": _as_array(saved_config.get("recent_stage_ids", [])),
		"recent_stage_difficulty_ids": _as_array(saved_config.get("recent_stage_difficulty_ids", [])),
	}


func _apply_local_save_preferences(save_payload: Dictionary) -> void:
	var preferences := LocalSaveDataScript.extract_save_preferences(save_payload)
	saved_config["character_id"] = str(preferences.get("character_id", "")).strip_edges()
	saved_config["battle_character_id"] = str(
		preferences.get("battle_character_id", saved_config.get("character_id", ""))
	).strip_edges()
	saved_config["chapter_id"] = str(preferences.get("chapter_id", "")).strip_edges()
	saved_config["stage_id"] = str(preferences.get("stage_id", "")).strip_edges()
	saved_config["stage_difficulty_id"] = str(preferences.get("stage_difficulty_id", "")).strip_edges()
	saved_config["recent_characters"] = _as_array(preferences.get("recent_characters", []))
	saved_config["recent_chapter_ids"] = _as_array(preferences.get("recent_chapter_ids", []))
	saved_config["recent_stage_ids"] = _as_array(preferences.get("recent_stage_ids", []))
	saved_config["recent_stage_difficulty_ids"] = _as_array(preferences.get("recent_stage_difficulty_ids", []))


func _apply_runtime_selections_to_pages() -> void:
	_is_applying_config = true
	var selections: Dictionary = runtime_state.get_dictionary_state("selections") if runtime_state != null else {}
	var detail_character_id := _normalize_id_string(selections.get("character_id", ""))
	var battle_character_id := _normalize_id_string(selections.get("battle_character_id", ""))
	var equipment_character_id := _normalize_id_string(selections.get("equipment_character_id", ""))
	var chapter_id := str(selections.get("chapter_id", "")).strip_edges()
	var stage_id := str(selections.get("stage_id", "")).strip_edges()
	var stage_difficulty_id := str(selections.get("stage_difficulty_id", "")).strip_edges()
	var battle_context_id := str(selections.get("battle_context_id", "")).strip_edges()

	character_page.set_character_id(detail_character_id)
	equipment_page.set_character_id(
		equipment_character_id if not equipment_character_id.is_empty() else detail_character_id
	)
	prepare_page.set_character_id(
		battle_character_id if not battle_character_id.is_empty() else detail_character_id
	)
	settle_page.set_character_id(
		battle_character_id if not battle_character_id.is_empty() else detail_character_id
	)
	stage_page.set_selected_chapter_id(chapter_id)
	stage_page.set_stage_id(stage_id)
	stage_page.set_selected_stage_difficulty(stage_difficulty_id)
	prepare_page.set_stage_difficulty_id(stage_difficulty_id)
	settle_page.set_stage_difficulty_id(stage_difficulty_id)
	settle_page.set_battle_context_id(battle_context_id)
	settle_page.set_killed_monsters(_runtime_prepared_monster_ids())
	_apply_runtime_ui_focus_to_pages()
	_is_applying_config = false


func _apply_runtime_ui_focus_to_pages() -> void:
	var inventory_section := _runtime_inventory_focus_section()
	var equipment_slot_key := _runtime_equipment_focus_slot_key()
	var equipment_instance_id := _runtime_equipment_focus_instance_id()

	inventory_page.set_selected_section(inventory_section)
	equipment_page.set_target_slot_key(equipment_slot_key)
	equipment_page.set_selected_equipment_instance(equipment_instance_id)


func _restore_or_initialize_local_save_on_boot() -> void:
	var inspection := LocalSaveServiceScript.inspect_save()
	var result: Dictionary = {}
	if inspection.get("valid", false):
		result = {
			"ok": true,
			"data": inspection.get("data", {}),
			"path": inspection.get("path", LocalSaveServiceScript.SAVE_PATH),
			"action": "loaded",
		}
	else:
		result = LocalSaveServiceScript.create_new_save()
		if result.get("ok", false):
			result["action"] = (
				"created"
				if not bool(inspection.get("exists", false))
				else "recreated"
			)
			if inspection.has("error"):
				result["previous_error"] = inspection.get("error", {})

	if not result.get("ok", false):
		var failure_message := "本地正式存档暂时没能建立：%s" % str(result.get("message", inspection.get("message", "未知原因")))
		current_local_save = {}
		current_local_save_action = "error"
		_local_save_ready = false
		_allow_battle_page_restore = false
		if runtime_state != null:
			runtime_state.set_local_save_meta({
				"has_save": false,
				"message": failure_message,
			})
		config_page.set_page_state("error", failure_message)
		return

	_apply_local_save_result(result)


func _apply_local_save_result(result: Dictionary) -> void:
	current_local_save = _as_dictionary(result.get("data", {}))
	current_local_save_action = str(result.get("action", "loaded")).strip_edges()
	_local_save_ready = true
	_allow_battle_page_restore = false
	if runtime_state != null:
		runtime_state.apply_local_save(current_local_save)
	_apply_local_save_preferences(current_local_save)
	_sync_legacy_cache_from_runtime_state()
	_apply_runtime_selections_to_pages()
	_persist_client_config()
	_apply_local_save_page_states(current_local_save_action)


func _persist_local_save(reason: String = "autosave") -> void:
	if runtime_state == null or not _local_save_ready:
		return

	var result := LocalSaveServiceScript.overwrite_save(
		runtime_state.export_local_save(current_local_save, _build_local_save_preferences()),
		"saved"
	)
	if not result.get("ok", false):
		push_warning("Failed to save local save (%s): %s" % [reason, str(result.get("message", "unknown"))])
		return

	current_local_save = _as_dictionary(result.get("data", {}))
	runtime_state.set_local_save_meta(LocalSaveDataScript.extract_save_meta(current_local_save))


func _runtime_startup_snapshot() -> Dictionary:
	if runtime_state == null:
		return _as_dictionary(saved_config.get("startup_snapshot", {}))
	return runtime_state.get_dictionary_state("startup_snapshot")


func _runtime_local_save_meta() -> Dictionary:
	if runtime_state == null:
		return {}
	return runtime_state.get_dictionary_state("local_save_meta")


func _runtime_selection(selection_key: String, fallback: String = "") -> String:
	if runtime_state == null:
		return fallback.strip_edges()
	return runtime_state.get_selection_or(selection_key, fallback)


func _runtime_ui_focus() -> Dictionary:
	if runtime_state == null:
		return {}
	return runtime_state.get_dictionary_state("ui_focus")


func _runtime_character_selection() -> String:
	return _runtime_selection("character_id", character_page.get_character_id_text())


func _runtime_battle_character_selection() -> String:
	return _runtime_selection("battle_character_id", prepare_page.get_character_id_text())


func _runtime_equipment_character_selection() -> String:
	return _runtime_selection("equipment_character_id", equipment_page.get_character_id_text())


func _runtime_selected_chapter_id() -> String:
	return _runtime_selection("chapter_id", stage_page.get_selected_chapter_id())


func _runtime_selected_stage_id() -> String:
	return _runtime_selection("stage_id", stage_page.get_stage_id_text())


func _runtime_selected_stage_difficulty_id() -> String:
	return _runtime_selection("stage_difficulty_id", _selected_stage_difficulty_id())


func _runtime_battle_context_selection() -> String:
	return _runtime_selection("battle_context_id", settle_page.get_battle_context_text())


func _runtime_active_page_key() -> String:
	if runtime_state == null:
		return CONFIG_PAGE
	return runtime_state.get_active_page_key(CONFIG_PAGE)


func _runtime_inventory_focus_section() -> String:
	var focus := _runtime_ui_focus()
	var section := str(focus.get("inventory_section", "all")).strip_edges()
	if section.is_empty():
		return "all"
	return section


func _runtime_inventory_focus_equipment_instance_id() -> String:
	return _normalize_id_string(_runtime_ui_focus().get("inventory_equipment_instance_id", ""))


func _runtime_equipment_focus_slot_key() -> String:
	return str(_runtime_ui_focus().get("equipment_target_slot_key", "")).strip_edges()


func _runtime_equipment_focus_instance_id() -> String:
	return _normalize_id_string(_runtime_ui_focus().get("equipment_focus_instance_id", ""))


func _update_runtime_focus(selection_patch: Dictionary = {}, ui_focus_patch: Dictionary = {}) -> void:
	if runtime_state == null:
		return
	if not selection_patch.is_empty():
		runtime_state.set_selections(selection_patch)
	if not ui_focus_patch.is_empty():
		runtime_state.update_ui_focus(ui_focus_patch)


func _remember_active_page_key(page_key: String, autosave_reason: String = "") -> void:
	var normalized_page_key := page_key.strip_edges()
	if normalized_page_key.is_empty():
		return

	if runtime_state != null:
		runtime_state.set_active_page_key(normalized_page_key)
	if not autosave_reason.is_empty():
		_autosave_local_progress(autosave_reason)


func _runtime_character_list() -> Dictionary:
	if runtime_state == null:
		return current_character_list.duplicate(true)
	return runtime_state.get_dictionary_state("character_list")


func _runtime_character_detail() -> Dictionary:
	if runtime_state == null:
		return current_character_detail.duplicate(true)
	return runtime_state.get_dictionary_state("character_detail")


func _runtime_inventory() -> Dictionary:
	if runtime_state == null:
		return current_inventory.duplicate(true)
	return runtime_state.get_dictionary_state("inventory")


func _runtime_slots() -> Dictionary:
	if runtime_state == null:
		return current_slots.duplicate(true)
	return runtime_state.get_dictionary_state("slots")


func _runtime_chapters() -> Dictionary:
	if runtime_state == null:
		return current_chapters.duplicate(true)
	return runtime_state.get_dictionary_state("chapters")


func _runtime_stages() -> Dictionary:
	if runtime_state == null:
		return current_stages.duplicate(true)
	return runtime_state.get_dictionary_state("stages")


func _runtime_difficulties() -> Dictionary:
	if runtime_state == null:
		return current_difficulties.duplicate(true)
	return runtime_state.get_dictionary_state("difficulties")


func _runtime_reward_status() -> Dictionary:
	if runtime_state == null:
		return current_reward_status.duplicate(true)
	return runtime_state.get_dictionary_state("reward_status")


func _runtime_prepare_result() -> Dictionary:
	if runtime_state == null:
		return current_prepare_result.duplicate(true)
	return runtime_state.get_dictionary_state("prepare_result")


func _runtime_settle_result() -> Dictionary:
	if runtime_state == null:
		return current_settle_result.duplicate(true)
	return runtime_state.get_dictionary_state("settle_result")


func _runtime_dungeon_summary() -> Dictionary:
	if runtime_state == null:
		return current_dungeon_summary.duplicate(true)
	return runtime_state.get_dictionary_state("dungeon_summary")


func _runtime_dungeon_records() -> Dictionary:
	if runtime_state == null:
		return current_dungeon_records.duplicate(true)
	return runtime_state.get_dictionary_state("dungeon_records")


func _runtime_equipment_feedback() -> Dictionary:
	if runtime_state == null:
		return current_character_equipment_feedback.duplicate(true)
	return runtime_state.get_dictionary_state("character_equipment_feedback")


func _runtime_recent_battle_context_ids() -> Array:
	if runtime_state == null:
		return recent_battle_context_ids.duplicate(true)
	return runtime_state.get_array_state("recent_battle_context_ids")


func _runtime_prepared_monster_ids() -> PackedStringArray:
	if runtime_state == null:
		return PackedStringArray(current_prepared_monster_ids)
	return runtime_state.get_packed_string_array_state("prepared_monster_ids")


func _build_localized_settle_result(data: Dictionary, stage_difficulty_id_value: String) -> Dictionary:
	var localized := data.duplicate(true)
	var dungeon_summary := _runtime_dungeon_summary()
	if dungeon_summary.is_empty():
		dungeon_summary = current_dungeon_summary.duplicate(true)
	if dungeon_summary.is_empty():
		return localized

	var record_stage_difficulty_id := stage_difficulty_id_value
	if record_stage_difficulty_id.is_empty():
		record_stage_difficulty_id = str(dungeon_summary.get("stage_difficulty_id", "")).strip_edges()

	dungeon_summary["stage_difficulty_id"] = record_stage_difficulty_id
	dungeon_summary["settled"] = true
	var dungeon_result_type := (
		"full_clear"
		if bool(dungeon_summary.get("full_clear_completed", false))
		else ("boss_clear" if int(localized.get("is_cleared", 0)) == 1 else "partial")
	)
	dungeon_summary["settle_result_type"] = dungeon_result_type

	var updated_records := _record_dungeon_completion(record_stage_difficulty_id, dungeon_summary)
	current_dungeon_summary = dungeon_summary.duplicate(true)
	current_dungeon_records = updated_records.duplicate(true)

	localized["dungeon_summary"] = current_dungeon_summary
	localized["dungeon_record"] = _as_dictionary(updated_records.get(record_stage_difficulty_id, {}))
	localized["dungeon_result_type"] = dungeon_result_type
	localized["full_clear_recorded"] = bool(dungeon_summary.get("full_clear_completed", false))
	if bool(dungeon_summary.get("boss_defeated", false)):
		localized["boss_clear_elapsed_seconds"] = float(dungeon_summary.get("boss_defeated_elapsed_seconds", 0.0))
	if bool(dungeon_summary.get("full_clear_completed", false)):
		localized["full_clear_elapsed_seconds"] = float(dungeon_summary.get("full_clear_elapsed_seconds", 0.0))
	return localized


func _record_dungeon_completion(stage_difficulty_id: String, dungeon_summary: Dictionary) -> Dictionary:
	var updated_records := _runtime_dungeon_records()
	if updated_records.is_empty():
		updated_records = current_dungeon_records.duplicate(true)
	else:
		updated_records = updated_records.duplicate(true)

	var normalized_stage_difficulty_id := stage_difficulty_id.strip_edges()
	if normalized_stage_difficulty_id.is_empty():
		normalized_stage_difficulty_id = str(dungeon_summary.get("stage_difficulty_id", "")).strip_edges()
	if normalized_stage_difficulty_id.is_empty():
		return updated_records

	var record := _as_dictionary(updated_records.get(normalized_stage_difficulty_id, {})).duplicate(true)
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var battle_context_id := str(dungeon_summary.get("battle_context_id", "")).strip_edges()
	if (
		not battle_context_id.is_empty()
		and str(record.get("last_recorded_battle_context_id", "")).strip_edges() == battle_context_id
	):
		return updated_records
	record["stage_difficulty_id"] = normalized_stage_difficulty_id
	record["stage_name"] = str(dungeon_summary.get("stage_name", "")).strip_edges()
	record["difficulty_name"] = str(dungeon_summary.get("difficulty_name", "")).strip_edges()
	record["last_recorded_battle_context_id"] = battle_context_id

	if bool(dungeon_summary.get("boss_defeated", false)):
		record["last_boss_clear_at"] = timestamp
		record["boss_clear_count"] = maxi(int(record.get("boss_clear_count", 0)) + 1, 1)
		var boss_clear_seconds := float(dungeon_summary.get("boss_defeated_elapsed_seconds", 0.0))
		if boss_clear_seconds > 0.0:
			record["last_boss_clear_seconds"] = boss_clear_seconds

	if bool(dungeon_summary.get("full_clear_completed", false)):
		record["last_full_clear_at"] = timestamp
		record["full_clear_count"] = maxi(int(record.get("full_clear_count", 0)) + 1, 1)
		var full_clear_seconds := float(dungeon_summary.get("full_clear_elapsed_seconds", 0.0))
		if full_clear_seconds > 0.0:
			record["last_full_clear_seconds"] = full_clear_seconds
			var best_full_clear_seconds := float(record.get("best_full_clear_seconds", 0.0))
			if best_full_clear_seconds <= 0.0 or full_clear_seconds < best_full_clear_seconds:
				record["best_full_clear_seconds"] = full_clear_seconds

	updated_records[normalized_stage_difficulty_id] = record
	return updated_records


func _restore_cached_startup_snapshot() -> void:
	var state_kind := "error" if current_local_save_action == "error" else "success"
	_refresh_startup_entry_state(state_kind, _build_local_save_action_message(current_local_save_action, true))


func _run_startup_check_on_boot() -> void:
	if _has_attempted_startup_check:
		return

	_has_attempted_startup_check = true
	_refresh_runtime_config_snapshot()

	if str(saved_config.get("base_url", "")).strip_edges().is_empty():
		_refresh_startup_entry_state("empty", "启动检查还没开始，先补启动检查地址。")
		_refresh_flow_summary()
		return

	await _execute_startup_check(true)


func _on_run_startup_check_pressed() -> void:
	_has_attempted_startup_check = true
	await _execute_startup_check(false)


func _execute_startup_check(from_boot: bool) -> void:
	_persist_runtime_config()
	config_page.set_page_state(
		"loading",
		"启动中，正在生成一次启动快照。"
		if from_boot
		else "正在重做启动检查并刷新本地快照。"
	)

	var local_versions := {
		"local_app_version": _resolve_local_app_version(),
		"local_data_version": _resolve_local_data_version(),
		"local_resource_version": _resolve_local_resource_version(),
	}
	var result: Dictionary = await api.request_startup_check(local_versions)

	if not result.get("ok", false):
		var failure_snapshot := _build_failed_startup_snapshot(result, local_versions)
		saved_config["startup_snapshot"] = failure_snapshot
		_sync_local_runtime_from_legacy_cache()
		_persist_runtime_config()
		_refresh_startup_entry_state(
			"error",
			"启动检查失败：%s" % str(result.get("message", "当前世界暂时没接通。"))
		)
		_refresh_flow_summary()
		return

	var startup_snapshot := _as_dictionary(result.get("data", {}))
	saved_config["startup_snapshot"] = startup_snapshot
	_sync_local_runtime_from_legacy_cache()
	_persist_runtime_config()

	var diagnosis := _as_dictionary(startup_snapshot.get("diagnosis", {}))
	var failures := int(diagnosis.get("failures", 0))
	var warnings := int(diagnosis.get("warnings", 0))
	var state_kind := "success" if bool(startup_snapshot.get("ready", false)) else "error"
	_refresh_startup_entry_state(
		state_kind,
		"启动检查完成：failures=%d，warnings=%d。"
		% [failures, warnings]
	)
	_refresh_flow_summary()


func _build_failed_startup_snapshot(result: Dictionary, local_versions: Dictionary) -> Dictionary:
	return {
		"checked_at": Time.get_datetime_string_from_system(false, true),
		"source": "/readyz?profile=interop",
		"network_mode": "startup_check_only",
		"ready": false,
		"profile": "interop",
		"versions": {
			"app": {
				"local": str(local_versions.get("local_app_version", "dev-local")),
				"remote": "unknown",
				"status": "unknown",
			},
			"data": {
				"local": str(local_versions.get("local_data_version", DEFAULT_LOCAL_DATA_VERSION)),
				"remote": "unknown",
				"status": "unknown",
			},
			"resource": {
				"local": str(local_versions.get("local_resource_version", DEFAULT_LOCAL_RESOURCE_VERSION)),
				"remote": "not_declared",
				"status": "not_declared",
			},
		},
		"services": {
			"save_upload": {
				"available": false,
				"status": "unknown",
				"message": "启动检查失败，未取回上传服务快照。",
			},
			"save_download": {
				"available": false,
				"status": "unknown",
				"message": "启动检查失败，未取回下载服务快照。",
			},
		},
		"diagnosis": {
			"status": "request_failed",
			"failures": 1,
			"warnings": 0,
			"app_env": "",
		},
		"message": str(result.get("message", "启动检查失败。")),
		"raw_readiness": result.get("raw", {}),
	}


func _build_startup_snapshot_summary(snapshot: Dictionary) -> String:
	var versions := _as_dictionary(snapshot.get("versions", {}))
	var services := _as_dictionary(snapshot.get("services", {}))
	var diagnosis := _as_dictionary(snapshot.get("diagnosis", {}))
	return "启动快照：游戏 %s，数据 %s，资源 %s，存档上传 %s，存档下载 %s。状态：ready=%s，failures=%d，warnings=%d。" % [
		_describe_version_snapshot(_as_dictionary(versions.get("app", {}))),
		_describe_version_snapshot(_as_dictionary(versions.get("data", {}))),
		_describe_version_snapshot(_as_dictionary(versions.get("resource", {}))),
		_describe_service_snapshot(_as_dictionary(services.get("save_upload", {}))),
		_describe_service_snapshot(_as_dictionary(services.get("save_download", {}))),
		str(snapshot.get("ready", false)),
		int(diagnosis.get("failures", 0)),
		int(diagnosis.get("warnings", 0)),
	]


func _build_local_save_action_message(action: String, from_boot: bool = false) -> String:
	match action:
		"created":
			return (
				"当前还没有本地正式存档，已先为你开一局默认单机进度。"
				if not from_boot
				else "启动检查完成后，已建立默认本地存档并进入新开局初始化。"
			)
		"recreated":
			return (
				"检测到旧本地存档已失效，已重建为默认单机进度。"
				if not from_boot
				else "启动检查完成后，已用默认新进度重建本地存档。"
			)
		"saved":
			return "本地正式存档已覆盖保存。"
		"error":
			return "本地正式存档暂时不可用。"
		_:
			return (
				"已从本地正式存档恢复当前进度。"
				if not from_boot
				else "启动检查完成后，已从本地正式存档恢复当前进度。"
			)


func _build_local_save_summary() -> String:
	var save_meta := _runtime_local_save_meta()
	if save_meta.is_empty() or not bool(save_meta.get("has_save", false)):
		return "本地存档：尚未建立。"

	var character_count := int(save_meta.get("character_count", 0))
	var route_summary := _build_flow_route_summary(_build_route_context(_runtime_selected_stage_difficulty_id()))
	var updated_at := str(save_meta.get("updated_at", "")).strip_edges()
	var pending_battle_note := ""
	if bool(save_meta.get("has_pending_battle_context", false)):
		pending_battle_note = " 最近一次出战上下文已保留，但战斗进行中的瞬时表现不会跨启动恢复。"
	if character_count <= 0:
		return "本地存档：默认新开局已就位，当前目标 %s。最近保存：%s。%s" % [
			route_summary,
			updated_at if not updated_at.is_empty() else "刚刚",
			pending_battle_note,
		]

	return "本地存档：已恢复 %d 名角色，当前主角 %s，目标 %s。最近保存：%s。%s" % [
		character_count,
		_describe_character(_runtime_character_selection()),
		route_summary,
		updated_at if not updated_at.is_empty() else "刚刚",
		pending_battle_note,
	]


func _build_startup_entry_output() -> Dictionary:
	return {
		"local_save": {
			"path": LocalSaveServiceScript.SAVE_PATH,
			"action": current_local_save_action,
			"meta": _runtime_local_save_meta(),
			"preferences": LocalSaveDataScript.extract_save_preferences(current_local_save) if not current_local_save.is_empty() else {},
		},
		"startup_snapshot": _runtime_startup_snapshot(),
	}


func _current_startup_page_status() -> String:
	var startup_snapshot := _runtime_startup_snapshot()
	if startup_snapshot.is_empty():
		return "empty"
	return "success" if bool(startup_snapshot.get("ready", false)) else "error"


func _refresh_startup_entry_state(page_status: String = "", message: String = "") -> void:
	if not page_status.is_empty() and not message.is_empty():
		config_page.set_page_state(page_status, message)

	var lines := [_build_local_save_summary()]
	var startup_snapshot := _runtime_startup_snapshot()
	if startup_snapshot.is_empty():
		lines.append("启动快照：尚未生成。")
	else:
		lines.append(_build_startup_snapshot_summary(startup_snapshot))
	config_page.set_summary_text("\n".join(lines))
	config_page.set_output_json(_build_startup_entry_output())


func _apply_local_save_page_states(action: String) -> void:
	_refresh_startup_entry_state(_current_startup_page_status(), _build_local_save_action_message(action, true))

	if not _runtime_character_detail().is_empty() or not _as_array(_runtime_character_list().get("characters", [])).is_empty():
		character_page.set_page_state("success", "当前角色进度已从本地正式存档接回。")
	elif action != "loaded":
		character_page.set_page_state("empty", "当前是新开局；先创建一个角色，再开始这轮山海路。")

	if not _runtime_chapters().is_empty():
		stage_page.set_page_state("success", "当前章节、关卡和难度已从本地正式存档接回。")

	var inventory_payload := _runtime_inventory()
	var inventory_count := _as_array(inventory_payload.get("stack_items", [])).size() + _as_array(inventory_payload.get("equipment_items", [])).size()
	if inventory_count > 0:
		inventory_page.set_page_state("success", "背包快照已从本地正式存档接回。")

	if not _runtime_slots().is_empty():
		equipment_page.set_page_state("success", "当前穿戴快照已从本地正式存档接回。")

	if not _runtime_prepare_result().is_empty():
		prepare_page.set_page_state("success", "最近一次出战信息已从本地正式存档接回。")
		battle_page.set_page_state(
			"empty",
			"本地存档只恢复最近一次出战上下文，不恢复战斗进行中的瞬时表现；如要继续推进，请从出战页重新进入。"
		)

	if not _runtime_settle_result().is_empty():
		settle_page.set_page_state("success", "最近一次结算结果已从本地正式存档接回。")


func _describe_version_snapshot(snapshot: Dictionary) -> String:
	var local_value := str(snapshot.get("local", "unknown")).strip_edges()
	var remote_value := str(snapshot.get("remote", "unknown")).strip_edges()
	var status := str(snapshot.get("status", "unknown")).strip_edges()
	match status:
		"match":
			return "本地 %s / 远端 %s（已对齐）" % [local_value, remote_value]
		"mismatch":
			return "本地 %s / 远端 %s（待确认）" % [local_value, remote_value]
		"not_declared":
			return "本地 %s / 远端未声明" % local_value
		_:
			return "本地 %s / 远端未知" % local_value


func _describe_service_snapshot(snapshot: Dictionary) -> String:
	var status := str(snapshot.get("status", "unknown")).strip_edges()
	if bool(snapshot.get("available", false)):
		return "可用"
	if status == "not_declared":
		return "未声明"
	return "待确认"


func _refresh_recent_selectors() -> void:
	var recent_characters = _build_available_character_records()
	var recent_stage_difficulty_ids: Array = _build_available_stage_difficulty_ids()
	var selected_character_id := _runtime_character_selection()
	var selected_battle_character_id := _runtime_battle_character_selection()
	var selected_equipment_character_id := _runtime_equipment_character_selection()
	var selected_stage_difficulty_id := _runtime_selected_stage_difficulty_id()
	var selected_battle_context_id := _runtime_battle_context_selection()

	if has_loaded_character_list:
		character_page.set_character_list(
			_as_array(_runtime_character_list().get("characters", [])),
			selected_character_id
		)
	else:
		character_page.set_recent_characters(recent_characters, selected_character_id)

	equipment_page.set_recent_characters(recent_characters, selected_equipment_character_id)
	prepare_page.set_recent_characters(recent_characters, selected_battle_character_id)
	settle_page.set_recent_characters(recent_characters, selected_battle_character_id)

	stage_page.set_selected_stage_difficulty(selected_stage_difficulty_id)
	prepare_page.set_recent_stage_difficulties(
		recent_stage_difficulty_ids,
		selected_stage_difficulty_id
	)
	settle_page.set_recent_stage_difficulties(
		recent_stage_difficulty_ids,
		selected_stage_difficulty_id
	)
	settle_page.set_recent_battle_contexts(_runtime_recent_battle_context_ids(), selected_battle_context_id)


func _build_available_character_records() -> Array:
	if has_loaded_character_list:
		return _as_array(_runtime_character_list().get("characters", []))

	return _build_recent_character_records()


func _build_available_stage_difficulty_ids() -> Array:
	if has_loaded_difficulties:
		var difficulty_ids: Array = []
		for difficulty in _as_array(_runtime_difficulties().get("difficulties", [])):
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
	for chapter in _as_array(_runtime_chapters().get("chapters", [])):
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
		_as_dictionary(_runtime_character_detail().get("character", {}))
	)
	recent = _prepend_character_record(
		recent,
		_as_dictionary(_runtime_prepare_result().get("character", {}))
	)
	recent = _prepend_character_record(
		recent,
		_runtime_character_stub(_runtime_character_selection(), "当前角色输入")
	)
	recent = _prepend_character_record(
		recent,
		_runtime_character_stub(_runtime_battle_character_selection(), "当前出战角色")
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

	var current_detail_character_id = _runtime_character_selection()
	if _runtime_character_detail().is_empty() or not _records_contain_character(records, current_detail_character_id):
		current_character_detail = {"character": active_character}
		character_page.set_character_id(active_character_id)
		equipment_page.set_character_id(active_character_id)


func _runtime_character_stub(character_id: String, fallback_name: String) -> Dictionary:
	var normalized_id = character_id.strip_edges()
	if normalized_id.is_empty():
		return {}

	var detail_character = _as_dictionary(_runtime_character_detail().get("character", {}))
	if _normalize_id_string(detail_character.get("character_id", "")) == normalized_id:
		return detail_character

	var prepare_character = _as_dictionary(_runtime_prepare_result().get("character", {}))
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
	_sync_local_runtime_from_legacy_cache()
	_sync_recent_characters_from_records(_as_array(_runtime_character_list().get("characters", [])))


func _upsert_character_in_current_list(character: Dictionary) -> void:
	if character.is_empty():
		return

	if not has_loaded_character_list:
		_remember_character(character)
		return

	var character_id = _normalize_id_string(character.get("character_id", ""))
	var merged: Array = []
	var found := false

	for record in _as_array(_runtime_character_list().get("characters", [])):
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
		source_records = _as_array(_runtime_character_list().get("characters", []))
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

	var detail_character := _as_dictionary(_runtime_character_detail().get("character", {})).duplicate(true)
	if detail_character.is_empty():
		return

	if _normalize_id_string(detail_character.get("character_id", "")) == active_character_id:
		current_character_detail = {"character": character}
	else:
		detail_character["is_active"] = 0
		current_character_detail = {"character": detail_character}


func _refresh_flow_summary() -> void:
	var config_values: Dictionary = config_page.get_config_values()
	var startup_snapshot := _runtime_startup_snapshot()
	var local_save_meta := _runtime_local_save_meta()
	var detail_character = _describe_character(_runtime_character_selection())
	var battle_character = _describe_character(_runtime_battle_character_selection())
	var route_context := _build_route_context(_runtime_selected_stage_difficulty_id())
	var dungeon_summary := _runtime_dungeon_summary()
	var battle_context_id = _runtime_battle_context_selection()
	var route_summary := _build_flow_route_summary(route_context)
	var save_line := "本地存档：等待建立。"
	var hero_line := "当前主角：待确认。"
	var target_line := "这轮目标：先完成启动检查，再踏上这一轮山海路。"
	var next_step_line := "现在最顺：启动时只联网一次，先把版本与存档服务快照写到本地。"
	var reminder_line := ""

	if not local_save_meta.is_empty() and bool(local_save_meta.get("has_save", false)):
		save_line = _build_local_save_summary()

	if str(config_values.get("base_url", "")).strip_edges().is_empty():
		target_line = "这轮目标：先把弱联网入口接上。"
		next_step_line = "现在最顺：先填启动检查地址。"
	elif startup_snapshot.is_empty():
		target_line = "这轮目标：先完成启动检查。"
		next_step_line = "现在最顺：执行一次启动检查，把版本和存档服务状态记到本地。"
	elif not bool(startup_snapshot.get("ready", false)):
		target_line = "这轮目标：先处理启动检查里暴露的缺口。"
		next_step_line = "现在最顺：先看启动页里的版本 / 服务提示，再决定是否继续旧接口兼容链。"
	else:
		var character_line: String = detail_character
		if detail_character != battle_character and battle_character != "待确认":
			character_line = "查看 %s，出战 %s" % [detail_character, battle_character]
		elif detail_character == "待确认" and battle_character != "待确认":
			character_line = battle_character

		hero_line = "当前主角：%s。" % character_line
		target_line = "这轮目标：%s。" % route_summary

		if detail_character == "待确认" and battle_character == "待确认":
			next_step_line = "现在最顺：先去角色页挑一个主角；如果还没有，就创建一个。"
		elif _runtime_selected_chapter_id().is_empty():
			next_step_line = "现在最顺：去主线页挑一章。"
		elif _runtime_selected_stage_id().is_empty():
			next_step_line = "现在最顺：这一章已经展开，先挑一关。"
		elif _runtime_selected_stage_difficulty_id().is_empty():
			next_step_line = "现在最顺：关卡已经锁定，再选一档难度。"
		elif not dungeon_summary.is_empty() and bool(dungeon_summary.get("full_clear_completed", false)) and _runtime_settle_result().is_empty():
			next_step_line = "现在最顺：这轮已经全清，去结算页把收益和完整通关时间一起收稳。"
		elif not dungeon_summary.is_empty() and bool(dungeon_summary.get("boss_defeated", false)) and _runtime_settle_result().is_empty():
			next_step_line = "现在最顺：Boss 已倒，可以立即结算，也可以回战斗页继续清图补完整通关时间。"
		elif not battle_context_id.is_empty():
			next_step_line = "现在最顺：副本已经展开，去战斗页推进；普通怪、精英和 Boss 都已按大地图分布入场。"
		elif _runtime_settle_result().is_empty():
			next_step_line = "现在最顺：目标已经锁定，去出战页决定要不要开打。"
		else:
			var created_equipment_instances := _as_array(_runtime_settle_result().get("created_equipment_instances", []))
			var inventory_results := _as_dictionary(_runtime_settle_result().get("inventory_results", {}))
			var inventory_entry_count := _as_array(inventory_results.get("stack_results", [])).size() + _as_array(inventory_results.get("equipment_instance_results", [])).size()
			if not created_equipment_instances.is_empty():
				next_step_line = "现在最顺：这轮有新装备，先去结算或穿戴把它试上身。"
			elif inventory_entry_count > 0:
				next_step_line = "现在最顺：这轮收益已经落袋，先去背包整理，再决定继续刷还是回主线。"
			else:
				next_step_line = "现在最顺：这轮已经收好，可以直接再打一场，或回主线换目标。"

		if not has_loaded_character_list and _runtime_character_detail().is_empty():
			reminder_line = "提醒：角色列表还没回齐，先去角色页确认当前主角。"

	var current_character = _as_dictionary(_runtime_character_detail().get("character", {}))
	if not current_character.is_empty() and int(current_character.get("is_active", 0)) == 0:
		reminder_line = "提醒：这名角色还没启用，先在角色页点“启用角色”会更顺。"
	elif not dungeon_summary.is_empty() and bool(dungeon_summary.get("full_clear_completed", false)):
		reminder_line = "提醒：完整通关时间 %.1f 秒已写入本地记录，可作为后续挂机 / 离线收益基础。" % float(
			dungeon_summary.get("full_clear_elapsed_seconds", 0.0)
		)
	elif not dungeon_summary.is_empty() and bool(dungeon_summary.get("boss_defeated", false)) and _runtime_settle_result().is_empty():
		reminder_line = "提醒：Boss 已倒但尚未全清；如果现在结算，不会记录完整通关时间。"

	var services := _as_dictionary(_runtime_startup_snapshot().get("services", {}))
	var save_upload := _as_dictionary(services.get("save_upload", {}))
	var save_download := _as_dictionary(services.get("save_download", {}))
	if (
		str(save_upload.get("status", "")).strip_edges() == "not_declared"
		or str(save_download.get("status", "")).strip_edges() == "not_declared"
	):
		reminder_line = "提醒：当前启动检查还未声明存档上传 / 下载状态，本轮先按弱联网占位处理。"

	var lines := [save_line, hero_line, target_line, next_step_line]
	if not reminder_line.is_empty():
		lines.append(reminder_line)
	flow_summary_label.text = "\n".join(lines)


func _describe_character(character_id: String) -> String:
	var normalized_id = character_id.strip_edges()
	if normalized_id.is_empty():
		return "待确认"

	for record in _as_array(_runtime_character_list().get("characters", [])):
		var listed_entry := _as_dictionary(record)
		if _normalize_id_string(listed_entry.get("character_id", "")) == normalized_id:
			return str(listed_entry.get("character_name", "角色"))

	var detail_character = _as_dictionary(_runtime_character_detail().get("character", {}))
	if _normalize_id_string(detail_character.get("character_id", "")) == normalized_id:
		return str(detail_character.get("character_name", "角色"))

	var prepare_character = _as_dictionary(_runtime_prepare_result().get("character", {}))
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

	for record in _as_array(_runtime_character_list().get("characters", [])):
		var listed_entry := _as_dictionary(record)
		if _normalize_id_string(listed_entry.get("character_id", "")) == normalized_id:
			return listed_entry

	var detail_character := _as_dictionary(_runtime_character_detail().get("character", {}))
	if _normalize_id_string(detail_character.get("character_id", "")) == normalized_id:
		return detail_character

	var prepare_character := _as_dictionary(_runtime_prepare_result().get("character", {}))
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

	var prepared_character := _as_dictionary(_runtime_prepare_result().get("character", {}))
	if _normalize_id_string(prepared_character.get("character_id", "")) != character_id:
		return {}

	var stats := _as_dictionary(_runtime_prepare_result().get("character_stats", {})).duplicate(true)
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
	var slots_payload := _runtime_slots()
	var has_slot_snapshot := _normalize_id_string(slots_payload.get("character_id", "")) == character_id
	if has_slot_snapshot:
		var slot_entries := _as_array(slots_payload.get("slots", []))
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

	var equipment_feedback := _runtime_equipment_feedback()
	if _normalize_id_string(equipment_feedback.get("character_id", "")) == character_id:
		for key in equipment_feedback.keys():
			context[key] = equipment_feedback[key]

	return context


func _build_character_growth_context(character: Dictionary) -> Dictionary:
	if character.is_empty():
		return {}

	var character_id := _normalize_id_string(character.get("character_id", ""))
	if character_id.is_empty():
		return {}

	var context := {
		"character_id": character_id,
		"has_new_equipment": false,
		"has_recent_inventory_gain": false,
	}
	var route_context := _build_route_context(_runtime_selected_stage_difficulty_id())
	var route_text := _build_growth_route_text(route_context)
	var prepare_character := _as_dictionary(_runtime_prepare_result().get("character", {}))
	var prepare_character_id := _normalize_id_string(prepare_character.get("character_id", ""))
	var settle_character_id := _normalize_id_string(_runtime_battle_character_selection())
	var matches_recent_battle := (
		character_id == prepare_character_id
		or (not settle_character_id.is_empty() and character_id == settle_character_id)
	)

	var settle_result := _runtime_settle_result()
	if matches_recent_battle and not settle_result.is_empty():
		var drop_count := _as_array(settle_result.get("drop_results", [])).size()
		var reward_count := _as_array(settle_result.get("reward_results", [])).size()
		var created_equipment_instances := _as_array(settle_result.get("created_equipment_instances", []))
		var inventory_results := _as_dictionary(settle_result.get("inventory_results", {}))
		var inventory_entry_count := _as_array(inventory_results.get("stack_results", [])).size() + _as_array(inventory_results.get("equipment_instance_results", [])).size()
		context["has_new_equipment"] = not created_equipment_instances.is_empty()
		context["has_recent_inventory_gain"] = inventory_entry_count > 0
		context["recent_result_text"] = "最近一场：%s 已%s，带回掉落 %d 项、奖励 %d 份、入包 %d 条。" % [
			route_text,
			"打完" if int(settle_result.get("is_cleared", 0)) == 1 else "收束",
			drop_count,
			reward_count,
			inventory_entry_count,
		]
		if not created_equipment_instances.is_empty():
			context["growth_focus_text"] = "其中有 %d 件新装备，最顺的是先去穿戴试装。" % created_equipment_instances.size()
		elif inventory_entry_count > 0:
			context["growth_focus_text"] = "这轮收益已经落袋，先去背包整理会更清楚。"
		else:
			context["growth_focus_text"] = "这轮更像一次过程确认，可以直接再打一场，或回主线换目标。"
		return context

	var prepare_result := _runtime_prepare_result()
	if matches_recent_battle and not prepare_result.is_empty():
		var monster_count := _as_array(prepare_result.get("monster_list", [])).size()
		context["next_target_text"] = "%s 已锁定，前方共有 %d 个敌人，随时可以走进战场。" % [route_text, monster_count]
		return context

	if not str(route_context.get("stage_difficulty_id", "")).strip_edges().is_empty() and int(character.get("is_active", 0)) == 1:
		context["next_target_text"] = "下一场目标是 %s。" % route_text
		return context

	return {}


func _build_growth_route_text(route_context: Dictionary) -> String:
	var chapter_name := str(route_context.get("chapter_name", "章节待选"))
	var stage_name := str(route_context.get("stage_name", "关卡待选"))
	var difficulty_name := str(route_context.get("difficulty_name", "难度待选"))
	if str(route_context.get("stage_difficulty_id", "")).strip_edges().is_empty():
		return _build_flow_route_summary(route_context)
	return "%s / %s / %s" % [chapter_name, stage_name, difficulty_name]


func _build_equipment_feedback(
	character_id: int,
	change_type: String,
	slot_key: String,
	fallback_item_name: String = ""
) -> Dictionary:
	var slot_entry := _find_slot_snapshot_entry(_runtime_slots(), slot_key)
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
	var selected_chapter_id: String = _runtime_selected_chapter_id()
	for chapter in _as_array(_runtime_chapters().get("chapters", [])):
		var entry := _as_dictionary(chapter)
		if str(entry.get("chapter_id", "")) == selected_chapter_id:
			return entry
	return {}


func _find_selected_stage_context() -> Dictionary:
	var selected_stage_id: String = _runtime_selected_stage_id()
	for stage in _as_array(_runtime_stages().get("stages", [])):
		var entry := _as_dictionary(stage)
		if str(entry.get("stage_id", "")) == selected_stage_id:
			return entry
	return {}


func _find_stage_difficulty_context(stage_difficulty_id: String) -> Dictionary:
	for difficulty in _as_array(_runtime_difficulties().get("difficulties", [])):
		var entry := _as_dictionary(difficulty)
		if str(entry.get("stage_difficulty_id", "")) == stage_difficulty_id:
			return entry
	return {}


func _build_route_context(stage_difficulty_id: String = "") -> Dictionary:
	var chapter := _find_selected_chapter_context()
	var stage := _find_selected_stage_context()
	var resolved_stage_difficulty_id := stage_difficulty_id if not stage_difficulty_id.is_empty() else _runtime_selected_stage_difficulty_id()
	var difficulty := _find_stage_difficulty_context(resolved_stage_difficulty_id)

	return {
		"chapter_id": str(chapter.get("chapter_id", "")),
		"chapter_name": str(chapter.get("chapter_name", "章节待选择")),
		"stage_id": str(stage.get("stage_id", _runtime_selected_stage_id())),
		"stage_name": str(stage.get("stage_name", "关卡待选择")),
		"stage_difficulty_id": str(difficulty.get("stage_difficulty_id", resolved_stage_difficulty_id)),
		"difficulty_key": str(difficulty.get("difficulty_key", "")),
		"difficulty_name": str(difficulty.get("difficulty_name", "难度待选择")),
		"recommended_power": difficulty.get("recommended_power", "-"),
	}


func _refresh_product_pages() -> void:
	var current_character := _find_character_record(_runtime_character_selection())
	character_page.set_character_stat_snapshot(_build_character_stat_snapshot(current_character))
	character_page.set_character_equipment_context(_build_character_equipment_context(current_character))
	character_page.set_recent_growth_context(_build_character_growth_context(current_character))
	character_page.show_character_summary(current_character)

	var battle_character := _find_character_record(_runtime_battle_character_selection())
	var inventory_character := current_character if not current_character.is_empty() else battle_character
	var settle_result := _runtime_settle_result()
	if not settle_result.is_empty() and not battle_character.is_empty():
		inventory_character = battle_character
	var equipment_character := _find_character_record(_runtime_equipment_character_selection())
	if equipment_character.is_empty():
		equipment_character = inventory_character
	var equipment_character_id := _normalize_id_string(
		_runtime_equipment_character_selection()
		if not _runtime_equipment_character_selection().is_empty()
		else equipment_character.get("character_id", "")
	)
	var equipment_slots := {}
	var slot_snapshot := _runtime_slots()
	if _normalize_id_string(slot_snapshot.get("character_id", "")) == equipment_character_id:
		equipment_slots = slot_snapshot.duplicate(true)
	var route_context := _build_route_context(_runtime_selected_stage_difficulty_id())
	inventory_page.render_inventory_context(inventory_character, settle_result)
	inventory_page.render_inventory(_runtime_inventory())
	equipment_page.render_equipment_context(
		equipment_character,
		equipment_slots,
		_runtime_inventory(),
		settle_result
	)
	stage_page.render_chapters(_runtime_chapters(), _build_preferred_chapter_ids())
	stage_page.render_stages(_runtime_stages(), _build_preferred_stage_ids())
	stage_page.render_reward_context(
		_runtime_chapters(),
		_runtime_stages(),
		_runtime_difficulties(),
		_runtime_reward_status()
	)
	stage_page.set_stage_summary(
		_as_array(_runtime_chapters().get("chapters", [])).size(),
		_as_array(_runtime_stages().get("stages", [])).size(),
		_as_array(_runtime_difficulties().get("difficulties", [])).size(),
		_runtime_reward_status()
	)
	prepare_page.render_prepare_context(battle_character, route_context, _runtime_reward_status())
	prepare_page.show_prepare_summary(_runtime_prepare_result())
	if not _runtime_prepare_result().is_empty() and _allow_battle_page_restore:
		battle_page.load_battle(
			_runtime_prepare_result(),
			route_context,
			_runtime_reward_status(),
			_runtime_dungeon_summary()
		)
	else:
		battle_page.reset_battle_space()
	settle_page.render_settle_context(battle_character, route_context)
	if not settle_result.is_empty():
		settle_page.show_settlement_summary(settle_result)
	elif not _runtime_prepare_result().is_empty():
		settle_page.show_settlement_summary({})
		settle_page.show_handoff_summary(
			_runtime_battle_character_selection(),
			_runtime_selected_stage_difficulty_id(),
			_runtime_battle_context_selection(),
			_runtime_prepared_monster_ids().size()
		)
	else:
		settle_page.show_settlement_summary({})
	_is_applying_config = true
	_apply_runtime_ui_focus_to_pages()
	_is_applying_config = false


func _page_key_for_index(index: int) -> String:
	for page_key in page_indices.keys():
		if int(page_indices.get(page_key, -1)) == index:
			return str(page_key)
	return CONFIG_PAGE


func _resolve_resume_page_key() -> String:
	if not _local_save_ready:
		return CONFIG_PAGE

	var saved_page_key := _runtime_active_page_key()
	var preferred_page_key := CHARACTER_PAGE
	if not _runtime_settle_result().is_empty():
		preferred_page_key = SETTLE_PAGE
	elif not _runtime_prepare_result().is_empty() or bool(_runtime_local_save_meta().get("has_pending_battle_context", false)):
		preferred_page_key = PREPARE_PAGE
	elif not _runtime_selected_stage_difficulty_id().is_empty():
		preferred_page_key = STAGE_PAGE
	elif not _runtime_character_selection().is_empty():
		preferred_page_key = CHARACTER_PAGE

	if saved_page_key == BATTLE_PAGE:
		return preferred_page_key
	if page_indices.has(saved_page_key) and saved_page_key != CONFIG_PAGE:
		return saved_page_key
	return preferred_page_key


func _restore_runtime_entry_after_boot() -> void:
	if tab_container == null:
		return

	var page_key := _resolve_resume_page_key()
	_remember_active_page_key(page_key)
	_is_applying_config = true
	tab_container.current_tab = int(page_indices.get(page_key, 0))
	_is_applying_config = false
	_apply_runtime_selections_to_pages()
	_refresh_product_pages()
	_refresh_flow_summary()


func _set_current_tab(page_key: String) -> void:
	_apply_runtime_selections_to_pages()
	_refresh_product_pages()
	_refresh_flow_summary()
	var target_index := int(page_indices.get(page_key, 0))
	if tab_container.current_tab == target_index:
		_remember_active_page_key(page_key, "page_navigation:%s" % page_key)
		return
	tab_container.current_tab = target_index


func _on_tab_changed(index: int) -> void:
	var active_page_key := _page_key_for_index(index)
	if not _is_applying_config:
		_remember_active_page_key(active_page_key, "page_focus:%s" % active_page_key)
	_apply_runtime_selections_to_pages()
	_refresh_product_pages()
	_refresh_flow_summary()
	if _is_applying_config:
		return
	if index == int(page_indices.get(CHARACTER_PAGE, -1)):
		await _auto_sync_character_page_if_needed()
	if index == int(page_indices.get(STAGE_PAGE, -1)):
		_auto_sync_stage_page_if_needed()


func _can_auto_sync_stage_page() -> bool:
	var config_values: Dictionary = config_page.get_config_values()
	var startup_snapshot := _runtime_startup_snapshot()
	return (
		not str(config_values.get("base_url", "")).strip_edges().is_empty()
		and not str(config_values.get("bearer_token", "")).strip_edges().is_empty()
		and not startup_snapshot.is_empty()
		and bool(startup_snapshot.get("ready", false))
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
	var listed_records := _as_array(_runtime_character_list().get("characters", []))
	var active_character := _find_active_character(listed_records)
	if not active_character.is_empty():
		return active_character

	var current_character := _find_character_record(_runtime_character_selection())
	if not current_character.is_empty():
		return current_character

	if not listed_records.is_empty():
		return _as_dictionary(listed_records[0])

	return {}


func _reward_status_matches_selected_difficulty() -> bool:
	var selected_stage_difficulty_id: String = _runtime_selected_stage_difficulty_id()
	var reward_status := _runtime_reward_status()
	if selected_stage_difficulty_id.is_empty() or reward_status.is_empty():
		return false

	return str(reward_status.get("source_id", "")).strip_edges() == selected_stage_difficulty_id


func _auto_sync_stage_page_if_needed() -> void:
	if _stage_auto_sync_in_flight or not _can_auto_sync_stage_page():
		return

	_stage_auto_sync_in_flight = true
	await _ensure_stage_page_progression()
	_stage_auto_sync_in_flight = false


func _ensure_stage_page_progression() -> void:
	var chapters_payload := _runtime_chapters()
	var stages_payload := _runtime_stages()
	var difficulties_payload := _runtime_difficulties()
	if _as_array(chapters_payload.get("chapters", [])).is_empty():
		await _on_load_chapters_pressed()
		return

	if (
		_runtime_selected_chapter_id().is_empty()
		or str(stages_payload.get("chapter_id", "")).strip_edges() != _runtime_selected_chapter_id()
		or (not has_loaded_stages and _as_array(stages_payload.get("stages", [])).is_empty())
	):
		await _on_load_stages_pressed(_runtime_selected_chapter_id())
		return

	if (
		_runtime_selected_stage_id().is_empty()
		or str(difficulties_payload.get("stage_id", "")).strip_edges() != _runtime_selected_stage_id()
		or (not has_loaded_difficulties and _as_array(difficulties_payload.get("difficulties", [])).is_empty())
	):
		await _on_load_difficulties_pressed()
		return

	if not _runtime_selected_stage_difficulty_id().is_empty() and not _reward_status_matches_selected_difficulty():
		await _on_refresh_reward_status_pressed(false)


func _focus_on_auth() -> void:
	_set_current_tab(CONFIG_PAGE)
	config_page.focus_auth_inputs()


func _open_inventory_from_settle() -> void:
	var settle_result := _runtime_settle_result()
	var inventory_focus_section := "all"
	var inventory_focus_equipment_id := ""
	if not settle_result.is_empty():
		var created_equipment_instances := _as_array(settle_result.get("created_equipment_instances", []))
		if not created_equipment_instances.is_empty():
			inventory_focus_section = "equipment"
			inventory_focus_equipment_id = _normalize_id_string(
				_as_dictionary(created_equipment_instances[0]).get("equipment_instance_id", "")
			)
		elif not _as_array(_as_dictionary(settle_result.get("inventory_results", {})).get("stack_results", [])).is_empty():
			inventory_focus_section = "material"
	_update_runtime_focus({}, {
		"inventory_section": inventory_focus_section,
		"inventory_equipment_instance_id": inventory_focus_equipment_id,
	})
	_persist_local_save()
	_set_current_tab(INVENTORY_PAGE)
	if settle_result.is_empty():
		inventory_page.set_page_state("empty", "这轮收益还没收稳，先把结算走完，再回来整理背包。")
		inventory_page.show_handoff_summary("这轮收益还没收好；先完成结算，再回背包看新装备和关键材料。")
		return

	var inventory_results := _as_dictionary(settle_result.get("inventory_results", {}))
	var stack_results := _as_array(inventory_results.get("stack_results", []))
	var equipment_results := _as_array(inventory_results.get("equipment_instance_results", []))
	inventory_page.set_page_state("success", "本轮收益已经承接到背包，新增装备和关键材料已经被顶到最前。")
	inventory_page.set_summary_text("本轮收获：掉落 %d | 奖励 %d | 入包 %d | 新装备 %d" % [
		_as_array(settle_result.get("drop_results", [])).size(),
		_as_array(settle_result.get("reward_results", [])).size(),
		stack_results.size(),
		equipment_results.size(),
	])
	inventory_page.show_handoff_summary(
		"已带着本轮结果来到背包；先看这轮真正新增了什么，再决定去穿戴试装、回角色确认成长，还是继续主线。"
	)


func _open_equipment_from_settle() -> void:
	var current_character_id: String = _runtime_battle_character_selection()
	if current_character_id.is_empty():
		current_character_id = _runtime_character_selection()
	var equipment_focus := {
		"equipment_target_slot_key": "",
		"equipment_focus_instance_id": "",
	}
	var equipment_selection := {}
	if not current_character_id.is_empty():
		equipment_selection = {"equipment_character_id": current_character_id}
		_update_runtime_focus(equipment_selection, equipment_focus)

	var latest_equipment: Dictionary = _latest_created_equipment_instance()
	if not latest_equipment.is_empty():
		equipment_focus["equipment_target_slot_key"] = str(latest_equipment.get("equipment_slot", "")).strip_edges()
		equipment_focus["equipment_focus_instance_id"] = _normalize_id_string(
			latest_equipment.get("equipment_instance_id", "")
		)
		_update_runtime_focus(equipment_selection, equipment_focus)
	_persist_local_save()
	_set_current_tab(EQUIPMENT_PAGE)
	if not current_character_id.is_empty():
		equipment_page.set_character_id(current_character_id)
	if latest_equipment.is_empty():
		equipment_page.set_page_state("empty", "本轮没有新增装备可直接试穿。")
		equipment_page.set_summary_text("当前角色上下文已保留，你仍可刷新穿戴槽查看现有装备。")
		equipment_page.show_handoff_summary("这轮没有新装备可直达试穿，但当前角色和当前搭配都还在，你可以继续查看现有穿戴。")
		return

	equipment_page.set_selected_equipment_instance(
		_normalize_id_string(latest_equipment.get("equipment_instance_id", "")),
		str(latest_equipment.get("item_name", latest_equipment.get("item_id", "新装备"))),
		str(latest_equipment.get("equipment_slot", ""))
	)
	equipment_page.set_page_state("success", "已带上本轮新装备，当前槽位和候选区会优先围绕它展开。")
	equipment_page.show_handoff_summary("已承接本轮新装备；先看它更适合哪一格，再回角色或主线确认这轮成长值不值得留下。")


func _open_character_page(from_settle: bool = false) -> void:
	_set_current_tab(CHARACTER_PAGE)
	var current_character_id := ""
	if from_settle:
		current_character_id = _runtime_battle_character_selection()
		if current_character_id.is_empty():
			current_character_id = _runtime_character_selection()
	else:
		current_character_id = _runtime_character_selection()
		if current_character_id.is_empty():
			current_character_id = _runtime_equipment_character_selection()
		if current_character_id.is_empty():
			current_character_id = _runtime_battle_character_selection()
		if current_character_id.is_empty():
			current_character_id = _runtime_battle_character_selection()

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
		character_page.set_page_state("success", "已回到角色页，可以继续查看这轮战后成长。")
	else:
		character_page.set_page_state("success", "已回到角色页，当前角色和成长入口都已就位。")


func _open_stage_from_settle() -> void:
	_set_current_tab(STAGE_PAGE)
	stage_page.set_page_state("success", "已回到主线，当前章节、关卡和难度都还保留着。")


func _latest_created_equipment_instance() -> Dictionary:
	var created_equipment_instances := _as_array(_runtime_settle_result().get("created_equipment_instances", []))
	if created_equipment_instances.is_empty():
		return {}

	return _as_dictionary(created_equipment_instances[0])


func _merge_slot_snapshot_payload(character_id: int, slot_snapshot: Array) -> Dictionary:
	var merged_lookup := {}
	var current_slot_snapshot := _runtime_slots()
	if _parse_character_id(current_slot_snapshot.get("character_id", "")) == character_id:
		for slot in _as_array(current_slot_snapshot.get("slots", [])):
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
	var equipment_feedback := _runtime_equipment_feedback()
	if not normalized_character_id.is_empty() and _normalize_id_string(equipment_feedback.get("character_id", "")) == normalized_character_id:
		var slot_name := str(equipment_feedback.get("slot_name", "这格装备")).strip_edges()
		var item_name := str(equipment_feedback.get("item_name", "当前装备")).strip_edges()
		match str(equipment_feedback.get("change_type", "")):
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
		var settle_result := _runtime_settle_result()
		var created_equipment_instances := _as_array(settle_result.get("created_equipment_instances", []))
		var inventory_results := _as_dictionary(settle_result.get("inventory_results", {}))
		var inventory_entry_count := _as_array(inventory_results.get("stack_results", [])).size() + _as_array(inventory_results.get("equipment_instance_results", [])).size()
		if not created_equipment_instances.is_empty():
			return "这轮结果已经回流到角色页；你可以先去穿戴试这轮新装备，再回来看看这次成长，最后决定继续刷还是回主线。"
		if inventory_entry_count > 0:
			return "这轮收益已经回流到角色页；如果还没整理完，先去背包看新增，再决定继续刷这一关还是回主线换目标。"
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
			page.set_page_state("unauthorized", message, "回到“启动”页重新确认地址和令牌。")
			_focus_on_auth()
		"config":
			page.set_page_state("error", message, "保持当前选择，补齐这一步后再试一次。")
		"network":
			page.set_page_state("error", message, "确认启动检查地址或弱联网服务可达后，再试一次。")
		_:
			page.set_page_state("error", message, "保持当前选择，稍微调整后再试一次。")

	if result.has("raw"):
		page.set_output_json(result.get("raw"))


func _on_page_context_changed(context: String, payload: Dictionary) -> void:
	if _is_applying_config:
		return

	var autosave_reason := ""
	match context:
		"detail_character_changed":
			var character_id = _normalize_id_string(payload.get("character_id", ""))
			if not character_id.is_empty():
				if character_page.get_character_id_text() != character_id:
					character_page.set_character_id(character_id)
				if equipment_page.get_character_id_text() != character_id:
					equipment_page.set_character_id(character_id)
				_update_runtime_focus({
					"character_id": character_id,
					"equipment_character_id": equipment_page.get_character_id_text(),
				})
				autosave_reason = "detail_character_changed"
		"battle_character_changed":
			var battle_character_id = _normalize_id_string(payload.get("character_id", ""))
			if not battle_character_id.is_empty():
				if prepare_page.get_character_id_text() != battle_character_id:
					prepare_page.set_character_id(battle_character_id)
				if settle_page.get_character_id_text() != battle_character_id:
					settle_page.set_character_id(battle_character_id)
				_update_runtime_focus({"battle_character_id": battle_character_id})
				autosave_reason = "battle_character_changed"
		"stage_id_changed":
			var stage_id = str(payload.get("stage_id", "")).strip_edges()
			if not stage_id.is_empty():
				if stage_page.get_stage_id_text() != stage_id:
					stage_page.set_stage_id(stage_id)
				_update_runtime_focus({"stage_id": stage_id})
				autosave_reason = "stage_id_changed"
		"stage_difficulty_changed":
			var stage_difficulty_id = str(payload.get("stage_difficulty_id", "")).strip_edges()
			if not stage_difficulty_id.is_empty():
				stage_page.set_selected_stage_difficulty(stage_difficulty_id)
				if prepare_page.get_stage_difficulty_text() != stage_difficulty_id:
					prepare_page.set_stage_difficulty_id(stage_difficulty_id)
				if settle_page.get_stage_difficulty_text() != stage_difficulty_id:
					settle_page.set_stage_difficulty_id(stage_difficulty_id)
				_update_runtime_focus({"stage_difficulty_id": stage_difficulty_id})
				autosave_reason = "stage_difficulty_changed"
		"battle_context_changed":
			var battle_context_id = str(payload.get("battle_context_id", "")).strip_edges()
			if not battle_context_id.is_empty():
				if settle_page.get_battle_context_text() != battle_context_id:
					settle_page.set_battle_context_id(battle_context_id)
				_update_runtime_focus({"battle_context_id": battle_context_id})
				autosave_reason = "battle_context_changed"
		"dungeon_summary_changed":
			var dungeon_summary := _as_dictionary(payload.get("dungeon_summary", {}))
			if not dungeon_summary.is_empty():
				current_dungeon_summary = dungeon_summary.duplicate(true)
				_sync_local_runtime_from_legacy_cache()
				autosave_reason = "dungeon_summary_changed"
		"inventory_focus_changed":
			_update_runtime_focus({}, {
				"inventory_section": str(payload.get("inventory_section", "all")).strip_edges(),
				"inventory_equipment_instance_id": _runtime_inventory_focus_equipment_instance_id(),
			})
			autosave_reason = "inventory_focus_changed"
		"equipment_focus_changed":
			var equipment_character_id: String = equipment_page.get_character_id_text()
			if equipment_character_id.is_empty():
				equipment_character_id = _runtime_equipment_character_selection()
			if equipment_character_id.is_empty():
				equipment_character_id = _runtime_character_selection()
			_update_runtime_focus(
				{"equipment_character_id": equipment_character_id},
				{
					"equipment_target_slot_key": str(payload.get("equipment_target_slot_key", "")).strip_edges(),
					"equipment_focus_instance_id": _normalize_id_string(
						payload.get("equipment_focus_instance_id", "")
					),
				}
			)
			autosave_reason = "equipment_focus_changed"
		_:
			pass

	_refresh_runtime_config_snapshot()
	if not autosave_reason.is_empty():
		_autosave_local_progress(autosave_reason)
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()


func _on_page_action_requested(action: String, payload: Dictionary) -> void:
	match action:
		"fill_default_config":
			_on_fill_default_config_pressed()
		"continue_local_game":
			_on_continue_local_game_pressed()
		"start_new_local_game":
			_on_start_new_local_game_pressed()
		"save_config":
			_on_save_config_pressed()
		"run_startup_check":
			await _on_run_startup_check_pressed()
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
	_update_runtime_focus(
		{
			"character_id": "1001",
			"battle_character_id": "1001",
			"equipment_character_id": "1001",
			"chapter_id": "chapter_nanshan_001",
			"stage_id": "stage_nanshan_001",
			"stage_difficulty_id": "stage_nanshan_001_normal",
			"battle_context_id": "",
		},
		{
			"inventory_section": "all",
			"inventory_equipment_instance_id": "",
			"equipment_target_slot_key": "",
			"equipment_focus_instance_id": "",
		}
	)

	_refresh_runtime_config_snapshot()
	_autosave_local_progress("fill_default_config")
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()
	config_page.set_page_state("success", "已填入开发默认值，记得点击“保存配置”。")
	_refresh_startup_entry_state(_current_startup_page_status(), "已填入开发默认值，记得点击“保存配置”。")


func _on_continue_local_game_pressed() -> void:
	var inspection := LocalSaveServiceScript.inspect_save()
	if not inspection.get("valid", false):
		config_page.set_page_state(
			"error",
			"继续游戏失败：%s" % str(
				inspection.get("message", "当前没有可恢复的本地正式存档，请改点“新开一局”。")
			)
		)
		return
	var result := {
		"ok": true,
		"data": inspection.get("data", {}),
		"path": inspection.get("path", LocalSaveServiceScript.SAVE_PATH),
		"action": "loaded",
	}

	_apply_local_save_result(result)
	_refresh_recent_selectors()
	_refresh_product_pages()
	_restore_runtime_entry_after_boot()
	_refresh_flow_summary()
	_refresh_startup_entry_state(_current_startup_page_status(), _build_local_save_action_message(current_local_save_action, false))


func _on_start_new_local_game_pressed() -> void:
	var result := LocalSaveServiceScript.create_new_save()
	if not result.get("ok", false):
		config_page.set_page_state("error", "新开局失败：%s" % str(result.get("message", "本地存档暂不可写。")))
		return

	result["action"] = "created"
	_apply_local_save_result(result)
	_refresh_recent_selectors()
	_refresh_product_pages()
	_restore_runtime_entry_after_boot()
	_refresh_flow_summary()
	_refresh_startup_entry_state(_current_startup_page_status(), "已新开一局，并用默认单机进度覆盖当前本地存档。")


func _on_save_config_pressed() -> void:
	_persist_client_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_refresh_flow_summary()
	_refresh_startup_entry_state(
		_current_startup_page_status(),
		"弱联网配置已保存到 user://phase_one_client.cfg；正式本地存档位于 %s。"
		% LocalSaveServiceScript.SAVE_PATH
	)


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
	_autosave_local_progress("character_list_loaded")
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
	_sync_local_runtime_from_legacy_cache()

	character_page.set_character_id(created_character_id)
	equipment_page.set_character_id(created_character_id)
	character_page.show_character_summary(character)
	equipment_page.render_slots(_runtime_slots())
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
	_autosave_local_progress("character_created")
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
	_sync_local_runtime_from_legacy_cache()
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
	_autosave_local_progress("character_detail_loaded")
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
	_sync_local_runtime_from_legacy_cache()

	if not _runtime_character_detail().is_empty():
		character_page.show_character_summary(_as_dictionary(_runtime_character_detail().get("character", {})))

	page.set_output_json(data)
	page.set_page_state("success", success_message)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_autosave_local_progress("character_activated")
	_refresh_flow_summary()


func _on_sync_current_character_pressed() -> void:
	var character_detail := _runtime_character_detail()
	if character_detail.is_empty():
		character_page.set_page_state("empty", "这名角色的详情还没到位。")
		return

	var character: Dictionary = _as_dictionary(character_detail.get("character", {}))
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
	_autosave_local_progress("character_synced")
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
	_sync_local_runtime_from_legacy_cache()
	inventory_page.render_inventory(_runtime_inventory())

	var stack_items: Array = _as_array(_runtime_inventory().get("stack_items", []))
	var equipment_items: Array = _as_array(_runtime_inventory().get("equipment_items", []))
	if stack_items.is_empty() and equipment_items.is_empty():
		inventory_page.set_page_state("empty", "现在背包还是空的。")
	else:
		inventory_page.set_page_state("success", "背包已经到位，本轮新增和新装备会优先排在前面。")

	_persist_runtime_config()
	_refresh_product_pages()
	_autosave_local_progress("inventory_loaded")
	_refresh_flow_summary()


func _on_inventory_equipment_selected(metadata: Dictionary) -> void:
	var equipment_instance_id = _normalize_id_string(metadata.get("equipment_instance_id", ""))
	if equipment_instance_id.is_empty():
		return

	var equipment_character_id: String = equipment_page.get_character_id_text()
	if equipment_character_id.is_empty():
		equipment_character_id = _runtime_equipment_character_selection()
	if equipment_character_id.is_empty():
		equipment_character_id = _runtime_character_selection()

	_update_runtime_focus(
		{"equipment_character_id": equipment_character_id},
		{
			"inventory_section": "equipment",
			"inventory_equipment_instance_id": equipment_instance_id,
			"equipment_target_slot_key": str(metadata.get("equipment_slot", "")).strip_edges(),
			"equipment_focus_instance_id": equipment_instance_id,
		}
	)
	_autosave_local_progress("inventory_equipment_selected")
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
	_sync_local_runtime_from_legacy_cache()
	equipment_page.render_slots(_runtime_slots())

	if _as_array(_runtime_slots().get("slots", [])).is_empty():
		equipment_page.set_page_state("empty", "当前角色没有可显示的槽位。")
	else:
		equipment_page.set_page_state("success", "穿戴槽已刷新，可以继续穿上或卸下装备。")

	_persist_runtime_config()
	_refresh_product_pages()
	_autosave_local_progress("slots_loaded")
	_refresh_flow_summary()


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
	_sync_local_runtime_from_legacy_cache()
	equipment_page.render_slots(_runtime_slots())
	equipment_page.set_page_state(
		"success",
		"穿戴完成，当前装备位和候选区都已刷新。"
		if slots_refresh_result.get("ok", false)
		else "穿戴完成；当前槽位已按返回结果更新，完整快照可再刷新一次。"
	)
	_persist_runtime_config()
	_refresh_product_pages()
	_autosave_local_progress("equipment_equipped")
	_refresh_flow_summary()


func _on_unequip_pressed() -> void:
	var character_id_value = _parse_character_id(equipment_page.get_character_id_text())
	var target_slot = equipment_page.get_target_slot_key()
	var previous_slot_entry := _find_slot_snapshot_entry(_runtime_slots(), target_slot)
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
	_sync_local_runtime_from_legacy_cache()
	equipment_page.render_slots(_runtime_slots())
	equipment_page.set_page_state(
		"success",
		"卸下完成，当前装备位和候选区都已刷新。"
		if slots_refresh_result.get("ok", false)
		else "卸下完成；当前槽位已按返回结果更新，完整快照可再刷新一次。"
	)
	_persist_runtime_config()
	_refresh_product_pages()
	_autosave_local_progress("equipment_unequipped")
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
	_sync_local_runtime_from_legacy_cache()
	stage_page.render_chapters(_runtime_chapters(), _build_preferred_chapter_ids())
	_autosave_local_progress("chapters_loaded")

	if _as_array(_runtime_chapters().get("chapters", [])).is_empty():
		has_loaded_stages = false
		has_loaded_difficulties = false
		current_stages = {}
		current_difficulties = {}
		current_reward_status = {}
		_sync_local_runtime_from_legacy_cache()
		stage_page.set_selected_chapter_id("")
		stage_page.render_stages(_runtime_stages())
		stage_page.set_selected_stage_difficulty("")
		prepare_page.set_stage_difficulty_id("")
		settle_page.set_stage_difficulty_id("")
		_update_runtime_focus({
			"chapter_id": "",
			"stage_id": "",
			"stage_difficulty_id": "",
		})
		stage_page.render_reward_context(_runtime_chapters(), _runtime_stages(), _runtime_difficulties(), _runtime_reward_status())
		stage_page.set_page_state("empty", "山海路暂时还没有开放章节。")
		stage_page.set_stage_summary(0, 0, 0, _runtime_reward_status())
		_persist_runtime_config()
		_refresh_recent_selectors()
		_refresh_product_pages()
		_autosave_local_progress("chapters_cleared")
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
	_update_runtime_focus({
		"chapter_id": chapter_id_value,
		"stage_id": "",
		"stage_difficulty_id": "",
	})
	_remember_chapter_id(chapter_id_value)
	_autosave_local_progress("chapter_selected")
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
	_sync_local_runtime_from_legacy_cache()
	prepare_page.set_stage_difficulty_id("")
	settle_page.set_stage_difficulty_id("")
	stage_page.render_stages(_runtime_stages(), _build_preferred_stage_ids())
	_update_runtime_focus({
		"stage_id": stage_page.get_stage_id_text(),
		"stage_difficulty_id": "",
	})
	stage_page.render_reward_context(_runtime_chapters(), _runtime_stages(), _runtime_difficulties(), _runtime_reward_status())
	stage_page.set_stage_summary(
		_as_array(_runtime_chapters().get("chapters", [])).size(),
		_as_array(_runtime_stages().get("stages", [])).size(),
		0,
		_runtime_reward_status()
	)

	if _as_array(_runtime_stages().get("stages", [])).is_empty():
		stage_page.set_page_state("empty", "这一章暂时还没有可推进的关卡。")
	else:
		stage_page.set_page_state("success", "这一章已经铺开，可以继续选关卡和难度。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_autosave_local_progress("stages_loaded")
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
	_sync_local_runtime_from_legacy_cache()
	stage_page.render_difficulties(_runtime_difficulties(), _runtime_reward_status(), _build_preferred_stage_difficulty_ids())
	_update_runtime_focus({
		"stage_id": stage_id_value,
		"stage_difficulty_id": stage_page.get_selected_stage_difficulty(),
	})
	stage_page.set_stage_summary(
		_as_array(_runtime_chapters().get("chapters", [])).size(),
		_as_array(_runtime_stages().get("stages", [])).size(),
		_as_array(_runtime_difficulties().get("difficulties", [])).size(),
		_runtime_reward_status()
	)
	_remember_stage_id(stage_id_value)
	var selected_stage_difficulty_id: String = stage_page.get_selected_stage_difficulty()
	if not selected_stage_difficulty_id.is_empty():
		prepare_page.set_stage_difficulty_id(selected_stage_difficulty_id)
		settle_page.set_stage_difficulty_id(selected_stage_difficulty_id)
		_update_runtime_focus({
			"stage_id": stage_id_value,
			"stage_difficulty_id": selected_stage_difficulty_id,
		})
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
	_autosave_local_progress("difficulties_loaded")
	_refresh_flow_summary()


func _on_stage_selected(metadata: Dictionary) -> void:
	var stage_id_value = str(metadata.get("stage_id", "")).strip_edges()
	if stage_id_value.is_empty():
		return

	stage_page.set_stage_id(stage_id_value)
	_update_runtime_focus({
		"stage_id": stage_id_value,
		"stage_difficulty_id": "",
	})
	_remember_stage_id(stage_id_value)
	_refresh_recent_selectors()
	_refresh_product_pages()
	_autosave_local_progress("stage_selected")
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
	_sync_local_runtime_from_legacy_cache()
	stage_page.render_reward_context(_runtime_chapters(), _runtime_stages(), _runtime_difficulties(), _runtime_reward_status())
	stage_page.set_stage_summary(
		_as_array(_runtime_chapters().get("chapters", [])).size(),
		_as_array(_runtime_stages().get("stages", [])).size(),
		_as_array(_runtime_difficulties().get("difficulties", [])).size(),
		_runtime_reward_status()
	)

	var reward_status_text = "当前没有首通奖励"
	if int(_runtime_reward_status().get("has_reward", 0)) == 1 and int(_runtime_reward_status().get("has_granted", 0)) == 1:
		reward_status_text = "首通奖励已领取"
	elif int(_runtime_reward_status().get("has_reward", 0)) == 1:
		reward_status_text = "首通奖励待领取"

	if show_success_message:
		if str(_runtime_reward_status().get("grant_status", "")).is_empty():
			stage_page.set_page_state("success", "这一档奖励状态已经同步：%s。" % reward_status_text)
		else:
			stage_page.set_page_state(
				"success",
				"这一档奖励状态已经同步：%s。更细的技术状态已放到技术详情里。" % [
					reward_status_text,
				]
			)

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_autosave_local_progress("reward_status_refreshed")
	_refresh_flow_summary()
	return true


func _on_difficulty_selected(metadata: Dictionary) -> void:
	var stage_difficulty_id_value = str(metadata.get("stage_difficulty_id", ""))
	if stage_difficulty_id_value.is_empty():
		return

	stage_page.set_selected_stage_difficulty(stage_difficulty_id_value)
	prepare_page.set_stage_difficulty_id(stage_difficulty_id_value)
	settle_page.set_stage_difficulty_id(stage_difficulty_id_value)
	_update_runtime_focus({"stage_difficulty_id": stage_difficulty_id_value})
	_remember_stage_difficulty_id(stage_difficulty_id_value)
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_autosave_local_progress("difficulty_selected")
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
	_update_runtime_focus(
		{
			"battle_character_id": str(character_id_value),
			"stage_difficulty_id": stage_difficulty_id_value,
		},
		{
			"inventory_section": "all",
			"inventory_equipment_instance_id": "",
			"equipment_target_slot_key": "",
			"equipment_focus_instance_id": "",
		}
	)
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
	current_dungeon_summary = {}
	current_prepared_monster_ids = _extract_monster_ids(data)
	_allow_battle_page_restore = true
	_sync_local_runtime_from_legacy_cache()
	prepare_page.show_prepare_summary(data)
	var battle_route_context := _build_route_context(stage_difficulty_id_value)
	var prepared_stage_difficulty := _as_dictionary(data.get("stage_difficulty", {}))
	if not prepared_stage_difficulty.is_empty():
		battle_route_context["stage_difficulty_id"] = str(prepared_stage_difficulty.get("stage_difficulty_id", stage_difficulty_id_value))
		battle_route_context["difficulty_key"] = str(prepared_stage_difficulty.get("difficulty_key", battle_route_context.get("difficulty_key", "")))
		battle_route_context["difficulty_name"] = str(prepared_stage_difficulty.get("difficulty_name", battle_route_context.get("difficulty_name", "难度待选择")))
		battle_route_context["recommended_power"] = prepared_stage_difficulty.get("recommended_power", battle_route_context.get("recommended_power", "-"))
	battle_page.load_battle(data, battle_route_context, _runtime_reward_status())

	var battle_context_id = str(data.get("battle_context_id", ""))
	settle_page.set_battle_context_id(battle_context_id)
	settle_page.set_killed_monsters(_runtime_prepared_monster_ids())
	settle_page.show_handoff_summary(
		str(character_id_value),
		stage_difficulty_id_value,
		battle_context_id,
		_runtime_prepared_monster_ids().size()
	)
	recent_battle_context_ids = ClientConfigStoreScript.upsert_recent_string(
		recent_battle_context_ids,
		battle_context_id,
		5
	)
	_sync_local_runtime_from_legacy_cache()
	_update_runtime_focus(
		{
			"battle_character_id": str(character_id_value),
			"stage_difficulty_id": stage_difficulty_id_value,
			"battle_context_id": battle_context_id,
		},
		{
			"inventory_section": "all",
			"inventory_equipment_instance_id": "",
			"equipment_target_slot_key": "",
			"equipment_focus_instance_id": "",
		}
	)
	_remember_character(_as_dictionary(data.get("character", {})))
	_remember_stage_difficulty_id(stage_difficulty_id_value)
	prepare_page.set_page_state("success", "出战信息已经锁定，走进战场吧。")
	battle_page.set_page_state("success", "战场已经准备好，该前压接敌了。")
	settle_page.set_page_state("success", "这一场打完后，这里会先把战利品和成长路线收好。")

	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_autosave_local_progress("prepare_locked")
	_refresh_flow_summary()
	_set_current_tab(BATTLE_PAGE)


func _on_fill_prepared_monsters_pressed() -> void:
	var prepared_monster_ids := _runtime_prepared_monster_ids()
	if prepared_monster_ids.is_empty():
		settle_page.set_page_state("empty", "当前还没有可复用的敌方列表。")
		return

	settle_page.set_killed_monsters(prepared_monster_ids)
	settle_page.show_handoff_summary(
		_runtime_battle_character_selection(),
		_runtime_selected_stage_difficulty_id(),
		_runtime_battle_context_selection(),
		prepared_monster_ids.size()
	)
	settle_page.set_page_state("success", "这一场的结果页已经就位，战斗结束后会自动回到这里。")


func _on_battle_request_settle(payload: Dictionary) -> void:
	var character_id_value = _parse_character_id(str(payload.get("character_id", "")))
	var stage_difficulty_id_value = str(payload.get("stage_difficulty_id", "")).strip_edges()
	var battle_context_id_value = str(payload.get("battle_context_id", "")).strip_edges()
	var killed_monsters = _as_array(payload.get("killed_monsters", []))
	var is_cleared_value := int(payload.get("is_cleared", 0)) == 1
	var dungeon_summary := _as_dictionary(payload.get("dungeon_summary", {}))
	if not dungeon_summary.is_empty():
		current_dungeon_summary = dungeon_summary.duplicate(true)
		_sync_local_runtime_from_legacy_cache()

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
	current_dungeon_summary = {}
	current_prepared_monster_ids = PackedStringArray()
	_allow_battle_page_restore = false
	_sync_local_runtime_from_legacy_cache()
	_update_runtime_focus(
		{"battle_context_id": ""},
		{
			"inventory_section": "all",
			"inventory_equipment_instance_id": "",
			"equipment_target_slot_key": "",
			"equipment_focus_instance_id": "",
		}
	)
	battle_page.reset_battle_space()
	_autosave_local_progress("retry_battle_reset")
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
	_update_runtime_focus({
		"battle_character_id": str(character_id_value),
		"stage_difficulty_id": stage_difficulty_id_value,
		"battle_context_id": battle_context_id_value,
	})
	_persist_runtime_config()
	if from_battle_page:
		battle_page.set_page_state("settling", "战斗结束，正在把这场战果收好。")
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
	var localized_result := _build_localized_settle_result(data, stage_difficulty_id_value)
	current_settle_result = localized_result
	current_reward_status = _as_dictionary(localized_result.get("first_clear_reward_status", {}))
	_allow_battle_page_restore = false
	_sync_local_runtime_from_legacy_cache()
	var created_equipment_instances := _as_array(localized_result.get("created_equipment_instances", []))
	var inventory_results := _as_dictionary(localized_result.get("inventory_results", {}))
	var inventory_entry_count := _as_array(inventory_results.get("stack_results", [])).size() + _as_array(inventory_results.get("equipment_instance_results", [])).size()
	var focus_equipment := _as_dictionary(created_equipment_instances[0]) if not created_equipment_instances.is_empty() else {}
	_update_runtime_focus(
		{
			"battle_character_id": str(character_id_value),
			"stage_difficulty_id": stage_difficulty_id_value,
			"battle_context_id": battle_context_id_value,
		},
		{
			"inventory_section": (
				"equipment"
				if not created_equipment_instances.is_empty()
				else ("material" if inventory_entry_count > 0 else "all")
			),
			"inventory_equipment_instance_id": _normalize_id_string(
				focus_equipment.get("equipment_instance_id", "")
			),
			"equipment_target_slot_key": str(focus_equipment.get("equipment_slot", "")).strip_edges(),
			"equipment_focus_instance_id": _normalize_id_string(
				focus_equipment.get("equipment_instance_id", "")
			),
		}
	)
	settle_page.show_settlement_summary(localized_result)
	if from_battle_page:
		battle_page.set_page_state("success", "战斗已收束，结果页已经接住这轮战果。")
	settle_page.set_page_state("success", "这一场已经打完，掉落、奖励、入包和后续路线都整理好了。")
	stage_page.render_reward_context(_runtime_chapters(), _runtime_stages(), _runtime_difficulties(), _runtime_reward_status())
	stage_page.set_stage_summary(
		_as_array(_runtime_chapters().get("chapters", [])).size(),
		_as_array(_runtime_stages().get("stages", [])).size(),
		_as_array(_runtime_difficulties().get("difficulties", [])).size(),
		_runtime_reward_status()
	)
	stage_page.set_page_state("success", "结算完成，主线页的首通奖励状态也已经同步。")
	_persist_runtime_config()
	_refresh_recent_selectors()
	_refresh_product_pages()
	_autosave_local_progress("settle_completed")
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
		_runtime_selected_chapter_id(),
		str(_runtime_stages().get("chapter_id", "")).strip_edges(),
		str(saved_config.get("chapter_id", "")).strip_edges(),
	]

	for chapter_id in _build_available_chapter_ids():
		candidates.append(chapter_id)

	return candidates


func _build_preferred_stage_ids() -> Array:
	var candidates: Array = [
		_runtime_selected_stage_id(),
		str(_runtime_difficulties().get("stage_id", "")).strip_edges(),
		str(saved_config.get("stage_id", "")).strip_edges(),
	]

	for stage_id in _as_array(saved_config.get("recent_stage_ids", [])):
		candidates.append(str(stage_id).strip_edges())

	return candidates


func _build_preferred_stage_difficulty_ids() -> Array:
	var candidates: Array = [
		_runtime_selected_stage_difficulty_id(),
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

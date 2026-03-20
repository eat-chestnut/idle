extends Control

const BackendApiScript = preload("res://client/scripts/backend_api.gd")
const ClientConfigStoreScript = preload("res://client/scripts/client_config_store.gd")

const CONFIG_PAGE := "config"
const CHARACTER_PAGE := "character"
const INVENTORY_PAGE := "inventory"
const EQUIPMENT_PAGE := "equipment"
const CHAPTER_PAGE := "chapter"
const PREPARE_PAGE := "prepare"
const SETTLE_PAGE := "settle"

const STATUS_COLORS := {
	"empty": Color(0.75, 0.75, 0.75),
	"loading": Color(0.95, 0.83, 0.40),
	"preparing": Color(0.95, 0.83, 0.40),
	"settling": Color(0.95, 0.83, 0.40),
	"success": Color(0.55, 0.85, 0.55),
	"error": Color(1.0, 0.62, 0.62),
	"unauthorized": Color(1.0, 0.75, 0.45),
}

var api
var saved_config: Dictionary = {}
var tab_container: TabContainer
var page_state_labels: Dictionary = {}
var page_output_boxes: Dictionary = {}
var tab_indices: Dictionary = {}

var base_url_input: LineEdit
var token_input: LineEdit
var character_class_input: LineEdit
var character_name_input: LineEdit
var character_id_input: LineEdit
var inventory_tab_selector: OptionButton
var inventory_equipment_list: ItemList
var equipment_slot_list: ItemList
var target_slot_input: LineEdit
var equipment_instance_input: LineEdit
var stage_id_input: LineEdit
var chapter_list: ItemList
var difficulty_list: ItemList
var prepare_character_id_input: LineEdit
var prepare_stage_difficulty_input: LineEdit
var settle_character_id_input: LineEdit
var settle_stage_difficulty_input: LineEdit
var settle_battle_context_input: LineEdit
var killed_monsters_input: LineEdit
var is_cleared_checkbox: CheckBox

var current_character_detail: Dictionary = {}
var current_inventory: Dictionary = {}
var current_slots: Dictionary = {}
var current_chapters: Dictionary = {}
var current_difficulties: Dictionary = {}
var current_reward_status: Dictionary = {}
var current_prepare_result: Dictionary = {}
var current_settle_result: Dictionary = {}
var current_prepared_monster_ids: PackedStringArray = []


func _ready() -> void:
	saved_config = ClientConfigStoreScript.load_config()
	api = BackendApiScript.new(self, saved_config.get("base_url", ""), saved_config.get("bearer_token", ""))
	_build_ui()
	_apply_saved_config()
	_set_initial_states()


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
	subtitle.text = "最小联调链：环境/Token -> 角色 -> 背包/穿戴 -> 章节/难度 -> Prepare -> Settle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(subtitle)

	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(tab_container)

	_build_config_page()
	_build_character_page()
	_build_inventory_page()
	_build_equipment_page()
	_build_chapter_page()
	_build_prepare_page()
	_build_settle_page()


func _build_config_page() -> void:
	var page := _make_tab("环境与 Token", CONFIG_PAGE)
	_add_hint(page, "保存 backend 地址与 Bearer Token。当前本地联调默认建议：127.0.0.1:8000 + test-token-2001。")

	base_url_input = _add_labeled_input(page, "Backend Base URL", "http://127.0.0.1:8000")
	token_input = _add_labeled_input(page, "Bearer Token", "")

	var buttons := _add_button_row(page)
	var fill_defaults_button := _add_button(buttons, "填入联调默认值", _on_fill_default_config_pressed)
	fill_defaults_button.tooltip_text = "写入文档默认联调地址和 test-token-2001。"
	_add_button(buttons, "保存配置", _on_save_config_pressed)
	_add_button(buttons, "探测章节接口", _on_probe_backend_pressed)

	_add_state_and_output(page, CONFIG_PAGE)


func _build_character_page() -> void:
	var page := _make_tab("角色", CHARACTER_PAGE)
	_add_hint(page, "角色页覆盖创建角色与读取角色详情；创建成功后会自动把 character_id 带入后续页面。")

	character_class_input = _add_labeled_input(page, "class_id", "class_jingang")
	character_name_input = _add_labeled_input(page, "character_name", "联调角色")

	var create_buttons := _add_button_row(page)
	_add_button(create_buttons, "创建角色", _on_create_character_pressed)

	page.add_child(HSeparator.new())

	character_id_input = _add_labeled_input(page, "character_id", "")
	var detail_buttons := _add_button_row(page)
	_add_button(detail_buttons, "读取角色详情", _on_load_character_pressed)
	_add_button(detail_buttons, "同步当前 character_id", _on_sync_current_character_id_pressed)

	_add_state_and_output(page, CHARACTER_PAGE)


func _build_inventory_page() -> void:
	var page := _make_tab("背包", INVENTORY_PAGE)
	_add_hint(page, "背包页真实接 GET /api/inventory。选择装备条目后，会自动把 equipment_instance_id 带入穿戴页。")

	inventory_tab_selector = OptionButton.new()
	inventory_tab_selector.add_item("all")
	inventory_tab_selector.add_item("stack")
	inventory_tab_selector.add_item("equipment")
	page.add_child(_wrap_labeled_control("tab", inventory_tab_selector))

	var buttons := _add_button_row(page)
	_add_button(buttons, "读取背包", _on_load_inventory_pressed)

	var equipment_label := Label.new()
	equipment_label.text = "可选装备实例"
	page.add_child(equipment_label)

	inventory_equipment_list = ItemList.new()
	inventory_equipment_list.custom_minimum_size = Vector2(0, 180)
	inventory_equipment_list.item_selected.connect(_on_inventory_equipment_selected)
	page.add_child(inventory_equipment_list)

	_add_state_and_output(page, INVENTORY_PAGE)


func _build_equipment_page() -> void:
	var page := _make_tab("穿戴", EQUIPMENT_PAGE)
	_add_hint(page, "穿戴页真实接 GET/POST 装备槽与 equip/unequip。客户端只提交 equipment_instance_id 与 target_slot_key，不复制槽位兼容规则。")

	var buttons := _add_button_row(page)
	_add_button(buttons, "读取穿戴槽", _on_load_slots_pressed)

	var slot_label := Label.new()
	slot_label.text = "当前槽位快照"
	page.add_child(slot_label)

	equipment_slot_list = ItemList.new()
	equipment_slot_list.custom_minimum_size = Vector2(0, 180)
	equipment_slot_list.item_selected.connect(_on_equipment_slot_selected)
	page.add_child(equipment_slot_list)

	target_slot_input = _add_labeled_input(page, "target_slot_key", "main_weapon")
	equipment_instance_input = _add_labeled_input(page, "equipment_instance_id", "")

	var action_buttons := _add_button_row(page)
	_add_button(action_buttons, "执行 Equip", _on_equip_pressed)
	_add_button(action_buttons, "执行 Unequip", _on_unequip_pressed)

	_add_state_and_output(page, EQUIPMENT_PAGE)


func _build_chapter_page() -> void:
	var page := _make_tab("章节与难度", CHAPTER_PAGE)
	_add_hint(page, "当前 phase-one 没有公开 stage list 接口，所以这里会显示真实章节列表，同时保留一个 stage_id 输入承接难度联调。默认值使用文档/seed 的联调 stage_id。")

	var chapter_buttons := _add_button_row(page)
	_add_button(chapter_buttons, "读取章节列表", _on_load_chapters_pressed)

	var chapter_label := Label.new()
	chapter_label.text = "章节列表"
	page.add_child(chapter_label)

	chapter_list = ItemList.new()
	chapter_list.custom_minimum_size = Vector2(0, 120)
	page.add_child(chapter_list)

	stage_id_input = _add_labeled_input(page, "stage_id", "stage_nanshan_001")
	var difficulty_buttons := _add_button_row(page)
	_add_button(difficulty_buttons, "读取难度列表", _on_load_difficulties_pressed)
	_add_button(difficulty_buttons, "刷新首通奖励状态", _on_refresh_reward_status_pressed)

	var difficulty_label := Label.new()
	difficulty_label.text = "难度列表"
	page.add_child(difficulty_label)

	difficulty_list = ItemList.new()
	difficulty_list.custom_minimum_size = Vector2(0, 180)
	difficulty_list.item_selected.connect(_on_difficulty_selected)
	page.add_child(difficulty_list)

	_add_state_and_output(page, CHAPTER_PAGE)


func _build_prepare_page() -> void:
	var page := _make_tab("Battle Prepare", PREPARE_PAGE)
	_add_hint(page, "Prepare 页真实接 POST /api/battles/prepare。当前真实后端要求这里使用 is_active=1 的角色；成功后会把 battle_context_id、stage_difficulty_id 和怪物列表自动带到结算页。")

	prepare_character_id_input = _add_labeled_input(page, "character_id", "")
	prepare_stage_difficulty_input = _add_labeled_input(page, "stage_difficulty_id", "stage_nanshan_001_normal")

	var buttons := _add_button_row(page)
	_add_button(buttons, "执行 Prepare", _on_prepare_pressed)

	_add_state_and_output(page, PREPARE_PAGE)


func _build_settle_page() -> void:
	var page := _make_tab("Battle Settle", SETTLE_PAGE)
	_add_hint(page, "Settle 页真实接 POST /api/battles/settle。这里不会客户端生成 battle_context_id，也不会自己推断奖励状态。")

	settle_character_id_input = _add_labeled_input(page, "character_id", "")
	settle_stage_difficulty_input = _add_labeled_input(page, "stage_difficulty_id", "stage_nanshan_001_normal")
	settle_battle_context_input = _add_labeled_input(page, "battle_context_id", "")
	killed_monsters_input = _add_labeled_input(page, "killed_monsters（逗号分隔）", "")

	is_cleared_checkbox = CheckBox.new()
	is_cleared_checkbox.text = "is_cleared = 1"
	is_cleared_checkbox.button_pressed = true
	page.add_child(is_cleared_checkbox)

	var buttons := _add_button_row(page)
	_add_button(buttons, "使用 Prepare 怪物列表", _on_fill_prepared_monsters_pressed)
	_add_button(buttons, "执行 Settle", _on_settle_pressed)

	_add_state_and_output(page, SETTLE_PAGE)


func _make_tab(title: String, page_key: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)
	tab_indices[page_key] = tab_container.get_tab_count() - 1

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	scroll.add_child(page)

	return page


func _add_hint(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _add_labeled_input(parent: Control, label_text: String, default_value: String) -> LineEdit:
	var input := LineEdit.new()
	input.text = default_value
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_wrap_labeled_control(label_text, input))
	return input


func _wrap_labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = label_text
	box.add_child(label)
	box.add_child(control)

	return box


func _add_button_row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	return row


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_state_and_output(parent: Control, page_key: String) -> void:
	var state_label := Label.new()
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(state_label)
	page_state_labels[page_key] = state_label

	var output := TextEdit.new()
	output.editable = false
	output.custom_minimum_size = Vector2(0, 260)
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(output)
	page_output_boxes[page_key] = output


func _apply_saved_config() -> void:
	base_url_input.text = str(saved_config.get("base_url", "http://127.0.0.1:8000"))
	token_input.text = str(saved_config.get("bearer_token", "test-token-2001"))
	character_class_input.text = str(saved_config.get("class_id", "class_jingang"))
	character_name_input.text = str(saved_config.get("character_name", "联调角色"))
	character_id_input.text = str(saved_config.get("character_id", "1001"))
	stage_id_input.text = str(saved_config.get("stage_id", "stage_nanshan_001"))
	var battle_character_id := str(saved_config.get("battle_character_id", character_id_input.text))
	prepare_character_id_input.text = battle_character_id
	settle_character_id_input.text = battle_character_id
	prepare_stage_difficulty_input.text = str(saved_config.get("stage_difficulty_id", "stage_nanshan_001_normal"))
	settle_stage_difficulty_input.text = prepare_stage_difficulty_input.text


func _set_initial_states() -> void:
	_set_page_state(CONFIG_PAGE, "empty", "请先确认 backend 地址与 Bearer Token。")
	_set_page_output_text(CONFIG_PAGE, "尚未保存配置。")
	_set_page_state(CHARACTER_PAGE, "empty", "尚未创建或读取角色。")
	_set_page_output_text(CHARACTER_PAGE, "等待角色创建或详情读取。")
	_set_page_state(INVENTORY_PAGE, "empty", "尚未读取背包。")
	_set_page_output_text(INVENTORY_PAGE, "等待背包请求。")
	_set_page_state(EQUIPMENT_PAGE, "empty", "尚未读取穿戴槽。")
	_set_page_output_text(EQUIPMENT_PAGE, "等待穿戴槽请求。")
	_set_page_state(CHAPTER_PAGE, "empty", "尚未读取章节与难度。")
	_set_page_output_text(CHAPTER_PAGE, "等待章节和难度请求。")
	_set_page_state(PREPARE_PAGE, "empty", "尚未执行 battle prepare。")
	_set_page_output_text(PREPARE_PAGE, "等待 battle prepare 请求。")
	_set_page_state(SETTLE_PAGE, "empty", "尚未执行 battle settle。")
	_set_page_output_text(SETTLE_PAGE, "等待 battle settle 请求。")


func _set_page_state(page_key: String, status: String, message: String) -> void:
	var label: Label = page_state_labels.get(page_key)
	if label == null:
		return

	label.text = "状态：%s\n%s" % [status, message]
	label.modulate = STATUS_COLORS.get(status, Color.WHITE)

	if status == "unauthorized":
		tab_container.current_tab = int(tab_indices.get(CONFIG_PAGE, 0))


func _set_page_output_text(page_key: String, text: String) -> void:
	var output: TextEdit = page_output_boxes.get(page_key)
	if output != null:
		output.text = text


func _set_page_output_json(page_key: String, payload: Variant) -> void:
	_set_page_output_text(page_key, _pretty_json(payload))


func _pretty_json(payload: Variant) -> String:
	return JSON.stringify(payload, "  ")


func _persist_runtime_config() -> void:
	var values: Dictionary = {
		"base_url": base_url_input.text.strip_edges(),
		"bearer_token": token_input.text.strip_edges(),
		"class_id": character_class_input.text.strip_edges(),
		"character_name": character_name_input.text.strip_edges(),
		"character_id": character_id_input.text.strip_edges(),
		"battle_character_id": prepare_character_id_input.text.strip_edges(),
		"stage_id": stage_id_input.text.strip_edges(),
		"stage_difficulty_id": prepare_stage_difficulty_input.text.strip_edges(),
	}

	ClientConfigStoreScript.save_config(values)
	saved_config = values
	api.update_credentials(values["base_url"], values["bearer_token"])


func _fill_character_inputs(character_id_value: String, sync_battle_inputs: bool = true) -> void:
	character_id_input.text = character_id_value
	if sync_battle_inputs:
		prepare_character_id_input.text = character_id_value
		settle_character_id_input.text = character_id_value
	_persist_runtime_config()


func _fill_stage_difficulty_inputs(stage_difficulty_id_value: String) -> void:
	prepare_stage_difficulty_input.text = stage_difficulty_id_value
	settle_stage_difficulty_input.text = stage_difficulty_id_value
	_persist_runtime_config()


func _fill_settle_context(battle_context_id_value: String) -> void:
	settle_battle_context_input.text = battle_context_id_value


func _parse_character_id(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty() or not trimmed.is_valid_int():
		return -1
	return int(trimmed)


func _parse_killed_monsters() -> Array:
	var values: Array = []
	for raw_part in killed_monsters_input.text.split(","):
		var part := raw_part.strip_edges()
		if not part.is_empty():
			values.append(part)
	return values


func _handle_failure(page_key: String, result: Dictionary, fallback: String) -> void:
	var message := str(result.get("message", fallback))
	var kind := str(result.get("kind", "error"))

	match kind:
		"unauthorized":
			_set_page_state(page_key, "unauthorized", message)
		"config":
			_set_page_state(page_key, "error", message)
		_:
			var code := int(result.get("code", -1))
			if code > 0:
				message = "%s（code=%d）" % [message, code]
			_set_page_state(page_key, "error", message)

	if result.has("raw"):
		_set_page_output_json(page_key, result.get("raw"))


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _as_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


func _render_inventory(payload: Dictionary) -> void:
	inventory_equipment_list.clear()

	for item in _as_array(payload.get("equipment_items", [])):
		var equipment: Dictionary = _as_dictionary(item)
		var label := "%s #%s [%s]" % [
			str(equipment.get("item_name", "")),
			str(equipment.get("equipment_instance_id", "")),
			str(equipment.get("equipment_slot", "")),
		]
		inventory_equipment_list.add_item(label)
		inventory_equipment_list.set_item_metadata(inventory_equipment_list.get_item_count() - 1, equipment)

	_set_page_output_json(INVENTORY_PAGE, payload)


func _render_slots(payload: Dictionary) -> void:
	equipment_slot_list.clear()

	for slot in _as_array(payload.get("slots", [])):
		var slot_data: Dictionary = _as_dictionary(slot)
		var equipment: Dictionary = _as_dictionary(slot_data.get("equipment", {}))
		var equipment_name := "空"
		if not equipment.is_empty():
			equipment_name = str(equipment.get("item_name", ""))
		var label := "%s -> %s" % [str(slot_data.get("slot_key", "")), equipment_name]
		equipment_slot_list.add_item(label)
		equipment_slot_list.set_item_metadata(equipment_slot_list.get_item_count() - 1, slot_data)

	_set_page_output_json(EQUIPMENT_PAGE, payload)


func _render_chapters(payload: Dictionary) -> void:
	chapter_list.clear()

	for chapter in _as_array(payload.get("chapters", [])):
		var chapter_data: Dictionary = _as_dictionary(chapter)
		var label := "%s (%s)" % [
			str(chapter_data.get("chapter_name", "")),
			str(chapter_data.get("chapter_id", "")),
		]
		chapter_list.add_item(label)
		chapter_list.set_item_metadata(chapter_list.get_item_count() - 1, chapter_data)

	_set_page_output_json(CHAPTER_PAGE, {
		"chapters": payload.get("chapters", []),
		"difficulties": current_difficulties.get("difficulties", []),
		"reward_status": current_reward_status,
	})


func _render_difficulties(payload: Dictionary) -> void:
	difficulty_list.clear()

	for difficulty in _as_array(payload.get("difficulties", [])):
		var difficulty_data: Dictionary = _as_dictionary(difficulty)
		var reward: Dictionary = _as_dictionary(difficulty_data.get("first_clear_reward", {}))
		var reward_text := "reward=none"
		if not reward.is_empty():
			if int(reward.get("has_reward", 0)) == 1 and int(reward.get("has_granted", 0)) == 1:
				reward_text = "reward=claimed"
			elif int(reward.get("has_reward", 0)) == 1:
				reward_text = "reward=available"

		var label := "%s [%s] power=%s %s" % [
			str(difficulty_data.get("difficulty_name", "")),
			str(difficulty_data.get("stage_difficulty_id", "")),
			str(difficulty_data.get("recommended_power", "")),
			reward_text,
		]
		difficulty_list.add_item(label)
		difficulty_list.set_item_metadata(difficulty_list.get_item_count() - 1, difficulty_data)

	_set_page_output_json(CHAPTER_PAGE, {
		"chapters": current_chapters.get("chapters", []),
		"difficulties": payload.get("difficulties", []),
		"reward_status": current_reward_status,
	})


func _render_reward_status() -> void:
	_set_page_output_json(CHAPTER_PAGE, {
		"chapters": current_chapters.get("chapters", []),
		"difficulties": current_difficulties.get("difficulties", []),
		"reward_status": current_reward_status,
	})


func _render_prepare(payload: Dictionary) -> void:
	var monster_ids: PackedStringArray = []
	for monster in _as_array(payload.get("monster_list", [])):
		var monster_data: Dictionary = _as_dictionary(monster)
		monster_ids.append(str(monster_data.get("monster_id", "")))

	current_prepared_monster_ids = monster_ids
	_fill_settle_context(str(payload.get("battle_context_id", "")))
	killed_monsters_input.text = ",".join(current_prepared_monster_ids)
	_set_page_output_json(PREPARE_PAGE, payload)


func _render_settlement(payload: Dictionary) -> void:
	_set_page_output_json(SETTLE_PAGE, payload)


func _selected_difficulty_id() -> String:
	if difficulty_list.get_selected_items().is_empty():
		return prepare_stage_difficulty_input.text.strip_edges()

	var index: int = difficulty_list.get_selected_items()[0]
	var metadata: Dictionary = _as_dictionary(difficulty_list.get_item_metadata(index))
	if not metadata.is_empty():
		return str(metadata.get("stage_difficulty_id", prepare_stage_difficulty_input.text.strip_edges()))

	return prepare_stage_difficulty_input.text.strip_edges()


func _on_fill_default_config_pressed() -> void:
	base_url_input.text = "http://127.0.0.1:8000"
	token_input.text = "test-token-2001"
	character_class_input.text = "class_jingang"
	character_name_input.text = "联调角色"
	character_id_input.text = "1001"
	prepare_character_id_input.text = "1001"
	settle_character_id_input.text = "1001"
	stage_id_input.text = "stage_nanshan_001"
	prepare_stage_difficulty_input.text = "stage_nanshan_001_normal"
	settle_stage_difficulty_input.text = "stage_nanshan_001_normal"
	_set_page_state(CONFIG_PAGE, "success", "已填入联调默认值，记得点击“保存配置”。")
	_set_page_output_text(CONFIG_PAGE, "默认值来自当前正式文档与最小联调 seed：127.0.0.1:8000 / test-token-2001 / character_id=1001 / stage_nanshan_001。")


func _on_save_config_pressed() -> void:
	_persist_runtime_config()
	_set_page_state(CONFIG_PAGE, "success", "配置已保存到 user://phase_one_client.cfg。")
	_set_page_output_json(CONFIG_PAGE, saved_config)


func _on_probe_backend_pressed() -> void:
	_persist_runtime_config()
	_set_page_state(CONFIG_PAGE, "loading", "正在用章节接口验证 backend 地址与 token。")
	var result: Dictionary = await api.request_json("GET", "/api/chapters")

	if not result.get("ok", false):
		_handle_failure(CONFIG_PAGE, result, "探测 backend 失败。")
		return

	_set_page_state(CONFIG_PAGE, "success", "章节接口已返回成功，当前 token/地址可联调。")
	_set_page_output_json(CONFIG_PAGE, result.get("raw"))


func _on_create_character_pressed() -> void:
	_persist_runtime_config()
	_set_page_state(CHARACTER_PAGE, "loading", "正在创建角色。")
	var payload := {
		"class_id": character_class_input.text.strip_edges(),
		"character_name": character_name_input.text.strip_edges(),
	}
	var result: Dictionary = await api.request_json("POST", "/api/characters", payload)

	if not result.get("ok", false):
		_handle_failure(CHARACTER_PAGE, result, "创建角色失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	var character: Dictionary = _as_dictionary(data.get("character", {}))
	var created_character_id := str(character.get("character_id", ""))
	var is_active := int(character.get("is_active", 0)) == 1

	current_character_detail = {
		"character": character,
	}
	_fill_character_inputs(created_character_id, is_active)
	if is_active:
		_set_page_state(CHARACTER_PAGE, "success", "角色创建成功，已同步 character_id 到后续页面。")
	else:
		_set_page_state(CHARACTER_PAGE, "success", "角色创建成功，但当前角色 is_active=0；角色页/穿戴页已切到新角色，battle 页继续保留当前可战斗角色。")
	_set_page_output_json(CHARACTER_PAGE, data)


func _on_load_character_pressed() -> void:
	var character_id_value := _parse_character_id(character_id_input.text)
	if character_id_value <= 0:
		_set_page_state(CHARACTER_PAGE, "error", "请先填写有效的 character_id。")
		return

	_persist_runtime_config()
	_set_page_state(CHARACTER_PAGE, "loading", "正在读取角色详情。")
	var result: Dictionary = await api.request_json("GET", "/api/characters/%d" % character_id_value)

	if not result.get("ok", false):
		_handle_failure(CHARACTER_PAGE, result, "读取角色详情失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_character_detail = data
	var character: Dictionary = _as_dictionary(data.get("character", {}))
	var is_active := int(character.get("is_active", 0)) == 1
	_fill_character_inputs(str(character_id_value), is_active)
	if is_active:
		_set_page_state(CHARACTER_PAGE, "success", "角色详情已加载，并已同步到 battle 页。")
	else:
		_set_page_state(CHARACTER_PAGE, "success", "角色详情已加载；当前角色 is_active=0，battle 页继续保留当前可战斗角色。")
	_set_page_output_json(CHARACTER_PAGE, data)


func _on_sync_current_character_id_pressed() -> void:
	if current_character_detail.is_empty():
		_set_page_state(CHARACTER_PAGE, "empty", "当前还没有已加载的角色详情。")
		return

	var character: Dictionary = _as_dictionary(current_character_detail.get("character", {}))
	var current_character_id := str(character.get("character_id", ""))
	if current_character_id.is_empty():
		_set_page_state(CHARACTER_PAGE, "error", "当前角色详情里没有 character_id。")
		return

	var is_active := int(character.get("is_active", 0)) == 1
	_fill_character_inputs(current_character_id, is_active)
	if is_active:
		_set_page_state(CHARACTER_PAGE, "success", "当前角色 ID 已同步到后续页面。")
	else:
		_set_page_state(CHARACTER_PAGE, "success", "当前角色 ID 已同步到角色页/穿戴页；由于 is_active=0，battle 页保留原角色。")


func _on_load_inventory_pressed() -> void:
	_persist_runtime_config()
	_set_page_state(INVENTORY_PAGE, "loading", "正在读取背包。")
	var selected_index := inventory_tab_selector.get_selected_id()
	if selected_index < 0:
		selected_index = 0
	var tab_value := inventory_tab_selector.get_item_text(selected_index)
	var result: Dictionary = await api.request_json("GET", "/api/inventory", null, {
		"tab": tab_value,
		"page": 1,
		"page_size": 20,
	})

	if not result.get("ok", false):
		_handle_failure(INVENTORY_PAGE, result, "读取背包失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_inventory = data
	_render_inventory(data)

	var stack_items: Array = _as_array(data.get("stack_items", []))
	var equipment_items: Array = _as_array(data.get("equipment_items", []))
	if stack_items.is_empty() and equipment_items.is_empty():
		_set_page_state(INVENTORY_PAGE, "empty", "背包为空。")
	else:
		_set_page_state(INVENTORY_PAGE, "success", "背包已加载，可选择装备实例带入穿戴页。")


func _on_inventory_equipment_selected(index: int) -> void:
	var metadata: Dictionary = _as_dictionary(inventory_equipment_list.get_item_metadata(index))
	if metadata.is_empty():
		return

	equipment_instance_input.text = str(metadata.get("equipment_instance_id", ""))
	tab_container.current_tab = int(tab_indices.get(EQUIPMENT_PAGE, 0))
	_set_page_state(EQUIPMENT_PAGE, "success", "已从背包选中装备实例，接下来请选择槽位并执行 Equip。")


func _on_load_slots_pressed() -> void:
	var character_id_value := _parse_character_id(character_id_input.text)
	if character_id_value <= 0:
		_set_page_state(EQUIPMENT_PAGE, "error", "请先在角色页或穿戴页填写有效的 character_id。")
		return

	_persist_runtime_config()
	_set_page_state(EQUIPMENT_PAGE, "loading", "正在读取穿戴槽。")
	var result: Dictionary = await api.request_json("GET", "/api/characters/%d/equipment-slots" % character_id_value)

	if not result.get("ok", false):
		_handle_failure(EQUIPMENT_PAGE, result, "读取穿戴槽失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = data
	_render_slots(data)

	if _as_array(data.get("slots", [])).is_empty():
		_set_page_state(EQUIPMENT_PAGE, "empty", "当前角色没有可显示的槽位。")
	else:
		_set_page_state(EQUIPMENT_PAGE, "success", "穿戴槽已加载，可执行 equip/unequip。")


func _on_equipment_slot_selected(index: int) -> void:
	var metadata: Dictionary = _as_dictionary(equipment_slot_list.get_item_metadata(index))
	if metadata.is_empty():
		return

	target_slot_input.text = str(metadata.get("slot_key", ""))


func _on_equip_pressed() -> void:
	var character_id_value := _parse_character_id(character_id_input.text)
	var equipment_instance_id_value := _parse_character_id(equipment_instance_input.text)
	var target_slot := target_slot_input.text.strip_edges()

	if character_id_value <= 0:
		_set_page_state(EQUIPMENT_PAGE, "error", "请先填写有效的 character_id。")
		return
	if equipment_instance_id_value <= 0:
		_set_page_state(EQUIPMENT_PAGE, "error", "请先填写有效的 equipment_instance_id。")
		return
	if target_slot.is_empty():
		_set_page_state(EQUIPMENT_PAGE, "error", "请先填写 target_slot_key。")
		return

	_persist_runtime_config()
	_set_page_state(EQUIPMENT_PAGE, "loading", "正在执行 equip。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%d/equip" % character_id_value,
		{
			"equipment_instance_id": equipment_instance_id_value,
			"target_slot_key": target_slot,
		}
	)

	if not result.get("ok", false):
		_handle_failure(EQUIPMENT_PAGE, result, "执行 equip 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = {
		"character_id": data.get("character_id"),
		"slots": data.get("slot_snapshot", []),
	}
	_render_slots(current_slots)
	_set_page_state(EQUIPMENT_PAGE, "success", "equip 成功，已刷新槽位快照。")


func _on_unequip_pressed() -> void:
	var character_id_value := _parse_character_id(character_id_input.text)
	var target_slot := target_slot_input.text.strip_edges()

	if character_id_value <= 0:
		_set_page_state(EQUIPMENT_PAGE, "error", "请先填写有效的 character_id。")
		return
	if target_slot.is_empty():
		_set_page_state(EQUIPMENT_PAGE, "error", "请先填写 target_slot_key。")
		return

	_persist_runtime_config()
	_set_page_state(EQUIPMENT_PAGE, "loading", "正在执行 unequip。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%d/unequip" % character_id_value,
		{
			"target_slot_key": target_slot,
		}
	)

	if not result.get("ok", false):
		_handle_failure(EQUIPMENT_PAGE, result, "执行 unequip 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_slots = {
		"character_id": data.get("character_id"),
		"slots": data.get("slot_snapshot", []),
	}
	_render_slots(current_slots)
	_set_page_state(EQUIPMENT_PAGE, "success", "unequip 成功，已刷新槽位快照。")


func _on_load_chapters_pressed() -> void:
	_persist_runtime_config()
	_set_page_state(CHAPTER_PAGE, "loading", "正在读取章节列表。")
	var result: Dictionary = await api.request_json("GET", "/api/chapters")

	if not result.get("ok", false):
		_handle_failure(CHAPTER_PAGE, result, "读取章节列表失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_chapters = data
	_render_chapters(data)

	if _as_array(data.get("chapters", [])).is_empty():
		_set_page_state(CHAPTER_PAGE, "empty", "当前没有章节数据。")
	else:
		_set_page_state(CHAPTER_PAGE, "success", "章节列表已加载。")


func _on_load_difficulties_pressed() -> void:
	var stage_id_value := stage_id_input.text.strip_edges()
	if stage_id_value.is_empty():
		_set_page_state(CHAPTER_PAGE, "error", "请先填写 stage_id。")
		return

	_persist_runtime_config()
	_set_page_state(CHAPTER_PAGE, "loading", "正在读取关卡难度列表。")
	var result: Dictionary = await api.request_json("GET", "/api/stages/%s/difficulties" % stage_id_value)

	if not result.get("ok", false):
		_handle_failure(CHAPTER_PAGE, result, "读取关卡难度失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_difficulties = data
	_render_difficulties(data)

	if _as_array(data.get("difficulties", [])).is_empty():
		_set_page_state(CHAPTER_PAGE, "empty", "当前没有难度数据。")
	else:
		_set_page_state(CHAPTER_PAGE, "success", "难度列表已加载，可继续查看首通奖励状态。")


func _on_refresh_reward_status_pressed() -> void:
	var stage_difficulty_id_value := _selected_difficulty_id()
	if stage_difficulty_id_value.is_empty():
		_set_page_state(CHAPTER_PAGE, "error", "请先选择或填写 stage_difficulty_id。")
		return

	_fill_stage_difficulty_inputs(stage_difficulty_id_value)
	_set_page_state(CHAPTER_PAGE, "loading", "正在刷新首通奖励状态。")
	var result: Dictionary = await api.request_json(
		"GET",
		"/api/stage-difficulties/%s/first-clear-reward-status" % stage_difficulty_id_value
	)

	if not result.get("ok", false):
		_handle_failure(CHAPTER_PAGE, result, "读取首通奖励状态失败。")
		return

	current_reward_status = _as_dictionary(result.get("data", {}))
	_render_reward_status()

	var reward_status_text := "无奖励"
	if int(current_reward_status.get("has_reward", 0)) == 1 and int(current_reward_status.get("has_granted", 0)) == 1:
		reward_status_text = "reward claimed"
	elif int(current_reward_status.get("has_reward", 0)) == 1:
		reward_status_text = "reward available"

	if str(current_reward_status.get("grant_status", "")).is_empty():
		_set_page_state(CHAPTER_PAGE, "success", "首通奖励状态已刷新：%s。" % reward_status_text)
	else:
		_set_page_state(
			CHAPTER_PAGE,
			"success",
			"首通奖励状态已刷新：%s，grant_status=%s。" % [reward_status_text, str(current_reward_status.get("grant_status", ""))]
		)


func _on_difficulty_selected(index: int) -> void:
	var metadata: Dictionary = _as_dictionary(difficulty_list.get_item_metadata(index))
	if metadata.is_empty():
		return

	var stage_difficulty_id_value := str(metadata.get("stage_difficulty_id", ""))
	_fill_stage_difficulty_inputs(stage_difficulty_id_value)
	tab_container.current_tab = int(tab_indices.get(PREPARE_PAGE, 0))
	_set_page_state(PREPARE_PAGE, "success", "已选中难度，可继续执行 battle prepare。")


func _on_prepare_pressed() -> void:
	var character_id_value := _parse_character_id(prepare_character_id_input.text)
	var stage_difficulty_id_value := prepare_stage_difficulty_input.text.strip_edges()

	if character_id_value <= 0:
		_set_page_state(PREPARE_PAGE, "error", "请先填写有效的 character_id。")
		return
	if stage_difficulty_id_value.is_empty():
		_set_page_state(PREPARE_PAGE, "error", "请先填写 stage_difficulty_id。")
		return

	_fill_character_inputs(str(character_id_value))
	_fill_stage_difficulty_inputs(stage_difficulty_id_value)
	_set_page_state(PREPARE_PAGE, "preparing", "正在执行 battle prepare。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/battles/prepare",
		{
			"character_id": character_id_value,
			"stage_difficulty_id": stage_difficulty_id_value,
		}
	)

	if not result.get("ok", false):
		_handle_failure(PREPARE_PAGE, result, "battle prepare 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_prepare_result = data
	_render_prepare(data)
	_set_page_state(PREPARE_PAGE, "success", "battle prepare 成功，battle_context_id 已同步到结算页。")


func _on_fill_prepared_monsters_pressed() -> void:
	if current_prepared_monster_ids.is_empty():
		_set_page_state(SETTLE_PAGE, "empty", "当前没有 prepare 结果可复用。")
		return

	killed_monsters_input.text = ",".join(current_prepared_monster_ids)
	_set_page_state(SETTLE_PAGE, "success", "已填入 prepare 阶段的 monster_id 列表。")


func _on_settle_pressed() -> void:
	var character_id_value := _parse_character_id(settle_character_id_input.text)
	var stage_difficulty_id_value := settle_stage_difficulty_input.text.strip_edges()
	var battle_context_id_value := settle_battle_context_input.text.strip_edges()
	var killed_monsters := _parse_killed_monsters()

	if character_id_value <= 0:
		_set_page_state(SETTLE_PAGE, "error", "请先填写有效的 character_id。")
		return
	if stage_difficulty_id_value.is_empty():
		_set_page_state(SETTLE_PAGE, "error", "请先填写 stage_difficulty_id。")
		return
	if battle_context_id_value.is_empty():
		_set_page_state(SETTLE_PAGE, "error", "请先填写 battle_context_id。")
		return
	if killed_monsters.is_empty():
		_set_page_state(SETTLE_PAGE, "error", "请先填写至少一个 killed_monsters。")
		return

	_fill_character_inputs(str(character_id_value))
	_fill_stage_difficulty_inputs(stage_difficulty_id_value)
	_fill_settle_context(battle_context_id_value)
	_set_page_state(SETTLE_PAGE, "settling", "正在执行 battle settle。")
	var result: Dictionary = await api.request_json(
		"POST",
		"/api/battles/settle",
		{
			"character_id": character_id_value,
			"stage_difficulty_id": stage_difficulty_id_value,
			"battle_context_id": battle_context_id_value,
			"is_cleared": 1 if is_cleared_checkbox.button_pressed else 0,
			"killed_monsters": killed_monsters,
		}
	)

	if not result.get("ok", false):
		_handle_failure(SETTLE_PAGE, result, "battle settle 失败。")
		return

	var data: Dictionary = _as_dictionary(result.get("data", {}))
	current_settle_result = data
	current_reward_status = _as_dictionary(data.get("first_clear_reward_status", {}))
	_render_settlement(data)
	_set_page_state(SETTLE_PAGE, "success", "battle settle 成功，已显示掉落、奖励、入包与首通奖励状态。")
	_render_reward_status()

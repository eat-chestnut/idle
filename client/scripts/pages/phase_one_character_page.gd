extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneCharacterPage

const ACTIVE_TINT := Color(0.45, 0.88, 0.62, 1.0)
const IDLE_TINT := Color(0.65, 0.73, 0.88, 1.0)

var hero_name_label: Label
var hero_meta_label: Label
var hero_progress_label: Label
var hero_tag_row: HBoxContainer
var growth_hint_label: Label
var character_cards_box: VBoxContainer
var class_input: LineEdit
var name_input: LineEdit
var character_id_input: LineEdit
var stage_entry_button: Button

var _current_records: Array = []


func _init() -> void:
	setup_page(
		"角色",
		[
			"角色页现在承担竖版主入口：先确认当前角色，再进入背包、穿戴和主线。",
			"Battle 可战斗资格仍以后端 `is_active` 为准；切换当前启用角色必须走真实激活接口。",
		]
	)

	var hero_card := add_card("当前角色", "优先承接当前启用角色；如果没有启用角色，会跟随你当前选中的详情角色。")
	hero_name_label = Label.new()
	hero_name_label.add_theme_font_size_override("font_size", 24)
	hero_card.add_child(hero_name_label)

	hero_meta_label = Label.new()
	hero_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_card.add_child(hero_meta_label)

	hero_progress_label = Label.new()
	hero_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_progress_label.modulate = CARD_TEXT_MUTED
	hero_card.add_child(hero_progress_label)

	hero_tag_row = HBoxContainer.new()
	hero_tag_row.add_theme_constant_override("separation", 8)
	hero_card.add_child(hero_tag_row)

	growth_hint_label = Label.new()
	growth_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_hint_label.modulate = CARD_TEXT_MUTED
	hero_card.add_child(growth_hint_label)

	var hero_buttons := add_button_row(hero_card)
	add_action_button(hero_buttons, "查看角色详情", "load_character")
	add_action_button(hero_buttons, "设为当前出战角色", "activate_current_character")
	add_action_button(hero_buttons, "同步到主流程", "sync_current_character")

	var entry_buttons := add_button_row(hero_card)
	add_action_button(entry_buttons, "去背包", "navigate_inventory")
	add_action_button(entry_buttons, "去穿戴", "navigate_equipment")
	stage_entry_button = add_action_button(entry_buttons, "继续主线", "navigate_stage")
	style_primary_button(stage_entry_button)

	var list_card := add_card("角色切换", "真实角色列表会优先展示当前启用角色，并保留创建后的快速回跳。")
	var list_buttons := add_button_row(list_card)
	add_action_button(list_buttons, "刷新角色列表", "load_characters")

	character_cards_box = VBoxContainer.new()
	character_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_cards_box.add_theme_constant_override("separation", 10)
	list_card.add_child(character_cards_box)

	var create_card := add_card("创建角色", "只保留 phase-one 创建入口，不扩未来成长系统。")
	class_input = add_labeled_input("class_id", "class_jingang", create_card)
	name_input = add_labeled_input("character_name", "联调角色", create_card)
	var create_buttons := add_button_row(create_card)
	add_action_button(create_buttons, "创建角色", "create_character")

	var current_card := add_card("当前选中角色", "这里保留最小技术输入兜底，避免卡住真实联调链路。")
	character_id_input = add_labeled_input("character_id", "", current_card)
	character_id_input.text_changed.connect(_on_character_id_changed)
	var detail_buttons := add_button_row(current_card)
	add_action_button(detail_buttons, "查看角色详情", "load_character")
	add_action_button(detail_buttons, "设为当前出战角色", "activate_current_character")

	show_character_summary({})
	set_character_list([], "")
	show_growth_handoff("当前角色页是成长回流入口：确认角色后，可以继续去背包、穿戴或主线。")


func apply_config(values: Dictionary) -> void:
	class_input.text = str(values.get("class_id", "class_jingang"))
	name_input.text = str(values.get("character_name", "联调角色"))
	character_id_input.text = normalize_id_string(values.get("character_id", "1001"))


func get_create_payload() -> Dictionary:
	return {
		"class_id": class_input.text.strip_edges(),
		"character_name": name_input.text.strip_edges(),
	}


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func set_character_id(character_id: String) -> void:
	character_id_input.text = normalize_id_string(character_id)
	_refresh_hero_from_records()


func set_character_list(records: Array, current_character_id: String) -> String:
	_current_records = records.duplicate(true)
	clear_container(character_cards_box)

	var selected_character_id := current_character_id
	var active_character_id := ""

	for character in _current_records:
		var entry: Dictionary = character if typeof(character) == TYPE_DICTIONARY else {}
		var character_id := normalize_id_string(entry.get("character_id", ""))
		if character_id.is_empty():
			continue

		if int(entry.get("is_active", 0)) == 1:
			active_character_id = character_id

		character_cards_box.add_child(_build_character_card(entry))

	if selected_character_id.is_empty():
		selected_character_id = active_character_id
	if selected_character_id.is_empty() and not _current_records.is_empty():
		selected_character_id = normalize_id_string(_current_records[0].get("character_id", ""))

	if not selected_character_id.is_empty():
		character_id_input.text = selected_character_id

	if character_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "当前还没有角色，请先创建角色。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.modulate = CARD_TEXT_MUTED
		character_cards_box.add_child(empty_label)

	_refresh_hero_from_records()
	return active_character_id


func render_character_list(payload: Dictionary, current_character_id: String) -> void:
	var active_character_id := set_character_list(payload.get("characters", []), current_character_id)
	set_summary_text("当前用户角色=%d | 当前启用角色=%s" % [
		_current_records.size(),
		active_character_id if not active_character_id.is_empty() else "(无)",
	])
	set_output_json(payload)


func show_character_list_empty() -> void:
	set_character_list([], character_id_input.text)
	set_summary_text("当前没有角色，请先创建角色。")
	set_output_json({"characters": []})


func set_recent_characters(records: Array, current_character_id: String) -> void:
	render_character_list({"characters": records}, current_character_id)


func show_character_summary(character: Dictionary) -> void:
	var resolved := character.duplicate(true)
	if resolved.is_empty():
		resolved = _find_character_by_id(character_id_input.text)

	if resolved.is_empty():
		hero_name_label.text = "尚未选择角色"
		hero_meta_label.text = "先读取角色列表，或创建第一个角色。"
		hero_progress_label.text = "角色详情、激活状态和主入口会在这里汇总。"
		clear_container(hero_tag_row)
		return

	var character_id := normalize_id_string(resolved.get("character_id", ""))
	var is_active := int(resolved.get("is_active", 0)) == 1

	hero_name_label.text = "%s  #%s" % [str(resolved.get("character_name", "角色")), character_id]
	hero_meta_label.text = "%s | 等级 %s | exp %s" % [
		str(resolved.get("class_name", resolved.get("class_id", ""))),
		str(resolved.get("level", "1")),
		str(resolved.get("exp", "0")),
	]
	hero_progress_label.text = "未分配属性点 %s | 力量 %s | 灵力 %s | 体魄 %s | 身法 %s" % [
		str(resolved.get("unspent_stat_points", "0")),
		str(resolved.get("added_strength", "0")),
		str(resolved.get("added_mana", "0")),
		str(resolved.get("added_constitution", "0")),
		str(resolved.get("added_dexterity", "0")),
	]

	clear_container(hero_tag_row)
	hero_tag_row.add_child(create_pill("当前详情角色", IDLE_TINT))
	if is_active:
		hero_tag_row.add_child(create_pill("已激活，可直接出战", ACTIVE_TINT))
	else:
		hero_tag_row.add_child(create_pill("未激活，需要先切换出战角色", Color(0.95, 0.68, 0.38, 1.0)))


func show_growth_handoff(text: String) -> void:
	growth_hint_label.text = text


func _build_character_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var character_id := normalize_id_string(entry.get("character_id", ""))
	var is_active := int(entry.get("is_active", 0)) == 1

	var title := Label.new()
	title.text = "%s  #%s" % [str(entry.get("character_name", "角色")), character_id]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "%s | 等级 %s | 当前状态：%s" % [
		str(entry.get("class_name", entry.get("class_id", ""))),
		str(entry.get("level", "1")),
		"已激活" if is_active else "未激活",
	]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	box.add_child(tags)
	tags.add_child(create_pill("职业 %s" % str(entry.get("class_name", entry.get("class_id", ""))), IDLE_TINT))
	if is_active:
		tags.add_child(create_pill("当前启用", ACTIVE_TINT))
	else:
		tags.add_child(create_pill("可切换", Color(0.95, 0.68, 0.38, 1.0)))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var select_button := Button.new()
	select_button.text = "选中"
	select_button.pressed.connect(func() -> void:
		character_id_input.text = character_id
		show_character_summary(entry)
		_emit_context("detail_character_changed", {"character_id": character_id})
	)
	actions.add_child(select_button)

	if not is_active:
		var activate_button := Button.new()
		activate_button.text = "激活"
		activate_button.pressed.connect(func() -> void:
			character_id_input.text = character_id
			show_character_summary(entry)
			_emit_context("detail_character_changed", {"character_id": character_id})
			_emit_action("activate_current_character", {"character_id": character_id})
		)
		actions.add_child(activate_button)

	return card


func _refresh_hero_from_records() -> void:
	show_character_summary(_find_character_by_id(character_id_input.text))


func _find_character_by_id(character_id: String) -> Dictionary:
	var normalized_id := normalize_id_string(character_id)
	if normalized_id.is_empty():
		return {}

	for record in _current_records:
		var entry: Dictionary = record if typeof(record) == TYPE_DICTIONARY else {}
		if normalize_id_string(entry.get("character_id", "")) == normalized_id:
			return entry

	return {}


func _on_character_id_changed(_text: String) -> void:
	_refresh_hero_from_records()
	_emit_context("detail_character_changed", {"character_id": get_character_id_text()})

extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneCharacterPage

const ACTIVE_TINT := Color(0.45, 0.88, 0.62, 1.0)
const IDLE_TINT := Color(0.65, 0.73, 0.88, 1.0)
const WARNING_TINT := Color(0.95, 0.68, 0.38, 1.0)

var current_role_name_label: Label
var current_role_meta_label: Label
var current_role_status_label: Label
var current_role_tag_row: HBoxContainer

var summary_meta_label: Label
var summary_equipment_label: Label
var summary_stats_label: Label
var summary_hint_label: Label

var action_status_label: Label
var activate_button: Button

var inventory_entry_button: Button
var equipment_entry_button: Button
var stage_entry_button: Button

var recommendation_label: Label
var handoff_label: Label
var recommendation_button: Button
var _recommendation_action := ""
var _recommendation_payload: Dictionary = {}

var character_cards_box: VBoxContainer
var class_input: LineEdit
var name_input: LineEdit
var character_id_input: LineEdit
var tech_toggle: CheckBox
var tech_box: VBoxContainer

var _current_records: Array = []
var _current_stat_snapshot: Dictionary = {}
var _current_equipment_context: Dictionary = {}


func _init() -> void:
	setup_page("角色", [])

	var current_card := add_card("我是这名角色", "先认出你是谁，再决定接下来先去哪。")
	current_role_name_label = Label.new()
	current_role_name_label.add_theme_font_size_override("font_size", 26)
	current_card.add_child(current_role_name_label)

	current_role_meta_label = Label.new()
	current_role_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_card.add_child(current_role_meta_label)

	current_role_status_label = Label.new()
	current_role_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_role_status_label.modulate = CARD_TEXT_MUTED
	current_card.add_child(current_role_status_label)

	current_role_tag_row = HBoxContainer.new()
	current_role_tag_row.add_theme_constant_override("separation", 8)
	current_card.add_child(current_role_tag_row)

	var summary_card := add_card("这名角色近况", "这名角色现在能做什么，会先在这里说清楚。")
	summary_meta_label = Label.new()
	summary_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_card.add_child(summary_meta_label)

	summary_equipment_label = Label.new()
	summary_equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_card.add_child(summary_equipment_label)

	summary_stats_label = Label.new()
	summary_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_card.add_child(summary_stats_label)

	summary_hint_label = Label.new()
	summary_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_hint_label.modulate = CARD_TEXT_MUTED
	summary_card.add_child(summary_hint_label)

	var action_card := add_card("现在做什么", "先把角色就位，再往主线、背包或穿戴走。")
	action_status_label = Label.new()
	action_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_status_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(action_status_label)

	var action_buttons := add_button_row(action_card)
	activate_button = add_action_button(action_buttons, "启用这名角色", "activate_current_character")
	style_primary_button(activate_button, ACTIVE_TINT)
	add_action_button(action_buttons, "刷新角色列表", "load_characters")

	var entry_card := add_card("常走入口", "背包、穿戴、主线是这名角色当前最常走的三条路。")
	var entry_buttons := add_button_row(entry_card)
	inventory_entry_button = add_action_button(entry_buttons, "去背包", "navigate_inventory")
	equipment_entry_button = add_action_button(entry_buttons, "去穿戴", "navigate_equipment")
	stage_entry_button = add_action_button(entry_buttons, "去主线", "navigate_stage")
	style_primary_button(stage_entry_button)

	var recommendation_card := add_card("下一步去哪", "优先告诉你现在最顺的一步。")
	recommendation_label = Label.new()
	recommendation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recommendation_card.add_child(recommendation_label)

	handoff_label = Label.new()
	handoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	handoff_label.modulate = CARD_TEXT_MUTED
	recommendation_card.add_child(handoff_label)

	var recommendation_buttons := add_button_row(recommendation_card)
	recommendation_button = add_button(recommendation_buttons, "去主线", _on_recommendation_pressed)
	style_primary_button(recommendation_button)

	var list_card := add_card("换个角色看", "已有角色会突出当前启用角色；你也可以改看别的角色。")
	character_cards_box = VBoxContainer.new()
	character_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_cards_box.add_theme_constant_override("separation", 10)
	list_card.add_child(character_cards_box)

	var create_card := add_card("再开新角色", "只有真的还没有角色，或你想开一个新角色时才需要这里。")
	class_input = add_labeled_input("职业", "class_jingang", create_card)
	name_input = add_labeled_input("角色名称", "山海行者", create_card)
	var create_buttons := add_button_row(create_card)
	add_action_button(create_buttons, "创建新角色", "create_character")

	var tech_card := add_card("调试区", "角色编号和手动读取都留在这里，不占首屏。")
	tech_toggle = add_check_box("显示角色编号输入", false, tech_card)
	tech_toggle.toggled.connect(_on_tech_toggle)

	tech_box = VBoxContainer.new()
	tech_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tech_box.visible = false
	tech_card.add_child(tech_box)

	character_id_input = add_labeled_input("character_id（调试）", "", tech_box)
	character_id_input.text_changed.connect(_on_character_id_changed)
	var tech_buttons := add_button_row(tech_box)
	add_action_button(tech_buttons, "读取这个编号", "load_character")
	add_action_button(tech_buttons, "同步当前角色", "sync_current_character")

	show_character_summary({})
	set_character_list([], "")
	show_growth_handoff("")
	set_output_text("")
	_move_secondary_sections_to_bottom()


func apply_config(values: Dictionary) -> void:
	class_input.text = str(values.get("class_id", "class_jingang"))
	name_input.text = str(values.get("character_name", "山海行者"))
	character_id_input.text = normalize_id_string(values.get("character_id", ""))


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


func set_character_stat_snapshot(snapshot: Dictionary) -> void:
	_current_stat_snapshot = snapshot.duplicate(true)
	_refresh_hero_from_records()


func set_character_equipment_context(context: Dictionary) -> void:
	_current_equipment_context = context.duplicate(true)
	_refresh_hero_from_records()


func set_character_list(records: Array, current_character_id: String) -> String:
	_current_records = records.duplicate(true)

	var selected_character_id := _determine_selected_character_id(current_character_id)
	if selected_character_id != get_character_id_text():
		character_id_input.text = selected_character_id

	_rebuild_character_cards(selected_character_id)
	_refresh_hero_from_records()
	return _find_active_character_id()


func render_character_list(payload: Dictionary, current_character_id: String) -> void:
	var active_character_id := set_character_list(payload.get("characters", []), current_character_id)
	if _current_records.is_empty():
		set_summary_text("当前还没有角色，先创建一个新的当前角色。")
	else:
		var active_name := "暂未启用角色"
		if not active_character_id.is_empty():
			active_name = _describe_character_brief(_find_character_by_id(active_character_id))
		set_summary_text("当前共有 %d 名角色；%s。" % [_current_records.size(), active_name])
	set_output_json(payload)


func show_character_list_empty() -> void:
	set_character_list([], character_id_input.text)
	set_summary_text("当前还没有角色，创建完成后就能继续前往背包、穿戴和主线。")
	set_output_json({"characters": []})


func set_recent_characters(records: Array, current_character_id: String) -> void:
	render_character_list({"characters": records}, current_character_id)


func show_character_summary(character: Dictionary) -> void:
	var resolved := character.duplicate(true)
	if resolved.is_empty():
		resolved = _find_character_by_id(character_id_input.text)

	var has_records := not _current_records.is_empty()
	var has_character := not resolved.is_empty()
	var is_active := int(resolved.get("is_active", 0)) == 1

	clear_container(current_role_tag_row)

	if not has_character:
		current_role_name_label.text = "当前角色待确认"
		if has_records:
			current_role_meta_label.text = "已有角色可用，先从下方角色列表里挑一名当前主角。"
			current_role_status_label.text = "锁定后就能直接去背包、穿戴或主线。"
			current_role_tag_row.add_child(create_pill("等待选择", IDLE_TINT))
		else:
			current_role_meta_label.text = "当前还没有角色。"
			current_role_status_label.text = "先创建角色，创建后就能直接进入背包、穿戴和主线。"
			current_role_tag_row.add_child(create_pill("等待创建", WARNING_TINT))

		summary_meta_label.text = "锁定当前角色后，这里会马上告诉你该往哪里走。"
		summary_equipment_label.text = "当前穿戴：待确认"
		summary_stats_label.text = "攻击：待确认 | 防御：待确认 | 生命：待确认"
		summary_hint_label.text = "最近一次正式出战的属性快照，会在这里回来看。"
	else:
		current_role_name_label.text = str(resolved.get("character_name", "角色"))
		current_role_meta_label.text = "%s | 等级 %s" % [
			str(resolved.get("class_name", resolved.get("class_id", ""))),
			str(resolved.get("level", "1")),
		]
		current_role_status_label.text = (
			"已经启用，下一步更适合去主线定下这一场。"
			if is_active
			else "这名角色还没启用，先启用后再去主线会更顺。"
		)
		current_role_tag_row.add_child(create_pill("当前主角", IDLE_TINT))
		current_role_tag_row.add_child(
			create_pill("当前启用" if is_active else "待启用", ACTIVE_TINT if is_active else WARNING_TINT)
		)
		current_role_tag_row.add_child(
			create_pill("可出战" if is_active else "暂不可出战", ACTIVE_TINT if is_active else WARNING_TINT)
		)

		summary_meta_label.text = "%s | 等级 %s | 未分配属性点 %s" % [
			str(resolved.get("class_name", resolved.get("class_id", ""))),
			str(resolved.get("level", "1")),
			str(resolved.get("unspent_stat_points", "0")),
		]
		summary_equipment_label.text = _build_equipment_summary_text(resolved)
		summary_stats_label.text = _build_stat_summary_text(resolved)
		summary_hint_label.text = _build_summary_hint_text(resolved)

	_refresh_action_panel(resolved)
	_refresh_entry_buttons(has_character)
	_refresh_recommendation(resolved)
	_rebuild_character_cards(get_character_id_text())


func show_growth_handoff(text: String) -> void:
	handoff_label.text = text


func _rebuild_character_cards(selected_character_id: String) -> void:
	clear_container(character_cards_box)

	if _current_records.is_empty():
		var empty_label := Label.new()
		empty_label.text = "当前还没有角色，先创建一个新的当前角色吧。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.modulate = CARD_TEXT_MUTED
		character_cards_box.add_child(empty_label)
		return

	for character in _current_records:
		var entry: Dictionary = character if typeof(character) == TYPE_DICTIONARY else {}
		if normalize_id_string(entry.get("character_id", "")).is_empty():
			continue
		character_cards_box.add_child(_build_character_card(entry, selected_character_id))


func _build_character_card(entry: Dictionary, selected_character_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_create_character_card_style(
			normalize_id_string(entry.get("character_id", "")) == selected_character_id,
			int(entry.get("is_active", 0)) == 1
		)
	)

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
	var is_selected := character_id == selected_character_id
	var is_active := int(entry.get("is_active", 0)) == 1

	var title := Label.new()
	title.text = str(entry.get("character_name", "角色"))
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "%s | 等级 %s | %s" % [
		str(entry.get("class_name", entry.get("class_id", ""))),
		str(entry.get("level", "1")),
		"当前启用" if is_active else "未启用",
	]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	box.add_child(tags)
	if is_selected:
		tags.add_child(create_pill("当前查看", IDLE_TINT))
	if is_active:
		tags.add_child(create_pill("可出战", ACTIVE_TINT))
	else:
		tags.add_child(create_pill("可切换后启用", WARNING_TINT))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var select_button := Button.new()
	select_button.text = "正在查看" if is_selected else "看这名角色"
	select_button.disabled = is_selected
	select_button.pressed.connect(func() -> void:
		character_id_input.text = character_id
		show_character_summary(entry)
		_emit_context("detail_character_changed", {"character_id": character_id})
	)
	actions.add_child(select_button)

	if not is_active:
		var activate_card_button := Button.new()
		activate_card_button.text = "启用这名角色"
		activate_card_button.pressed.connect(func() -> void:
			character_id_input.text = character_id
			show_character_summary(entry)
			_emit_context("detail_character_changed", {"character_id": character_id})
			_emit_action("activate_current_character", {"character_id": character_id})
		)
		actions.add_child(activate_card_button)

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


func _find_active_character_id() -> String:
	for record in _current_records:
		var entry: Dictionary = record if typeof(record) == TYPE_DICTIONARY else {}
		if int(entry.get("is_active", 0)) == 1:
			return normalize_id_string(entry.get("character_id", ""))
	return ""


func _determine_selected_character_id(current_character_id: String) -> String:
	var candidates := [
		normalize_id_string(current_character_id),
		get_character_id_text(),
		_find_active_character_id(),
	]

	for candidate in candidates:
		if candidate.is_empty():
			continue
		if not _find_character_by_id(candidate).is_empty():
			return candidate

	if _current_records.is_empty():
		return ""

	var first_entry: Dictionary = _current_records[0] if typeof(_current_records[0]) == TYPE_DICTIONARY else {}
	return normalize_id_string(first_entry.get("character_id", ""))


func _describe_character_brief(character: Dictionary) -> String:
	if character.is_empty():
		return "还没有可承接的当前角色"
	return "%s 已作为当前角色" % str(character.get("character_name", "角色"))


func _build_stat_summary_text(character: Dictionary) -> String:
	if _stat_snapshot_matches_character(character):
		var prefix := "最近一次正式出战" if _has_recent_equipment_change(character) else "攻击"
		if prefix == "攻击":
			return "攻击：%s | 防御：物防 %s / 法防 %s | 生命：%s" % [
				str(_current_stat_snapshot.get("attack", "-")),
				str(_current_stat_snapshot.get("physical_defense", "-")),
				str(_current_stat_snapshot.get("magic_defense", "-")),
				str(_current_stat_snapshot.get("hp", "-")),
			]
		return "%s：攻击 %s | 防御 物防 %s / 法防 %s | 生命 %s" % [
			prefix,
			str(_current_stat_snapshot.get("attack", "-")),
			str(_current_stat_snapshot.get("physical_defense", "-")),
			str(_current_stat_snapshot.get("magic_defense", "-")),
			str(_current_stat_snapshot.get("hp", "-")),
		]

	if _has_recent_equipment_change(character):
		return "当前成长：最近一次换装已经同步，精确战斗属性会在下一场正式出战时回读。"

	return "攻击：待出战确认 | 防御：待出战确认 | 生命：待出战确认"


func _build_summary_hint_text(character: Dictionary) -> String:
	if character.is_empty():
		return "锁定当前角色后，这里会立刻切到可推进状态。"
	if _has_recent_equipment_change(character):
		if _stat_snapshot_matches_character(character):
			return "最近一次换装已经同步到角色；上面数值仍是最近一次正式出战摘要，如要确认这次变化，直接回主线或出战会更自然。"
		return "最近一次换装已经同步到角色；当前穿戴是最新的，精确战斗属性会在下一场正式出战时回读。"
	if _stat_snapshot_matches_character(character):
		return "以上攻击、防御、生命来自最近一次正式出战快照。"
	if int(character.get("is_active", 0)) == 1:
		return "这名角色已经可以出战；去主线选关后，出战页会带回正式属性摘要。"
	return "先启用这名角色，再去主线和出战页会更顺。"


func _stat_snapshot_matches_character(character: Dictionary) -> bool:
	if character.is_empty() or _current_stat_snapshot.is_empty():
		return false

	return normalize_id_string(_current_stat_snapshot.get("character_id", "")) == normalize_id_string(character.get("character_id", ""))


func _equipment_context_matches_character(character: Dictionary) -> bool:
	if character.is_empty() or _current_equipment_context.is_empty():
		return false

	return normalize_id_string(_current_equipment_context.get("character_id", "")) == normalize_id_string(character.get("character_id", ""))


func _has_recent_equipment_change(character: Dictionary) -> bool:
	return _equipment_context_matches_character(character) and not str(_current_equipment_context.get("change_type", "")).strip_edges().is_empty()


func _build_equipment_summary_text(character: Dictionary) -> String:
	if not _equipment_context_matches_character(character):
		return "当前穿戴：回到穿戴页后，这里会承接最新换装状态。"

	var slot_count := int(_current_equipment_context.get("slot_count", 0))
	var equipped_count := int(_current_equipment_context.get("equipped_count", 0))
	var empty_count := int(_current_equipment_context.get("empty_count", maxi(slot_count - equipped_count, 0)))
	var has_slot_snapshot := bool(_current_equipment_context.get("has_slot_snapshot", false))
	var base_text := "当前穿戴：已同步最新穿戴状态。"
	if has_slot_snapshot and slot_count > 0:
		base_text = "当前穿戴：已穿戴 %d / 空槽 %d。" % [equipped_count, empty_count]

	if not _has_recent_equipment_change(character):
		return base_text

	var slot_name := str(_current_equipment_context.get("slot_name", "当前槽位")).strip_edges()
	var item_name := str(_current_equipment_context.get("item_name", "当前装备")).strip_edges()
	match str(_current_equipment_context.get("change_type", "")):
		"equip":
			return "%s 最近一次换装：%s 现在穿着 %s。" % [base_text, slot_name, item_name]
		"unequip":
			return "%s 最近一次换装：%s 已卸下 %s。" % [base_text, slot_name, item_name]
		_:
			return base_text


func _refresh_action_panel(character: Dictionary) -> void:
	if _current_records.is_empty():
		action_status_label.text = "当前还没有角色，先创建一名角色。"
		activate_button.text = "先创建角色"
		activate_button.disabled = true
		return

	if character.is_empty():
		action_status_label.text = "先从下方角色列表里定下一名角色，再决定是否启用。"
		activate_button.text = "启用这名角色"
		activate_button.disabled = true
		return

	if int(character.get("is_active", 0)) == 1:
		if _has_recent_equipment_change(character):
			action_status_label.text = "最近一次换装已经同步到当前角色；现在最自然的是去主线或出战确认这次变化，也可以回穿戴继续调整。"
			activate_button.text = "已经启用"
			activate_button.disabled = true
			return
		action_status_label.text = "这名角色已经能直接上阵，可以继续去背包、穿戴或主线。"
		activate_button.text = "已经启用"
		activate_button.disabled = true
		return

	action_status_label.text = "当前角色还没启用，先启用后再去主线推进最顺。"
	activate_button.text = "启用这名角色"
	activate_button.disabled = false


func _refresh_entry_buttons(has_character: bool) -> void:
	inventory_entry_button.disabled = not has_character
	equipment_entry_button.disabled = not has_character
	stage_entry_button.disabled = not has_character


func _refresh_recommendation(character: Dictionary) -> void:
	if _current_records.is_empty():
		recommendation_label.text = "先创建角色。创建完成后，这一页就会变成主入口。"
		_set_recommendation_action("创建新角色", "create_character")
		return

	if character.is_empty():
		recommendation_label.text = "先从角色列表里选一名当前主角。"
		_set_recommendation_action("刷新角色列表", "load_characters")
		return

	if int(character.get("is_active", 0)) == 0:
		recommendation_label.text = "先启用这名角色，再去主线推进会更自然。"
		_set_recommendation_action("启用这名角色", "activate_current_character")
		return

	if _has_recent_equipment_change(character):
		recommendation_label.text = "最近一次换装已经接回角色，最顺的下一步是去主线或出战确认这次变化。"
		_set_recommendation_action("去主线", "navigate_stage")
		return

	recommendation_label.text = "先去主线推进；如果想先整理收益，也可以顺手前往背包或穿戴。"
	_set_recommendation_action("去主线", "navigate_stage")


func _set_recommendation_action(button_text: String, action: String, payload: Dictionary = {}) -> void:
	_recommendation_action = action
	_recommendation_payload = payload.duplicate(true)
	recommendation_button.text = button_text
	recommendation_button.disabled = action.strip_edges().is_empty()


func _create_character_card_style(is_selected: bool, is_active: bool) -> StyleBoxFlat:
	var style := _create_card_style()
	if is_selected:
		style.border_color = PRIMARY_BUTTON_TINT
		style.bg_color = Color(0.12, 0.16, 0.24, 0.98)
	elif is_active:
		style.border_color = ACTIVE_TINT
		style.bg_color = Color(0.09, 0.14, 0.18, 0.98)
	return style


func _move_secondary_sections_to_bottom() -> void:
	var output_panel := _resolve_card_panel(_output_toggle)
	if output_panel != null and output_panel.get_parent() == _body:
		_body.move_child(output_panel, _body.get_child_count() - 1)

	var status_panel := _resolve_card_panel(_state_badge_row)
	if status_panel != null and status_panel.get_parent() == _shell:
		_shell.move_child(status_panel, _shell.get_child_count() - 1)


func _resolve_card_panel(control: Control) -> Control:
	if control == null:
		return null
	var parent := control.get_parent()
	if parent == null or parent.get_parent() == null or parent.get_parent().get_parent() == null:
		return null
	return parent.get_parent().get_parent()


func _on_recommendation_pressed() -> void:
	if _recommendation_action.strip_edges().is_empty():
		return
	_emit_action(_recommendation_action, _recommendation_payload)


func _on_tech_toggle(pressed: bool) -> void:
	tech_box.visible = pressed


func _on_character_id_changed(_text: String) -> void:
	_refresh_hero_from_records()
	_emit_context("detail_character_changed", {"character_id": get_character_id_text()})

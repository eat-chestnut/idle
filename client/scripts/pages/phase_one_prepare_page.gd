extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOnePreparePage

const CHARACTER_TINT := Color(0.56, 0.82, 0.96, 1.0)
const BATTLE_TINT := Color(0.99, 0.72, 0.40, 1.0)
const REWARD_TINT := Color(0.55, 0.86, 0.68, 1.0)
const WARNING_TINT := Color(0.95, 0.68, 0.38, 1.0)

var recent_character_selector: OptionButton
var recent_stage_difficulty_selector: OptionButton
var override_toggle: CheckBox
var override_box: VBoxContainer
var character_id_input: LineEdit
var stage_difficulty_input: LineEdit

var header_target_label: Label
var header_character_label: Label
var header_tag_row: HBoxContainer

var character_name_label: Label
var character_status_label: Label
var character_stat_label: Label
var character_tag_row: HBoxContainer

var route_title_label: Label
var route_meta_label: Label
var route_recommendation_label: Label
var route_tag_row: HBoxContainer

var enemy_summary_label: Label
var enemy_hint_label: Label
var monster_rows_box: VBoxContainer

var reward_status_label: Label
var reward_detail_label: Label
var reward_tag_row: HBoxContainer

var action_status_label: Label
var primary_prepare_button: Button
var activate_button: Button
var back_stage_button: Button

var _character_context: Dictionary = {}
var _route_context: Dictionary = {}
var _reward_status: Dictionary = {}
var _prepare_payload: Dictionary = {}


func _init() -> void:
	setup_page("出战", [])

	var header_card := add_card("这场要不要打", "")
	header_target_label = Label.new()
	header_target_label.add_theme_font_size_override("font_size", 24)
	header_card.add_child(header_target_label)

	header_character_label = Label.new()
	header_character_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(header_character_label)

	header_tag_row = HBoxContainer.new()
	header_tag_row.add_theme_constant_override("separation", 8)
	header_card.add_child(header_tag_row)

	var character_card := add_card("出战的是谁", "")
	character_name_label = Label.new()
	character_name_label.add_theme_font_size_override("font_size", 22)
	character_card.add_child(character_name_label)

	character_status_label = Label.new()
	character_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_card.add_child(character_status_label)

	character_stat_label = Label.new()
	character_stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_stat_label.modulate = CARD_TEXT_MUTED
	character_card.add_child(character_stat_label)

	character_tag_row = HBoxContainer.new()
	character_tag_row.add_theme_constant_override("separation", 8)
	character_card.add_child(character_tag_row)

	var route_card := add_card("这一场打哪里", "")
	route_title_label = Label.new()
	route_title_label.add_theme_font_size_override("font_size", 22)
	route_card.add_child(route_title_label)

	route_meta_label = Label.new()
	route_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_card.add_child(route_meta_label)

	route_recommendation_label = Label.new()
	route_recommendation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_recommendation_label.modulate = CARD_TEXT_MUTED
	route_card.add_child(route_recommendation_label)

	route_tag_row = HBoxContainer.new()
	route_tag_row.add_theme_constant_override("separation", 8)
	route_card.add_child(route_tag_row)

	var enemy_card := add_card("这一场会遇到谁", "")
	enemy_summary_label = Label.new()
	enemy_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_card.add_child(enemy_summary_label)

	enemy_hint_label = Label.new()
	enemy_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_hint_label.modulate = CARD_TEXT_MUTED
	enemy_card.add_child(enemy_hint_label)

	monster_rows_box = VBoxContainer.new()
	monster_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	monster_rows_box.add_theme_constant_override("separation", 10)
	enemy_card.add_child(monster_rows_box)

	var reward_card := add_card("这一档奖励", "")
	reward_status_label = Label.new()
	reward_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_card.add_child(reward_status_label)

	reward_detail_label = Label.new()
	reward_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_detail_label.modulate = CARD_TEXT_MUTED
	reward_card.add_child(reward_detail_label)

	reward_tag_row = HBoxContainer.new()
	reward_tag_row.add_theme_constant_override("separation", 8)
	reward_card.add_child(reward_tag_row)

	var action_card := add_card("开打这一场", "")
	action_status_label = Label.new()
	action_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(action_status_label)

	var buttons := add_button_row(action_card)
	primary_prepare_button = add_action_button(buttons, "开打这一场", "prepare")
	style_primary_button(primary_prepare_button)
	activate_button = add_action_button(buttons, "先启用角色", "activate_battle_character")
	back_stage_button = add_action_button(buttons, "回主线改目标", "navigate_stage")

	var tech_card := add_card("调试区", "快速切换和技术字段都留在这里，不占首屏。")
	recent_character_selector = add_labeled_option_button("快速切换角色", tech_card)
	recent_character_selector.item_selected.connect(_on_recent_character_selected)

	recent_stage_difficulty_selector = add_labeled_option_button("快速切换目标难度", tech_card)
	recent_stage_difficulty_selector.item_selected.connect(_on_recent_stage_difficulty_selected)

	override_toggle = add_check_box("显示调试输入", false, tech_card)
	override_toggle.toggled.connect(_on_override_toggled)
	override_box = VBoxContainer.new()
	override_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	override_box.visible = false
	tech_card.add_child(override_box)

	character_id_input = add_labeled_input("character_id（调试）", "", override_box)
	character_id_input.text_changed.connect(_on_character_id_changed)

	stage_difficulty_input = add_labeled_input("stage_difficulty_id（调试）", "", override_box)
	stage_difficulty_input.text_changed.connect(_on_stage_difficulty_changed)

	render_prepare_context({}, {}, {})
	show_prepare_summary({})
	_move_secondary_sections_to_bottom()


func apply_config(values: Dictionary) -> void:
	character_id_input.text = normalize_id_string(
		values.get("battle_character_id", values.get("character_id", ""))
	)
	stage_difficulty_input.text = str(values.get("stage_difficulty_id", "")).strip_edges()


func render_prepare_context(character: Dictionary, route_context: Dictionary, reward_status: Dictionary) -> void:
	_character_context = character.duplicate(true)
	_route_context = route_context.duplicate(true)
	_reward_status = reward_status.duplicate(true)
	_refresh_prepare_page()


func set_recent_characters(records: Array, current_character_id: String) -> void:
	var options: Array = []
	for record in records:
		var entry = record if typeof(record) == TYPE_DICTIONARY else {}
		var character_id = normalize_id_string(entry.get("character_id", ""))
		if character_id.is_empty():
			continue

		var label = "%s #%s" % [str(entry.get("character_name", "角色")), character_id]
		if entry.has("is_active") and int(entry.get("is_active", 0)) == 1:
			label += " [当前可战斗]"
		elif entry.has("is_active"):
			label += " [待启用]"

		options.append({
			"label": label,
			"value": character_id,
			"record": entry,
		})

	replace_options(recent_character_selector, options, "暂无角色记录", current_character_id)


func set_recent_stage_difficulties(stage_difficulty_ids: Array, current_stage_difficulty_id: String) -> void:
	var options: Array = []
	for stage_difficulty_id in stage_difficulty_ids:
		var normalized = str(stage_difficulty_id).strip_edges()
		if normalized.is_empty():
			continue
		options.append({
			"label": normalized,
			"value": normalized,
		})

	replace_options(
		recent_stage_difficulty_selector,
		options,
		"暂无难度记录",
		current_stage_difficulty_id
	)


func set_character_id(character_id: String) -> void:
	character_id_input.text = normalize_id_string(character_id)


func set_stage_difficulty_id(stage_difficulty_id: String) -> void:
	stage_difficulty_input.text = stage_difficulty_id.strip_edges()


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func get_stage_difficulty_text() -> String:
	return stage_difficulty_input.text.strip_edges()


func show_prepare_summary(payload: Dictionary) -> void:
	_prepare_payload = payload.duplicate(true)
	_refresh_prepare_page()
	if payload.is_empty():
		set_output_text("")
	else:
		set_output_json(payload)


func _refresh_prepare_page() -> void:
	var preview_payload := _matched_prepare_payload()
	var preview_character := _as_dictionary(preview_payload.get("character", {}))
	var preview_stats := _as_dictionary(preview_payload.get("character_stats", {}))
	var preview_stage_difficulty := _as_dictionary(preview_payload.get("stage_difficulty", {}))
	var monster_list: Array = _as_array(preview_payload.get("monster_list", []))

	_refresh_header()
	_refresh_character_summary(preview_character, preview_stats)
	_refresh_route_summary(preview_stage_difficulty)
	_refresh_enemy_summary(monster_list)
	_refresh_reward_summary()
	_refresh_action_area()


func _refresh_header() -> void:
	var character := _character_context
	var route_context := _route_context
	var chapter_name := str(route_context.get("chapter_name", "当前目标待确认"))
	var stage_name := str(route_context.get("stage_name", "请先回主线选关"))
	var difficulty_name := str(route_context.get("difficulty_name", "请先选难度"))

	header_target_label.text = "这一场：%s / %s / %s" % [chapter_name, stage_name, difficulty_name]
	if character.is_empty():
		header_character_label.text = "出战角色：待确认"
	else:
		header_character_label.text = "出战角色：%s" % _character_title(character)

	clear_container(header_tag_row)
	if not character.is_empty():
		header_tag_row.add_child(create_pill("当前角色", CHARACTER_TINT))
		if int(character.get("is_active", 0)) == 1:
			header_tag_row.add_child(create_pill("可开始战斗", REWARD_TINT))
		else:
			header_tag_row.add_child(create_pill("需先启用", WARNING_TINT))
	if not str(route_context.get("stage_difficulty_id", "")).is_empty():
		header_tag_row.add_child(create_pill("当前目标", BATTLE_TINT))


func _refresh_character_summary(preview_character: Dictionary, preview_stats: Dictionary) -> void:
	var character := _character_context
	clear_container(character_tag_row)

	if character.is_empty():
		character_name_label.text = "当前角色待确认"
		character_status_label.text = "先去角色页认出这次出战的是谁，或回主线改目标。"
		character_stat_label.text = "攻击 / 防御 / 生命会在开打前按正式快照确认。"
		character_tag_row.add_child(create_pill("等待角色", CHARACTER_TINT))
		return

	character_name_label.text = _character_title(character)
	if int(character.get("is_active", 0)) == 1:
		character_status_label.text = "这名角色已经能直接开打。"
		character_tag_row.add_child(create_pill("当前启用", REWARD_TINT))
		character_tag_row.add_child(create_pill("可出战", REWARD_TINT))
	else:
		character_status_label.text = "这名角色还没启用，先启用后再开始战斗会更顺。"
		character_tag_row.add_child(create_pill("待启用", WARNING_TINT))
		character_tag_row.add_child(create_pill("暂不可出战", WARNING_TINT))

	if not preview_character.is_empty() and not preview_stats.is_empty():
		character_stat_label.text = "攻击：%s | 防御：物防 %s / 法防 %s | 生命：%s" % [
			str(preview_stats.get("attack", "-")),
			str(preview_stats.get("physical_defense", "-")),
			str(preview_stats.get("magic_defense", "-")),
			str(preview_stats.get("hp", "-")),
		]
	else:
		character_stat_label.text = "攻击 / 防御 / 生命会在点击“开始战斗”后按正式快照确认。"


func _refresh_route_summary(preview_stage_difficulty: Dictionary) -> void:
	var route_context := _route_context
	var chapter_name := str(route_context.get("chapter_name", "当前章节待确认"))
	var stage_name := str(route_context.get("stage_name", "请先回主线选关"))
	var difficulty_name := str(route_context.get("difficulty_name", "请先选难度"))
	var recommended_power := str(route_context.get("recommended_power", "-"))
	if not preview_stage_difficulty.is_empty():
		difficulty_name = str(preview_stage_difficulty.get("difficulty_name", difficulty_name))
		recommended_power = str(preview_stage_difficulty.get("recommended_power", recommended_power))

	route_title_label.text = "%s / %s / %s" % [chapter_name, stage_name, difficulty_name]
	route_meta_label.text = "去向：%s · %s · %s | 推荐战力 %s" % [
		chapter_name,
		stage_name,
		difficulty_name,
		recommended_power,
	]

	if str(route_context.get("stage_difficulty_id", "")).is_empty():
		route_recommendation_label.text = "先回主线定下这一档，这里就会进入可开打状态。"
	else:
		route_recommendation_label.text = "目标已经定下；确认角色状态后就可以决定要不要开打。"

	clear_container(route_tag_row)
	if not str(route_context.get("chapter_name", "")).is_empty():
		route_tag_row.add_child(create_pill("当前目标", BATTLE_TINT))
	if not str(route_context.get("difficulty_key", "")).is_empty():
		route_tag_row.add_child(create_pill("难度 %s" % str(route_context.get("difficulty_key", "")), CHARACTER_TINT))
	if not str(route_context.get("stage_difficulty_id", "")).is_empty():
		route_tag_row.add_child(create_pill("当前挑战", BATTLE_TINT))


func _refresh_enemy_summary(monster_list: Array) -> void:
	clear_container(monster_rows_box)

	if monster_list.is_empty():
		enemy_summary_label.text = "这一场目标已经锁定，开打后就会正式亮出敌方阵容。"
		enemy_hint_label.text = "准备完成后，这里会先告诉你敌人数量、波次和主要目标。"

		var empty_monsters := Label.new()
		empty_monsters.text = "点击“开始战斗”后，这里会展示敌方数量、波次和主要目标。"
		empty_monsters.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_monsters.modulate = CARD_TEXT_MUTED
		monster_rows_box.add_child(empty_monsters)
		return

	var wave_numbers: Dictionary = {}
	var boss_count := 0
	for monster in monster_list:
		var entry: Dictionary = monster if typeof(monster) == TYPE_DICTIONARY else {}
		wave_numbers[int(entry.get("wave_no", 1))] = true
		if str(entry.get("monster_role", "")) == "boss_enemy":
			boss_count += 1
		monster_rows_box.add_child(_build_monster_card(entry))

	enemy_summary_label.text = "本次敌方：%d 名敌人 | %d 波 | 首领 %d 名。" % [
		monster_list.size(),
		wave_numbers.size(),
		boss_count,
	]
	if boss_count > 0:
		enemy_hint_label.text = "这一场会遇到首领目标，建议确认当前角色状态后再开打。"
	else:
		enemy_hint_label.text = "当前阵容以普通敌人为主，开始战斗后会立即进入正式战场。"


func _refresh_reward_summary() -> void:
	reward_status_label.text = _format_reward_status(_reward_status)
	if _reward_status.is_empty():
		reward_detail_label.text = "首通奖励状态会跟着当前难度自动同步。"
	else:
		reward_detail_label.text = "这一档奖励状态已经同步，开打后会在收获页正式回显。"

	clear_container(reward_tag_row)
	reward_tag_row.add_child(create_pill(_reward_tag_text(_reward_status), REWARD_TINT if int(_reward_status.get("has_reward", 0)) == 1 else CHARACTER_TINT))


func _refresh_action_area() -> void:
	var has_character := not _character_context.is_empty()
	var has_difficulty := not str(_route_context.get("stage_difficulty_id", "")).is_empty()
	var is_active := int(_character_context.get("is_active", 0)) == 1
	var can_start := has_character and has_difficulty and is_active

	if not has_character:
		action_status_label.text = "先认出这次出战的是谁，再决定要不要开打。"
	elif not has_difficulty:
		action_status_label.text = "先回主线定下这一档，再决定要不要开打。"
	elif not is_active:
		action_status_label.text = "这名角色还没启用，先启用后就能开始战斗。"
	else:
		action_status_label.text = "角色和目标都已定下，可以直接开打。"

	primary_prepare_button.disabled = not can_start
	activate_button.visible = has_character and not is_active
	activate_button.disabled = not has_character or is_active
	back_stage_button.disabled = false


func _matched_prepare_payload() -> Dictionary:
	if _prepare_payload.is_empty():
		return {}

	var prepared_character := _as_dictionary(_prepare_payload.get("character", {}))
	var prepared_stage_difficulty := _as_dictionary(_prepare_payload.get("stage_difficulty", {}))
	var expected_character_id := get_character_id_text()
	var expected_stage_difficulty_id := str(_route_context.get("stage_difficulty_id", get_stage_difficulty_text())).strip_edges()

	if not expected_character_id.is_empty() and normalize_id_string(prepared_character.get("character_id", "")) != normalize_id_string(expected_character_id):
		return {}
	if not expected_stage_difficulty_id.is_empty() and str(prepared_stage_difficulty.get("stage_difficulty_id", "")).strip_edges() != expected_stage_difficulty_id:
		return {}

	return _prepare_payload


func _build_monster_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "第 %s 波 · %s" % [
		str(entry.get("wave_no", "-")),
		str(entry.get("monster_name", "未知敌人")),
	]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill(
		"首领" if str(entry.get("monster_role", "")) == "boss_enemy" else "普通敌人",
		BATTLE_TINT if str(entry.get("monster_role", "")) == "boss_enemy" else CHARACTER_TINT
	))
	box.add_child(tags)

	var meta := Label.new()
	meta.text = "生命 %s | 攻击 %s | 物防 %s | 法防 %s" % [
		str(entry.get("base_hp", "-")),
		str(entry.get("base_attack", "-")),
		str(entry.get("base_physical_defense", "-")),
		str(entry.get("base_magic_defense", "-")),
	]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)

	return card


func _format_reward_status(reward_status: Dictionary) -> String:
	if reward_status.is_empty():
		return "当前奖励状态会在难度锁定后自动同步。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "当前难度没有首通奖励，放心继续推进即可。"
	if int(reward_status.get("has_granted", 0)) == 1:
		return "当前难度的首通奖励已经领过，这一场不会重复新增。"
	return "当前难度还有首通奖励待领取。"


func _reward_tag_text(reward_status: Dictionary) -> String:
	if reward_status.is_empty():
		return "待同步"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "无新增"
	if int(reward_status.get("has_granted", 0)) == 1:
		return "已领取"
	return "可领取"


func _character_title(character: Dictionary) -> String:
	return str(character.get("character_name", "角色"))


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


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _as_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _on_override_toggled(pressed: bool) -> void:
	override_box.visible = pressed


func _on_recent_character_selected(_index: int) -> void:
	var selected = get_selected_option(recent_character_selector)
	var character_id = str(selected.get("value", ""))
	if character_id.is_empty():
		return

	character_id_input.text = character_id
	_emit_context("battle_character_changed", {"character_id": character_id})


func _on_character_id_changed(_text: String) -> void:
	_emit_context("battle_character_changed", {"character_id": get_character_id_text()})


func _on_recent_stage_difficulty_selected(_index: int) -> void:
	var selected = get_selected_option(recent_stage_difficulty_selector)
	var stage_difficulty_id = str(selected.get("value", ""))
	if stage_difficulty_id.is_empty():
		return

	stage_difficulty_input.text = stage_difficulty_id
	_emit_context("stage_difficulty_changed", {"stage_difficulty_id": stage_difficulty_id})


func _on_stage_difficulty_changed(_text: String) -> void:
	_emit_context("stage_difficulty_changed", {"stage_difficulty_id": get_stage_difficulty_text()})

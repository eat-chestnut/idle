extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOnePreparePage

const CHARACTER_TINT := Color(0.56, 0.82, 0.96, 1.0)
const BATTLE_TINT := Color(0.99, 0.72, 0.40, 1.0)
const REWARD_TINT := Color(0.55, 0.86, 0.68, 1.0)

var recent_character_selector: OptionButton
var override_toggle: CheckBox
var override_box: VBoxContainer
var character_id_input: LineEdit
var recent_stage_difficulty_selector: OptionButton
var stage_difficulty_input: LineEdit

var character_name_label: Label
var character_meta_label: Label
var character_tag_row: HBoxContainer
var route_title_label: Label
var route_meta_label: Label
var reward_status_label: Label
var stat_rows_box: VBoxContainer
var monster_rows_box: VBoxContainer
var technical_note_label: Label

var _route_context: Dictionary = {}
var _reward_status: Dictionary = {}


func _init() -> void:
	setup_page(
		"出战",
		[
			"Prepare 页只负责把真实角色、真实关卡难度和敌方信息收完整，再发起 battle prepare。",
			"battle_context_id 仍会承接，但它已经下沉为技术详情，不再作为主要操作入口。",
		]
	)

	var character_card := add_card("当前出战角色", "Battle 角色仍必须是后端真实 `is_active=1` 的当前启用角色。")
	character_name_label = Label.new()
	character_name_label.add_theme_font_size_override("font_size", 22)
	character_card.add_child(character_name_label)

	character_meta_label = Label.new()
	character_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_card.add_child(character_meta_label)

	character_tag_row = HBoxContainer.new()
	character_tag_row.add_theme_constant_override("separation", 8)
	character_card.add_child(character_tag_row)

	recent_character_selector = add_labeled_option_button("出战角色（优先真实角色列表）", character_card)
	recent_character_selector.item_selected.connect(_on_recent_character_selected)

	var character_buttons := add_button_row(character_card)
	add_action_button(character_buttons, "激活当前出战角色", "activate_battle_character")
	add_action_button(character_buttons, "返回主线页", "navigate_stage")

	var route_card := add_card("本次目标", "默认承接主线页已选中的章节、关卡和难度，不让玩家重复输入。")
	route_title_label = Label.new()
	route_title_label.add_theme_font_size_override("font_size", 22)
	route_card.add_child(route_title_label)

	route_meta_label = Label.new()
	route_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_card.add_child(route_meta_label)

	reward_status_label = Label.new()
	reward_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_status_label.modulate = CARD_TEXT_MUTED
	route_card.add_child(reward_status_label)

	recent_stage_difficulty_selector = add_labeled_option_button("当前已选难度 / 最近难度", route_card)
	recent_stage_difficulty_selector.item_selected.connect(_on_recent_stage_difficulty_selected)

	var stats_card := add_card("战斗预览", "Battle prepare 成功后会把角色属性和敌方列表补全到这里。")
	stat_rows_box = VBoxContainer.new()
	stat_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_rows_box.add_theme_constant_override("separation", 8)
	stats_card.add_child(stat_rows_box)

	var monster_card := add_card("敌方阵容", "敌方信息完全来自 prepare 返回的 monster_list。")
	monster_rows_box = VBoxContainer.new()
	monster_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	monster_rows_box.add_theme_constant_override("separation", 10)
	monster_card.add_child(monster_rows_box)

	override_toggle = add_check_box("显示 Battle Prepare 联调覆盖输入", false, monster_card)
	override_toggle.toggled.connect(_on_override_toggled)
	override_box = VBoxContainer.new()
	override_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	override_box.visible = false
	monster_card.add_child(override_box)

	character_id_input = add_labeled_input("character_id（联调覆盖）", "", override_box)
	character_id_input.text_changed.connect(_on_character_id_changed)

	stage_difficulty_input = add_labeled_input(
		"stage_difficulty_id（联调覆盖）",
		"stage_nanshan_001_normal",
		override_box
	)
	stage_difficulty_input.text_changed.connect(_on_stage_difficulty_changed)

	var action_card := add_card("出战", "主按钮只保留开始战斗，其余技术信息仍放在页面底部。")
	technical_note_label = Label.new()
	technical_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	technical_note_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(technical_note_label)

	var buttons := add_button_row(action_card)
	add_action_button(buttons, "开始战斗", "prepare")

	render_prepare_context({}, {}, {})
	show_prepare_summary({})


func apply_config(values: Dictionary) -> void:
	character_id_input.text = normalize_id_string(
		values.get("battle_character_id", values.get("character_id", "1001"))
	)
	stage_difficulty_input.text = str(values.get("stage_difficulty_id", "stage_nanshan_001_normal"))


func render_prepare_context(character: Dictionary, route_context: Dictionary, reward_status: Dictionary) -> void:
	_route_context = route_context.duplicate(true)
	_reward_status = reward_status.duplicate(true)

	var resolved_character := character.duplicate(true)
	if resolved_character.is_empty():
		character_name_label.text = "尚未锁定出战角色"
		character_meta_label.text = "请先在角色页确认当前角色，或在本页选择可战斗角色。"
	else:
		character_name_label.text = "%s  #%s" % [
			str(resolved_character.get("character_name", "角色")),
			normalize_id_string(resolved_character.get("character_id", "")),
		]
		character_meta_label.text = "%s | 等级 %s | 当前状态：%s" % [
			str(resolved_character.get("class_name", resolved_character.get("class_id", ""))),
			str(resolved_character.get("level", "1")),
			"已激活" if int(resolved_character.get("is_active", 0)) == 1 else "未激活",
		]

	clear_container(character_tag_row)
	if resolved_character.is_empty():
		character_tag_row.add_child(create_pill("等待角色", CHARACTER_TINT))
	else:
		character_tag_row.add_child(create_pill("角色已锁定", CHARACTER_TINT))
		if int(resolved_character.get("is_active", 0)) == 1:
			character_tag_row.add_child(create_pill("可直接出战", REWARD_TINT))
		else:
			character_tag_row.add_child(create_pill("需先激活", BATTLE_TINT))

	var chapter_name := str(route_context.get("chapter_name", "章节待选择"))
	var stage_name := str(route_context.get("stage_name", "关卡待选择"))
	var difficulty_name := str(route_context.get("difficulty_name", "难度待选择"))
	route_title_label.text = "%s / %s / %s" % [chapter_name, stage_name, difficulty_name]
	route_meta_label.text = "chapter_id=%s | stage_id=%s | stage_difficulty_id=%s | 推荐战力 %s" % [
		str(route_context.get("chapter_id", "(未选择)")),
		str(route_context.get("stage_id", "(未选择)")),
		str(route_context.get("stage_difficulty_id", get_stage_difficulty_text())),
		str(route_context.get("recommended_power", "-")),
	]
	reward_status_label.text = _format_reward_status(reward_status)


func set_recent_characters(records: Array, current_character_id: String) -> void:
	var options: Array = []
	for record in records:
		var entry = record if typeof(record) == TYPE_DICTIONARY else {}
		var character_id = normalize_id_string(entry.get("character_id", ""))
		if character_id.is_empty():
			continue

		var label = "%s #%s" % [str(entry.get("character_name", "角色")), character_id]
		if entry.has("is_active") and int(entry.get("is_active", 0)) == 1:
			label += " [可战斗]"
		elif entry.has("is_active"):
			label += " [未激活]"

		options.append({
			"label": label,
			"value": character_id,
			"record": entry,
		})

	replace_options(recent_character_selector, options, "暂无真实角色记录", current_character_id)


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
		"暂无成功难度记录",
		current_stage_difficulty_id
	)


func set_character_id(character_id: String) -> void:
	character_id_input.text = normalize_id_string(character_id)


func set_stage_difficulty_id(stage_difficulty_id: String) -> void:
	stage_difficulty_input.text = stage_difficulty_id


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func get_stage_difficulty_text() -> String:
	return stage_difficulty_input.text.strip_edges()


func show_prepare_summary(payload: Dictionary) -> void:
	clear_container(stat_rows_box)
	clear_container(monster_rows_box)

	if payload.is_empty():
		var empty_stats := Label.new()
		empty_stats.text = "battle prepare 成功后，这里会展示角色属性摘要。"
		empty_stats.modulate = CARD_TEXT_MUTED
		stat_rows_box.add_child(empty_stats)

		var empty_monsters := Label.new()
		empty_monsters.text = "敌方阵容会在 prepare 成功后填入。"
		empty_monsters.modulate = CARD_TEXT_MUTED
		monster_rows_box.add_child(empty_monsters)
		technical_note_label.text = "尚未生成 battle_context。"
		set_output_json({})
		return

	var stage_difficulty = payload.get("stage_difficulty", {})
	var stage_difficulty_data = stage_difficulty if typeof(stage_difficulty) == TYPE_DICTIONARY else {}
	var stats = payload.get("character_stats", {})
	var stats_data = stats if typeof(stats) == TYPE_DICTIONARY else {}

	for key in [
		{"label": "攻击", "value": stats_data.get("attack", "-")},
		{"label": "生命", "value": stats_data.get("hp", "-")},
		{"label": "物防", "value": stats_data.get("physical_defense", "-")},
		{"label": "法防", "value": stats_data.get("magic_defense", "-")},
		{"label": "法力", "value": stats_data.get("mana", "-")},
		{"label": "攻速", "value": stats_data.get("attack_speed", "-")},
	]:
		var row := Label.new()
		row.text = "%s：%s" % [str(key.get("label", "")), str(key.get("value", "-"))]
		stat_rows_box.add_child(row)

	for monster in payload.get("monster_list", []):
		var entry: Dictionary = monster if typeof(monster) == TYPE_DICTIONARY else {}
		monster_rows_box.add_child(_build_monster_card(entry))

	var battle_context_id := str(payload.get("battle_context_id", ""))
	technical_note_label.text = "Prepare 已生成 battle_context_id=%s，战斗页会自动承接它。" % battle_context_id
	set_summary_text("角色已完成出战确认 | monsters=%d | difficulty=%s" % [
		payload.get("monster_list", []).size(),
		str(stage_difficulty_data.get("difficulty_name", stage_difficulty_data.get("stage_difficulty_id", ""))),
	])
	set_output_json(payload)


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

	var meta := Label.new()
	meta.text = "monster_id=%s | 角色=%s | HP %s | 攻击 %s" % [
		str(entry.get("monster_id", "")),
		str(entry.get("monster_role", "")),
		str(entry.get("base_hp", "-")),
		str(entry.get("base_attack", "-")),
	]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)

	return card


func _format_reward_status(reward_status: Dictionary) -> String:
	if reward_status.is_empty():
		return "首通奖励状态：等主线页同步。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "首通奖励状态：本难度没有首通奖励。"
	if int(reward_status.get("has_granted", 0)) == 1:
		var grant_status := str(reward_status.get("grant_status", "")).strip_edges()
		if grant_status.is_empty():
			return "首通奖励状态：已领取。"
		return "首通奖励状态：已领取，grant_status=%s。" % grant_status
	return "首通奖励状态：首次通关后可发放。"


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

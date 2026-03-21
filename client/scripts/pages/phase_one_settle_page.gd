extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneSettlePage

const DROP_TINT := Color(0.56, 0.83, 0.96, 1.0)
const REWARD_TINT := Color(0.58, 0.88, 0.66, 1.0)
const INVENTORY_TINT := Color(0.98, 0.77, 0.44, 1.0)

var recent_character_selector: OptionButton
var override_toggle: CheckBox
var override_box: VBoxContainer
var character_id_input: LineEdit
var recent_stage_difficulty_selector: OptionButton
var stage_difficulty_input: LineEdit
var battle_context_selector: OptionButton
var battle_context_input: LineEdit
var killed_monsters_input: LineEdit
var is_cleared_checkbox: CheckBox

var result_title_label: Label
var result_meta_label: Label
var result_state_label: Label

var drop_box: VBoxContainer
var reward_box: VBoxContainer
var inventory_box: VBoxContainer

var _route_context: Dictionary = {}


func _init() -> void:
	setup_page(
		"结算",
		[
			"结果页会把掉落、奖励、入包拆开显示，不再混成一块技术数据。",
			"奖励没有新增不等于错误，它可能只是当前难度没有奖励，或已经领过首通奖励。",
		]
	)

	var header_card := add_card("本次战斗结果", "结算完成后会自动回写主线页的首通奖励状态。")
	result_title_label = Label.new()
	result_title_label.add_theme_font_size_override("font_size", 22)
	header_card.add_child(result_title_label)

	result_meta_label = Label.new()
	result_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(result_meta_label)

	result_state_label = Label.new()
	result_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_state_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(result_state_label)

	var action_row := add_button_row(header_card)
	add_action_button(action_row, "再来一场", "retry_battle")
	add_action_button(action_row, "返回主线", "navigate_stage")
	add_action_button(action_row, "去背包", "navigate_inventory")

	var drop_card := add_card("掉落结果", "这里展示怪物掉落链产生的正式结果。")
	drop_box = VBoxContainer.new()
	drop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_box.add_theme_constant_override("separation", 10)
	drop_card.add_child(drop_box)

	var reward_card := add_card("奖励结果", "这里展示首通奖励等正式 reward grant 结果。")
	reward_box = VBoxContainer.new()
	reward_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_box.add_theme_constant_override("separation", 10)
	reward_card.add_child(reward_box)

	var inventory_card := add_card("入包结果", "掉落和奖励最终如何入包，会在这里分别回显。")
	inventory_box = VBoxContainer.new()
	inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_box.add_theme_constant_override("separation", 10)
	inventory_card.add_child(inventory_box)

	var debug_card := add_card("调试覆盖", "正式流程默认不需要填写 battle_context_id；这里只保留联调兜底。")
	recent_character_selector = add_labeled_option_button("出战角色（优先真实角色列表）", debug_card)
	recent_character_selector.item_selected.connect(_on_recent_character_selected)

	recent_stage_difficulty_selector = add_labeled_option_button("当前已选难度 / 最近难度", debug_card)
	recent_stage_difficulty_selector.item_selected.connect(_on_recent_stage_difficulty_selected)

	battle_context_selector = add_labeled_option_button("本轮 Prepare 生成的 battle_context", debug_card)
	battle_context_selector.item_selected.connect(_on_battle_context_selected)
	replace_options(battle_context_selector, [], "暂无 Prepare 上下文")

	override_toggle = add_check_box("显示 Battle Settle 联调覆盖输入", false, debug_card)
	override_toggle.toggled.connect(_on_override_toggled)
	override_box = VBoxContainer.new()
	override_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	override_box.visible = false
	debug_card.add_child(override_box)

	character_id_input = add_labeled_input("character_id（联调覆盖）", "", override_box)
	character_id_input.text_changed.connect(_on_character_id_changed)

	stage_difficulty_input = add_labeled_input(
		"stage_difficulty_id（联调覆盖）",
		"stage_nanshan_001_normal",
		override_box
	)
	stage_difficulty_input.text_changed.connect(_on_stage_difficulty_changed)

	battle_context_input = add_labeled_input("battle_context_id（联调覆盖）", "", override_box)
	battle_context_input.text_changed.connect(_on_battle_context_changed)

	killed_monsters_input = add_labeled_input("killed_monsters（逗号分隔）", "", override_box)
	var override_buttons := add_button_row(override_box)
	add_action_button(override_buttons, "使用 Prepare 怪物列表", "fill_prepared_monsters")
	add_action_button(override_buttons, "手动提交结算", "settle")

	is_cleared_checkbox = add_check_box("本次通关成功", true, override_box)

	show_handoff_summary("", "", "", 0)
	show_settlement_summary({})


func apply_config(values: Dictionary) -> void:
	character_id_input.text = normalize_id_string(
		values.get("battle_character_id", values.get("character_id", "1001"))
	)
	stage_difficulty_input.text = str(values.get("stage_difficulty_id", "stage_nanshan_001_normal"))


func render_settle_context(character: Dictionary, route_context: Dictionary) -> void:
	_route_context = route_context.duplicate(true)
	var chapter_name := str(route_context.get("chapter_name", "章节"))
	var stage_name := str(route_context.get("stage_name", "关卡"))
	var difficulty_name := str(route_context.get("difficulty_name", "难度"))
	var character_name := str(character.get("character_name", "角色"))
	result_meta_label.text = "角色 %s | %s / %s / %s | stage_difficulty_id=%s | battle_context_id=%s" % [
		character_name,
		chapter_name,
		stage_name,
		difficulty_name,
		str(route_context.get("stage_difficulty_id", get_stage_difficulty_text())),
		get_battle_context_text() if not get_battle_context_text().is_empty() else "(待生成)",
	]


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


func set_recent_battle_contexts(battle_context_ids: Array, current_battle_context_id: String) -> void:
	var options: Array = []
	for battle_context_id in battle_context_ids:
		var normalized = str(battle_context_id).strip_edges()
		if normalized.is_empty():
			continue
		options.append({
			"label": normalized,
			"value": normalized,
		})

	replace_options(
		battle_context_selector,
		options,
		"暂无 Prepare 上下文",
		current_battle_context_id
	)
	if not current_battle_context_id.is_empty():
		battle_context_input.text = current_battle_context_id


func set_character_id(character_id: String) -> void:
	character_id_input.text = normalize_id_string(character_id)


func set_stage_difficulty_id(stage_difficulty_id: String) -> void:
	stage_difficulty_input.text = stage_difficulty_id


func set_battle_context_id(battle_context_id: String) -> void:
	battle_context_input.text = battle_context_id


func set_killed_monsters(monster_ids: PackedStringArray) -> void:
	killed_monsters_input.text = ",".join(monster_ids)


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func get_stage_difficulty_text() -> String:
	return stage_difficulty_input.text.strip_edges()


func get_battle_context_text() -> String:
	return battle_context_input.text.strip_edges()


func get_killed_monster_text() -> String:
	return killed_monsters_input.text.strip_edges()


func is_cleared() -> bool:
	return is_cleared_checkbox.button_pressed


func show_settlement_summary(payload: Dictionary) -> void:
	clear_container(drop_box)
	clear_container(reward_box)
	clear_container(inventory_box)

	if payload.is_empty():
		result_title_label.text = "等待战斗结算"
		result_state_label.text = "战斗页完成后，这里会自动承接正式掉落、奖励和入包结果。"
		drop_box.add_child(_build_empty_label("还没有掉落结果。"))
		reward_box.add_child(_build_empty_label("还没有奖励结果。"))
		inventory_box.add_child(_build_empty_label("还没有入包结果。"))
		set_output_json({})
		return

	var stage_difficulty: Dictionary = payload.get("stage_difficulty", {}) if typeof(payload.get("stage_difficulty", {})) == TYPE_DICTIONARY else {}
	var stage_difficulty_data: Dictionary = stage_difficulty
	var drop_results: Array = payload.get("drop_results", []) if typeof(payload.get("drop_results", [])) == TYPE_ARRAY else []
	var reward_results: Array = payload.get("reward_results", []) if typeof(payload.get("reward_results", [])) == TYPE_ARRAY else []
	var inventory_results: Dictionary = payload.get("inventory_results", {}) if typeof(payload.get("inventory_results", {})) == TYPE_DICTIONARY else {}
	var inventory_result_data: Dictionary = inventory_results
	var first_clear_reward_status: Dictionary = payload.get("first_clear_reward_status", {}) if typeof(payload.get("first_clear_reward_status", {})) == TYPE_DICTIONARY else {}
	var reward_status_data: Dictionary = first_clear_reward_status
	var settlement_summary: Dictionary = payload.get("settlement_summary", {}) if typeof(payload.get("settlement_summary", {})) == TYPE_DICTIONARY else {}
	var summary_data: Dictionary = settlement_summary

	result_title_label.text = "战斗%s  ·  %s" % [
		"胜利" if int(payload.get("is_cleared", 0)) == 1 else "结束",
		str(stage_difficulty_data.get("difficulty_name", stage_difficulty_data.get("stage_difficulty_id", ""))),
	]
	result_state_label.text = _format_reward_result_state(reward_status_data, summary_data)

	for drop in drop_results:
		var entry: Dictionary = drop if typeof(drop) == TYPE_DICTIONARY else {}
		drop_box.add_child(_build_result_card(
			"%s x%s" % [str(entry.get("item_name", "掉落物")), str(entry.get("quantity", 0))],
			"掉落链 | item_id=%s | rarity=%s" % [
				str(entry.get("item_id", "")),
				str(entry.get("rarity", "")),
			],
			DROP_TINT
		))

	if drop_box.get_child_count() == 0:
		drop_box.add_child(_build_empty_label("本次没有掉落。"))

	for reward in reward_results:
		var entry: Dictionary = reward if typeof(reward) == TYPE_DICTIONARY else {}
		var reward_items: Array = entry.get("reward_items", []) if typeof(entry.get("reward_items", [])) == TYPE_ARRAY else []
		var reward_count: int = reward_items.size()
		reward_box.add_child(_build_result_card(
			"奖励组 %s" % str(entry.get("reward_group_id", "(unknown)")),
			"grant_status=%s | 奖励项 %d" % [
				str(entry.get("grant_status", "")),
				reward_count,
			],
			REWARD_TINT
		))

	if reward_box.get_child_count() == 0:
		reward_box.add_child(_build_empty_label("本次没有新增奖励记录；这可能是当前难度无奖励，或首通奖励已领取。"))

	for stack_result in inventory_result_data.get("stack_results", []):
		var stack_entry: Dictionary = stack_result if typeof(stack_result) == TYPE_DICTIONARY else {}
		inventory_box.add_child(_build_result_card(
			"%s +%s" % [str(stack_entry.get("item_id", "")), str(stack_entry.get("add_quantity", 0))],
			"%s：%s -> %s" % [
				str(stack_entry.get("action", "write")),
				str(stack_entry.get("before_quantity", 0)),
				str(stack_entry.get("after_quantity", 0)),
			],
			INVENTORY_TINT
		))

	for equipment_result in inventory_result_data.get("equipment_instance_results", []):
		var equipment_entry: Dictionary = equipment_result if typeof(equipment_result) == TYPE_DICTIONARY else {}
		inventory_box.add_child(_build_result_card(
			"装备实例 #%s" % normalize_id_string(equipment_entry.get("equipment_instance_id", "")),
			"item_id=%s | 耐久 %s/%s" % [
				str(equipment_entry.get("item_id", "")),
				str(equipment_entry.get("durability", 0)),
				str(equipment_entry.get("max_durability", 0)),
			],
			INVENTORY_TINT
		))

	if inventory_box.get_child_count() == 0:
		inventory_box.add_child(_build_empty_label("本次没有新增入包写入。"))

	set_summary_text("drops=%d | rewards=%d | stack_writes=%d | equipment_writes=%d" % [
		drop_results.size(),
		reward_results.size(),
		inventory_result_data.get("stack_results", []).size(),
		inventory_result_data.get("equipment_instance_results", []).size(),
	])
	set_output_json(payload)


func show_handoff_summary(character_id: String, stage_difficulty_id: String, battle_context_id: String, monster_count: int) -> void:
	result_title_label.text = "等待提交正式结算"
	result_state_label.text = "Prepare 已经承接到结算链，接下来只需走正式 settle。"
	result_meta_label.text = "character_id=%s | stage_difficulty_id=%s | battle_context_id=%s | 已击败怪物数 %d" % [
		character_id if not character_id.is_empty() else "(未同步)",
		stage_difficulty_id if not stage_difficulty_id.is_empty() else "(未同步)",
		battle_context_id if not battle_context_id.is_empty() else "(未同步)",
		monster_count,
	]
	set_output_json({
		"ready_to_settle": {
			"character_id": character_id,
			"stage_difficulty_id": stage_difficulty_id,
			"battle_context_id": battle_context_id,
			"killed_monster_count": monster_count,
			"is_cleared": 1 if is_cleared_checkbox.button_pressed else 0,
		},
	})


func _build_result_card(title_text: String, meta_text: String, tint: Color) -> PanelContainer:
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

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill(title_text, tint))
	box.add_child(tags)

	var meta := Label.new()
	meta.text = meta_text
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)
	return card


func _build_empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = CARD_TEXT_MUTED
	return label


func _format_reward_result_state(reward_status: Dictionary, summary_data: Dictionary) -> String:
	if reward_status.is_empty():
		return "首通奖励状态：等主线页回读。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "首通奖励状态：本难度没有首通奖励。掉落和入包仍然是正常结算结果。"
	if int(reward_status.get("has_granted", 0)) == 1:
		return "首通奖励状态：已发放，created_equipment_instance_count=%s。" % str(summary_data.get("created_equipment_instance_count", 0))
	return "首通奖励状态：当前仍未发放，请检查 grant_status。"


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


func _on_battle_context_selected(_index: int) -> void:
	var selected = get_selected_option(battle_context_selector)
	var battle_context_id = str(selected.get("value", ""))
	if battle_context_id.is_empty():
		return

	battle_context_input.text = battle_context_id
	_emit_context("battle_context_changed", {"battle_context_id": battle_context_id})


func _on_battle_context_changed(_text: String) -> void:
	_emit_context("battle_context_changed", {"battle_context_id": get_battle_context_text()})

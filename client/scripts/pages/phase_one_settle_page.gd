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
var result_tag_row: HBoxContainer
var spotlight_title_label: Label
var spotlight_detail_label: Label
var spotlight_box: VBoxContainer

var drop_box: VBoxContainer
var reward_box: VBoxContainer
var inventory_box: VBoxContainer
var growth_hint_label: Label
var primary_inventory_button: Button
var equipment_followup_button: Button
var retry_button: Button
var stage_button: Button
var character_followup_button: Button

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
	result_title_label.add_theme_font_size_override("font_size", 26)
	header_card.add_child(result_title_label)

	result_meta_label = Label.new()
	result_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_meta_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(result_meta_label)

	result_state_label = Label.new()
	result_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_state_label.modulate = BODY_TEXT
	header_card.add_child(result_state_label)

	result_tag_row = HBoxContainer.new()
	result_tag_row.add_theme_constant_override("separation", 8)
	header_card.add_child(result_tag_row)

	var spotlight_card := add_card("本轮收获焦点", "如果有新装备或特别值得关注的结果，会先在这里提示。")
	spotlight_title_label = Label.new()
	spotlight_title_label.add_theme_font_size_override("font_size", 22)
	spotlight_card.add_child(spotlight_title_label)

	spotlight_detail_label = Label.new()
	spotlight_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spotlight_detail_label.modulate = CARD_TEXT_MUTED
	spotlight_card.add_child(spotlight_detail_label)

	spotlight_box = VBoxContainer.new()
	spotlight_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spotlight_box.add_theme_constant_override("separation", 10)
	spotlight_card.add_child(spotlight_box)

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

	var growth_card := add_card("结算后下一步", "尽量把“看结果 -> 看背包 -> 看穿戴/角色”顺着承接起来。")
	growth_hint_label = Label.new()
	growth_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_hint_label.modulate = CARD_TEXT_MUTED
	growth_card.add_child(growth_hint_label)

	var primary_actions := add_button_row(growth_card)
	retry_button = add_action_button(primary_actions, "再打一场", "retry_battle")
	stage_button = add_action_button(primary_actions, "回主线", "navigate_stage", {"source": "settle"})
	primary_inventory_button = add_action_button(primary_actions, "先看背包", "navigate_inventory", {"source": "settle"})
	style_primary_button(primary_inventory_button)

	var followup_actions := add_button_row(growth_card)
	equipment_followup_button = add_action_button(followup_actions, "去穿戴", "navigate_equipment", {"source": "settle"})
	character_followup_button = add_action_button(followup_actions, "回角色看成长", "navigate_character", {"source": "settle"})

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
	result_meta_label.text = "角色 %s | %s / %s / %s | 本轮难度 %s | 战斗上下文 %s" % [
		character_name,
		chapter_name,
		stage_name,
		difficulty_name,
		str(route_context.get("stage_difficulty_id", get_stage_difficulty_text())),
		"已锁定" if not get_battle_context_text().is_empty() else "待 Prepare",
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
	clear_container(spotlight_box)
	clear_container(drop_box)
	clear_container(reward_box)
	clear_container(inventory_box)
	clear_container(result_tag_row)

	if payload.is_empty():
		result_title_label.text = "等待战斗结算"
		result_state_label.text = "战斗页完成后，这里会自动承接正式掉落、奖励和入包结果。"
		spotlight_title_label.text = "结果页还在等待本轮结果"
		spotlight_detail_label.text = "完成结算后，这里会先把这场最值得关注的结果顶出来。"
		spotlight_box.add_child(_build_empty_label("现在还没有需要特别关注的战利品。"))
		growth_hint_label.text = "结算完成后，这里会告诉你更适合先去背包、回角色，还是直接去穿戴。"
		primary_inventory_button.text = "先看背包"
		equipment_followup_button.text = "去穿戴"
		character_followup_button.text = "回角色看成长"
		equipment_followup_button.disabled = true
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
	var stack_results: Array = inventory_result_data.get("stack_results", []) if typeof(inventory_result_data.get("stack_results", [])) == TYPE_ARRAY else []
	var equipment_instance_results: Array = inventory_result_data.get("equipment_instance_results", []) if typeof(inventory_result_data.get("equipment_instance_results", [])) == TYPE_ARRAY else []
	var created_equipment_instances: Array = payload.get("created_equipment_instances", []) if typeof(payload.get("created_equipment_instances", [])) == TYPE_ARRAY else []
	var first_clear_reward_status: Dictionary = payload.get("first_clear_reward_status", {}) if typeof(payload.get("first_clear_reward_status", {})) == TYPE_DICTIONARY else {}
	var reward_status_data: Dictionary = first_clear_reward_status
	var item_name_map := _build_item_name_map(drop_results, reward_results)
	var equipment_name_map := _build_created_equipment_map(created_equipment_instances)

	result_title_label.text = "战斗%s  ·  %s" % [
		"胜利" if int(payload.get("is_cleared", 0)) == 1 else "收束",
		str(stage_difficulty_data.get("difficulty_name", stage_difficulty_data.get("stage_difficulty_id", ""))),
	]
	result_state_label.text = _format_reward_result_state(reward_status_data, reward_results.size())
	_render_result_tags(payload, drop_results, reward_results, stack_results, equipment_instance_results, reward_status_data)
	_render_spotlight_section(drop_results, reward_results, created_equipment_instances, reward_status_data)
	growth_hint_label.text = _build_growth_hint(
		reward_status_data,
		drop_results,
		reward_results,
		stack_results,
		created_equipment_instances
	)
	primary_inventory_button.text = "先看背包" if not stack_results.is_empty() or not created_equipment_instances.is_empty() else "去背包"
	equipment_followup_button.text = "去穿戴新装备" if not created_equipment_instances.is_empty() else "查看穿戴"
	character_followup_button.text = "回角色看成长"
	equipment_followup_button.disabled = created_equipment_instances.is_empty()

	for drop in drop_results:
		var entry: Dictionary = drop if typeof(drop) == TYPE_DICTIONARY else {}
		drop_box.add_child(_build_result_card(
			"%s x%s" % [str(entry.get("item_name", "掉落物")), str(entry.get("quantity", 0))],
			"怪物掉落 | 稀有度 %s" % str(entry.get("rarity", "")),
			DROP_TINT
		))

	if drop_box.get_child_count() == 0:
		drop_box.add_child(_build_empty_label("本次没有掉落。"))

	var reward_display_index := 0
	for reward in reward_results:
		var entry: Dictionary = reward if typeof(reward) == TYPE_DICTIONARY else {}
		var reward_items: Array = entry.get("reward_items", []) if typeof(entry.get("reward_items", [])) == TYPE_ARRAY else []
		var reward_count: int = reward_items.size()
		var reward_lines: Array = []
		reward_display_index += 1
		for reward_item in reward_items:
			var reward_item_entry: Dictionary = reward_item if typeof(reward_item) == TYPE_DICTIONARY else {}
			reward_lines.append(
				"%s x%s" % [
					str(reward_item_entry.get("item_name", reward_item_entry.get("item_id", "奖励项"))),
					str(reward_item_entry.get("quantity", 0)),
				]
			)
		reward_box.add_child(_build_result_card(
			"固定奖励 %d" % reward_display_index,
			"到账状态：%s | 奖励项 %d\n%s" % [
				str(entry.get("grant_status", "")),
				reward_count,
				("奖励内容：" + "、".join(reward_lines)) if not reward_lines.is_empty() else "奖励内容：本次没有返回奖励项。",
			],
			REWARD_TINT
		))

	if reward_box.get_child_count() == 0:
		reward_box.add_child(_build_empty_label("本次没有新增奖励记录。这不是错误，可能是当前难度没有首通奖励，或这份首通奖励已经领过。"))

	for stack_result in stack_results:
		var stack_entry: Dictionary = stack_result if typeof(stack_result) == TYPE_DICTIONARY else {}
		var stack_item_id := str(stack_entry.get("item_id", ""))
		inventory_box.add_child(_build_result_card(
			"%s +%s" % [
				str(item_name_map.get(stack_item_id, stack_item_id)),
				str(stack_entry.get("add_quantity", 0)),
			],
			"已入包 | 数量 %s -> %s" % [
				str(stack_entry.get("before_quantity", 0)),
				str(stack_entry.get("after_quantity", 0)),
			],
			INVENTORY_TINT
		))

	for equipment_result in equipment_instance_results:
		var equipment_entry: Dictionary = equipment_result if typeof(equipment_result) == TYPE_DICTIONARY else {}
		var equipment_instance_id := normalize_id_string(equipment_entry.get("equipment_instance_id", ""))
		inventory_box.add_child(_build_result_card(
			"%s #%s" % [
				str(equipment_name_map.get(equipment_instance_id, equipment_entry.get("item_id", "新装备"))),
				equipment_instance_id,
			],
			"装备已入包 | 可前往穿戴 | 耐久 %s/%s" % [
				str(equipment_entry.get("durability", 0)),
				str(equipment_entry.get("max_durability", 0)),
			],
			INVENTORY_TINT
		))

	if inventory_box.get_child_count() == 0:
		inventory_box.add_child(_build_empty_label("本次没有新增入包写入。"))

	set_summary_text("结果总览：掉落 %d | 奖励 %d | 入包 %d" % [
		drop_results.size(),
		reward_results.size(),
		stack_results.size() + equipment_instance_results.size(),
	])
	set_output_json(payload)


func show_handoff_summary(character_id: String, stage_difficulty_id: String, battle_context_id: String, monster_count: int) -> void:
	clear_container(spotlight_box)
	clear_container(result_tag_row)
	result_title_label.text = "等待提交正式结算"
	result_state_label.text = "Prepare 已承接到结算链，战斗页结束后就会在这里生成正式结果。"
	spotlight_title_label.text = "这场的结果亮点还在路上"
	spotlight_detail_label.text = "一旦结算完成，这里会先提示新装备、奖励变化或需要特别关注的结果。"
	spotlight_box.add_child(_build_empty_label("现在只差正式结算结果返回。"))
	result_meta_label.text = "当前角色 %s | 当前难度 %s | 战斗上下文 %s | 已击败怪物 %d" % [
		character_id if not character_id.is_empty() else "(未同步)",
		stage_difficulty_id if not stage_difficulty_id.is_empty() else "(未同步)",
		"已锁定" if not battle_context_id.is_empty() else "(未同步)",
		monster_count,
	]
	growth_hint_label.text = "等战斗结果返回后，这里会告诉你本次更适合先去背包、回角色，还是直接去穿戴新装备。"
	primary_inventory_button.text = "先看背包"
	equipment_followup_button.text = "去穿戴"
	character_followup_button.text = "回角色看成长"
	equipment_followup_button.disabled = true
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


func _format_reward_result_state(reward_status: Dictionary, reward_result_count: int) -> String:
	if reward_status.is_empty():
		return "首通奖励状态：等主线页回读，本次先看掉落、奖励和入包结果。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "首通奖励状态：这个难度没有首通奖励，掉落和入包仍然是正常结果。"
	if int(reward_status.get("has_granted", 0)) == 1:
		if reward_result_count > 0:
			return "首通奖励状态：本次已发放并回写，可以直接去看入包结果。"
		return "首通奖励状态：本次没有新增奖励记录，这不是错误，说明首通奖励已经领过。"
	return "首通奖励状态：还没回写完成，稍后回主线刷新就能继续确认。"


func _render_spotlight_section(
	drop_results: Array,
	reward_results: Array,
	created_equipment_instances: Array,
	reward_status: Dictionary
) -> void:
	if not created_equipment_instances.is_empty():
		spotlight_title_label.text = "本轮最值得先看的，是新装备"
		spotlight_detail_label.text = "新装备已经正式入包，可以直接从这里去穿戴试装。"
		var equipment_index := 0
		for equipment in created_equipment_instances:
			if equipment_index >= 3:
				break
			var equipment_entry: Dictionary = equipment if typeof(equipment) == TYPE_DICTIONARY else {}
			spotlight_box.add_child(_build_result_card(
				"%s #%s" % [
					str(equipment_entry.get("item_name", equipment_entry.get("item_id", "新装备"))),
					normalize_id_string(equipment_entry.get("equipment_instance_id", "")),
				],
				"装备位 %s | 稀有度 %s | 已准备好去穿戴" % [
					str(equipment_entry.get("equipment_slot", "")),
					str(equipment_entry.get("rarity", "")),
				],
				INVENTORY_TINT
			))
			equipment_index += 1
		return

	if not reward_results.is_empty():
		spotlight_title_label.text = "这轮还有固定奖励到账"
		spotlight_detail_label.text = "首通奖励已经回写成功，奖励项和入包结果都可以继续往下看。"
		var reward_index := 0
		for reward in reward_results:
			if reward_index >= 2:
				break
			var reward_entry: Dictionary = reward if typeof(reward) == TYPE_DICTIONARY else {}
			var reward_items: Array = reward_entry.get("reward_items", []) if typeof(reward_entry.get("reward_items", [])) == TYPE_ARRAY else []
			var reward_names: Array = []
			for reward_item in reward_items:
				var reward_item_entry: Dictionary = reward_item if typeof(reward_item) == TYPE_DICTIONARY else {}
				reward_names.append(
					"%s x%s" % [
						str(reward_item_entry.get("item_name", reward_item_entry.get("item_id", "奖励项"))),
						str(reward_item_entry.get("quantity", 0)),
					]
				)
			spotlight_box.add_child(_build_result_card(
				"固定奖励 %d" % (reward_index + 1),
				("奖励内容：" + "、".join(reward_names)) if not reward_names.is_empty() else "本次没有返回可展示的奖励项。",
				REWARD_TINT
			))
			reward_index += 1
		return

	if not drop_results.is_empty():
		spotlight_title_label.text = "这轮主要收获已经出来了"
		spotlight_detail_label.text = "没有新增首通奖励时，最值得先看的就是本次怪物掉落和入包变化。"
		var drop_index := 0
		for drop in drop_results:
			if drop_index >= 3:
				break
			var drop_entry: Dictionary = drop if typeof(drop) == TYPE_DICTIONARY else {}
			spotlight_box.add_child(_build_result_card(
				"%s x%s" % [
					str(drop_entry.get("item_name", drop_entry.get("item_id", "掉落物"))),
					str(drop_entry.get("quantity", 0)),
				],
				"稀有度 %s | 本轮主要掉落之一" % str(drop_entry.get("rarity", "")),
				DROP_TINT
			))
			drop_index += 1
		return

	spotlight_title_label.text = "这轮没有新增收获"
	if int(reward_status.get("has_reward", 0)) == 1 and int(reward_status.get("has_granted", 0)) == 1:
		spotlight_detail_label.text = "这不是异常，说明首通奖励已经领过；你可以直接再打一场，或回主线换目标。"
	else:
		spotlight_detail_label.text = "这不是异常，当前更适合回主线换目标，或直接再打一场。"
	spotlight_box.add_child(_build_empty_label("本次没有需要特别关注的新装备或新增收益。"))


func _render_result_tags(
	payload: Dictionary,
	drop_results: Array,
	reward_results: Array,
	stack_results: Array,
	equipment_instance_results: Array,
	reward_status: Dictionary
) -> void:
	result_tag_row.add_child(create_pill(
		"通关成功" if int(payload.get("is_cleared", 0)) == 1 else "中途收束",
		DROP_TINT
	))
	result_tag_row.add_child(create_pill("掉落 %d" % drop_results.size(), DROP_TINT))
	result_tag_row.add_child(create_pill("奖励 %d" % reward_results.size(), REWARD_TINT))
	result_tag_row.add_child(create_pill(
		"入包 %d" % (stack_results.size() + equipment_instance_results.size()),
		INVENTORY_TINT
	))
	result_tag_row.add_child(create_pill(
		_first_clear_tag_text(reward_status),
		REWARD_TINT if int(reward_status.get("has_reward", 0)) == 1 else DROP_TINT
	))


func _first_clear_tag_text(reward_status: Dictionary) -> String:
	if reward_status.is_empty():
		return "首通待回读"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "无首通奖励"
	if int(reward_status.get("has_granted", 0)) == 1:
		return "首通已领取"
	return "首通未领取"


func _build_growth_hint(
	reward_status: Dictionary,
	drop_results: Array,
	reward_results: Array,
	stack_results: Array,
	created_equipment_instances: Array
) -> String:
	if not created_equipment_instances.is_empty():
		return "本次拿到了 %d 件新装备，建议先去背包确认收益，再直接去穿戴试装；当前角色和新装备上下文都会保留。" % created_equipment_instances.size()
	if not stack_results.is_empty():
		return "收益已经正式入包，先去背包看材料/货币变化会更顺，再决定继续推进还是回角色看成长。"
	if reward_results.is_empty() and int(reward_status.get("has_reward", 0)) == 1 and int(reward_status.get("has_granted", 0)) == 1:
		return "奖励没有新增不是错误，说明这份首通奖励已经领过；这次可以直接再打一场，或回主线继续推进。"
	if int(reward_status.get("has_reward", 0)) == 0 and drop_results.is_empty():
		return "这个难度没有首通奖励，本次也没有额外收益；可以直接再打一场，或回主线换目标。"
	return "结果已经汇总完成，建议先去背包看收益，再决定继续推进还是回角色查看成长。"


func _build_item_name_map(drop_results: Array, reward_results: Array) -> Dictionary:
	var item_name_map := {}
	for drop in drop_results:
		var drop_entry: Dictionary = drop if typeof(drop) == TYPE_DICTIONARY else {}
		var drop_item_id := str(drop_entry.get("item_id", ""))
		if drop_item_id.is_empty():
			continue
		item_name_map[drop_item_id] = str(drop_entry.get("item_name", drop_item_id))

	for reward in reward_results:
		var reward_entry: Dictionary = reward if typeof(reward) == TYPE_DICTIONARY else {}
		var reward_items: Array = reward_entry.get("reward_items", []) if typeof(reward_entry.get("reward_items", [])) == TYPE_ARRAY else []
		for reward_item in reward_items:
			var reward_item_entry: Dictionary = reward_item if typeof(reward_item) == TYPE_DICTIONARY else {}
			var reward_item_id := str(reward_item_entry.get("item_id", ""))
			if reward_item_id.is_empty():
				continue
			item_name_map[reward_item_id] = str(reward_item_entry.get("item_name", reward_item_id))

	return item_name_map


func _build_created_equipment_map(created_equipment_instances: Array) -> Dictionary:
	var equipment_name_map := {}
	for equipment in created_equipment_instances:
		var equipment_entry: Dictionary = equipment if typeof(equipment) == TYPE_DICTIONARY else {}
		var equipment_instance_id := normalize_id_string(equipment_entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty():
			continue
		equipment_name_map[equipment_instance_id] = str(equipment_entry.get("item_name", equipment_entry.get("item_id", "新装备")))

	return equipment_name_map


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

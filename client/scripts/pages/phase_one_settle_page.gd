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
	setup_page("结算", [])

	var header_card := add_card("我得到了什么", "")
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

	var spotlight_card := add_card("先看这个", "")
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

	var drop_card := add_card("怪物掉了什么", "这部分只看这一场实际掉了什么。")
	drop_box = VBoxContainer.new()
	drop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_box.add_theme_constant_override("separation", 10)
	drop_card.add_child(drop_box)

	var reward_card := add_card("固定奖励", "首通奖励会单独展示，不和掉落混在一起。")
	reward_box = VBoxContainer.new()
	reward_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_box.add_theme_constant_override("separation", 10)
	reward_card.add_child(reward_box)

	var inventory_card := add_card("已经进包", "这部分会单独回显哪些收获真正进了包。")
	inventory_box = VBoxContainer.new()
	inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_box.add_theme_constant_override("separation", 10)
	inventory_card.add_child(inventory_box)

	var growth_card := add_card("接下来去哪", "结果看完后，可以顺着背包、穿戴、角色和主线继续推进。")
	growth_hint_label = Label.new()
	growth_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_hint_label.modulate = CARD_TEXT_MUTED
	growth_card.add_child(growth_hint_label)

	var primary_actions := add_button_row(growth_card)
	retry_button = add_action_button(primary_actions, "再打一场", "retry_battle")
	primary_inventory_button = add_action_button(primary_actions, "整理背包", "navigate_inventory", {"source": "settle"})
	style_primary_button(primary_inventory_button)
	stage_button = add_action_button(primary_actions, "回主线", "navigate_stage", {"source": "settle"})

	var followup_actions := add_button_row(growth_card)
	equipment_followup_button = add_action_button(followup_actions, "去穿戴", "navigate_equipment", {"source": "settle"})
	character_followup_button = add_action_button(followup_actions, "看角色", "navigate_character", {"source": "settle"})

	var debug_card := add_card("调试区", "技术字段和手动提交流程都留在这里，不占首屏。")
	recent_character_selector = add_labeled_option_button("当前出战角色", debug_card)
	recent_character_selector.item_selected.connect(_on_recent_character_selected)

	recent_stage_difficulty_selector = add_labeled_option_button("最近目标难度", debug_card)
	recent_stage_difficulty_selector.item_selected.connect(_on_recent_stage_difficulty_selected)

	battle_context_selector = add_labeled_option_button("最近战斗上下文", debug_card)
	battle_context_selector.item_selected.connect(_on_battle_context_selected)
	replace_options(battle_context_selector, [], "暂无最近战斗")

	override_toggle = add_check_box("显示调试输入", false, debug_card)
	override_toggle.toggled.connect(_on_override_toggled)
	override_box = VBoxContainer.new()
	override_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	override_box.visible = false
	debug_card.add_child(override_box)

	character_id_input = add_labeled_input("character_id（调试）", "", override_box)
	character_id_input.text_changed.connect(_on_character_id_changed)

	stage_difficulty_input = add_labeled_input(
		"stage_difficulty_id（调试）",
		"stage_nanshan_001_normal",
		override_box
	)
	stage_difficulty_input.text_changed.connect(_on_stage_difficulty_changed)

	battle_context_input = add_labeled_input("battle_context_id（调试）", "", override_box)
	battle_context_input.text_changed.connect(_on_battle_context_changed)

	killed_monsters_input = add_labeled_input("killed_monsters（逗号分隔）", "", override_box)
	var override_buttons := add_button_row(override_box)
	add_action_button(override_buttons, "带入本场敌人", "fill_prepared_monsters")
	add_action_button(override_buttons, "手动结算", "settle")

	is_cleared_checkbox = add_check_box("本次通关成功", true, override_box)

	show_handoff_summary("", "", "", 0)
	show_settlement_summary({})
	_move_secondary_sections_to_bottom()


func apply_config(values: Dictionary) -> void:
	character_id_input.text = normalize_id_string(
		values.get("battle_character_id", values.get("character_id", "1001"))
	)
	stage_difficulty_input.text = str(values.get("stage_difficulty_id", "stage_nanshan_001_normal"))


func render_settle_context(_character: Dictionary, route_context: Dictionary) -> void:
	_route_context = route_context.duplicate(true)
	result_meta_label.text = _build_route_summary({})


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
			label += " [未启用]"

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
		"暂无最近战斗",
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
		result_title_label.text = "这一场的收获还没回来"
		result_meta_label.text = _build_route_summary({})
		result_state_label.text = "这一场打完后，这里会先告诉你去了哪、拿到了什么，以及接下来更适合去哪里。"
		spotlight_title_label.text = "这一场最值得先看的收获"
		spotlight_detail_label.text = "如果有新装备、主要掉落或奖励变化，这里会先把最值得马上看的内容顶出来。"
		spotlight_box.add_child(_build_empty_label("现在还没有新的结果回流。"))
		growth_hint_label.text = "结算完成后，可以先看背包，再决定前往穿戴、查看角色，还是继续主线。"
		primary_inventory_button.text = "先整理本轮收益"
		equipment_followup_button.text = "去穿戴看装备"
		character_followup_button.text = "看角色"
		equipment_followup_button.disabled = false
		drop_box.add_child(_build_empty_label("这一场打完后，这里会展示本次掉落。"))
		reward_box.add_child(_build_empty_label("这一场打完后，这里会展示当前奖励状态变化。"))
		inventory_box.add_child(_build_empty_label("这一场打完后，这里会展示哪些收获真正进了背包。"))
		set_summary_text("")
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
	var inventory_entry_count := stack_results.size() + equipment_instance_results.size()

	result_title_label.text = "这场%s" % ("打赢了" if int(payload.get("is_cleared", 0)) == 1 else "已经收束")
	result_meta_label.text = _build_route_summary(stage_difficulty_data)
	result_state_label.text = _build_result_summary_text(
		int(payload.get("is_cleared", 0)) == 1,
		drop_results.size(),
		reward_results.size(),
		inventory_entry_count,
		reward_status_data
	)
	_render_result_tags(payload, drop_results, reward_results, stack_results, equipment_instance_results, reward_status_data)
	_render_spotlight_section(drop_results, reward_results, created_equipment_instances, reward_status_data)
	growth_hint_label.text = _build_growth_hint(
		reward_status_data,
		drop_results,
		reward_results,
		stack_results,
		created_equipment_instances
	)
	if not created_equipment_instances.is_empty():
		primary_inventory_button.text = "先整理本轮收益"
		equipment_followup_button.text = "去穿戴试新装备"
	elif inventory_entry_count > 0:
		primary_inventory_button.text = "去背包整理收益"
		equipment_followup_button.text = "去穿戴看装备"
	else:
		primary_inventory_button.text = "去背包看看"
		equipment_followup_button.text = "去穿戴"
	character_followup_button.text = "看角色"
	equipment_followup_button.disabled = false

	for drop in drop_results:
		var entry: Dictionary = drop if typeof(drop) == TYPE_DICTIONARY else {}
		drop_box.add_child(_build_result_card(
			"%s x%s" % [str(entry.get("item_name", "掉落物")), str(entry.get("quantity", 0))],
			_build_drop_meta(entry),
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
					_display_named_item(reward_item_entry, "奖励物资"),
					str(reward_item_entry.get("quantity", 0)),
				]
			)
		reward_box.add_child(_build_result_card(
			"奖励结果 %d" % reward_display_index,
			"奖励状态：%s | 奖励项 %d\n%s" % [
				_reward_grant_status_text(str(entry.get("grant_status", ""))),
				reward_count,
				("奖励内容：" + "、".join(reward_lines)) if not reward_lines.is_empty() else "奖励内容：本次没有可展示的奖励项。",
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
				_display_name_from_map(item_name_map, stack_item_id, "物资"),
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
			str(equipment_name_map.get(equipment_instance_id, "新装备")),
			"装备已入包 | 可以直接前往穿戴查看 | 耐久 %s/%s" % [
				str(equipment_entry.get("durability", 0)),
				str(equipment_entry.get("max_durability", 0)),
			],
			INVENTORY_TINT
		))

	if inventory_box.get_child_count() == 0:
		inventory_box.add_child(_build_empty_label("本次没有新增入包变化。"))

	set_summary_text("本轮收获：掉落 %d | 奖励 %d | 入包 %d" % [
		drop_results.size(),
		reward_results.size(),
		inventory_entry_count,
	])
	set_output_json(payload)


func show_handoff_summary(character_id: String, stage_difficulty_id: String, battle_context_id: String, monster_count: int) -> void:
	clear_container(spotlight_box)
	clear_container(drop_box)
	clear_container(reward_box)
	clear_container(inventory_box)
	clear_container(result_tag_row)
	result_title_label.text = "这一场的收获正在回来"
	result_meta_label.text = _build_route_summary({})
	result_state_label.text = "这一场已经开始收束，结果返回后，这里会自动拆开展示掉落、奖励和入包结果。"
	spotlight_title_label.text = "这一场的亮点还在路上"
	spotlight_detail_label.text = "一旦结果回来，这里会先告诉你有没有新装备、主要掉落或奖励变化。"
	spotlight_box.add_child(_build_empty_label("现在只差这一场的正式结果返回。"))
	drop_box.add_child(_build_empty_label("结果返回后，这里会展示本次掉落。"))
	reward_box.add_child(_build_empty_label("结果返回后，这里会展示当前奖励状态变化。"))
	inventory_box.add_child(_build_empty_label("结果返回后，这里会展示哪些收获已经进包。"))
	growth_hint_label.text = "等结果回来后，这里会告诉你更适合先看背包、前往穿戴，还是回主线继续推进。"
	primary_inventory_button.text = "先整理本轮收益"
	equipment_followup_button.text = "去穿戴看装备"
	character_followup_button.text = "看角色"
	equipment_followup_button.disabled = false
	set_summary_text("这场已经结束，收获正在整理。")
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
		return "奖励状态会跟着这场收获一起同步。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "当前没有新增奖励，这属于正常情况；掉落和入包仍然照常结算。"
	if int(reward_status.get("has_granted", 0)) == 1:
		if reward_result_count > 0:
			return "首通奖励已经发放完成，本次新增奖励也已经进入结果页。"
		return "当前没有新增奖励，这属于正常情况，说明首通奖励已经领过。"
	if str(reward_status.get("grant_status", "")) == "failed":
		return "奖励状态暂未完成回写，稍后回主线刷新即可继续确认。"
	return "奖励状态还在同步中，稍后回主线刷新即可继续确认。"


func _render_spotlight_section(
	drop_results: Array,
	reward_results: Array,
	created_equipment_instances: Array,
	reward_status: Dictionary
) -> void:
	if not created_equipment_instances.is_empty():
		spotlight_title_label.text = "本轮最值得先看的，是新装备"
		spotlight_detail_label.text = "新装备已经正式入包，可以直接从这里前往穿戴试装。"
		var equipment_index := 0
		for equipment in created_equipment_instances:
			if equipment_index >= 3:
				break
			var equipment_entry: Dictionary = equipment if typeof(equipment) == TYPE_DICTIONARY else {}
			spotlight_box.add_child(_build_result_card(
				str(equipment_entry.get("item_name", "新装备")),
				"这件新装备已经准备好去试穿，可以先看背包或前往穿戴页确认收益。",
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
						_display_named_item(reward_item_entry, "奖励物资"),
						str(reward_item_entry.get("quantity", 0)),
					]
				)
			spotlight_box.add_child(_build_result_card(
				"奖励结果 %d" % (reward_index + 1),
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
				"%s x%s" % [str(drop_entry.get("item_name", "掉落物")), str(drop_entry.get("quantity", 0))],
				"这是本轮主要掉落之一，可以继续往下看它是否已经进包。",
				DROP_TINT
			))
			drop_index += 1
		return

	spotlight_title_label.text = "这轮没有新增收获"
	if int(reward_status.get("has_reward", 0)) == 1 and int(reward_status.get("has_granted", 0)) == 1:
		spotlight_detail_label.text = "这不是异常，说明首通奖励已经领过；你可以直接再战一场，或回主线换目标。"
	else:
		spotlight_detail_label.text = "这不是异常，当前更适合回主线换目标，或直接再战一场。"
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
		return "奖励待同步"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "无首通奖励"
	if int(reward_status.get("has_granted", 0)) == 1:
		return "首通已领取"
	if str(reward_status.get("grant_status", "")) == "failed":
		return "奖励待补发"
	return "首通未领取"


func _build_growth_hint(
	reward_status: Dictionary,
	drop_results: Array,
	reward_results: Array,
	stack_results: Array,
	created_equipment_instances: Array
) -> String:
	if not created_equipment_instances.is_empty():
		return "本次拿到了 %d 件新装备，背包页会先承接这批收益，再把可试装的新装备明确导向穿戴页；当前角色和新装备信息都会继续保留。" % created_equipment_instances.size()
	if not stack_results.is_empty():
		return "收益已经正式入包，先去背包整理本轮材料和其他收益会更顺，再决定回角色看成长还是继续主线。"
	if reward_results.is_empty() and int(reward_status.get("has_reward", 0)) == 1 and int(reward_status.get("has_granted", 0)) == 1:
		return "奖励没有新增不是错误，说明这份首通奖励已经领过；这次可以直接再战一场，或回主线继续推进。"
	if int(reward_status.get("has_reward", 0)) == 0 and drop_results.is_empty():
		return "这个难度没有首通奖励，本次也没有额外收益；可以直接再战一场，或回主线换目标。"
	return "结果已经汇总完成，建议先看背包，再决定继续推进还是回角色查看成长。"


func _build_route_summary(stage_difficulty_data: Dictionary) -> String:
	var chapter_name := str(_route_context.get("chapter_name", "当前章节待确认"))
	var stage_name := str(_route_context.get("stage_name", "当前关卡待确认"))
	var difficulty_name := str(stage_difficulty_data.get("difficulty_name", _route_context.get("difficulty_name", "当前难度待确认")))
	return "这一场：%s / %s / %s" % [chapter_name, stage_name, difficulty_name]


func _build_result_summary_text(
	is_cleared: bool,
	drop_count: int,
	reward_count: int,
	inventory_count: int,
	reward_status: Dictionary
) -> String:
	return "这一场已经%s，本轮收获：掉落 %d 项 / 奖励 %d 份 / 入包 %d 条。%s" % [
		"打完" if is_cleared else "收束",
		drop_count,
		reward_count,
		inventory_count,
		_format_reward_result_state(reward_status, reward_count),
	]


func _build_drop_meta(entry: Dictionary) -> String:
	var rarity_text := str(entry.get("rarity", "")).strip_edges()
	if rarity_text.is_empty():
		return "怪物掉落，已经计入这场收获。"
	return "怪物掉落 | 稀有度 %s" % rarity_text


func _display_named_item(entry: Dictionary, fallback: String) -> String:
	var item_name := str(entry.get("item_name", "")).strip_edges()
	if not item_name.is_empty():
		return item_name
	return fallback


func _display_name_from_map(item_name_map: Dictionary, item_id: String, fallback: String) -> String:
	var resolved := str(item_name_map.get(item_id, "")).strip_edges()
	if not resolved.is_empty():
		return resolved
	return fallback


func _reward_grant_status_text(grant_status: String) -> String:
	match grant_status:
		"success":
			return "已发放"
		"failed":
			return "暂未发放"
		"":
			return "待确认"
		_:
			return "处理中"


func _build_item_name_map(drop_results: Array, reward_results: Array) -> Dictionary:
	var item_name_map := {}
	for drop in drop_results:
		var drop_entry: Dictionary = drop if typeof(drop) == TYPE_DICTIONARY else {}
		var drop_item_id := str(drop_entry.get("item_id", ""))
		var drop_item_name := str(drop_entry.get("item_name", "")).strip_edges()
		if drop_item_id.is_empty():
			continue
		if not drop_item_name.is_empty():
			item_name_map[drop_item_id] = drop_item_name

	for reward in reward_results:
		var reward_entry: Dictionary = reward if typeof(reward) == TYPE_DICTIONARY else {}
		var reward_items: Array = reward_entry.get("reward_items", []) if typeof(reward_entry.get("reward_items", [])) == TYPE_ARRAY else []
		for reward_item in reward_items:
			var reward_item_entry: Dictionary = reward_item if typeof(reward_item) == TYPE_DICTIONARY else {}
			var reward_item_id := str(reward_item_entry.get("item_id", ""))
			var reward_item_name := str(reward_item_entry.get("item_name", "")).strip_edges()
			if reward_item_id.is_empty():
				continue
			if not reward_item_name.is_empty():
				item_name_map[reward_item_id] = reward_item_name

	return item_name_map


func _build_created_equipment_map(created_equipment_instances: Array) -> Dictionary:
	var equipment_name_map := {}
	for equipment in created_equipment_instances:
		var equipment_entry: Dictionary = equipment if typeof(equipment) == TYPE_DICTIONARY else {}
		var equipment_instance_id := normalize_id_string(equipment_entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty():
			continue
		equipment_name_map[equipment_instance_id] = _display_named_item(equipment_entry, "新装备")

	return equipment_name_map


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

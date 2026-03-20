extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneSettlePage

var recent_character_selector: OptionButton
var character_id_input: LineEdit
var recent_stage_difficulty_selector: OptionButton
var stage_difficulty_input: LineEdit
var battle_context_selector: OptionButton
var battle_context_input: LineEdit
var killed_monsters_input: LineEdit
var is_cleared_checkbox: CheckBox


func _init() -> void:
	setup_page(
		"Battle Settle",
		[
			"Settle 页真实接 POST /api/battles/settle，不会本地生成 battle_context_id，也不会猜测奖励状态。",
		]
	)

	recent_character_selector = add_labeled_option_button("Battle 角色（优先真实角色列表）")
	recent_character_selector.item_selected.connect(_on_recent_character_selected)
	character_id_input = add_labeled_input("character_id", "")
	character_id_input.text_changed.connect(_on_character_id_changed)

	recent_stage_difficulty_selector = add_labeled_option_button("最近成功难度 / 当前已选难度")
	recent_stage_difficulty_selector.item_selected.connect(_on_recent_stage_difficulty_selected)
	stage_difficulty_input = add_labeled_input("stage_difficulty_id", "stage_nanshan_001_normal")
	stage_difficulty_input.text_changed.connect(_on_stage_difficulty_changed)

	battle_context_selector = add_labeled_option_button("本轮 Prepare 生成的 battle_context")
	battle_context_selector.item_selected.connect(_on_battle_context_selected)
	replace_options(battle_context_selector, [], "暂无 Prepare 上下文")
	battle_context_input = add_labeled_input("battle_context_id", "")
	battle_context_input.text_changed.connect(_on_battle_context_changed)

	killed_monsters_input = add_labeled_input("killed_monsters（逗号分隔）", "")
	is_cleared_checkbox = add_check_box("is_cleared = 1", true)

	var buttons := add_button_row()
	add_action_button(buttons, "使用 Prepare 怪物列表", "fill_prepared_monsters")
	add_action_button(buttons, "执行 Settle", "settle")


func apply_config(values: Dictionary) -> void:
	character_id_input.text = str(values.get("battle_character_id", values.get("character_id", "1001")))
	stage_difficulty_input.text = str(values.get("stage_difficulty_id", "stage_nanshan_001_normal"))


func set_recent_characters(records: Array, current_character_id: String) -> void:
	var options: Array = []
	for record in records:
		var entry = record if typeof(record) == TYPE_DICTIONARY else {}
		var character_id = str(entry.get("character_id", ""))
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
	character_id_input.text = character_id


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
	var drop_results = payload.get("drop_results", [])
	var reward_results = payload.get("reward_results", [])
	var inventory_results = payload.get("inventory_results", {})
	var inventory_result_data = inventory_results if typeof(inventory_results) == TYPE_DICTIONARY else {}
	var stack_results = inventory_result_data.get("stack_results", [])
	var equipment_results = inventory_result_data.get("equipment_results", [])
	set_summary_text("drops=%d | rewards=%d | stack_writes=%d | equipment_writes=%d" % [
		drop_results.size(),
		reward_results.size(),
		stack_results.size(),
		equipment_results.size(),
	])
	set_output_json(payload)


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

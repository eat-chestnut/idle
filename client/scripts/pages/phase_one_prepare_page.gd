extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOnePreparePage

var recent_character_selector: OptionButton
var character_id_input: LineEdit
var recent_stage_difficulty_selector: OptionButton
var stage_difficulty_input: LineEdit


func _init() -> void:
	setup_page(
		"Battle Prepare",
		[
			"Prepare 页真实接 POST /api/battles/prepare。",
			"当前真实后端要求 battle 角色为 is_active=1；若目标角色未启用，请先走真实激活接口。",
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

	var buttons := add_button_row()
	add_action_button(buttons, "激活当前 Battle 角色", "activate_battle_character")
	add_action_button(buttons, "执行 Prepare", "prepare")


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


func set_character_id(character_id: String) -> void:
	character_id_input.text = character_id


func set_stage_difficulty_id(stage_difficulty_id: String) -> void:
	stage_difficulty_input.text = stage_difficulty_id


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func get_stage_difficulty_text() -> String:
	return stage_difficulty_input.text.strip_edges()


func show_prepare_summary(payload: Dictionary) -> void:
	var monsters = payload.get("monster_list", [])
	var stage_difficulty = payload.get("stage_difficulty", {})
	var stage_difficulty_data = stage_difficulty if typeof(stage_difficulty) == TYPE_DICTIONARY else {}
	set_summary_text("battle_context_id=%s | monsters=%d | difficulty=%s" % [
		str(payload.get("battle_context_id", "")),
		monsters.size(),
		str(stage_difficulty_data.get("stage_difficulty_id", "")),
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

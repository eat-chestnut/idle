extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneStagePage

var chapter_list: ItemList
var recent_stage_selector: OptionButton
var stage_id_input: LineEdit
var difficulty_list: ItemList
var _selected_stage_difficulty_id := ""


func _init() -> void:
	setup_page(
		"章节与难度",
		[
			"当前 phase-one 没有公开 stage list API，所以这里不会伪造正式关卡列表。",
			"章节页展示真实章节接口结果，stage_id 只提供默认联调值、最近成功值和手动补充入口。",
		]
	)

	var chapter_buttons := add_button_row()
	add_action_button(chapter_buttons, "读取章节列表", "load_chapters")

	chapter_list = add_labeled_item_list("章节列表", 120)
	chapter_list.item_selected.connect(_on_chapter_selected)

	recent_stage_selector = add_labeled_option_button("最近成功的 stage_id（非正式 stage list）")
	recent_stage_selector.item_selected.connect(_on_recent_stage_selected)
	stage_id_input = add_labeled_input("stage_id", "stage_nanshan_001")
	stage_id_input.text_changed.connect(_on_stage_id_changed)

	var difficulty_buttons := add_button_row()
	add_action_button(difficulty_buttons, "读取难度列表", "load_difficulties")
	add_action_button(difficulty_buttons, "刷新首通奖励状态", "refresh_reward_status")

	difficulty_list = add_labeled_item_list("难度列表", 180)
	difficulty_list.item_selected.connect(_on_difficulty_selected)


func apply_config(values: Dictionary) -> void:
	stage_id_input.text = str(values.get("stage_id", "stage_nanshan_001"))


func set_recent_stage_ids(stage_ids: Array, current_stage_id: String) -> void:
	var options: Array = []
	for stage_id in stage_ids:
		var normalized = str(stage_id).strip_edges()
		if normalized.is_empty():
			continue
		options.append({
			"label": normalized,
			"value": normalized,
		})

	replace_options(recent_stage_selector, options, "暂无成功 stage_id", current_stage_id)


func set_stage_id(stage_id: String) -> void:
	stage_id_input.text = stage_id


func get_stage_id_text() -> String:
	return stage_id_input.text.strip_edges()


func set_selected_stage_difficulty(stage_difficulty_id: String) -> void:
	_selected_stage_difficulty_id = stage_difficulty_id
	for index in range(difficulty_list.item_count):
		var metadata = difficulty_list.get_item_metadata(index)
		if typeof(metadata) == TYPE_DICTIONARY and str(metadata.get("stage_difficulty_id", "")) == stage_difficulty_id:
			difficulty_list.select(index)
			break


func get_selected_stage_difficulty() -> String:
	return _selected_stage_difficulty_id


func render_chapters(payload: Dictionary) -> void:
	chapter_list.clear()
	for chapter in payload.get("chapters", []):
		var entry = chapter if typeof(chapter) == TYPE_DICTIONARY else {}
		chapter_list.add_item("%s (%s)" % [
			str(entry.get("chapter_name", "")),
			str(entry.get("chapter_id", "")),
		])
		chapter_list.set_item_metadata(chapter_list.item_count - 1, entry)

	set_summary_text("chapters=%d | 当前 stage_id=%s" % [chapter_list.item_count, get_stage_id_text()])


func render_difficulties(payload: Dictionary, reward_status: Dictionary) -> void:
	difficulty_list.clear()

	for difficulty in payload.get("difficulties", []):
		var entry = difficulty if typeof(difficulty) == TYPE_DICTIONARY else {}
		var reward = entry.get("first_clear_reward", {})
		var reward_text = "reward=none"
		if typeof(reward) == TYPE_DICTIONARY:
			if int(reward.get("has_reward", 0)) == 1 and int(reward.get("has_granted", 0)) == 1:
				reward_text = "reward=claimed"
			elif int(reward.get("has_reward", 0)) == 1:
				reward_text = "reward=available"

		difficulty_list.add_item("%s [%s] power=%s %s" % [
			str(entry.get("difficulty_name", "")),
			str(entry.get("stage_difficulty_id", "")),
			str(entry.get("recommended_power", "")),
			reward_text,
		])
		difficulty_list.set_item_metadata(difficulty_list.item_count - 1, entry)

	set_output_json({
		"stage_id": payload.get("stage_id", ""),
		"difficulties": payload.get("difficulties", []),
		"reward_status": reward_status,
	})


func render_reward_status(chapters: Dictionary, difficulties: Dictionary, reward_status: Dictionary) -> void:
	set_output_json({
		"chapters": chapters.get("chapters", []),
		"difficulties": difficulties.get("difficulties", []),
		"reward_status": reward_status,
	})


func set_stage_summary(chapter_count: int, difficulty_count: int, reward_status: Dictionary) -> void:
	var reward_text = "未读取奖励状态"
	if not reward_status.is_empty():
		if int(reward_status.get("has_reward", 0)) == 1 and int(reward_status.get("has_granted", 0)) == 1:
			reward_text = "首通奖励已领取"
		elif int(reward_status.get("has_reward", 0)) == 1:
			reward_text = "首通奖励待领取"
		else:
			reward_text = "无首通奖励"

	set_summary_text("chapters=%d | difficulties=%d | 当前 stage_id=%s | %s" % [
		chapter_count,
		difficulty_count,
		get_stage_id_text(),
		reward_text,
	])


func _on_recent_stage_selected(_index: int) -> void:
	var selected = get_selected_option(recent_stage_selector)
	var stage_id = str(selected.get("value", ""))
	if stage_id.is_empty():
		return

	stage_id_input.text = stage_id
	_emit_context("stage_id_changed", {"stage_id": stage_id})


func _on_stage_id_changed(_text: String) -> void:
	_emit_context("stage_id_changed", {"stage_id": get_stage_id_text()})


func _on_chapter_selected(index: int) -> void:
	var metadata = chapter_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	var chapter_id = str(metadata.get("chapter_id", ""))
	set_page_state("success", "已选中章节 %s。当前章节接口不返回 stage_id，请从最近成功 stage 或默认联调值继续。" % chapter_id)


func _on_difficulty_selected(index: int) -> void:
	var metadata = difficulty_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	_selected_stage_difficulty_id = str(metadata.get("stage_difficulty_id", ""))
	_emit_action("difficulty_selected", metadata)

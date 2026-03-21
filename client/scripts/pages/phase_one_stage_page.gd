extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneStagePage

var chapter_list: ItemList
var stage_list: ItemList
var stage_override_toggle: CheckBox
var stage_override_box: VBoxContainer
var stage_id_input: LineEdit
var difficulty_list: ItemList
var _selected_chapter_id := ""
var _selected_stage_difficulty_id := ""


func _init() -> void:
	setup_page(
		"主线",
		[
			"主路径是：读取章节 -> 选择章节 -> 自动读取关卡 -> 选择关卡 -> 自动读取难度。",
			"手输 `stage_id` 仅保留给联调覆盖，不再作为主流程入口。",
		]
	)

	var chapter_buttons := add_button_row()
	add_action_button(chapter_buttons, "进入章节列表", "load_chapters")
	add_action_button(chapter_buttons, "重读当前章节关卡", "load_stages")

	chapter_list = add_labeled_item_list("章节列表", 120)
	chapter_list.item_selected.connect(_on_chapter_selected)

	stage_list = add_labeled_item_list("关卡列表", 120)
	stage_list.item_selected.connect(_on_stage_selected)

	stage_override_toggle = add_check_box("显示 stage_id 联调覆盖输入", false)
	stage_override_toggle.toggled.connect(_on_stage_override_toggled)
	stage_override_box = VBoxContainer.new()
	stage_override_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_override_box.visible = false
	get_body().add_child(stage_override_box)

	stage_id_input = add_labeled_input("当前 stage_id（联调覆盖）", "stage_nanshan_001", stage_override_box)
	stage_id_input.text_changed.connect(_on_stage_id_changed)

	var difficulty_buttons := add_button_row()
	add_action_button(difficulty_buttons, "重读当前难度列表", "load_difficulties")
	add_action_button(difficulty_buttons, "刷新首通奖励状态", "refresh_reward_status")

	difficulty_list = add_labeled_item_list("难度列表", 180)
	difficulty_list.item_selected.connect(_on_difficulty_selected)


func apply_config(values: Dictionary) -> void:
	stage_id_input.text = str(values.get("stage_id", "stage_nanshan_001"))


func set_stage_id(stage_id: String) -> void:
	stage_id_input.text = stage_id


func get_stage_id_text() -> String:
	return stage_id_input.text.strip_edges()


func get_selected_chapter_id() -> String:
	return _selected_chapter_id


func set_selected_chapter_id(chapter_id: String) -> void:
	_selected_chapter_id = chapter_id


func set_selected_stage_difficulty(stage_difficulty_id: String) -> void:
	_selected_stage_difficulty_id = stage_difficulty_id
	for index in range(difficulty_list.item_count):
		var metadata = difficulty_list.get_item_metadata(index)
		if typeof(metadata) == TYPE_DICTIONARY and str(metadata.get("stage_difficulty_id", "")) == stage_difficulty_id:
			difficulty_list.select(index)
			break


func get_selected_stage_difficulty() -> String:
	return _selected_stage_difficulty_id


func render_chapters(payload: Dictionary, current_chapter_id: String = "") -> void:
	chapter_list.clear()
	var selected_chapter_id := current_chapter_id

	for chapter in payload.get("chapters", []):
		var entry = chapter if typeof(chapter) == TYPE_DICTIONARY else {}
		chapter_list.add_item("%s (%s)" % [
			str(entry.get("chapter_name", "")),
			str(entry.get("chapter_id", "")),
		])
		chapter_list.set_item_metadata(chapter_list.item_count - 1, entry)

	if selected_chapter_id.is_empty() and chapter_list.item_count > 0:
		var first_entry = chapter_list.get_item_metadata(0)
		if typeof(first_entry) == TYPE_DICTIONARY:
			selected_chapter_id = str(first_entry.get("chapter_id", ""))

	for index in range(chapter_list.item_count):
		var metadata = chapter_list.get_item_metadata(index)
		if typeof(metadata) != TYPE_DICTIONARY:
			continue
		if str(metadata.get("chapter_id", "")) == selected_chapter_id:
			chapter_list.select(index)
			break

	_selected_chapter_id = selected_chapter_id
	set_summary_text("chapters=%d | 当前 chapter_id=%s | 当前 stage_id=%s" % [
		chapter_list.item_count,
		_selected_chapter_id if not _selected_chapter_id.is_empty() else "(未选择)",
		get_stage_id_text(),
	])


func render_stages(payload: Dictionary) -> void:
	stage_list.clear()
	var selected_stage_id := get_stage_id_text()

	for stage in payload.get("stages", []):
		var entry = stage if typeof(stage) == TYPE_DICTIONARY else {}
		stage_list.add_item("%s (%s)" % [
			str(entry.get("stage_name", "")),
			str(entry.get("stage_id", "")),
		])
		stage_list.set_item_metadata(stage_list.item_count - 1, entry)

	if selected_stage_id.is_empty() and stage_list.item_count > 0:
		var first_stage = stage_list.get_item_metadata(0)
		if typeof(first_stage) == TYPE_DICTIONARY:
			selected_stage_id = str(first_stage.get("stage_id", ""))

	for index in range(stage_list.item_count):
		var metadata = stage_list.get_item_metadata(index)
		if typeof(metadata) != TYPE_DICTIONARY:
			continue
		if str(metadata.get("stage_id", "")) == selected_stage_id:
			stage_list.select(index)
			break

	if not selected_stage_id.is_empty():
		stage_id_input.text = selected_stage_id

	set_summary_text("chapter_id=%s | stages=%d | 当前 stage_id=%s" % [
		str(payload.get("chapter_id", _selected_chapter_id)),
		stage_list.item_count,
		get_stage_id_text(),
	])


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


func render_reward_context(
	chapters: Dictionary,
	stages: Dictionary,
	difficulties: Dictionary,
	reward_status: Dictionary
) -> void:
	set_output_json({
		"chapters": chapters.get("chapters", []),
		"stages": stages.get("stages", []),
		"difficulties": difficulties.get("difficulties", []),
		"reward_status": reward_status,
	})


func set_stage_summary(chapter_count: int, stage_count: int, difficulty_count: int, reward_status: Dictionary) -> void:
	var reward_text = "未读取奖励状态"
	if not reward_status.is_empty():
		if int(reward_status.get("has_reward", 0)) == 1 and int(reward_status.get("has_granted", 0)) == 1:
			reward_text = "首通奖励已领取"
		elif int(reward_status.get("has_reward", 0)) == 1:
			reward_text = "首通奖励待领取"
		else:
			reward_text = "无首通奖励"

	var stage_difficulty_text = _selected_stage_difficulty_id if not _selected_stage_difficulty_id.is_empty() else "(未选择)"
	set_summary_text("chapters=%d | stages=%d | difficulties=%d | 当前 stage_id=%s | 当前难度=%s | %s" % [
		chapter_count,
		stage_count,
		difficulty_count,
		get_stage_id_text(),
		stage_difficulty_text,
		reward_text,
	])


func _on_stage_override_toggled(pressed: bool) -> void:
	stage_override_box.visible = pressed


func _on_stage_id_changed(_text: String) -> void:
	_emit_context("stage_id_changed", {"stage_id": get_stage_id_text()})


func _on_chapter_selected(index: int) -> void:
	var metadata = chapter_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	var chapter_id = str(metadata.get("chapter_id", ""))
	_selected_chapter_id = chapter_id
	set_page_state("success", "已选中章节 %s，接下来读取真实关卡列表。" % chapter_id)
	_emit_action("chapter_selected", {"chapter_id": chapter_id})


func _on_stage_selected(index: int) -> void:
	var metadata = stage_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	var stage_id = str(metadata.get("stage_id", ""))
	if stage_id.is_empty():
		return

	stage_id_input.text = stage_id
	_emit_context("stage_id_changed", {"stage_id": stage_id})
	set_page_state("loading", "已选中关卡 %s，正在读取真实难度列表。" % stage_id)
	_emit_action("stage_selected", metadata)


func _on_difficulty_selected(index: int) -> void:
	var metadata = difficulty_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	_selected_stage_difficulty_id = str(metadata.get("stage_difficulty_id", ""))
	_emit_action("difficulty_selected", metadata)

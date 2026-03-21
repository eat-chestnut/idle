extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneStagePage

const CHAPTER_TINT := Color(0.52, 0.74, 0.98, 1.0)
const STAGE_TINT := Color(0.57, 0.86, 0.72, 1.0)
const DIFFICULTY_TINT := Color(0.97, 0.74, 0.40, 1.0)

var route_title_label: Label
var route_meta_label: Label
var reward_hint_label: Label
var route_tag_row: HBoxContainer

var chapter_cards_box: VBoxContainer
var stage_cards_box: VBoxContainer
var difficulty_cards_box: VBoxContainer

var stage_override_toggle: CheckBox
var stage_override_box: VBoxContainer
var stage_id_input: LineEdit

var _selected_chapter_id := ""
var _selected_stage_difficulty_id := ""
var _chapters_payload: Dictionary = {}
var _stages_payload: Dictionary = {}
var _difficulties_payload: Dictionary = {}
var _reward_status_payload: Dictionary = {}


func _init() -> void:
	setup_page(
		"主线",
		[
			"主线页现在按竖版推进顺序组织：章节 -> 关卡 -> 难度 -> 出战。",
			"仍然不做复杂横向地图，只把推进感、奖励状态和当前目标清晰地收出来。",
		]
	)

	var route_card := add_card("当前推进", "先锁定章节，再选关卡和难度；选中难度后会同步首通奖励状态。")
	route_title_label = Label.new()
	route_title_label.add_theme_font_size_override("font_size", 22)
	route_card.add_child(route_title_label)

	route_meta_label = Label.new()
	route_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_card.add_child(route_meta_label)

	reward_hint_label = Label.new()
	reward_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_hint_label.modulate = CARD_TEXT_MUTED
	route_card.add_child(reward_hint_label)

	route_tag_row = HBoxContainer.new()
	route_tag_row.add_theme_constant_override("separation", 8)
	route_card.add_child(route_tag_row)

	var route_buttons := add_button_row(route_card)
	add_action_button(route_buttons, "读取章节", "load_chapters")
	add_action_button(route_buttons, "重读当前章节", "load_stages")
	add_action_button(route_buttons, "刷新难度", "load_difficulties")
	add_action_button(route_buttons, "刷新首通奖励", "refresh_reward_status")

	var chapter_card := add_card("章节区", "默认优先展开当前常用章节，不引入横向大地图。")
	chapter_cards_box = VBoxContainer.new()
	chapter_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_cards_box.add_theme_constant_override("separation", 10)
	chapter_card.add_child(chapter_cards_box)

	var stage_card := add_card("关卡区", "关卡保持纵向浏览，方便竖版逐层推进。")
	stage_cards_box = VBoxContainer.new()
	stage_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_cards_box.add_theme_constant_override("separation", 10)
	stage_card.add_child(stage_cards_box)

	var difficulty_card := add_card("难度与首通奖励", "选中难度后会自动同步出战确认页。")
	difficulty_cards_box = VBoxContainer.new()
	difficulty_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_cards_box.add_theme_constant_override("separation", 10)
	difficulty_card.add_child(difficulty_cards_box)

	stage_override_toggle = add_check_box("显示 stage_id 联调覆盖输入", false, difficulty_card)
	stage_override_toggle.toggled.connect(_on_stage_override_toggled)

	stage_override_box = VBoxContainer.new()
	stage_override_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_override_box.visible = false
	difficulty_card.add_child(stage_override_box)

	stage_id_input = add_labeled_input("当前 stage_id（联调覆盖）", "stage_nanshan_001", stage_override_box)
	stage_id_input.text_changed.connect(_on_stage_id_changed)

	set_stage_summary(0, 0, 0, {})


func apply_config(values: Dictionary) -> void:
	stage_id_input.text = str(values.get("stage_id", "stage_nanshan_001"))


func set_stage_id(stage_id: String) -> void:
	stage_id_input.text = stage_id
	_refresh_route_header()


func get_stage_id_text() -> String:
	return stage_id_input.text.strip_edges()


func get_selected_chapter_id() -> String:
	return _selected_chapter_id


func set_selected_chapter_id(chapter_id: String) -> void:
	_selected_chapter_id = chapter_id
	_refresh_route_header()


func set_selected_stage_difficulty(stage_difficulty_id: String) -> void:
	_selected_stage_difficulty_id = stage_difficulty_id
	_refresh_route_header()
	_rebuild_difficulty_cards()


func get_selected_stage_difficulty() -> String:
	return _selected_stage_difficulty_id


func render_chapters(payload: Dictionary, current_chapter_id: String = "") -> void:
	_chapters_payload = payload.duplicate(true)
	clear_container(chapter_cards_box)

	var selected_chapter_id: String = current_chapter_id
	if selected_chapter_id.is_empty():
		selected_chapter_id = _selected_chapter_id

	for chapter in payload.get("chapters", []):
		var entry: Dictionary = chapter if typeof(chapter) == TYPE_DICTIONARY else {}
		var chapter_id := str(entry.get("chapter_id", "")).strip_edges()
		if chapter_id.is_empty():
			continue
		chapter_cards_box.add_child(_build_chapter_card(entry))

	if selected_chapter_id.is_empty():
		var first_chapter: Dictionary = _first_payload_entry(payload.get("chapters", []))
		selected_chapter_id = str(first_chapter.get("chapter_id", ""))

	_selected_chapter_id = selected_chapter_id
	_refresh_route_header()


func render_stages(payload: Dictionary) -> void:
	_stages_payload = payload.duplicate(true)
	clear_container(stage_cards_box)

	var selected_stage_id: String = get_stage_id_text()
	for stage in payload.get("stages", []):
		var entry: Dictionary = stage if typeof(stage) == TYPE_DICTIONARY else {}
		var stage_id := str(entry.get("stage_id", "")).strip_edges()
		if stage_id.is_empty():
			continue
		stage_cards_box.add_child(_build_stage_card(entry))

	if selected_stage_id.is_empty():
		var first_stage: Dictionary = _first_payload_entry(payload.get("stages", []))
		selected_stage_id = str(first_stage.get("stage_id", ""))

	if not selected_stage_id.is_empty():
		stage_id_input.text = selected_stage_id

	_refresh_route_header()

	if stage_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "当前章节还没有关卡。"
		empty_label.modulate = CARD_TEXT_MUTED
		stage_cards_box.add_child(empty_label)


func render_difficulties(payload: Dictionary, reward_status: Dictionary) -> void:
	_difficulties_payload = payload.duplicate(true)
	_reward_status_payload = reward_status.duplicate(true)
	_rebuild_difficulty_cards()
	_refresh_route_header()
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
	_chapters_payload = chapters.duplicate(true)
	_stages_payload = stages.duplicate(true)
	_difficulties_payload = difficulties.duplicate(true)
	_reward_status_payload = reward_status.duplicate(true)
	_refresh_route_header()
	_rebuild_difficulty_cards()
	set_output_json({
		"chapters": chapters.get("chapters", []),
		"stages": stages.get("stages", []),
		"difficulties": difficulties.get("difficulties", []),
		"reward_status": reward_status,
	})


func set_stage_summary(chapter_count: int, stage_count: int, difficulty_count: int, reward_status: Dictionary) -> void:
	var reward_text := _reward_status_text(reward_status)
	var stage_difficulty_text = _selected_stage_difficulty_id if not _selected_stage_difficulty_id.is_empty() else "(未选择)"
	set_summary_text("章节 %d | 关卡 %d | 难度 %d | 当前 stage_id=%s | 当前难度=%s | %s" % [
		chapter_count,
		stage_count,
		difficulty_count,
		get_stage_id_text() if not get_stage_id_text().is_empty() else "(未选择)",
		stage_difficulty_text,
		reward_text,
	])
	_reward_status_payload = reward_status.duplicate(true)
	_refresh_route_header()


func _build_chapter_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var chapter_id := str(entry.get("chapter_id", ""))
	var is_selected := chapter_id == _selected_chapter_id

	var title := Label.new()
	title.text = "%s  ·  %s" % [str(entry.get("chapter_name", "章节")), chapter_id]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var desc := Label.new()
	var desc_text := str(entry.get("chapter_desc", "")).strip_edges()
	if desc_text.is_empty():
		desc_text = "当前阶段没有额外章节文案，主线推进以后端真实章节列表为准。"
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = CARD_TEXT_MUTED
	box.add_child(desc)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill("章节", CHAPTER_TINT))
	if is_selected:
		tags.add_child(create_pill("当前展开", STAGE_TINT))
	box.add_child(tags)

	var button := Button.new()
	button.text = "展开本章节"
	button.pressed.connect(func() -> void:
		_selected_chapter_id = chapter_id
		set_page_state("loading", "已选中章节 %s，正在读取真实关卡列表。" % chapter_id)
		_emit_action("chapter_selected", {"chapter_id": chapter_id})
	)
	box.add_child(button)

	return card


func _build_stage_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var stage_id := str(entry.get("stage_id", ""))
	var is_selected := stage_id == get_stage_id_text()

	var title := Label.new()
	title.text = "%s  ·  第 %s 关" % [
		str(entry.get("stage_name", "关卡")),
		str(entry.get("stage_order", "")),
	]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "stage_id=%s%s" % [
		stage_id,
		" | 当前选中" if is_selected else "",
	]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill("关卡", STAGE_TINT))
	if is_selected:
		tags.add_child(create_pill("当前关卡", CHAPTER_TINT))
	box.add_child(tags)

	var button := Button.new()
	button.text = "选择关卡并读取难度"
	button.pressed.connect(func() -> void:
		stage_id_input.text = stage_id
		_emit_context("stage_id_changed", {"stage_id": stage_id})
		set_page_state("loading", "已选中关卡 %s，正在读取真实难度列表。" % stage_id)
		_emit_action("stage_selected", entry)
	)
	box.add_child(button)

	return card


func _rebuild_difficulty_cards() -> void:
	clear_container(difficulty_cards_box)

	var difficulties: Array = _difficulties_payload.get("difficulties", []) if typeof(_difficulties_payload.get("difficulties", [])) == TYPE_ARRAY else []
	for difficulty in difficulties:
		var entry: Dictionary = difficulty if typeof(difficulty) == TYPE_DICTIONARY else {}
		var stage_difficulty_id := str(entry.get("stage_difficulty_id", "")).strip_edges()
		if stage_difficulty_id.is_empty():
			continue
		difficulty_cards_box.add_child(_build_difficulty_card(entry))

	if difficulty_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "先选中关卡，再读取对应难度。"
		empty_label.modulate = CARD_TEXT_MUTED
		difficulty_cards_box.add_child(empty_label)


func _build_difficulty_card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var stage_difficulty_id := str(entry.get("stage_difficulty_id", ""))
	var reward: Dictionary = entry.get("first_clear_reward", {}) if typeof(entry.get("first_clear_reward", {})) == TYPE_DICTIONARY else {}
	var reward_data: Dictionary = reward
	var is_selected := stage_difficulty_id == _selected_stage_difficulty_id

	var title := Label.new()
	title.text = "%s  ·  推荐战力 %s" % [
		str(entry.get("difficulty_name", "难度")),
		str(entry.get("recommended_power", "-")),
	]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "stage_difficulty_id=%s" % stage_difficulty_id
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill("难度 %s" % str(entry.get("difficulty_key", "")), DIFFICULTY_TINT))
	if int(reward_data.get("has_reward", 0)) == 1:
		tags.add_child(create_pill("有首通奖励", STAGE_TINT))
	else:
		tags.add_child(create_pill("无首通奖励", CHAPTER_TINT))
	if is_selected:
		tags.add_child(create_pill("当前难度", DIFFICULTY_TINT))
	box.add_child(tags)

	var reward_label := Label.new()
	var reward_text := _reward_status_text(_reward_status_payload)
	if stage_difficulty_id != _selected_stage_difficulty_id or _reward_status_payload.is_empty():
		if int(reward_data.get("has_reward", 0)) == 1 and int(reward_data.get("has_granted", 0)) == 1:
			reward_text = "首通奖励：已领取"
		elif int(reward_data.get("has_reward", 0)) == 1:
			reward_text = "首通奖励：待领取"
		else:
			reward_text = "首通奖励：无"
	reward_label.text = reward_text
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.modulate = CARD_TEXT_MUTED
	box.add_child(reward_label)

	var button := Button.new()
	button.text = "选择该难度"
	button.pressed.connect(func() -> void:
		_selected_stage_difficulty_id = stage_difficulty_id
		_refresh_route_header()
		_emit_action("difficulty_selected", entry)
	)
	box.add_child(button)

	return card


func _refresh_route_header() -> void:
	var chapter := _find_chapter(_selected_chapter_id)
	var stage := _find_stage(get_stage_id_text())
	var difficulty := _find_difficulty(_selected_stage_difficulty_id)

	route_title_label.text = "%s / %s / %s" % [
		str(chapter.get("chapter_name", "章节待选择")),
		str(stage.get("stage_name", "关卡待选择")),
		str(difficulty.get("difficulty_name", "难度待选择")),
	]

	var recommended_power := str(difficulty.get("recommended_power", "-"))
	route_meta_label.text = "chapter_id=%s | stage_id=%s | stage_difficulty_id=%s | 推荐战力 %s" % [
		str(chapter.get("chapter_id", _selected_chapter_id if not _selected_chapter_id.is_empty() else "(未选择)")),
		get_stage_id_text() if not get_stage_id_text().is_empty() else "(未选择)",
		_selected_stage_difficulty_id if not _selected_stage_difficulty_id.is_empty() else "(未选择)",
		recommended_power,
	]
	reward_hint_label.text = _reward_status_text(_reward_status_payload)

	clear_container(route_tag_row)
	if not str(chapter.get("chapter_id", "")).is_empty():
		route_tag_row.add_child(create_pill("章节已锁定", CHAPTER_TINT))
	if not str(stage.get("stage_id", "")).is_empty():
		route_tag_row.add_child(create_pill("关卡已锁定", STAGE_TINT))
	if not str(difficulty.get("stage_difficulty_id", "")).is_empty():
		route_tag_row.add_child(create_pill("可进入出战确认", DIFFICULTY_TINT))


func _find_chapter(chapter_id: String) -> Dictionary:
	for chapter in _chapters_payload.get("chapters", []):
		var entry: Dictionary = chapter if typeof(chapter) == TYPE_DICTIONARY else {}
		if str(entry.get("chapter_id", "")) == chapter_id:
			return entry
	return {}


func _find_stage(stage_id: String) -> Dictionary:
	for stage in _stages_payload.get("stages", []):
		var entry: Dictionary = stage if typeof(stage) == TYPE_DICTIONARY else {}
		if str(entry.get("stage_id", "")) == stage_id:
			return entry
	return {}


func _find_difficulty(stage_difficulty_id: String) -> Dictionary:
	for difficulty in _difficulties_payload.get("difficulties", []):
		var entry: Dictionary = difficulty if typeof(difficulty) == TYPE_DICTIONARY else {}
		if str(entry.get("stage_difficulty_id", "")) == stage_difficulty_id:
			return entry
	return {}


func _first_payload_entry(entries: Variant) -> Dictionary:
	if typeof(entries) != TYPE_ARRAY or entries.is_empty():
		return {}
	var first_entry = entries[0]
	return first_entry if typeof(first_entry) == TYPE_DICTIONARY else {}


func _reward_status_text(reward_status: Dictionary) -> String:
	if reward_status.is_empty():
		return "首通奖励状态：等待读取。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "首通奖励状态：当前难度没有首通奖励。"
	if int(reward_status.get("has_granted", 0)) == 1:
		var grant_status := str(reward_status.get("grant_status", "")).strip_edges()
		if grant_status.is_empty():
			return "首通奖励状态：已领取。"
		return "首通奖励状态：已领取，grant_status=%s。" % grant_status
	return "首通奖励状态：可领取，尚未发放。"


func _on_stage_override_toggled(pressed: bool) -> void:
	stage_override_box.visible = pressed


func _on_stage_id_changed(_text: String) -> void:
	_refresh_route_header()
	_emit_context("stage_id_changed", {"stage_id": get_stage_id_text()})

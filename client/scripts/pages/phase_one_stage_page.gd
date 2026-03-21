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
var _selected_stage_id := ""
var _selected_stage_difficulty_id := ""
var _chapters_payload: Dictionary = {}
var _stages_payload: Dictionary = {}
var _difficulties_payload: Dictionary = {}
var _reward_status_payload: Dictionary = {}


func _init() -> void:
	setup_page("主线", [])

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
	_selected_chapter_id = str(values.get("chapter_id", "")).strip_edges()
	_selected_stage_id = str(values.get("stage_id", "stage_nanshan_001")).strip_edges()
	_selected_stage_difficulty_id = str(values.get("stage_difficulty_id", "")).strip_edges()
	stage_id_input.text = _selected_stage_id
	_refresh_route_header()


func set_stage_id(stage_id: String) -> void:
	_selected_stage_id = stage_id.strip_edges()
	stage_id_input.text = _selected_stage_id
	_rebuild_stage_cards()
	_refresh_route_header()


func get_stage_id_text() -> String:
	if not _selected_stage_id.is_empty():
		return _selected_stage_id
	return stage_id_input.text.strip_edges()


func get_selected_chapter_id() -> String:
	return _selected_chapter_id


func set_selected_chapter_id(chapter_id: String) -> void:
	_selected_chapter_id = chapter_id.strip_edges()
	_rebuild_chapter_cards()
	_refresh_route_header()


func set_selected_stage_difficulty(stage_difficulty_id: String) -> void:
	_selected_stage_difficulty_id = stage_difficulty_id.strip_edges()
	_refresh_route_header()
	_rebuild_difficulty_cards()


func get_selected_stage_difficulty() -> String:
	return _selected_stage_difficulty_id


func render_chapters(payload: Dictionary, current_chapter_id: String = "") -> void:
	_chapters_payload = payload.duplicate(true)
	var chapters: Array = payload.get("chapters", []) if typeof(payload.get("chapters", [])) == TYPE_ARRAY else []
	_selected_chapter_id = _resolve_preferred_identifier(
		chapters,
		"chapter_id",
		[current_chapter_id, _selected_chapter_id]
	)
	_rebuild_chapter_cards()
	_refresh_route_header()


func render_stages(payload: Dictionary) -> void:
	_stages_payload = payload.duplicate(true)
	var stages: Array = payload.get("stages", []) if typeof(payload.get("stages", [])) == TYPE_ARRAY else []
	_selected_stage_id = _resolve_preferred_identifier(
		stages,
		"stage_id",
		[get_stage_id_text()]
	)
	stage_id_input.text = _selected_stage_id
	_rebuild_stage_cards()
	_refresh_route_header()


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
	var next_step := "主线已经展开，继续往下选就能推进。"
	if chapter_count <= 0:
		next_step = "当前还没有开放章节。"
	elif stage_count <= 0:
		next_step = "这一章节暂时还没有可推进的关卡。"
	elif difficulty_count <= 0:
		next_step = "点一个关卡，就会展开可选难度。"
	elif _selected_stage_difficulty_id.is_empty():
		next_step = "选一档难度，就能进入出战确认。"
	else:
		next_step = "当前目标已经锁定，可以直接进入出战。"

	set_summary_text("已开放章节 %d 个 | 当前章节关卡 %d 个 | 可选难度 %d 个 | %s | 下一步：%s" % [
		chapter_count,
		stage_count,
		difficulty_count,
		_reward_status_text(reward_status),
		next_step,
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
	var chapter_order := str(entry.get("sort_order", "")).strip_edges()
	title.text = "%s%s" % [
		"第 %s 章 · " % chapter_order if not chapter_order.is_empty() else "",
		str(entry.get("chapter_name", "章节")),
	]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var desc := Label.new()
	var desc_text := str(entry.get("chapter_desc", "")).strip_edges()
	if desc_text.is_empty():
		desc_text = "这一章已经可以推进，点开后就能看到可挑战的关卡。"
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
	button.text = "查看本章关卡" if not is_selected else "当前章节已展开"
	button.pressed.connect(func() -> void:
		_selected_chapter_id = chapter_id
		_rebuild_chapter_cards()
		set_page_state("loading", "已展开 %s，正在同步这一章的关卡。" % str(entry.get("chapter_name", "章节")))
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
	var stage_order := str(entry.get("stage_order", "")).strip_edges()
	title.text = "%s%s" % [
		"第 %s 关 · " % stage_order if not stage_order.is_empty() else "",
		str(entry.get("stage_name", "关卡")),
	]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "点开后会展开当前关卡的难度列表。%s" % (
		"当前正在查看这一关。" if is_selected else "选中后会同步到当前目标。"
	)
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
	button.text = "查看这一关的难度"
	button.pressed.connect(func() -> void:
		set_stage_id(stage_id)
		_emit_context("stage_id_changed", {"stage_id": stage_id})
		set_page_state("loading", "已选中 %s，正在展开这一关的难度。" % str(entry.get("stage_name", "关卡")))
		_emit_action("stage_selected", entry)
	)
	box.add_child(button)

	return card


func _rebuild_difficulty_cards() -> void:
	clear_container(difficulty_cards_box)

	var difficulties: Array = _difficulties_payload.get("difficulties", []) if typeof(_difficulties_payload.get("difficulties", [])) == TYPE_ARRAY else []
	_selected_stage_difficulty_id = _resolve_preferred_identifier(
		difficulties,
		"stage_difficulty_id",
		[_selected_stage_difficulty_id]
	)

	for difficulty in difficulties:
		var entry: Dictionary = difficulty if typeof(difficulty) == TYPE_DICTIONARY else {}
		var stage_difficulty_id := str(entry.get("stage_difficulty_id", "")).strip_edges()
		if stage_difficulty_id.is_empty():
			continue
		difficulty_cards_box.add_child(_build_difficulty_card(entry))

	if difficulty_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "先点一个关卡，就能看到可选难度。"
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
	meta.text = "选中后会同步首通奖励状态，并把当前目标带去出战确认。"
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
	var chapter_name := str(chapter.get("chapter_name", "可推进章节"))
	var stage_name := str(stage.get("stage_name", "请先选一关"))
	var difficulty_name := str(difficulty.get("difficulty_name", "请先选难度"))

	route_title_label.text = "%s / %s / %s" % [
		chapter_name,
		stage_name,
		difficulty_name,
	]

	var recommended_power := str(difficulty.get("recommended_power", "-"))
	var route_hint := "先展开一个章节，系统会自动把关卡铺开。"
	if not str(chapter.get("chapter_id", "")).is_empty() and str(stage.get("stage_id", "")).is_empty():
		route_hint = "当前章节已经展开，点一关就会出现难度区。"
	elif not str(stage.get("stage_id", "")).is_empty() and str(difficulty.get("stage_difficulty_id", "")).is_empty():
		route_hint = "这一关已经锁定，正在等待你选择难度。"
	elif not str(difficulty.get("stage_difficulty_id", "")).is_empty():
		route_hint = "当前目标已经锁定，推荐战力 %s，随时可以进入出战。" % recommended_power
	route_meta_label.text = route_hint
	reward_hint_label.text = _reward_status_text(_reward_status_payload)

	clear_container(route_tag_row)
	if not str(chapter.get("chapter_id", "")).is_empty():
		route_tag_row.add_child(create_pill("当前章节", CHAPTER_TINT))
	if not str(stage.get("stage_id", "")).is_empty():
		route_tag_row.add_child(create_pill("当前关卡", STAGE_TINT))
	if not str(difficulty.get("stage_difficulty_id", "")).is_empty():
		route_tag_row.add_child(create_pill("当前难度", DIFFICULTY_TINT))
		route_tag_row.add_child(create_pill("下一步可出战", DIFFICULTY_TINT))


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
		return "首通奖励：选中难度后会自动同步。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "首通奖励：当前难度没有首通奖励。"
	if int(reward_status.get("has_granted", 0)) == 1:
		return "首通奖励：已经领过，本轮不会重复获得。"
	return "首通奖励：本档难度还没领，通关后会在结果页正式回显。"


func _on_stage_override_toggled(pressed: bool) -> void:
	stage_override_box.visible = pressed


func _on_stage_id_changed(_text: String) -> void:
	_selected_stage_id = stage_id_input.text.strip_edges()
	_rebuild_stage_cards()
	_refresh_route_header()
	_emit_context("stage_id_changed", {"stage_id": get_stage_id_text()})


func _rebuild_chapter_cards() -> void:
	clear_container(chapter_cards_box)

	var chapters: Array = _chapters_payload.get("chapters", []) if typeof(_chapters_payload.get("chapters", [])) == TYPE_ARRAY else []
	for chapter in chapters:
		var entry: Dictionary = chapter if typeof(chapter) == TYPE_DICTIONARY else {}
		var chapter_id := str(entry.get("chapter_id", "")).strip_edges()
		if chapter_id.is_empty():
			continue
		chapter_cards_box.add_child(_build_chapter_card(entry))

	if chapter_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "山海路暂时还没有开放章节。"
		empty_label.modulate = CARD_TEXT_MUTED
		chapter_cards_box.add_child(empty_label)


func _rebuild_stage_cards() -> void:
	clear_container(stage_cards_box)

	var stages: Array = _stages_payload.get("stages", []) if typeof(_stages_payload.get("stages", [])) == TYPE_ARRAY else []
	for stage in stages:
		var entry: Dictionary = stage if typeof(stage) == TYPE_DICTIONARY else {}
		var stage_id := str(entry.get("stage_id", "")).strip_edges()
		if stage_id.is_empty():
			continue
		stage_cards_box.add_child(_build_stage_card(entry))

	if stage_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "这一章节暂时还没有可推进的关卡。"
		empty_label.modulate = CARD_TEXT_MUTED
		stage_cards_box.add_child(empty_label)


func _resolve_preferred_identifier(entries: Array, key: String, candidates: Array) -> String:
	for candidate in candidates:
		var normalized_candidate := str(candidate).strip_edges()
		if normalized_candidate.is_empty():
			continue
		for entry in entries:
			var item: Dictionary = entry if typeof(entry) == TYPE_DICTIONARY else {}
			if str(item.get(key, "")).strip_edges() == normalized_candidate:
				return normalized_candidate

	var first_entry := _first_payload_entry(entries)
	return str(first_entry.get(key, "")).strip_edges()

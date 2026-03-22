extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneStagePage

const CHAPTER_TINT := Color(0.52, 0.74, 0.98, 1.0)
const STAGE_TINT := Color(0.57, 0.86, 0.72, 1.0)
const DIFFICULTY_TINT := Color(0.97, 0.74, 0.40, 1.0)

var header_page_label: Label
var header_chapter_label: Label
var header_recommendation_label: Label
var header_tag_row: HBoxContainer

var chapter_desc_label: Label
var chapter_progress_label: Label
var chapter_cards_box: VBoxContainer

var stage_section_label: Label
var stage_cards_box: VBoxContainer

var difficulty_section_label: Label
var difficulty_cards_box: VBoxContainer

var reward_status_label: Label
var reward_detail_label: Label
var reward_tag_row: HBoxContainer

var target_summary_label: Label
var next_action_label: Label
var next_action_button: Button

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

	var header_card := add_card("这轮去哪里", "先认出这一章，再决定下一关打哪里。")
	header_page_label = Label.new()
	header_page_label.text = "当前去向"
	header_page_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(header_page_label)

	header_chapter_label = Label.new()
	header_chapter_label.add_theme_font_size_override("font_size", 24)
	header_card.add_child(header_chapter_label)

	header_recommendation_label = Label.new()
	header_recommendation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(header_recommendation_label)

	header_tag_row = HBoxContainer.new()
	header_tag_row.add_theme_constant_override("separation", 8)
	header_card.add_child(header_tag_row)

	var chapter_card := add_card("这一章", "当前章节的说明和推进节奏会在这里更新。")
	chapter_desc_label = Label.new()
	chapter_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_card.add_child(chapter_desc_label)

	chapter_progress_label = Label.new()
	chapter_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chapter_progress_label.modulate = CARD_TEXT_MUTED
	chapter_card.add_child(chapter_progress_label)

	chapter_cards_box = VBoxContainer.new()
	chapter_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_cards_box.add_theme_constant_override("separation", 10)
	chapter_card.add_child(chapter_cards_box)

	var stage_card := add_card("这一章能打什么", "这一章里能打的关卡会直接铺开在这里。")
	stage_section_label = Label.new()
	stage_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage_section_label.modulate = CARD_TEXT_MUTED
	stage_card.add_child(stage_section_label)

	stage_cards_box = VBoxContainer.new()
	stage_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_cards_box.add_theme_constant_override("separation", 10)
	stage_card.add_child(stage_cards_box)

	var difficulty_card := add_card("这一关打哪一档", "锁定关卡后，这里会直接出现可选难度。")
	difficulty_section_label = Label.new()
	difficulty_section_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_section_label.modulate = CARD_TEXT_MUTED
	difficulty_card.add_child(difficulty_section_label)

	difficulty_cards_box = VBoxContainer.new()
	difficulty_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_cards_box.add_theme_constant_override("separation", 10)
	difficulty_card.add_child(difficulty_cards_box)

	var action_card := add_card("出发前最后确认", "锁定章节、关卡和难度后，这里会直接给出出战入口。")
	target_summary_label = Label.new()
	target_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_summary_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(target_summary_label)

	next_action_label = Label.new()
	next_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(next_action_label)

	var action_buttons := add_button_row(action_card)
	next_action_button = add_action_button(action_buttons, "去出战", "navigate_prepare")
	style_primary_button(next_action_button)

	var reward_card := add_card("这一档奖励", "首通奖励状态会跟着当前难度一起刷新。")
	reward_status_label = Label.new()
	reward_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_card.add_child(reward_status_label)

	reward_detail_label = Label.new()
	reward_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_detail_label.modulate = CARD_TEXT_MUTED
	reward_card.add_child(reward_detail_label)

	reward_tag_row = HBoxContainer.new()
	reward_tag_row.add_theme_constant_override("separation", 8)
	reward_card.add_child(reward_tag_row)

	var tech_card := add_card("调试区", "手动刷新和技术字段都留在这里，不占首屏。")
	var tech_buttons := add_button_row(tech_card)
	add_action_button(tech_buttons, "刷新章节", "load_chapters")
	add_action_button(tech_buttons, "刷新本章", "load_stages")
	add_action_button(tech_buttons, "刷新难度", "load_difficulties")
	add_action_button(tech_buttons, "刷新奖励", "refresh_reward_status")

	stage_override_toggle = add_check_box("显示关卡编号输入", false, tech_card)
	stage_override_toggle.toggled.connect(_on_stage_override_toggled)

	stage_override_box = VBoxContainer.new()
	stage_override_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_override_box.visible = false
	tech_card.add_child(stage_override_box)

	stage_id_input = add_labeled_input("stage_id（调试）", "", stage_override_box)
	stage_id_input.text_changed.connect(_on_stage_id_changed)

	set_stage_summary(0, 0, 0, {})
	set_output_text("")
	_move_secondary_sections_to_bottom()


func apply_config(values: Dictionary) -> void:
	_selected_chapter_id = str(values.get("chapter_id", "")).strip_edges()
	_selected_stage_id = str(values.get("stage_id", "")).strip_edges()
	_selected_stage_difficulty_id = str(values.get("stage_difficulty_id", "")).strip_edges()
	stage_id_input.text = _selected_stage_id
	_refresh_stage_page()


func set_stage_id(stage_id: String) -> void:
	_selected_stage_id = stage_id.strip_edges()
	stage_id_input.text = _selected_stage_id
	_refresh_stage_page()


func get_stage_id_text() -> String:
	if not _selected_stage_id.is_empty():
		return _selected_stage_id
	return stage_id_input.text.strip_edges()


func get_selected_chapter_id() -> String:
	return _selected_chapter_id


func set_selected_chapter_id(chapter_id: String) -> void:
	_selected_chapter_id = chapter_id.strip_edges()
	_refresh_stage_page()


func set_selected_stage_difficulty(stage_difficulty_id: String) -> void:
	_selected_stage_difficulty_id = stage_difficulty_id.strip_edges()
	_refresh_stage_page()


func get_selected_stage_difficulty() -> String:
	return _selected_stage_difficulty_id


func render_chapters(payload: Dictionary, preferred_chapter_ids: Array = []) -> void:
	_chapters_payload = payload.duplicate(true)
	var chapters: Array = _as_dictionary_array(payload.get("chapters", []))
	_selected_chapter_id = _resolve_preferred_identifier(
		chapters,
		"chapter_id",
		preferred_chapter_ids
	)
	_refresh_stage_page()


func render_stages(payload: Dictionary, preferred_stage_ids: Array = []) -> void:
	_stages_payload = payload.duplicate(true)
	var stages: Array = _as_dictionary_array(payload.get("stages", []))
	_selected_stage_id = _resolve_preferred_identifier(
		stages,
		"stage_id",
		preferred_stage_ids
	)
	stage_id_input.text = _selected_stage_id
	_refresh_stage_page()


func render_difficulties(
	payload: Dictionary,
	reward_status: Dictionary,
	preferred_stage_difficulty_ids: Array = []
) -> void:
	_difficulties_payload = payload.duplicate(true)
	_reward_status_payload = reward_status.duplicate(true)
	_selected_stage_difficulty_id = _resolve_preferred_identifier(
		_as_dictionary_array(payload.get("difficulties", [])),
		"stage_difficulty_id",
		preferred_stage_difficulty_ids
	)
	_refresh_stage_page()
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
	_selected_stage_difficulty_id = _resolve_preferred_identifier(
		_as_dictionary_array(difficulties.get("difficulties", [])),
		"stage_difficulty_id",
		[_selected_stage_difficulty_id]
	)
	_refresh_stage_page()
	set_output_json({
		"chapters": chapters.get("chapters", []),
		"stages": stages.get("stages", []),
		"difficulties": difficulties.get("difficulties", []),
		"reward_status": reward_status,
	})


func set_stage_summary(chapter_count: int, stage_count: int, difficulty_count: int, reward_status: Dictionary) -> void:
	var summary := "主线已开放 %d 个章节，本章可挑战 %d 关，可选 %d 档难度。" % [
		chapter_count,
		stage_count,
		difficulty_count,
	]
	if chapter_count <= 0:
		summary = "山海路暂时还没有开放章节。"
	elif stage_count <= 0:
		summary = "当前章节已经锁定，但这一章暂时还没有可挑战关卡。"
	elif difficulty_count <= 0:
		summary = "当前章节和关卡已经锁定，下一步请选择难度。"
	elif _selected_stage_difficulty_id.is_empty():
		summary = "当前章节和关卡已经锁定，下一步请选择难度。"
	else:
		summary = "当前目标已经锁定，奖励状态也已同步，可以进入出战。"

	set_summary_text(summary)
	_reward_status_payload = reward_status.duplicate(true)
	_refresh_stage_page()


func _refresh_stage_page() -> void:
	_rebuild_chapter_cards()
	_rebuild_stage_cards()
	_rebuild_difficulty_cards()
	_refresh_header()
	_refresh_chapter_info()
	_refresh_reward_summary()
	_refresh_next_action()


func _rebuild_chapter_cards() -> void:
	clear_container(chapter_cards_box)

	var chapters: Array = _as_dictionary_array(_chapters_payload.get("chapters", []))
	for chapter in chapters:
		var chapter_id := str(chapter.get("chapter_id", "")).strip_edges()
		if chapter_id.is_empty():
			continue
		chapter_cards_box.add_child(_build_chapter_card(chapter))

	if chapter_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "山海路暂时还没有开放章节。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.modulate = CARD_TEXT_MUTED
		chapter_cards_box.add_child(empty_label)


func _rebuild_stage_cards() -> void:
	clear_container(stage_cards_box)

	var stages: Array = _as_dictionary_array(_stages_payload.get("stages", []))
	stage_section_label.text = _build_stage_section_text(stages.size())

	for stage in stages:
		var stage_id := str(stage.get("stage_id", "")).strip_edges()
		if stage_id.is_empty():
			continue
		stage_cards_box.add_child(_build_stage_card(stage))

	if stage_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = (
			"先锁定一个章节，就能看到这一章里的可挑战关卡。"
			if _selected_chapter_id.is_empty()
			else "这一章节暂时还没有可挑战关卡。"
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.modulate = CARD_TEXT_MUTED
		stage_cards_box.add_child(empty_label)


func _rebuild_difficulty_cards() -> void:
	clear_container(difficulty_cards_box)

	var difficulties: Array = _as_dictionary_array(_difficulties_payload.get("difficulties", []))
	difficulty_section_label.text = _build_difficulty_section_text(difficulties.size())

	for difficulty in difficulties:
		var stage_difficulty_id := str(difficulty.get("stage_difficulty_id", "")).strip_edges()
		if stage_difficulty_id.is_empty():
			continue
		difficulty_cards_box.add_child(_build_difficulty_card(difficulty))

	if difficulty_cards_box.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = (
			"先点一个关卡，这里就会展开可选难度。"
			if get_stage_id_text().is_empty()
			else "这一关暂时还没有开放难度。"
		)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.modulate = CARD_TEXT_MUTED
		difficulty_cards_box.add_child(empty_label)


func _build_chapter_card(entry: Dictionary) -> PanelContainer:
	var chapter_id := str(entry.get("chapter_id", ""))
	var is_selected := chapter_id == _selected_chapter_id
	var card := _build_route_card(_create_route_card_style(is_selected, CHAPTER_TINT))
	var box := _card_content_box(card)

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
		tags.add_child(create_pill("当前章节", STAGE_TINT))
	box.add_child(tags)

	var button := Button.new()
	button.text = "已在本章" if is_selected else "定下这一章"
	button.disabled = is_selected
	button.pressed.connect(func() -> void:
		_selected_chapter_id = chapter_id
		_refresh_stage_page()
		set_page_state("loading", "已切换到 %s，正在展开这一章的关卡。" % str(entry.get("chapter_name", "章节")))
		_emit_action("chapter_selected", {"chapter_id": chapter_id})
	)
	box.add_child(button)

	return card


func _build_stage_card(entry: Dictionary) -> PanelContainer:
	var stage_id := str(entry.get("stage_id", ""))
	var is_selected := stage_id == get_stage_id_text()
	var card := _build_route_card(_create_route_card_style(is_selected, STAGE_TINT))
	var box := _card_content_box(card)

	var title := Label.new()
	var stage_order := str(entry.get("stage_order", "")).strip_edges()
	title.text = "%s%s" % [
		"第 %s 关 · " % stage_order if not stage_order.is_empty() else "",
		str(entry.get("stage_name", "关卡")),
	]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "定下后会直接展开这一关的可选难度。"
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
	button.text = "已选这关" if is_selected else "定下这一关"
	button.disabled = is_selected
	button.pressed.connect(func() -> void:
		set_stage_id(stage_id)
		_emit_context("stage_id_changed", {"stage_id": stage_id})
		set_page_state("loading", "已锁定 %s，正在展开这一关的难度。" % str(entry.get("stage_name", "关卡")))
		_emit_action("stage_selected", entry)
	)
	box.add_child(button)

	return card


func _build_difficulty_card(entry: Dictionary) -> PanelContainer:
	var stage_difficulty_id := str(entry.get("stage_difficulty_id", ""))
	var reward_data := _as_dictionary(entry.get("first_clear_reward", {}))
	var is_selected := stage_difficulty_id == _selected_stage_difficulty_id
	var card := _build_route_card(_create_route_card_style(is_selected, DIFFICULTY_TINT))
	var box := _card_content_box(card)

	var title := Label.new()
	title.text = "%s · 推荐战力 %s" % [
		str(entry.get("difficulty_name", "难度")),
		str(entry.get("recommended_power", "-")),
	]
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = "定下后会同步奖励状态，并把当前目标带去出战页。"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = CARD_TEXT_MUTED
	box.add_child(meta)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill("难度 %s" % str(entry.get("difficulty_key", "")), DIFFICULTY_TINT))
	tags.add_child(create_pill(_difficulty_reward_tag(reward_data), STAGE_TINT if int(reward_data.get("has_reward", 0)) == 1 else CHAPTER_TINT))
	if is_selected:
		tags.add_child(create_pill("当前难度", DIFFICULTY_TINT))
	box.add_child(tags)

	var reward_label := Label.new()
	reward_label.text = _difficulty_reward_text(stage_difficulty_id, reward_data)
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.modulate = CARD_TEXT_MUTED
	box.add_child(reward_label)

	var button := Button.new()
	button.text = "已选这档" if is_selected else "定下这一档"
	button.disabled = is_selected
	button.pressed.connect(func() -> void:
		_selected_stage_difficulty_id = stage_difficulty_id
		_refresh_stage_page()
		_emit_action("difficulty_selected", entry)
	)
	box.add_child(button)

	return card


func _refresh_header() -> void:
	var chapter := _find_chapter(_selected_chapter_id)
	var stage := _find_stage(get_stage_id_text())
	var difficulty := _find_difficulty(_selected_stage_difficulty_id)
	var chapter_name := str(chapter.get("chapter_name", "山海路待开启"))

	header_chapter_label.text = chapter_name
	header_recommendation_label.text = _build_header_recommendation(chapter, stage, difficulty)

	clear_container(header_tag_row)
	if not str(chapter.get("chapter_id", "")).is_empty():
		header_tag_row.add_child(create_pill("当前章节", CHAPTER_TINT))
	if not str(stage.get("stage_id", "")).is_empty():
		header_tag_row.add_child(create_pill("当前关卡", STAGE_TINT))
	if not str(difficulty.get("stage_difficulty_id", "")).is_empty():
		header_tag_row.add_child(create_pill("当前难度", DIFFICULTY_TINT))
		header_tag_row.add_child(create_pill("可进入出战", DIFFICULTY_TINT))


func _refresh_chapter_info() -> void:
	var chapter := _find_chapter(_selected_chapter_id)
	var stage_count := _as_dictionary_array(_stages_payload.get("stages", [])).size()
	var difficulty_count := _as_dictionary_array(_difficulties_payload.get("difficulties", [])).size()

	if chapter.is_empty():
		chapter_desc_label.text = "章节锁定后，这里会展示当前章节说明。"
		chapter_progress_label.text = "进入主线后，会自动选中一个可用章节并展开关卡。"
		return

	var chapter_desc := str(chapter.get("chapter_desc", "")).strip_edges()
	if chapter_desc.is_empty():
		chapter_desc = "这一章已经开放，可以继续往下推进。"
	chapter_desc_label.text = chapter_desc

	var stage_name := str(_find_stage(get_stage_id_text()).get("stage_name", "")).strip_edges()
	if stage_count <= 0:
		chapter_progress_label.text = "当前进度：本章暂时还没有开放关卡。"
	elif stage_name.is_empty():
		chapter_progress_label.text = "当前进度：本章已展开，可挑战 %d 关；下一步请选择一关。" % stage_count
	elif difficulty_count <= 0:
		chapter_progress_label.text = "当前进度：已锁定 %s；下一步请选择难度。" % stage_name
	elif _selected_stage_difficulty_id.is_empty():
		chapter_progress_label.text = "当前进度：已锁定 %s；请选择难度后进入出战。" % stage_name
	else:
		chapter_progress_label.text = "当前进度：本章目标已锁定，可直接进入出战。"


func _refresh_reward_summary() -> void:
	reward_status_label.text = _reward_status_text(_reward_status_payload)
	reward_detail_label.text = _reward_detail_text()

	clear_container(reward_tag_row)
	var difficulty := _find_difficulty(_selected_stage_difficulty_id)
	if not difficulty.is_empty():
		reward_tag_row.add_child(create_pill(str(difficulty.get("difficulty_name", "当前难度")), DIFFICULTY_TINT))

	if _reward_status_payload.is_empty():
		reward_tag_row.add_child(create_pill("待同步", CHAPTER_TINT))
		return

	if int(_reward_status_payload.get("has_reward", 0)) == 0:
		reward_tag_row.add_child(create_pill("无首通奖励", CHAPTER_TINT))
	elif int(_reward_status_payload.get("has_granted", 0)) == 1:
		reward_tag_row.add_child(create_pill("首通已领取", STAGE_TINT))
	else:
		reward_tag_row.add_child(create_pill("首通待领取", STAGE_TINT))


func _refresh_next_action() -> void:
	var chapter := _find_chapter(_selected_chapter_id)
	var stage := _find_stage(get_stage_id_text())
	var difficulty := _find_difficulty(_selected_stage_difficulty_id)

	if chapter.is_empty():
		target_summary_label.text = "主线页会先帮你锁定一个可推进章节，再把这一章的关卡直接铺开。"
		next_action_label.text = "当前还没锁定章节，稍后会自动展开可推进内容。"
		next_action_button.disabled = true
		return

	if stage.is_empty():
		target_summary_label.text = "当前章节：%s。先从这一章里挑一关，难度区就会立刻展开。" % [
			str(chapter.get("chapter_name", "当前章节")),
		]
		next_action_label.text = "这一章已经展开，先选一关再决定挑战难度。"
		next_action_button.disabled = true
		return

	if difficulty.is_empty():
		target_summary_label.text = "当前目标：%s / %s。下一步从下方难度里选一档。" % [
			str(chapter.get("chapter_name", "当前章节")),
			str(stage.get("stage_name", "当前关卡")),
		]
		next_action_label.text = "这一关已经锁定，选好难度后就能直接进入出战。"
		next_action_button.disabled = true
		return

	target_summary_label.text = "当前目标：%s / %s / %s。" % [
		str(chapter.get("chapter_name", "当前章节")),
		str(stage.get("stage_name", "当前关卡")),
		str(difficulty.get("difficulty_name", "当前难度")),
	]
	next_action_label.text = "目标已经锁定，首通奖励状态也会跟着更新，现在可以直接进入出战。"
	next_action_button.disabled = false


func _build_header_recommendation(chapter: Dictionary, stage: Dictionary, difficulty: Dictionary) -> String:
	if chapter.is_empty():
		return "下一步：主线页会自动锁定一个可推进章节。"
	if stage.is_empty():
		return "下一步：先从 %s 里选一关。" % str(chapter.get("chapter_name", "当前章节"))
	if difficulty.is_empty():
		return "下一步：%s 已锁定，再选一档难度。" % str(stage.get("stage_name", "当前关卡"))
	return "下一步：%s，推荐战力 %s，可以前往出战。" % [
		str(difficulty.get("difficulty_name", "当前难度")),
		str(difficulty.get("recommended_power", "-")),
	]


func _build_stage_section_text(stage_count: int) -> String:
	if _selected_chapter_id.is_empty():
		return "章节锁定后，可挑战关卡会直接铺开。"
	if stage_count <= 0:
		return "当前章节暂时还没有开放关卡。"
	return "当前章节共有 %d 个可挑战关卡；点任意一关就会展开难度。" % stage_count


func _build_difficulty_section_text(difficulty_count: int) -> String:
	if get_stage_id_text().is_empty():
		return "先选一关，这里就会出现可选难度。"
	if difficulty_count <= 0:
		return "这一关暂时还没有开放难度。"
	return "当前关卡共有 %d 档难度；选好后就能进入出战。" % difficulty_count


func _difficulty_reward_text(stage_difficulty_id: String, reward_data: Dictionary) -> String:
	if stage_difficulty_id == _selected_stage_difficulty_id and not _reward_status_payload.is_empty():
		return _reward_status_text(_reward_status_payload)
	if int(reward_data.get("has_reward", 0)) == 0:
		return "当前难度没有首通奖励。"
	if int(reward_data.get("has_granted", 0)) == 1:
		return "这一档的首通奖励已经领过。"
	return "这一档还有首通奖励可领取。"


func _difficulty_reward_tag(reward_data: Dictionary) -> String:
	if int(reward_data.get("has_reward", 0)) == 0:
		return "无首通奖励"
	if int(reward_data.get("has_granted", 0)) == 1:
		return "首通已领取"
	return "首通待领取"


func _reward_detail_text() -> String:
	if _selected_stage_difficulty_id.is_empty():
		return "选中一个难度后，这里会显示当前奖励状态。"

	var difficulty := _find_difficulty(_selected_stage_difficulty_id)
	var difficulty_name := str(difficulty.get("difficulty_name", "当前难度"))
	if _reward_status_payload.is_empty():
		return "%s 已锁定，奖励状态会自动同步。" % difficulty_name
	return "%s 的奖励状态已经同步，可放心进入出战。" % difficulty_name


func _reward_status_text(reward_status: Dictionary) -> String:
	if reward_status.is_empty():
		return "请选择一个难度后查看当前奖励状态。"
	if int(reward_status.get("has_reward", 0)) == 0:
		return "当前难度没有首通奖励。"
	if int(reward_status.get("has_granted", 0)) == 1:
		return "当前难度的首通奖励已经领取过。"
	return "当前难度还有首通奖励待领取。"


func _find_chapter(chapter_id: String) -> Dictionary:
	for chapter in _as_dictionary_array(_chapters_payload.get("chapters", [])):
		if str(chapter.get("chapter_id", "")) == chapter_id:
			return chapter
	return {}


func _find_stage(stage_id: String) -> Dictionary:
	for stage in _as_dictionary_array(_stages_payload.get("stages", [])):
		if str(stage.get("stage_id", "")) == stage_id:
			return stage
	return {}


func _find_difficulty(stage_difficulty_id: String) -> Dictionary:
	for difficulty in _as_dictionary_array(_difficulties_payload.get("difficulties", [])):
		if str(difficulty.get("stage_difficulty_id", "")) == stage_difficulty_id:
			return difficulty
	return {}


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


func _first_payload_entry(entries: Variant) -> Dictionary:
	if typeof(entries) != TYPE_ARRAY or entries.is_empty():
		return {}
	var first_entry = entries[0]
	return first_entry if typeof(first_entry) == TYPE_DICTIONARY else {}


func _as_dictionary_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _build_route_card(style: StyleBoxFlat) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return card


func _card_content_box(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0).get_child(0)


func _create_route_card_style(is_selected: bool, tint: Color) -> StyleBoxFlat:
	var style := _create_card_style()
	if is_selected:
		style.border_color = tint
		style.bg_color = Color(0.12, 0.16, 0.24, 0.98)
	return style


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


func _on_stage_override_toggled(pressed: bool) -> void:
	stage_override_box.visible = pressed


func _on_stage_id_changed(_text: String) -> void:
	_selected_stage_id = stage_id_input.text.strip_edges()
	_refresh_stage_page()
	_emit_context("stage_id_changed", {"stage_id": get_stage_id_text()})

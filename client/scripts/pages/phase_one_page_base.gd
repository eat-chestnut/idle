extends ScrollContainer
class_name PhaseOnePageBase

const ClientConfigStoreScript = preload("res://client/scripts/client_config_store.gd")

signal action_requested(action: String, payload: Dictionary)
signal context_changed(context: String, payload: Dictionary)

const STATUS_COLORS := {
	"empty": Color(0.72, 0.74, 0.79),
	"loading": Color(0.94, 0.79, 0.35),
	"preparing": Color(0.94, 0.79, 0.35),
	"settling": Color(0.94, 0.79, 0.35),
	"success": Color(0.42, 0.83, 0.58),
	"error": Color(0.97, 0.52, 0.52),
	"unauthorized": Color(0.97, 0.66, 0.36),
}
const STATUS_LABELS := {
	"empty": "待推进",
	"loading": "同步中",
	"preparing": "整备中",
	"settling": "收束中",
	"success": "已就位",
	"error": "需调整",
	"unauthorized": "需重连",
}
const STATUS_TITLES := {
	"empty": "这一步还没开始",
	"loading": "正在把这一页补齐",
	"preparing": "正在为这一场做准备",
	"settling": "正在收回这一场的结果",
	"success": "这一步已经准备好了",
	"error": "这一步还没完成",
	"unauthorized": "需要重新连上后端",
}
const STATUS_HINTS := {
	"empty": "",
	"loading": "",
	"preparing": "",
	"settling": "",
	"success": "",
	"error": "保持当前选择，补齐这一步后再试一次。",
	"unauthorized": "回到“环境”页重新确认地址和 Bearer Token。",
}

const CARD_BACKGROUND := Color(0.09, 0.12, 0.18, 0.96)
const CARD_BORDER := Color(0.22, 0.29, 0.42, 1.0)
const CARD_TEXT_MUTED := Color(0.68, 0.73, 0.81, 1.0)
const BODY_TEXT := Color(0.93, 0.95, 0.98, 1.0)
const PRIMARY_BUTTON_TINT := Color(0.97, 0.74, 0.40, 1.0)

var _shell: VBoxContainer
var _body: VBoxContainer
var _state_badge_row: HBoxContainer
var _state_title_label: Label
var _state_label: Label
var _state_hint_label: Label
var _summary_label: Label
var _output_box: TextEdit
var _output_toggle: Button
var _built := false


func setup_page(tab_title: String, hints: Array[String]) -> void:
	if _built:
		return

	_built = true
	name = tab_title
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true

	var page_margin := MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_left", 2)
	page_margin.add_theme_constant_override("margin_top", 2)
	page_margin.add_theme_constant_override("margin_right", 2)
	page_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(page_margin)

	_shell = VBoxContainer.new()
	_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_theme_constant_override("separation", 10)
	page_margin.add_child(_shell)

	if not hints.is_empty():
		var intro_card := add_card("本页说明", "")
		for hint in hints:
			add_note(hint, intro_card)

	var status_panel := PanelContainer.new()
	status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_panel.add_theme_stylebox_override("panel", _create_card_style())
	_shell.add_child(status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 12)
	status_margin.add_theme_constant_override("margin_top", 8)
	status_margin.add_theme_constant_override("margin_right", 12)
	status_margin.add_theme_constant_override("margin_bottom", 8)
	status_panel.add_child(status_margin)

	var status_card := VBoxContainer.new()
	status_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_card.add_theme_constant_override("separation", 4)
	status_margin.add_child(status_card)

	var status_head := HBoxContainer.new()
	status_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_head.add_theme_constant_override("separation", 6)
	status_card.add_child(status_head)

	_state_badge_row = HBoxContainer.new()
	_state_badge_row.add_theme_constant_override("separation", 8)
	status_head.add_child(_state_badge_row)

	_state_title_label = Label.new()
	_state_title_label.add_theme_font_size_override("font_size", 14)
	_state_title_label.modulate = BODY_TEXT
	status_head.add_child(_state_title_label)

	_state_label = Label.new()
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_label.modulate = BODY_TEXT
	status_card.add_child(_state_label)

	_state_hint_label = Label.new()
	_state_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_hint_label.modulate = CARD_TEXT_MUTED
	_state_hint_label.visible = false
	status_card.add_child(_state_hint_label)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.modulate = CARD_TEXT_MUTED
	_summary_label.visible = false
	status_card.add_child(_summary_label)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	_shell.add_child(_body)

	var output_card := add_card("技术详情", "原始字段留在这里，需要时再展开。")
	_output_toggle = Button.new()
	_output_toggle.toggle_mode = true
	_output_toggle.text = "展开技术详情"
	_output_toggle.pressed.connect(_on_output_toggle_pressed)
	output_card.add_child(_output_toggle)

	_output_box = TextEdit.new()
	_output_box.editable = false
	_output_box.visible = false
	_output_box.custom_minimum_size = Vector2(0, 220)
	_output_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_card.add_child(_output_box)


func get_body() -> VBoxContainer:
	return _body


func add_card(title: String = "", subtitle: String = "", parent: Control = null) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_card_style())
	_resolve_parent(parent).add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	if not title.strip_edges().is_empty():
		var title_label := Label.new()
		title_label.text = title
		title_label.modulate = BODY_TEXT
		title_label.add_theme_font_size_override("font_size", 18)
		body.add_child(title_label)

	if not subtitle.strip_edges().is_empty():
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle_label.modulate = CARD_TEXT_MUTED
		body.add_child(subtitle_label)

	return body


func add_note(text: String, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = "• %s" % text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = CARD_TEXT_MUTED
	_resolve_parent(parent).add_child(label)
	return label


func add_section_title(text: String, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = BODY_TEXT
	_resolve_parent(parent).add_child(label)
	return label


func add_separator(parent: Control = null) -> HSeparator:
	var separator := HSeparator.new()
	_resolve_parent(parent).add_child(separator)
	return separator


func add_labeled_input(label_text: String, default_value: String = "", parent: Control = null) -> LineEdit:
	var input := LineEdit.new()
	input.text = default_value
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = label_text
	_resolve_parent(parent).add_child(_wrap_labeled_control(label_text, input))
	return input


func add_labeled_option_button(label_text: String, parent: Control = null) -> OptionButton:
	var button := OptionButton.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resolve_parent(parent).add_child(_wrap_labeled_control(label_text, button))
	return button


func add_labeled_item_list(
	label_text: String,
	min_height: float = 160.0,
	parent: Control = null
) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, min_height)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_resolve_parent(parent).add_child(_wrap_labeled_control(label_text, list))
	return list


func add_check_box(text: String, pressed: bool = false, parent: Control = null) -> CheckBox:
	var checkbox := CheckBox.new()
	checkbox.text = text
	checkbox.button_pressed = pressed
	_resolve_parent(parent).add_child(checkbox)
	return checkbox


func add_button_row(parent: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 8)
	_resolve_parent(parent).add_child(row)
	return row


func add_action_button(parent: Control, text: String, action: String, payload: Dictionary = {}) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		_emit_action(action, payload)
	)
	parent.add_child(button)
	return button


func add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func style_primary_button(button: Button, tint: Color = PRIMARY_BUTTON_TINT) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint.r, tint.g, tint.b, 0.92)
	normal.border_color = tint.lightened(0.12)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_right = 16
	normal.corner_radius_bottom_left = 16

	var hover := normal.duplicate()
	hover.bg_color = tint.lightened(0.08)

	var pressed := normal.duplicate()
	pressed.bg_color = tint.darkened(0.12)

	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 46)
	button.modulate = BODY_TEXT
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)


func replace_options(
	button: OptionButton,
	options: Array,
	empty_label: String,
	selected_value: Variant = null
) -> void:
	button.clear()

	if options.is_empty():
		button.add_item(empty_label)
		button.set_item_metadata(0, {})
		button.disabled = true
		button.select(0)
		return

	button.disabled = false

	for option in options:
		var entry = option if typeof(option) == TYPE_DICTIONARY else {}
		var index = button.item_count
		button.add_item(str(entry.get("label", entry.get("value", ""))))
		button.set_item_metadata(index, entry)

	var selected_index := 0
	if selected_value != null:
		for index in range(button.item_count):
			var metadata: Dictionary = _as_dictionary(button.get_item_metadata(index))
			if str(metadata.get("value", "")) == str(selected_value):
				selected_index = index
				break

	button.select(selected_index)


func get_selected_option(button: OptionButton) -> Dictionary:
	var index := button.get_selected_id()
	if index < 0 or index >= button.item_count:
		return {}

	return _as_dictionary(button.get_item_metadata(index))


func select_option_by_value(button: OptionButton, selected_value: Variant) -> bool:
	for index in range(button.item_count):
		var metadata: Dictionary = _as_dictionary(button.get_item_metadata(index))
		if str(metadata.get("value", "")) == str(selected_value):
			button.select(index)
			return true

	return false


func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func create_pill(text: String, tint: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.18)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.65)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	pill.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	pill.add_child(margin)

	var label := Label.new()
	label.text = text
	label.modulate = tint.lightened(0.25)
	margin.add_child(label)
	return pill


func set_page_state(status: String, message: String, next_step: String = "") -> void:
	clear_container(_state_badge_row)
	_state_badge_row.add_child(create_pill(_status_label(status), STATUS_COLORS.get(status, BODY_TEXT)))
	_state_title_label.text = _status_title(status)
	_state_label.text = message
	_state_label.visible = not message.strip_edges().is_empty()

	var resolved_next_step := next_step.strip_edges()
	if resolved_next_step.is_empty() and (status == "error" or status == "unauthorized"):
		resolved_next_step = _status_hint(status)

	_state_hint_label.visible = not resolved_next_step.is_empty()
	_state_hint_label.text = "接下来：%s" % resolved_next_step


func set_summary_text(text: String) -> void:
	_summary_label.text = text
	_summary_label.visible = not text.strip_edges().is_empty()


func set_output_text(text: String) -> void:
	_output_box.text = text
	_output_toggle.visible = not text.strip_edges().is_empty()
	if text.strip_edges().is_empty():
		_output_box.visible = false
		_output_toggle.button_pressed = false
		_output_toggle.text = "展开技术详情"


func set_output_json(payload: Variant) -> void:
	set_output_text(JSON.stringify(payload, "  "))


func _emit_action(action: String, payload: Dictionary = {}) -> void:
	action_requested.emit(action, payload)


func _emit_context(context: String, payload: Dictionary = {}) -> void:
	context_changed.emit(context, payload)


func _resolve_parent(parent: Control) -> Control:
	if parent != null:
		return parent
	if _body != null:
		return _body
	if _shell != null:
		return _shell
	return self


func _wrap_labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = label_text
	label.modulate = CARD_TEXT_MUTED
	box.add_child(label)
	box.add_child(control)
	return box


func _create_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BACKGROUND
	style.border_color = CARD_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	return style


func _on_output_toggle_pressed() -> void:
	_output_box.visible = _output_toggle.button_pressed
	_output_toggle.text = "收起技术详情" if _output_toggle.button_pressed else "展开技术详情"


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func normalize_id_string(value: Variant) -> String:
	return ClientConfigStoreScript.normalize_id_string(value)


func _status_label(status: String) -> String:
	return str(STATUS_LABELS.get(status, "状态更新"))


func _status_title(status: String) -> String:
	return str(STATUS_TITLES.get(status, "页面状态已变化"))


func _status_hint(status: String) -> String:
	return str(STATUS_HINTS.get(status, ""))

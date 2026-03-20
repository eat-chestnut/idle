extends ScrollContainer
class_name PhaseOnePageBase

signal action_requested(action: String, payload: Dictionary)
signal context_changed(context: String, payload: Dictionary)

const STATUS_COLORS := {
	"empty": Color(0.75, 0.75, 0.75),
	"loading": Color(0.95, 0.83, 0.40),
	"preparing": Color(0.95, 0.83, 0.40),
	"settling": Color(0.95, 0.83, 0.40),
	"success": Color(0.55, 0.85, 0.55),
	"error": Color(1.0, 0.62, 0.62),
	"unauthorized": Color(1.0, 0.75, 0.45),
}

var _shell: VBoxContainer
var _body: VBoxContainer
var _state_label: Label
var _summary_label: Label
var _output_box: TextEdit
var _built := false


func setup_page(tab_title: String, hints: Array[String]) -> void:
	if _built:
		return

	_built = true
	name = tab_title
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_shell = VBoxContainer.new()
	_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_theme_constant_override("separation", 10)
	add_child(_shell)

	for hint in hints:
		add_note(hint, _shell)

	_state_label = Label.new()
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shell.add_child(_state_label)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.visible = false
	_shell.add_child(_summary_label)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_shell.add_child(_body)

	_output_box = TextEdit.new()
	_output_box.editable = false
	_output_box.custom_minimum_size = Vector2(0, 260)
	_output_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(_output_box)


func get_body() -> VBoxContainer:
	return _body


func add_note(text: String, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resolve_parent(parent).add_child(label)
	return label


func add_section_title(text: String, parent: Control = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
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


func set_page_state(status: String, message: String) -> void:
	_state_label.text = "状态：%s\n%s" % [status, message]
	_state_label.modulate = STATUS_COLORS.get(status, Color.WHITE)


func set_summary_text(text: String) -> void:
	_summary_label.text = text
	_summary_label.visible = not text.strip_edges().is_empty()


func set_output_text(text: String) -> void:
	_output_box.text = text


func set_output_json(payload: Variant) -> void:
	set_output_text(JSON.stringify(payload, "  "))


func _emit_action(action: String, payload: Dictionary = {}) -> void:
	action_requested.emit(action, payload)


func _emit_context(context: String, payload: Dictionary = {}) -> void:
	context_changed.emit(context, payload)


func _resolve_parent(parent: Control) -> Control:
	return parent if parent != null else _body


func _wrap_labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = label_text
	box.add_child(label)
	box.add_child(control)
	return box


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}

extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneCharacterPage

var class_input: LineEdit
var name_input: LineEdit
var recent_character_selector: OptionButton
var character_id_input: LineEdit


func _init() -> void:
	setup_page(
		"角色",
		[
			"角色页负责创建角色、读取角色详情，并维护当前角色上下文。",
			"由于 backend 当前没有正式角色列表接口，这里的角色选择器只展示真实成功创建/读取过的最近记录。",
		]
	)

	add_section_title("创建角色")
	class_input = add_labeled_input("class_id", "class_jingang")
	name_input = add_labeled_input("character_name", "联调角色")

	var create_buttons := add_button_row()
	add_action_button(create_buttons, "创建角色", "create_character")

	add_separator()
	add_section_title("当前角色")
	recent_character_selector = add_labeled_option_button("最近联调角色（真实记录）")
	recent_character_selector.item_selected.connect(_on_recent_character_selected)
	character_id_input = add_labeled_input("character_id", "")
	character_id_input.text_changed.connect(_on_character_id_changed)

	var detail_buttons := add_button_row()
	add_action_button(detail_buttons, "读取角色详情", "load_character")
	add_action_button(detail_buttons, "同步当前角色到后续页面", "sync_current_character")


func apply_config(values: Dictionary) -> void:
	class_input.text = str(values.get("class_id", "class_jingang"))
	name_input.text = str(values.get("character_name", "联调角色"))
	character_id_input.text = str(values.get("character_id", "1001"))


func get_create_payload() -> Dictionary:
	return {
		"class_id": class_input.text.strip_edges(),
		"character_name": name_input.text.strip_edges(),
	}


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func set_character_id(character_id: String) -> void:
	character_id_input.text = character_id


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


func show_character_summary(character: Dictionary) -> void:
	if character.is_empty():
		set_summary_text("")
		return

	var active_text = "is_active=1" if int(character.get("is_active", 0)) == 1 else "is_active=0"
	set_summary_text(
		"当前角色：%s #%s | 职业：%s | 等级：%s | %s" % [
			str(character.get("character_name", "角色")),
			str(character.get("character_id", "")),
			str(character.get("class_name", character.get("class_id", ""))),
			str(character.get("level", "")),
			active_text,
		]
	)


func _on_recent_character_selected(_index: int) -> void:
	var selected = get_selected_option(recent_character_selector)
	var character_id = str(selected.get("value", ""))
	if character_id.is_empty():
		return

	character_id_input.text = character_id
	_emit_context("detail_character_changed", {"character_id": character_id})


func _on_character_id_changed(_text: String) -> void:
	_emit_context("detail_character_changed", {"character_id": get_character_id_text()})

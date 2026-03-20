extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneCharacterPage

var character_list: ItemList
var class_input: LineEdit
var name_input: LineEdit
var character_id_input: LineEdit


func _init() -> void:
	setup_page(
		"角色与激活",
		[
			"主流程从真实角色列表开始：选择角色、查看详情，再决定是否切换当前启用角色。",
			"battle 可战斗资格以后端 `is_active` 为准；若需要切换当前启用角色，请走真实激活接口。",
		]
	)

	add_section_title("当前用户角色")
	var list_buttons := add_button_row()
	add_action_button(list_buttons, "刷新角色列表", "load_characters")
	character_list = add_labeled_item_list("真实角色列表", 140)
	character_list.item_selected.connect(_on_character_selected)

	add_separator()
	add_section_title("创建角色")
	class_input = add_labeled_input("class_id", "class_jingang")
	name_input = add_labeled_input("character_name", "联调角色")

	var create_buttons := add_button_row()
	add_action_button(create_buttons, "创建角色", "create_character")

	add_separator()
	add_section_title("当前角色")
	character_id_input = add_labeled_input("character_id", "")
	character_id_input.text_changed.connect(_on_character_id_changed)

	var detail_buttons := add_button_row()
	add_action_button(detail_buttons, "查看角色详情", "load_character")
	add_action_button(detail_buttons, "设为当前出战角色", "activate_current_character")
	add_action_button(detail_buttons, "同步到背包与主线", "sync_current_character")


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


func set_character_list(records: Array, current_character_id: String) -> String:
	character_list.clear()

	var selected_character_id := current_character_id
	var active_character_id := ""
	var selected_index := -1

	for character in records:
		var entry = character if typeof(character) == TYPE_DICTIONARY else {}
		var character_id = str(entry.get("character_id", ""))
		if character_id.is_empty():
			continue

		var label = "%s #%s | %s" % [
			str(entry.get("character_name", "角色")),
			character_id,
			str(entry.get("class_name", entry.get("class_id", ""))),
		]
		if int(entry.get("is_active", 0)) == 1:
			label += " [当前启用]"
			active_character_id = character_id
		else:
			label += " [未启用]"

		character_list.add_item(label)
		var item_index := character_list.item_count - 1
		character_list.set_item_metadata(item_index, entry)
		if character_id == selected_character_id:
			selected_index = item_index

	if selected_character_id.is_empty() and character_list.item_count > 0:
		if not active_character_id.is_empty():
			selected_character_id = active_character_id
		else:
			var first_entry = character_list.get_item_metadata(0)
			if typeof(first_entry) == TYPE_DICTIONARY:
				selected_character_id = str(first_entry.get("character_id", ""))

	if selected_index < 0 and not selected_character_id.is_empty():
		for index in range(character_list.item_count):
			var metadata = character_list.get_item_metadata(index)
			if typeof(metadata) != TYPE_DICTIONARY:
				continue
			if str(metadata.get("character_id", "")) == selected_character_id:
				selected_index = index
				break

	if selected_index < 0 and not active_character_id.is_empty():
		for index in range(character_list.item_count):
			var metadata = character_list.get_item_metadata(index)
			if typeof(metadata) != TYPE_DICTIONARY:
				continue
			if str(metadata.get("character_id", "")) == active_character_id:
				selected_index = index
				selected_character_id = active_character_id
				break

	if selected_index < 0 and character_list.item_count > 0:
		selected_index = 0
		var selected_entry = character_list.get_item_metadata(0)
		if typeof(selected_entry) == TYPE_DICTIONARY:
			selected_character_id = str(selected_entry.get("character_id", ""))

	if selected_index >= 0:
		character_list.select(selected_index)

	if not selected_character_id.is_empty():
		character_id_input.text = selected_character_id

	return active_character_id


func render_character_list(payload: Dictionary, current_character_id: String) -> void:
	var active_character_id := set_character_list(payload.get("characters", []), current_character_id)

	set_summary_text("characters=%d | 当前启用角色=%s" % [
		character_list.item_count,
		active_character_id if not active_character_id.is_empty() else "(无)",
	])
	set_output_json(payload)


func show_character_list_empty() -> void:
	set_character_list([], character_id_input.text)
	set_summary_text("characters=0 | 当前没有角色，请先创建。")
	set_output_json({"characters": []})


func set_recent_characters(records: Array, current_character_id: String) -> void:
	render_character_list({"characters": records}, current_character_id)


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


func _on_character_selected(index: int) -> void:
	var metadata = character_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	var character_id = str(metadata.get("character_id", ""))
	if character_id.is_empty():
		return

	character_id_input.text = character_id
	_emit_context("detail_character_changed", {"character_id": character_id})


func _on_character_id_changed(_text: String) -> void:
	_emit_context("detail_character_changed", {"character_id": get_character_id_text()})

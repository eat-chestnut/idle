extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneEquipmentPage

var recent_character_selector: OptionButton
var character_id_input: LineEdit
var slot_list: ItemList
var target_slot_selector: OptionButton
var equipment_instance_input: LineEdit
var handoff_label: Label
var equip_button: Button


func _init() -> void:
	setup_page(
		"穿戴",
		[
			"穿戴页直接承接真实装备槽接口，不额外发明本地穿戴规则。",
			"客户端只带当前装备和目标槽位，槽位兼容仍以服务端结果为准。",
		]
	)

	recent_character_selector = add_labeled_option_button("当前角色 / 真实角色列表")
	recent_character_selector.item_selected.connect(_on_recent_character_selected)
	character_id_input = add_labeled_input("当前角色编号", "")
	character_id_input.text_changed.connect(_on_character_id_changed)

	var handoff_card := add_card("穿戴承接", "从背包或结算页来到这里时，会继续保留当前角色和装备上下文。")
	handoff_label = Label.new()
	handoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	handoff_label.modulate = CARD_TEXT_MUTED
	handoff_card.add_child(handoff_label)

	var handoff_buttons := add_button_row(handoff_card)
	add_action_button(handoff_buttons, "回背包", "navigate_inventory")
	add_action_button(handoff_buttons, "回角色看成长", "navigate_character")
	add_action_button(handoff_buttons, "继续主线", "navigate_stage")

	var read_buttons := add_button_row()
	add_action_button(read_buttons, "刷新穿戴槽", "load_slots")

	slot_list = add_labeled_item_list("当前槽位快照", 180)
	slot_list.item_selected.connect(_on_slot_selected)
	target_slot_selector = add_labeled_option_button("目标槽位")
	replace_options(target_slot_selector, [], "请先刷新穿戴槽")

	equipment_instance_input = add_labeled_input("装备实例编号", "")

	var action_buttons := add_button_row()
	equip_button = add_action_button(action_buttons, "穿上所选装备", "equip")
	style_primary_button(equip_button)
	add_action_button(action_buttons, "卸下当前槽位", "unequip")

	show_handoff_summary("刷新穿戴槽后，可以把背包或结算页带来的装备直接试穿到当前角色身上。")


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func set_character_id(character_id: String) -> void:
	character_id_input.text = normalize_id_string(character_id)


func set_recent_characters(records: Array, current_character_id: String) -> void:
	var options: Array = []
	for record in records:
		var entry = record if typeof(record) == TYPE_DICTIONARY else {}
		var character_id = normalize_id_string(entry.get("character_id", ""))
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


func set_selected_equipment_instance(equipment_instance_id: String, equipment_name: String = "") -> void:
	equipment_instance_input.text = normalize_id_string(equipment_instance_id)
	if equipment_name.is_empty():
		set_summary_text("待穿戴装备实例 #%s" % equipment_instance_input.text)
		show_handoff_summary("已带入装备实例 #%s；刷新穿戴槽后即可试穿。" % equipment_instance_input.text)
	else:
		set_summary_text("待穿戴装备：%s #%s" % [equipment_name, equipment_instance_input.text])
		show_handoff_summary("已带入 %s；刷新穿戴槽后即可试穿到当前角色。" % equipment_name)


func render_slots(payload: Dictionary) -> void:
	slot_list.clear()

	var slot_options: Array = []
	var filled_slots := 0
	for slot in payload.get("slots", []):
		var entry = slot if typeof(slot) == TYPE_DICTIONARY else {}
		var slot_key = str(entry.get("slot_key", ""))
		var equipment = entry.get("equipment", {})
		var equipment_name = "空"
		if typeof(equipment) == TYPE_DICTIONARY and not equipment.is_empty():
			equipment_name = str(equipment.get("item_name", ""))
			filled_slots += 1

		slot_list.add_item("%s -> %s" % [slot_key, equipment_name])
		slot_list.set_item_metadata(slot_list.item_count - 1, entry)
		slot_options.append({
			"label": slot_key,
			"value": slot_key,
		})

	replace_options(target_slot_selector, slot_options, "请先刷新穿戴槽")
	set_summary_text("穿戴总览：角色 #%s | 槽位 %d | 已穿戴 %d" % [
		normalize_id_string(payload.get("character_id", "")),
		slot_list.item_count,
		filled_slots,
	])
	set_output_json(payload)


func show_handoff_summary(text: String) -> void:
	handoff_label.text = text


func get_target_slot_key() -> String:
	var selected = get_selected_option(target_slot_selector)
	return str(selected.get("value", ""))


func get_equipment_instance_id_text() -> String:
	return equipment_instance_input.text.strip_edges()


func _on_recent_character_selected(_index: int) -> void:
	var selected = get_selected_option(recent_character_selector)
	var character_id = normalize_id_string(selected.get("value", ""))
	if character_id.is_empty():
		return

	character_id_input.text = character_id
	_emit_context("detail_character_changed", {"character_id": character_id})


func _on_character_id_changed(_text: String) -> void:
	_emit_context("detail_character_changed", {"character_id": get_character_id_text()})


func _on_slot_selected(index: int) -> void:
	var metadata = slot_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	select_option_by_value(target_slot_selector, str(metadata.get("slot_key", "")))

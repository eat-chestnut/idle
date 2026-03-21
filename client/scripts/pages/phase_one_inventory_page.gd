extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneInventoryPage

var tab_selector: OptionButton
var stack_item_list: ItemList
var equipment_item_list: ItemList
var handoff_label: Label


func _init() -> void:
	setup_page(
		"背包",
		[
			"背包页会承接最近一次结算收益，也能把装备实例直接带到穿戴页。",
		]
	)

	tab_selector = add_labeled_option_button("tab")
	replace_options(
		tab_selector,
		[
			{"label": "全部", "value": "all"},
			{"label": "仅堆叠物", "value": "stack"},
			{"label": "仅装备实例", "value": "equipment"},
		],
		"暂无选项",
		"all"
	)

	var buttons := add_button_row()
	add_action_button(buttons, "读取背包", "load_inventory")

	var handoff_card := add_card("背包承接", "打完一场后通常先看这里，再决定去穿戴、回角色还是继续主线。")
	handoff_label = Label.new()
	handoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	handoff_label.modulate = CARD_TEXT_MUTED
	handoff_card.add_child(handoff_label)

	var handoff_buttons := add_button_row(handoff_card)
	add_action_button(handoff_buttons, "去穿戴", "navigate_equipment")
	add_action_button(handoff_buttons, "回角色看成长", "navigate_character")
	add_action_button(handoff_buttons, "继续主线", "navigate_stage")

	stack_item_list = add_labeled_item_list("堆叠物摘要", 120)
	equipment_item_list = add_labeled_item_list("装备实例", 180)
	equipment_item_list.item_selected.connect(_on_equipment_selected)

	show_handoff_summary("背包会承接最近一次结算收益；如果想继续成长，通常是先看装备实例，再去穿戴。")


func get_selected_tab() -> String:
	var selected = get_selected_option(tab_selector)
	return str(selected.get("value", "all"))


func render_inventory(payload: Dictionary) -> void:
	stack_item_list.clear()
	equipment_item_list.clear()

	var stack_count := 0
	for item in payload.get("stack_items", []):
		var entry = item if typeof(item) == TYPE_DICTIONARY else {}
		stack_count += 1
		var label = "%s x%s [%s]" % [
			str(entry.get("item_name", "")),
			str(entry.get("quantity", "")),
			str(entry.get("item_id", "")),
		]
		stack_item_list.add_item(label)
		stack_item_list.set_item_metadata(stack_item_list.item_count - 1, entry)

	var equipment_count := 0
	for item in payload.get("equipment_items", []):
		var entry = item if typeof(item) == TYPE_DICTIONARY else {}
		equipment_count += 1
		var label = "%s #%s [%s]" % [
			str(entry.get("item_name", "")),
			normalize_id_string(entry.get("equipment_instance_id", "")),
			str(entry.get("equipment_slot", "")),
		]
		equipment_item_list.add_item(label)
		equipment_item_list.set_item_metadata(equipment_item_list.item_count - 1, entry)

	set_summary_text("背包总览：堆叠物 %d | 装备实例 %d" % [stack_count, equipment_count])
	set_output_json(payload)


func show_handoff_summary(text: String) -> void:
	handoff_label.text = text


func _on_equipment_selected(index: int) -> void:
	var metadata = equipment_item_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	_emit_action("inventory_equipment_selected", metadata)

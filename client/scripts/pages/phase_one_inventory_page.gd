extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneInventoryPage

var tab_selector: OptionButton
var stack_item_list: ItemList
var equipment_item_list: ItemList


func _init() -> void:
	setup_page(
		"背包",
		[
			"背包页真实接 GET /api/inventory，并把装备实例选择带到穿戴页。",
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

	stack_item_list = add_labeled_item_list("堆叠物摘要", 120)
	equipment_item_list = add_labeled_item_list("装备实例", 180)
	equipment_item_list.item_selected.connect(_on_equipment_selected)


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
			str(entry.get("equipment_instance_id", "")),
			str(entry.get("equipment_slot", "")),
		]
		equipment_item_list.add_item(label)
		equipment_item_list.set_item_metadata(equipment_item_list.item_count - 1, entry)

	set_summary_text("stack_items=%d | equipment_items=%d" % [stack_count, equipment_count])
	set_output_json(payload)


func _on_equipment_selected(index: int) -> void:
	var metadata = equipment_item_list.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	_emit_action("inventory_equipment_selected", metadata)

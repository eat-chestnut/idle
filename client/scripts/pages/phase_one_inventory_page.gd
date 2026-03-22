extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneInventoryPage

const CHARACTER_TINT := Color(0.56, 0.82, 0.96, 1.0)
const EQUIPMENT_TINT := Color(0.98, 0.77, 0.44, 1.0)
const MATERIAL_TINT := Color(0.58, 0.88, 0.66, 1.0)
const OTHER_TINT := Color(0.76, 0.70, 0.96, 1.0)

var header_character_label: Label
var header_status_label: Label
var header_gain_label: Label
var header_tag_row: HBoxContainer

var focus_title_label: Label
var focus_hint_label: Label
var focus_box: VBoxContainer

var section_summary_label: Label
var all_section_button: Button
var equipment_section_button: Button
var material_section_button: Button
var other_section_button: Button
var load_button: Button

var list_hint_label: Label
var inventory_rows_box: VBoxContainer

var action_status_label: Label
var handoff_label: Label
var action_route_label: Label
var equipment_entry_button: Button
var character_entry_button: Button
var stage_entry_button: Button

var _selected_section := "all"
var _current_inventory: Dictionary = {}
var _current_character: Dictionary = {}
var _current_settle_result: Dictionary = {}
var _handoff_text := ""


func _init() -> void:
	setup_page("背包", [])

	var header_card := add_card("这一包收获", "")
	header_character_label = Label.new()
	header_character_label.add_theme_font_size_override("font_size", 24)
	header_card.add_child(header_character_label)

	header_status_label = Label.new()
	header_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(header_status_label)

	header_gain_label = Label.new()
	header_gain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_gain_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(header_gain_label)

	header_tag_row = HBoxContainer.new()
	header_tag_row.add_theme_constant_override("separation", 8)
	header_card.add_child(header_tag_row)

	var focus_card := add_card("本轮焦点", "")
	focus_title_label = Label.new()
	focus_title_label.add_theme_font_size_override("font_size", 22)
	focus_card.add_child(focus_title_label)

	focus_hint_label = Label.new()
	focus_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	focus_hint_label.modulate = CARD_TEXT_MUTED
	focus_card.add_child(focus_hint_label)

	focus_box = VBoxContainer.new()
	focus_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_box.add_theme_constant_override("separation", 10)
	focus_card.add_child(focus_box)

	var section_card := add_card("按类型整理", "先拆开装备、材料、其他，再决定接下来去哪。")
	section_summary_label = Label.new()
	section_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section_card.add_child(section_summary_label)

	var section_buttons := add_button_row(section_card)
	all_section_button = add_button(section_buttons, "全部", func() -> void:
		_select_section("all")
	)
	equipment_section_button = add_button(section_buttons, "装备", func() -> void:
		_select_section("equipment")
	)
	material_section_button = add_button(section_buttons, "材料", func() -> void:
		_select_section("material")
	)
	other_section_button = add_button(section_buttons, "其他", func() -> void:
		_select_section("other")
	)

	var load_buttons := add_button_row(section_card)
	load_button = add_action_button(load_buttons, "刷新背包", "load_inventory")

	var list_card := add_card("当前背包", "")
	list_hint_label = Label.new()
	list_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_hint_label.modulate = CARD_TEXT_MUTED
	list_card.add_child(list_hint_label)

	inventory_rows_box = VBoxContainer.new()
	inventory_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_rows_box.add_theme_constant_override("separation", 10)
	list_card.add_child(inventory_rows_box)

	var action_card := add_card("整理后的下一步", "看完本轮收获后，可以顺着穿戴、角色、主线继续推进。")
	action_status_label = Label.new()
	action_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(action_status_label)

	handoff_label = Label.new()
	handoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	handoff_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(handoff_label)

	action_route_label = Label.new()
	action_route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_route_label.modulate = BODY_TEXT
	action_card.add_child(action_route_label)

	var action_buttons := add_button_row(action_card)
	equipment_entry_button = add_action_button(action_buttons, "去穿戴", "navigate_equipment")
	style_primary_button(equipment_entry_button)
	character_entry_button = add_action_button(action_buttons, "回角色看成长", "navigate_character")
	stage_entry_button = add_action_button(action_buttons, "返回主线继续推进", "navigate_stage")

	render_inventory_context({}, {})
	render_inventory({})
	show_handoff_summary("背包会接住最近一次收获；先看新装备和关键材料，再决定去穿戴、回角色还是继续主线。")
	_move_secondary_sections_to_bottom()


func get_selected_tab() -> String:
	return "all"


func render_inventory_context(character: Dictionary, settle_result: Dictionary) -> void:
	_current_character = character.duplicate(true)
	_current_settle_result = settle_result.duplicate(true)
	if not _current_settle_result.is_empty():
		_selected_section = _preferred_section()
	_refresh_inventory_page()


func render_inventory(payload: Dictionary) -> void:
	_current_inventory = payload.duplicate(true)
	_refresh_inventory_page()
	if payload.is_empty():
		set_output_text("")
	else:
		set_output_json(payload)


func show_handoff_summary(text: String) -> void:
	_handoff_text = text.strip_edges()
	_refresh_action_area()


func _refresh_inventory_page() -> void:
	_refresh_header()
	_refresh_focus_area()
	_refresh_section_area()
	_refresh_inventory_list()
	_refresh_action_area()


func _refresh_header() -> void:
	clear_container(header_tag_row)

	if _current_character.is_empty():
		header_character_label.text = "当前角色：待确认"
		header_status_label.text = "当前没有锁定角色摘要，仍然可以先整理这轮收益。"
		header_tag_row.add_child(create_pill("等待角色", CHARACTER_TINT))
	else:
		header_character_label.text = "当前角色：%s" % str(_current_character.get("character_name", "角色"))
		header_status_label.text = "%s | 等级 %s | %s" % [
			str(_current_character.get("class_name", _current_character.get("class_id", "当前职业待确认"))),
			str(_current_character.get("level", "1")),
			"当前启用" if int(_current_character.get("is_active", 0)) == 1 else "待启用",
		]
		header_tag_row.add_child(create_pill("当前角色", CHARACTER_TINT))
		header_tag_row.add_child(
			create_pill(
				"可继续推进" if int(_current_character.get("is_active", 0)) == 1 else "先看收益也可以",
				MATERIAL_TINT if int(_current_character.get("is_active", 0)) == 1 else OTHER_TINT
			)
		)

	header_gain_label.text = _build_recent_gain_summary()
	if _recent_equipment_rows().size() > 0:
		header_tag_row.add_child(create_pill("本轮有新装备", EQUIPMENT_TINT))
	if _recent_material_rows().size() > 0:
		header_tag_row.add_child(create_pill("本轮有关键材料", MATERIAL_TINT))
	if _recent_other_rows().size() > 0:
		header_tag_row.add_child(create_pill("本轮有其他收益", OTHER_TINT))
	var recent_entry_count := _recent_inventory_entry_count()
	if recent_entry_count > 0:
		header_tag_row.add_child(create_pill("本轮入包 %d" % recent_entry_count, MATERIAL_TINT))


func _refresh_focus_area() -> void:
	clear_container(focus_box)

	var recent_equipment := _recent_equipment_rows()
	var recent_materials := _recent_material_rows()
	var recent_others := _recent_other_rows()
	var visible_equipment := _filtered_rows(_combined_inventory_rows(), "equipment")

	if recent_equipment.size() > 0:
		focus_title_label.text = "先看新装备"
		focus_hint_label.text = "本轮最值得马上处理的是新装备；先认出哪件最想试穿，再决定回角色确认成长，还是继续主线推进。"
		focus_box.add_child(_build_focus_card(
			"新装备 %d 件" % recent_equipment.size(),
			_trimmed_row_titles(recent_equipment, 3, "已经进包，建议先点开其中一件再去穿戴页确认。"),
			EQUIPMENT_TINT
		))
		if recent_materials.size() > 0:
			focus_box.add_child(_build_focus_card(
				"关键材料 %d 种" % recent_materials.size(),
				_trimmed_row_titles(recent_materials, 2, "已经进入本轮收益整理范围。"),
				MATERIAL_TINT
			))
		if recent_others.size() > 0:
			focus_box.add_child(_build_focus_card(
				"其他新增收益 %d 种" % recent_others.size(),
				_trimmed_row_titles(recent_others, 2, "可以整理完后继续推进。"),
				OTHER_TINT
			))
		return

	if recent_materials.size() > 0 or recent_others.size() > 0:
		focus_title_label.text = "先把本轮收益认清楚"
		focus_hint_label.text = "没有新装备时，关键材料和其他新增收益会先顶出来，方便你判断这一关值不值得继续刷。"
		if recent_materials.size() > 0:
			focus_box.add_child(_build_focus_card(
				"关键材料 %d 种" % recent_materials.size(),
				_trimmed_row_titles(recent_materials, 3, "已经正式进包。"),
				MATERIAL_TINT
			))
		if recent_others.size() > 0:
			focus_box.add_child(_build_focus_card(
				"其他收益 %d 种" % recent_others.size(),
				_trimmed_row_titles(recent_others, 3, "已经正式进包。"),
				OTHER_TINT
			))
		return

	if visible_equipment.size() > 0:
		focus_title_label.text = "当前更适合先看装备区"
		focus_hint_label.text = "最近没有新的战斗收益时，装备区通常最容易接到穿戴和角色成长。"
		focus_box.add_child(_build_focus_card(
			"装备 %d 件" % visible_equipment.size(),
			_trimmed_row_titles(visible_equipment, 3, "可继续导向穿戴页。"),
			EQUIPMENT_TINT
		))
		return

	focus_title_label.text = "最近还没有新的收益焦点"
	focus_hint_label.text = "如果刚打完一场，回到这里后，本轮新增收益会优先出现在这块区域。"
	focus_box.add_child(_build_empty_label("现在没有特别需要优先处理的收益。"))


func _refresh_section_area() -> void:
	var rows := _combined_inventory_rows()
	var equipment_count := _filtered_rows(rows, "equipment").size()
	var material_count := _filtered_rows(rows, "material").size()
	var other_count := _filtered_rows(rows, "other").size()

	section_summary_label.text = "当前分区：%s。带“本轮新增”或“新装备”的物品会优先排在最前面。" % _section_name(_selected_section)

	_apply_section_button(all_section_button, "全部", "all", rows.size())
	_apply_section_button(equipment_section_button, "装备", "equipment", equipment_count)
	_apply_section_button(material_section_button, "材料", "material", material_count)
	_apply_section_button(other_section_button, "其他", "other", other_count)


func _refresh_inventory_list() -> void:
	clear_container(inventory_rows_box)

	var all_rows := _combined_inventory_rows()
	set_summary_text("当前背包：装备 %d | 材料 %d | 其他 %d" % [
		_filtered_rows(all_rows, "equipment").size(),
		_filtered_rows(all_rows, "material").size(),
		_filtered_rows(all_rows, "other").size(),
	])
	var rows := _filtered_rows(all_rows, _selected_section)
	if rows.is_empty():
		if all_rows.is_empty():
			list_hint_label.text = "当前背包还没有物品；继续推进后，这里会先承接本轮新增收益。"
			inventory_rows_box.add_child(_build_empty_label("当前背包还是空的。"))
		else:
			list_hint_label.text = "这个分区暂时没有物品，切到别的分区看看会更合适。"
			inventory_rows_box.add_child(_build_empty_label("当前分区还没有可展示的物品。"))
		return

	list_hint_label.text = "当前分区共有 %d 个条目；本轮新增和新装备已经优先排前。" % rows.size()
	for row in rows:
		inventory_rows_box.add_child(_build_inventory_row_card(_as_dictionary(row)))


func _refresh_action_area() -> void:
	var recent_equipment_count := _recent_equipment_rows().size()
	if recent_equipment_count > 0:
		action_status_label.text = "这轮新装备已经优先顶出来了，最自然的下一步是挑一件去穿戴试装。"
	elif not _combined_inventory_rows().is_empty():
		action_status_label.text = "背包已经整理成收益分区；接下来可以判断是继续刷这一关，还是带着收获回主线。"
	else:
		action_status_label.text = "背包还没有内容时，可以先回主线推进，或回角色页确认当前状态。"

	handoff_label.text = _handoff_text if not _handoff_text.is_empty() else "整理完这轮收益后，通常会先去穿戴看新装备，再决定回角色还是继续主线。"
	action_route_label.text = _build_action_route_text()
	equipment_entry_button.text = "去试这轮新装备" if recent_equipment_count > 0 else "去穿戴"
	character_entry_button.text = "回角色看成长"
	stage_entry_button.text = "回主线继续刷"


func _select_section(section: String) -> void:
	_selected_section = section
	_refresh_section_area()
	_refresh_inventory_list()


func _apply_section_button(button: Button, base_text: String, section: String, count: int) -> void:
	var is_selected := _selected_section == section
	button.text = "%s%s %d" % ["当前：" if is_selected else "", base_text, count]
	button.disabled = is_selected


func _combined_inventory_rows() -> Array:
	var rows: Array = []
	var recent_equipment_lookup := _recent_equipment_lookup()
	var recent_stack_lookup := _recent_stack_lookup()
	var seen_equipment := {}
	var seen_stack := {}

	for item in _as_array(_current_inventory.get("equipment_items", [])):
		var entry := _as_dictionary(item)
		var equipment_instance_id := normalize_id_string(entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty():
			continue
		seen_equipment[equipment_instance_id] = true
		rows.append(_build_equipment_row(entry, recent_equipment_lookup.has(equipment_instance_id), false))

	for item in _as_array(_current_inventory.get("stack_items", [])):
		var entry := _as_dictionary(item)
		var item_id := str(entry.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		seen_stack[item_id] = true
		rows.append(_build_stack_row(entry, recent_stack_lookup.has(item_id), false))

	for item in _as_array(_current_settle_result.get("created_equipment_instances", [])):
		var entry := _as_dictionary(item)
		var equipment_instance_id := normalize_id_string(entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty() or seen_equipment.has(equipment_instance_id):
			continue
		rows.append(_build_equipment_row(entry, true, true))

	var item_info_map := _settle_item_info_map()
	var settle_inventory_results := _as_dictionary(_current_settle_result.get("inventory_results", {}))
	for item in _as_array(settle_inventory_results.get("stack_results", [])):
		var entry := _as_dictionary(item).duplicate(true)
		var item_id := str(entry.get("item_id", "")).strip_edges()
		if item_id.is_empty() or seen_stack.has(item_id):
			continue
		var info := _as_dictionary(item_info_map.get(item_id, {}))
		if not info.is_empty():
			entry["item_name"] = info.get("item_name", "")
			entry["item_type"] = info.get("item_type", "")
			entry["rarity"] = info.get("rarity", "")
		entry["quantity"] = entry.get("add_quantity", 0)
		entry["quantity_prefix"] = "+"
		rows.append(_build_stack_row(entry, true, true))

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := int(a.get("priority", 0))
		var priority_b := int(b.get("priority", 0))
		if priority_a == priority_b:
			return str(a.get("sort_name", "")) < str(b.get("sort_name", ""))
		return priority_a > priority_b
	)
	return rows


func _build_equipment_row(entry: Dictionary, is_recent: bool, is_synthetic: bool) -> Dictionary:
	var item_name := _display_item_name(entry, "新装备")
	var slot_text := _equipment_slot_text(str(entry.get("equipment_slot", "")))
	var rarity_text := _rarity_text(str(entry.get("rarity", "")))
	var meta_parts: Array = []
	if not slot_text.is_empty():
		meta_parts.append(slot_text)
	if not rarity_text.is_empty():
		meta_parts.append(rarity_text)
	if is_synthetic:
		meta_parts.append("本轮新增")

	return {
		"kind": "equipment",
		"section": "equipment",
		"priority": 4 if is_recent else 1,
		"sort_name": item_name,
		"title": item_name,
		"meta_text": " | ".join(meta_parts) if not meta_parts.is_empty() else "可继续导向穿戴页。",
		"detail_text": (
			"这件装备是本轮刚到手的，建议先带去穿戴页试装。"
			if is_recent
			else "这件装备已经在当前背包里，可继续前往穿戴页做换装决策。"
		),
		"slot_text": slot_text,
		"rarity_text": rarity_text,
		"quantity_text": "",
		"is_recent": is_recent,
		"payload": entry,
	}


func _build_stack_row(entry: Dictionary, is_recent: bool, is_synthetic: bool) -> Dictionary:
	var item_name := _display_item_name(entry, "物资")
	var section := _stack_section(str(entry.get("item_type", "")))
	var quantity_prefix := str(entry.get("quantity_prefix", "x"))
	var quantity_value := str(entry.get("quantity", entry.get("add_quantity", 0)))
	var rarity_text := _rarity_text(str(entry.get("rarity", "")))
	var section_text := _section_name(section)
	var meta_parts: Array = [section_text]
	if not rarity_text.is_empty():
		meta_parts.append(rarity_text)
	if is_synthetic:
		meta_parts.append("本轮新增")

	return {
		"kind": "stack",
		"section": section,
		"priority": 3 if is_recent and section == "material" else (2 if is_recent else 0),
		"sort_name": item_name,
		"title": item_name,
		"meta_text": "%s%s | %s" % [
			quantity_prefix,
			quantity_value,
			" | ".join(meta_parts)
		],
		"detail_text": (
			"这类材料已经正式进包，确认完就可以继续推进。"
			if section == "material"
			else "这份收益已经入包，整理完后可以回角色或继续主线。"
		),
		"slot_text": "",
		"rarity_text": rarity_text,
		"quantity_text": "%s%s" % [quantity_prefix, quantity_value],
		"is_recent": is_recent,
		"payload": entry,
	}


func _build_inventory_row_card(row: Dictionary) -> PanelContainer:
	var section := str(row.get("section", "other"))
	var is_recent := bool(row.get("is_recent", false))
	var tint := _section_tint(section)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_inventory_card_style(tint, is_recent))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill(_section_name(section), tint))
	if is_recent:
		tags.add_child(create_pill("新装备" if section == "equipment" else "本轮新增", tint))
	var slot_text := str(row.get("slot_text", ""))
	if not slot_text.is_empty():
		tags.add_child(create_pill(slot_text, CHARACTER_TINT))
	var quantity_text := str(row.get("quantity_text", ""))
	if not quantity_text.is_empty():
		tags.add_child(create_pill(quantity_text, MATERIAL_TINT if section == "material" else OTHER_TINT))
	var rarity_text := str(row.get("rarity_text", ""))
	if not rarity_text.is_empty():
		tags.add_child(create_pill(rarity_text, OTHER_TINT))
	box.add_child(tags)

	var title := Label.new()
	title.text = str(row.get("title", "物品"))
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = str(row.get("meta_text", ""))
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta)

	var detail := Label.new()
	detail.text = str(row.get("detail_text", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate = CARD_TEXT_MUTED
	box.add_child(detail)

	if str(row.get("kind", "")) == "equipment":
		var action_row := HBoxContainer.new()
		action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_theme_constant_override("separation", 8)
		box.add_child(action_row)

		var action_button := Button.new()
		action_button.text = "去穿戴这件"
		style_primary_button(action_button, tint)
		action_button.pressed.connect(func() -> void:
			_emit_action("inventory_equipment_selected", _as_dictionary(row.get("payload", {})))
		)
		action_row.add_child(action_button)

	return card


func _filtered_rows(rows: Array, section: String) -> Array:
	if section == "all":
		return rows.duplicate(true)

	var filtered: Array = []
	for row in rows:
		var entry := _as_dictionary(row)
		if str(entry.get("section", "")) == section:
			filtered.append(entry)
	return filtered


func _recent_equipment_rows() -> Array:
	return _filtered_recent_rows("equipment")


func _recent_material_rows() -> Array:
	return _filtered_recent_rows("material")


func _recent_other_rows() -> Array:
	return _filtered_recent_rows("other")


func _filtered_recent_rows(section: String) -> Array:
	var rows: Array = []
	for row in _combined_inventory_rows():
		var entry := _as_dictionary(row)
		if str(entry.get("section", "")) != section:
			continue
		if int(entry.get("priority", 0)) < 2:
			continue
		rows.append(entry)
	return rows


func _preferred_section() -> String:
	if _recent_equipment_lookup().size() > 0:
		return "equipment"
	if _recent_material_rows().size() > 0:
		return "material"
	if _recent_other_rows().size() > 0:
		return "other"
	return "all"


func _build_recent_gain_summary() -> String:
	var recent_equipment_count := _recent_equipment_lookup().size()
	var recent_stack_lookup := _recent_stack_lookup()
	var item_info_map := _settle_item_info_map()
	var recent_material_count := 0
	var recent_other_count := 0
	for item_id in recent_stack_lookup.keys():
		var info := _as_dictionary(item_info_map.get(item_id, {}))
		if _stack_section(str(info.get("item_type", ""))) == "material":
			recent_material_count += 1
		else:
			recent_other_count += 1

	if recent_equipment_count == 0 and recent_material_count == 0 and recent_other_count == 0:
		if _combined_inventory_rows().is_empty():
			return "最近还没有新的收益回流；继续推进后，这里会先承接本轮新增物品。"
		return "最近没有新的战斗收益，当前背包仍可按分区继续整理。"

	return "本轮收获：新装备 %d 件 | 关键材料 %d 种 | 其他收益 %d 种。" % [
		recent_equipment_count,
		recent_material_count,
		recent_other_count,
	]


func _recent_inventory_entry_count() -> int:
	return _recent_equipment_lookup().size() + _recent_stack_lookup().size()


func _build_action_route_text() -> String:
	var recent_equipment_count := _recent_equipment_rows().size()
	var recent_material_count := _recent_material_rows().size()
	var recent_other_count := _recent_other_rows().size()

	if recent_equipment_count > 0:
		return "推荐路线：先点一件新装备去试穿，再回角色确认这轮成长，最后决定继续刷这一关还是回主线推进。"
	if recent_material_count > 0 or recent_other_count > 0:
		return "推荐路线：先把本轮新增收益看清，再判断这关值不值得继续刷；如果收益已经够了，就带着它回主线。"
	if not _combined_inventory_rows().is_empty():
		return "推荐路线：当前背包更像长期仓库，穿戴和角色页会更容易帮你做下一步决策。"
	return "推荐路线：当前还没有新增收益，直接回主线继续打，通常会比停在背包里更有推进感。"


func _settle_item_info_map() -> Dictionary:
	var info_map := {}
	for item in _as_array(_current_settle_result.get("drop_results", [])):
		var entry := _as_dictionary(item)
		var item_id := str(entry.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		info_map[item_id] = entry

	for reward in _as_array(_current_settle_result.get("reward_results", [])):
		var reward_entry := _as_dictionary(reward)
		for item in _as_array(reward_entry.get("reward_items", [])):
			var entry := _as_dictionary(item)
			var item_id := str(entry.get("item_id", "")).strip_edges()
			if item_id.is_empty():
				continue
			info_map[item_id] = entry

	return info_map


func _recent_equipment_lookup() -> Dictionary:
	var lookup := {}
	for item in _as_array(_current_settle_result.get("created_equipment_instances", [])):
		var entry := _as_dictionary(item)
		var equipment_instance_id := normalize_id_string(entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty():
			continue
		lookup[equipment_instance_id] = true
	return lookup


func _recent_stack_lookup() -> Dictionary:
	var lookup := {}
	var settle_inventory_results := _as_dictionary(_current_settle_result.get("inventory_results", {}))
	for item in _as_array(settle_inventory_results.get("stack_results", [])):
		var entry := _as_dictionary(item)
		var item_id := str(entry.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			continue
		lookup[item_id] = true
	return lookup


func _build_focus_card(title_text: String, meta_text: String, tint: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_inventory_card_style(tint, true))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	tags.add_child(create_pill(title_text, tint))
	box.add_child(tags)

	var meta := Label.new()
	meta.text = meta_text
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.modulate = BODY_TEXT
	box.add_child(meta)
	return card


func _build_empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = CARD_TEXT_MUTED
	return label


func _display_item_name(entry: Dictionary, fallback: String) -> String:
	var item_name := str(entry.get("item_name", "")).strip_edges()
	if not item_name.is_empty():
		return item_name
	return fallback


func _stack_section(item_type: String) -> String:
	return "material" if item_type == "material" else "other"


func _section_name(section: String) -> String:
	match section:
		"equipment":
			return "装备"
		"material":
			return "材料"
		"other":
			return "其他"
		_:
			return "全部"


func _equipment_slot_text(slot: String) -> String:
	match slot:
		"main_weapon":
			return "主武器"
		"sub_weapon":
			return "副武器"
		"armor":
			return "护甲"
		"leggings":
			return "下装"
		"gloves":
			return "手部"
		"boots":
			return "鞋履"
		"cloak":
			return "披风"
		"necklace":
			return "项链"
		"ring":
			return "戒指"
		"bracelet":
			return "手镯"
		"ring_1":
			return "戒指 1"
		"ring_2":
			return "戒指 2"
		"bracelet_1":
			return "手镯 1"
		"bracelet_2":
			return "手镯 2"
		_:
			return ""


func _rarity_text(rarity: String) -> String:
	match rarity:
		"common":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
		_:
			return ""


func _trimmed_row_titles(rows: Array, limit: int, fallback: String) -> String:
	var names: Array = []
	for row in rows:
		if names.size() >= limit:
			break
		names.append(str(_as_dictionary(row).get("title", "物品")))

	if names.is_empty():
		return fallback
	if rows.size() > limit:
		return "%s 等 %d 项，%s" % [", ".join(names), rows.size(), fallback]
	return "%s，%s" % [", ".join(names), fallback]


func _create_inventory_card_style(tint: Color, emphasize: bool) -> StyleBoxFlat:
	var style := _create_card_style()
	style.bg_color = Color(tint.r * 0.16 + CARD_BACKGROUND.r * 0.84, tint.g * 0.16 + CARD_BACKGROUND.g * 0.84, tint.b * 0.16 + CARD_BACKGROUND.b * 0.84, 0.98)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.88 if emphasize else 0.54)
	style.shadow_size = 8 if emphasize else 6
	return style


func _section_tint(section: String) -> Color:
	match section:
		"equipment":
			return EQUIPMENT_TINT
		"material":
			return MATERIAL_TINT
		"other":
			return OTHER_TINT
		_:
			return CHARACTER_TINT


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


func _as_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

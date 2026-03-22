extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneEquipmentPage

const CHARACTER_TINT := Color(0.56, 0.82, 0.96, 1.0)
const EQUIPMENT_TINT := Color(0.98, 0.77, 0.44, 1.0)
const READY_TINT := Color(0.58, 0.88, 0.66, 1.0)
const WARNING_TINT := Color(0.95, 0.68, 0.38, 1.0)
const OTHER_TINT := Color(0.76, 0.70, 0.96, 1.0)
const SLOT_ORDER := [
	"main_weapon",
	"sub_weapon",
	"armor",
	"leggings",
	"gloves",
	"boots",
	"cloak",
	"necklace",
	"ring_1",
	"ring_2",
	"bracelet_1",
	"bracelet_2",
]

var recent_character_selector: OptionButton
var character_id_input: LineEdit
var target_slot_selector: OptionButton
var equipment_instance_input: LineEdit
var debug_toggle: CheckBox
var debug_box: VBoxContainer

var header_character_label: Label
var header_status_label: Label
var header_overview_label: Label
var header_tag_row: HBoxContainer

var slot_focus_title_label: Label
var slot_focus_hint_label: Label
var slot_cards_box: VBoxContainer

var candidate_summary_label: Label
var candidate_box: VBoxContainer

var action_status_label: Label
var action_hint_label: Label
var handoff_label: Label
var refresh_button: Button
var equip_button: Button
var unequip_button: Button
var inventory_button: Button
var character_button: Button
var stage_button: Button

var _current_character: Dictionary = {}
var _current_slots: Dictionary = {}
var _current_inventory: Dictionary = {}
var _current_settle_result: Dictionary = {}
var _selected_slot_key := ""
var _selected_equipment_payload: Dictionary = {}
var _handoff_text := ""


func _init() -> void:
	setup_page("穿戴", [])

	var header_card := add_card("当前穿戴", "")
	header_character_label = Label.new()
	header_character_label.add_theme_font_size_override("font_size", 24)
	header_card.add_child(header_character_label)

	header_status_label = Label.new()
	header_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(header_status_label)

	header_overview_label = Label.new()
	header_overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_overview_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(header_overview_label)

	header_tag_row = HBoxContainer.new()
	header_tag_row.add_theme_constant_override("separation", 8)
	header_card.add_child(header_tag_row)

	var slot_card := add_card("这一格穿什么", "")
	slot_focus_title_label = Label.new()
	slot_focus_title_label.add_theme_font_size_override("font_size", 22)
	slot_card.add_child(slot_focus_title_label)

	slot_focus_hint_label = Label.new()
	slot_focus_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_focus_hint_label.modulate = CARD_TEXT_MUTED
	slot_card.add_child(slot_focus_hint_label)

	slot_cards_box = VBoxContainer.new()
	slot_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_cards_box.add_theme_constant_override("separation", 10)
	slot_card.add_child(slot_cards_box)

	var candidate_card := add_card("可替换装备", "新装备会优先顶出来；同槽候选会围绕当前关注槽位展示。")
	candidate_summary_label = Label.new()
	candidate_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidate_card.add_child(candidate_summary_label)

	candidate_box = VBoxContainer.new()
	candidate_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	candidate_box.add_theme_constant_override("separation", 10)
	candidate_card.add_child(candidate_box)

	var action_card := add_card("现在怎么做", "先看当前槽位，再决定穿上、卸下，还是回背包 / 角色 / 主线。")
	action_status_label = Label.new()
	action_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(action_status_label)

	action_hint_label = Label.new()
	action_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_hint_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(action_hint_label)

	handoff_label = Label.new()
	handoff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	handoff_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(handoff_label)

	var primary_actions := add_button_row(action_card)
	refresh_button = add_action_button(primary_actions, "刷新当前穿戴", "load_slots")
	equip_button = add_action_button(primary_actions, "穿上当前候选", "equip")
	style_primary_button(equip_button)
	unequip_button = add_action_button(primary_actions, "卸下这一格", "unequip")

	var followup_actions := add_button_row(action_card)
	inventory_button = add_action_button(followup_actions, "去背包看更多", "navigate_inventory")
	character_button = add_action_button(followup_actions, "回角色看成长", "navigate_character")
	stage_button = add_action_button(followup_actions, "回主线继续推进", "navigate_stage")

	var debug_card := add_card("调试区", "角色切换、slot_key 和 equipment_instance_id 都留在这里，不占首屏。")
	recent_character_selector = add_labeled_option_button("快速切换角色", debug_card)
	recent_character_selector.item_selected.connect(_on_recent_character_selected)

	debug_toggle = add_check_box("显示调试输入", false, debug_card)
	debug_toggle.toggled.connect(_on_debug_toggle)

	debug_box = VBoxContainer.new()
	debug_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_box.visible = false
	debug_card.add_child(debug_box)

	character_id_input = add_labeled_input("character_id（调试）", "", debug_box)
	character_id_input.text_changed.connect(_on_character_id_changed)

	target_slot_selector = add_labeled_option_button("target_slot_key（调试）", debug_box)
	replace_options(target_slot_selector, [], "请先选中槽位")
	target_slot_selector.item_selected.connect(_on_target_slot_selected)

	equipment_instance_input = add_labeled_input("equipment_instance_id（调试）", "", debug_box)

	render_equipment_context({}, {}, {}, {})
	show_handoff_summary("先看当前穿戴，再决定去背包看更多、回角色看成长，还是继续主线推进。")
	_move_secondary_sections_to_bottom()


func get_character_id_text() -> String:
	return character_id_input.text.strip_edges()


func set_character_id(character_id: String) -> void:
	character_id_input.text = normalize_id_string(character_id)
	_refresh_equipment_page()


func set_recent_characters(records: Array, current_character_id: String) -> void:
	var options: Array = []
	for record in records:
		var entry = record if typeof(record) == TYPE_DICTIONARY else {}
		var character_id = normalize_id_string(entry.get("character_id", ""))
		if character_id.is_empty():
			continue

		var label = "%s #%s" % [str(entry.get("character_name", "角色")), character_id]
		if entry.has("is_active") and int(entry.get("is_active", 0)) == 1:
			label += " [当前可战斗]"
		elif entry.has("is_active"):
			label += " [待启用]"

		options.append({
			"label": label,
			"value": character_id,
			"record": entry,
		})

	replace_options(recent_character_selector, options, "暂无真实角色记录", current_character_id)


func set_selected_equipment_instance(
	equipment_instance_id: String,
	equipment_name: String = "",
	equipment_slot: String = ""
) -> void:
	var normalized_id := normalize_id_string(equipment_instance_id)
	if normalized_id.is_empty():
		_selected_equipment_payload = {}
		equipment_instance_input.text = ""
		_refresh_equipment_page()
		return

	var payload := _find_equipment_payload(normalized_id)
	if payload.is_empty():
		payload = {
			"equipment_instance_id": normalized_id,
			"item_name": equipment_name,
			"equipment_slot": equipment_slot,
		}
	elif not equipment_name.is_empty():
		payload["item_name"] = equipment_name
	if str(payload.get("equipment_slot", "")).strip_edges().is_empty() and not equipment_slot.strip_edges().is_empty():
		payload["equipment_slot"] = equipment_slot

	_selected_equipment_payload = payload
	equipment_instance_input.text = normalized_id
	var preferred_slot := _best_slot_for_equipment(_build_slot_entries(_build_candidate_pool()), str(payload.get("equipment_slot", "")))
	if not preferred_slot.is_empty():
		_selected_slot_key = preferred_slot
		select_option_by_value(target_slot_selector, preferred_slot)
	_refresh_equipment_page()


func render_equipment_context(
	character: Dictionary,
	slots_payload: Dictionary,
	inventory_payload: Dictionary,
	settle_result: Dictionary
) -> void:
	_current_character = character.duplicate(true)
	_current_inventory = inventory_payload.duplicate(true)
	_current_settle_result = settle_result.duplicate(true)
	_current_slots = slots_payload.duplicate(true)
	_refresh_equipment_page()


func render_slots(payload: Dictionary) -> void:
	_current_slots = payload.duplicate(true)
	_refresh_equipment_page()
	if payload.is_empty():
		set_output_text("")
	else:
		set_output_json(payload)


func show_handoff_summary(text: String) -> void:
	_handoff_text = text.strip_edges()
	var candidate_pool := _build_candidate_pool()
	_refresh_action_area(_build_slot_entries(candidate_pool), candidate_pool)


func get_target_slot_key() -> String:
	var selected := get_selected_option(target_slot_selector)
	var slot_key := str(selected.get("value", "")).strip_edges()
	if slot_key.is_empty():
		return _selected_slot_key
	return slot_key


func get_equipment_instance_id_text() -> String:
	var selected_id := normalize_id_string(equipment_instance_input.text)
	if not selected_id.is_empty():
		return selected_id
	return normalize_id_string(_selected_equipment_payload.get("equipment_instance_id", ""))


func _refresh_equipment_page() -> void:
	var candidate_pool := _build_candidate_pool()
	_sync_selected_equipment(candidate_pool)
	var slot_entries := _build_slot_entries(candidate_pool)
	_selected_slot_key = _resolve_focus_slot_key(slot_entries)
	_sync_slot_selector(slot_entries)
	_refresh_header(slot_entries, candidate_pool)
	_refresh_slot_area(slot_entries)
	_refresh_candidate_area(slot_entries, candidate_pool)
	_refresh_action_area(slot_entries, candidate_pool)


func _refresh_header(slot_entries: Array, candidate_pool: Array) -> void:
	clear_container(header_tag_row)

	var filled_count := 0
	var slots_with_candidates := 0
	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		if not bool(slot_entry.get("is_empty", true)):
			filled_count += 1
		if int(slot_entry.get("candidate_count", 0)) > 0:
			slots_with_candidates += 1

	if _current_character.is_empty():
		header_character_label.text = "当前角色：待确认"
		header_status_label.text = "先锁定当前角色，再决定哪个部位值得先换。"
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
				"可直接换装" if int(_current_character.get("is_active", 0)) == 1 else "先看当前装备也可以",
				READY_TINT if int(_current_character.get("is_active", 0)) == 1 else WARNING_TINT
			)
		)

	var recent_candidate_count := _count_recent_candidates(candidate_pool)
	header_overview_label.text = "当前穿戴：已穿戴 %d / 空槽 %d / 可试装槽位 %d / 本轮新装备 %d" % [
		filled_count,
		max(0, slot_entries.size() - filled_count),
		slots_with_candidates,
		recent_candidate_count,
	]
	set_summary_text(header_overview_label.text)

	if filled_count > 0:
		header_tag_row.add_child(create_pill("已穿戴 %d" % filled_count, READY_TINT))
	if slots_with_candidates > 0:
		header_tag_row.add_child(create_pill("可替换槽位 %d" % slots_with_candidates, EQUIPMENT_TINT))
	if recent_candidate_count > 0:
		header_tag_row.add_child(create_pill("本轮有新装备", EQUIPMENT_TINT))
	elif not candidate_pool.is_empty():
		header_tag_row.add_child(create_pill("可继续整理装备", EQUIPMENT_TINT))


func _refresh_slot_area(slot_entries: Array) -> void:
	clear_container(slot_cards_box)

	var focus_entry := _find_slot_entry(slot_entries, _selected_slot_key)
	if focus_entry.is_empty():
		slot_focus_title_label.text = "这一格穿什么：待确认"
		slot_focus_hint_label.text = "先锁定角色并刷新当前穿戴，12 个固定槽位就会在这里展开。"
		slot_cards_box.add_child(_build_empty_label("当前还没有可展示的穿戴槽。"))
		return

	slot_focus_title_label.text = "这一格穿什么：%s" % _slot_display_name(str(focus_entry.get("slot_key", "")))
	slot_focus_hint_label.text = _slot_focus_hint(focus_entry)
	for entry in slot_entries:
		slot_cards_box.add_child(_build_slot_card(_as_dictionary(entry)))


func _refresh_candidate_area(slot_entries: Array, candidate_pool: Array) -> void:
	clear_container(candidate_box)

	var focus_entry := _find_slot_entry(slot_entries, _selected_slot_key)
	if focus_entry.is_empty():
		candidate_summary_label.text = "先锁定当前槽位，再看可替换装备。"
		candidate_box.add_child(_build_empty_label("当前还没有聚焦槽位。"))
		return

	var slot_key := str(focus_entry.get("slot_key", ""))
	var candidates := _compatible_candidates(candidate_pool, slot_key)
	if candidates.is_empty():
		if _current_slots.is_empty():
			candidate_summary_label.text = "%s 的候选装备会在刷新穿戴槽后更清楚。" % _slot_display_name(slot_key)
			candidate_box.add_child(_build_empty_label("先刷新当前穿戴，再回来挑这一格的候选装备。"))
			return
		if bool(focus_entry.get("is_empty", true)):
			candidate_summary_label.text = "%s 当前还是空槽，但手头暂时没有可直接补上的装备。" % _slot_display_name(slot_key)
			candidate_box.add_child(_build_empty_label("去背包看更多，或打完一场后再回来处理这一格。"))
			return
		candidate_summary_label.text = "%s 暂时没有新的同槽候选。" % _slot_display_name(slot_key)
		candidate_box.add_child(_build_empty_label("这格可以先保持当前穿戴，继续去背包整理或回主线推进。"))
		return

	candidate_summary_label.text = "%s 当前可试装 %d 件，其中本轮新装备 %d 件。" % [
		_slot_display_name(slot_key),
		candidates.size(),
		_count_recent_candidates(candidates),
	]
	for candidate in candidates:
		candidate_box.add_child(_build_candidate_card(_as_dictionary(candidate), focus_entry))


func _refresh_action_area(slot_entries: Array, candidate_pool: Array) -> void:
	var focus_entry := _find_slot_entry(slot_entries, _selected_slot_key)
	var candidates := _compatible_candidates(candidate_pool, _selected_slot_key)
	var selected_name := str(_selected_equipment_payload.get("item_name", ""))

	if _current_character.is_empty():
		action_status_label.text = "先确认当前角色，再继续换装会更稳。"
	elif _current_slots.is_empty():
		action_status_label.text = "先刷新当前穿戴，确认这一格现在穿了什么。"
	elif focus_entry.is_empty():
		action_status_label.text = "先锁定一个装备位，再看可替换装备。"
	elif bool(focus_entry.get("is_empty", true)) and not candidates.is_empty():
		action_status_label.text = "这格现在还是空的，先补上最顺。"
	elif int(focus_entry.get("recent_candidate_count", 0)) > 0:
		action_status_label.text = "这一格有本轮新装备可试穿，优先看这里最直接。"
	elif not candidates.is_empty():
		action_status_label.text = "这一格有可替换装备，先对比这一格最清楚。"
	else:
		action_status_label.text = "这一格暂时没有可换候选，可以回背包看更多。"

	if not selected_name.is_empty():
		action_hint_label.text = "当前待穿戴：%s -> %s" % [
			selected_name,
			_slot_display_name(_selected_slot_key),
		]
	elif not candidates.is_empty():
		action_hint_label.text = "先从候选区选一件，再点“穿上当前候选”。"
	else:
		action_hint_label.text = "如果这格暂时没有可换候选，就去背包看更多，或回主线继续推进。"

	handoff_label.text = _handoff_text if not _handoff_text.is_empty() else "换完这一件后，通常会回角色看成长，或回主线继续推进。"

	equip_button.text = (
		"穿上当前候选"
		if selected_name.is_empty()
		else "把 %s 穿上" % selected_name
	)
	equip_button.disabled = (
		get_character_id_text().is_empty()
		or get_target_slot_key().is_empty()
		or get_equipment_instance_id_text().is_empty()
	)

	unequip_button.disabled = focus_entry.is_empty() or bool(focus_entry.get("is_empty", true)) or get_character_id_text().is_empty()
	unequip_button.text = "卸下这一格" if not focus_entry.is_empty() and not bool(focus_entry.get("is_empty", true)) else "这一格暂无已穿戴装备"

	inventory_button.text = "去背包看更多"
	character_button.text = "回角色看成长"
	stage_button.text = "回主线继续推进"


func _build_slot_entries(candidate_pool: Array) -> Array:
	var slot_lookup := {}
	for slot in _as_array(_current_slots.get("slots", [])):
		var entry := _as_dictionary(slot)
		var slot_key := str(entry.get("slot_key", "")).strip_edges()
		if slot_key.is_empty():
			continue
		slot_lookup[slot_key] = entry

	var entries: Array = []
	for slot_key in SLOT_ORDER:
		var slot_entry := _as_dictionary(slot_lookup.get(slot_key, {"slot_key": slot_key, "equipment": {}}))
		var equipment := _as_dictionary(slot_entry.get("equipment", {}))
		var candidate_count := 0
		var recent_candidate_count := 0
		for candidate in candidate_pool:
			var candidate_entry := _as_dictionary(candidate)
			if not _slot_accepts_equipment(slot_key, str(candidate_entry.get("equipment_slot", ""))):
				continue
			candidate_count += 1
			if bool(candidate_entry.get("is_recent", false)):
				recent_candidate_count += 1

		entries.append({
			"slot_key": slot_key,
			"slot_name": _slot_display_name(slot_key),
			"equipment": equipment,
			"is_empty": equipment.is_empty(),
			"candidate_count": candidate_count,
			"recent_candidate_count": recent_candidate_count,
		})

	return entries


func _resolve_focus_slot_key(slot_entries: Array) -> String:
	if _slot_exists(slot_entries, _selected_slot_key):
		return _selected_slot_key

	var selected_equipment_slot := str(_selected_equipment_payload.get("equipment_slot", "")).strip_edges()
	if not selected_equipment_slot.is_empty():
		var preferred := _best_slot_for_equipment(slot_entries, selected_equipment_slot)
		if not preferred.is_empty():
			return preferred

	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		if bool(slot_entry.get("is_empty", true)) and int(slot_entry.get("candidate_count", 0)) > 0:
			return str(slot_entry.get("slot_key", ""))
	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		if int(slot_entry.get("recent_candidate_count", 0)) > 0:
			return str(slot_entry.get("slot_key", ""))
	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		if int(slot_entry.get("candidate_count", 0)) > 0:
			return str(slot_entry.get("slot_key", ""))
	if not slot_entries.is_empty():
		return str(_as_dictionary(slot_entries[0]).get("slot_key", ""))
	return ""


func _best_slot_for_equipment(slot_entries: Array, equipment_slot: String) -> String:
	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		if _slot_accepts_equipment(str(slot_entry.get("slot_key", "")), equipment_slot) and bool(slot_entry.get("is_empty", true)):
			return str(slot_entry.get("slot_key", ""))
	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		if _slot_accepts_equipment(str(slot_entry.get("slot_key", "")), equipment_slot):
			return str(slot_entry.get("slot_key", ""))
	return ""


func _build_candidate_pool() -> Array:
	var candidates: Array = []
	var recent_lookup := _recent_equipment_lookup()
	var equipped_lookup := _equipped_instance_lookup()
	var seen := {}

	for item in _as_array(_current_inventory.get("equipment_items", [])):
		var entry := _as_dictionary(item)
		var equipment_instance_id := normalize_id_string(entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty() or seen.has(equipment_instance_id) or equipped_lookup.has(equipment_instance_id):
			continue
		seen[equipment_instance_id] = true
		candidates.append(_build_candidate_entry(entry, recent_lookup.has(equipment_instance_id), false))

	for item in _as_array(_current_settle_result.get("created_equipment_instances", [])):
		var entry := _as_dictionary(item)
		var equipment_instance_id := normalize_id_string(entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty() or seen.has(equipment_instance_id) or equipped_lookup.has(equipment_instance_id):
			continue
		seen[equipment_instance_id] = true
		candidates.append(_build_candidate_entry(entry, true, true))

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.get("is_recent", false)) == bool(b.get("is_recent", false)):
			var rarity_a := int(a.get("rarity_rank", 0))
			var rarity_b := int(b.get("rarity_rank", 0))
			if rarity_a == rarity_b:
				return str(a.get("sort_name", "")) < str(b.get("sort_name", ""))
			return rarity_a > rarity_b
		return bool(a.get("is_recent", false))
	)
	return candidates


func _build_candidate_entry(entry: Dictionary, is_recent: bool, is_synthetic: bool) -> Dictionary:
	var item_name := _display_item_name(entry, "可替换装备")
	var equipment_slot := str(entry.get("equipment_slot", "")).strip_edges()
	var rarity_text := _rarity_text(str(entry.get("rarity", "")))
	return {
		"equipment_instance_id": normalize_id_string(entry.get("equipment_instance_id", "")),
		"item_name": item_name,
		"equipment_slot": equipment_slot,
		"slot_text": _equipment_type_text(equipment_slot),
		"rarity_text": rarity_text,
		"rarity_rank": _rarity_rank(str(entry.get("rarity", ""))),
		"is_recent": is_recent,
		"is_synthetic": is_synthetic,
		"sort_name": item_name,
		"payload": entry,
	}


func _compatible_candidates(candidate_pool: Array, slot_key: String) -> Array:
	var compatible: Array = []
	for candidate in candidate_pool:
		var entry := _as_dictionary(candidate)
		if _slot_accepts_equipment(slot_key, str(entry.get("equipment_slot", ""))):
			compatible.append(entry)
	return compatible


func _build_slot_card(entry: Dictionary) -> PanelContainer:
	var slot_key := str(entry.get("slot_key", ""))
	var is_focus := slot_key == _selected_slot_key
	var is_empty := bool(entry.get("is_empty", true))
	var equipment := _as_dictionary(entry.get("equipment", {}))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_slot_card_style(is_focus, is_empty))

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
	tags.add_child(create_pill(str(entry.get("slot_name", "")), EQUIPMENT_TINT if is_focus else CHARACTER_TINT))
	tags.add_child(create_pill("当前关注" if is_focus else ("空槽" if is_empty else "已穿戴"), EQUIPMENT_TINT if is_focus else (WARNING_TINT if is_empty else READY_TINT)))
	if int(entry.get("recent_candidate_count", 0)) > 0:
		tags.add_child(create_pill("本轮可试装 %d" % int(entry.get("recent_candidate_count", 0)), EQUIPMENT_TINT))
	elif int(entry.get("candidate_count", 0)) > 0:
		tags.add_child(create_pill("候选 %d" % int(entry.get("candidate_count", 0)), READY_TINT))
	box.add_child(tags)

	var title := Label.new()
	title.text = (
		"这一格还空着"
		if is_empty
		else str(equipment.get("item_name", "已穿戴装备"))
	)
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = _slot_card_meta(entry)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta)

	var detail := Label.new()
	detail.text = _slot_card_detail(entry)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate = CARD_TEXT_MUTED
	box.add_child(detail)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)

	var button := Button.new()
	button.text = "当前关注" if is_focus else "查看这一格"
	button.disabled = is_focus
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		_selected_slot_key = slot_key
		select_option_by_value(target_slot_selector, slot_key)
		_refresh_equipment_page()
	)
	action_row.add_child(button)

	return card


func _build_candidate_card(candidate: Dictionary, focus_entry: Dictionary) -> PanelContainer:
	var candidate_id := normalize_id_string(candidate.get("equipment_instance_id", ""))
	var is_selected := candidate_id == normalize_id_string(_selected_equipment_payload.get("equipment_instance_id", ""))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _create_candidate_card_style(bool(candidate.get("is_recent", false)), is_selected))

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
	tags.add_child(create_pill("可替换装备", EQUIPMENT_TINT))
	if bool(candidate.get("is_recent", false)):
		tags.add_child(create_pill("本轮新装备", EQUIPMENT_TINT))
	if is_selected:
		tags.add_child(create_pill("当前候选", READY_TINT))
	var rarity_text := str(candidate.get("rarity_text", ""))
	if not rarity_text.is_empty():
		tags.add_child(create_pill(rarity_text, OTHER_TINT))
	box.add_child(tags)

	var title := Label.new()
	title.text = str(candidate.get("item_name", "可替换装备"))
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	var meta := Label.new()
	meta.text = _candidate_meta(candidate, focus_entry)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta)

	var detail := Label.new()
	detail.text = _candidate_detail(candidate, focus_entry)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.modulate = CARD_TEXT_MUTED
	box.add_child(detail)

	var action_row := HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)

	var button := Button.new()
	button.text = "当前候选" if is_selected else "选为待穿戴"
	button.disabled = is_selected
	style_primary_button(button, EQUIPMENT_TINT if bool(candidate.get("is_recent", false)) else READY_TINT)
	button.pressed.connect(func() -> void:
		_select_candidate(candidate, str(focus_entry.get("slot_key", "")))
	)
	action_row.add_child(button)

	return card


func _select_candidate(candidate: Dictionary, slot_key: String) -> void:
	_selected_equipment_payload = candidate.duplicate(true)
	_selected_slot_key = slot_key
	equipment_instance_input.text = normalize_id_string(candidate.get("equipment_instance_id", ""))
	select_option_by_value(target_slot_selector, slot_key)
	_refresh_equipment_page()


func _sync_slot_selector(slot_entries: Array) -> void:
	var options: Array = []
	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		options.append({
			"label": str(slot_entry.get("slot_name", slot_entry.get("slot_key", ""))),
			"value": str(slot_entry.get("slot_key", "")),
		})

	replace_options(target_slot_selector, options, "请先选中槽位", _selected_slot_key)


func _sync_selected_equipment(candidate_pool: Array) -> void:
	var selected_id := normalize_id_string(_selected_equipment_payload.get("equipment_instance_id", ""))
	if selected_id.is_empty():
		return
	if _equipped_instance_lookup().has(selected_id):
		_selected_equipment_payload = {}
		equipment_instance_input.text = ""
		return

	var matched := _find_candidate_by_id(candidate_pool, selected_id)
	if not matched.is_empty():
		_selected_equipment_payload = matched
	equipment_instance_input.text = selected_id


func _count_recent_candidates(candidates: Array) -> int:
	var count := 0
	for candidate in candidates:
		if bool(_as_dictionary(candidate).get("is_recent", false)):
			count += 1
	return count


func _equipped_instance_lookup() -> Dictionary:
	var lookup := {}
	for slot in _as_array(_current_slots.get("slots", [])):
		var entry := _as_dictionary(slot)
		var equipment_instance_id := normalize_id_string(entry.get("equipped_instance_id", ""))
		if equipment_instance_id.is_empty():
			continue
		lookup[equipment_instance_id] = true
	return lookup


func _recent_equipment_lookup() -> Dictionary:
	var lookup := {}
	for item in _as_array(_current_settle_result.get("created_equipment_instances", [])):
		var entry := _as_dictionary(item)
		var equipment_instance_id := normalize_id_string(entry.get("equipment_instance_id", ""))
		if equipment_instance_id.is_empty():
			continue
		lookup[equipment_instance_id] = true
	return lookup


func _find_equipment_payload(equipment_instance_id: String) -> Dictionary:
	for item in _as_array(_current_inventory.get("equipment_items", [])):
		var entry := _as_dictionary(item)
		if normalize_id_string(entry.get("equipment_instance_id", "")) == equipment_instance_id:
			return entry.duplicate(true)
	for item in _as_array(_current_settle_result.get("created_equipment_instances", [])):
		var entry := _as_dictionary(item)
		if normalize_id_string(entry.get("equipment_instance_id", "")) == equipment_instance_id:
			return entry.duplicate(true)
	return {}


func _find_candidate_by_id(candidate_pool: Array, equipment_instance_id: String) -> Dictionary:
	for candidate in candidate_pool:
		var entry := _as_dictionary(candidate)
		if normalize_id_string(entry.get("equipment_instance_id", "")) == equipment_instance_id:
			return entry.duplicate(true)
	return {}


func _find_slot_entry(slot_entries: Array, slot_key: String) -> Dictionary:
	for entry in slot_entries:
		var slot_entry := _as_dictionary(entry)
		if str(slot_entry.get("slot_key", "")) == slot_key:
			return slot_entry
	return {}


func _slot_exists(slot_entries: Array, slot_key: String) -> bool:
	return not _find_slot_entry(slot_entries, slot_key).is_empty()


func _slot_accepts_equipment(slot_key: String, equipment_slot: String) -> bool:
	if slot_key.begins_with("ring_"):
		return equipment_slot == "ring"
	if slot_key.begins_with("bracelet_"):
		return equipment_slot == "bracelet"
	return slot_key == equipment_slot


func _slot_focus_hint(entry: Dictionary) -> String:
	if bool(entry.get("is_empty", true)):
		if int(entry.get("candidate_count", 0)) > 0:
			return "这一格现在还是空的，而且手头有可用装备，优先补上最顺。"
		return "这一格现在还是空的；如果手头没有同槽装备，就先去背包看更多。"
	if int(entry.get("recent_candidate_count", 0)) > 0:
		return "这一格当前有本轮新装备可试穿，建议先在候选区里选一件。"
	if int(entry.get("candidate_count", 0)) > 0:
		return "这一格已经有装备，但仍有同槽候选可对比。"
	return "这一格当前已稳定；如果想继续换装，可以去背包挑别的候选。"


func _slot_card_meta(entry: Dictionary) -> String:
	var equipment := _as_dictionary(entry.get("equipment", {}))
	if equipment.is_empty():
		return "当前未穿戴 | 候选装备 %d 件" % int(entry.get("candidate_count", 0))
	return "%s | 候选装备 %d 件" % [
		_compact_equipment_meta(equipment),
		int(entry.get("candidate_count", 0)),
	]


func _slot_card_detail(entry: Dictionary) -> String:
	if bool(entry.get("is_empty", true)):
		return "这格还没有正式穿戴装备。"
	if int(entry.get("recent_candidate_count", 0)) > 0:
		return "本轮新装备已经能直接对这格发起试穿。"
	if int(entry.get("candidate_count", 0)) > 0:
		return "这格有同槽候选可替换，适合继续做换装决策。"
	return "这格目前没有新的同槽候选。"


func _candidate_meta(candidate: Dictionary, focus_entry: Dictionary) -> String:
	var focus_equipment := _as_dictionary(focus_entry.get("equipment", {}))
	if focus_equipment.is_empty():
		return "当前这格还是空的，补上后会更完整。"
	return "当前这格穿的是 %s；这件可拿来试装对比。" % str(focus_equipment.get("item_name", "当前装备"))


func _candidate_detail(candidate: Dictionary, focus_entry: Dictionary) -> String:
	var detail_parts: Array = []
	var slot_text := str(candidate.get("slot_text", ""))
	if not slot_text.is_empty():
		detail_parts.append("装备类型：%s" % slot_text)
	if bool(candidate.get("is_recent", false)):
		detail_parts.append("这是本轮新装备，建议优先试穿。")
	else:
		detail_parts.append("这件装备已经在当前可用范围内。")
	if bool(focus_entry.get("is_empty", true)):
		detail_parts.append("这一格当前为空，穿上后最容易形成明确变化。")
	return " | ".join(detail_parts)


func _compact_equipment_meta(equipment: Dictionary) -> String:
	var parts: Array = []
	var equipment_type := _equipment_type_text(str(equipment.get("equipment_slot", "")))
	if not equipment_type.is_empty():
		parts.append(equipment_type)
	var rarity_text := _rarity_text(str(equipment.get("rarity", "")))
	if not rarity_text.is_empty():
		parts.append(rarity_text)
	return " | ".join(parts) if not parts.is_empty() else "当前已穿戴"


func _slot_display_name(slot_key: String) -> String:
	match slot_key:
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
		"ring_1":
			return "戒指 1"
		"ring_2":
			return "戒指 2"
		"bracelet_1":
			return "手镯 1"
		"bracelet_2":
			return "手镯 2"
		_:
			return slot_key


func _equipment_type_text(equipment_slot: String) -> String:
	match equipment_slot:
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
		_:
			return equipment_slot


func _display_item_name(entry: Dictionary, fallback: String) -> String:
	var item_name := str(entry.get("item_name", "")).strip_edges()
	if not item_name.is_empty():
		return item_name
	return fallback


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


func _rarity_rank(rarity: String) -> int:
	match rarity:
		"legendary":
			return 4
		"epic":
			return 3
		"rare":
			return 2
		"common":
			return 1
		_:
			return 0


func _build_empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = CARD_TEXT_MUTED
	return label


func _create_slot_card_style(is_focus: bool, is_empty: bool) -> StyleBoxFlat:
	var tint := EQUIPMENT_TINT if is_focus else (WARNING_TINT if is_empty else READY_TINT)
	var style := _create_card_style()
	style.bg_color = Color(tint.r * 0.14 + CARD_BACKGROUND.r * 0.86, tint.g * 0.14 + CARD_BACKGROUND.g * 0.86, tint.b * 0.14 + CARD_BACKGROUND.b * 0.86, 0.98)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.92 if is_focus else 0.56)
	style.shadow_size = 8 if is_focus else 6
	return style


func _create_candidate_card_style(is_recent: bool, is_selected: bool) -> StyleBoxFlat:
	var tint := READY_TINT
	if is_recent:
		tint = EQUIPMENT_TINT
	if is_selected:
		tint = READY_TINT
	var style := _create_card_style()
	style.bg_color = Color(tint.r * 0.16 + CARD_BACKGROUND.r * 0.84, tint.g * 0.16 + CARD_BACKGROUND.g * 0.84, tint.b * 0.16 + CARD_BACKGROUND.b * 0.84, 0.98)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.9 if is_selected else 0.58)
	style.shadow_size = 8 if is_selected else 6
	return style


func _on_recent_character_selected(_index: int) -> void:
	var selected = get_selected_option(recent_character_selector)
	var character_id = normalize_id_string(selected.get("value", ""))
	if character_id.is_empty():
		return

	character_id_input.text = character_id
	_emit_context("detail_character_changed", {"character_id": character_id})


func _on_character_id_changed(_text: String) -> void:
	_emit_context("detail_character_changed", {"character_id": get_character_id_text()})


func _on_target_slot_selected(_index: int) -> void:
	_selected_slot_key = get_target_slot_key()
	_refresh_equipment_page()


func _on_debug_toggle(pressed: bool) -> void:
	debug_box.visible = pressed


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

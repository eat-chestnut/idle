extends RefCounted

const MAP_WIDTH_SCREENS := 4.0
const MAP_HEIGHT_SCREENS := 2.0

const PLAYER_START_ANCHOR := Vector2(0.08, 0.72)
const BOSS_ZONE := Rect2(0.76, 0.14, 0.22, 0.54)
const BOSS_ANCHOR := Vector2(0.93, 0.40)
const BOSS_GUARD_ANCHORS := [
	Vector2(0.85, 0.58),
	Vector2(0.85, 0.24),
]
const ELITE_GUARD_ANCHORS := [
	Vector2(0.48, 0.56),
	Vector2(0.62, 0.28),
	Vector2(0.66, 0.74),
]
const NORMAL_PATROL_ANCHORS := [
	Vector2(0.18, 0.66),
	Vector2(0.24, 0.30),
	Vector2(0.32, 0.78),
	Vector2(0.38, 0.46),
	Vector2(0.46, 0.20),
	Vector2(0.52, 0.72),
	Vector2(0.58, 0.42),
	Vector2(0.64, 0.16),
	Vector2(0.68, 0.58),
	Vector2(0.72, 0.34),
]
const MAP_SECTIONS := [
	{
		"label": "起始活动区",
		"rect": Rect2(0.00, 0.50, 0.22, 0.40),
	},
	{
		"label": "巡猎带 A",
		"rect": Rect2(0.18, 0.18, 0.24, 0.62),
	},
	{
		"label": "巡猎带 B",
		"rect": Rect2(0.40, 0.12, 0.24, 0.72),
	},
	{
		"label": "终点 Boss 区",
		"rect": BOSS_ZONE,
	},
]


static func build_layout(monster_list: Array, battle_context_id: String = "") -> Array:
	var entries: Array = []
	for monster in monster_list:
		if typeof(monster) != TYPE_DICTIONARY:
			continue
		entries.append(monster)

	if entries.is_empty():
		return []

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _sort_value(a) < _sort_value(b)
	)

	var boss_entry: Dictionary = {}
	for entry in entries:
		if str(entry.get("monster_role", "normal_enemy")) == "boss_enemy":
			boss_entry = entry
			break

	if boss_entry.is_empty():
		boss_entry = entries[entries.size() - 1]

	var non_boss_entries: Array = []
	for entry in entries:
		if str(entry.get("monster_id", "")) == str(boss_entry.get("monster_id", "")):
			continue
		non_boss_entries.append(entry)

	var elite_pool: Array = []
	var normal_pool: Array = []
	for entry in non_boss_entries:
		if str(entry.get("monster_role", "normal_enemy")) == "elite_enemy":
			elite_pool.append(entry)
		else:
			normal_pool.append(entry)

	var boss_guards: Array = []
	while boss_guards.size() < 2 and not elite_pool.is_empty():
		boss_guards.append(elite_pool.pop_front())
	while boss_guards.size() < 2 and not normal_pool.is_empty():
		boss_guards.append(normal_pool.pop_front())

	var guard_ids := {}
	for guard in boss_guards:
		guard_ids[str(guard.get("monster_id", ""))] = true

	var field_elites: Array = []
	for elite in elite_pool:
		if guard_ids.has(str(elite.get("monster_id", ""))):
			continue
		field_elites.append(elite)

	var normals: Array = []
	for normal in normal_pool:
		if guard_ids.has(str(normal.get("monster_id", ""))):
			continue
		normals.append(normal)

	var rng := RandomNumberGenerator.new()
	rng.seed = _build_seed("%s|%d" % [battle_context_id, entries.size()])
	var normal_anchors := NORMAL_PATROL_ANCHORS.duplicate(true)
	var elite_anchors := ELITE_GUARD_ANCHORS.duplicate(true)
	_shuffle_array(normal_anchors, rng)
	_shuffle_array(elite_anchors, rng)

	var layout: Array = []
	layout.append(_build_layout_entry(
		boss_entry,
		BOSS_ANCHOR,
		BOSS_ANCHOR,
		"boss_zone",
		"Boss 终点位",
		"boss_enemy",
		false
	))

	for index in range(boss_guards.size()):
		var guard_entry: Dictionary = boss_guards[index]
		var anchor: Vector2 = BOSS_GUARD_ANCHORS[min(index, BOSS_GUARD_ANCHORS.size() - 1)]
		layout.append(_build_layout_entry(
			guard_entry,
			anchor,
			anchor,
			"boss_guard",
			"Boss 护卫位",
			"elite_enemy",
			str(guard_entry.get("monster_role", "normal_enemy")) != "elite_enemy"
		))

	for index in range(field_elites.size()):
		var elite_entry: Dictionary = field_elites[index]
		var anchor: Vector2 = elite_anchors[index % elite_anchors.size()]
		layout.append(_build_layout_entry(
			elite_entry,
			anchor,
			anchor,
			"elite_guard",
			"精英守点",
			"elite_enemy",
			false
		))

	for index in range(normals.size()):
		var normal_entry: Dictionary = normals[index]
		var anchor: Vector2 = normal_anchors[index % normal_anchors.size()]
		layout.append(_build_layout_entry(
			normal_entry,
			anchor,
			anchor,
			"normal_patrol",
			"普通巡逻点",
			"normal_enemy",
			false
		))

	layout.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _layout_sort_value(a) < _layout_sort_value(b)
	)
	return layout


static func build_initial_summary(prepare_payload: Dictionary, route_context: Dictionary, layout: Array) -> Dictionary:
	var summary := {
		"battle_context_id": str(prepare_payload.get("battle_context_id", "")).strip_edges(),
		"stage_difficulty_id": str(
			_as_dictionary(prepare_payload.get("stage_difficulty", {})).get(
				"stage_difficulty_id",
				route_context.get("stage_difficulty_id", "")
			)
		).strip_edges(),
		"chapter_name": str(route_context.get("chapter_name", "")).strip_edges(),
		"stage_name": str(route_context.get("stage_name", "")).strip_edges(),
		"difficulty_name": str(route_context.get("difficulty_name", "")).strip_edges(),
		"map_width_screens": MAP_WIDTH_SCREENS,
		"map_height_screens": MAP_HEIGHT_SCREENS,
		"monster_total_count": layout.size(),
		"remaining_monster_count": layout.size(),
		"normal_total_count": 0,
		"elite_total_count": 0,
		"boss_total_count": 0,
		"remaining_normal_count": 0,
		"remaining_elite_count": 0,
		"remaining_boss_count": 0,
		"boss_monster_id": "",
		"boss_defeated": false,
		"boss_defeated_elapsed_seconds": 0.0,
		"full_clear_completed": false,
		"full_clear_elapsed_seconds": 0.0,
		"boss_loot_ready": false,
		"settled": false,
		"settle_route": "explore",
		"full_clear_recorded": false,
		"defeated_monster_ids": [],
	}

	for entry in layout:
		var presentation_role := str(entry.get("presentation_role", "normal_enemy"))
		match presentation_role:
			"boss_enemy":
				summary["boss_total_count"] = int(summary.get("boss_total_count", 0)) + 1
				summary["remaining_boss_count"] = int(summary.get("remaining_boss_count", 0)) + 1
				summary["boss_monster_id"] = str(entry.get("monster_id", "")).strip_edges()
			"elite_enemy":
				summary["elite_total_count"] = int(summary.get("elite_total_count", 0)) + 1
				summary["remaining_elite_count"] = int(summary.get("remaining_elite_count", 0)) + 1
			_:
				summary["normal_total_count"] = int(summary.get("normal_total_count", 0)) + 1
				summary["remaining_normal_count"] = int(summary.get("remaining_normal_count", 0)) + 1

	return summary


static func is_in_boss_zone(anchor: Vector2) -> bool:
	return BOSS_ZONE.has_point(anchor)


static func anchor_to_world(anchor: Vector2, world_size: Vector2) -> Vector2:
	return Vector2(anchor.x * world_size.x, anchor.y * world_size.y)


static func world_rect_from_anchor_rect(anchor_rect: Rect2, world_size: Vector2) -> Rect2:
	return Rect2(
		anchor_rect.position.x * world_size.x,
		anchor_rect.position.y * world_size.y,
		anchor_rect.size.x * world_size.x,
		anchor_rect.size.y * world_size.y
	)


static func map_sections() -> Array:
	return MAP_SECTIONS.duplicate(true)


static func build_route_note(summary: Dictionary) -> String:
	var stage_name := str(summary.get("stage_name", "当前副本")).strip_edges()
	var difficulty_name := str(summary.get("difficulty_name", "当前难度")).strip_edges()
	return "%s / %s：固定 2x4 地图，Boss 固定在终点区。" % [stage_name, difficulty_name]


static func _build_layout_entry(
	entry: Dictionary,
	spawn_anchor: Vector2,
	guard_anchor: Vector2,
	area_key: String,
	area_label: String,
	presentation_role: String,
	is_promoted_elite_guard: bool
) -> Dictionary:
	var actual_role := str(entry.get("monster_role", "normal_enemy")).strip_edges()
	var max_combat_hp := 1
	if presentation_role == "elite_enemy":
		max_combat_hp = 2
	elif presentation_role == "boss_enemy":
		max_combat_hp = 4

	return {
		"monster_id": str(entry.get("monster_id", "")).strip_edges(),
		"monster_name": str(entry.get("monster_name", "敌人")).strip_edges(),
		"monster_role": actual_role,
		"presentation_role": presentation_role,
		"wave_no": int(entry.get("wave_no", 1)),
		"sort_order": int(entry.get("sort_order", 1)),
		"spawn_anchor": spawn_anchor,
		"guard_anchor": guard_anchor,
		"area_key": area_key,
		"area_label": area_label,
		"is_promoted_elite_guard": is_promoted_elite_guard,
		"max_combat_hp": max_combat_hp,
	}


static func _sort_value(entry: Dictionary) -> String:
	var role_priority := "2"
	match str(entry.get("monster_role", "normal_enemy")):
		"boss_enemy":
			role_priority = "0"
		"elite_enemy":
			role_priority = "1"
		_:
			role_priority = "2"

	return "%s-%04d-%04d-%s" % [
		role_priority,
		int(entry.get("wave_no", 1)),
		int(entry.get("sort_order", 1)),
		str(entry.get("monster_id", "")),
	]


static func _layout_sort_value(entry: Dictionary) -> String:
	var area_priority := "3"
	match str(entry.get("area_key", "")):
		"boss_zone":
			area_priority = "0"
		"boss_guard":
			area_priority = "1"
		"elite_guard":
			area_priority = "2"
		_:
			area_priority = "3"
	return "%s-%s" % [area_priority, str(entry.get("monster_id", ""))]


static func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current = values[index]
		values[index] = values[swap_index]
		values[swap_index] = current


static func _build_seed(text: String) -> int:
	var seed := 17
	var bytes := text.to_utf8_buffer()
	for byte in bytes:
		seed = int((seed * 31 + int(byte)) % 2147483647)
	return seed


static func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}

extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneBattlePage

const LANE_TINT := Color(0.32, 0.57, 0.74, 1.0)
const PLAYER_TINT := Color(0.52, 0.86, 0.64, 1.0)
const MONSTER_TINT := Color(0.95, 0.58, 0.48, 1.0)
const BOSS_TINT := Color(0.98, 0.78, 0.44, 1.0)

var route_title_label: Label
var route_meta_label: Label
var battle_hint_label: Label
var battle_context_label: Label
var progress_label: Label
var player_position_label: Label
var target_status_label: Label

var battle_view: Control
var battle_world: Control
var movement_status_label: Label
var control_hint_label: Label
var skill_button: Button

var _route_context: Dictionary = {}
var _prepare_payload: Dictionary = {}
var _reward_status: Dictionary = {}
var _monster_states: Array = []
var _marker_nodes: Dictionary = {}
var _player_node: PanelContainer

var _world_height := 780.0
var _lane_center_x := 180.0
var _lane_half_width := 82.0
var _player_position := Vector2(180.0, 660.0)
var _camera_y := 0.0
var _settle_requested := false


func _init() -> void:
	setup_page(
		"战斗",
		[
			"本轮战斗页先建立竖版空间感，不重做复杂 AI 和大量特效。",
			"玩家走位以纵向为主，横向只保留少量偏移；战斗结束后仍走真实 settle 接口。",
		]
	)

	var header_card := add_card("战场信息", "角色会尽量保持在屏幕中下区域，前方保留视野。")
	route_title_label = Label.new()
	route_title_label.add_theme_font_size_override("font_size", 22)
	header_card.add_child(route_title_label)

	route_meta_label = Label.new()
	route_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(route_meta_label)

	battle_hint_label = Label.new()
	battle_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_hint_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(battle_hint_label)

	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(progress_label)

	player_position_label = Label.new()
	player_position_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(player_position_label)

	target_status_label = Label.new()
	target_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_status_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(target_status_label)

	var arena_card := add_card("竖版战斗空间", "地图高度约为视区的 1.4 倍，角色前进时镜头会轻微跟随。")
	battle_view = Control.new()
	battle_view.custom_minimum_size = Vector2(0, 560)
	battle_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_view.clip_contents = true
	battle_view.resized.connect(_on_battle_view_resized)
	arena_card.add_child(battle_view)

	battle_world = Control.new()
	battle_world.position = Vector2.ZERO
	battle_view.add_child(battle_world)

	movement_status_label = Label.new()
	movement_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movement_status_label.modulate = CARD_TEXT_MUTED
	arena_card.add_child(movement_status_label)

	var action_card := add_card("技能与操作", "先做最小战斗闭环：位移、技能、撤退/收束，避免把战斗页继续做成表单。")
	battle_context_label = Label.new()
	battle_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_context_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(battle_context_label)

	control_hint_label = Label.new()
	control_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_hint_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(control_hint_label)

	var movement_buttons := add_button_row(action_card)
	add_button(movement_buttons, "侧移左", func() -> void:
		_move_player(Vector2(-38.0, 0.0), "侧移避让")
	)
	add_button(movement_buttons, "前压", func() -> void:
		_move_player(Vector2(0.0, -56.0), "向前推进")
	)
	add_button(movement_buttons, "侧移右", func() -> void:
		_move_player(Vector2(38.0, 0.0), "侧移拉扯")
	)
	add_button(movement_buttons, "后撤", func() -> void:
		_move_player(Vector2(0.0, 40.0), "后撤调整站位")
	)

	var battle_buttons := add_button_row(action_card)
	skill_button = add_button(battle_buttons, "释放技能", _use_skill)
	style_primary_button(skill_button)
	add_button(battle_buttons, "安全撤离", func() -> void:
		_request_settle(false)
	)

	reset_battle_space()


func load_battle(payload: Dictionary, route_context: Dictionary, reward_status: Dictionary) -> void:
	_prepare_payload = payload.duplicate(true)
	_route_context = route_context.duplicate(true)
	_reward_status = reward_status.duplicate(true)
	_settle_requested = false
	_build_monster_states()
	_sync_header()
	_sync_world()
	set_page_state("success", "Prepare 已承接到战斗页，可以先走位，再处理敌人。")
	set_output_json(payload)


func reset_battle_space() -> void:
	_prepare_payload = {}
	_route_context = {}
	_reward_status = {}
	_monster_states = []
	_marker_nodes = {}
	_settle_requested = false
	route_title_label.text = "等待战斗上下文"
	route_meta_label.text = "先在出战确认页完成 prepare，再进入战斗空间。"
	battle_hint_label.text = "当前没有战斗地图。"
	progress_label.text = "战场进度：还没有敌方数据。"
	player_position_label.text = "当前位置：等待战斗开始。"
	target_status_label.text = "当前目标：等待 Prepare 承接敌方信息。"
	battle_context_label.text = "本次战斗上下文尚未生成。"
	control_hint_label.text = "先在出战页锁定角色和难度，战斗页会自动承接路线与敌方信息。"
	movement_status_label.text = "前进、横移和技能会在 prepare 成功后解锁。"
	clear_container(battle_world)
	set_output_json({})


func allow_retry_settle() -> void:
	_settle_requested = false


func _build_monster_states() -> void:
	_monster_states.clear()

	var visible_height: float = maxf(battle_view.size.y, 560.0)
	_world_height = max(visible_height * 1.42, 760.0)
	_lane_center_x = max(battle_view.size.x * 0.5, 180.0)
	_lane_half_width = clampf(battle_view.size.x * 0.18, 70.0, 96.0)
	_player_position = Vector2(_lane_center_x, _world_height - 120.0)
	_camera_y = clampf(_player_position.y - visible_height * 0.68, 0.0, _world_height - visible_height)

	var monsters: Array = _prepare_payload.get("monster_list", []) if typeof(_prepare_payload.get("monster_list", [])) == TYPE_ARRAY else []
	var total_count: int = maxi(monsters.size(), 1)

	for index in range(monsters.size()):
		var entry: Dictionary = monsters[index] if typeof(monsters[index]) == TYPE_DICTIONARY else {}
		var y_ratio: float = clampf(0.68 - float(index) * (0.42 / float(total_count)), 0.18, 0.7)
		var x_offset := 0.0
		if index % 3 == 0:
			x_offset = -_lane_half_width * 0.55
		elif index % 3 == 2:
			x_offset = _lane_half_width * 0.55

		_monster_states.append({
			"monster_id": str(entry.get("monster_id", "")),
			"monster_name": str(entry.get("monster_name", "敌人")),
			"monster_role": str(entry.get("monster_role", "normal_enemy")),
			"wave_no": int(entry.get("wave_no", 1)),
			"base_hp": int(entry.get("base_hp", 0)),
			"base_attack": int(entry.get("base_attack", 0)),
			"alive": true,
			"world_position": Vector2(_lane_center_x + x_offset, _world_height * y_ratio),
		})


func _sync_header() -> void:
	var chapter_name := str(_route_context.get("chapter_name", "章节"))
	var stage_name := str(_route_context.get("stage_name", "关卡"))
	var difficulty_name := str(_route_context.get("difficulty_name", "难度"))
	route_title_label.text = "%s / %s / %s" % [chapter_name, stage_name, difficulty_name]
	route_meta_label.text = "角色 %s | 推荐战力 %s | 路线已锁定" % [
		str(_prepare_payload.get("character", {}).get("character_name", "未准备")),
		str(_route_context.get("recommended_power", "-")),
	]

	if _reward_status.is_empty():
		battle_hint_label.text = "首通奖励状态：等结算页回读。"
	elif int(_reward_status.get("has_reward", 0)) == 0:
		battle_hint_label.text = "首通奖励状态：当前难度没有首通奖励。"
	elif int(_reward_status.get("has_granted", 0)) == 1:
		battle_hint_label.text = "首通奖励状态：已领取，本次重点看掉落与入包。"
	else:
		battle_hint_label.text = "首通奖励状态：未领取，若首通成功会在结算页展示。"

	battle_context_label.text = "战斗上下文已锁定；完整 battle_context_id 可在技术详情查看。"
	control_hint_label.text = "战斗区负责推进与找目标，底部操作区负责位移、出手和安全收束。"
	_refresh_progress_text()
	_refresh_status_panels()


func _sync_world() -> void:
	clear_container(battle_world)
	_marker_nodes.clear()

	var view_width: float = maxf(battle_view.size.x, 320.0)
	var view_height: float = maxf(battle_view.size.y, 560.0)
	battle_world.size = Vector2(view_width, _world_height)
	battle_world.custom_minimum_size = Vector2(view_width, _world_height)

	var sky := ColorRect.new()
	sky.color = Color(0.07, 0.12, 0.18, 1.0)
	sky.position = Vector2.ZERO
	sky.size = Vector2(view_width, _world_height)
	battle_world.add_child(sky)

	var lane := ColorRect.new()
	lane.color = Color(LANE_TINT.r, LANE_TINT.g, LANE_TINT.b, 0.18)
	lane.position = Vector2(_lane_center_x - 72.0, 0.0)
	lane.size = Vector2(144.0, _world_height)
	battle_world.add_child(lane)

	for lane_index in range(5):
		var mark := ColorRect.new()
		mark.color = Color(0.85, 0.92, 0.98, 0.12)
		mark.position = Vector2(_lane_center_x - 6.0, float(lane_index) * (_world_height / 5.0) + 36.0)
		mark.size = Vector2(12.0, 80.0)
		battle_world.add_child(mark)

	for monster_state in _monster_states:
		var monster_id := str(monster_state.get("monster_id", ""))
		var marker := _build_marker(
			str(monster_state.get("monster_name", "敌人")),
			BOSS_TINT if str(monster_state.get("monster_role", "")) == "boss_enemy" else MONSTER_TINT
		)
		marker.position = Vector2.ZERO
		battle_world.add_child(marker)
		_marker_nodes[monster_id] = marker

	_player_node = _build_marker("我方", PLAYER_TINT)
	battle_world.add_child(_player_node)
	_refresh_world_positions()


func _build_marker(text: String, tint: Color) -> PanelContainer:
	var marker := PanelContainer.new()
	marker.size = Vector2(112.0, 44.0)
	marker.custom_minimum_size = Vector2(112.0, 44.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.18)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.75)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	marker.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	marker.add_child(margin)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return marker


func _refresh_world_positions() -> void:
	var visible_height: float = maxf(battle_view.size.y, 560.0)
	var target_camera_y: float = clampf(_player_position.y - visible_height * 0.68, 0.0, _world_height - visible_height)
	_camera_y = lerpf(_camera_y, target_camera_y, 0.4)
	battle_world.position = Vector2(0.0, -_camera_y)

	for monster_state in _monster_states:
		var monster_id := str(monster_state.get("monster_id", ""))
		var marker: PanelContainer = _marker_nodes.get(monster_id)
		if marker == null:
			continue
		var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
		marker.position = Vector2(world_position.x - marker.size.x * 0.5, world_position.y - marker.size.y * 0.5)
		marker.visible = bool(monster_state.get("alive", false))

	_player_node.position = Vector2(
		_player_position.x - _player_node.size.x * 0.5,
		_player_position.y - _player_node.size.y * 0.5
	)


func _move_player(delta: Vector2, label_text: String) -> void:
	if _prepare_payload.is_empty():
		set_page_state("empty", "请先完成出战确认，再进入战斗。")
		return

	if _settle_requested:
		return

	_player_position.x = clampf(_player_position.x + delta.x, _lane_center_x - _lane_half_width, _lane_center_x + _lane_half_width)
	_player_position.y = clampf(_player_position.y + delta.y, 96.0, _world_height - 96.0)
	movement_status_label.text = "%s | 当前站位 y=%.0f / %.0f" % [label_text, _player_position.y, _world_height]
	_refresh_world_positions()
	_refresh_status_panels()


func _use_skill() -> void:
	if _prepare_payload.is_empty():
		set_page_state("empty", "请先完成出战确认，再进入战斗。")
		return

	if _settle_requested:
		return

	var target_index := _find_attack_target_index()
	if target_index < 0:
		movement_status_label.text = "目标还在前方，继续前压或横移寻找出手机会。"
		return

	var target: Dictionary = _monster_states[target_index]
	target["alive"] = false
	_monster_states[target_index] = target
	movement_status_label.text = "技能命中 %s，已从战场清除。" % str(target.get("monster_name", "敌人"))
	_refresh_world_positions()
	_refresh_progress_text()
	_refresh_status_panels()

	if _alive_monster_count() == 0:
		set_page_state("success", "敌方已清空，正在进入结算页。")
		_request_settle(true)


func _find_attack_target_index() -> int:
	var best_index := -1
	var best_score := 999999.0

	for index in range(_monster_states.size()):
		var target: Dictionary = _monster_states[index]
		if not bool(target.get("alive", false)):
			continue
		var world_position: Vector2 = target.get("world_position", Vector2.ZERO)
		var dx := absf(world_position.x - _player_position.x)
		var dy := _player_position.y - world_position.y
		if dy < -24.0:
			continue
		if dx > 84.0 or absf(dy) > 138.0:
			continue

		var score := absf(dy) + dx
		if score < best_score:
			best_score = score
			best_index = index

	return best_index


func _request_settle(is_cleared: bool) -> void:
	if _prepare_payload.is_empty() or _settle_requested:
		return

	_settle_requested = true
	var killed_monsters: Array = []
	for monster_state in _monster_states:
		if not bool(monster_state.get("alive", false)):
			killed_monsters.append(str(monster_state.get("monster_id", "")))

	if killed_monsters.is_empty():
		_settle_requested = false
		set_page_state("error", "至少击败一个敌人后，才能提交当前战斗的正式结算。")
		movement_status_label.text = "先继续前压或释放技能，形成最小合法结算结果。"
		return

	_emit_action("battle_request_settle", {
		"character_id": _prepare_payload.get("character", {}).get("character_id", 0),
		"stage_difficulty_id": _prepare_payload.get("stage_difficulty", {}).get("stage_difficulty_id", ""),
		"battle_context_id": _prepare_payload.get("battle_context_id", ""),
		"killed_monsters": killed_monsters,
		"is_cleared": 1 if is_cleared else 0,
	})


func _alive_monster_count() -> int:
	var count := 0
	for monster_state in _monster_states:
		if bool(monster_state.get("alive", false)):
			count += 1
	return count


func _refresh_progress_text() -> void:
	var remaining := _alive_monster_count()
	var defeated := _monster_states.size() - remaining
	progress_label.text = "战场进度：已击败 %d / %d，剩余 %d。" % [defeated, _monster_states.size(), remaining]


func _refresh_status_panels() -> void:
	player_position_label.text = "当前位置：%s" % _describe_player_position()
	target_status_label.text = "当前目标：%s" % _describe_target_state()


func _describe_player_position() -> String:
	if _prepare_payload.is_empty():
		return "等待 Prepare"

	var progress_ratio := clampf(1.0 - (_player_position.y / maxf(_world_height, 1.0)), 0.0, 1.0)
	var lane_side := "中线"
	if _player_position.x < _lane_center_x - _lane_half_width * 0.3:
		lane_side = "左侧"
	elif _player_position.x > _lane_center_x + _lane_half_width * 0.3:
		lane_side = "右侧"

	if progress_ratio < 0.28:
		return "%s后排，仍在观察前方。" % lane_side
	if progress_ratio < 0.58:
		return "%s中段，已经进入接敌区域。" % lane_side
	return "%s前线，准备收掉最后目标。" % lane_side


func _describe_target_state() -> String:
	if _prepare_payload.is_empty():
		return "等待敌方承接。"

	var target := _find_next_target()
	if target.is_empty():
		return "敌方已清空，可以直接进入结算。"

	var world_position: Vector2 = target.get("world_position", Vector2.ZERO)
	var dx := absf(world_position.x - _player_position.x)
	var dy := _player_position.y - world_position.y
	var in_range := dx <= 84.0 and dy >= -24.0 and absf(dy) <= 138.0
	var range_text := "已经进入出手机会" if in_range else "还需要再前压一点"
	return "%s（第 %s 波，%s，%s）" % [
		str(target.get("monster_name", "敌人")),
		str(target.get("wave_no", 1)),
		"首领" if str(target.get("monster_role", "")) == "boss_enemy" else "普通敌人",
		range_text,
	]


func _find_next_target() -> Dictionary:
	var best_target: Dictionary = {}
	var best_score := 999999.0

	for monster_state in _monster_states:
		if not bool(monster_state.get("alive", false)):
			continue
		var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
		var score := absf(_player_position.y - world_position.y) + absf(_player_position.x - world_position.x) * 0.25
		if score < best_score:
			best_score = score
			best_target = monster_state

	return best_target


func _on_battle_view_resized() -> void:
	if _prepare_payload.is_empty():
		return
	_build_monster_states()
	_sync_world()
	_refresh_status_panels()

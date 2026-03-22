extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneBattlePage

const LANE_TINT := Color(0.32, 0.57, 0.74, 1.0)
const PLAYER_TINT := Color(0.52, 0.86, 0.64, 1.0)
const MONSTER_TINT := Color(0.95, 0.58, 0.48, 1.0)
const BOSS_TINT := Color(0.98, 0.78, 0.44, 1.0)
const DROP_TINT := Color(0.97, 0.86, 0.52, 1.0)
const ENEMY_ZONE_TINT := Color(0.58, 0.22, 0.20, 1.0)
const PLAYER_ZONE_TINT := Color(0.20, 0.36, 0.30, 1.0)

const MARKER_SIZE := Vector2(118.0, 46.0)
const DROP_MARKER_SIZE := Vector2(96.0, 34.0)
const PLAYER_MOVE_LERP := 10.0
const PLAYER_ATTACK_RANGE_X := 84.0
const PLAYER_ATTACK_RANGE_Y := 138.0
const MONSTER_PRESSURE_RANGE_X := 72.0
const MONSTER_PRESSURE_RANGE_Y := 126.0
const PLAYER_HIT_FEEDBACK_SECONDS := 0.22
const PLAYER_ATTACK_FEEDBACK_SECONDS := 0.18
const MONSTER_DEATH_FEEDBACK_SECONDS := 0.34
const FINISH_PAUSE_SECONDS := 0.90
const MESSAGE_COOLDOWN_SECONDS := 0.38

var route_title_label: Label
var route_meta_label: Label
var battle_hint_label: Label
var battle_state_label: Label
var progress_label: Label
var target_status_label: Label
var pause_button: Button

var battle_view: Control
var battle_world: Control
var drop_status_label: Label
var movement_status_label: Label
var player_feedback_label: Label
var player_status_label: Label
var player_position_label: Label
var skill_button: Button

var _route_context: Dictionary = {}
var _prepare_payload: Dictionary = {}
var _reward_status: Dictionary = {}
var _monster_states: Array = []
var _marker_nodes: Dictionary = {}
var _feedback_nodes: Array = []
var _drop_nodes: Array = []
var _player_node: PanelContainer

var _world_height := 800.0
var _lane_center_x := 180.0
var _lane_half_width := 82.0
var _player_position := Vector2(180.0, 660.0)
var _player_visual_position := Vector2(180.0, 660.0)
var _camera_y := 0.0
var _player_hit_timer := 0.0
var _player_attack_burst_timer := 0.0
var _screen_shake_timer := 0.0
var _screen_shake_strength := 0.0
var _message_cooldown := 0.0
var _battle_phase := "idle"
var _battle_state_text := "等待战斗"
var _player_status_text := "等待 Prepare"
var _drop_preview_count := 0
var _presentation_dirty := false
var _settle_requested := false
var _finish_sequence_id := 0


func _ready() -> void:
	set_process(true)


func _init() -> void:
	setup_page("战斗", [])

	var header_card := add_card("战场", "")
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

	battle_state_label = Label.new()
	battle_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_state_label.add_theme_font_size_override("font_size", 18)
	header_card.add_child(battle_state_label)

	progress_label = Label.new()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_card.add_child(progress_label)

	target_status_label = Label.new()
	target_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_status_label.modulate = BODY_TEXT
	header_card.add_child(target_status_label)

	var header_buttons := add_button_row(header_card)
	add_action_button(header_buttons, "回出战确认", "navigate_prepare")
	pause_button = add_button(header_buttons, "暂停", _toggle_pause)

	var arena_card := add_card("竖版战场", "")
	battle_view = Control.new()
	battle_view.custom_minimum_size = Vector2(0, 590)
	battle_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_view.clip_contents = true
	battle_view.resized.connect(_on_battle_view_resized)
	arena_card.add_child(battle_view)

	battle_world = Control.new()
	battle_world.position = Vector2.ZERO
	battle_view.add_child(battle_world)

	var action_card := add_card("操作", "")

	player_feedback_label = Label.new()
	player_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(player_feedback_label)

	player_status_label = Label.new()
	player_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(player_status_label)

	player_position_label = Label.new()
	player_position_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_position_label.modulate = BODY_TEXT
	action_card.add_child(player_position_label)

	movement_status_label = Label.new()
	movement_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movement_status_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(movement_status_label)

	drop_status_label = Label.new()
	drop_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drop_status_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(drop_status_label)

	var attack_row := add_button_row(action_card)
	add_button(attack_row, "左移", func() -> void:
		_move_player(Vector2(-30.0, 0.0), "左移试探")
	)
	skill_button = add_button(attack_row, "攻击", _use_skill)
	style_primary_button(skill_button)
	add_button(attack_row, "右移", func() -> void:
		_move_player(Vector2(30.0, 0.0), "右移拉扯")
	)

	var movement_row := add_button_row(action_card)
	add_button(movement_row, "前压", func() -> void:
		_move_player(Vector2(0.0, -52.0), "前压接敌")
	)
	add_button(movement_row, "后撤", func() -> void:
		_move_player(Vector2(0.0, 36.0), "后撤调整")
	)
	add_button(movement_row, "收束/结束", func() -> void:
		_request_settle(false)
	)

	reset_battle_space()
	_move_secondary_sections_to_bottom()


func _process(delta: float) -> void:
	if _prepare_payload.is_empty():
		return

	_player_visual_position = _player_visual_position.lerp(
		_player_position,
		clampf(delta * PLAYER_MOVE_LERP, 0.0, 1.0)
	)
	_player_hit_timer = maxf(_player_hit_timer - delta, 0.0)
	_player_attack_burst_timer = maxf(_player_attack_burst_timer - delta, 0.0)
	_screen_shake_timer = maxf(_screen_shake_timer - delta, 0.0)
	_message_cooldown = maxf(_message_cooldown - delta, 0.0)

	_update_monster_motion(delta)
	_update_feedback_nodes(delta)
	_update_drop_nodes(delta)
	_refresh_world_positions()
	_refresh_status_panels()
	_update_interaction_state()


func load_battle(payload: Dictionary, route_context: Dictionary, reward_status: Dictionary) -> void:
	_prepare_payload = payload.duplicate(true)
	_route_context = route_context.duplicate(true)
	_reward_status = reward_status.duplicate(true)
	_settle_requested = false
	_finish_sequence_id += 1
	_build_monster_states()
	_sync_header()
	_sync_world()
	set_page_state("success", "敌人已经出现，先接敌、压位，再让正式结算自然承接。")
	set_output_json(payload)


func reset_battle_space() -> void:
	_prepare_payload = {}
	_route_context = {}
	_reward_status = {}
	_monster_states = []
	_marker_nodes = {}
	_feedback_nodes = []
	_drop_nodes = []
	_settle_requested = false
	_finish_sequence_id += 1
	_drop_preview_count = 0
	_presentation_dirty = false
	_battle_phase = "idle"
	_battle_state_text = "等待战斗"
	_player_status_text = "等待 Prepare"
	_player_hit_timer = 0.0
	_player_attack_burst_timer = 0.0
	_screen_shake_timer = 0.0
	_screen_shake_strength = 0.0
	_message_cooldown = 0.0
	route_title_label.text = "等待战斗上下文"
	route_meta_label.text = "先回出战页锁定角色和目标，再进入战场。"
	battle_hint_label.text = "玩家会在中下区域迎敌，怪物会从中上区域继续压近。"
	battle_state_label.text = "战场状态：等待战斗开始。"
	progress_label.text = "战场进度：还没有敌方数据。"
	target_status_label.text = "当前目标：等待敌方入场。"
	drop_status_label.text = "掉落显现：敌人倒下后会短暂出现战利品影子。"
	movement_status_label.text = "可用动作：前压、左右微调、后撤、攻击、收束。"
	player_feedback_label.text = "前线反馈：等待战斗开始。"
	player_status_label.text = "状态：先在出战页确认角色与难度。"
	player_position_label.text = "当前位置：等待 Battle 页承接。"
	clear_container(battle_world)
	set_output_json({})
	_update_interaction_state()


func allow_retry_settle() -> void:
	_settle_requested = false
	if _prepare_payload.is_empty():
		return

	_battle_phase = "finish_pause" if _alive_monster_count() == 0 else "interactive"
	_battle_state_text = "可再次收束"
	_player_status_text = "正式结算未完成，可继续提交"
	movement_status_label.text = "这一场还没正式收束，可以继续整理站位后再试一次。"
	_update_interaction_state()
	_refresh_status_panels()


func _build_monster_states() -> void:
	_monster_states.clear()
	_feedback_nodes.clear()
	_drop_nodes.clear()
	_drop_preview_count = 0
	_presentation_dirty = false
	_player_hit_timer = 0.0
	_player_attack_burst_timer = 0.0
	_screen_shake_timer = 0.0
	_screen_shake_strength = 0.0
	_message_cooldown = 0.0
	_battle_phase = "interactive"
	_battle_state_text = "已承接战场"
	_player_status_text = "整队推进"

	var visible_height: float = maxf(battle_view.size.y, 560.0)
	var view_width: float = maxf(battle_view.size.x, 320.0)
	_world_height = maxf(visible_height * 1.46, 800.0)
	_lane_center_x = maxf(view_width * 0.5, 180.0)
	_lane_half_width = clampf(view_width * 0.15, 62.0, 88.0)
	_player_position = Vector2(_lane_center_x, _world_height * 0.78)
	_player_visual_position = _player_position
	_camera_y = clampf(_player_position.y - visible_height * 0.70, 0.0, _world_height - visible_height)

	var monsters: Array = _prepare_payload.get("monster_list", []) if typeof(_prepare_payload.get("monster_list", [])) == TYPE_ARRAY else []
	var spread_divisor := float(maxi(monsters.size() - 1, 1))

	for index in range(monsters.size()):
		var entry: Dictionary = monsters[index] if typeof(monsters[index]) == TYPE_DICTIONARY else {}
		var spawn_ratio: float = clampf(0.20 + float(index) * (0.28 / spread_divisor), 0.20, 0.56)
		var x_offset := 0.0
		if index % 3 == 0:
			x_offset = -_lane_half_width * 0.48
		elif index % 3 == 2:
			x_offset = _lane_half_width * 0.48

		var spawn_position := Vector2(_lane_center_x + x_offset, _world_height * spawn_ratio)
		var monster_role := str(entry.get("monster_role", "normal_enemy"))
		var wave_no := int(entry.get("wave_no", 1))
		var front_position := _build_front_position(spawn_position, wave_no, x_offset)
		var presentation_speed := 92.0 + float(maxi(wave_no - 1, 0)) * 8.0 + float(index % 2) * 6.0
		if monster_role == "boss_enemy":
			presentation_speed = maxf(presentation_speed - 10.0, 78.0)

		_monster_states.append({
			"monster_id": str(entry.get("monster_id", "")),
			"monster_name": str(entry.get("monster_name", "敌人")),
			"monster_role": monster_role,
			"wave_no": wave_no,
			"alive": true,
			"dying": false,
			"drop_spawned": false,
			"spawn_position": spawn_position,
			"front_position": front_position,
			"world_position": spawn_position,
			"presentation_speed": presentation_speed,
			"pressure_feedback_played": false,
			"hit_timer": 0.0,
			"death_timer": 0.0,
		})


func _sync_header() -> void:
	var chapter_name := str(_route_context.get("chapter_name", "章节"))
	var stage_name := str(_route_context.get("stage_name", "关卡"))
	var difficulty_name := str(_route_context.get("difficulty_name", "难度"))
	route_title_label.text = "%s / %s / %s" % [chapter_name, stage_name, difficulty_name]
	route_meta_label.text = "当前挑战：%s | 推荐战力 %s | 我方在中下区域迎敌" % [
		str(_prepare_payload.get("character", {}).get("character_name", "未准备")),
		str(_route_context.get("recommended_power", "-")),
	]
	battle_hint_label.text = "怪物会从中上区域继续压近；建议先前压接敌，再配合左右微调找出手机会。"
	_refresh_progress_text()
	_refresh_drop_status()
	_refresh_status_panels()
	_update_interaction_state()


func _sync_world() -> void:
	clear_container(battle_world)
	_marker_nodes.clear()
	_feedback_nodes.clear()
	_drop_nodes.clear()

	var view_width: float = maxf(battle_view.size.x, 320.0)
	var view_height: float = maxf(battle_view.size.y, 560.0)
	battle_world.size = Vector2(view_width, _world_height)
	battle_world.custom_minimum_size = Vector2(view_width, _world_height)

	var sky := ColorRect.new()
	sky.color = Color(0.07, 0.12, 0.18, 1.0)
	sky.position = Vector2.ZERO
	sky.size = Vector2(view_width, _world_height)
	battle_world.add_child(sky)

	var enemy_zone := ColorRect.new()
	enemy_zone.color = Color(ENEMY_ZONE_TINT.r, ENEMY_ZONE_TINT.g, ENEMY_ZONE_TINT.b, 0.12)
	enemy_zone.position = Vector2(0.0, 0.0)
	enemy_zone.size = Vector2(view_width, _world_height * 0.36)
	battle_world.add_child(enemy_zone)

	var drop_zone := ColorRect.new()
	drop_zone.color = Color(DROP_TINT.r, DROP_TINT.g, DROP_TINT.b, 0.08)
	drop_zone.position = Vector2(0.0, _world_height * 0.52)
	drop_zone.size = Vector2(view_width, _world_height * 0.16)
	battle_world.add_child(drop_zone)

	var player_zone := ColorRect.new()
	player_zone.color = Color(PLAYER_ZONE_TINT.r, PLAYER_ZONE_TINT.g, PLAYER_ZONE_TINT.b, 0.11)
	player_zone.position = Vector2(0.0, _world_height * 0.64)
	player_zone.size = Vector2(view_width, _world_height * 0.36)
	battle_world.add_child(player_zone)

	var lane := ColorRect.new()
	lane.color = Color(LANE_TINT.r, LANE_TINT.g, LANE_TINT.b, 0.18)
	lane.position = Vector2(_lane_center_x - (_lane_half_width + 34.0), 0.0)
	lane.size = Vector2((_lane_half_width + 34.0) * 2.0, _world_height)
	battle_world.add_child(lane)

	for lane_index in range(6):
		var mark := ColorRect.new()
		mark.color = Color(0.85, 0.92, 0.98, 0.12)
		mark.position = Vector2(
			_lane_center_x - 5.0,
			float(lane_index) * (_world_height / 6.0) + 30.0
		)
		mark.size = Vector2(10.0, 74.0)
		battle_world.add_child(mark)

	_add_zone_label("敌人刷新区", 48.0)
	_add_zone_label("接敌区", _world_height * 0.40)
	_add_zone_label("掉落出现区", _world_height * 0.58)
	_add_zone_label("玩家活动区", _world_height * 0.80)

	for monster_state in _monster_states:
		var monster_id := str(monster_state.get("monster_id", ""))
		var marker := _build_marker(
			str(monster_state.get("monster_name", "敌人")),
			BOSS_TINT if str(monster_state.get("monster_role", "")) == "boss_enemy" else MONSTER_TINT
		)
		battle_world.add_child(marker)
		_marker_nodes[monster_id] = marker

	_player_node = _build_marker("我方", PLAYER_TINT)
	battle_world.add_child(_player_node)
	_refresh_world_positions()


func _build_marker(text: String, tint: Color) -> PanelContainer:
	var marker := PanelContainer.new()
	marker.size = MARKER_SIZE
	marker.custom_minimum_size = MARKER_SIZE

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


func _build_drop_marker(text: String) -> PanelContainer:
	var marker := PanelContainer.new()
	marker.size = DROP_MARKER_SIZE
	marker.custom_minimum_size = DROP_MARKER_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(DROP_TINT.r, DROP_TINT.g, DROP_TINT.b, 0.20)
	style.border_color = Color(DROP_TINT.r, DROP_TINT.g, DROP_TINT.b, 0.80)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	marker.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	marker.add_child(margin)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return marker


func _refresh_world_positions() -> void:
	if _player_node == null:
		return

	var visible_height: float = maxf(battle_view.size.y, 560.0)
	var target_camera_y: float = clampf(
		_player_visual_position.y - visible_height * 0.70,
		0.0,
		_world_height - visible_height
	)
	_camera_y = lerpf(_camera_y, target_camera_y, 0.32)

	var shake_offset := Vector2.ZERO
	if _screen_shake_timer > 0.0:
		var shake_ratio := _screen_shake_timer / maxf(PLAYER_HIT_FEEDBACK_SECONDS, 0.001)
		shake_offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-0.6, 0.6)
		) * (_screen_shake_strength * shake_ratio)

	battle_world.position = Vector2(shake_offset.x, -_camera_y + shake_offset.y)
	var focus_target_id := str(_find_next_target().get("monster_id", ""))

	for monster_state in _monster_states:
		var monster_id := str(monster_state.get("monster_id", ""))
		var marker = _marker_nodes.get(monster_id, null)
		if marker == null:
			continue

		var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
		var hit_ratio := clampf(
			float(monster_state.get("hit_timer", 0.0)) / maxf(PLAYER_ATTACK_FEEDBACK_SECONDS, 0.001),
			0.0,
			1.0
		)
		var dying := bool(monster_state.get("dying", false))
		var alive := bool(monster_state.get("alive", false))
		var death_ratio := 0.0
		if dying:
			death_ratio = 1.0 - clampf(
				float(monster_state.get("death_timer", 0.0)) / maxf(MONSTER_DEATH_FEEDBACK_SECONDS, 0.001),
				0.0,
				1.0
			)

		marker.position = world_position - MARKER_SIZE * 0.5
		marker.visible = alive or dying

		var scale_value := 1.0
		if alive and monster_id == focus_target_id:
			scale_value += 0.08
		scale_value += hit_ratio * 0.12
		if dying:
			scale_value = lerpf(1.06, 0.76, death_ratio)
		marker.scale = Vector2(scale_value, scale_value)
		marker.z_index = 3 if alive and monster_id == focus_target_id else 1

		if dying:
			var fall_rotation := -7.0 if world_position.x >= _player_visual_position.x else 7.0
			marker.rotation_degrees = lerpf(0.0, fall_rotation, death_ratio)
			marker.modulate = Color(1.0, 0.82 - death_ratio * 0.18, 0.82 - death_ratio * 0.18, 1.0 - death_ratio * 0.55)
		else:
			marker.rotation_degrees = 0.0
			if hit_ratio > 0.0:
				marker.modulate = Color(1.0, 1.0, 1.0, 1.0)
			elif alive and monster_id == focus_target_id:
				marker.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				marker.modulate = Color(0.92, 0.95, 1.0, 0.96)

	var player_render_position := _player_visual_position
	if _player_hit_timer > 0.0:
		player_render_position += Vector2(0.0, 8.0 * (_player_hit_timer / PLAYER_HIT_FEEDBACK_SECONDS))
	elif _player_attack_burst_timer > 0.0:
		player_render_position += Vector2(0.0, -4.0 * (_player_attack_burst_timer / PLAYER_ATTACK_FEEDBACK_SECONDS))

	_player_node.position = player_render_position - MARKER_SIZE * 0.5
	_player_node.z_index = 4

	var player_scale := 1.0 + minf(_player_visual_position.distance_to(_player_position) / 180.0, 0.08)
	if _player_hit_timer > 0.0:
		player_scale += 0.08 * (_player_hit_timer / PLAYER_HIT_FEEDBACK_SECONDS)
	if _player_attack_burst_timer > 0.0:
		player_scale += 0.10 * (_player_attack_burst_timer / PLAYER_ATTACK_FEEDBACK_SECONDS)
	_player_node.scale = Vector2(player_scale, player_scale)

	if _player_hit_timer > 0.0:
		_player_node.modulate = Color(1.0, 0.74, 0.74, 1.0)
	elif _player_attack_burst_timer > 0.0:
		_player_node.modulate = Color(1.0, 0.96, 0.84, 1.0)
	else:
		_player_node.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _move_player(delta: Vector2, label_text: String) -> void:
	if _prepare_payload.is_empty():
		set_page_state("empty", "请先完成出战确认，再进入战斗。")
		return

	if _interaction_locked():
		return

	var next_position := _player_position + delta
	next_position.x = clampf(
		next_position.x,
		_lane_center_x - _lane_half_width,
		_lane_center_x + _lane_half_width
	)
	next_position.y = clampf(next_position.y, 112.0, _world_height - 92.0)
	if next_position.is_equal_approx(_player_position):
		return

	_player_position = next_position
	_presentation_dirty = true
	if delta.y < 0.0:
		_player_status_text = "前压找机会"
	elif delta.y > 0.0:
		_player_status_text = "后撤稳住阵型"
	else:
		_player_status_text = "横移调整角度"

	_battle_state_text = "保持压近"
	movement_status_label.text = "%s | 当前站位 y=%.0f / %.0f" % [
		label_text,
		_player_position.y,
		_world_height,
	]
	_refresh_status_panels()


func _use_skill() -> void:
	if _prepare_payload.is_empty():
		set_page_state("empty", "请先完成出战确认，再进入战斗。")
		return

	if _interaction_locked():
		return

	var target_index := _find_attack_target_index()
	if target_index < 0:
		_player_status_text = "出手落空，继续压位"
		movement_status_label.text = "目标还在前方，继续前压或横移寻找出手机会。"
		_spawn_float_text(
			"未到位",
			_player_visual_position + Vector2(0.0, -58.0),
			Color(0.85, 0.92, 0.98, 1.0),
			0.58
		)
		_bump_screen_shake(1.4, 0.08)
		return

	var target: Dictionary = _monster_states[target_index]
	var world_position: Vector2 = target.get("world_position", Vector2.ZERO)
	var hit_shift := -12.0 if world_position.x >= _player_position.x else 12.0
	target["alive"] = false
	target["dying"] = true
	target["death_timer"] = MONSTER_DEATH_FEEDBACK_SECONDS
	target["hit_timer"] = PLAYER_ATTACK_FEEDBACK_SECONDS
	target["world_position"] = Vector2(world_position.x + hit_shift, world_position.y - 14.0)
	_monster_states[target_index] = target

	_presentation_dirty = true
	_player_attack_burst_timer = PLAYER_ATTACK_FEEDBACK_SECONDS
	_player_status_text = "命中得手，继续推进"
	_battle_state_text = "命中反馈"
	movement_status_label.text = "%s 被命中，战线被向前撕开。" % str(target.get("monster_name", "敌人"))
	_spawn_float_text(
		"命中",
		world_position + Vector2(0.0, -28.0),
		Color(1.0, 0.84, 0.48, 1.0),
		0.72
	)
	_bump_screen_shake(2.6, 0.12)
	_refresh_progress_text()
	_refresh_status_panels()
	_update_interaction_state()

	if _alive_monster_count() == 0:
		_start_finish_sequence()


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
		if dy < -20.0:
			continue
		if dx > PLAYER_ATTACK_RANGE_X or absf(dy) > PLAYER_ATTACK_RANGE_Y:
			continue

		var score := absf(dy) + dx
		if score < best_score:
			best_score = score
			best_index = index

	return best_index


func _request_settle(is_cleared: bool) -> void:
	if _prepare_payload.is_empty() or _settle_requested:
		return

	_finish_sequence_id += 1
	_settle_requested = true
	_battle_phase = "settling"
	_battle_state_text = "收束中"
	_player_status_text = "准备提交正式结算"
	_update_interaction_state()

	var killed_monsters: Array = []
	for monster_state in _monster_states:
		if not bool(monster_state.get("alive", false)):
			killed_monsters.append(str(monster_state.get("monster_id", "")))

	if killed_monsters.is_empty():
		_settle_requested = false
		_battle_phase = "interactive"
		_battle_state_text = "尚未形成有效击杀"
		set_page_state("error", "至少击败一个敌人后，才能提交当前战斗的正式结算。")
		movement_status_label.text = "先继续前压或攻击，打出这一场的第一波击杀。"
		_update_interaction_state()
		return

	movement_status_label.text = "战斗已经收束，正在离开战场。"
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
	if _monster_states.is_empty():
		progress_label.text = "战场进度：还没有敌方数据。"
		return

	var remaining := _alive_monster_count()
	var defeated := _monster_states.size() - remaining
	if _drop_preview_count > 0:
		progress_label.text = "战场进度：已击败 %d / %d，剩余 %d，掉落预热 %d。" % [
			defeated,
			_monster_states.size(),
			remaining,
			_drop_preview_count,
		]
	else:
		progress_label.text = "战场进度：已击败 %d / %d，剩余 %d。" % [
			defeated,
			_monster_states.size(),
			remaining,
		]


func _refresh_drop_status() -> void:
	if _prepare_payload.is_empty():
		drop_status_label.text = "掉落显现：等待战斗开始。"
		return

	if _drop_preview_count <= 0:
		drop_status_label.text = "掉落显现：敌人倒下后会短暂浮出战利品影子。"
	elif _alive_monster_count() == 0:
		drop_status_label.text = "掉落显现：已看到 %d 份战利品影子，战场正在收束。" % _drop_preview_count
	else:
		drop_status_label.text = "掉落显现：已出现 %d 份战利品影子，继续清场后会统一结算。" % _drop_preview_count


func _refresh_status_panels() -> void:
	player_feedback_label.text = "前线反馈：%s" % _describe_player_feedback()
	player_status_label.text = "状态：%s" % _describe_player_status()
	player_position_label.text = "当前位置：%s" % _describe_player_position()
	target_status_label.text = "当前目标：%s" % _describe_target_state()
	battle_state_label.text = "战场状态：%s" % _describe_battle_state()
	_refresh_drop_status()


func _describe_battle_state() -> String:
	if _prepare_payload.is_empty():
		return "等待 Prepare"
	if _battle_phase == "paused":
		return "战场已暂停"
	if _battle_phase == "settling" or _settle_requested:
		return "正式结算提交中"
	if _battle_phase == "finish_pause":
		return "敌方清空，战场收束中"
	if _alive_monster_count() == 0:
		return "敌方已清空"
	if _find_attack_target_index() >= 0:
		return "已接敌，可继续出手"

	return _battle_state_text


func _describe_player_feedback() -> String:
	if _prepare_payload.is_empty():
		return "等待战斗开始。"
	if _battle_phase == "paused":
		return "战场已暂停，当前站位保持不变。"
	if _battle_phase == "settling" or _settle_requested:
		return "战斗已收束，等待结果回传。"
	if _battle_phase == "finish_pause":
		return "最后一击后的短暂停顿已触发。"
	if _player_hit_timer > 0.0:
		return "前线受压反馈已出现。"
	if _player_attack_burst_timer > 0.0:
		return "命中演出进行中。"
	if _alive_monster_count() == 0:
		return "敌方已清空，等待战场收束。"
	if _find_attack_target_index() >= 0:
		return "已进入出手机会。"
	return "以站位推进和轻量演出反馈为主。"


func _describe_player_status() -> String:
	if _prepare_payload.is_empty():
		return "等待战斗开始"
	if _battle_phase == "paused":
		return "战场已暂停，随时可以继续"
	if _battle_phase == "settling" or _settle_requested:
		return "已锁定收束，等待结果"
	if _battle_phase == "finish_pause":
		return "清场完成，等待战场收束"
	if _player_hit_timer > 0.0:
		return "%s，前线受压反馈已出现" % _player_status_text
	if _find_attack_target_index() >= 0:
		return "%s，已进入出手机会" % _player_status_text
	return _player_status_text


func _describe_player_position() -> String:
	if _prepare_payload.is_empty():
		return "等待 Prepare"

	var progress_ratio := clampf(1.0 - (_player_position.y / maxf(_world_height, 1.0)), 0.0, 1.0)
	var lane_side := "中线"
	if _player_position.x < _lane_center_x - _lane_half_width * 0.28:
		lane_side = "左侧"
	elif _player_position.x > _lane_center_x + _lane_half_width * 0.28:
		lane_side = "右侧"

	if progress_ratio < 0.22:
		return "%s中下段，仍在观察前方。" % lane_side
	if progress_ratio < 0.48:
		return "%s接敌区，已经能感到怪物压近。" % lane_side
	return "%s前线，准备完成本轮清场。" % lane_side


func _describe_target_state() -> String:
	if _prepare_payload.is_empty():
		return "等待敌方承接。"

	var target := _find_next_target()
	if target.is_empty():
		return "敌方已清空，可以进入正式结算。"

	var world_position: Vector2 = target.get("world_position", Vector2.ZERO)
	var dx := absf(world_position.x - _player_position.x)
	var dy := _player_position.y - world_position.y
	var in_attack_range := dx <= PLAYER_ATTACK_RANGE_X and dy >= -20.0 and absf(dy) <= PLAYER_ATTACK_RANGE_Y
	var enemy_pressing := dx <= MONSTER_PRESSURE_RANGE_X and dy >= 14.0 and dy <= MONSTER_PRESSURE_RANGE_Y

	var range_text := "已经进入出手机会"
	if not in_attack_range and enemy_pressing:
		range_text = "已经逼近我方前线"
	elif not in_attack_range:
		range_text = "还需要再前压一点"

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


func _update_monster_motion(delta: float) -> void:
	for index in range(_monster_states.size()):
		var monster_state: Dictionary = _monster_states[index]
		if bool(monster_state.get("alive", false)):
			monster_state = _update_alive_monster_state(monster_state, delta)
		elif bool(monster_state.get("dying", false)):
			monster_state = _update_dying_monster_state(monster_state, delta)
		_monster_states[index] = monster_state


func _update_alive_monster_state(monster_state: Dictionary, delta: float) -> Dictionary:
	monster_state["hit_timer"] = maxf(float(monster_state.get("hit_timer", 0.0)) - delta, 0.0)

	var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	var front_position: Vector2 = monster_state.get("front_position", world_position)
	var presentation_speed := float(monster_state.get("presentation_speed", 96.0))
	world_position = world_position.move_toward(front_position, presentation_speed * delta)
	monster_state["world_position"] = world_position

	if _battle_phase == "interactive" and not bool(monster_state.get("pressure_feedback_played", false)) and _monster_has_reached_frontline(monster_state):
		monster_state["pressure_feedback_played"] = true
		_play_player_pressure_feedback(str(monster_state.get("monster_name", "敌人")))

	return monster_state


func _update_dying_monster_state(monster_state: Dictionary, delta: float) -> Dictionary:
	monster_state["hit_timer"] = maxf(float(monster_state.get("hit_timer", 0.0)) - delta, 0.0)

	var death_timer := maxf(float(monster_state.get("death_timer", 0.0)) - delta, 0.0)
	monster_state["death_timer"] = death_timer

	var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	world_position.y = maxf(world_position.y - 12.0 * delta, 64.0)
	monster_state["world_position"] = world_position

	if death_timer <= 0.0:
		monster_state["dying"] = false
		if not bool(monster_state.get("drop_spawned", false)):
			_spawn_drop_preview(monster_state)
			monster_state["drop_spawned"] = true

	return monster_state


func _monster_has_reached_frontline(monster_state: Dictionary) -> bool:
	var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	var dx := absf(world_position.x - _player_position.x)
	var dy := _player_position.y - world_position.y
	return dx <= MONSTER_PRESSURE_RANGE_X and dy >= 14.0 and dy <= MONSTER_PRESSURE_RANGE_Y


func _play_player_pressure_feedback(monster_name: String) -> void:
	_presentation_dirty = true
	_player_hit_timer = PLAYER_HIT_FEEDBACK_SECONDS
	_player_status_text = "前线受压，先稳住站位"
	_battle_state_text = "前线受压"

	_spawn_float_text(
		"受压",
		_player_visual_position + Vector2(0.0, -54.0),
		Color(1.0, 0.72, 0.72, 1.0),
		0.74
	)
	_bump_screen_shake(2.6, PLAYER_HIT_FEEDBACK_SECONDS)
	if _message_cooldown <= 0.0:
		movement_status_label.text = "%s 已逼近我方前线，先稳住站位再找机会出手。" % monster_name
		_message_cooldown = MESSAGE_COOLDOWN_SECONDS


func _spawn_drop_preview(monster_state: Dictionary) -> void:
	var start_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	var target_position := Vector2(
		clampf(
			start_position.x + (18.0 if start_position.x < _lane_center_x else -18.0),
			_lane_center_x - _lane_half_width * 0.55,
			_lane_center_x + _lane_half_width * 0.55
		),
		clampf(
			maxf(start_position.y + 52.0, _world_height * 0.58),
			_world_height * 0.54,
			_world_height * 0.70
		)
	)

	var drop_marker := _build_drop_marker("掉落显现")
	battle_world.add_child(drop_marker)
	_drop_nodes.append({
		"node": drop_marker,
		"from": start_position,
		"to": target_position,
		"progress": 0.0,
		"ttl": 1.12,
	})

	_presentation_dirty = true
	_drop_preview_count += 1
	_spawn_float_text(
		"掉落",
		target_position + Vector2(0.0, -24.0),
		DROP_TINT,
		0.82
	)
	_refresh_progress_text()
	_refresh_drop_status()
	if _message_cooldown <= 0.0:
		movement_status_label.text = "%s 倒下后留下战利品影子，继续清场后就会离开战场。" % str(monster_state.get("monster_name", "敌人"))
		_message_cooldown = MESSAGE_COOLDOWN_SECONDS


func _spawn_float_text(text: String, world_position: Vector2, tint: Color, duration: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.modulate = tint
	battle_world.add_child(label)
	label.size = label.get_combined_minimum_size()

	_feedback_nodes.append({
		"node": label,
		"world_position": world_position,
		"velocity": Vector2(0.0, -32.0),
		"ttl": duration,
		"duration": duration,
		"tint": tint,
	})


func _update_feedback_nodes(delta: float) -> void:
	for index in range(_feedback_nodes.size() - 1, -1, -1):
		var entry: Dictionary = _feedback_nodes[index]
		var node = entry.get("node", null)
		if node == null:
			_feedback_nodes.remove_at(index)
			continue

		var ttl := maxf(float(entry.get("ttl", 0.0)) - delta, 0.0)
		var duration := maxf(float(entry.get("duration", 0.6)), 0.001)
		var tint: Color = entry.get("tint", BODY_TEXT)
		var world_position: Vector2 = entry.get("world_position", Vector2.ZERO)
		var velocity: Vector2 = entry.get("velocity", Vector2(0.0, -32.0))
		world_position += velocity * delta

		entry["ttl"] = ttl
		entry["world_position"] = world_position
		_feedback_nodes[index] = entry

		node.size = node.get_combined_minimum_size()
		node.position = world_position - node.size * 0.5
		node.modulate = Color(tint.r, tint.g, tint.b, clampf(ttl / duration, 0.0, 1.0))
		if ttl <= 0.0:
			node.queue_free()
			_feedback_nodes.remove_at(index)


func _update_drop_nodes(delta: float) -> void:
	for index in range(_drop_nodes.size() - 1, -1, -1):
		var entry: Dictionary = _drop_nodes[index]
		var node = entry.get("node", null)
		if node == null:
			_drop_nodes.remove_at(index)
			continue

		var progress := minf(float(entry.get("progress", 0.0)) + delta * 1.9, 1.0)
		var ttl := float(entry.get("ttl", 0.0)) - delta
		var from_position: Vector2 = entry.get("from", Vector2.ZERO)
		var to_position: Vector2 = entry.get("to", Vector2.ZERO)
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		var world_position := from_position.lerp(to_position, eased)

		entry["progress"] = progress
		entry["ttl"] = ttl
		_drop_nodes[index] = entry

		node.position = world_position - DROP_MARKER_SIZE * 0.5
		var alpha := 1.0
		if ttl < 0.32:
			alpha = clampf(ttl / 0.32, 0.0, 1.0)
		node.modulate = Color(1.0, 1.0, 1.0, alpha)
		if ttl <= 0.0:
			node.queue_free()
			_drop_nodes.remove_at(index)


func _interaction_locked() -> bool:
	return _battle_phase == "paused" or _battle_phase == "settling" or _battle_phase == "finish_pause"


func _update_interaction_state() -> void:
	if skill_button != null:
		skill_button.disabled = _prepare_payload.is_empty() or _battle_phase != "interactive" or _alive_monster_count() == 0
	if pause_button != null:
		pause_button.text = "继续" if _battle_phase == "paused" else "暂停"
		pause_button.disabled = _prepare_payload.is_empty() or _battle_phase == "settling" or _battle_phase == "finish_pause"


func _toggle_pause() -> void:
	if _prepare_payload.is_empty():
		return
	if _battle_phase == "settling" or _battle_phase == "finish_pause":
		return

	if _battle_phase == "paused":
		_battle_phase = "interactive"
		_battle_state_text = "继续推进"
		_player_status_text = "重新进入战场"
		movement_status_label.text = "继续推进，保持前压和微调寻找新的出手机会。"
	else:
		_battle_phase = "paused"
		_battle_state_text = "战场已暂停"
		movement_status_label.text = "战场已暂停，当前站位和敌方位置都会保持。"

	_refresh_status_panels()
	_update_interaction_state()


func _start_finish_sequence() -> void:
	if _settle_requested or _battle_phase == "finish_pause":
		return

	_battle_phase = "finish_pause"
	_battle_state_text = "战斗完成"
	_player_status_text = "清场结束，等待收束"
	set_page_state("success", "敌方已清空，掉落预热已经出现，稍后会自然切到正式结算。")
	movement_status_label.text = "最后一个敌人倒下，战场短暂停顿后会自然收束。"
	_update_interaction_state()

	_finish_sequence_id += 1
	var sequence_id := _finish_sequence_id
	_run_finish_sequence(sequence_id)


func _run_finish_sequence(sequence_id: int) -> void:
	await get_tree().create_timer(FINISH_PAUSE_SECONDS).timeout
	if sequence_id != _finish_sequence_id:
		return
	if _prepare_payload.is_empty() or _settle_requested:
		return

	_request_settle(true)


func _add_zone_label(text: String, y_position: float) -> void:
	var zone_label := Label.new()
	zone_label.text = text
	zone_label.modulate = Color(0.83, 0.90, 0.98, 0.45)
	zone_label.position = Vector2(18.0, clampf(y_position, 24.0, _world_height - 36.0))
	battle_world.add_child(zone_label)


func _build_front_position(spawn_position: Vector2, wave_no: int, x_offset: float) -> Vector2:
	var front_y := minf(
		_player_position.y - 128.0,
		spawn_position.y + 214.0 + float(maxi(wave_no - 1, 0)) * 24.0
	)
	front_y = clampf(front_y, spawn_position.y + 96.0, _world_height - 156.0)
	var front_x := clampf(
		_lane_center_x + x_offset * 0.34,
		_lane_center_x - _lane_half_width * 0.82,
		_lane_center_x + _lane_half_width * 0.82
	)
	return Vector2(front_x, front_y)


func _bump_screen_shake(strength: float, duration: float) -> void:
	_screen_shake_strength = maxf(_screen_shake_strength, strength)
	_screen_shake_timer = maxf(_screen_shake_timer, duration)


func _on_battle_view_resized() -> void:
	if _prepare_payload.is_empty():
		return

	if _monster_states.is_empty():
		_build_monster_states()
		_sync_world()
		_refresh_status_panels()
		return

	var can_reflow_clean := (
		not _presentation_dirty
		and _drop_preview_count == 0
		and _alive_monster_count() == _monster_states.size()
		and _battle_phase == "interactive"
	)
	if can_reflow_clean:
		_build_monster_states()
		_sync_world()
	else:
		_refresh_world_positions()

	_refresh_status_panels()


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

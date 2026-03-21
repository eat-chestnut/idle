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
const MONSTER_ATTACK_RANGE_X := 72.0
const MONSTER_ATTACK_RANGE_Y := 126.0
const PLAYER_HIT_FEEDBACK_SECONDS := 0.22
const PLAYER_ATTACK_FEEDBACK_SECONDS := 0.18
const MONSTER_DEATH_FEEDBACK_SECONDS := 0.34
const FINISH_PAUSE_SECONDS := 0.90
const MESSAGE_COOLDOWN_SECONDS := 0.38
const HP_BAR_SEGMENTS := 10

var route_title_label: Label
var route_meta_label: Label
var battle_hint_label: Label
var battle_state_label: Label
var battle_context_label: Label
var progress_label: Label
var target_status_label: Label

var battle_view: Control
var battle_world: Control
var drop_status_label: Label
var movement_status_label: Label
var player_hp_label: Label
var player_status_label: Label
var player_position_label: Label
var control_hint_label: Label
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
var _player_hp_max := 0.0
var _player_hp_current := 0.0
var _player_hit_timer := 0.0
var _player_attack_burst_timer := 0.0
var _screen_shake_timer := 0.0
var _screen_shake_strength := 0.0
var _message_cooldown := 0.0
var _battle_phase := "idle"
var _battle_state_text := "等待战斗"
var _player_status_text := "等待 Prepare"
var _drop_preview_count := 0
var _settle_requested := false
var _finish_sequence_id := 0


func _ready() -> void:
	set_process(true)


func _init() -> void:
	setup_page(
		"战斗",
		[
			"本轮战斗页只补基础手感：接敌、位移、命中、受击、掉落预热与结算衔接。",
			"正式掉落、奖励和 battle_context 真相仍以后端 prepare / settle 返回为准。",
		]
	)

	var header_card := add_card("战场信息", "顶部只保留关卡、目标和战场状态，不把 Battle 页继续膨胀成复杂系统页。")
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

	var arena_card := add_card("竖版战斗空间", "地图高度约为视区的 1.45 倍，怪物会从中上区域压近，镜头只做轻跟随。")
	battle_view = Control.new()
	battle_view.custom_minimum_size = Vector2(0, 560)
	battle_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_view.clip_contents = true
	battle_view.resized.connect(_on_battle_view_resized)
	arena_card.add_child(battle_view)

	battle_world = Control.new()
	battle_world.position = Vector2.ZERO
	battle_view.add_child(battle_world)

	drop_status_label = Label.new()
	drop_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drop_status_label.modulate = CARD_TEXT_MUTED
	arena_card.add_child(drop_status_label)

	movement_status_label = Label.new()
	movement_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movement_status_label.modulate = CARD_TEXT_MUTED
	arena_card.add_child(movement_status_label)

	var action_card := add_card("底部操作", "底部只保留 HP、状态、站位和最关键按钮，让战斗区保持够高。")
	battle_context_label = Label.new()
	battle_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_context_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(battle_context_label)

	player_hp_label = Label.new()
	player_hp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(player_hp_label)

	player_status_label = Label.new()
	player_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_card.add_child(player_status_label)

	player_position_label = Label.new()
	player_position_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_position_label.modulate = BODY_TEXT
	action_card.add_child(player_position_label)

	control_hint_label = Label.new()
	control_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_hint_label.modulate = CARD_TEXT_MUTED
	action_card.add_child(control_hint_label)

	var attack_row := add_button_row(action_card)
	add_button(attack_row, "左移", func() -> void:
		_move_player(Vector2(-30.0, 0.0), "左移试探")
	)
	skill_button = add_button(attack_row, "攻击当前目标", _use_skill)
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
	_battle_phase = "idle"
	_battle_state_text = "等待战斗"
	_player_status_text = "等待 Prepare"
	_player_hp_max = 0.0
	_player_hp_current = 0.0
	_player_hit_timer = 0.0
	_player_attack_burst_timer = 0.0
	_screen_shake_timer = 0.0
	_screen_shake_strength = 0.0
	_message_cooldown = 0.0
	route_title_label.text = "等待战斗上下文"
	route_meta_label.text = "先回出战页锁定角色和难度，再进入 Battle 页。"
	battle_hint_label.text = "当前 Battle 页只承接真实 prepare 结果，不伪造掉落和奖励。"
	battle_state_label.text = "战场状态：等待战斗开始。"
	progress_label.text = "战场进度：还没有敌方数据。"
	target_status_label.text = "当前目标：等待 Prepare 承接敌方信息。"
	drop_status_label.text = "掉落出现区：战斗开始后，敌人倒下时会先出现战利品影子。"
	movement_status_label.text = "前压、横移和攻击会在出战确认完成后解锁。"
	battle_context_label.text = "本次 battle_context 尚未生成。"
	player_hp_label.text = "HP：等待战斗开始。"
	player_status_label.text = "状态：先在出战页确认角色与难度。"
	player_position_label.text = "当前位置：等待 Battle 页承接。"
	control_hint_label.text = "Battle 页只保留最关键的站位、攻击与收束，不扩未来系统按钮。"
	clear_container(battle_world)
	set_output_json({})
	_update_interaction_state()


func allow_retry_settle() -> void:
	_settle_requested = false
	if _prepare_payload.is_empty():
		return

	_battle_phase = "finish_pause" if _alive_monster_count() == 0 else "engaging"
	_battle_state_text = "可再次收束"
	_player_status_text = "正式结算未完成，可继续提交"
	movement_status_label.text = "正式结算没有完成，可以继续收束或回到安全状态后再试一次。"
	_update_interaction_state()
	_refresh_status_panels()


func _build_monster_states() -> void:
	_monster_states.clear()
	_feedback_nodes.clear()
	_drop_nodes.clear()
	_drop_preview_count = 0
	_player_hit_timer = 0.0
	_player_attack_burst_timer = 0.0
	_screen_shake_timer = 0.0
	_screen_shake_strength = 0.0
	_message_cooldown = 0.0
	_battle_phase = "engaging"
	_battle_state_text = "接敌中"
	_player_status_text = "整队推进"

	var visible_height: float = maxf(battle_view.size.y, 560.0)
	var view_width: float = maxf(battle_view.size.x, 320.0)
	_world_height = maxf(visible_height * 1.46, 800.0)
	_lane_center_x = maxf(view_width * 0.5, 180.0)
	_lane_half_width = clampf(view_width * 0.15, 62.0, 88.0)
	_player_position = Vector2(_lane_center_x, _world_height * 0.78)
	_player_visual_position = _player_position
	_camera_y = clampf(_player_position.y - visible_height * 0.70, 0.0, _world_height - visible_height)

	var character_stats := _as_dictionary(_prepare_payload.get("character_stats", {}))
	_player_hp_max = maxf(_variant_to_float(character_stats.get("hp", 30), 30.0), 1.0)
	_player_hp_current = _player_hp_max

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
		var fallback_move_speed := 90.0 if monster_role == "boss_enemy" else 108.0
		var fallback_attack_interval := 1.35 if monster_role == "boss_enemy" else 1.12

		_monster_states.append({
			"monster_id": str(entry.get("monster_id", "")),
			"monster_name": str(entry.get("monster_name", "敌人")),
			"monster_role": monster_role,
			"wave_no": int(entry.get("wave_no", 1)),
			"base_hp": int(entry.get("base_hp", 0)),
			"base_attack": int(entry.get("base_attack", 0)),
			"alive": true,
			"dying": false,
			"drop_spawned": false,
			"spawn_position": spawn_position,
			"world_position": spawn_position,
			"approach_speed": maxf(_variant_to_float(entry.get("move_speed", 0.0), fallback_move_speed), 72.0),
			"attack_interval": maxf(_variant_to_float(entry.get("attack_interval", 0.0), fallback_attack_interval), 0.85),
			"attack_cooldown": 0.55 + float(index) * 0.12,
			"pressure_gap": 122.0 + float(maxi(int(entry.get("wave_no", 1)) - 1, 0)) * 18.0 + float(index % 2) * 12.0,
			"max_advance": 220.0 + float(maxi(int(entry.get("wave_no", 1)), 1)) * 24.0,
			"lane_bias": x_offset * 0.45,
			"hit_timer": 0.0,
			"death_timer": 0.0,
			"attack_pulse": 0.0,
		})


func _sync_header() -> void:
	var chapter_name := str(_route_context.get("chapter_name", "章节"))
	var stage_name := str(_route_context.get("stage_name", "关卡"))
	var difficulty_name := str(_route_context.get("difficulty_name", "难度"))
	route_title_label.text = "%s / %s / %s" % [chapter_name, stage_name, difficulty_name]
	route_meta_label.text = "角色 %s | 推荐战力 %s | 怪物从中上区域压近" % [
		str(_prepare_payload.get("character", {}).get("character_name", "未准备")),
		str(_route_context.get("recommended_power", "-")),
	]

	if _reward_status.is_empty():
		battle_hint_label.text = "首通奖励状态：等结算页正式回读。"
	elif int(_reward_status.get("has_reward", 0)) == 0:
		battle_hint_label.text = "首通奖励状态：当前难度没有首通奖励，本轮重点看掉落与结算衔接。"
	elif int(_reward_status.get("has_granted", 0)) == 1:
		battle_hint_label.text = "首通奖励状态：已领取，本轮重点看基础战斗手感和掉落出现。"
	else:
		battle_hint_label.text = "首通奖励状态：未领取，若本轮首通成功会在结算页展示正式结果。"

	battle_context_label.text = "本次 battle_context 已锁定；Battle 页只做轻量体验，正式结算仍走真实 settle 接口。"
	control_hint_label.text = "建议用“前压”拉近距离，再配合左右微调；敌方清空后会短暂停顿，再自然切到结算页。"
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
	if delta.y < 0.0:
		_player_status_text = "前压找机会"
	elif delta.y > 0.0:
		_player_status_text = "后撤稳住阵型"
	else:
		_player_status_text = "横移调整角度"

	_battle_state_text = "接敌压近"
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
	target["attack_cooldown"] = maxf(float(target.get("attack_interval", 1.0)), 0.85)
	target["world_position"] = Vector2(world_position.x + hit_shift, world_position.y - 14.0)
	_monster_states[target_index] = target

	_player_attack_burst_timer = PLAYER_ATTACK_FEEDBACK_SECONDS
	_player_status_text = "命中得手，继续推进"
	_battle_state_text = "出手命中"
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
		_battle_phase = "engaging"
		_battle_state_text = "尚未形成有效击杀"
		set_page_state("error", "至少击败一个敌人后，才能提交当前战斗的正式结算。")
		movement_status_label.text = "先继续前压或攻击，形成最小合法结算结果。"
		_update_interaction_state()
		return

	movement_status_label.text = "战斗已经收束，正在提交正式结算。"
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
		drop_status_label.text = "掉落出现区：等待战斗开始。"
		return

	if _drop_preview_count <= 0:
		drop_status_label.text = "掉落出现区：敌人倒下后会短暂浮出战利品影子，正式内容仍以后端结算结果为准。"
	elif _alive_monster_count() == 0:
		drop_status_label.text = "掉落出现区：已看到 %d 份战利品影子，战场正在收束，马上进入正式结算。" % _drop_preview_count
	else:
		drop_status_label.text = "掉落出现区：已出现 %d 份战利品影子，继续清场后会统一进入结算。" % _drop_preview_count


func _refresh_status_panels() -> void:
	player_hp_label.text = "HP：%s %d / %d" % [
		_build_hp_bar(),
		int(round(_player_hp_current)),
		int(round(_player_hp_max)),
	]
	player_status_label.text = "状态：%s" % _describe_player_status()
	player_position_label.text = "当前位置：%s" % _describe_player_position()
	target_status_label.text = "当前目标：%s" % _describe_target_state()
	battle_state_label.text = "战场状态：%s" % _describe_battle_state()
	_refresh_drop_status()


func _describe_battle_state() -> String:
	if _prepare_payload.is_empty():
		return "等待 Prepare"
	if _settle_requested:
		return "正式结算提交中"
	if _battle_phase == "finish_pause":
		return "敌方清空，战场收束中"
	if _alive_monster_count() == 0:
		return "敌方已清空"
	if _find_attack_target_index() >= 0:
		return "贴身交火"

	return _battle_state_text


func _describe_player_status() -> String:
	if _prepare_payload.is_empty():
		return "等待战斗开始"
	if _settle_requested:
		return "已锁定收束，等待正式结算"

	var hp_ratio := clampf(_player_hp_current / maxf(_player_hp_max, 1.0), 0.0, 1.0)
	if _battle_phase == "finish_pause":
		return "清场完成，战斗完成感已经建立"
	if hp_ratio < 0.35:
		return "%s，前线压力偏高" % _player_status_text
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
	var enemy_threat := dx <= MONSTER_ATTACK_RANGE_X and dy >= 14.0 and dy <= MONSTER_ATTACK_RANGE_Y

	var range_text := "已经进入出手机会"
	if not in_attack_range and enemy_threat:
		range_text = "已经压到我方脸前"
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
	monster_state["attack_pulse"] = maxf(float(monster_state.get("attack_pulse", 0.0)) - delta, 0.0)

	var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	var spawn_position: Vector2 = monster_state.get("spawn_position", world_position)
	var desired_y: float = minf(
		_player_position.y - float(monster_state.get("pressure_gap", 126.0)),
		spawn_position.y + float(monster_state.get("max_advance", 220.0))
	)
	desired_y = clampf(desired_y, spawn_position.y, _world_height - 148.0)

	var approach_speed := float(monster_state.get("approach_speed", 96.0))
	if desired_y > world_position.y:
		world_position.y = min(world_position.y + approach_speed * delta, desired_y)
	else:
		world_position.y = lerpf(world_position.y, desired_y, clampf(delta * 1.6, 0.0, 1.0))

	var desired_x := clampf(
		lerpf(spawn_position.x, _player_position.x + float(monster_state.get("lane_bias", 0.0)), 0.66),
		_lane_center_x - _lane_half_width * 0.82,
		_lane_center_x + _lane_half_width * 0.82
	)
	world_position.x = lerpf(world_position.x, desired_x, clampf(delta * 2.2, 0.0, 1.0))
	monster_state["world_position"] = world_position

	var attack_cooldown := maxf(float(monster_state.get("attack_cooldown", 0.0)) - delta, 0.0)
	monster_state["attack_cooldown"] = attack_cooldown
	if _monster_is_in_attack_range(monster_state) and attack_cooldown <= 0.0 and not _settle_requested:
		monster_state = _apply_monster_attack(monster_state)

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


func _monster_is_in_attack_range(monster_state: Dictionary) -> bool:
	var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	var dx := absf(world_position.x - _player_position.x)
	var dy := _player_position.y - world_position.y
	return dx <= MONSTER_ATTACK_RANGE_X and dy >= 14.0 and dy <= MONSTER_ATTACK_RANGE_Y


func _apply_monster_attack(monster_state: Dictionary) -> Dictionary:
	monster_state["attack_cooldown"] = maxf(float(monster_state.get("attack_interval", 1.1)), 0.85)
	monster_state["attack_pulse"] = 0.16

	var raw_damage := _variant_to_float(monster_state.get("base_attack", 8), 8.0) * 0.25
	var damage := int(round(clampf(raw_damage, 3.0, 12.0)))
	_player_hp_current = maxf(_player_hp_current - float(damage), 1.0)
	_player_hit_timer = PLAYER_HIT_FEEDBACK_SECONDS
	_player_status_text = "受击后稳住阵线"
	_battle_state_text = "短兵相接"
	_player_position.y = clampf(_player_position.y + 10.0, 112.0, _world_height - 92.0)

	_spawn_float_text(
		"-%d" % damage,
		_player_visual_position + Vector2(0.0, -54.0),
		Color(1.0, 0.64, 0.64, 1.0),
		0.74
	)
	_bump_screen_shake(4.0, PLAYER_HIT_FEEDBACK_SECONDS)
	if _message_cooldown <= 0.0:
		movement_status_label.text = "%s 顶到前线，我方吃到一次短促受击。" % str(monster_state.get("monster_name", "敌人"))
		_message_cooldown = MESSAGE_COOLDOWN_SECONDS

	return monster_state


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
		movement_status_label.text = "%s 倒下后留下战利品影子，正式结果会在结算页回显。" % str(monster_state.get("monster_name", "敌人"))
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
	return _settle_requested or _battle_phase == "finish_pause"


func _update_interaction_state() -> void:
	if skill_button != null:
		skill_button.disabled = _prepare_payload.is_empty() or _settle_requested or _alive_monster_count() == 0 or _battle_phase == "finish_pause"


func _start_finish_sequence() -> void:
	if _settle_requested or _battle_phase == "finish_pause":
		return

	_battle_phase = "finish_pause"
	_battle_state_text = "战斗完成"
	_player_status_text = "清场结束，等待收束"
	set_page_state("success", "敌方已清空，掉落预热已经出现，稍后会自然切到正式结算。")
	movement_status_label.text = "最后一个敌人倒下，战场短暂停顿后会进入正式结算。"
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


func _build_hp_bar() -> String:
	if _player_hp_max <= 0.0:
		return "[----------]"

	var ratio := clampf(_player_hp_current / _player_hp_max, 0.0, 1.0)
	var filled := mini(int(round(ratio * float(HP_BAR_SEGMENTS))), HP_BAR_SEGMENTS)
	var result := "["
	for index in range(HP_BAR_SEGMENTS):
		result += "#" if index < filled else "-"
	result += "]"
	return result


func _add_zone_label(text: String, y_position: float) -> void:
	var zone_label := Label.new()
	zone_label.text = text
	zone_label.modulate = Color(0.83, 0.90, 0.98, 0.45)
	zone_label.position = Vector2(18.0, clampf(y_position, 24.0, _world_height - 36.0))
	battle_world.add_child(zone_label)


func _bump_screen_shake(strength: float, duration: float) -> void:
	_screen_shake_strength = maxf(_screen_shake_strength, strength)
	_screen_shake_timer = maxf(_screen_shake_timer, duration)


func _variant_to_float(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _on_battle_view_resized() -> void:
	if _prepare_payload.is_empty():
		return

	if _monster_states.is_empty():
		_build_monster_states()
		_sync_world()
		_refresh_status_panels()
		return

	var can_reflow_clean := (
		_drop_preview_count == 0
		and _alive_monster_count() == _monster_states.size()
		and is_equal_approx(_player_hp_current, _player_hp_max)
	)
	if can_reflow_clean:
		_build_monster_states()
		_sync_world()
	else:
		_refresh_world_positions()

	_refresh_status_panels()

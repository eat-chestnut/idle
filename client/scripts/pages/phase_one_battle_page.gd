extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneBattlePage

const DungeonLayoutScript = preload("res://client/scripts/phase_one_dungeon_map_layout.gd")

const MAP_BG_TINT := Color(0.08, 0.11, 0.16, 1.0)
const MAP_GRID_TINT := Color(0.22, 0.30, 0.42, 0.28)
const START_ZONE_TINT := Color(0.22, 0.42, 0.36, 0.16)
const NORMAL_ZONE_TINT := Color(0.26, 0.34, 0.48, 0.14)
const ELITE_ZONE_TINT := Color(0.55, 0.34, 0.18, 0.14)
const BOSS_ZONE_TINT := Color(0.58, 0.18, 0.20, 0.20)
const PLAYER_TINT := Color(0.58, 0.88, 0.72, 1.0)
const NORMAL_TINT := Color(0.88, 0.60, 0.46, 1.0)
const ELITE_TINT := Color(0.98, 0.76, 0.42, 1.0)
const BOSS_TINT := Color(0.97, 0.46, 0.48, 1.0)
const DROP_TINT := Color(0.98, 0.86, 0.54, 1.0)
const CONTROL_TINT := Color(0.66, 0.78, 0.98, 1.0)

const PLAYER_MARKER_SIZE := Vector2(126.0, 60.0)
const MONSTER_MARKER_SIZE := Vector2(134.0, 64.0)
const DROP_MARKER_SIZE := Vector2(92.0, 34.0)
const PLAYER_STEP := 96.0
const PLAYER_MOVE_LERP := 8.0
const CAMERA_LERP := 7.0
const AUTO_ATTACK_RANGE := 142.0
const OUTPUT_SKILL_RANGE := 236.0
const AUTO_ATTACK_INTERVAL := 0.58
const OUTPUT_SKILL_COOLDOWN := 4.5
const CONTROL_SKILL_COOLDOWN := 7.0
const CONTROL_DURATION := 1.2
const CONTROL_PUSH_DISTANCE := 120.0
const PLAYER_ATTACK_FEEDBACK_SECONDS := 0.18
const PLAYER_HIT_FEEDBACK_SECONDS := 0.24
const MONSTER_HIT_FEEDBACK_SECONDS := 0.22
const MONSTER_DEATH_FEEDBACK_SECONDS := 0.34
const DROP_COLLECT_SECONDS := 0.72
const MESSAGE_COOLDOWN_SECONDS := 0.42

var route_title_label: Label
var route_meta_label: Label
var battle_hint_label: Label
var battle_state_label: Label
var progress_label: Label
var target_status_label: Label
var map_rule_label: Label

var battle_view: Control
var battle_world: Control
var battle_objective_label: Label
var battle_pace_label: Label
var battle_log_hint_label: Label
var battle_log_box: VBoxContainer

var player_feedback_label: Label
var player_status_label: Label
var player_position_label: Label
var movement_status_label: Label
var drop_status_label: Label

var pause_button: Button
var output_skill_button: Button
var control_skill_button: Button
var settle_button: Button
var continue_button: Button

var _route_context: Dictionary = {}
var _prepare_payload: Dictionary = {}
var _reward_status: Dictionary = {}
var _dungeon_summary: Dictionary = {}

var _monster_states: Array = []
var _marker_nodes: Dictionary = {}
var _feedback_nodes: Array = []
var _drop_nodes: Array = []
var _battle_log_entries: Array = []
var _player_marker: Dictionary = {}

var _world_size := Vector2(1440.0, 1180.0)
var _boss_zone_rect := Rect2()
var _player_position := Vector2(96.0, 520.0)
var _player_visual_position := Vector2(96.0, 520.0)
var _camera_position := Vector2.ZERO
var _battle_phase := "idle"
var _battle_state_text := "等待进图"
var _player_status_text := "等待进图"
var _battle_elapsed_seconds := 0.0
var _auto_attack_cooldown := 0.0
var _output_skill_cooldown := 0.0
var _control_skill_cooldown := 0.0
var _control_effect_timer := 0.0
var _player_hit_timer := 0.0
var _player_attack_timer := 0.0
var _screen_shake_timer := 0.0
var _screen_shake_strength := 0.0
var _message_cooldown := 0.0
var _settle_requested := false
var _drop_preview_count := 0
var _auto_pickup_count := 0
var _hit_count := 0
var _pressure_count := 0


func _ready() -> void:
	set_process(true)


func _init() -> void:
	setup_page("战斗", [])

	var header_card := add_card("副本地图刷图", "")
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

	map_rule_label = Label.new()
	map_rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_rule_label.modulate = CARD_TEXT_MUTED
	header_card.add_child(map_rule_label)

	var header_buttons := add_button_row(header_card)
	add_action_button(header_buttons, "回出战页", "navigate_prepare")
	pause_button = add_button(header_buttons, "暂停", _toggle_pause)

	var arena_card := add_card("固定 2x4 副本地图", "")
	battle_view = Control.new()
	battle_view.custom_minimum_size = Vector2(0, 620)
	battle_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_view.clip_contents = true
	battle_view.resized.connect(_on_battle_view_resized)
	arena_card.add_child(battle_view)

	battle_world = Control.new()
	battle_world.position = Vector2.ZERO
	battle_view.add_child(battle_world)

	var rhythm_card := add_card("战场节奏", "")
	battle_objective_label = Label.new()
	battle_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_objective_label.add_theme_font_size_override("font_size", 18)
	rhythm_card.add_child(battle_objective_label)

	battle_pace_label = Label.new()
	battle_pace_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rhythm_card.add_child(battle_pace_label)

	battle_log_hint_label = Label.new()
	battle_log_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_log_hint_label.modulate = CARD_TEXT_MUTED
	rhythm_card.add_child(battle_log_hint_label)

	battle_log_box = VBoxContainer.new()
	battle_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_box.add_theme_constant_override("separation", 8)
	rhythm_card.add_child(battle_log_box)

	var action_card := add_card("副本内操作", "")
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

	var joystick_title := Label.new()
	joystick_title.text = "左摇杆（模拟）"
	joystick_title.add_theme_font_size_override("font_size", 16)
	action_card.add_child(joystick_title)

	action_card.add_child(_build_joystick_grid())

	var skill_row := add_button_row(action_card)
	output_skill_button = add_button(skill_row, "输出技能", _use_output_skill)
	style_primary_button(output_skill_button)
	control_skill_button = add_button(skill_row, "保命 / 控制", _use_control_skill)
	style_primary_button(control_skill_button, CONTROL_TINT)

	var settle_row := add_button_row(action_card)
	continue_button = add_button(settle_row, "继续清图", _continue_after_boss)
	settle_button = add_button(settle_row, "立即结算", _request_settle.bind(true))
	style_primary_button(settle_button)

	reset_battle_space()
	_move_secondary_sections_to_bottom()


func load_battle(
	payload: Dictionary,
	route_context: Dictionary,
	reward_status: Dictionary,
	dungeon_summary: Dictionary = {}
) -> void:
	var next_battle_context_id := str(payload.get("battle_context_id", "")).strip_edges()
	if (
		not _prepare_payload.is_empty()
		and next_battle_context_id == str(_prepare_payload.get("battle_context_id", "")).strip_edges()
		and not _monster_states.is_empty()
	):
		_prepare_payload = payload.duplicate(true)
		_route_context = route_context.duplicate(true)
		_reward_status = reward_status.duplicate(true)
		if not dungeon_summary.is_empty():
			_dungeon_summary = dungeon_summary.duplicate(true)
			_sync_dungeon_summary(str(_dungeon_summary.get("settle_route", "explore")))
		_sync_header()
		_refresh_status_panels()
		_update_interaction_state()
		set_output_json(_build_output_payload())
		return

	_prepare_payload = payload.duplicate(true)
	_route_context = route_context.duplicate(true)
	_reward_status = reward_status.duplicate(true)
	_settle_requested = false
	_battle_elapsed_seconds = 0.0
	_auto_attack_cooldown = 0.0
	_output_skill_cooldown = 0.0
	_control_skill_cooldown = 0.0
	_control_effect_timer = 0.0
	_player_hit_timer = 0.0
	_player_attack_timer = 0.0
	_screen_shake_timer = 0.0
	_screen_shake_strength = 0.0
	_message_cooldown = 0.0
	_drop_preview_count = 0
	_auto_pickup_count = 0
	_hit_count = 0
	_pressure_count = 0
	_battle_log_entries.clear()
	_feedback_nodes.clear()
	_drop_nodes.clear()
	_build_monster_states()
	_dungeon_summary = dungeon_summary.duplicate(true)
	if _dungeon_summary.is_empty():
		_dungeon_summary = DungeonLayoutScript.build_initial_summary(_prepare_payload, _route_context, _monster_states)
	_sync_dungeon_summary("explore")
	_battle_phase = "interactive"
	_battle_state_text = "副本已展开"
	_player_status_text = "全图怪物已入场"
	_sync_header()
	_sync_world()
	_push_battle_log(
		"踏入 %s / %s / %s，2x4 副本地图已展开，全图共载入 %d 名敌人。" % [
			str(_route_context.get("chapter_name", "章节")),
			str(_route_context.get("stage_name", "关卡")),
			str(_route_context.get("difficulty_name", "难度")),
			_monster_states.size(),
		],
		PLAYER_TINT
	)
	_push_battle_log("普通怪散布在巡猎带，精英会守点，Boss 固定在终点区。", CONTROL_TINT)
	if _boss_guard_promotion_count() > 0:
		_push_battle_log("本场终点护卫位存在客户端精英表现补位，不改正式掉落角色。", DROP_TINT)
	set_page_state("success", "固定副本地图已经就位，可以自由走位推进。")
	set_output_json(_build_output_payload())
	_emit_dungeon_summary_changed()


func reset_battle_space() -> void:
	_prepare_payload = {}
	_route_context = {}
	_reward_status = {}
	_dungeon_summary = {}
	_monster_states = []
	_marker_nodes = {}
	_feedback_nodes = []
	_drop_nodes = []
	_battle_log_entries = []
	_player_marker = {}
	_settle_requested = false
	_battle_phase = "idle"
	_battle_state_text = "等待进图"
	_player_status_text = "等待进图"
	_battle_elapsed_seconds = 0.0
	_auto_attack_cooldown = 0.0
	_output_skill_cooldown = 0.0
	_control_skill_cooldown = 0.0
	_control_effect_timer = 0.0
	_player_hit_timer = 0.0
	_player_attack_timer = 0.0
	_screen_shake_timer = 0.0
	_screen_shake_strength = 0.0
	_message_cooldown = 0.0
	_drop_preview_count = 0
	_auto_pickup_count = 0
	_hit_count = 0
	_pressure_count = 0
	route_title_label.text = "等待进图"
	route_meta_label.text = "先回出战页定下角色和目标，再走进这张副本地图。"
	battle_hint_label.text = "Battle 第一版已改为固定 2x4 副本地图：进图即加载全图怪物，Boss 固定终点区。"
	battle_state_label.text = "战场状态：等待进图。"
	progress_label.text = "战场进度：全图怪物尚未展开。"
	target_status_label.text = "当前目标：等待副本展开。"
	map_rule_label.text = "规则提醒：击杀 Boss 后可立即结算，也可继续清图；只有全清才记录完整通关时间。"
	player_feedback_label.text = "前线反馈：这轮副本还没开始。"
	player_status_label.text = "状态：先在出战页锁定当前角色和目标。"
	player_position_label.text = "当前位置：进图后会开始跟随玩家回报。"
	movement_status_label.text = "操作规则：左摇杆模拟移动，自动索敌、自动普攻、自动拾取，保留 2 个主动按钮。"
	drop_status_label.text = "掉落提示：当前只会显示战利品影子，正式掉落仍以后端结算结果为准。"
	battle_objective_label.text = "本场目标：先从出战页走进这张副本地图。"
	battle_pace_label.text = "战斗节奏：Boss 倒下后先做选择，全清后再记录完整通关时间。"
	battle_log_hint_label.text = "战报：进图、接敌、Boss 倒下、继续清图和结算选择都会留在这里。"
	clear_container(battle_log_box)
	battle_log_box.add_child(_build_empty_label("副本地图还没有展开。"))
	clear_container(battle_world)
	set_output_json({})
	_update_interaction_state()


func allow_retry_settle() -> void:
	_settle_requested = false
	if _prepare_payload.is_empty():
		return
	if not _dungeon_summary.is_empty():
		_dungeon_summary["settled"] = false

	if bool(_dungeon_summary.get("full_clear_completed", false)):
		_battle_phase = "full_clear_ready"
		_battle_state_text = "全清结果待提交"
		_player_status_text = "完整通关时间已保留，等待再次提交"
	elif bool(_dungeon_summary.get("boss_defeated", false)):
		_battle_phase = "boss_choice" if _alive_monster_count() > 0 else "full_clear_ready"
		_battle_state_text = "Boss 已倒，可重新选择"
		_player_status_text = "可以立即结算，也可以继续清图"
	else:
		_battle_phase = "interactive"
		_battle_state_text = "继续刷图"
		_player_status_text = "可以继续推进"

	_push_battle_log("正式结算还没收稳，这张副本地图仍可继续处理。", DROP_TINT)
	_emit_dungeon_summary_changed()
	_update_interaction_state()
	_refresh_status_panels()


func _process(delta: float) -> void:
	if _prepare_payload.is_empty():
		return

	_player_visual_position = _player_visual_position.lerp(
		_player_position,
		clampf(delta * PLAYER_MOVE_LERP, 0.0, 1.0)
	)
	_player_hit_timer = maxf(_player_hit_timer - delta, 0.0)
	_player_attack_timer = maxf(_player_attack_timer - delta, 0.0)
	_screen_shake_timer = maxf(_screen_shake_timer - delta, 0.0)
	_message_cooldown = maxf(_message_cooldown - delta, 0.0)
	_output_skill_cooldown = maxf(_output_skill_cooldown - delta, 0.0)
	_control_skill_cooldown = maxf(_control_skill_cooldown - delta, 0.0)
	_control_effect_timer = maxf(_control_effect_timer - delta, 0.0)

	if _battle_phase == "interactive":
		_battle_elapsed_seconds += delta
		_auto_attack_cooldown = maxf(_auto_attack_cooldown - delta, 0.0)
		_update_monster_motion(delta)
		_update_player_auto_attack()
	else:
		_auto_attack_cooldown = maxf(_auto_attack_cooldown - delta, 0.0)
		_update_idle_monster_motion(delta)

	_update_feedback_nodes(delta)
	_update_drop_nodes(delta)
	_refresh_world_positions()
	_refresh_status_panels()
	_update_interaction_state()


func _build_joystick_grid() -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 8)

	var hint := Label.new()
	hint.text = "支持 8 向自由走位，镜头会跟随玩家。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = CARD_TEXT_MUTED
	wrapper.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	wrapper.add_child(grid)

	var controls := [
		{"label": "左上", "vector": Vector2(-1.0, -1.0), "hint": "左上压位"},
		{"label": "上移", "vector": Vector2(0.0, -1.0), "hint": "前压推进"},
		{"label": "右上", "vector": Vector2(1.0, -1.0), "hint": "右上压位"},
		{"label": "左移", "vector": Vector2(-1.0, 0.0), "hint": "左移拉位"},
		{"label": "停步", "vector": Vector2.ZERO, "hint": "稳住当前位置"},
		{"label": "右移", "vector": Vector2(1.0, 0.0), "hint": "右移拉位"},
		{"label": "左下", "vector": Vector2(-1.0, 1.0), "hint": "左下脱战"},
		{"label": "下移", "vector": Vector2(0.0, 1.0), "hint": "后撤脱战"},
		{"label": "右下", "vector": Vector2(1.0, 1.0), "hint": "右下脱战"},
	]

	for control in controls:
		var button := Button.new()
		button.text = str(control.get("label", "移动"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 42.0)
		if Vector2(control.get("vector", Vector2.ZERO)).is_zero_approx():
			button.disabled = true
		else:
			button.pressed.connect(func() -> void:
				_move_player(
					Vector2(control.get("vector", Vector2.ZERO)),
					str(control.get("hint", "移动"))
				)
			)
		grid.add_child(button)

	return wrapper


func _build_monster_states() -> void:
	_monster_states.clear()
	var view_width := maxf(battle_view.size.x, 340.0)
	var view_height := maxf(battle_view.size.y, 560.0)
	_world_size = Vector2(
		view_width * DungeonLayoutScript.MAP_WIDTH_SCREENS,
		view_height * DungeonLayoutScript.MAP_HEIGHT_SCREENS
	)
	_boss_zone_rect = DungeonLayoutScript.world_rect_from_anchor_rect(DungeonLayoutScript.BOSS_ZONE, _world_size)
	_player_position = DungeonLayoutScript.anchor_to_world(DungeonLayoutScript.PLAYER_START_ANCHOR, _world_size)
	_player_visual_position = _player_position
	_camera_position = Vector2.ZERO

	var battle_context_id := str(_prepare_payload.get("battle_context_id", "")).strip_edges()
	var layout := DungeonLayoutScript.build_layout(_as_array(_prepare_payload.get("monster_list", [])), battle_context_id)
	for index in range(layout.size()):
		var entry: Dictionary = layout[index]
		var presentation_role := str(entry.get("presentation_role", "normal_enemy"))
		var home_position := DungeonLayoutScript.anchor_to_world(
			entry.get("guard_anchor", Vector2.ZERO),
			_world_size
		)
		var spawn_position := DungeonLayoutScript.anchor_to_world(
			entry.get("spawn_anchor", Vector2.ZERO),
			_world_size
		)
		_monster_states.append({
			"monster_id": str(entry.get("monster_id", "")).strip_edges(),
			"monster_name": str(entry.get("monster_name", "敌人")).strip_edges(),
			"monster_role": str(entry.get("monster_role", "normal_enemy")).strip_edges(),
			"presentation_role": presentation_role,
			"wave_no": int(entry.get("wave_no", 1)),
			"sort_order": int(entry.get("sort_order", 1)),
			"area_key": str(entry.get("area_key", "normal_patrol")),
			"area_label": str(entry.get("area_label", "巡猎带")),
			"is_promoted_elite_guard": bool(entry.get("is_promoted_elite_guard", false)),
			"alive": true,
			"dying": false,
			"world_position": spawn_position,
			"home_position": home_position,
			"aggro_range": _monster_aggro_range(presentation_role),
			"attack_range": _monster_attack_range(presentation_role),
			"move_speed": _monster_move_speed(presentation_role),
			"leash_radius": _monster_leash_radius(presentation_role),
			"attack_cooldown": 0.18 * float(index % 3),
			"engaged": false,
			"combat_hp": int(entry.get("max_combat_hp", 1)),
			"max_combat_hp": int(entry.get("max_combat_hp", 1)),
			"hit_flash_timer": 0.0,
			"death_timer": 0.0,
			"drop_spawned": false,
			"drop_collected": false,
		})


func _sync_header() -> void:
	route_title_label.text = "%s / %s / %s" % [
		str(_route_context.get("chapter_name", "章节")),
		str(_route_context.get("stage_name", "关卡")),
		str(_route_context.get("difficulty_name", "难度")),
	]
	route_meta_label.text = "当前副本：固定 2 屏高 × 4 屏宽 | 角色 %s | 推荐战力 %s" % [
		str(_prepare_payload.get("character", {}).get("character_name", "未准备")),
		str(_route_context.get("recommended_power", "-")),
	]
	battle_hint_label.text = "进图即加载全图怪物，普通怪散点巡逻，精英守点，Boss 固定终点区并带 2 个精英位。"
	map_rule_label.text = "规则提醒：击杀 Boss 后可立即结算，也可继续清图；只有全清才会把完整通关时间写入本地 runtime / save。"
	_refresh_progress_text()
	_refresh_drop_status()
	_refresh_status_panels()
	_update_interaction_state()


func _sync_world() -> void:
	clear_container(battle_world)
	_marker_nodes.clear()
	_feedback_nodes.clear()
	_drop_nodes.clear()
	_player_marker = {}

	battle_world.size = _world_size
	battle_world.custom_minimum_size = _world_size

	var background := ColorRect.new()
	background.color = MAP_BG_TINT
	background.position = Vector2.ZERO
	background.size = _world_size
	battle_world.add_child(background)

	for section in DungeonLayoutScript.map_sections():
		var section_rect := DungeonLayoutScript.world_rect_from_anchor_rect(
			section.get("rect", Rect2()),
			_world_size
		)
		var zone := ColorRect.new()
		zone.position = section_rect.position
		zone.size = section_rect.size
		zone.color = _section_tint(str(section.get("label", "")))
		battle_world.add_child(zone)

		var label := Label.new()
		label.text = str(section.get("label", "区域"))
		label.position = section_rect.position + Vector2(18.0, 14.0)
		label.modulate = Color(0.86, 0.92, 0.98, 0.58)
		battle_world.add_child(label)

	for column in range(1, int(DungeonLayoutScript.MAP_WIDTH_SCREENS)):
		var divider := ColorRect.new()
		divider.position = Vector2(_world_size.x * float(column) / DungeonLayoutScript.MAP_WIDTH_SCREENS, 0.0)
		divider.size = Vector2(2.0, _world_size.y)
		divider.color = MAP_GRID_TINT
		battle_world.add_child(divider)

	for row in range(1, int(DungeonLayoutScript.MAP_HEIGHT_SCREENS)):
		var divider := ColorRect.new()
		divider.position = Vector2(0.0, _world_size.y * float(row) / DungeonLayoutScript.MAP_HEIGHT_SCREENS)
		divider.size = Vector2(_world_size.x, 2.0)
		divider.color = MAP_GRID_TINT
		battle_world.add_child(divider)

	var boss_zone := ColorRect.new()
	boss_zone.position = _boss_zone_rect.position
	boss_zone.size = _boss_zone_rect.size
	boss_zone.color = BOSS_ZONE_TINT
	battle_world.add_child(boss_zone)

	for monster_state in _monster_states:
		var monster_id := str(monster_state.get("monster_id", ""))
		var marker := _build_marker(
			str(monster_state.get("monster_name", "敌人")),
			_monster_tint(str(monster_state.get("presentation_role", "normal_enemy"))),
			MONSTER_MARKER_SIZE
		)
		battle_world.add_child(marker.get("panel", null))
		_marker_nodes[monster_id] = marker

	_player_marker = _build_marker("我方", PLAYER_TINT, PLAYER_MARKER_SIZE)
	battle_world.add_child(_player_marker.get("panel", null))
	_refresh_world_positions()


func _build_marker(text: String, tint: Color, marker_size: Vector2) -> Dictionary:
	var marker := PanelContainer.new()
	marker.size = marker_size
	marker.custom_minimum_size = marker_size

	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.18)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.80)
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

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)

	var detail := Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.modulate = Color(0.90, 0.94, 1.0, 0.84)
	detail.add_theme_font_size_override("font_size", 12)
	box.add_child(detail)

	return {
		"panel": marker,
		"title": title,
		"detail": detail,
	}


func _build_drop_marker(text: String) -> PanelContainer:
	var marker := PanelContainer.new()
	marker.size = DROP_MARKER_SIZE
	marker.custom_minimum_size = DROP_MARKER_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(DROP_TINT.r, DROP_TINT.g, DROP_TINT.b, 0.20)
	style.border_color = Color(DROP_TINT.r, DROP_TINT.g, DROP_TINT.b, 0.82)
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
	var player_panel = _player_marker.get("panel", null)
	if player_panel == null:
		return

	var visible_size := battle_view.size
	var max_camera_x := maxf(_world_size.x - visible_size.x, 0.0)
	var max_camera_y := maxf(_world_size.y - visible_size.y, 0.0)
	var target_camera := Vector2(
		clampf(_player_visual_position.x - visible_size.x * 0.46, 0.0, max_camera_x),
		clampf(_player_visual_position.y - visible_size.y * 0.52, 0.0, max_camera_y)
	)
	_camera_position = _camera_position.lerp(target_camera, clampf(CAMERA_LERP * get_process_delta_time(), 0.0, 1.0))

	var shake_offset := Vector2.ZERO
	if _screen_shake_timer > 0.0:
		var shake_ratio := clampf(_screen_shake_timer / maxf(PLAYER_HIT_FEEDBACK_SECONDS, 0.001), 0.0, 1.0)
		shake_offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-0.8, 0.8)
		) * (_screen_shake_strength * shake_ratio)

	battle_world.position = -_camera_position + shake_offset

	for monster_state in _monster_states:
		var monster_id := str(monster_state.get("monster_id", ""))
		var marker: Dictionary = _as_dictionary(_marker_nodes.get(monster_id, {}))
		var panel = marker.get("panel", null)
		if panel == null:
			continue

		var title: Label = marker.get("title", null)
		var detail: Label = marker.get("detail", null)
		var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
		var alive := bool(monster_state.get("alive", false))
		var dying := bool(monster_state.get("dying", false))
		panel.visible = alive or dying
		panel.position = world_position - MONSTER_MARKER_SIZE * 0.5
		panel.z_index = 2 if alive else 1

		var scale_value := 1.0
		if alive and monster_id == str(_focus_target().get("monster_id", "")):
			scale_value += 0.08
		if float(monster_state.get("hit_flash_timer", 0.0)) > 0.0:
			scale_value += 0.10
		if dying:
			var fade_ratio := clampf(
				float(monster_state.get("death_timer", 0.0)) / maxf(MONSTER_DEATH_FEEDBACK_SECONDS, 0.001),
				0.0,
				1.0
			)
			scale_value = lerpf(0.74, 1.08, fade_ratio)
			panel.modulate = Color(1.0, 0.84, 0.84, fade_ratio)
		else:
			panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		panel.scale = Vector2(scale_value, scale_value)

		if title != null:
			title.text = str(monster_state.get("monster_name", "敌人"))
		if detail != null:
			detail.text = "%s | HP %d/%d" % [
				_monster_short_role(monster_state),
				int(monster_state.get("combat_hp", 0)),
				int(monster_state.get("max_combat_hp", 0)),
			]

	var player_render_position := _player_visual_position
	if _player_hit_timer > 0.0:
		player_render_position += Vector2(0.0, 10.0 * (_player_hit_timer / PLAYER_HIT_FEEDBACK_SECONDS))
	elif _player_attack_timer > 0.0:
		player_render_position += Vector2(0.0, -6.0 * (_player_attack_timer / PLAYER_ATTACK_FEEDBACK_SECONDS))

	player_panel.position = player_render_position - PLAYER_MARKER_SIZE * 0.5
	player_panel.z_index = 4
	player_panel.scale = Vector2.ONE * (
		1.0
		+ 0.08 * (_player_hit_timer / maxf(PLAYER_HIT_FEEDBACK_SECONDS, 0.001))
		+ 0.06 * (_player_attack_timer / maxf(PLAYER_ATTACK_FEEDBACK_SECONDS, 0.001))
	)
	if _player_hit_timer > 0.0:
		player_panel.modulate = Color(1.0, 0.76, 0.76, 1.0)
	elif _control_effect_timer > 0.0:
		player_panel.modulate = Color(0.82, 0.92, 1.0, 1.0)
	else:
		player_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var player_title: Label = _player_marker.get("title", null)
	var player_detail: Label = _player_marker.get("detail", null)
	if player_title != null:
		player_title.text = "我方"
	if player_detail != null:
		var cooldown_text := "普攻自动"
		if _output_skill_cooldown > 0.0:
			cooldown_text += " | 输出 %.1fs" % _output_skill_cooldown
		if _control_skill_cooldown > 0.0:
			cooldown_text += " | 保命 %.1fs" % _control_skill_cooldown
		player_detail.text = cooldown_text


func _move_player(direction: Vector2, label_text: String) -> void:
	if _prepare_payload.is_empty():
		set_page_state("empty", "先从出战页进入这一张副本地图。")
		return
	if _interaction_locked():
		return
	if direction.is_zero_approx():
		return

	var normalized_direction := direction.normalized()
	var next_position := _player_position + normalized_direction * PLAYER_STEP
	next_position.x = clampf(next_position.x, 54.0, _world_size.x - 54.0)
	next_position.y = clampf(next_position.y, 64.0, _world_size.y - 64.0)
	if next_position.is_equal_approx(_player_position):
		return

	_player_position = next_position
	if normalized_direction.y < -0.25:
		_player_status_text = "前压推进"
	elif normalized_direction.y > 0.25:
		_player_status_text = "后撤脱战"
	else:
		_player_status_text = "横移找角度"

	_battle_state_text = "自由走位中"
	movement_status_label.text = "%s | 当前位于 %s。" % [label_text, _describe_player_position()]
	if _message_cooldown <= 0.0:
		_push_battle_log("我方%s，继续在副本内调整站位。" % label_text, PLAYER_TINT)
		_message_cooldown = MESSAGE_COOLDOWN_SECONDS


func _use_output_skill() -> void:
	if _prepare_payload.is_empty():
		set_page_state("empty", "先从出战页进入这一张副本地图。")
		return
	if _interaction_locked():
		return
	if _output_skill_cooldown > 0.0:
		movement_status_label.text = "输出技能还在冷却，剩余 %.1f 秒。" % _output_skill_cooldown
		return

	var target_index := _find_attack_target_index(OUTPUT_SKILL_RANGE)
	if target_index < 0:
		movement_status_label.text = "当前没有进入输出技能范围的目标，先继续压位。"
		_spawn_float_text("未锁定", _player_visual_position + Vector2(0.0, -54.0), BODY_TEXT, 0.62)
		return

	_output_skill_cooldown = OUTPUT_SKILL_COOLDOWN
	_player_attack_timer = PLAYER_ATTACK_FEEDBACK_SECONDS
	_apply_damage(target_index, 2, "输出技能", DROP_TINT)


func _use_control_skill() -> void:
	if _prepare_payload.is_empty():
		set_page_state("empty", "先从出战页进入这一张副本地图。")
		return
	if _interaction_locked():
		return
	if _control_skill_cooldown > 0.0:
		movement_status_label.text = "保命 / 控制技能还在冷却，剩余 %.1f 秒。" % _control_skill_cooldown
		return

	_control_skill_cooldown = CONTROL_SKILL_COOLDOWN
	_control_effect_timer = CONTROL_DURATION
	_player_status_text = "拉开距离，准备脱战"
	_battle_state_text = "保命技生效"
	_player_position = Vector2(
		clampf(_player_position.x - CONTROL_PUSH_DISTANCE, 54.0, _world_size.x - 54.0),
		clampf(_player_position.y + 56.0, 64.0, _world_size.y - 64.0)
	)

	var controlled_count := 0
	for index in range(_monster_states.size()):
		var monster_state: Dictionary = _monster_states[index]
		if not bool(monster_state.get("alive", false)):
			continue
		var distance := Vector2(monster_state.get("world_position", Vector2.ZERO)).distance_to(_player_position)
		if distance > OUTPUT_SKILL_RANGE:
			continue
		monster_state["engaged"] = false
		var push_direction := (Vector2(monster_state.get("world_position", Vector2.ZERO)) - _player_position).normalized()
		if push_direction.is_zero_approx():
			push_direction = Vector2(1.0, 0.0)
		monster_state["world_position"] = Vector2(monster_state.get("world_position", Vector2.ZERO)) + push_direction * 84.0
		_monster_states[index] = monster_state
		controlled_count += 1

	_push_battle_log("保命 / 控制技能生效，附近敌人被压回守位。", CONTROL_TINT)
	movement_status_label.text = "保命 / 控制技能已生效，当前压回 %d 名敌人。" % controlled_count
	_spawn_float_text("脱战", _player_visual_position + Vector2(0.0, -52.0), CONTROL_TINT, 0.82)


func _continue_after_boss() -> void:
	if _battle_phase != "boss_choice":
		return
	_battle_phase = "interactive"
	_battle_state_text = "继续清图"
	_player_status_text = "Boss 已倒，继续扫图"
	_sync_dungeon_summary("continue_full_clear")
	_emit_dungeon_summary_changed()
	_push_battle_log("选择继续清图，准备把剩余怪物一起清空。", PLAYER_TINT)
	movement_status_label.text = "Boss 已倒，继续清图；只有全清才会记录完整通关时间。"


func _request_settle(_ignored: bool = true) -> void:
	if _prepare_payload.is_empty() or _settle_requested:
		return
	if not bool(_dungeon_summary.get("boss_defeated", false)):
		set_page_state("error", "先击杀 Boss，再决定是否立即结算。")
		movement_status_label.text = "当前还不能正式结算，先直奔 Boss 或继续清图。"
		return

	var killed_monsters: Array = []
	for monster_state in _monster_states:
		if not bool(monster_state.get("alive", false)):
			killed_monsters.append(str(monster_state.get("monster_id", "")))

	if killed_monsters.is_empty():
		set_page_state("error", "当前还没有有效击杀，无法提交结算。")
		return

	_settle_requested = true
	_battle_phase = "settling"
	_battle_state_text = "正在提交正式结算"
	_player_status_text = "战果已经锁定"
	var settle_route := "full_clear_ready" if bool(_dungeon_summary.get("full_clear_completed", false)) else "boss_choice"
	_sync_dungeon_summary(settle_route)
	_dungeon_summary["settled"] = true
	_emit_dungeon_summary_changed()
	_update_interaction_state()
	movement_status_label.text = (
		"全清完成，正在提交正式结算。"
		if bool(_dungeon_summary.get("full_clear_completed", false))
		else "Boss 已倒，正在按当前击杀结果提交正式结算。"
	)
	_push_battle_log("战果已经锁定，准备带着这轮收获离开副本。", PLAYER_TINT)
	_emit_action("battle_request_settle", {
		"character_id": _prepare_payload.get("character", {}).get("character_id", 0),
		"stage_difficulty_id": _prepare_payload.get("stage_difficulty", {}).get("stage_difficulty_id", ""),
		"battle_context_id": _prepare_payload.get("battle_context_id", ""),
		"killed_monsters": killed_monsters,
		"is_cleared": 1,
		"dungeon_summary": _dungeon_summary.duplicate(true),
	})


func _find_attack_target_index(max_range: float) -> int:
	var best_index := -1
	var best_score := 999999.0

	for index in range(_monster_states.size()):
		var target: Dictionary = _monster_states[index]
		if not bool(target.get("alive", false)):
			continue
		if _battle_phase != "interactive":
			continue

		var world_position: Vector2 = target.get("world_position", Vector2.ZERO)
		var distance := world_position.distance_to(_player_position)
		if distance > max_range:
			continue
		var score := distance
		if bool(target.get("engaged", false)):
			score -= 28.0
		if str(target.get("presentation_role", "normal_enemy")) == "boss_enemy":
			score -= 42.0
		elif str(target.get("presentation_role", "normal_enemy")) == "elite_enemy":
			score -= 18.0
		if score < best_score:
			best_score = score
			best_index = index

	return best_index


func _focus_target() -> Dictionary:
	var target_index := _find_attack_target_index(OUTPUT_SKILL_RANGE)
	if target_index >= 0:
		return _monster_states[target_index]

	var best_target: Dictionary = {}
	var best_score := 999999.0
	for monster_state in _monster_states:
		if not bool(monster_state.get("alive", false)):
			continue
		var score := Vector2(monster_state.get("world_position", Vector2.ZERO)).distance_to(_player_position)
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


func _update_idle_monster_motion(delta: float) -> void:
	for index in range(_monster_states.size()):
		var monster_state: Dictionary = _monster_states[index]
		if bool(monster_state.get("alive", false)):
			monster_state["attack_cooldown"] = maxf(float(monster_state.get("attack_cooldown", 0.0)) - delta, 0.0)
			monster_state["hit_flash_timer"] = maxf(float(monster_state.get("hit_flash_timer", 0.0)) - delta, 0.0)
			if _battle_phase == "boss_choice":
				monster_state["engaged"] = false
				monster_state["world_position"] = Vector2(monster_state.get("world_position", Vector2.ZERO)).move_toward(
					monster_state.get("home_position", Vector2.ZERO),
					float(monster_state.get("move_speed", 80.0)) * delta * 0.7
				)
		elif bool(monster_state.get("dying", false)):
			monster_state = _update_dying_monster_state(monster_state, delta)
		_monster_states[index] = monster_state


func _update_alive_monster_state(monster_state: Dictionary, delta: float) -> Dictionary:
	monster_state["attack_cooldown"] = maxf(float(monster_state.get("attack_cooldown", 0.0)) - delta, 0.0)
	monster_state["hit_flash_timer"] = maxf(float(monster_state.get("hit_flash_timer", 0.0)) - delta, 0.0)

	var world_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	var home_position: Vector2 = monster_state.get("home_position", world_position)
	var aggro_range := float(monster_state.get("aggro_range", 160.0))
	var attack_range := float(monster_state.get("attack_range", 88.0))
	var leash_radius := float(monster_state.get("leash_radius", 160.0))
	var move_speed := float(monster_state.get("move_speed", 80.0))
	var distance_to_player := world_position.distance_to(_player_position)
	var can_aggro := distance_to_player <= aggro_range

	if str(monster_state.get("presentation_role", "normal_enemy")) == "boss_enemy":
		can_aggro = can_aggro and _boss_zone_rect.has_point(_player_position)

	if _control_effect_timer > 0.0:
		can_aggro = false

	if can_aggro:
		monster_state["engaged"] = true
	elif bool(monster_state.get("engaged", false)):
		if (
			distance_to_player > aggro_range + 72.0
			or world_position.distance_to(home_position) > leash_radius
			or (
				str(monster_state.get("presentation_role", "normal_enemy")) == "boss_enemy"
				and not _boss_zone_rect.has_point(_player_position)
			)
		):
			monster_state["engaged"] = false

	if bool(monster_state.get("engaged", false)):
		if distance_to_player > attack_range:
			world_position = world_position.move_toward(_player_position, move_speed * delta)
		elif float(monster_state.get("attack_cooldown", 0.0)) <= 0.0:
			monster_state["attack_cooldown"] = _monster_attack_cooldown(str(monster_state.get("presentation_role", "normal_enemy")))
			_play_player_pressure_feedback(monster_state)
	else:
		world_position = world_position.move_toward(home_position, move_speed * delta * 0.65)

	monster_state["world_position"] = world_position
	return monster_state


func _update_dying_monster_state(monster_state: Dictionary, delta: float) -> Dictionary:
	monster_state["hit_flash_timer"] = maxf(float(monster_state.get("hit_flash_timer", 0.0)) - delta, 0.0)
	var death_timer := maxf(float(monster_state.get("death_timer", 0.0)) - delta, 0.0)
	monster_state["death_timer"] = death_timer
	monster_state["world_position"] = Vector2(monster_state.get("world_position", Vector2.ZERO)) + Vector2(0.0, -18.0 * delta)
	if death_timer <= 0.0:
		monster_state["dying"] = false
		if not bool(monster_state.get("drop_spawned", false)):
			_spawn_drop_preview(monster_state)
			monster_state["drop_spawned"] = true
	return monster_state


func _update_player_auto_attack() -> void:
	if _auto_attack_cooldown > 0.0:
		return
	var target_index := _find_attack_target_index(AUTO_ATTACK_RANGE)
	if target_index < 0:
		return
	_auto_attack_cooldown = AUTO_ATTACK_INTERVAL
	_player_attack_timer = PLAYER_ATTACK_FEEDBACK_SECONDS
	_apply_damage(target_index, 1, "自动普攻", PLAYER_TINT)


func _apply_damage(target_index: int, damage: int, source_text: String, tint: Color) -> void:
	if target_index < 0 or target_index >= _monster_states.size():
		return

	var target: Dictionary = _monster_states[target_index]
	if not bool(target.get("alive", false)):
		return

	var remaining_hp := maxi(int(target.get("combat_hp", 1)) - damage, 0)
	target["combat_hp"] = remaining_hp
	target["hit_flash_timer"] = MONSTER_HIT_FEEDBACK_SECONDS
	_monster_states[target_index] = target
	_hit_count += 1

	var target_position: Vector2 = target.get("world_position", Vector2.ZERO)
	if remaining_hp > 0:
		_player_status_text = "%s 命中，继续贴身输出" % source_text
		_battle_state_text = "自动交战中"
		movement_status_label.text = "%s 命中了 %s，剩余战斗 HP %d。" % [
			source_text,
			str(target.get("monster_name", "敌人")),
			remaining_hp,
		]
		_push_battle_log("%s 命中了 %s。" % [source_text, str(target.get("monster_name", "敌人"))], tint)
		_spawn_float_text(
			"%s -%d" % [source_text, damage],
			target_position + Vector2(0.0, -26.0),
			tint,
			0.68
		)
		return

	target["alive"] = false
	target["dying"] = true
	target["death_timer"] = MONSTER_DEATH_FEEDBACK_SECONDS
	target["engaged"] = false
	_monster_states[target_index] = target
	_player_status_text = "%s 收掉目标" % source_text
	_battle_state_text = "击杀完成"
	movement_status_label.text = "%s 击败了 %s，掉落影子会自动回收。" % [
		source_text,
		str(target.get("monster_name", "敌人")),
	]
	_push_battle_log("%s 击败了 %s。" % [source_text, str(target.get("monster_name", "敌人"))], tint)
	_spawn_float_text(
		"击败",
		target_position + Vector2(0.0, -30.0),
		DROP_TINT,
		0.82
	)
	_refresh_progress_text()
	_bump_screen_shake(2.8, 0.12)

	var is_boss := str(target.get("presentation_role", "normal_enemy")) == "boss_enemy"
	if is_boss and not bool(_dungeon_summary.get("boss_defeated", false)):
		_dungeon_summary["boss_defeated"] = true
		_dungeon_summary["boss_defeated_elapsed_seconds"] = snappedf(_battle_elapsed_seconds, 0.1)
		_dungeon_summary["boss_loot_ready"] = true

	if _alive_monster_count() == 0 and bool(_dungeon_summary.get("boss_defeated", false)):
		_on_full_clear_completed()
	elif is_boss:
		_on_boss_defeated()
	else:
		_sync_dungeon_summary(str(_dungeon_summary.get("settle_route", "explore")))
		_emit_dungeon_summary_changed()


func _on_boss_defeated() -> void:
	for index in range(_monster_states.size()):
		var monster_state: Dictionary = _monster_states[index]
		if bool(monster_state.get("alive", false)):
			monster_state["engaged"] = false
			_monster_states[index] = monster_state

	_battle_phase = "boss_choice"
	_battle_state_text = "Boss 已倒"
	_player_status_text = "可立即结算，也可继续清图"
	_sync_dungeon_summary("boss_choice")
	_emit_dungeon_summary_changed()
	_push_battle_log("Boss 已被击杀，当前可立即结算，也可留下来继续清图。", BOSS_TINT)
	set_page_state("success", "Boss 已倒，当前可以选择立即结算，或继续清图冲完整通关时间。")
	movement_status_label.text = "Boss 已倒：可立即结算拿走本次结果，也可继续清图，只有全清才记录完整通关时间。"


func _on_full_clear_completed() -> void:
	if not bool(_dungeon_summary.get("boss_defeated", false)):
		_dungeon_summary["boss_defeated"] = true
		_dungeon_summary["boss_defeated_elapsed_seconds"] = snappedf(_battle_elapsed_seconds, 0.1)
		_dungeon_summary["boss_loot_ready"] = true

	_dungeon_summary["full_clear_completed"] = true
	_dungeon_summary["full_clear_elapsed_seconds"] = snappedf(_battle_elapsed_seconds, 0.1)
	_battle_phase = "full_clear_ready"
	_battle_state_text = "全图已清空"
	_player_status_text = "完整通关时间已记录"
	_sync_dungeon_summary("full_clear_ready")
	_emit_dungeon_summary_changed()
	_push_battle_log(
		"全图怪物已清空，完整通关时间 %.1f 秒已记录进本地 runtime / save。" % float(_dungeon_summary.get("full_clear_elapsed_seconds", 0.0)),
		DROP_TINT
	)
	set_page_state("success", "副本已全清，完整通关时间已经落到本地状态里。")
	movement_status_label.text = "全清完成：完整通关时间 %.1f 秒已记录，准备提交正式结算。" % float(_dungeon_summary.get("full_clear_elapsed_seconds", 0.0))


func _play_player_pressure_feedback(monster_state: Dictionary) -> void:
	_pressure_count += 1
	_player_hit_timer = PLAYER_HIT_FEEDBACK_SECONDS
	_player_status_text = "前线受压，注意拉开距离"
	_battle_state_text = "怪物正在追击"
	_player_position = Vector2(
		clampf(_player_position.x - 18.0, 54.0, _world_size.x - 54.0),
		clampf(_player_position.y + 14.0, 64.0, _world_size.y - 64.0)
	)
	_push_battle_log(
		"%s 已压到我方身前，需要调整站位。" % str(monster_state.get("monster_name", "敌人")),
		Color(1.0, 0.74, 0.74, 1.0)
	)
	_spawn_float_text(
		"受压",
		_player_visual_position + Vector2(0.0, -54.0),
		Color(1.0, 0.76, 0.76, 1.0),
		0.74
	)
	_bump_screen_shake(2.4, PLAYER_HIT_FEEDBACK_SECONDS)
	if _message_cooldown <= 0.0:
		movement_status_label.text = "%s 已贴近我方，当前可用保命 / 控制技能拉开距离。" % str(monster_state.get("monster_name", "敌人"))
		_message_cooldown = MESSAGE_COOLDOWN_SECONDS


func _spawn_drop_preview(monster_state: Dictionary) -> void:
	var start_position: Vector2 = monster_state.get("world_position", Vector2.ZERO)
	var drop_marker := _build_drop_marker("自动拾取")
	battle_world.add_child(drop_marker)
	_drop_nodes.append({
		"node": drop_marker,
		"from": start_position,
		"to": _player_position,
		"progress": 0.0,
		"ttl": DROP_COLLECT_SECONDS,
		"monster_name": str(monster_state.get("monster_name", "敌人")),
		"collected": false,
	})
	_drop_preview_count += 1
	_refresh_progress_text()
	_refresh_drop_status()


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
		"velocity": Vector2(0.0, -34.0),
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
		var world_position: Vector2 = entry.get("world_position", Vector2.ZERO) + entry.get("velocity", Vector2.ZERO) * delta

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

		entry["to"] = _player_position
		var progress := minf(float(entry.get("progress", 0.0)) + delta * 1.8, 1.0)
		var ttl := maxf(float(entry.get("ttl", 0.0)) - delta, 0.0)
		var from_position: Vector2 = entry.get("from", Vector2.ZERO)
		var to_position: Vector2 = entry.get("to", Vector2.ZERO)
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		var world_position := from_position.lerp(to_position, eased)
		entry["progress"] = progress
		entry["ttl"] = ttl
		_drop_nodes[index] = entry

		node.position = world_position - DROP_MARKER_SIZE * 0.5
		node.modulate = Color(1.0, 1.0, 1.0, clampf(ttl / DROP_COLLECT_SECONDS, 0.0, 1.0))
		if not bool(entry.get("collected", false)) and progress >= 0.92:
			entry["collected"] = true
			_drop_nodes[index] = entry
			_auto_pickup_count += 1
			_push_battle_log(
				"%s 的战利品影子已被自动拾取。" % str(entry.get("monster_name", "敌人")),
				DROP_TINT
			)
			_refresh_drop_status()
		if ttl <= 0.0:
			node.queue_free()
			_drop_nodes.remove_at(index)


func _refresh_progress_text() -> void:
	if _monster_states.is_empty():
		progress_label.text = "战场进度：当前还没有副本怪物数据。"
		return

	var remaining := _alive_monster_count()
	progress_label.text = "战场进度：剩余 %d / %d | 普通 %d | 精英 %d | Boss %d | 自动拾取 %d。" % [
		remaining,
		_monster_states.size(),
		_remaining_count_by_role("normal_enemy"),
		_remaining_count_by_role("elite_enemy"),
		_remaining_count_by_role("boss_enemy"),
		_auto_pickup_count,
	]


func _refresh_drop_status() -> void:
	if _prepare_payload.is_empty():
		drop_status_label.text = "掉落提示：进图后才会开始自动拾取。"
		return

	if _drop_preview_count <= 0:
		drop_status_label.text = "掉落提示：当前会把战利品影子自动回收到玩家身边，正式掉落仍以后端结算页为准。"
	elif bool(_dungeon_summary.get("full_clear_completed", false)):
		drop_status_label.text = "掉落提示：本轮已自动拾取 %d 份战利品影子，完整通关时间已记录。" % _auto_pickup_count
	elif bool(_dungeon_summary.get("boss_defeated", false)):
		drop_status_label.text = "掉落提示：Boss 已倒，当前已自动拾取 %d 份战利品影子，可立即结算或继续清图。" % _auto_pickup_count
	else:
		drop_status_label.text = "掉落提示：当前已自动拾取 %d 份战利品影子，继续推进或直奔 Boss 都可以。" % _auto_pickup_count


func _refresh_status_panels() -> void:
	player_feedback_label.text = "前线反馈：%s" % _describe_player_feedback()
	player_status_label.text = "状态：%s" % _describe_player_status()
	player_position_label.text = "当前位置：%s" % _describe_player_position()
	target_status_label.text = "当前目标：%s" % _describe_target_state()
	battle_state_label.text = "战场状态：%s" % _describe_battle_state()
	_refresh_drop_status()
	_refresh_battle_story()
	set_output_json(_build_output_payload())


func _describe_battle_state() -> String:
	if _prepare_payload.is_empty():
		return "等待进图"
	match _battle_phase:
		"paused":
			return "副本已暂停"
		"boss_choice":
			return "Boss 已倒，等待选择"
		"full_clear_ready":
			return "全图已清空，等待提交"
		"settling":
			return "正式结算提交中"
		_:
			return _battle_state_text


func _describe_player_feedback() -> String:
	if _prepare_payload.is_empty():
		return "这轮副本还没开始。"
	if _battle_phase == "paused":
		return "当前暂停在地图内，站位和怪物位置都会保持。"
	if _battle_phase == "boss_choice":
		return "Boss 已倒，当前先做路线选择。"
	if _battle_phase == "full_clear_ready":
		return "全清完成，完整通关时间已经本地记录。"
	if _battle_phase == "settling":
		return "战果已锁定，等待结果回传。"
	if _control_effect_timer > 0.0:
		return "保命 / 控制技能生效中。"
	if _player_hit_timer > 0.0:
		return "前线受压反馈已出现。"
	if _player_attack_timer > 0.0:
		return "自动攻击命中反馈中。"
	return "当前以自由走位、自动普攻和两个主动按钮推进。"


func _describe_player_status() -> String:
	if _prepare_payload.is_empty():
		return "等待进图"
	if _battle_phase == "paused":
		return "副本已暂停，随时可以继续"
	if _battle_phase == "boss_choice":
		return "Boss 已倒，可结算也可继续清图"
	if _battle_phase == "full_clear_ready":
		return "完整通关时间已记录，准备提交正式结算"
	if _battle_phase == "settling":
		return "结果回传中"
	return _player_status_text


func _describe_player_position() -> String:
	if _prepare_payload.is_empty():
		return "等你进入副本。"

	var x_ratio := clampf(_player_position.x / maxf(_world_size.x, 1.0), 0.0, 1.0)
	var y_ratio := clampf(_player_position.y / maxf(_world_size.y, 1.0), 0.0, 1.0)
	var lane_text := "中段"
	if x_ratio < 0.22:
		lane_text = "起始活动区"
	elif x_ratio < 0.46:
		lane_text = "巡猎带 A"
	elif x_ratio < 0.74:
		lane_text = "巡猎带 B"
	else:
		lane_text = "终点 Boss 区"
	var row_text := "上层" if y_ratio < 0.50 else "下层"
	return "%s %s。" % [lane_text, row_text]


func _describe_target_state() -> String:
	if _prepare_payload.is_empty():
		return "等待副本展开。"
	var target := _focus_target()
	if target.is_empty():
		return "当前没有存活目标。"

	var distance := Vector2(target.get("world_position", Vector2.ZERO)).distance_to(_player_position)
	var range_text := "自动普攻范围内" if distance <= AUTO_ATTACK_RANGE else "仍需压位"
	if bool(_dungeon_summary.get("boss_defeated", false)) and str(target.get("presentation_role", "normal_enemy")) != "boss_enemy":
		range_text += "，当前是在补清剩余怪"

	return "%s（%s，%s，距离 %.0f）" % [
		str(target.get("monster_name", "敌人")),
		_monster_short_role(target),
		range_text,
		distance,
	]


func _refresh_battle_story() -> void:
	if _prepare_payload.is_empty():
		battle_objective_label.text = "本场目标：先从出战页走进这张副本地图。"
		battle_pace_label.text = "战斗节奏：Boss 倒下后先做路线选择，全清后再记录完整通关时间。"
		battle_log_hint_label.text = "战报：进图、接敌、Boss 倒下、继续清图和结算选择都会留在这里。"
		return

	if _battle_phase == "boss_choice":
		battle_objective_label.text = "本场目标：决定是立即结算，还是继续清图冲完整通关时间。"
	elif _battle_phase == "full_clear_ready":
		battle_objective_label.text = "本场目标：提交全清结算，把完整通关时间和收益一起收稳。"
	elif _battle_phase == "settling":
		battle_objective_label.text = "本场目标：等待这轮正式结算收口。"
	else:
		var target := _focus_target()
		if target.is_empty():
			battle_objective_label.text = "本场目标：当前已没有存活怪物。"
		elif bool(_dungeon_summary.get("boss_defeated", false)):
			battle_objective_label.text = "本场目标：把剩余怪物清空，补齐完整通关时间。"
		elif str(target.get("presentation_role", "normal_enemy")) == "boss_enemy":
			battle_objective_label.text = "本场目标：直奔终点 Boss 区，完成这轮 Boss 击破。"
		else:
			battle_objective_label.text = "本场目标：在巡猎带推进，清怪或绕行都可以。"

	battle_pace_label.text = "地图节奏：已击杀 %d / %d | 命中 %d 次 | 受压 %d 次 | 自动拾取 %d | 用时 %.1f 秒。" % [
		_monster_states.size() - _alive_monster_count(),
		_monster_states.size(),
		_hit_count,
		_pressure_count,
		_auto_pickup_count,
		_battle_elapsed_seconds,
	]
	battle_log_hint_label.text = "战报：最新一条会顶在最前，方便直接看这轮副本的推进节奏。"
	_refresh_battle_log()


func _refresh_battle_log() -> void:
	clear_container(battle_log_box)
	if _battle_log_entries.is_empty():
		battle_log_box.add_child(_build_empty_label("战报还没有开始滚动。"))
		return

	for index in range(_battle_log_entries.size()):
		var entry: Dictionary = _battle_log_entries[index]
		battle_log_box.add_child(_build_battle_log_card(
			str(entry.get("text", "")),
			entry.get("tint", BODY_TEXT),
			index == 0
		))


func _push_battle_log(text: String, tint: Color = BODY_TEXT) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	if not _battle_log_entries.is_empty() and str(_battle_log_entries[0].get("text", "")) == trimmed:
		return

	_battle_log_entries.push_front({
		"text": trimmed,
		"tint": tint,
	})
	while _battle_log_entries.size() > 7:
		_battle_log_entries.pop_back()
	_refresh_battle_log()


func _build_battle_log_card(text: String, tint: Color, emphasize: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := _create_card_style()
	style.bg_color = Color(
		tint.r * 0.12 + CARD_BACKGROUND.r * 0.88,
		tint.g * 0.12 + CARD_BACKGROUND.g * 0.88,
		tint.b * 0.12 + CARD_BACKGROUND.b * 0.88,
		0.98
	)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.84 if emphasize else 0.52)
	style.shadow_size = 8 if emphasize else 4
	card.add_theme_stylebox_override("panel", style)

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
	tags.add_child(create_pill("最新战报" if emphasize else "前线记录", tint))
	box.add_child(tags)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = BODY_TEXT
	if emphasize:
		label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)
	return card


func _build_empty_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = CARD_TEXT_MUTED
	return label


func _interaction_locked() -> bool:
	return _battle_phase == "settling" or _battle_phase == "boss_choice" or _battle_phase == "full_clear_ready"


func _update_interaction_state() -> void:
	var in_interactive := _battle_phase == "interactive"
	if output_skill_button != null:
		output_skill_button.disabled = _prepare_payload.is_empty() or not in_interactive or _output_skill_cooldown > 0.0
		output_skill_button.text = (
			"输出技能 %.1fs" % _output_skill_cooldown
			if _output_skill_cooldown > 0.0
			else "输出技能"
		)
	if control_skill_button != null:
		control_skill_button.disabled = _prepare_payload.is_empty() or not in_interactive or _control_skill_cooldown > 0.0
		control_skill_button.text = (
			"保命 / 控制 %.1fs" % _control_skill_cooldown
			if _control_skill_cooldown > 0.0
			else "保命 / 控制"
		)
	if pause_button != null:
		pause_button.text = "继续" if _battle_phase == "paused" else "暂停"
		pause_button.disabled = _prepare_payload.is_empty() or _battle_phase == "boss_choice" or _battle_phase == "full_clear_ready" or _battle_phase == "settling"
	if continue_button != null:
		continue_button.visible = bool(_dungeon_summary.get("boss_defeated", false)) and not bool(_dungeon_summary.get("full_clear_completed", false))
		continue_button.disabled = _battle_phase != "boss_choice"
	if settle_button != null:
		settle_button.visible = bool(_dungeon_summary.get("boss_defeated", false))
		settle_button.disabled = _battle_phase != "boss_choice" and _battle_phase != "full_clear_ready"
		settle_button.text = "全清结算" if bool(_dungeon_summary.get("full_clear_completed", false)) else "立即结算"


func _toggle_pause() -> void:
	if _prepare_payload.is_empty():
		return
	if _battle_phase == "boss_choice" or _battle_phase == "full_clear_ready" or _battle_phase == "settling":
		return

	if _battle_phase == "paused":
		_battle_phase = "interactive"
		_battle_state_text = "继续推进"
		_player_status_text = "重新投入刷图"
		_push_battle_log("短暂停手后重新压回副本。", PLAYER_TINT)
	else:
		_battle_phase = "paused"
		_battle_state_text = "副本已暂停"
		_player_status_text = "当前站位已冻结"
		_push_battle_log("先暂停看清楚地图和怪物分布。", BODY_TEXT)

	_refresh_status_panels()
	_update_interaction_state()


func _sync_dungeon_summary(settle_route: String) -> void:
	if _dungeon_summary.is_empty():
		return

	var defeated_ids: Array = []
	var remaining_normal := 0
	var remaining_elite := 0
	var remaining_boss := 0
	for monster_state in _monster_states:
		var presentation_role := str(monster_state.get("presentation_role", "normal_enemy"))
		if bool(monster_state.get("alive", false)):
			match presentation_role:
				"boss_enemy":
					remaining_boss += 1
				"elite_enemy":
					remaining_elite += 1
				_:
					remaining_normal += 1
		else:
			defeated_ids.append(str(monster_state.get("monster_id", "")))

	_dungeon_summary["remaining_monster_count"] = remaining_normal + remaining_elite + remaining_boss
	_dungeon_summary["remaining_normal_count"] = remaining_normal
	_dungeon_summary["remaining_elite_count"] = remaining_elite
	_dungeon_summary["remaining_boss_count"] = remaining_boss
	_dungeon_summary["defeated_monster_ids"] = defeated_ids
	_dungeon_summary["settle_route"] = settle_route
	_dungeon_summary["settled"] = _battle_phase == "settling"
	_dungeon_summary["boss_loot_ready"] = bool(_dungeon_summary.get("boss_defeated", false))


func _emit_dungeon_summary_changed() -> void:
	if _dungeon_summary.is_empty():
		return
	_emit_context("dungeon_summary_changed", {
		"dungeon_summary": _dungeon_summary.duplicate(true),
	})


func _alive_monster_count() -> int:
	var count := 0
	for monster_state in _monster_states:
		if bool(monster_state.get("alive", false)):
			count += 1
	return count


func _remaining_count_by_role(presentation_role: String) -> int:
	var count := 0
	for monster_state in _monster_states:
		if bool(monster_state.get("alive", false)) and str(monster_state.get("presentation_role", "normal_enemy")) == presentation_role:
			count += 1
	return count


func _boss_guard_promotion_count() -> int:
	var count := 0
	for monster_state in _monster_states:
		if bool(monster_state.get("is_promoted_elite_guard", false)):
			count += 1
	return count


func _monster_tint(presentation_role: String) -> Color:
	match presentation_role:
		"boss_enemy":
			return BOSS_TINT
		"elite_enemy":
			return ELITE_TINT
		_:
			return NORMAL_TINT


func _monster_short_role(monster_state: Dictionary) -> String:
	var presentation_role := str(monster_state.get("presentation_role", "normal_enemy"))
	match presentation_role:
		"boss_enemy":
			return "Boss"
		"elite_enemy":
			if bool(monster_state.get("is_promoted_elite_guard", false)):
				return "护卫位"
			return "精英"
		_:
			return "普通"


func _monster_aggro_range(presentation_role: String) -> float:
	match presentation_role:
		"boss_enemy":
			return 280.0
		"elite_enemy":
			return 220.0
		_:
			return 156.0


func _monster_attack_range(presentation_role: String) -> float:
	match presentation_role:
		"boss_enemy":
			return 124.0
		"elite_enemy":
			return 98.0
		_:
			return 80.0


func _monster_move_speed(presentation_role: String) -> float:
	match presentation_role:
		"boss_enemy":
			return 84.0
		"elite_enemy":
			return 92.0
		_:
			return 82.0


func _monster_leash_radius(presentation_role: String) -> float:
	match presentation_role:
		"boss_enemy":
			return 168.0
		"elite_enemy":
			return 144.0
		_:
			return 108.0


func _monster_attack_cooldown(presentation_role: String) -> float:
	match presentation_role:
		"boss_enemy":
			return 1.2
		"elite_enemy":
			return 1.0
		_:
			return 0.86


func _section_tint(label: String) -> Color:
	if label.find("起始") >= 0:
		return START_ZONE_TINT
	if label.find("Boss") >= 0:
		return BOSS_ZONE_TINT
	if label.find("巡猎") >= 0:
		return NORMAL_ZONE_TINT
	return ELITE_ZONE_TINT


func _build_output_payload() -> Dictionary:
	return {
		"prepare_payload": _prepare_payload,
		"dungeon_summary": _dungeon_summary,
		"battle_phase": _battle_phase,
	}


func _bump_screen_shake(strength: float, duration: float) -> void:
	_screen_shake_strength = maxf(_screen_shake_strength, strength)
	_screen_shake_timer = maxf(_screen_shake_timer, duration)


func _on_battle_view_resized() -> void:
	if _prepare_payload.is_empty():
		return
	_build_monster_states()
	_sync_world()
	_sync_header()
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


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _as_array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

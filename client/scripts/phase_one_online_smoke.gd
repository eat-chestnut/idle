extends SceneTree

const BackendApi = preload("res://client/scripts/backend_api.gd")


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const SMOKE_LOG_PREFIX := "[client-online-smoke]"
const DEFAULT_BASE_URL := "http://127.0.0.1:8000"
const DEFAULT_BEARER_TOKEN := "test-token-2001"
const DEFAULT_SMOKE_CLASS_ID := "class_jingang"
const READY_PROFILE := "interop"

const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1
const EXIT_USAGE := 2

const HELP_FLAGS := ["--help", "-h"]


# ------------------------------------------------------------------------------
# Runtime state
# ------------------------------------------------------------------------------
var _base_url := DEFAULT_BASE_URL
var _bearer_token := DEFAULT_BEARER_TOKEN
var _should_print_help := false


# ------------------------------------------------------------------------------
# Entry
# ------------------------------------------------------------------------------
func _initialize() -> void:
	var parse_error := _parse_args(OS.get_cmdline_user_args())

	if _should_print_help:
		_print_usage()
		quit(EXIT_SUCCESS)
		return

	if not parse_error.is_empty():
		printerr("%s %s" % [SMOKE_LOG_PREFIX, parse_error])
		_print_usage()
		quit(EXIT_USAGE)
		return

	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var exit_code := await _execute_smoke()
	quit(exit_code)


func _execute_smoke() -> int:
	var api = BackendApi.new(root, _base_url, _bearer_token)
	_print_runtime_context()

	# Phase 1: readiness / interop prerequisites.
	_log_phase("ready")
	if not await _ensure_ready(api):
		return EXIT_FAILURE

	# Phase 2: select an existing character or create the smallest legal one.
	_log_phase("character")
	var selected_character := await _select_or_create_character(api)
	if selected_character.is_empty():
		return EXIT_FAILURE

	var character_id := _resolve_character_id(selected_character)
	if character_id <= 0:
		return EXIT_FAILURE

	# Phase 3: keep the smoke chain aligned with the real active-character flow.
	_log_phase("activate")
	var active_character := await _activate_character(api, character_id)
	if active_character.is_empty():
		return EXIT_FAILURE

	# Phase 4: walk the first backend-provided chapter -> stage -> difficulty path.
	_log_phase("stage")
	var stage_target := await _load_stage_target(api)
	if stage_target.is_empty():
		return EXIT_FAILURE

	# Phase 5: prepare a real battle context through the formal backend API.
	_log_phase("prepare")
	var prepare_payload := await _prepare_battle(api, character_id, stage_target)
	if prepare_payload.is_empty():
		return EXIT_FAILURE

	# Phase 6: settle the prepared battle with the real battle context id.
	_log_phase("settle")
	var battle_context_id := str(prepare_payload.get("battle_context_id", ""))
	var monster_ids := _as_array(prepare_payload.get("monster_ids", []))
	var settle_payload := await _settle_battle(
		api,
		character_id,
		stage_target,
		battle_context_id,
		monster_ids
	)
	if settle_payload.is_empty():
		return EXIT_FAILURE

	# Phase 7: print a compact, machine-friendly success summary.
	_log_phase("summary")
	var summary := _build_success_summary(
		character_id,
		stage_target,
		battle_context_id,
		monster_ids,
		settle_payload
	)

	print("%s success" % SMOKE_LOG_PREFIX)
	_print_json(summary)
	return EXIT_SUCCESS


# ------------------------------------------------------------------------------
# CLI parsing and usage
# ------------------------------------------------------------------------------
func _parse_args(args: Array) -> String:
	var index := 0

	while index < args.size():
		var arg := str(args[index])

		if arg in HELP_FLAGS:
			_should_print_help = true
		elif arg.begins_with("--base-url="):
			_base_url = arg.trim_prefix("--base-url=").strip_edges()
		elif arg == "--base-url":
			index += 1
			if index >= args.size():
				return "--base-url requires a value"
			_base_url = str(args[index]).strip_edges()
		elif arg.begins_with("--bearer-token="):
			_bearer_token = arg.trim_prefix("--bearer-token=").strip_edges()
		elif arg == "--bearer-token":
			index += 1
			if index >= args.size():
				return "--bearer-token requires a value"
			_bearer_token = str(args[index]).strip_edges()
		else:
			return "unknown argument: %s" % arg

		index += 1

	if _base_url.is_empty():
		return "base_url is required"

	if _bearer_token.is_empty():
		return "bearer_token is required"

	return ""


func _print_usage() -> void:
	print(
		"\n".join([
			"Usage:",
			"  godot --headless --path . --script ./client/scripts/phase_one_online_smoke.gd -- \\",
			"    --base-url=http://127.0.0.1:8000 \\",
			"    --bearer-token=test-token-2001",
			"",
			"Options:",
			"  --base-url=... or --base-url ...",
			"  --bearer-token=... or --bearer-token ...",
			"  --help, -h",
			"",
			"Covered flow:",
			"  readyz -> characters -> activate -> chapters -> stages -> difficulties -> prepare -> settle",
			"",
			"Notes:",
			"  - Reuses an active character when available.",
			"  - Creates a smallest legal character only when the account is empty.",
			"  - Always uses the first backend-provided chapter, stage, and difficulty.",
			"  - Does not invent battle_context_id or reward status locally.",
		])
	)


func _print_runtime_context() -> void:
	print("%s base_url=%s" % [SMOKE_LOG_PREFIX, _base_url])
	print("%s ready_profile=%s" % [SMOKE_LOG_PREFIX, READY_PROFILE])
	print("%s smoke_class_id=%s" % [SMOKE_LOG_PREFIX, DEFAULT_SMOKE_CLASS_ID])
	print("%s bearer_token_length=%s" % [SMOKE_LOG_PREFIX, str(_bearer_token.length())])


func _log_phase(phase_name: String) -> void:
	print("%s phase=%s" % [SMOKE_LOG_PREFIX, phase_name])


# ------------------------------------------------------------------------------
# Ready check
# ------------------------------------------------------------------------------
func _ensure_ready(api) -> bool:
	var ready_result: Dictionary = await api.request_public_json(
		"GET",
		"/readyz",
		{"profile": READY_PROFILE}
	)
	if not ready_result.get("ok", false):
		_fail("readyz", ready_result)
		return false

	var ready_data := _as_dictionary(ready_result.get("data", {}))
	if bool(ready_data.get("ready", false)):
		return true

	printerr("%s readyz returned ready=false" % SMOKE_LOG_PREFIX)
	_print_json(ready_data)
	return false


# ------------------------------------------------------------------------------
# Character flow
# ------------------------------------------------------------------------------
func _select_or_create_character(api) -> Dictionary:
	var list_result: Dictionary = await api.request_json("GET", "/api/characters")
	if not list_result.get("ok", false):
		_fail("characters.list", list_result)
		return {}

	var characters := _as_array(_as_dictionary(list_result.get("data", {})).get("characters", []))
	var selected_character := _pick_character_candidate(characters)
	if not selected_character.is_empty():
		print("%s selected_character_strategy=reuse" % SMOKE_LOG_PREFIX)
		_print_json({
			"character_id": int(selected_character.get("character_id", 0)),
			"is_active": int(selected_character.get("is_active", 0)),
		})
		return selected_character

	var create_result: Dictionary = await api.request_json("POST", "/api/characters", {
		"class_id": DEFAULT_SMOKE_CLASS_ID,
		"character_name": _build_smoke_character_name(),
	})
	if not create_result.get("ok", false):
		_fail("characters.create", create_result)
		return {}

	selected_character = _as_dictionary(_as_dictionary(create_result.get("data", {})).get("character", {}))
	if selected_character.is_empty():
		printerr("%s characters.create returned empty character payload" % SMOKE_LOG_PREFIX)
		return {}

	print("%s selected_character_strategy=create" % SMOKE_LOG_PREFIX)
	_print_json({
		"character_id": int(selected_character.get("character_id", 0)),
		"is_active": int(selected_character.get("is_active", 0)),
	})
	return selected_character


func _activate_character(api, character_id: int) -> Dictionary:
	var activate_result: Dictionary = await api.request_json(
		"POST",
		"/api/characters/%s/activate" % str(character_id)
	)
	if not activate_result.get("ok", false):
		_fail("characters.activate", activate_result)
		return {}

	var refreshed_list_result: Dictionary = await api.request_json("GET", "/api/characters")
	if not refreshed_list_result.get("ok", false):
		_fail("characters.list.after_activate", refreshed_list_result)
		return {}

	var characters := _as_array(_as_dictionary(refreshed_list_result.get("data", {})).get("characters", []))
	var active_character := _find_character(characters, character_id)
	if int(active_character.get("is_active", 0)) == 1:
		return active_character

	printerr("%s activate did not leave selected character in active state" % SMOKE_LOG_PREFIX)
	_print_json(active_character)
	return {}


func _resolve_character_id(selected_character: Dictionary) -> int:
	var character_id := int(selected_character.get("character_id", 0))
	if character_id > 0:
		return character_id

	printerr("%s invalid character_id in selected character payload" % SMOKE_LOG_PREFIX)
	_print_json(selected_character)
	return 0


func _pick_character_candidate(records: Array) -> Dictionary:
	for record in records:
		var entry := _as_dictionary(record)
		if int(entry.get("is_active", 0)) == 1:
			return entry

	if records.is_empty():
		return {}

	return _as_dictionary(records[0])


func _build_smoke_character_name() -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var normalized_timestamp := timestamp.replace(":", "").replace("-", "").replace(" ", "_")
	return "smoke_%s" % normalized_timestamp


# ------------------------------------------------------------------------------
# Stage target flow
# ------------------------------------------------------------------------------
func _load_stage_target(api) -> Dictionary:
	var chapter_id := await _load_first_chapter_id(api)
	if chapter_id.is_empty():
		return {}

	var stage_id := await _load_first_stage_id(api, chapter_id)
	if stage_id.is_empty():
		return {}

	var stage_difficulty_id := await _load_first_stage_difficulty_id(api, stage_id)
	if stage_difficulty_id.is_empty():
		return {}

	var reward_status_before := await _load_reward_status_before(api, stage_difficulty_id)
	if reward_status_before.is_empty():
		return {}

	return {
		"chapter_id": chapter_id,
		"stage_id": stage_id,
		"stage_difficulty_id": stage_difficulty_id,
		"reward_status_before": reward_status_before,
	}


func _load_first_chapter_id(api) -> String:
	var chapters_result: Dictionary = await api.request_json("GET", "/api/chapters")
	if not chapters_result.get("ok", false):
		_fail("chapters.list", chapters_result)
		return ""

	var chapters := _as_array(_as_dictionary(chapters_result.get("data", {})).get("chapters", []))
	return _first_identifier(chapters, "chapter_id", "chapters")


func _load_first_stage_id(api, chapter_id: String) -> String:
	var stages_result: Dictionary = await api.request_json("GET", "/api/chapters/%s/stages" % chapter_id)
	if not stages_result.get("ok", false):
		_fail("stages.list", stages_result)
		return ""

	var stages := _as_array(_as_dictionary(stages_result.get("data", {})).get("stages", []))
	return _first_identifier(stages, "stage_id", "stages")


func _load_first_stage_difficulty_id(api, stage_id: String) -> String:
	var difficulties_result: Dictionary = await api.request_json("GET", "/api/stages/%s/difficulties" % stage_id)
	if not difficulties_result.get("ok", false):
		_fail("difficulties.list", difficulties_result)
		return ""

	var difficulties := _as_array(_as_dictionary(difficulties_result.get("data", {})).get("difficulties", []))
	return _first_identifier(difficulties, "stage_difficulty_id", "difficulties")


func _load_reward_status_before(api, stage_difficulty_id: String) -> Dictionary:
	var reward_status_result: Dictionary = await api.request_json(
		"GET",
		"/api/stage-difficulties/%s/first-clear-reward-status" % stage_difficulty_id
	)
	if not reward_status_result.get("ok", false):
		_fail("reward_status.before", reward_status_result)
		return {}

	return _as_dictionary(reward_status_result.get("data", {}))


# ------------------------------------------------------------------------------
# Battle flow
# ------------------------------------------------------------------------------
func _prepare_battle(api, character_id: int, stage_target: Dictionary) -> Dictionary:
	var prepare_result: Dictionary = await api.request_json("POST", "/api/battles/prepare", {
		"character_id": character_id,
		"stage_difficulty_id": str(stage_target.get("stage_difficulty_id", "")),
	})
	if not prepare_result.get("ok", false):
		_fail("battles.prepare", prepare_result)
		return {}

	var prepare_data := _as_dictionary(prepare_result.get("data", {}))
	var battle_context_id := str(prepare_data.get("battle_context_id", "")).strip_edges()
	var monster_ids := _extract_monster_ids(prepare_data)

	if battle_context_id.is_empty() or monster_ids.is_empty():
		printerr("%s prepare payload missing battle_context_id or monster_list" % SMOKE_LOG_PREFIX)
		_print_json(prepare_data)
		return {}

	return {
		"battle_context_id": battle_context_id,
		"monster_ids": monster_ids,
	}


func _settle_battle(
	api,
	character_id: int,
	stage_target: Dictionary,
	battle_context_id: String,
	monster_ids: Array
) -> Dictionary:
	var settle_result: Dictionary = await api.request_json("POST", "/api/battles/settle", {
		"character_id": character_id,
		"stage_difficulty_id": str(stage_target.get("stage_difficulty_id", "")),
		"battle_context_id": battle_context_id,
		"is_cleared": 1,
		"killed_monsters": monster_ids,
	})
	if not settle_result.get("ok", false):
		_fail("battles.settle", settle_result)
		return {}

	return _as_dictionary(settle_result.get("data", {}))


# ------------------------------------------------------------------------------
# Success summary
# ------------------------------------------------------------------------------
func _build_success_summary(
	character_id: int,
	stage_target: Dictionary,
	battle_context_id: String,
	monster_ids: Array,
	settle_data: Dictionary
) -> Dictionary:
	var settlement_summary := _as_dictionary(settle_data.get("settlement_summary", {}))

	return {
		"base_url": _base_url,
		"character_id": character_id,
		"chapter_id": str(stage_target.get("chapter_id", "")),
		"stage_id": str(stage_target.get("stage_id", "")),
		"stage_difficulty_id": str(stage_target.get("stage_difficulty_id", "")),
		"battle_context_id": battle_context_id,
		"monster_count": monster_ids.size(),
		"drop_count": _as_array(settle_data.get("drop_results", [])).size(),
		"reward_count": _as_array(settle_data.get("reward_results", [])).size(),
		"created_equipment_instance_count": int(
			settlement_summary.get("created_equipment_instance_count", 0)
		),
		"reward_status_before": _as_dictionary(stage_target.get("reward_status_before", {})),
		"reward_status_after": _as_dictionary(settle_data.get("first_clear_reward_status", {})),
		"settlement_summary": settlement_summary,
	}


# ------------------------------------------------------------------------------
# Shared helpers
# ------------------------------------------------------------------------------
func _first_identifier(records: Array, field_name: String, label: String) -> String:
	if records.is_empty():
		printerr("%s %s list is empty" % [SMOKE_LOG_PREFIX, label])
		return ""

	var identifier := str(_as_dictionary(records[0]).get(field_name, "")).strip_edges()
	if identifier.is_empty():
		printerr("%s %s is empty" % [SMOKE_LOG_PREFIX, field_name])
		return ""

	return identifier


func _find_character(records: Array, character_id: int) -> Dictionary:
	for record in records:
		var entry := _as_dictionary(record)
		if int(entry.get("character_id", 0)) == character_id:
			return entry

	return {}


func _extract_monster_ids(payload: Dictionary) -> Array:
	var result: Array = []

	for monster in _as_array(payload.get("monster_list", [])):
		var monster_id := str(_as_dictionary(monster).get("monster_id", "")).strip_edges()
		if not monster_id.is_empty():
			result.append(monster_id)

	return result


func _fail(step: String, result: Dictionary) -> int:
	printerr(
		"%s %s failed: kind=%s code=%s http_status=%s message=%s" % [
			SMOKE_LOG_PREFIX,
			step,
			str(result.get("kind", "unknown")),
			str(result.get("code", -1)),
			str(result.get("http_status", 0)),
			str(result.get("message", "request failed")),
		]
	)
	_print_json(_as_dictionary(result.get("raw", {})))
	return 1


func _print_json(value: Variant) -> void:
	print(JSON.stringify(value, "  "))


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value

	return {}


func _as_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value

	return []

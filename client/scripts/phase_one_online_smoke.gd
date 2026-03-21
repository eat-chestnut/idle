extends SceneTree

# Headless smoke that walks the real phase-one client/backend main path:
# readyz -> character -> activate -> chapter/stage/difficulty -> prepare -> settle.
const BackendApi = preload("res://client/scripts/backend_api.gd")
const SMOKE_LOG_PREFIX := "[client-online-smoke]"
const DEFAULT_BASE_URL := "http://127.0.0.1:8000"
const DEFAULT_BEARER_TOKEN := "test-token-2001"
const DEFAULT_SMOKE_CLASS_ID := "class_jingang"
const READY_PROFILE := "interop"
const EXIT_SUCCESS := 0
const EXIT_FAILURE := 1
const EXIT_USAGE := 2
const HELP_FLAGS := ["--help", "-h"]

var _base_url := DEFAULT_BASE_URL
var _bearer_token := DEFAULT_BEARER_TOKEN
var _should_print_help := false


# ----- Entry / lifecycle -----
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
	# Keep the smoke flow aligned with the player-facing client order so the
	# output stays useful for merge-gate triage and manual handoff.
	var api = BackendApi.new(root, _base_url, _bearer_token)
	_print_runtime_context()

	if not await _ensure_ready(api):
		return EXIT_FAILURE

	# Character selection stays aligned with the real client entry path:
	# reuse an active character first, then create the smallest legal fallback.
	var selected_character := await _select_or_create_character(api)
	if selected_character.is_empty():
		return EXIT_FAILURE

	var character_id := _resolve_character_id(selected_character)
	if character_id <= 0:
		return EXIT_FAILURE

	if (await _activate_character(api, character_id)).is_empty():
		return EXIT_FAILURE

	# Stage selection deliberately follows "first real backend-provided option"
	# so the smoke stays deterministic without inventing any local fixtures.
	var stage_target := await _load_stage_target(api)
	if stage_target.is_empty():
		return EXIT_FAILURE

	var prepare_payload := await _prepare_battle(api, character_id, stage_target)
	if prepare_payload.is_empty():
		return EXIT_FAILURE

	var settle_data := await _settle_battle(
		api,
		character_id,
		stage_target,
		str(prepare_payload.get("battle_context_id", "")),
		_as_array(prepare_payload.get("monster_ids", []))
	)
	if settle_data.is_empty():
		return EXIT_FAILURE

	var summary := _build_success_summary(
		character_id,
		stage_target,
		str(prepare_payload.get("battle_context_id", "")),
		_as_array(prepare_payload.get("monster_ids", [])),
		settle_data
	)

	print("%s success" % SMOKE_LOG_PREFIX)
	_print_json(summary)
	return EXIT_SUCCESS


# ----- CLI / runtime context -----
func _parse_args(args: Array) -> String:
	for raw_arg in args:
		var arg := str(raw_arg)
		if arg in HELP_FLAGS:
			_should_print_help = true
		elif arg.begins_with("--base-url="):
			_base_url = arg.trim_prefix("--base-url=").strip_edges()
		elif arg.begins_with("--bearer-token="):
			_bearer_token = arg.trim_prefix("--bearer-token=").strip_edges()

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
			"Optional flags:",
			"  --base-url=...       backend base URL, defaults to %s" % DEFAULT_BASE_URL,
			"  --bearer-token=...   bearer token, defaults to %s" % DEFAULT_BEARER_TOKEN,
			"  --help, -h           print this help and exit",
			"",
			"Covered flow:",
			"  readyz -> characters -> activate -> chapters/stages/difficulties -> prepare -> settle",
		])
	)


func _print_runtime_context() -> void:
	print(
		"%s base_url=%s ready_profile=%s" % [
			SMOKE_LOG_PREFIX,
			_base_url,
			READY_PROFILE,
		]
	)


# ----- Character helpers -----
func _resolve_character_id(selected_character: Dictionary) -> int:
	var character_id := int(selected_character.get("character_id", 0))
	if character_id > 0:
		return character_id

	printerr("%s invalid character_id in selected character payload" % SMOKE_LOG_PREFIX)
	_print_json(selected_character)
	return 0


func _pick_active_character(records: Array) -> Dictionary:
	for record in records:
		var entry := _as_dictionary(record)
		if int(entry.get("is_active", 0)) == 1:
			return entry

	if records.is_empty():
		return {}

	return _as_dictionary(records[0])


func _select_or_create_character(api) -> Dictionary:
	var list_result: Dictionary = await api.request_json("GET", "/api/characters")
	if not list_result.get("ok", false):
		_fail("characters.list", list_result)
		return {}

	var list_data := _as_dictionary(list_result.get("data", {}))
	var characters := _as_array(list_data.get("characters", []))
	var selected_character := _pick_active_character(characters)
	if not selected_character.is_empty():
		return selected_character

	# Reuse the formal character-create API instead of inventing a local smoke fixture.
	var create_result: Dictionary = await api.request_json("POST", "/api/characters", {
		"class_id": DEFAULT_SMOKE_CLASS_ID,
		"character_name": _build_smoke_character_name(),
	})
	if not create_result.get("ok", false):
		_fail("characters.create", create_result)
		return {}

	var create_data := _as_dictionary(create_result.get("data", {}))
	selected_character = _as_dictionary(create_data.get("character", {}))
	if selected_character.is_empty():
		printerr("%s characters.create returned empty character payload" % SMOKE_LOG_PREFIX)

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
	var selected_character := _find_character(characters, character_id)
	if int(selected_character.get("is_active", 0)) != 1:
		printerr("%s activate did not leave selected character in active state" % SMOKE_LOG_PREFIX)
		_print_json(selected_character)
		return {}

	return selected_character


# ----- Stage selection helpers -----
func _build_stage_target(
	chapter_id: String,
	stage_id: String,
	stage_difficulty_id: String,
	reward_status_before: Dictionary
) -> Dictionary:
	return {
		"chapter_id": chapter_id,
		"stage_id": stage_id,
		"stage_difficulty_id": stage_difficulty_id,
		"reward_status_before": reward_status_before,
	}


func _load_stage_target(api) -> Dictionary:
	# Pick the first backend-provided chapter/stage/difficulty instead of
	# inventing any local ordering or synthetic smoke fixture.
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

	return _build_stage_target(chapter_id, stage_id, stage_difficulty_id, reward_status_before)


func _validate_ready_payload(ready_data: Dictionary) -> bool:
	if bool(ready_data.get("ready", false)):
		return true

	printerr("%s readyz returned ready=false" % SMOKE_LOG_PREFIX)
	_print_json(ready_data)
	return false


func _ensure_ready(api) -> bool:
	var ready_result: Dictionary = await api.request_public_json("GET", "/readyz", {"profile": READY_PROFILE})
	if not ready_result.get("ok", false):
		_fail("readyz", ready_result)
		return false

	var ready_data := _as_dictionary(ready_result.get("data", {}))
	if not _validate_ready_payload(ready_data):
		return false

	return true


# ----- Battle helpers -----
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


func _build_success_summary(
	character_id: int,
	stage_target: Dictionary,
	battle_context_id: String,
	monster_ids: Array,
	settle_data: Dictionary
) -> Dictionary:
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
		"reward_status_before": _as_dictionary(stage_target.get("reward_status_before", {})),
		"reward_status_after": _as_dictionary(settle_data.get("first_clear_reward_status", {})),
	}


# ----- Backend list readers -----
func _build_smoke_character_name() -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var normalized_timestamp := timestamp.replace(":", "").replace("-", "").replace(" ", "_")
	return "smoke_%s" % normalized_timestamp


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
	var reward_status_before_result: Dictionary = await api.request_json(
		"GET",
		"/api/stage-difficulties/%s/first-clear-reward-status" % stage_difficulty_id
	)
	if not reward_status_before_result.get("ok", false):
		_fail("reward_status.before", reward_status_before_result)
		return {}

	return _as_dictionary(reward_status_before_result.get("data", {}))


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


# ----- Shared output / coercion helpers -----
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

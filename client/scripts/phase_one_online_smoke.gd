extends SceneTree

const BackendApi = preload("res://client/scripts/backend_api.gd")

var _base_url := "http://127.0.0.1:8000"
var _bearer_token := "test-token-2001"


func _initialize() -> void:
	var parse_error := _parse_args(OS.get_cmdline_user_args())
	if not parse_error.is_empty():
		printerr("[client-online-smoke] %s" % parse_error)
		quit(2)
		return

	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var exit_code := await _execute_smoke()
	quit(exit_code)


func _execute_smoke() -> int:
	var api = BackendApi.new(root, _base_url, _bearer_token)

	var ready_result: Dictionary = await api.request_public_json("GET", "/readyz", {"profile": "interop"})
	if not ready_result.get("ok", false):
		return _fail("readyz", ready_result)

	var ready_data := _as_dictionary(ready_result.get("data", {}))
	if not bool(ready_data.get("ready", false)):
		printerr("[client-online-smoke] readyz returned ready=false")
		print(JSON.stringify(ready_data, "  "))
		return 1

	var list_result: Dictionary = await api.request_json("GET", "/api/characters")
	if not list_result.get("ok", false):
		return _fail("characters.list", list_result)

	var list_data := _as_dictionary(list_result.get("data", {}))
	var characters := _as_array(list_data.get("characters", []))
	var selected_character := _pick_active_character(characters)

	if selected_character.is_empty():
		var create_result: Dictionary = await api.request_json("POST", "/api/characters", {
			"class_id": "class_jingang",
			"character_name": "smoke_%s" % Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace(" ", "_"),
		})
		if not create_result.get("ok", false):
			return _fail("characters.create", create_result)

		var create_data := _as_dictionary(create_result.get("data", {}))
		selected_character = _as_dictionary(create_data.get("character", {}))
		if selected_character.is_empty():
			printerr("[client-online-smoke] characters.create returned empty character payload")
			return 1

	var character_id := int(selected_character.get("character_id", 0))
	if character_id <= 0:
		printerr("[client-online-smoke] invalid character_id in selected character payload")
		print(JSON.stringify(selected_character, "  "))
		return 1

	var activate_result: Dictionary = await api.request_json("POST", "/api/characters/%s/activate" % str(character_id))
	if not activate_result.get("ok", false):
		return _fail("characters.activate", activate_result)

	var refreshed_list_result: Dictionary = await api.request_json("GET", "/api/characters")
	if not refreshed_list_result.get("ok", false):
		return _fail("characters.list.after_activate", refreshed_list_result)

	characters = _as_array(_as_dictionary(refreshed_list_result.get("data", {})).get("characters", []))
	selected_character = _find_character(characters, character_id)
	if int(selected_character.get("is_active", 0)) != 1:
		printerr("[client-online-smoke] activate did not leave selected character in active state")
		print(JSON.stringify(selected_character, "  "))
		return 1

	var chapters_result: Dictionary = await api.request_json("GET", "/api/chapters")
	if not chapters_result.get("ok", false):
		return _fail("chapters.list", chapters_result)

	var chapters := _as_array(_as_dictionary(chapters_result.get("data", {})).get("chapters", []))
	if chapters.is_empty():
		printerr("[client-online-smoke] chapters list is empty")
		return 1

	var chapter_id := str(_as_dictionary(chapters[0]).get("chapter_id", "")).strip_edges()
	if chapter_id.is_empty():
		printerr("[client-online-smoke] chapter_id is empty")
		return 1

	var stages_result: Dictionary = await api.request_json("GET", "/api/chapters/%s/stages" % chapter_id)
	if not stages_result.get("ok", false):
		return _fail("stages.list", stages_result)

	var stages := _as_array(_as_dictionary(stages_result.get("data", {})).get("stages", []))
	if stages.is_empty():
		printerr("[client-online-smoke] stages list is empty")
		return 1

	var stage_id := str(_as_dictionary(stages[0]).get("stage_id", "")).strip_edges()
	if stage_id.is_empty():
		printerr("[client-online-smoke] stage_id is empty")
		return 1

	var difficulties_result: Dictionary = await api.request_json("GET", "/api/stages/%s/difficulties" % stage_id)
	if not difficulties_result.get("ok", false):
		return _fail("difficulties.list", difficulties_result)

	var difficulties := _as_array(_as_dictionary(difficulties_result.get("data", {})).get("difficulties", []))
	if difficulties.is_empty():
		printerr("[client-online-smoke] difficulties list is empty")
		return 1

	var stage_difficulty_id := str(_as_dictionary(difficulties[0]).get("stage_difficulty_id", "")).strip_edges()
	if stage_difficulty_id.is_empty():
		printerr("[client-online-smoke] stage_difficulty_id is empty")
		return 1

	var reward_status_before_result: Dictionary = await api.request_json(
		"GET",
		"/api/stage-difficulties/%s/first-clear-reward-status" % stage_difficulty_id
	)
	if not reward_status_before_result.get("ok", false):
		return _fail("reward_status.before", reward_status_before_result)

	var reward_status_before := _as_dictionary(reward_status_before_result.get("data", {}))

	var prepare_result: Dictionary = await api.request_json("POST", "/api/battles/prepare", {
		"character_id": character_id,
		"stage_difficulty_id": stage_difficulty_id,
	})
	if not prepare_result.get("ok", false):
		return _fail("battles.prepare", prepare_result)

	var prepare_data := _as_dictionary(prepare_result.get("data", {}))
	var battle_context_id := str(prepare_data.get("battle_context_id", "")).strip_edges()
	var monster_ids := _extract_monster_ids(prepare_data)
	if battle_context_id.is_empty() or monster_ids.is_empty():
		printerr("[client-online-smoke] prepare payload missing battle_context_id or monster_list")
		print(JSON.stringify(prepare_data, "  "))
		return 1

	var settle_result: Dictionary = await api.request_json("POST", "/api/battles/settle", {
		"character_id": character_id,
		"stage_difficulty_id": stage_difficulty_id,
		"battle_context_id": battle_context_id,
		"is_cleared": 1,
		"killed_monsters": monster_ids,
	})
	if not settle_result.get("ok", false):
		return _fail("battles.settle", settle_result)

	var settle_data := _as_dictionary(settle_result.get("data", {}))
	var reward_status_after := _as_dictionary(settle_data.get("first_clear_reward_status", {}))
	var summary := {
		"base_url": _base_url,
		"character_id": character_id,
		"chapter_id": chapter_id,
		"stage_id": stage_id,
		"stage_difficulty_id": stage_difficulty_id,
		"battle_context_id": battle_context_id,
		"monster_count": monster_ids.size(),
		"drop_count": _as_array(settle_data.get("drop_results", [])).size(),
		"reward_count": _as_array(settle_data.get("reward_results", [])).size(),
		"reward_status_before": reward_status_before,
		"reward_status_after": reward_status_after,
	}

	print("[client-online-smoke] success")
	print(JSON.stringify(summary, "  "))
	return 0


func _parse_args(args: Array) -> String:
	for raw_arg in args:
		var arg := str(raw_arg)
		if arg.begins_with("--base-url="):
			_base_url = arg.trim_prefix("--base-url=").strip_edges()
		elif arg.begins_with("--bearer-token="):
			_bearer_token = arg.trim_prefix("--bearer-token=").strip_edges()

	if _base_url.is_empty():
		return "base_url is required"
	if _bearer_token.is_empty():
		return "bearer_token is required"

	return ""


func _pick_active_character(records: Array) -> Dictionary:
	for record in records:
		var entry := _as_dictionary(record)
		if int(entry.get("is_active", 0)) == 1:
			return entry

	if records.is_empty():
		return {}

	return _as_dictionary(records[0])


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
		"[client-online-smoke] %s failed: kind=%s code=%s http_status=%s message=%s" % [
			step,
			str(result.get("kind", "unknown")),
			str(result.get("code", -1)),
			str(result.get("http_status", 0)),
			str(result.get("message", "request failed")),
		]
	)
	print(JSON.stringify(_as_dictionary(result.get("raw", {})), "  "))
	return 1


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value

	return {}


func _as_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value

	return []

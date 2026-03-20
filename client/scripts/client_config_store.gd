extends RefCounted
class_name ClientConfigStore

const CONFIG_PATH := "user://phase_one_client.cfg"
const CONFIG_SECTION := "phase_one_client"
const DEFAULTS := {
	"base_url": "http://127.0.0.1:8000",
	"bearer_token": "test-token-2001",
	"class_id": "class_jingang",
	"character_name": "联调角色",
	"character_id": "1001",
	"battle_character_id": "1001",
	"stage_id": "stage_nanshan_001",
	"stage_difficulty_id": "stage_nanshan_001_normal",
}


static func load_config() -> Dictionary:
	var resolved := DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	var load_error := config.load(CONFIG_PATH)

	if load_error != OK:
		return resolved

	for key in DEFAULTS.keys():
		resolved[key] = String(config.get_value(CONFIG_SECTION, key, DEFAULTS[key]))

	return resolved


static func save_config(values: Dictionary) -> int:
	var config := ConfigFile.new()

	for key in DEFAULTS.keys():
		config.set_value(CONFIG_SECTION, key, String(values.get(key, DEFAULTS[key])))

	return config.save(CONFIG_PATH)

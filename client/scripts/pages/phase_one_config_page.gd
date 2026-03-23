extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneConfigPage

var base_url_input: LineEdit
var token_input: LineEdit


func _init() -> void:
	setup_page(
		"启动检查",
		[
			"这一页的主身份是启动检查入口，不是联调首页。",
			"启动时只做一次后台检查，把版本与存档服务快照记到本地运行时。",
			"本地正式存档会在这里接上继续游戏和新开局，但不会把页面变回联调入口。",
			"地址与令牌只服务弱联网检查和旧接口兼容，不代表运行期页面真相来源。",
			"当前开发默认建议：127.0.0.1:8000 + test-token-2001。",
		]
	)

	base_url_input = add_labeled_input("启动检查地址（弱联网）", "http://127.0.0.1:8000")
	token_input = add_labeled_input("兼容旧接口令牌（可留空）", "")
	base_url_input.text_changed.connect(_on_config_input_changed)
	token_input.text_changed.connect(_on_config_input_changed)

	var buttons := add_button_row()
	add_action_button(buttons, "填入开发样例", "fill_default_config")
	add_action_button(buttons, "保存弱联网配置", "save_config")
	add_action_button(buttons, "重做启动检查", "run_startup_check")

	var save_buttons := add_button_row()
	add_action_button(save_buttons, "继续游戏", "continue_local_game")
	add_action_button(save_buttons, "新开一局", "start_new_local_game")


func set_config_values(values: Dictionary) -> void:
	base_url_input.text = str(values.get("base_url", "http://127.0.0.1:8000"))
	token_input.text = str(values.get("bearer_token", "test-token-2001"))


func get_config_values() -> Dictionary:
	return {
		"base_url": base_url_input.text.strip_edges(),
		"bearer_token": token_input.text.strip_edges(),
	}


func focus_auth_inputs() -> void:
	base_url_input.grab_focus()


func _on_config_input_changed(_text: String) -> void:
	_emit_context("config_values_changed", get_config_values())

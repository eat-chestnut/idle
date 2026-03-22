extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneConfigPage

var base_url_input: LineEdit
var token_input: LineEdit


func _init() -> void:
	setup_page(
		"启动",
		[
			"启动时只做一次后台检查，把版本与存档服务快照记到本地运行时。",
			"进入游戏后，主循环应逐步以本地 runtime state 为真相，而不是持续把页面做成实时 API 壳。",
			"当前开发默认建议：127.0.0.1:8000 + test-token-2001。",
		]
	)

	base_url_input = add_labeled_input("弱联网 Backend URL", "http://127.0.0.1:8000")
	token_input = add_labeled_input("开发 Token（旧接口兼容）", "")
	base_url_input.text_changed.connect(_on_config_input_changed)
	token_input.text_changed.connect(_on_config_input_changed)

	var buttons := add_button_row()
	add_action_button(buttons, "填入开发默认值", "fill_default_config")
	add_action_button(buttons, "保存配置", "save_config")
	add_action_button(buttons, "执行启动检查", "run_startup_check")


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

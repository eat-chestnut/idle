extends "res://client/scripts/pages/phase_one_page_base.gd"
class_name PhaseOneConfigPage

var base_url_input: LineEdit
var token_input: LineEdit


func _init() -> void:
	setup_page(
		"环境与 Token",
		[
			"保存 backend 地址与 Bearer Token，并补一个最小 /readyz 联调预检。",
			"当前本地联调默认建议：127.0.0.1:8000 + test-token-2001。",
		]
	)

	base_url_input = add_labeled_input("Backend Base URL", "http://127.0.0.1:8000")
	token_input = add_labeled_input("Bearer Token", "")
	base_url_input.text_changed.connect(_on_config_input_changed)
	token_input.text_changed.connect(_on_config_input_changed)

	var buttons := add_button_row()
	add_action_button(buttons, "填入联调默认值", "fill_default_config")
	add_action_button(buttons, "保存配置", "save_config")
	add_action_button(buttons, "联调预检 /readyz", "run_readiness_check")
	add_action_button(buttons, "探测章节接口", "probe_backend")


func set_config_values(values: Dictionary) -> void:
	base_url_input.text = str(values.get("base_url", "http://127.0.0.1:8000"))
	token_input.text = str(values.get("bearer_token", "test-token-2001"))


func get_config_values() -> Dictionary:
	return {
		"base_url": base_url_input.text.strip_edges(),
		"bearer_token": token_input.text.strip_edges(),
	}


func focus_auth_inputs() -> void:
	token_input.grab_focus()


func _on_config_input_changed(_text: String) -> void:
	_emit_context("config_values_changed", get_config_values())

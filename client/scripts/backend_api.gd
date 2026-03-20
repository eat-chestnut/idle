extends RefCounted
class_name BackendApi

const UNAUTHORIZED_CODE := 10002

var _owner: Node
var _base_url := ""
var _bearer_token := ""


func _init(owner: Node, base_url: String = "", bearer_token: String = "") -> void:
	_owner = owner
	update_credentials(base_url, bearer_token)


func update_credentials(base_url: String, bearer_token: String) -> void:
	_base_url = _normalize_base_url(base_url)
	_bearer_token = bearer_token.strip_edges()


func request_json(method: String, path: String, payload: Variant = null, query: Dictionary = {}) -> Dictionary:
	if _owner == null:
		return _build_failure("config", "客户端 HTTP 上下文未初始化。")

	if _base_url.is_empty():
		return _build_failure("config", "请先填写 backend 地址。")

	if _bearer_token.is_empty():
		return _build_failure("config", "请先填写 Bearer Token。")

	var http_request := HTTPRequest.new()
	_owner.add_child(http_request)

	var headers := PackedStringArray([
		"Accept: application/json",
		"Authorization: Bearer %s" % _bearer_token,
	])
	var request_body := ""
	var normalized_method := method.to_upper()
	var http_method := _resolve_http_method(normalized_method)

	if normalized_method != "GET":
		headers.append("Content-Type: application/json")
		if payload != null:
			request_body = JSON.stringify(payload)

	var request_error := http_request.request(_build_url(path, query), headers, http_method, request_body)

	if request_error != OK:
		http_request.queue_free()
		return _build_failure(
			"network",
			"请求发送失败：%s" % error_string(request_error),
			-1,
			0
		)

	var result: Array = await http_request.request_completed
	http_request.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var body_text := response_body.get_string_from_utf8()
	var parsed := {}

	if not body_text.is_empty():
		parsed = JSON.parse_string(body_text)

	if response_code == 401:
		return _build_failure(
			"unauthorized",
			_extract_message(parsed, "未登录或登录失效。"),
			UNAUTHORIZED_CODE,
			response_code,
			parsed
		)

	if typeof(parsed) != TYPE_DICTIONARY:
		return _build_failure(
			"parse",
			"服务端返回了不可解析的响应。",
			-1,
			response_code,
			{"raw_text": body_text}
		)

	var response: Dictionary = parsed
	var code := int(response.get("code", -1))
	var message := str(response.get("message", "请求失败。"))
	var data: Variant = response.get("data")

	if code == 0:
		return {
			"ok": true,
			"kind": "success",
			"http_status": response_code,
			"code": code,
			"message": message,
			"data": data,
			"raw": response,
		}

	var failure_kind := "error"
	if code == UNAUTHORIZED_CODE or response_code == 403:
		failure_kind = "unauthorized"

	return _build_failure(failure_kind, message, code, response_code, response)


func _build_url(path: String, query: Dictionary) -> String:
	var full_url := "%s%s" % [_base_url, path]

	if query.is_empty():
		return full_url

	var query_parts: PackedStringArray = []
	for key in query.keys():
		query_parts.append("%s=%s" % [str(key).uri_encode(), str(query[key]).uri_encode()])

	return "%s?%s" % [full_url, "&".join(query_parts)]


func _normalize_base_url(value: String) -> String:
	var normalized := value.strip_edges()

	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)

	return normalized


func _resolve_http_method(method: String) -> HTTPClient.Method:
	match method:
		"POST":
			return HTTPClient.METHOD_POST
		_:
			return HTTPClient.METHOD_GET


func _extract_message(parsed: Variant, fallback: String) -> String:
	if typeof(parsed) == TYPE_DICTIONARY:
		var response: Dictionary = parsed
		return str(response.get("message", fallback))

	return fallback


func _build_failure(
	kind: String,
	message: String,
	code: int = -1,
	http_status: int = 0,
	raw: Variant = {}
) -> Dictionary:
	return {
		"ok": false,
		"kind": kind,
		"message": message,
		"code": code,
		"http_status": http_status,
		"raw": raw,
	}

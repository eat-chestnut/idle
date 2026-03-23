extends RefCounted
class_name BackendApi

const UNAUTHORIZED_CODE := 10002
const STARTUP_CHECK_PROFILE := "interop"
const VERSION_UNKNOWN := "unknown"
const VERSION_NOT_DECLARED := "not_declared"

var _owner: Node
var _base_url := ""
var _bearer_token := ""


func _init(owner: Node, base_url: String = "", bearer_token: String = "") -> void:
	_owner = owner
	update_credentials(base_url, bearer_token)


func update_credentials(base_url: String, bearer_token: String) -> void:
	_base_url = _normalize_base_url(base_url)
	_bearer_token = bearer_token.strip_edges()


func request_json(
	method: String,
	path: String,
	payload: Variant = null,
	query: Dictionary = {}
) -> Dictionary:
	return await _request_json(method, path, payload, query, true, true)


func request_public_json(
	method: String,
	path: String,
	query: Dictionary = {}
) -> Dictionary:
	return await _request_json(method, path, null, query, false, false)


func request_startup_check(local_snapshot: Dictionary = {}) -> Dictionary:
	var result: Dictionary = await request_public_json(
		"GET",
		"/readyz",
		{"profile": STARTUP_CHECK_PROFILE}
	)

	if not result.get("ok", false):
		return result

	var readiness_payload := _as_dictionary(result.get("data", {}))
	return {
		"ok": true,
		"kind": "success",
		"http_status": int(result.get("http_status", 200)),
		"code": 0,
		"message": "ok",
		"data": _normalize_startup_snapshot(readiness_payload, local_snapshot),
		"raw": readiness_payload,
	}


func _request_json(
	method: String,
	path: String,
	payload: Variant,
	query: Dictionary,
	require_auth: bool,
	expect_api_wrapper: bool
) -> Dictionary:
	if _owner == null:
		return _build_failure("config", "客户端 HTTP 上下文未初始化。")

	if _base_url.is_empty():
		return _build_failure("config", "请先填写启动检查地址。")

	if require_auth and _bearer_token.is_empty():
		return _build_failure("config", "旧接口兼容链需要开发令牌。")

	var http_request := HTTPRequest.new()
	_owner.add_child(http_request)

	var headers := PackedStringArray(["Accept: application/json"])
	if require_auth:
		headers.append("Authorization: Bearer %s" % _bearer_token)
	var request_body := ""
	var normalized_method := method.to_upper()
	var http_method := _resolve_http_method(normalized_method)

	if normalized_method != "GET":
		headers.append("Content-Type: application/json")
		if payload != null:
			request_body = JSON.stringify(payload)

	var request_error := http_request.request(
		_build_url(path, query),
		headers,
		http_method,
		request_body
	)

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

	if not expect_api_wrapper:
		var public_payload: Dictionary = parsed
		if response_code >= 200 and response_code < 300:
			return {
				"ok": true,
				"kind": "success",
				"http_status": response_code,
				"code": response_code,
				"message": "ok",
				"data": public_payload,
				"raw": public_payload,
			}

		return _build_failure(
			"error",
			_extract_public_message(public_payload, "服务预检失败。"),
			response_code,
			response_code,
			public_payload
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


func _extract_public_message(parsed: Dictionary, fallback: String) -> String:
	var summary = parsed.get("summary", {})
	var failures: Array = []
	if typeof(summary) == TYPE_DICTIONARY:
		failures = summary.get("failures", [])

	if typeof(failures) == TYPE_ARRAY and not failures.is_empty():
		var first_failure = failures[0]
		if typeof(first_failure) == TYPE_DICTIONARY:
			return str(first_failure.get("message", fallback))

	if parsed.has("message"):
		return str(parsed.get("message"))

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


func _normalize_startup_snapshot(readiness_payload: Dictionary, local_snapshot: Dictionary) -> Dictionary:
	var failures = _as_array(_as_dictionary(readiness_payload.get("summary", {})).get("failures", []))
	var warnings = _as_array(_as_dictionary(readiness_payload.get("summary", {})).get("warnings", []))
	return {
		"checked_at": Time.get_datetime_string_from_system(false, true),
		"source": "/readyz?profile=%s" % STARTUP_CHECK_PROFILE,
		"network_mode": "startup_check_only",
		"ready": bool(readiness_payload.get("ready", false)),
		"profile": str(readiness_payload.get("selected_profile", STARTUP_CHECK_PROFILE)),
		"versions": {
			"app": _build_version_snapshot("app", local_snapshot, readiness_payload),
			"data": _build_version_snapshot("data", local_snapshot, readiness_payload),
			"resource": _build_version_snapshot("resource", local_snapshot, readiness_payload),
		},
		"services": {
			"save_upload": _build_save_service_snapshot("save_upload", readiness_payload),
			"save_download": _build_save_service_snapshot("save_download", readiness_payload),
		},
		"diagnosis": {
			"status": str(readiness_payload.get("status", VERSION_UNKNOWN)),
			"failures": failures.size(),
			"warnings": warnings.size(),
			"app_env": str(readiness_payload.get("app_env", "")),
		},
		"raw_readiness": readiness_payload,
	}


func _build_version_snapshot(
	version_key: String,
	local_snapshot: Dictionary,
	readiness_payload: Dictionary
) -> Dictionary:
	var local_key := "local_%s_version" % version_key
	var local_value := _normalize_version_value(local_snapshot.get(local_key, VERSION_UNKNOWN))
	var remote_value := _extract_remote_version(version_key, readiness_payload)
	var status := VERSION_UNKNOWN

	if remote_value == VERSION_NOT_DECLARED:
		status = VERSION_NOT_DECLARED
	elif remote_value != VERSION_UNKNOWN and remote_value == local_value:
		status = "match"
	elif remote_value != VERSION_UNKNOWN:
		status = "mismatch"

	return {
		"local": local_value,
		"remote": remote_value,
		"status": status,
	}


func _build_save_service_snapshot(service_key: String, readiness_payload: Dictionary) -> Dictionary:
	var services := _as_dictionary(readiness_payload.get("services", {}))
	if services.has(service_key):
		var service_payload := _as_dictionary(services.get(service_key, {}))
		return {
			"available": bool(service_payload.get("available", false)),
			"status": str(service_payload.get("status", VERSION_UNKNOWN)),
			"message": str(service_payload.get("message", "")),
		}

	return {
		"available": false,
		"status": VERSION_NOT_DECLARED,
		"message": "当前后端启动检查尚未声明该服务状态。",
	}


func _extract_remote_version(version_key: String, readiness_payload: Dictionary) -> String:
	var versions := _as_dictionary(readiness_payload.get("versions", {}))
	if versions.has(version_key):
		return _normalize_version_value(versions.get(version_key, VERSION_UNKNOWN))

	var direct_key := "%s_version" % version_key
	if readiness_payload.has(direct_key):
		return _normalize_version_value(readiness_payload.get(direct_key, VERSION_UNKNOWN))

	if version_key == "resource":
		return VERSION_NOT_DECLARED

	return VERSION_UNKNOWN


func _normalize_version_value(value: Variant) -> String:
	var normalized := str(value).strip_edges()
	if normalized.is_empty():
		return VERSION_UNKNOWN
	return normalized


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _as_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value
	return []

@tool
extends PanelContainer
## Update hint at the top of the dock.
##
## Once a day greenlight asks GitHub for a tiny version.json. Thats a plain
## file download, nothing about you or your project is sent. If there is a newer version a small box shows
## up with a link to the store. You can skip a version or turn the whole check
## off in Project Settings > Greenlight > Updates.
##
## No internet, github down, whatever: nothing happens, no error.

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")

const VERSION_URL := "https://raw.githubusercontent.com/impactcores/greenlight/main/version.json"
const SETTING_ENABLED := "greenlight/updates/check_for_updates"
const CHECK_EVERY_SEC := 24 * 60 * 60
const META := "greenlight"

var _http: HTTPRequest
var _title: Label
var _notes: Label
var _latest := {}


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.8, 0.45, 0.12)
	style.border_color = Color(0.35, 0.8, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", Color(0.35, 0.8, 0.45))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_notes = Label.new()
	_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
	box.add_child(_notes)
	var row := HBoxContainer.new()
	box.add_child(row)
	var open := Button.new()
	open.text = I18n.t("Show update")
	open.pressed.connect(_on_open)
	row.add_child(open)
	var skip := Button.new()
	skip.text = I18n.t("Skip this version")
	skip.pressed.connect(_on_skip)
	row.add_child(skip)

	_http = HTTPRequest.new()
	_http.timeout = 10.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)

	# show what we found last time right away, then maybe ask again
	_latest = _meta("latest", {})
	_refresh()
	if is_enabled() and _due():
		_http.request(_url())


static func is_enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING_ENABLED, true))


## version of the installed plugin, straight from plugin.cfg
static func installed_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://addons/web_export_toolkit/plugin.cfg") != OK:
		return "0"
	return str(cfg.get_value("plugin", "version", "0"))


## true if a is newer than b ("1.2.0" vs "1.1.9")
static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _url() -> String:
	# only for testing the check against a local file
	var override := OS.get_environment("GREENLIGHT_UPDATE_URL")
	return override if override else VERSION_URL


func _due() -> bool:
	var last := int(_meta("last_check", 0))
	return Time.get_unix_time_from_system() - last >= CHECK_EVERY_SEC


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# failed (offline etc)? just try again next editor start, no need to wait a day
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	_set_meta("last_check", int(Time.get_unix_time_from_system()))
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not data.has("version"):
		return
	_latest = data
	_set_meta("latest", data)
	_refresh()


func _refresh() -> void:
	var latest := str(_latest.get("version", ""))
	var show := is_enabled() and latest != "" \
		and is_newer(latest, installed_version()) \
		and latest != str(_meta("skipped", ""))
	visible = show
	if not show:
		return
	_title.text = I18n.t("Greenlight %s is available (you have %s).") % [latest, installed_version()]
	var notes = _latest.get("notes", {})
	var text := ""
	if notes is Dictionary:
		text = str(notes.get(I18n._language(), notes.get("en", "")))
	elif notes is String:
		text = notes
	_notes.text = text
	_notes.visible = text != ""


func _on_open() -> void:
	OS.shell_open(str(_latest.get("url", "https://store.godotengine.org/asset/impact-cores/greenlight-web-export-toolkit/")))


func _on_skip() -> void:
	_set_meta("skipped", str(_latest.get("version", "")))
	_refresh()


func _meta(key: String, default: Variant) -> Variant:
	return EditorInterface.get_editor_settings().get_project_metadata(META, "update_" + key, default)


func _set_meta(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(META, "update_" + key, value)

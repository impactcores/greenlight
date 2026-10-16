@tool
extends VBoxContainer
## "Upload to itch.io" part of the dock.
##
## Uses butler, the official upload tool from itch.io:
##   1. find butler (own download, itch app, PATH) or download it from itch.io
##   2. log in once (butler opens the itch.io login in the browser and keeps the key itself,
##      greenlight never sees it)
##   3. tick the export presets you want (web, windows, linux, mac, android ...),
##      each one gets exported into build/itch/<channel>/ and pushed to user/game:channel
##
## butler runs with --json, so we get its log lines and the progress as json lines.

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")

const SETTING_TARGET := "greenlight/itch/target"
const SETTING_CHANNELS := "greenlight/itch/channels" # preset name -> channel
const SETTING_ENABLED := "greenlight/itch/upload_presets" # preset names that are ticked
const BROTH := "https://broth.itch.zone/butler/%s/LATEST/archive/default"
const TARGET_RE := "^[a-z0-9_-]+/[a-z0-9_-]+$"
const CHANNEL_RE := "^[a-z0-9_.-]+$"
const STAGING := "build/itch" # res:// relative, every channel gets its own folder in there

## itch.io tags a channel by its name (windows / linux / mac / android),
## web has no tag, you tick "played in the browser" once on the website
const DEFAULT_CHANNEL := {
	"Web": "html5",
	"Windows Desktop": "windows",
	"Linux": "linux",
	"Linux/X11": "linux",
	"macOS": "mac",
	"Android": "android",
}

## the dock, it does the export for us
var dock: Node

var _target: LineEdit
var _preset_box: VBoxContainer
var _preset_rows := {} # section -> {check, channel, name, platform}
var _butler_label: Label
var _download: Button
var _login: Button
var _upload: Button
var _progress: ProgressBar
var _status: Label
var _hint: Label
var _open_page: Button

var _butler := ""
var _http: HTTPRequest
var _download_channel := ""

# a running butler process: {pid, stdio, stderr, buf, kind ("login" / "push"), error, last}
var _job := {}
var _logged_in_cache := false

# upload run over several presets: [{section, name, platform, channel, file}]
var _queue: Array = []
var _current := {}
var _done: Array = [] # [{name, channel, ok, msg}]


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	add_child(HSeparator.new())

	var head := Label.new()
	head.text = I18n.t("Upload to itch.io")
	add_child(head)

	_target = LineEdit.new()
	_target.placeholder_text = I18n.t("user/game – like in your itch.io link")
	_target.tooltip_text = I18n.t("Your itch.io name and the name of the game page, e.g. impactcores/hairline for impactcores.itch.io/hairline")
	_target.text = str(ProjectSettings.get_setting(SETTING_TARGET, ""))
	_target.text_changed.connect(_on_target_changed)
	add_child(_target)

	var presets_label := Label.new()
	presets_label.text = I18n.t("Presets → channel")
	presets_label.tooltip_text = I18n.t("Channel names with windows, linux, mac or android get the right platform tag on itch.io automatically.")
	presets_label.mouse_filter = Control.MOUSE_FILTER_PASS
	presets_label.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
	presets_label.modulate = Color(1, 1, 1, 0.75)
	add_child(presets_label)

	_preset_box = VBoxContainer.new()
	add_child(_preset_box)

	var butler_row := HBoxContainer.new()
	add_child(butler_row)
	_butler_label = Label.new()
	_butler_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_butler_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_butler_label.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
	butler_row.add_child(_butler_label)
	_download = Button.new()
	_download.text = I18n.t("Download butler")
	_download.tooltip_text = I18n.t("Downloads butler (about 15 MB) from itch.io into the Godot editor data folder.")
	_download.pressed.connect(_on_download)
	butler_row.add_child(_download)
	_login = Button.new()
	_login.text = I18n.t("Log in")
	_login.tooltip_text = I18n.t("Opens the itch.io login in your browser. butler keeps the key, Greenlight never sees it.")
	_login.pressed.connect(_on_login)
	butler_row.add_child(_login)

	_upload = Button.new()
	_upload.text = I18n.t("Export & upload")
	_upload.pressed.connect(_on_upload)
	add_child(_upload)

	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.step = 0.001
	_progress.visible = false
	add_child(_progress)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
	add_child(_status)

	_open_page = Button.new()
	_open_page.text = I18n.t("Open game page")
	_open_page.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_open_page.visible = false
	_open_page.pressed.connect(func() -> void: OS.shell_open(_page_url()))
	add_child(_open_page)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", int(12 * EditorInterface.get_editor_scale()))
	_hint.modulate = Color(1, 1, 1, 0.7)
	_hint.visible = false
	add_child(_hint)

	_http = HTTPRequest.new()
	_http.timeout = 120.0
	_http.request_completed.connect(_on_download_done)
	add_child(_http)

	rebuild_presets()


func _exit_tree() -> void:
	if not _job.is_empty() and OS.is_process_running(_job.pid):
		OS.kill(_job.pid)
	_job = {}
	_queue.clear()


# --- presets ---

## all export presets except the ones itch.io cant do anything with (ios)
func _all_presets() -> Array:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	var out := []
	for section in cfg.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var platform := str(cfg.get_value(section, "platform", ""))
		if platform == "iOS" or platform.is_empty():
			continue
		out.append({"section": section, "name": str(cfg.get_value(section, "name", section)),
			"platform": platform, "export_path": str(cfg.get_value(section, "export_path", ""))})
	return out


func rebuild_presets() -> void:
	for child in _preset_box.get_children():
		child.queue_free()
	_preset_rows.clear()
	var channels: Dictionary = ProjectSettings.get_setting(SETTING_CHANNELS, {})
	var enabled = ProjectSettings.get_setting(SETTING_ENABLED, null)
	var presets := _all_presets()
	if presets.is_empty():
		var none := Label.new()
		none.text = I18n.t("No export presets yet (Project › Export).")
		none.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
		_preset_box.add_child(none)
	for p in presets:
		var row := HBoxContainer.new()
		_preset_box.add_child(row)
		var check := CheckBox.new()
		check.text = p.name
		check.tooltip_text = p.platform
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.clip_text = true
		# nothing saved yet -> web presets are ticked, like before
		check.button_pressed = (p.name in enabled) if enabled is Array else p.platform == "Web"
		check.toggled.connect(func(_on: bool) -> void: _save_presets())
		row.add_child(check)
		var channel := LineEdit.new()
		channel.custom_minimum_size.x = 90
		channel.text = str(channels.get(p.name, DEFAULT_CHANNEL.get(p.platform, p.platform.to_lower().replace(" ", "-"))))
		channel.tooltip_text = I18n.t("Channel names with windows, linux, mac or android get the right platform tag on itch.io automatically.")
		channel.text_changed.connect(func(_t: String) -> void: _save_presets())
		row.add_child(channel)
		_preset_rows[p.section] = {"check": check, "channel": channel, "name": p.name, "platform": p.platform}
	_refresh()


func _save_presets() -> void:
	var channels := {}
	var enabled := []
	for section in _preset_rows:
		var r: Dictionary = _preset_rows[section]
		channels[r.name] = (r.channel as LineEdit).text.strip_edges().to_lower()
		if (r.check as CheckBox).button_pressed:
			enabled.append(r.name)
	ProjectSettings.set_setting(SETTING_CHANNELS, channels)
	ProjectSettings.set_setting(SETTING_ENABLED, enabled)
	ProjectSettings.save()
	_refresh()


func _ticked() -> Array:
	var out := []
	for section in _preset_rows:
		var r: Dictionary = _preset_rows[section]
		if (r.check as CheckBox).button_pressed:
			out.append({"section": section, "name": r.name, "platform": r.platform,
				"channel": (r.channel as LineEdit).text.strip_edges().to_lower()})
	return out


# --- state ---

func _busy() -> bool:
	return not _job.is_empty() or not _queue.is_empty() or not _current.is_empty() \
		or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED \
		or (dock != null and dock.is_exporting())


func _refresh() -> void:
	_butler = find_butler()
	_logged_in_cache = is_logged_in()
	var busy := _busy()
	if _butler.is_empty():
		_butler_label.text = I18n.t("butler not found.")
	elif _logged_in_cache:
		_butler_label.text = I18n.t("butler ready, logged in.")
	else:
		_butler_label.text = I18n.t("butler found – log in once.")
	_butler_label.tooltip_text = _butler
	_download.visible = _butler.is_empty()
	_download.disabled = busy
	_login.visible = not _butler.is_empty() and not _logged_in_cache
	_login.disabled = busy
	var count := _ticked().size()
	_upload.text = I18n.t("Export & upload") if count <= 1 else I18n.t("Export & upload (%d)") % count
	_upload.disabled = busy or _butler.is_empty() or not _logged_in_cache or count == 0
	for section in _preset_rows:
		(_preset_rows[section].check as CheckBox).disabled = busy
		(_preset_rows[section].channel as LineEdit).editable = not busy


func set_busy_from_dock() -> void:
	_refresh()


# --- butler location ---

## where Greenlight puts its own butler
static func own_dir() -> String:
	return EditorInterface.get_editor_paths().get_data_dir().path_join("greenlight/butler")


static func _exe_name() -> String:
	return "butler.exe" if OS.get_name() == "Windows" else "butler"


## butler path or "" – own download first, then the itch app, then PATH
static func find_butler() -> String:
	var own := own_dir().path_join(_exe_name())
	if FileAccess.file_exists(own):
		return own

	# the itch app keeps an up to date butler, the active version is in .chosen-version
	var broth := ""
	match OS.get_name():
		"Windows":
			broth = OS.get_environment("APPDATA").path_join("itch/broth/butler")
		"macOS":
			broth = OS.get_environment("HOME").path_join("Library/Application Support/itch/broth/butler")
		_:
			broth = OS.get_environment("HOME").path_join(".config/itch/broth/butler")
	var chosen := broth.path_join(".chosen-version")
	if FileAccess.file_exists(chosen):
		var version := FileAccess.get_file_as_string(chosen).strip_edges()
		var app := broth.path_join("versions").path_join(version).path_join(_exe_name())
		if version and FileAccess.file_exists(app):
			return app

	var sep := ";" if OS.get_name() == "Windows" else ":"
	for dir in OS.get_environment("PATH").split(sep, false):
		var candidate := dir.strip_edges().trim_suffix("\"").trim_prefix("\"").replace("\\", "/").path_join(_exe_name())
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


## same file butler uses for its key (see butler main.go defaultKeyPath)
static func creds_path() -> String:
	var xdg := OS.get_environment("XDG_CONFIG_PATH")
	if xdg:
		return xdg
	var home := OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	if OS.get_name() == "macOS":
		return home.path_join("Library/Application Support/itch/butler_creds")
	return home.replace("\\", "/").path_join(".config/itch/butler_creds")


static func is_logged_in() -> bool:
	return OS.has_environment("BUTLER_API_KEY") or FileAccess.file_exists(creds_path())


# --- download ---

func _on_download() -> void:
	var arch := Engine.get_architecture_name()
	match OS.get_name():
		"Windows":
			_download_channel = "windows-amd64"
		"macOS":
			_download_channel = "darwin-arm64" if arch == "arm64" else "darwin-amd64"
		_:
			_download_channel = "linux-arm64" if arch == "arm64" else "linux-amd64"
	_start_download()


func _start_download() -> void:
	DirAccess.make_dir_recursive_absolute(own_dir())
	_http.download_file = own_dir().path_join("butler.zip")
	var err := _http.request(BROTH % _download_channel)
	if err != OK:
		_set_status(I18n.t("Download failed (%s).") % error_string(err), true)
		return
	_set_status(I18n.t("Downloading butler from itch.io …"))
	_refresh()


func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		# no native arm build? the intel one runs too
		if _download_channel == "darwin-arm64":
			_download_channel = "darwin-amd64"
			_start_download.call_deferred()
			return
		_set_status(I18n.t("Download failed (%s). You can also install the itch app, it brings butler along.") % ("HTTP %d" % code if code else str(result)), true)
		_refresh()
		return
	var zip_path := own_dir().path_join("butler.zip")
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		_set_status(I18n.t("Download failed (%s).") % "zip", true)
		_refresh()
		return
	for file in zip.get_files():
		if file.ends_with("/"):
			continue
		var target := own_dir().path_join(file.get_file())
		var f := FileAccess.open(target, FileAccess.WRITE)
		if f:
			f.store_buffer(zip.read_file(file))
			f.close()
	zip.close()
	DirAccess.remove_absolute(zip_path)
	if OS.get_name() != "Windows":
		OS.execute("chmod", ["+x", own_dir().path_join(_exe_name())])
	_refresh()
	if _butler.is_empty():
		_set_status(I18n.t("Download failed (%s).") % "butler", true)
		return
	var out := []
	OS.execute(_butler, ["version"], out, true)
	_set_status(I18n.t("butler installed: %s") % (str(out[0]).strip_edges().get_slice(",", 0) if out.size() else ""))


# --- login ---

func _on_login() -> void:
	if _butler.is_empty():
		return
	if OS.get_name() != "Windows":
		# butler only logs in from a real terminal there
		var cmd := "\"%s\" login" % _butler
		DisplayServer.clipboard_set(cmd)
		_set_status(I18n.t("Please run this once in a terminal (it is in your clipboard):\n%s") % cmd)
		return
	_run_butler("login", ["--json", "login"])
	_set_status(I18n.t("Log in with itch.io in your browser …"))


# --- upload ---

func _on_target_changed(text: String) -> void:
	_save_setting(SETTING_TARGET, text.strip_edges())


func _target_value() -> String:
	var t := _target.text.strip_edges().to_lower()
	# people paste the whole link: https://user.itch.io/game
	var re := RegEx.create_from_string("^(?:https?://)?([a-z0-9_-]+)\\.itch\\.io/([a-z0-9_-]+)")
	var m := re.search(t)
	if m:
		t = m.get_string(1) + "/" + m.get_string(2)
	return t


func _page_url() -> String:
	var t := _target_value()
	return "https://%s.itch.io/%s" % [t.get_slice("/", 0), t.get_slice("/", 1)]


## file name inside build/itch/<channel>/ – web has to be index.html
static func export_file_name(platform: String, export_path: String) -> String:
	var base := export_path.get_file().get_basename()
	if base.is_empty():
		base = str(ProjectSettings.get_setting("application/config/name", "game"))
	base = base.validate_filename().replace(" ", "_")
	if base.is_empty():
		base = "game"
	match platform:
		"Web":
			return "index.html"
		"Windows Desktop":
			return base + ".exe"
		"Linux", "Linux/X11":
			var ext := export_path.get_extension()
			return base + "." + (ext if ext else "x86_64")
		"macOS":
			# .zip so butler can unpack it (a .dmg would end up as one big file)
			return base + ".zip"
		"Android":
			return base + "." + (export_path.get_extension() if export_path.get_extension() in ["apk", "aab"] else "apk")
	return base + ("." + export_path.get_extension() if export_path.get_extension() else "")


func _on_upload() -> void:
	_open_page.visible = false
	_hint.visible = false
	var target := _target_value()
	if not RegEx.create_from_string(TARGET_RE).search(target):
		_set_status(I18n.t("Enter your itch.io name and game like this: user/game"), true)
		return
	if target != _target.text.strip_edges():
		_target.text = target
		_on_target_changed(target)

	var ticked := _ticked()
	if ticked.is_empty():
		_set_status(I18n.t("Tick at least one preset."), true)
		return
	var seen := {}
	var paths := {}
	for p in _all_presets():
		paths[p.section] = p.export_path
	_queue.clear()
	for p in ticked:
		if not RegEx.create_from_string(CHANNEL_RE).search(p.channel):
			_set_status(I18n.t("The channel may only contain a-z, 0-9, - and _.") + " (%s)" % p.name, true)
			return
		if seen.has(p.channel):
			_set_status(I18n.t("\"%s\" and \"%s\" use the same channel – each preset needs its own.") % [seen[p.channel], p.name], true)
			return
		seen[p.channel] = p.name
		var dir := ProjectSettings.globalize_path("res://").path_join(STAGING).path_join(p.channel)
		p.file = dir.path_join(export_file_name(p.platform, paths.get(p.section, "")))
		_queue.append(p)
	_done.clear()
	_next()


## export + push the next preset in the queue, or finish
func _next() -> void:
	if _queue.is_empty():
		_current = {}
		_finish()
		return
	_current = _queue.pop_front()
	if not dock.export_preset(_current.section, _current.file, _on_exported):
		_done.append({"name": _current.name, "channel": _current.channel, "platform": _current.platform, "ok": false, "msg": I18n.t("Could not start the export.")})
		_next.call_deferred()
		return
	_set_status(I18n.t("%s: exporting …") % _current.name)
	_refresh()


func _on_exported(ok: bool, file: String, threads: bool) -> void:
	if not ok:
		_done.append({"name": _current.name, "channel": _current.channel, "platform": _current.platform, "ok": false,
			"msg": dock._export_failed_text()})
		_next.call_deferred()
		return
	_current.threads = threads
	# a zip (mac) gets pushed as file, butler unpacks it. everything else: the whole folder
	var source := file if file.get_extension() == "zip" else file.get_base_dir()
	var args := ["--json", "push", source, _target_value() + ":" + _current.channel,
		"--if-changed", "--ignore", ".gdignore"]
	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version:
		args.append_array(["--userversion", version])
	_run_butler("push", args)
	_progress.value = 0.0
	_progress.visible = true
	_set_status(I18n.t("%s: uploading to itch.io …") % _current.name)


func _finish() -> void:
	_progress.visible = false
	_refresh()
	var good := _done.filter(func(d: Dictionary) -> bool: return d.ok)
	var lines := []
	for d in _done:
		lines.append(("✓ " if d.ok else "✗ ") + "%s → %s" % [d.name, d.channel] + ("" if d.ok else ": " + d.msg))
	var all_ok := good.size() == _done.size()
	var head := I18n.t("Uploaded! itch.io processes the build for a moment, then it is live.") if all_ok \
		else I18n.t("Some uploads failed:") if good.size() > 0 else I18n.t("Upload failed: %s") % ""
	_set_status(head.strip_edges() + ("\n" + "\n".join(lines) if _done.size() > 1 or not all_ok else ""), not all_ok)
	_open_page.visible = good.size() > 0
	if good.is_empty():
		return
	var hints := []
	var web := good.filter(func(d: Dictionary) -> bool: return d.get("platform", "") == "Web")
	if not web.is_empty():
		hints.append(I18n.t("First upload to this page? On itch.io open \"Edit game\": set \"Kind of project\" to HTML and tick \"This file will be played in the browser\" at the uploaded file. After that every upload goes live by itself."))
		if web.any(func(d: Dictionary) -> bool: return d.get("threads", false)):
			hints.append(I18n.t("Your preset uses threads: also tick \"SharedArrayBuffer support\" in the embed options."))
	if good.size() > web.size():
		hints.append(I18n.t("Downloads (Windows, Linux, Mac, Android) get their platform tag from the channel name and show up on the page by themselves."))
	_hint.text = "\n".join(hints)
	_hint.visible = true


# --- running butler ---

func _run_butler(kind: String, args: Array) -> void:
	var info := OS.execute_with_pipe(_butler, PackedStringArray(args), false)
	if info.is_empty():
		if kind == "push":
			_done.append({"name": _current.name, "channel": _current.channel, "platform": _current.platform, "ok": false, "msg": I18n.t("Could not start butler.")})
			_next.call_deferred()
		else:
			_set_status(I18n.t("Could not start butler."), true)
		return
	_job = {"pid": info.pid, "stdio": info.stdio, "stderr": info.stderr, "buf": "", "kind": kind, "error": "", "last": ""}
	_refresh()


func _process(_delta: float) -> void:
	if _job.is_empty():
		return
	_read_output()
	if OS.is_process_running(_job.pid):
		return
	_read_output()
	var code := OS.get_process_exit_code(_job.pid)
	var job := _job
	_job = {}
	if job.kind == "login":
		_refresh()
		if code == 0 and _logged_in_cache:
			_set_status(I18n.t("Logged in. You can upload now."))
		else:
			_set_status(I18n.t("Login did not work: %s") % (job.error if job.error else "exit %d" % code), true)
		return
	var ok: bool = code == 0 and job.error.is_empty()
	_done.append({"name": _current.name, "channel": _current.channel, "platform": _current.platform,
		"threads": _current.get("threads", false), "ok": ok,
		"msg": "" if ok else (job.error if job.error else job.last if job.last else "exit %d" % code)})
	_next()


func _read_output() -> void:
	for pipe in [_job.stdio, _job.stderr]:
		var f: FileAccess = pipe
		if f == null or not f.is_open():
			continue
		var chunk := f.get_buffer(65536)
		if chunk.size() > 0:
			_job.buf += chunk.get_string_from_utf8()
	var lines: PackedStringArray = _job.buf.split("\n")
	_job.buf = lines[lines.size() - 1]
	for i in lines.size() - 1:
		_on_line(lines[i].strip_edges())


func _on_line(line: String) -> void:
	if line.is_empty():
		return
	var msg = JSON.parse_string(line)
	if not (msg is Dictionary):
		_job.last = line
		return
	match str(msg.get("type", "")):
		"login":
			OS.shell_open(str(msg.get("uri", "")))
		"progress":
			_progress.value = float(msg.get("progress", 0.0))
		"error":
			_job.error = str(msg.get("message", ""))
		"log":
			var text := str(msg.get("message", "")).strip_edges()
			if text and str(msg.get("level", "info")) != "debug":
				_job.last = text
				if _job.kind == "push" and not _current.is_empty():
					_status.text = "%s: %s" % [_current.name, text]


# --- helpers ---

func _set_status(text: String, error := false) -> void:
	_status.text = text
	_status.modulate = Color(0.95, 0.45, 0.45) if error else Color(1, 1, 1, 0.75)


func _save_setting(key: String, value: String) -> void:
	ProjectSettings.set_setting(key, value)
	ProjectSettings.save()

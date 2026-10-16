@tool
extends VBoxContainer
## The dock on the right. Green/yellow/red list + fix buttons.

const Checker := preload("res://addons/web_export_toolkit/editor/export_checker.gd")
const TestServer := preload("res://addons/web_export_toolkit/editor/test_server.gd")
const UpdateCheck := preload("res://addons/web_export_toolkit/editor/update_check.gd")
const ItchUpload := preload("res://addons/web_export_toolkit/editor/itch_upload.gd")
const BRAND_DIR := "res://addons/web_export_toolkit/editor/brand/"
const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")

const COLORS := {
	"green": Color(0.35, 0.8, 0.45),
	"yellow": Color(0.95, 0.75, 0.25),
	"red": Color(0.95, 0.35, 0.35),
}

var _checker := Checker.new()
var _results: Array[Dictionary] = []
var _list: VBoxContainer
var _summary: Label
var _fix_all: Button
var _restart_dialog: ConfirmationDialog
var _preset_dialog: ConfirmationDialog
var _restart_banner: PanelContainer
var _preset_boxes: Dictionary = {} # section -> CheckBox

# browser test
var _server := TestServer.new()
var _test_preset: OptionButton
var _test_sdk: CheckBox
var _test_button: Button
var _test_last: Button
var _test_stop: Button
var _test_status: Label
var _export_pid := -1
var _export_target := ""
var _export_started := 0
var _export_threads := false
var _export_done := Callable() # called with (ok, file, threads) when the export finished
var _export_pipes: Array = [] # stdout/stderr of the export process
var _export_log := ""
## first error line of the last export (godot prints why it failed), "" if none
var last_export_error := ""
var _itch: VBoxContainer
var _content: VBoxContainer # scrolls: check list, browser test, itch.io


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	add_child(_make_title())

	var buttons := HBoxContainer.new()
	add_child(buttons)

	var check := Button.new()
	check.text = I18n.t("Check now")
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.pressed.connect(_run_checks)
	buttons.add_child(check)

	_fix_all = Button.new()
	_fix_all.text = I18n.t("Fix all")
	_fix_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fix_all.pressed.connect(_on_fix_all)
	buttons.add_child(_fix_all)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)

	add_child(UpdateCheck.new())

	_restart_banner = _make_restart_banner()
	add_child(_restart_banner)
	_restart_banner.visible = _restart_pending()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	# everything below the buttons scrolls together. before, the test + itch panels
	# took all the height and the check list got squeezed to 0 px
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	_content.add_child(_list)

	_restart_dialog = ConfirmationDialog.new()
	_restart_dialog.title = "Greenlight"
	_restart_dialog.dialog_text = I18n.t("The export settings were changed.\nGodot only picks them up after the editor restarts.\n\nRestart now? (Open scenes will be saved.)")
	_restart_dialog.ok_button_text = I18n.t("Restart")
	_restart_dialog.cancel_button_text = I18n.t("Later")
	_restart_dialog.confirmed.connect(func() -> void: EditorInterface.restart_editor(true))
	add_child(_restart_dialog)

	# asked before "fix all" touches more than one web preset
	_preset_dialog = ConfirmationDialog.new()
	_preset_dialog.title = "Greenlight"
	_preset_dialog.ok_button_text = I18n.t("Fix selected")
	_preset_dialog.cancel_button_text = I18n.t("Cancel")
	_preset_dialog.confirmed.connect(_on_preset_dialog_confirmed)
	add_child(_preset_dialog)

	_content.add_child(_make_test_panel())

	_itch = ItchUpload.new()
	_itch.dock = self
	_content.add_child(_itch)

	_run_checks()


func _process(_delta: float) -> void:
	_server.poll()
	if _export_pid > 0:
		_read_export_pipes()
		if not OS.is_process_running(_export_pid):
			_read_export_pipes()
			_export_pid = -1
			_finish_export()


func _exit_tree() -> void:
	_server.stop()
	if _export_pid > 0 and OS.is_process_running(_export_pid):
		OS.kill(_export_pid)
	_export_pid = -1


func _run_checks() -> void:
	for child in _list.get_children():
		child.queue_free()

	_results = _checker.run_all()
	var counts := {"green": 0, "yellow": 0, "red": 0}
	var fixable := 0

	for r in _results:
		counts[r.status] += 1
		if r.status != "green" and not r.fix.is_empty():
			fixable += 1
		_list.add_child(_make_row(r))

	_summary.text = I18n.t("%d ok · %d warnings · %d errors") % [counts.green, counts.yellow, counts.red]
	_refresh_test_presets()
	if _itch and _itch.is_inside_tree() and not _itch._busy():
		_itch.rebuild_presets()
	_fix_all.disabled = fixable == 0
	_fix_all.text = I18n.t("Fix all (%d)") % fixable if fixable > 0 else I18n.t("Fix all")


func _make_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_color_override("font_color", COLORS.get(r.status, Color.WHITE))
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dot)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)

	var head := Label.new()
	head.text = r.title
	text.add_child(head)

	var where: String = r.get("where", "")

	# green = fine, no need to spam text. details only when something is wrong
	if r.status == "green":
		head.tooltip_text = r.msg + ("\n" + I18n.t("Where: ") + where if where else "")
		head.mouse_filter = Control.MOUSE_FILTER_PASS
		return row

	var msg := Label.new()
	msg.text = r.msg
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
	msg.modulate = Color(1, 1, 1, 0.7)
	text.add_child(msg)

	if where:
		var where_label := Label.new()
		where_label.text = I18n.t("Where: ") + where
		where_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		where_label.add_theme_font_size_override("font_size", int(12 * EditorInterface.get_editor_scale()))
		where_label.add_theme_color_override("font_color", get_theme_color("accent_color", "Editor"))
		where_label.tooltip_text = I18n.t("This is where to find the setting if you want to change it yourself.")
		where_label.mouse_filter = Control.MOUSE_FILTER_PASS
		text.add_child(where_label)

	if not r.fix.is_empty():
		var fix := Button.new()
		fix.text = r.fix
		fix.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		fix.pressed.connect(_on_fix.bind(r.id, r.restart))
		text.add_child(fix)

	return row


func _on_fix(id: String, needs_restart: bool) -> void:
	var changed := _checker.apply_fix(id)
	_run_checks()
	if changed and needs_restart:
		_mark_restart_needed()
		_restart_dialog.popup_centered()


func _on_fix_all() -> void:
	# which presets have something to fix?
	var sections: Array = []
	var names := {}
	for r in _results:
		if r.status != "green" and not r.fix.is_empty() and str(r.get("preset", "")) != "":
			if not r.preset in sections:
				sections.append(r.preset)
				names[r.preset] = r.preset_name
	# one preset (or none): just do it. several: ask first, some devs want
	# e.g. threads on for their own server and only fix the portal preset
	if sections.size() <= 1:
		_fix_everything(sections)
		return
	_show_preset_dialog(sections, names)


func _show_preset_dialog(sections: Array, names: Dictionary) -> void:
	for child in _preset_dialog.get_children():
		if child is VBoxContainer:
			child.queue_free()
	_preset_boxes.clear()
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = I18n.t("Several web export presets need changes. Which ones should Greenlight fix?")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(380, 0)
	box.add_child(label)
	for section in sections:
		var cb := CheckBox.new()
		cb.text = names[section]
		cb.button_pressed = true
		box.add_child(cb)
		_preset_boxes[section] = cb
	var note := Label.new()
	note.text = I18n.t("Project settings (main scene, scaling, web audio) are fixed in any case.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(380, 0)
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)
	_preset_dialog.add_child(box)
	_preset_dialog.popup_centered()


func _on_preset_dialog_confirmed() -> void:
	var chosen: Array = []
	for section in _preset_boxes:
		if (_preset_boxes[section] as CheckBox).button_pressed:
			chosen.append(section)
	_fix_everything(chosen)


# fixes the project wide stuff + the preset rows of the given presets
func _fix_everything(sections: Array) -> void:
	var needs_restart := false
	# order matters here! preset has to exist before we can touch its options
	var order: Array = ["web_preset"]
	for r in _results:
		if str(r.get("preset", "")) in sections and r.id.split("@")[0] in ["threads", "export_path"]:
			order.append(r.id)
	order.append_array(["main_scene", "stretch", "web_audio"])
	for id in order:
		var r := _find_result(id)
		if r.is_empty() or r.status == "green" or r.fix.is_empty():
			continue
		if _checker.apply_fix(id) and r.restart:
			needs_restart = true
		_results = _checker.run_all() # check again after each fix, dont trust old results
	_run_checks()
	if needs_restart:
		_mark_restart_needed()
		_restart_dialog.popup_centered()


func _find_result(id: String) -> Dictionary:
	for r in _results:
		if r.id == id:
			return r
	return {}


# --- restart hint ------------------------------------------------------------
# godot keeps the export presets in memory. our fix is in the file already, but
# the export dialog only shows it after a restart (and saving from that dialog
# before would even overwrite our fix). so the hint stays until a real restart.
# we remember the editor process id: same process = still not restarted, and
# that also survives turning the plugin off and on again.

const META_SECTION := "greenlight"
const META_KEY := "restart_pending_pid"


func _make_restart_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.75, 0.25, 0.15)
	style.border_color = COLORS.yellow
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := Label.new()
	head.text = I18n.t("Restart needed")
	head.add_theme_color_override("font_color", COLORS.yellow)
	box.add_child(head)
	var msg := Label.new()
	msg.text = I18n.t("The fixes are saved, but Godot only uses the new export settings after a restart. Until then the Export dialog still shows the old values – don't save anything there, it would undo the fix.")
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
	box.add_child(msg)
	var btn := Button.new()
	btn.text = I18n.t("Restart now")
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.pressed.connect(func() -> void: EditorInterface.restart_editor(true))
	box.add_child(btn)
	return panel


func _mark_restart_needed() -> void:
	EditorInterface.get_editor_settings().set_project_metadata(META_SECTION, META_KEY, OS.get_process_id())
	if is_instance_valid(_restart_banner):
		_restart_banner.visible = true


func _restart_pending() -> bool:
	var pid = EditorInterface.get_editor_settings().get_project_metadata(META_SECTION, META_KEY, 0)
	return int(pid) == OS.get_process_id()


# --- browser test --------------------------------------------------------------
# exports the web preset in a second godot process (same as from the command
# line, so the editor stays usable), serves the folder on 127.0.0.1 and opens
# the browser. with "CrazyGames test ads" the url gets ?useLocalSdk=true, then
# the crazygames sdk shows test ads.

# logo at the top. loaded straight from the png (the brand folder has a .gdignore,
# so godot doesnt import it and it doesnt end up in your game export)
func _make_title() -> Control:
	var light_theme := false
	var es := EditorInterface.get_editor_settings()
	if es.has_setting("interface/theme/base_color"):
		light_theme = (es.get_setting("interface/theme/base_color") as Color).get_luminance() > 0.5
	var file := BRAND_DIR + ("logo_dock_light.png" if light_theme else "logo_dock_dark.png")
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(file)) == OK:
		var scale := EditorInterface.get_editor_scale()
		var rect := TextureRect.new()
		rect.texture = ImageTexture.create_from_image(image)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		# png is 2x, so 1 png pixel = half a ui pixel at 100 %
		rect.custom_minimum_size = Vector2(0, image.get_height() / 2.0 * scale)
		rect.tooltip_text = "Greenlight – Web Export Toolkit for Godot"
		return rect
	var title := Label.new()
	title.text = "Greenlight"
	title.add_theme_font_size_override("font_size", int(16 * EditorInterface.get_editor_scale()))
	return title


func _make_test_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(HSeparator.new())

	var head := Label.new()
	head.text = I18n.t("Test in browser")
	box.add_child(head)

	_test_preset = OptionButton.new()
	_test_preset.tooltip_text = I18n.t("Which web export preset to test")
	box.add_child(_test_preset)

	_test_sdk = CheckBox.new()
	_test_sdk.text = I18n.t("CrazyGames test ads")
	_test_sdk.tooltip_text = I18n.t("Opens the game with ?useLocalSdk=true, then the CrazyGames SDK shows test ads.")
	_test_sdk.button_pressed = str(ProjectSettings.get_setting("greenlight/portal/portal", "auto")) != "none"
	box.add_child(_test_sdk)

	var row := HBoxContainer.new()
	box.add_child(row)
	_test_button = Button.new()
	_test_button.text = I18n.t("Export & open")
	_test_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_button.pressed.connect(_on_test_export)
	row.add_child(_test_button)
	_test_last = Button.new()
	_test_last.text = I18n.t("Open last export")
	_test_last.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_last.pressed.connect(_on_test_last)
	row.add_child(_test_last)

	_test_status = Label.new()
	_test_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_test_status.add_theme_font_size_override("font_size", int(13 * EditorInterface.get_editor_scale()))
	_test_status.modulate = Color(1, 1, 1, 0.75)
	box.add_child(_test_status)

	_test_stop = Button.new()
	_test_stop.text = I18n.t("Stop server")
	_test_stop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_test_stop.visible = false
	_test_stop.pressed.connect(_on_test_stop)
	box.add_child(_test_stop)
	return box


func _refresh_test_presets() -> void:
	if _test_preset == null:
		return
	var keep = _test_preset.get_selected_metadata() if _test_preset.item_count > 0 else null
	_test_preset.clear()
	var cfg := _checker._load_presets()
	for section in _checker._find_web_presets(cfg):
		_test_preset.add_item(str(cfg.get_value(section, "name", "Web")))
		_test_preset.set_item_metadata(_test_preset.item_count - 1, section)
		if section == keep:
			_test_preset.select(_test_preset.item_count - 1)
	var has := _test_preset.item_count > 0
	_test_preset.visible = _test_preset.item_count > 1
	_test_button.disabled = not has or _export_pid > 0
	_test_last.disabled = not has or not FileAccess.file_exists(_selected_export_file())
	if not has:
		_test_status.text = I18n.t("Create a web preset first.")


# absolute path of the export file of the chosen preset ("" = none set)
func _selected_export_file() -> String:
	if _test_preset == null or _test_preset.item_count == 0:
		return ""
	var cfg := _checker._load_presets()
	var path := str(cfg.get_value(str(_test_preset.get_selected_metadata()), "export_path", ""))
	if path.is_empty():
		return ""
	return ProjectSettings.globalize_path("res://").path_join(path).simplify_path()


func _selected_threads() -> bool:
	if _test_preset == null or _test_preset.item_count == 0:
		return false
	var cfg := _checker._load_presets()
	return bool(cfg.get_value(str(_test_preset.get_selected_metadata()) + ".options", "variant/thread_support", false))


func _on_test_export() -> void:
	if _selected_export_file().is_empty():
		_test_status.text = I18n.t("This preset has no export path yet – \"Fix all\" sets one.")
		return
	if not start_export(_on_test_exported):
		_test_status.text = I18n.t("Could not start the export.")


func _on_test_exported(ok: bool, file: String, threads: bool) -> void:
	if not ok:
		_test_status.text = _export_failed_text()
		return
	_open_in_browser(file, threads)


func _export_failed_text() -> String:
	if last_export_error:
		return I18n.t("Export failed: %s") % last_export_error
	return I18n.t("Export failed. Try it once via Project › Export to see the error.")


## exports the preset chosen in the dropdown in the background (own godot process,
## so the editor stays usable). done gets (ok, file, threads). false = not started
func start_export(done: Callable) -> bool:
	var target := _selected_export_file()
	if target.is_empty():
		return false
	return export_preset(str(_test_preset.get_selected_metadata()), target, done)


## exports any preset (section like "preset.2") to an absolute target path in the
## background. own godot process, so the editor stays usable.
## done gets (ok, file, threads). false = not started
func export_preset(section: String, target: String, done: Callable) -> bool:
	if is_exporting() or target.is_empty():
		return false
	var cfg := _checker._load_presets()
	var preset_name := str(cfg.get_value(section, "name", ""))
	if preset_name.is_empty():
		return false
	var rel := target.trim_prefix(ProjectSettings.globalize_path("res://").simplify_path()).trim_prefix("/")
	_checker._ensure_export_dir(rel)
	_export_target = target
	_export_threads = bool(cfg.get_value(section + ".options", "variant/thread_support", false))
	_export_started = int(Time.get_unix_time_from_system())
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--export-release", preset_name, target]
	# with pipes, so we can tell the user *why* an export failed (missing templates etc)
	var info := OS.execute_with_pipe(OS.get_executable_path(), PackedStringArray(args), false)
	if info.is_empty():
		_export_pid = -1
		return false
	_export_pid = info.pid
	_export_pipes = [info.stdio, info.stderr]
	_export_log = ""
	last_export_error = ""
	_export_done = done
	_test_button.disabled = true
	_test_status.text = I18n.t("Exporting \"%s\" … this can take a moment.") % preset_name
	if _itch:
		_itch.set_busy_from_dock()
	return true


func _read_export_pipes() -> void:
	for pipe in _export_pipes:
		var f: FileAccess = pipe
		if f and f.is_open():
			var chunk := f.get_buffer(65536)
			if chunk.size() > 0 and _export_log.length() < 200000:
				_export_log += chunk.get_string_from_utf8()


## the most useful part of godots export output.
## "configuration errors" come with details in the next lines (missing templates ...),
## otherwise the last ERROR line, because the first ones are often just noise
func _export_error_from_log() -> String:
	var ansi := RegEx.create_from_string("\u001b\\[[0-9;]*m")
	var lines := ansi.sub(_export_log, "", true).replace("\r", "").split("\n")
	var last := ""
	for i in lines.size():
		var l := lines[i].strip_edges()
		if not l.begins_with("ERROR:"):
			continue
		if "configuration errors" in l:
			var details := []
			for j in range(i + 1, mini(i + 7, lines.size())):
				var d := lines[j].strip_edges()
				if d.is_empty() or d.begins_with("ERROR:") or d.begins_with("at:"):
					break
				details.append(d)
			if not details.is_empty():
				return " ".join(details).left(300)
		if not l.begins_with("ERROR: Project export for preset"):
			last = l.trim_prefix("ERROR:").strip_edges()
	return last.left(300)


func is_exporting() -> bool:
	return _export_pid > 0


## absolute path of the export file of the preset chosen in the dropdown
func selected_export_file() -> String:
	return _selected_export_file()


func _finish_export() -> void:
	_test_button.disabled = false
	_test_status.text = ""
	var ok := FileAccess.file_exists(_export_target) \
		and FileAccess.get_modified_time(_export_target) >= _export_started - 2
	_export_pipes.clear()
	last_export_error = "" if ok else _export_error_from_log()
	var done := _export_done
	_export_done = Callable()
	if _itch:
		_itch.set_busy_from_dock()
	if done.is_valid():
		done.call(ok, _export_target, _export_threads)


func _on_test_last() -> void:
	var target := _selected_export_file()
	if not FileAccess.file_exists(target):
		_test_status.text = I18n.t("No export found yet.")
		return
	_open_in_browser(target, _selected_threads())


func _open_in_browser(file: String, threads: bool) -> void:
	if not _server.start(file.get_base_dir(), threads):
		_test_status.text = I18n.t("No free port between 8070 and 8079.")
		return
	var url := _server.url() + file.get_file().uri_encode()
	if _test_sdk.button_pressed:
		url += "?useLocalSdk=true"
	OS.shell_open(url)
	_test_status.text = I18n.t("Running at %s") % url
	_test_stop.visible = true
	_refresh_test_presets()


func _on_test_stop() -> void:
	_server.stop()
	_test_stop.visible = false
	_test_status.text = ""

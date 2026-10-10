@tool
extends VBoxContainer
## The dock on the right. Green/yellow/red list + fix buttons.

const Checker := preload("res://addons/web_export_toolkit/editor/export_checker.gd")
const UpdateCheck := preload("res://addons/web_export_toolkit/editor/update_check.gd")
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


func _ready() -> void:
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Greenlight"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

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
	scroll.add_child(_list)

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

	_run_checks()


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
	msg.add_theme_font_size_override("font_size", 13)
	msg.modulate = Color(1, 1, 1, 0.7)
	text.add_child(msg)

	if where:
		var where_label := Label.new()
		where_label.text = I18n.t("Where: ") + where
		where_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		where_label.add_theme_font_size_override("font_size", 12)
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
	msg.add_theme_font_size_override("font_size", 13)
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

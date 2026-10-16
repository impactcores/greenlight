@tool
extends EditorPlugin
## Greenlight - main plugin script.
## Adds the dock, the WebToolkit autoload and the project settings.

const AUTOLOAD_NAME := "WebToolkit"
const AUTOLOAD_PATH := "res://addons/web_export_toolkit/runtime/web_toolkit.gd"
const DockScript := preload("res://addons/web_export_toolkit/editor/export_checker_dock.gd")

const SETTING_PORTAL := "greenlight/portal/portal"
const SETTING_SIMULATE := "greenlight/portal/simulate_outside_browser"
const SETTING_HIDDEN := "greenlight/web/when_tab_hidden"
const SETTING_UPDATES := "greenlight/updates/check_for_updates"
const SETTING_ITCH_TARGET := "greenlight/itch/target"

var _dock: Control


func _enter_tree() -> void:
	_register_settings()
	# after every file scan: make sure the WebToolkit autoload still points to
	# a script that exists (see _repair_autoload)
	var fs := EditorInterface.get_resource_filesystem()
	if fs and not fs.filesystem_changed.is_connected(_repair_autoload):
		fs.filesystem_changed.connect(_repair_autoload)
	_repair_autoload.call_deferred()
	_dock = DockScript.new()
	_dock.name = "Greenlight"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs and fs.filesystem_changed.is_connected(_repair_autoload):
		fs.filesystem_changed.disconnect(_repair_autoload)
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	# bring the dock to the front on first enable, otherwise it hides behind
	# Inspector/History and nobody finds it
	_focus_dock.call_deferred()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _focus_dock() -> void:
	if not is_instance_valid(_dock):
		return
	var parent := _dock.get_parent()
	# 4.6+ wraps docks in an EditorDock, that one can show itself
	if parent and parent.has_method("make_visible"):
		parent.call("make_visible")
		return
	# 4.5 and older: just switch the tab
	var node: Node = _dock
	while node and not (node.get_parent() is TabContainer):
		node = node.get_parent()
	if node:
		(node.get_parent() as TabContainer).current_tab = node.get_index()


func _register_settings() -> void:
	# auto = only load the crazygames sdk when we are actually on crazygames
	_add_setting(SETTING_PORTAL, "auto", TYPE_STRING, PROPERTY_HINT_ENUM, "auto,crazygames,none")
	# fake ads in editor/desktop so you can test wich things pause etc
	_add_setting(SETTING_SIMULATE, true, TYPE_BOOL)
	# portals want the game quiet when the player switches tabs
	_add_setting(SETTING_HIDDEN, "pause_and_mute", TYPE_STRING, PROPERTY_HINT_ENUM, "pause_and_mute,mute,off")
	# once a day ask github if there is a newer greenlight (plain file download)
	_add_setting(SETTING_UPDATES, true, TYPE_BOOL)
	# itch.io upload: "user/game". presets + channels are saved by the dock itself
	_add_setting(SETTING_ITCH_TARGET, "", TYPE_STRING, PROPERTY_HINT_PLACEHOLDER_TEXT, "user/game")


func _add_setting(setting: String, default: Variant, type: int,
		hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.add_property_info({
		"name": setting, "type": type, "hint": hint, "hint_string": hint_string,
	})
	ProjectSettings.set_as_basic(setting, true)


# Godot saves the autoload as "uid://...". If the addon folder gets replaced by
# hand (or an update brings other .uid files) that id can point to nothing and
# the game fails with "can't load autoload". Found that one the hard way, so:
# if the id is dead, just switch the autoload back to the normal path.
func _repair_autoload() -> void:
	var key := "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		return # no autoload (plugin off or removed on purpose) -> not our business
	var value := str(ProjectSettings.get_setting(key))
	var target := value.trim_prefix("*")
	if not target.begins_with("uid://"):
		return
	var id := ResourceUID.text_to_id(target)
	if id != ResourceUID.INVALID_ID and ResourceUID.has_id(id) \
			and ResourceUID.get_id_path(id) == AUTOLOAD_PATH:
		return
	ProjectSettings.set_setting(key, ("*" if value.begins_with("*") else "") + AUTOLOAD_PATH)
	ProjectSettings.save()
	print("Greenlight: WebToolkit autoload repaired (the saved id was not valid anymore).")

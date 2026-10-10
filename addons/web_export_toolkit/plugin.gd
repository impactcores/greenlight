@tool
extends EditorPlugin
## Greenlight - main plugin script.
## Adds the dock, the WebToolkit autoload and the project settings.

const AUTOLOAD_NAME := "WebToolkit"
const AUTOLOAD_PATH := "res://addons/web_export_toolkit/runtime/web_toolkit.gd"
const DockScript := preload("res://addons/web_export_toolkit/editor/export_checker_dock.gd")

const SETTING_UPDATES := "greenlight/updates/check_for_updates"

var _dock: Control


func _enter_tree() -> void:
	_register_settings()
	_dock = DockScript.new()
	_dock.name = "Greenlight"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
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
	# once a day ask github if there is a newer greenlight (no data is sent)
	if not ProjectSettings.has_setting(SETTING_UPDATES):
		ProjectSettings.set_setting(SETTING_UPDATES, true)
	ProjectSettings.set_initial_value(SETTING_UPDATES, true)
	ProjectSettings.add_property_info({"name": SETTING_UPDATES, "type": TYPE_BOOL})
	ProjectSettings.set_as_basic(SETTING_UPDATES, true)

extends Node
## WebToolkit autoload - this is what you call from your game.
##
##     func _ready() -> void:
##         await WebToolkit.wait_for_start()
##         $Music.play()

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")
const ClickToStart := preload("res://addons/web_export_toolkit/runtime/click_to_start.gd")

signal started

## show the start screen in the editor too, for testing
var force_click_to_start := false
var is_started := false

var _screen: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## true if we run in a browser
func is_web() -> bool:
	return OS.has_feature("web")


## Browsers block audio until the player clicked something, so wait for that.
## Outside the browser this returns right away.
## No prompt given -> "Click to start" in the players language.
func wait_for_start(prompt: String = "") -> void:
	if is_started:
		return
	if not is_web() and not force_click_to_start:
		_mark_started()
		return
	if _screen == null:
		_screen = ClickToStart.new()
		_screen.prompt = prompt if prompt else I18n.t("Click to start")
		add_child(_screen)
	await started


func _on_screen_started() -> void:
	_screen = null
	_mark_started()


func _mark_started() -> void:
	if is_started:
		return
	is_started = true
	started.emit()

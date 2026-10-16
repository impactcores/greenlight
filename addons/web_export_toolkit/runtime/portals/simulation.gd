extends "res://addons/web_export_toolkit/runtime/portals/portal_adapter.gd"
## Fake portal for editor/desktop. Shows a test overlay instead of a real ad,
## so you can test pause/sound/rewards without uploading every time.

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")
const AD_SECONDS := 2.0

var _log_calls := true


func _init(host_node: Node) -> void:
	super(host_node)
	portal_name = "simulation"


func loading_start() -> void: _log("loadingStart")
func loading_stop() -> void: _log("loadingStop")
func gameplay_start() -> void: _log("gameplayStart")
func gameplay_stop() -> void: _log("gameplayStop")
func happytime() -> void: _log("happytime")


func show_ad_async(kind: String) -> Dictionary:
	_log("requestAd(%s)" % kind)
	var overlay := _make_overlay(kind)
	host.add_child(overlay)
	ad_started.emit()
	await host.get_tree().create_timer(AD_SECONDS, true).timeout
	overlay.queue_free()
	return {"ok": true, "code": ""}


func _make_overlay(kind: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 127
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	var label := Label.new()
	label.text = I18n.t("Test ad (%s)\nOn CrazyGames a real ad appears here.") % kind
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(label)
	return layer


func _log(what: String) -> void:
	if _log_calls:
		print("[WebToolkit simulation] ", what)

extends Node2D
## Small demo, just the start screen.
## Autoload is fetched by path so this doesnt error before the plugin is enabled.

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")


func _ready() -> void:
	var toolkit := get_node_or_null("/root/WebToolkit")
	if toolkit == null:
		push_warning("Greenlight: enable the plugin in Project Settings › Plugins.")
		return

	toolkit.force_click_to_start = true # only for the demo, so you see it in the editor
	await toolkit.wait_for_start(I18n.t("Tap or click to start"))

	var label := Label.new()
	label.text = I18n.t("Started! Your music could start playing now.")
	label.position = Vector2(40, 40)
	add_child(label)
	print("[Demo] Start confirmed, web: ", toolkit.is_web())

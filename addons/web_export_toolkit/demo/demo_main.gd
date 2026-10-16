extends Node2D
## Demo for the start screen + ads.
## The spinning square stops during ads, so you can see the pause works.
## Autoload is fetched by path so this doesnt error before the plugin is enabled.

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")

var toolkit: Node
var coins := 0
var _spinner: ColorRect
var _log: Label
var _coins_label: Label


func _ready() -> void:
	toolkit = get_node_or_null("/root/WebToolkit")
	if toolkit == null:
		push_warning("Greenlight: enable the plugin in Project Settings › Plugins.")
		return

	_build_ui()
	await toolkit.wait_for_start(I18n.t("Tap or click to start"))

	toolkit.loading_start()
	await toolkit.wait_for_portal()
	toolkit.loading_stop()
	_write(I18n.t("Portal: %s") % toolkit.get_portal_name())
	toolkit.gameplay_start()
	toolkit.portal_mute_changed.connect(func(m: bool) -> void:
		_write(I18n.t("Portal sound: %s") % I18n.t("off" if m else "on")))


func _process(delta: float) -> void:
	if _spinner:
		_spinner.rotation += delta * 2.0


func _build_ui() -> void:
	_spinner = ColorRect.new()
	_spinner.size = Vector2(60, 60)
	_spinner.pivot_offset = Vector2(30, 30)
	_spinner.position = Vector2(520, 80)
	_spinner.color = Color(0.28, 0.55, 0.75)
	add_child(_spinner)

	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_coins_label = Label.new()
	_coins_label.text = I18n.t("Coins: %d") % 0
	_coins_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_coins_label)

	_button(box, I18n.t("Midgame ad"), _on_midgame)
	_button(box, I18n.t("Rewarded ad (+10 coins)"), _on_rewarded)
	_button(box, I18n.t("Happytime"), func() -> void:
		toolkit.happytime()
		_write(I18n.t("happytime sent")))
	_button(box, I18n.t("Check for ad blocker"), _on_adblock)

	_log = Label.new()
	_log.custom_minimum_size = Vector2(440, 0)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_log)


func _button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 40)
	b.pressed.connect(action)
	parent.add_child(b)


func _on_midgame() -> void:
	toolkit.gameplay_stop()
	var shown: bool = await toolkit.show_midgame_ad()
	_write(I18n.t("Midgame: %s") % I18n.t("shown" if shown else "not shown"))
	toolkit.gameplay_start()


func _on_rewarded() -> void:
	var rewarded: bool = await toolkit.show_rewarded_ad()
	if rewarded:
		coins += 10
		_coins_label.text = I18n.t("Coins: %d") % coins
	_write(I18n.t("Rewarded: %s") % I18n.t("reward granted" if rewarded else "no reward"))


func _on_adblock() -> void:
	var blocked: bool = await toolkit.has_adblock()
	_write(I18n.t("Ad blocker: %s") % I18n.t("yes" if blocked else "no"))


func _write(line: String) -> void:
	print("[Demo] ", line)
	if _log:
		_log.text = (line + "\n" + _log.text).strip_edges()

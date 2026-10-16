extends Node
## WebToolkit autoload - this is what you call from your game.
##
##     await WebToolkit.wait_for_start()
##
##     WebToolkit.gameplay_start()
##     if await WebToolkit.show_rewarded_ad():
##         give_extra_life()
##
## You can call the portal stuff everywhere. No portal = nothing happens,
## in the editor you get the fake ads.

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")
const ClickToStart := preload("res://addons/web_export_toolkit/runtime/click_to_start.gd")
const PortalNone := preload("res://addons/web_export_toolkit/runtime/portals/portal_adapter.gd")
const PortalCrazyGames := preload("res://addons/web_export_toolkit/runtime/portals/crazygames.gd")
const PortalSimulation := preload("res://addons/web_export_toolkit/runtime/portals/simulation.gd")

const SETTING_PORTAL := "greenlight/portal/portal"
const SETTING_SIMULATE := "greenlight/portal/simulate_outside_browser"
const SETTING_HIDDEN := "greenlight/web/when_tab_hidden"

## tiny JS helper: remembers if the tab is hidden and calls godot back.
## godot itself stops running frames in a hidden tab, but web audio keeps
## playing - thats why we need the callback and cant just poll.
const VISIBILITY_JS := """
(function () {
	if (window.__glVis) return;
	var V = window.__glVis = { hidden: !!document.hidden, cbs: [] };
	V.listen = function (cb) { V.cbs.push(cb); };
	function changed(h) {
		if (V.hidden === h) return;
		V.hidden = h;
		for (var i = 0; i < V.cbs.length; i++) { try { V.cbs[i](h); } catch (e) {} }
	}
	document.addEventListener('visibilitychange', function () { changed(!!document.hidden); });
	window.addEventListener('pagehide', function () { changed(true); });
	window.addEventListener('pageshow', function () { changed(!!document.hidden); });
})();
"""

signal started
## portal is ready ("crazygames", "simulation" or "none")
signal portal_ready(portal_name: String)
signal ad_started(kind: String)
signal ad_finished(kind: String, success: bool)
## portal wants sound on/off (crazygames has a sound toggle on the site)
signal portal_mute_changed(muted: bool)
## player switched the browser tab / minimized the window (or came back)
signal tab_visibility_changed(hidden: bool)

## show the start screen in the editor too, for testing
var force_click_to_start := false
var is_started := false
var is_ad_running := false
var is_tab_hidden := false

var _screen: CanvasLayer
var _portal # one of the adapters in runtime/portals
var _portal_is_ready := false
var _portal_muted := false
var _ad_kind := ""

# who wants the game muted/paused right now ("ad", "portal", "hidden").
# when the last one is gone we go back to how it was before.
var _mute_holds := {}
var _pause_holds := {}
var _muted_before := false
var _paused_before := false

var _vis_callback # JavaScriptObject, has to stay referenced or the browser drops it
var _vis_poll := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_visibility()
	_setup_portal()


func _process(delta: float) -> void:
	# backup for the callback, also catches the "tab is visible again" case
	if _vis_callback == null:
		return
	_vis_poll -= delta
	if _vis_poll <= 0.0:
		_vis_poll = 0.5
		_set_tab_hidden(bool(JavaScriptBridge.eval("window.__glVis ? window.__glVis.hidden : false", true)))


# --- start screen ---

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


# --- portal / ads ---

## "crazygames", "simulation" or "none"
func get_portal_name() -> String:
	return _portal.portal_name if _portal else "none"


## wait for the sdk. you usually dont need this, every call waits by itself
func wait_for_portal() -> void:
	if not _portal_is_ready:
		await portal_ready


## game is loading something (crazygames: loadingStart)
func loading_start() -> void:
	_when_ready(func() -> void: _portal.loading_start())


## done loading (crazygames: loadingStop)
func loading_stop() -> void:
	_when_ready(func() -> void: _portal.loading_stop())


## player is actually playing now (level start, back from menu...)
func gameplay_start() -> void:
	_when_ready(func() -> void: _portal.gameplay_start())


## pause, menu, level end
func gameplay_stop() -> void:
	_when_ready(func() -> void: _portal.gameplay_stop())


## big moment like boss killed or highscore. dont spam it, CG wants it rare
func happytime() -> void:
	_when_ready(func() -> void: _portal.happytime())


## ad between levels, true if it was shown.
## game is paused + muted while it runs
func show_midgame_ad() -> bool:
	return await _run_ad("midgame")


## rewarded ad. only give the reward if this returns true!
func show_rewarded_ad() -> bool:
	return await _run_ad("rewarded")


## adblock on? your game still has to work then (CG rule)
func has_adblock() -> bool:
	await wait_for_portal()
	return await _portal.has_adblock_async()


## portal wants silence right now
func is_muted_by_portal() -> bool:
	return _portal_muted


# --- tab hidden ---

func _setup_visibility() -> void:
	if not is_web():
		return
	if str(ProjectSettings.get_setting(SETTING_HIDDEN, "pause_and_mute")) == "off":
		return
	JavaScriptBridge.eval(VISIBILITY_JS, true)
	_vis_callback = JavaScriptBridge.create_callback(_on_js_visibility)
	var vis = JavaScriptBridge.get_interface("__glVis")
	if vis:
		vis.listen(_vis_callback)
	_set_tab_hidden(bool(JavaScriptBridge.eval("window.__glVis.hidden", true)))


func _on_js_visibility(args: Array) -> void:
	_set_tab_hidden(bool(args[0]) if args.size() > 0 else false)


func _set_tab_hidden(hidden: bool) -> void:
	if hidden == is_tab_hidden:
		return
	is_tab_hidden = hidden
	if hidden:
		var pause := str(ProjectSettings.get_setting(SETTING_HIDDEN, "pause_and_mute")) == "pause_and_mute"
		_hold("hidden", true, pause)
	else:
		_release("hidden")
	tab_visibility_changed.emit(hidden)


# --- mute / pause bookkeeping ---

func _hold(reason: String, mute: bool, pause: bool) -> void:
	var master := AudioServer.get_bus_index("Master")
	if mute and not _mute_holds.has(reason):
		if _mute_holds.is_empty():
			_muted_before = AudioServer.is_bus_mute(master)
		_mute_holds[reason] = true
		AudioServer.set_bus_mute(master, true)
	if pause and not _pause_holds.has(reason):
		if _pause_holds.is_empty():
			_paused_before = get_tree().paused
		_pause_holds[reason] = true
		get_tree().paused = true


func _release(reason: String) -> void:
	if _mute_holds.erase(reason) and _mute_holds.is_empty():
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted_before)
	if _pause_holds.erase(reason) and _pause_holds.is_empty():
		get_tree().paused = _paused_before


# --- internal ---

func _setup_portal() -> void:
	match _choose_portal():
		"crazygames":
			_portal = PortalCrazyGames.new(self)
		"simulation":
			_portal = PortalSimulation.new(self)
		_:
			_portal = PortalNone.new(self)

	var ok: bool = await _portal.init_async()
	if not ok:
		_portal = PortalNone.new(self)
	_portal.portal_mute_changed.connect(_on_portal_mute_changed)
	_portal.ad_started.connect(_on_adapter_ad_started)
	if _portal.is_muted_by_portal():
		_on_portal_mute_changed(true)

	_portal_is_ready = true
	portal_ready.emit(get_portal_name())


func _choose_portal() -> String:
	var setting := str(ProjectSettings.get_setting(SETTING_PORTAL, "auto"))
	if not is_web():
		return "simulation" if ProjectSettings.get_setting(SETTING_SIMULATE, true) else "none"
	if setting != "auto":
		return setting
	# auto: only load the crazygames sdk on crazygames (or with ?useLocalSdk=true for testing)
	var where := str(JavaScriptBridge.eval("location.hostname + location.search", true))
	if "crazygames" in where or "useLocalSdk=true" in where:
		return "crazygames"
	return "none"


func _when_ready(call: Callable) -> void:
	if not _portal_is_ready:
		await portal_ready
	call.call()


func _run_ad(kind: String) -> bool:
	await wait_for_portal()
	if is_ad_running:
		return false
	is_ad_running = true
	_ad_kind = kind

	# portal rules: pause + mute during ads
	_hold("ad", true, true)

	var result: Dictionary = await _portal.show_ad_async(kind)

	_release("ad")
	is_ad_running = false
	_ad_kind = ""

	var ok: bool = result.get("ok", false)
	if not ok and result.get("code", "") != "unsupported":
		print("[WebToolkit] Ad not shown: ", result.get("code", ""))
	ad_finished.emit(kind, ok)
	return ok


func _on_adapter_ad_started() -> void:
	ad_started.emit(_ad_kind)


func _on_portal_mute_changed(muted: bool) -> void:
	_portal_muted = muted
	if muted:
		_hold("portal", true, false)
	else:
		_release("portal")
	portal_mute_changed.emit(muted)

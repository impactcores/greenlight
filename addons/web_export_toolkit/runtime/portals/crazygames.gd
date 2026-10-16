extends "res://addons/web_export_toolkit/runtime/portals/portal_adapter.gd"
## CrazyGames HTML5 SDK v3
## docs: https://docs.crazygames.com/sdk/intro/
##
## How it works: small JS layer (window.__wetCrazy) talks to the sdk and saves
## every result as a "job". Godot just polls the job every frame with
## JavaScriptBridge.eval. I first used JS->Godot callbacks but they were not
## realiable with promises, polling is boring but it works.
##
## SDK gets loaded at runtime, no need to touch the exported html.

const SDK_URL := "https://sdk.crazygames.com/crazygames-sdk-v3.js"
## if the sdk doesnt answer after this many seconds we just continue the game
const AD_TIMEOUT_SEC := 90.0
const INIT_TIMEOUT_SEC := 15.0

const GLUE_JS := """
(function () {
	if (window.__wetCrazy) return;
	var B = window.__wetCrazy = { seq: 0, jobs: {}, muted: false };
	function job() { var id = ++B.seq; B.jobs[id] = { done: false, ok: false, value: null, started: false }; return id; }
	// job can already be gone (timeout) if the sdk answers late
	function finish(id, ok, value) { var j = B.jobs[id]; if (!j) return; j.done = true; j.ok = ok; j.value = value; }
	function track(id, promise) {
		Promise.resolve(promise).then(
			function (v) { finish(id, true, v === undefined ? null : v); },
			function (e) { finish(id, false, String((e && e.message) || e)); });
	}
	function sdk() { return window.CrazyGames && window.CrazyGames.SDK; }
	B.load = function (url) {
		var id = job();
		if (sdk()) { finish(id, true, true); return id; }
		var s = document.createElement('script');
		s.src = url; s.async = true;
		s.onload = function () { finish(id, !!sdk(), !!sdk()); };
		s.onerror = function () { finish(id, false, 'load_error'); };
		document.head.appendChild(s);
		return id;
	};
	B.init = function () {
		var id = job();
		try {
			track(id, sdk().init().then(function () {
				var g = sdk().game;
				B.muted = !!(g.settings && g.settings.muteAudio);
				g.addSettingsChangeListener(function (s) { B.muted = !!(s && s.muteAudio); });
				return String(sdk().environment);
			}));
		} catch (e) { finish(id, false, String(e)); }
		return id;
	};
	B.ad = function (kind) {
		var id = job();
		try {
			sdk().ad.requestAd(kind, {
				adStarted: function () { var j = B.jobs[id]; if (j) j.started = true; },
				adFinished: function () { finish(id, true, null); },
				adError: function (e) { finish(id, false, (e && e.code) || 'other'); }
			});
		} catch (e) { finish(id, false, 'other'); }
		return id;
	};
	B.adblock = function () {
		var id = job();
		try { track(id, sdk().ad.hasAdblock()); } catch (e) { finish(id, false, String(e)); }
		return id;
	};
	B.call = function (name) { try { sdk().game[name](); return true; } catch (e) { return false; } };
	B.poll = function (id) { var j = B.jobs[id]; return j ? JSON.stringify(j) : 'null'; };
	B.drop = function (id) { delete B.jobs[id]; };
})();
"""

var environment := ""

var _sdk_ready := false
var _muted := false


func _init(host_node: Node) -> void:
	super(host_node)
	portal_name = "crazygames"


func init_async() -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval(GLUE_JS, true)

	var loaded := await _run_job("window.__wetCrazy.load(%s)" % JSON.stringify(SDK_URL), INIT_TIMEOUT_SEC)
	if not loaded.ok:
		push_warning("WebToolkit: CrazyGames SDK could not be loaded (%s)." % str(loaded.value))
		return false

	var init := await _run_job("window.__wetCrazy.init()", INIT_TIMEOUT_SEC)
	if not init.ok:
		push_warning("WebToolkit: CrazyGames SDK init failed (%s)." % str(init.value))
		return false

	environment = str(init.value)
	if environment == "disabled":
		# not on crazygames -> sdk calls would just throw errors
		return false

	_sdk_ready = true
	_poll_mute() # get the current state once
	_watch_mute()
	return true


func loading_start() -> void: _game_call("loadingStart")
func loading_stop() -> void: _game_call("loadingStop")
func gameplay_start() -> void: _game_call("gameplayStart")
func gameplay_stop() -> void: _game_call("gameplayStop")
func happytime() -> void: _game_call("happytime")


func show_ad_async(kind: String) -> Dictionary:
	if not _sdk_ready:
		return {"ok": false, "code": "not_ready"}
	var id := int(JavaScriptBridge.eval("window.__wetCrazy.ad(%s)" % JSON.stringify(kind), true))
	var announced := false
	var deadline := Time.get_ticks_msec() + int(AD_TIMEOUT_SEC * 1000.0)
	var state := {}
	while Time.get_ticks_msec() < deadline:
		state = _poll(id)
		if not announced and state.get("started", false):
			announced = true
			ad_started.emit()
		if state.get("done", false):
			break
		await host.get_tree().process_frame
	_drop(id)

	if not state.get("done", false):
		return {"ok": false, "code": "timeout"}
	if state.get("ok", false):
		return {"ok": true, "code": ""}
	return {"ok": false, "code": str(state.get("value", "other"))}


func has_adblock_async() -> bool:
	if not _sdk_ready:
		return false
	var result := await _run_job("window.__wetCrazy.adblock()", 10.0)
	return result.ok and result.value == true


func is_muted_by_portal() -> bool:
	return _muted


# --- internal ---

func _game_call(fn: String) -> void:
	if _sdk_ready:
		JavaScriptBridge.eval("window.__wetCrazy.call(%s)" % JSON.stringify(fn), true)


# start a job with some js and wait till its done -> {"ok": bool, "value": Variant}
func _run_job(js_expression: String, timeout_sec: float) -> Dictionary:
	var id := int(JavaScriptBridge.eval(js_expression, true))
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	var state := {}
	while Time.get_ticks_msec() < deadline:
		state = _poll(id)
		if state.get("done", false):
			break
		await host.get_tree().process_frame
	_drop(id)
	if not state.get("done", false):
		return {"ok": false, "value": "timeout"}
	return {"ok": state.get("ok", false), "value": state.get("value")}


func _poll(id: int) -> Dictionary:
	var raw = JavaScriptBridge.eval("window.__wetCrazy.poll(%d)" % id, true)
	var parsed = JSON.parse_string(str(raw))
	return parsed if parsed is Dictionary else {}


func _drop(id: int) -> void:
	JavaScriptBridge.eval("window.__wetCrazy.drop(%d)" % id, true)


# check 2x per second if CG switched the sound on/off
func _watch_mute() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(_poll_mute)
	host.add_child.call_deferred(timer)
	timer.autostart = true


func _poll_mute() -> void:
	var muted := bool(JavaScriptBridge.eval("window.__wetCrazy.muted === true", true))
	if muted != _muted:
		_muted = muted
		portal_mute_changed.emit(_muted)

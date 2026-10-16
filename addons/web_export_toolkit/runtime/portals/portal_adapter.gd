extends RefCounted
## Base class for the portal adapters (crazygames, simulation, poki later).
## Your game never talks to this directly, always go through WebToolkit.
## New portal = extend this and override what you need.

## portal wants sound off/on
signal portal_mute_changed(muted: bool)
## ad is visible now
signal ad_started

## "crazygames", "simulation", "none"
var portal_name := "none"

## node we use for timers/frames (the WebToolkit autoload)
var host: Node


func _init(host_node: Node) -> void:
	host = host_node


## load + init the sdk, true if it worked
func init_async() -> bool:
	return true


func loading_start() -> void:
	pass


func loading_stop() -> void:
	pass


func gameplay_start() -> void:
	pass


func gameplay_stop() -> void:
	pass


func happytime() -> void:
	pass


## kind = "midgame" or "rewarded"
## returns {"ok": bool, "code": String}, ok = ad ran completly (rewarded -> give reward)
func show_ad_async(_kind: String) -> Dictionary:
	return {"ok": false, "code": "unsupported"}


func has_adblock_async() -> bool:
	return false


## portal wants sound off right now?
func is_muted_by_portal() -> bool:
	return false

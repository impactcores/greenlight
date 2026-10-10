@tool
extends RefCounted
## All the checks + fixes live here.
## Basically every problem I ran into with web exports at some point.
##
## Each check gives back a dict:
##   id       - used for apply_fix()
##   title    - shown in the dock
##   status   - "green" / "yellow" / "red"
##   msg      - what's wrong
##   fix      - text for the fix button, "" if there is no auto fix
##   restart  - fix needs an editor restart
##   where    - where to find the setting yourself (in editor language)
##   search   - search term for the project settings filter, "" if it lives somewhere else
##   advanced - needs "Advanced Settings" switched on
##   preset   - section of the web export preset this row is about ("" = project wide)
##   preset_name - its name as shown in the export dialog
##
## Projects can have more than one web preset (e.g. one for itch.io and one for
## your own website). Then every preset gets its own rows and the id looks like
## "threads@preset.3", so a fix only ever touches that one preset.

const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")

const PRESETS_PATH := "res://export_presets.cfg"
const DEFAULT_EXPORT_PATH := "build/web/index.html"

# web audio: these are just godots own web defaults (4.3+). if people change them it starts crackling
const AUDIO_LATENCY := "audio/driver/output_latency.web"
const AUDIO_LATENCY_MIN := 50 # ms
const AUDIO_PLAYBACK := "audio/general/default_playback_type.web"
const AUDIO_PLAYBACK_SAMPLE := 1 # 0 = Stream, 1 = Sample
const AUDIO_MIX_RATE := "audio/driver/mix_rate.web"
const AUDIO_MIX_RATE_BROWSER := 0 # 0 = use the browser's rate

## Where to find stuff in the editor.
## Menu names are godots original english texts, they get translated with godots
## own translations so a german editor shows german menus. [brackets] = names
## that should NOT be translated (preset name, field name).
## For project settings I just give the search term, becuase that works in every language.
const WHERE := {
	"web_preset": {"menu": ["Project", "Export...", "Add...", "[Web]"]},
	"threads": {"menu": ["Project", "Export...", "[Web]", "Options", "Variant", "[Thread Support]"]},
	"export_path": {"menu": ["Project", "Export...", "[Web]", "Export Path"]},
	"templates": {"menu": ["Editor", "Manage Export Templates..."]},
	"main_scene": {"search": ["main_scene"]},
	"stretch": {"search": ["stretch"]},
	"web_audio": {"search": ["output_latency", "default_playback_type", "mix_rate"], "advanced": true},
}


func run_all() -> Array[Dictionary]:
	var presets := _load_presets()
	var web_sections := _find_web_presets(presets)
	var multi := web_sections.size() > 1
	var results: Array[Dictionary] = [_check_web_preset(web_sections)]
	if web_sections.is_empty():
		# no preset yet: still show the rows, they just say "create a preset first"
		results.append(_check_threads(presets, "", false))
		results.append(_check_export_path(presets, "", false))
	for section in web_sections:
		results.append(_check_threads(presets, section, multi))
		results.append(_check_export_path(presets, section, multi))
	results.append_array([
		_check_templates(),
		_check_main_scene(),
		_check_stretch_mode(),
		_check_web_audio(),
	])
	for r in results:
		_add_where(r)
	return results


## run the fix for one check, true if something actually changed
func apply_fix(id: String) -> bool:
	var parts := id.split("@")
	var base := parts[0]
	var section := parts[1] if parts.size() > 1 else ""
	if section.is_empty() and base in ["threads", "export_path"]:
		section = _find_web_preset(_load_presets())
	match base:
		"web_preset":
			return _fix_web_preset()
		"threads":
			return _fix_threads(section)
		"export_path":
			return _fix_export_path(section)
		"main_scene":
			return _fix_main_scene()
		"stretch":
			return _fix_stretch_mode()
		"web_audio":
			return _fix_web_audio()
	return false


# --- Checks ------------------------------------------------------------------

func _check_web_preset(web_sections: Array) -> Dictionary:
	var title := I18n.t("Web export preset")
	if web_sections.is_empty():
		return _result("web_preset", title, "red",
			I18n.t("No web preset found."), I18n.t("Create preset"), true)
	if web_sections.size() > 1:
		return _result("web_preset", title, "green", I18n.t("%d web presets found.") % web_sections.size())
	return _result("web_preset", title, "green", I18n.t("Web preset found."))


func _check_threads(presets: ConfigFile, web_section: String, multi: bool) -> Dictionary:
	var title := I18n.t("Thread support")
	if web_section.is_empty():
		return _result("threads", title, "yellow", I18n.t("Create a web preset first."))
	var r: Dictionary
	if presets.get_value(web_section + ".options", "variant/thread_support", false):
		r = _result("threads", title, "yellow",
			I18n.t("Threads are on. That needs special server headers (COOP/COEP) and does not work on many portals."),
			I18n.t("Turn threads off"), true)
	else:
		r = _result("threads", title, "green", I18n.t("Threads off – runs on itch.io and portals."))
	return _for_preset(r, presets, web_section, multi)


func _check_export_path(presets: ConfigFile, web_section: String, multi: bool) -> Dictionary:
	var title := I18n.t("Export path")
	if web_section.is_empty():
		return _result("export_path", title, "yellow", I18n.t("Create a web preset first."))
	var path: String = presets.get_value(web_section, "export_path", "")
	var r: Dictionary
	if path.is_empty():
		r = _result("export_path", title, "yellow",
			I18n.t("No export path set."), I18n.t("Set to %s") % DEFAULT_EXPORT_PATH, true)
	elif path.get_file() != "index.html":
		r = _result("export_path", title, "yellow",
			I18n.t("File is called \"%s\". itch.io and many portals expect index.html.") % path.get_file(),
			I18n.t("Rename to index.html"), true)
	else:
		r = _result("export_path", title, "green", I18n.t("Exports to %s") % path)
	return _for_preset(r, presets, web_section, multi)


# tags a result with its preset. with several web presets the preset name goes
# into the title and the id, so every preset has its own row + own fix button
func _for_preset(r: Dictionary, presets: ConfigFile, section: String, multi: bool) -> Dictionary:
	var name := str(presets.get_value(section, "name", "Web"))
	r["preset"] = section
	r["preset_name"] = name
	if multi:
		r["id"] = "%s@%s" % [r.id, section]
		r["title"] = "%s – %s" % [r.title, name]
	return r


func _check_templates() -> Dictionary:
	var title := I18n.t("Export templates")
	var version := _engine_version()
	var dir := EditorInterface.get_editor_paths().get_data_dir().path_join("export_templates").path_join(version)
	for file in ["web_nothreads_release.zip", "web_release.zip"]:
		if FileAccess.file_exists(dir.path_join(file)):
			return _result("templates", title, "green", I18n.t("Web templates for %s installed.") % version)
	return _result("templates", title, "red",
		I18n.t("No web templates found for %s – without them Godot cannot export for the browser.") % version)


func _check_main_scene() -> Dictionary:
	var title := I18n.t("Main scene")
	var scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if scene.is_empty():
		var root := EditorInterface.get_edited_scene_root()
		var label := ""
		if root and not root.scene_file_path.is_empty():
			label = I18n.t("Use \"%s\"") % root.scene_file_path.get_file()
		var msg := I18n.t("No main scene set – the export will not start without one.")
		if label.is_empty():
			msg += I18n.t(" Open the scene you want and check again.")
		return _result("main_scene", title, "red", msg, label)
	return _result("main_scene", title, "green", scene.get_file())


func _check_stretch_mode() -> Dictionary:
	var title := I18n.t("Scaling")
	var mode := str(ProjectSettings.get_setting("display/window/stretch/mode", "disabled"))
	if mode == "disabled":
		return _result("stretch", title, "yellow",
			I18n.t("Stretch mode is off. On portals with changing window sizes the game gets cut off."),
			I18n.t("Set to canvas_items"))
	return _result("stretch", title, "green", I18n.t("Stretch mode: %s") % mode)


func _check_web_audio() -> Dictionary:
	var title := I18n.t("Web audio")
	var problems: Array[String] = []
	var latency := int(ProjectSettings.get_setting(AUDIO_LATENCY, AUDIO_LATENCY_MIN))
	if latency < AUDIO_LATENCY_MIN:
		problems.append(I18n.t("latency %d ms (below %d ms audio often crackles in the browser)") % [latency, AUDIO_LATENCY_MIN])
	if ProjectSettings.has_setting(AUDIO_PLAYBACK) \
			and int(ProjectSettings.get_setting(AUDIO_PLAYBACK)) != AUDIO_PLAYBACK_SAMPLE:
		problems.append(I18n.t("playback \"Stream\" instead of \"Sample\" (prone to dropouts without threads)"))
	var mix_rate := int(ProjectSettings.get_setting(AUDIO_MIX_RATE, AUDIO_MIX_RATE_BROWSER))
	if mix_rate != AUDIO_MIX_RATE_BROWSER:
		problems.append(I18n.t("fixed mix rate %d Hz instead of the browser's rate") % mix_rate)

	if problems.is_empty():
		return _result("web_audio", title, "green",
			I18n.t("Latency, playback mode and mix rate at web defaults."))
	var msg := "; ".join(problems) + "."
	msg = msg.left(1).to_upper() + msg.substr(1)
	return _result("web_audio", title, "yellow", msg, I18n.t("Reset to web defaults"))


# --- Fixes -------------------------------------------------------------------

func _fix_web_preset() -> bool:
	var cfg := _load_presets()
	if not _find_web_preset(cfg).is_empty():
		return false
	var i := 0
	while cfg.has_section("preset.%d" % i):
		i += 1
	# append a new block as text, so the presets that are already there stay untouched
	var block := "\n[preset.%d]\n\nname=\"Web\"\nplatform=\"Web\"\nrunnable=true\n" % i
	block += "advanced_options=false\ndedicated_server=false\ncustom_features=\"\"\n"
	block += "export_filter=\"all_resources\"\ninclude_filter=\"\"\nexclude_filter=\"\"\n"
	block += "export_path=\"%s\"\n\n[preset.%d.options]\n\n" % [DEFAULT_EXPORT_PATH, i]
	block += "variant/thread_support=false\nvariant/extensions_support=false\n"
	var text := _read_presets_text()
	if not text.is_empty() and not text.ends_with("\n"):
		text += "\n"
	_ensure_export_dir(DEFAULT_EXPORT_PATH)
	return _write_presets_text(text + block)


func _fix_threads(section: String) -> bool:
	if section.is_empty():
		return false
	return _set_preset_line(section + ".options", "variant/thread_support", "false")


func _fix_export_path(section: String) -> bool:
	if section.is_empty():
		return false
	var cfg := _load_presets()
	var s := section
	var path: String = cfg.get_value(s, "export_path", "")
	var new_path := DEFAULT_EXPORT_PATH if path.is_empty() else path.get_base_dir().path_join("index.html")
	_ensure_export_dir(new_path)
	return _set_preset_line(s, "export_path", "\"%s\"" % new_path)


# Changes ONE key in export_presets.cfg as plain text.
# Saving through ConfigFile would rewrite the whole file and mess with stuff
# we never touched (it drops spaces in keys like "Windows Desktop", reformats
# multiline scripts...). Found that one with a real project, so: text only.
func _set_preset_line(section: String, key: String, value: String) -> bool:
	var lines := _read_presets_text().split("\n")
	var header := "[%s]" % section
	var in_section := false
	var insert_at := -1
	for i in lines.size():
		var t := lines[i].strip_edges()
		if t.begins_with("[") and t.ends_with("]"):
			if in_section:
				break # next section, key not found
			in_section = (t == header)
			if in_section:
				insert_at = i + 1
			continue
		if in_section and t.begins_with(key + "="):
			lines[i] = "%s=%s" % [key, value]
			return _write_presets_text("\n".join(lines))
	if insert_at < 0:
		return false # section missing
	# key not there yet: put it right under the section header (after the empty line)
	if insert_at < lines.size() and lines[insert_at].strip_edges().is_empty():
		insert_at += 1
	lines.insert(insert_at, "%s=%s" % [key, value])
	return _write_presets_text("\n".join(lines))


func _read_presets_text() -> String:
	if not FileAccess.file_exists(PRESETS_PATH):
		return ""
	return FileAccess.get_file_as_string(PRESETS_PATH)


func _write_presets_text(text: String) -> bool:
	var f := FileAccess.open(PRESETS_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _fix_main_scene() -> bool:
	var root := EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path.is_empty():
		return false
	ProjectSettings.set_setting("application/run/main_scene", root.scene_file_path)
	return ProjectSettings.save() == OK


func _fix_stretch_mode() -> bool:
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	return ProjectSettings.save() == OK


func _fix_web_audio() -> bool:
	ProjectSettings.set_setting(AUDIO_LATENCY, AUDIO_LATENCY_MIN)
	if ProjectSettings.has_setting(AUDIO_PLAYBACK):
		ProjectSettings.set_setting(AUDIO_PLAYBACK, AUDIO_PLAYBACK_SAMPLE)
	ProjectSettings.set_setting(AUDIO_MIX_RATE, AUDIO_MIX_RATE_BROWSER)
	return ProjectSettings.save() == OK


# --- "Where" hints -----------------------------------------------------------

# fills in where/search/advanced from the WHERE table
func _add_where(r: Dictionary) -> void:
	var info: Dictionary = WHERE.get(str(r.id).split("@")[0], {})
	var terms: Array = info.get("search", [])
	var search: String = terms[0] if terms.size() > 0 else ""
	var advanced: bool = info.get("advanced", false)
	var parts: Array[String] = []
	if info.has("menu"):
		for item in info.menu:
			if item == "[Web]" and r.has("preset_name"):
				item = "[%s]" % r.preset_name # the preset as it is called in the export dialog
			parts.append(_ui(item))
	elif not search.is_empty():
		parts.append(_ui("Project"))
		parts.append(_ui("Project Settings..."))
		if advanced:
			parts.append(_ui("Advanced Settings"))
		var quoted: Array[String] = []
		for term in terms:
			quoted.append("\"%s\"" % term)
		parts.append("%s: %s" % [_ui("Filter Settings"), " / ".join(quoted)])
	r["where"] = " › ".join(parts)
	r["search"] = search
	r["advanced"] = advanced


# translate a godot menu text + cut the "..." at the end ("Export..." -> "Export")
func _ui(text: String) -> String:
	if text.begins_with("[") and text.ends_with("]"):
		return text.substr(1, text.length() - 2)
	var translated := text
	# domains only exist since 4.4, older versions just get english
	if TranslationServer.has_method("get_or_add_domain"):
		translated = String(TranslationServer.call("get_or_add_domain", "godot.editor").translate(text))
	return translated.trim_suffix("...").trim_suffix("…").strip_edges()


# --- Helpers -----------------------------------------------------------------

func _load_presets() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PRESETS_PATH) # no file yet? fine, cfg is just empty then
	return cfg


func _find_web_presets(cfg: ConfigFile) -> Array:
	var out := []
	for section in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		if cfg.get_value(section, "platform", "") == "Web":
			out.append(section)
	return out


func _find_web_preset(cfg: ConfigFile) -> String:
	for section in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		if cfg.get_value(section, "platform", "") == "Web":
			return section
	return ""


func _ensure_export_dir(export_path: String) -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(export_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir)
	# .gdignore so godot doesnt start importing the exported build (it will try otherwise)
	var ignore := dir.path_join(".gdignore")
	if not FileAccess.file_exists(ignore):
		FileAccess.open(ignore, FileAccess.WRITE)


func _engine_version() -> String:
	var v := Engine.get_version_info()
	var version := "%d.%d" % [v.major, v.minor]
	if v.patch > 0:
		version += ".%d" % v.patch
	return version + "." + str(v.status)


func _result(id: String, title: String, status: String, msg: String,
		fix: String = "", restart: bool = false) -> Dictionary:
	return {"id": id, "title": title, "status": status, "msg": msg, "fix": fix, "restart": restart}

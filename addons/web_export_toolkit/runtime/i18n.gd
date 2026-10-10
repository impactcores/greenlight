@tool
extends RefCounted
## Tiny translation helper. English is the base, german gets used when
##  - editor: your godot editor is set to german
##  - in game: the players system langauge is german
##
## Usage:
##     const I18n := preload("res://addons/web_export_toolkit/runtime/i18n.gd")
##     label.text = I18n.t("Check now")
##     msg = I18n.t("No web templates found for %s.") % version
##
## Want another language? Add a dict like DE and extend _language(). Just tell me which one :)

const DE := {
	# dock
	"Check now": "Jetzt prüfen",
	"Fix all": "Alle beheben",
	"Fix all (%d)": "Alle beheben (%d)",
	"%d ok · %d warnings · %d errors": "%d ok · %d Hinweise · %d Fehler",
	"Where: ": "Wo: ",
	"This is where to find the setting if you want to change it yourself.": "Hier findest du die Einstellung, falls du sie selbst ändern willst.",
	"The export settings were changed.\nGodot only picks them up after the editor restarts.\n\nRestart now? (Open scenes will be saved.)": "Die Export-Einstellungen wurden geändert.\nDamit Godot sie übernimmt, muss der Editor neu starten.\n\nJetzt neu starten? (Offene Szenen werden gespeichert.)",
	"Restart": "Neu starten",
	"Later": "Später",
	"Restart needed": "Neustart nötig",
	"The fixes are saved, but Godot only uses the new export settings after a restart. Until then the Export dialog still shows the old values – don't save anything there, it would undo the fix.": "Die Fixes sind gespeichert, aber Godot übernimmt die neuen Export-Einstellungen erst nach einem Neustart. Bis dahin zeigt der Export-Dialog noch die alten Werte – speichere dort nichts, sonst wird der Fix rückgängig gemacht.",
	"Restart now": "Jetzt neu starten",

	# update hint
	"Greenlight %s is available (you have %s).": "Greenlight %s ist da (du hast %s).",
	"Show update": "Update ansehen",
	"Skip this version": "Diese Version überspringen",

	# check titles
	"Web export preset": "Web-Export-Preset",
	"Thread support": "Thread-Unterstützung",
	"Export path": "Exportpfad",
	"Export templates": "Export-Templates",
	"Main scene": "Hauptszene",
	"Scaling": "Skalierung",
	"Web audio": "Web-Audio",

	# check messages + fix buttons
	"No web preset found.": "Kein Web-Preset gefunden.",
	"Create preset": "Preset anlegen",
	"Web preset found.": "Web-Preset vorhanden.",
	"%d web presets found.": "%d Web-Presets vorhanden.",
	"Fix selected": "Auswahl beheben",
	"Cancel": "Abbrechen",
	"Several web export presets need changes. Which ones should Greenlight fix?": "Mehrere Web-Export-Presets brauchen Änderungen. Welche soll Greenlight beheben?",
	"Project settings (main scene, scaling, web audio) are fixed in any case.": "Projekteinstellungen (Hauptszene, Skalierung, Web-Audio) werden in jedem Fall behoben.",
	"Create a web preset first.": "Erst ein Web-Preset anlegen.",
	"Threads are on. That needs special server headers (COOP/COEP) and does not work on many portals.": "Threads sind an. Das braucht spezielle Server-Header (COOP/COEP) und läuft auf vielen Portalen nicht.",
	"Turn threads off": "Threads ausschalten",
	"Threads off – runs on itch.io and portals.": "Threads aus – läuft auf itch.io und Portalen.",
	"No export path set.": "Kein Exportpfad gesetzt.",
	"Set to %s": "Auf %s setzen",
	"File is called \"%s\". itch.io and many portals expect index.html.": "Datei heißt „%s“. itch.io und viele Portale erwarten index.html.",
	"Rename to index.html": "In index.html umbenennen",
	"Exports to %s": "Export nach %s",
	"Web templates for %s installed.": "Web-Templates für %s installiert.",
	"No web templates found for %s – without them Godot cannot export for the browser.": "Keine Web-Templates für %s gefunden – ohne sie kann Godot nicht für den Browser exportieren.",
	"Use \"%s\"": "„%s“ verwenden",
	"No main scene set – the export will not start without one.": "Keine Hauptszene gesetzt – der Export startet sonst nicht.",
	" Open the scene you want and check again.": " Öffne die gewünschte Szene und prüfe erneut.",
	"Stretch mode is off. On portals with changing window sizes the game gets cut off.": "Stretch-Modus ist aus. Auf Portalen mit wechselnder Fenstergröße wird das Spiel sonst abgeschnitten.",
	"Set to canvas_items": "Auf canvas_items stellen",
	"Stretch mode: %s": "Stretch-Modus: %s",
	"latency %d ms (below %d ms audio often crackles in the browser)": "Latenz %d ms (unter %d ms knackt es im Browser oft)",
	"playback \"Stream\" instead of \"Sample\" (prone to dropouts without threads)": "Wiedergabe „Stream“ statt „Sample“ (ohne Threads anfällig für Aussetzer)",
	"fixed mix rate %d Hz instead of the browser's rate": "feste Mix-Rate %d Hz statt Browser-Rate",
	"Latency, playback mode and mix rate at web defaults.": "Latenz, Wiedergabemodus und Mix-Rate auf Web-Standard.",
	"Reset to web defaults": "Auf Web-Standard zurücksetzen",

	# ingame stuff (players see this)
	"Click to start": "Klicken zum Starten",
	"Tap or click to start": "Tippen oder klicken zum Starten",

	# demo scene
	"Started! Your music could start playing now.": "Gestartet! Hier könnte jetzt deine Musik loslegen.",
}

static var _cached_language := ""


## translate english text, no translation found = text comes back as is
static func t(text: String) -> String:
	if _language() == "de":
		return DE.get(text, text)
	return text


# "de" or "en"
static func _language() -> String:
	if _cached_language.is_empty():
		var lang := ""
		if Engine.is_editor_hint():
			# the language the editor UI is actually shown in. this also covers
			# the "auto" setting, where godot picks the system language
			if TranslationServer.has_method("get_tool_locale"):
				lang = str(TranslationServer.call("get_tool_locale"))
			if lang.is_empty() and Engine.has_singleton("EditorInterface"):
				var editor = Engine.get_singleton("EditorInterface")
				lang = str(editor.get_editor_settings().get_setting("interface/editor/editor_language"))
			if lang.is_empty() or lang == "auto":
				lang = OS.get_locale_language()
		else:
			lang = OS.get_locale_language()
		_cached_language = "de" if lang.begins_with("de") else "en"
	return _cached_language

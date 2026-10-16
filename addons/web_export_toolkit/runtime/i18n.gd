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

	# browser test
	"Test in browser": "Im Browser testen",
	"Which web export preset to test": "Welches Web-Export-Preset getestet wird",
	"CrazyGames test ads": "CrazyGames-Testwerbung",
	"Opens the game with ?useLocalSdk=true, then the CrazyGames SDK shows test ads.": "Öffnet das Spiel mit ?useLocalSdk=true, dann zeigt das CrazyGames-SDK Testwerbung.",
	"Export & open": "Exportieren & öffnen",
	"Open last export": "Letzten Export öffnen",
	"Stop server": "Server stoppen",
	"This preset has no export path yet – \"Fix all\" sets one.": "Dieses Preset hat noch keinen Exportpfad – „Alle beheben“ setzt einen.",
	"Could not start the export.": "Export konnte nicht gestartet werden.",
	"Exporting \"%s\" … this can take a moment.": "Exportiere „%s“ … das kann einen Moment dauern.",
	"Export failed. Try it once via Project › Export to see the error.": "Export fehlgeschlagen. Probier es einmal über Projekt › Exportieren, dann siehst du den Fehler.",
	"Export failed: %s": "Export fehlgeschlagen: %s",
	"No export found yet.": "Noch kein Export vorhanden.",
	"No free port between 8070 and 8079.": "Kein freier Port zwischen 8070 und 8079.",
	"Running at %s": "Läuft unter %s",

	# itch.io upload
	"Upload to itch.io": "Auf itch.io hochladen",
	"user/game – like in your itch.io link": "name/spiel – wie in deinem itch.io-Link",
	"Your itch.io name and the name of the game page, e.g. impactcores/hairline for impactcores.itch.io/hairline": "Dein itch.io-Name und der Name der Spielseite, z. B. impactcores/hairline für impactcores.itch.io/hairline",
	"Presets → channel": "Presets → Kanal",
	"Channel names with windows, linux, mac or android get the right platform tag on itch.io automatically.": "Kanalnamen mit windows, linux, mac oder android bekommen auf itch.io automatisch das richtige Plattform-Tag.",
	"No export presets yet (Project › Export).": "Noch keine Export-Presets (Projekt › Exportieren).",
	"Export & upload (%d)": "Exportieren & hochladen (%d)",
	"Tick at least one preset.": "Mindestens ein Preset anhaken.",
	"\"%s\" and \"%s\" use the same channel – each preset needs its own.": "„%s“ und „%s“ nutzen denselben Kanal – jedes Preset braucht einen eigenen.",
	"%s: exporting …": "%s: exportiere …",
	"%s: uploading to itch.io …": "%s: lade auf itch.io hoch …",
	"Some uploads failed:": "Einige Uploads sind fehlgeschlagen:",
	"Downloads (Windows, Linux, Mac, Android) get their platform tag from the channel name and show up on the page by themselves.": "Downloads (Windows, Linux, Mac, Android) bekommen ihr Plattform-Tag über den Kanalnamen und erscheinen von selbst auf der Seite.",
	"Download butler": "butler herunterladen",
	"Downloads butler (about 15 MB) from itch.io into the Godot editor data folder.": "Lädt butler (ca. 15 MB) von itch.io in den Datenordner des Godot-Editors.",
	"Log in": "Anmelden",
	"Opens the itch.io login in your browser. butler keeps the key, Greenlight never sees it.": "Öffnet die itch.io-Anmeldung im Browser. butler speichert den Schlüssel, Greenlight sieht ihn nie.",
	"Export & upload": "Exportieren & hochladen",
	"Open game page": "Spielseite öffnen",
	"butler not found.": "butler nicht gefunden.",
	"butler ready, logged in.": "butler bereit, angemeldet.",
	"butler found – log in once.": "butler gefunden – einmal anmelden.",
	"Download failed (%s).": "Download fehlgeschlagen (%s).",
	"Downloading butler from itch.io …": "Lade butler von itch.io …",
	"Download failed (%s). You can also install the itch app, it brings butler along.": "Download fehlgeschlagen (%s). Alternativ die itch-App installieren, die bringt butler mit.",
	"butler installed: %s": "butler installiert: %s",
	"Please run this once in a terminal (it is in your clipboard):\n%s": "Bitte einmal im Terminal ausführen (steht in deiner Zwischenablage):\n%s",
	"Log in with itch.io in your browser …": "Melde dich im Browser bei itch.io an …",
	"Enter your itch.io name and game like this: user/game": "Gib deinen itch.io-Namen und das Spiel so ein: name/spiel",
	"The channel may only contain a-z, 0-9, - and _.": "Der Kanal darf nur a–z, 0–9, - und _ enthalten.",
	"Could not start butler.": "butler konnte nicht gestartet werden.",
	"Logged in. You can upload now.": "Angemeldet. Du kannst jetzt hochladen.",
	"Login did not work: %s": "Anmeldung hat nicht geklappt: %s",
	"Upload failed: %s": "Upload fehlgeschlagen: %s",
	"Uploaded! itch.io processes the build for a moment, then it is live.": "Hochgeladen! itch.io verarbeitet den Build kurz, dann ist er online.",
	"First upload to this page? On itch.io open \"Edit game\": set \"Kind of project\" to HTML and tick \"This file will be played in the browser\" at the uploaded file. After that every upload goes live by itself.": "Erster Upload auf diese Seite? Auf itch.io „Edit game“ öffnen: „Kind of project“ auf HTML stellen und bei der hochgeladenen Datei „This file will be played in the browser“ anhaken. Danach geht jeder Upload von selbst online.",
	"Your preset uses threads: also tick \"SharedArrayBuffer support\" in the embed options.": "Dein Preset nutzt Threads: In den Embed-Optionen zusätzlich „SharedArrayBuffer support“ anhaken.",

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
	"Test ad (%s)\nOn CrazyGames a real ad appears here.": "Testwerbung (%s)\nAuf CrazyGames erscheint hier echte Werbung.",

	# demo scene
	"Coins: %d": "Münzen: %d",
	"Midgame ad": "Werbung zwischendurch",
	"Rewarded ad (+10 coins)": "Belohnte Werbung (+10 Münzen)",
	"Happytime": "Happytime",
	"Check for ad blocker": "Werbeblocker prüfen",
	"Portal: %s": "Portal: %s",
	"Portal sound: %s": "Portal-Ton: %s",
	"off": "aus",
	"on": "an",
	"happytime sent": "happytime gesendet",
	"Midgame: %s": "Midgame: %s",
	"shown": "gezeigt",
	"not shown": "nicht gezeigt",
	"Rewarded: %s": "Rewarded: %s",
	"reward granted": "Belohnung erhalten",
	"no reward": "keine Belohnung",
	"Ad blocker: %s": "Werbeblocker: %s",
	"yes": "ja",
	"no": "nein",
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

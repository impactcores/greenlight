# Greenlight – Web Export Toolkit for Godot (v1.1.0)

*English: [README.md](README.md)*

Ich mache kleine Spiele mit Godot und stelle sie auf CrazyGames und itch.io. Und jedes mal war der Web-Export der Teil, der am meisten Zeit gefressen hat. Threads aus Versehen an, falscher Dateiname, knackendes Audio, kein Ton bis man klickt, Spiel wird auf dem Portal abgeschnitten... und die passende Einstellung im Editor zu finden ist auch nochmal ein Abenteuer für sich.

Deshalb dieses Plugin. Es prüft dein Projekt, sagt dir was nicht passt und behebt das meiste mit einem Klick.

## Installation

1. `addons/web_export_toolkit` in dein Projekt kopieren
2. Projekt → Projekteinstellungen → Plugins → **Greenlight** aktivieren
3. Rechts geht der Tab **Greenlight** auf

Der Autoload `WebToolkit` wird automatisch angelegt. Das Dock ist auf Deutsch oder Englisch, je nachdem wie dein Editor eingestellt ist.

## Der Checker

Auf **Jetzt prüfen** klicken und du bekommst eine Liste mit grün/gelb/rot:

| Prüfung | Ein-Klick-Fix |
| --- | --- |
| Web-Preset vorhanden | legt eins an (Threads aus, Export nach `build/web/index.html`) |
| Thread-Unterstützung aus (brauchen die Portale) | schaltet Threads aus |
| Exportdatei heißt `index.html` | benennt sie um |
| Web-Export-Templates installiert | – (Editor → Exportvorlagen verwalten…) |
| Hauptszene gesetzt | nimmt die Szene, die gerade offen ist |
| Stretch-Modus an | setzt `canvas_items` / `expand` |
| Web-Audio: Latenz ≥ 50 ms, Wiedergabe „Sample“, Browser-Mix-Rate | zurück auf Godots Web-Standardwerte |

**Alle beheben** macht alles auf einmal, in der richtigen Reihenfolge (das Preset muss ja zuerst da sein).

Du hast mehrere Web-Presets (z. B. eins für CrazyGames und eins für itch.io)? Dann bekommt jedes Preset eigene Zeilen mit eigenem Beheben-Knopf, und **Alle beheben** fragt dich vorher, welche Presets angepasst werden sollen. Vielleicht willst du für deinen eigenen Server ja Threads an lassen, deine Entscheidung. Bei nur einem Preset wird einfach direkt behoben.

Unter jedem Problem steht eine **Wo:**-Zeile mit dem Pfad zur Einstellung, falls du es lieber selbst änderst. Bei den Projekteinstellungen steht der Suchbegriff fürs Filterfeld dabei, der geht in jeder Sprache.

Wichtig: Änderungen an Export-Presets übernimmt Godot erst nach einem Neustart. Das Plugin fragt dich danach, und wenn du „Später“ klickst, bleibt oben im Dock ein gelber Hinweis „Neustart nötig“ stehen, bis du wirklich neu gestartet hast (auch wenn du das Plugin aus- und wieder einschaltest). Bis dahin speichere nichts im Export-Dialog, sonst überschreibt Godot den Fix wieder.

Der Build-Ordner bekommt außerdem eine `.gdignore`, damit Godot nicht anfängt deine exportierten Dateien zu importieren.

## Im Browser testen

Unten im Dock gibts **Im Browser testen**. Web-Preset auswählen, **Exportieren & öffnen** klicken: Greenlight exportiert im Hintergrund (der Editor bleibt benutzbar), startet einen kleinen lokalen Server und öffnet das Spiel im Browser. **Letzten Export öffnen** spart dir den Export, wenn du nur nochmal schauen willst.

Warum nicht einfach die index.html doppelklicken? Browser laden die .wasm nicht aus einer Datei, und mit Threads brauchst du spezielle Header. Der Server kann beides, und zwar nur auf 127.0.0.1, also sieht das niemand sonst.

Mit Haken bei **CrazyGames-Testwerbung** bekommt die Adresse `?useLocalSdk=true`, dann zeigt das CrazyGames-SDK Testwerbung und du kannst den ganzen Werbe-Ablauf ausprobieren bevor du irgendwas hochlädst.

## Auf itch.io hochladen

Darunter kommt **Auf itch.io hochladen**. Das nutzt [butler](https://itch.io/docs/butler/), das offizielle Upload-Tool von itch.io – und zwar für alle deine Export-Presets, nicht nur Web.

1. Deine Seite als `name/spiel` eintragen (oder den Link reinkopieren, `https://name.itch.io/spiel` geht auch).
2. Die Presets anhaken, die hochgeladen werden sollen. Jedes Preset hat einen eigenen Kanal: `html5`, `windows`, `linux`, `mac`, `android`. itch.io erkennt die Plattform am Kanalnamen, also lass diese Wörter drin.
3. Noch kein butler? **butler herunterladen** klicken, Greenlight holt ihn von itch.io (ca. 15 MB, in den Datenordner des Godot-Editors). Hast du die itch-App installiert oder butler im PATH, nimmt Greenlight den.
4. Einmal **Anmelden** klicken. Der Browser öffnet die itch.io-Anmeldung, butler speichert den Schlüssel selbst. Greenlight sieht ihn nie. (Unter Linux/macOS will butler dafür ein echtes Terminal, Greenlight legt dir den Befehl in die Zwischenablage.)
5. **Exportieren & hochladen** exportiert jedes angehakte Preset nach `build/itch/<kanal>/` und lädt es hoch, eins nach dem anderen. Wenn du unter Projekteinstellungen › Application › Config › Version eine Version einträgst, zeigt itch.io die an. Uploads ohne Änderungen werden übersprungen. Schlägt ein Export fehl, steht Godots Grund direkt im Dock (fehlende Export-Templates usw.).

Für Web musst du pro Seite einmal auf der Website etwas machen: **Edit game** → *Kind of project* = HTML, und bei der hochgeladenen Datei *This file will be played in the browser* anhaken. Windows-/Linux-/Mac-/Android-Downloads erscheinen von selbst. macOS wird als .zip hochgeladen, butler entpackt das.

## Klicken zum Starten

Browser spielen keinen Ton ab, bevor der Spieler irgendwo geklickt hat. Also in deiner Hauptszene:

```gdscript
func _ready() -> void:
	await WebToolkit.wait_for_start()   # eigener Text geht auch
	$Music.play()
```

Im Browser kommt ein einfacher Startbildschirm („Klicken zum Starten“ in der Sprache des Spielers), im Editor geht es einfach weiter. Willst du ihn im Editor sehen? Vorher `WebToolkit.force_click_to_start = true` setzen.

## Portal-Kram: CrazyGames

Eine API für Werbung und Spiel-Events. Das CrazyGames-SDK (v3) wird zur Laufzeit geladen, am HTML musst du nichts ändern.

```gdscript
func _ready() -> void:
	await WebToolkit.wait_for_start()
	WebToolkit.gameplay_start()

func _on_level_finished() -> void:
	WebToolkit.gameplay_stop()
	await WebToolkit.show_midgame_ad()      # Spiel ist solange pausiert + stumm
	WebToolkit.gameplay_start()

func _on_extra_life_pressed() -> void:
	if await WebToolkit.show_rewarded_ad():
		lives += 1                           # nur wenn die Werbung bis zum Ende lief
```

**Was das Plugin dir abnimmt**

- Spieler wechselt den Tab oder minimiert den Browser? Spiel wird pausiert und stumm geschaltet und läuft weiter, sobald der Tab wieder sichtbar ist. Portale wollen das, und man vergisst es schnell. Klappt überall im Browser, nicht nur auf CrazyGames. Projekteinstellungen → Greenlight → Web → When Tab Hidden: `pause_and_mute` (Standard), `mute` oder `off`.
- Während Werbung ist das Spiel pausiert (`get_tree().paused`) und der Master-Bus stumm. Danach ist alles wieder wie vorher.
- Schaltet der Spieler auf CrazyGames den Ton aus, bleibt dein Spiel stumm. Auch nach einer Werbung.
- Antwortet das SDK nicht, geht das Spiel nach 90 Sekunden trotzdem weiter.
- Werbeblocker oder keine Werbung verfügbar? Du bekommst `false` und das Spiel läuft einfach weiter. CrazyGames will sowieso, das Spiele auch mit Adblock laufen.

**Welches Portal benutzt wird** – Projekteinstellungen → Greenlight → Portal:

| Einstellung | Was passiert |
| --- | --- |
| `auto` (Standard) | CrazyGames-SDK nur auf CrazyGames, sonst nichts (itch.io usw.) |
| `crazygames` | immer CrazyGames-SDK laden |
| `none` | gar kein Portal |
| Simulate Outside Browser (an) | 2 Sekunden Test-Werbung im Editor/auf dem Desktop |

Im Browser testen: am einfachsten über **Im Browser testen** im Dock mit Haken bei CrazyGames-Testwerbung. Von Hand gehts auch: Spiel mit `?useLocalSdk=true` am Ende der Adresse öffnen, dann zeigt das CrazyGames-SDK Test-Werbung.

## API

| Aufruf | Wofür |
| --- | --- |
| `WebToolkit.is_web()` | `true` im Browser |
| `await WebToolkit.wait_for_start(text)` | wartet auf den ersten Klick/Tap |
| `WebToolkit.is_started` / `started` | schon gestartet? / Signal nach dem Start |
| `WebToolkit.gameplay_start()` / `gameplay_stop()` | es wird gespielt / Pause, Menü, Level-Ende |
| `WebToolkit.loading_start()` / `loading_stop()` | lädt / fertig geladen |
| `WebToolkit.happytime()` | großer Moment (nicht übertreiben) |
| `await WebToolkit.show_midgame_ad()` | Werbung zwischendurch, `true` wenn gezeigt |
| `await WebToolkit.show_rewarded_ad()` | belohnte Werbung, `true` = Belohnung geben |
| `await WebToolkit.has_adblock()` | Werbeblocker an? |
| `WebToolkit.get_portal_name()` | `"crazygames"`, `"simulation"` oder `"none"` |
| `await WebToolkit.wait_for_portal()` | aufs SDK warten (braucht man selten) |
| `WebToolkit.is_tab_hidden` | Spieler ist gerade in einem anderen Tab |
| Signale `ad_started(kind)`, `ad_finished(kind, success)`, `portal_mute_changed(muted)`, `portal_ready(name)`, `tab_visibility_changed(hidden)` | falls du selbst reagieren willst |

Portal-Aufrufe kannst du überall machen, ohne Portal passiert einfach nichts.

## Demo

`addons/web_export_toolkit/demo/demo.tscn` öffnen und starten. Knöpfe für beide Werbearten, Happytime und den Adblock-Check. Das drehende Quadrat bleibt während der Werbung stehen, so siehst du das die Pause funktioniert.

Getestet mit Godot 4.5, 4.6 und 4.7. Bug gefunden oder fehlt dir was? Schreib mir an gdplugin@impact-cores.de oder einfach einen Kommentar auf die itch.io-Seite.

## Updates

Einmal am Tag schaut greenlight in eine kleine `version.json` auf GitHub, ob es eine neuere Version gibt. Daten über dich oder dein Projekt werden nicht mitgeschickt, das ist ein normaler Datei-Download (GitHub sieht dabei wie bei jeder Website deine IP). Gibts ein Update, erscheint oben im Dock ein kleiner grüner Kasten mit Link zum Store. Willst du das nicht? Projekteinstellungen → Greenlight → Updates → Check For Updates aus.

Quellcode: https://github.com/impactcores/greenlight

## Lizenz

MIT, mach damit was du willst. Siehe `LICENSE`.

Greenlight hat nichts mit CrazyGames zu tun. Für CrazyGames und ihr SDK gelten deren eigene Bedingungen.

# Greenlight – Web Export Toolkit for Godot (v1.0.1)

*English: [README.md](README.md)*

Ich mache kleine Spiele mit Godot und stelle sie auf itch.io und andere Web-Portale. Und jedes mal war der Web-Export der Teil, der am meisten Zeit gefressen hat. Threads aus Versehen an, falscher Dateiname, knackendes Audio, kein Ton bis man klickt, Spiel wird auf dem Portal abgeschnitten... und die passende Einstellung im Editor zu finden ist auch nochmal ein Abenteuer für sich.

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

Du hast mehrere Web-Presets (z. B. eins für itch.io und eins für deine eigene Website)? Dann bekommt jedes Preset eigene Zeilen mit eigenem Beheben-Knopf, und **Alle beheben** fragt dich vorher, welche Presets angepasst werden sollen. Vielleicht willst du für deinen eigenen Server ja Threads an lassen, deine Entscheidung. Bei nur einem Preset wird einfach direkt behoben.

Unter jedem Problem steht eine **Wo:**-Zeile mit dem Pfad zur Einstellung, falls du es lieber selbst änderst. Bei den Projekteinstellungen steht der Suchbegriff fürs Filterfeld dabei, der geht in jeder Sprache.

Wichtig: Änderungen an Export-Presets übernimmt Godot erst nach einem Neustart. Das Plugin fragt dich danach, und wenn du „Später“ klickst, bleibt oben im Dock ein gelber Hinweis „Neustart nötig“ stehen, bis du wirklich neu gestartet hast (auch wenn du das Plugin aus- und wieder einschaltest). Bis dahin speichere nichts im Export-Dialog, sonst überschreibt Godot den Fix wieder.

Der Build-Ordner bekommt außerdem eine `.gdignore`, damit Godot nicht anfängt deine exportierten Dateien zu importieren.

## Klicken zum Starten

Browser spielen keinen Ton ab, bevor der Spieler irgendwo geklickt hat. Also in deiner Hauptszene:

```gdscript
func _ready() -> void:
	await WebToolkit.wait_for_start()   # eigener Text geht auch
	$Music.play()
```

Im Browser kommt ein einfacher Startbildschirm („Klicken zum Starten“ in der Sprache des Spielers), im Editor geht es einfach weiter. Willst du ihn im Editor sehen? Vorher `WebToolkit.force_click_to_start = true` setzen.

## API

| Aufruf | Wofür |
| --- | --- |
| `WebToolkit.is_web()` | `true` im Browser |
| `await WebToolkit.wait_for_start(text)` | wartet auf den ersten Klick/Tap |
| `WebToolkit.is_started` / `started` | schon gestartet? / Signal nach dem Start |

## Demo

`addons/web_export_toolkit/demo/demo.tscn` öffnen und starten, dann siehst du den Startbildschirm.

Getestet mit Godot 4.5, 4.6 und 4.7. Bug gefunden oder fehlt dir was? Schreib mir an gdplugin@impact-cores.de oder einfach einen Kommentar auf die itch.io-Seite.

## Updates

Einmal am Tag schaut greenlight in eine kleine `version.json` auf GitHub, ob es eine neuere Version gibt. Daten über dich oder dein Projekt werden nicht mitgeschickt, das ist ein normaler Datei-Download (GitHub sieht dabei wie bei jeder Website deine IP). Gibts ein Update, erscheint oben im Dock ein kleiner grüner Kasten mit Link zum Store. Willst du das nicht? Projekteinstellungen → Greenlight → Updates → Check For Updates aus.

Quellcode: https://github.com/impactcores/greenlight

## Lizenz

MIT, mach damit was du willst. Siehe `LICENSE`.

# Greenlight – Web Export Toolkit for Godot (v1.0.1)

*Deutsch: [README.de.md](addons/web_export_toolkit/README.de.md) · Godot Asset Store: [Greenlight – Web Export Toolkit](https://store.godotengine.org/asset/impact-cores/greenlight-web-export-toolkit/)*

I make small games with Godot and put them on itch.io and other web portals. And the web export was always the part that ate my time. Threads on by accident, wrong file name, crackling audio, no sound until you click, game gets cut off on the portal... and finding the right setting for all of that in the editor is its own little adventure.

So I built this. It checks your project, tells you whats wrong and fixes most of it with one click.

## Install

1. Copy `addons/web_export_toolkit` into your project
2. Project → Project Settings → Plugins → turn on **Greenlight**
3. The **Greenlight** tab opens on the right

The `WebToolkit` autoload gets added automatically. The dock is in english or german, depending on your editor language.

## The checker

Hit **Check now** and you get a green/yellow/red list:

| Check | One-click fix |
| --- | --- |
| Web preset exists | creates one (threads off, exports to `build/web/index.html`) |
| Thread support off (portals need this) | turns threads off |
| Export file is called `index.html` | renames it |
| Web export templates installed | – (Editor → Manage Export Templates…) |
| Main scene set | uses the scene you have open |
| Stretch mode on | sets `canvas_items` / `expand` |
| Web audio: latency ≥ 50 ms, "Sample" playback, browser mix rate | back to godots web defaults |

**Fix all** does everything at once, in the right order becuase the preset has to exist first.

Got more than one web preset (like one for itch.io and one for your own website)? Then every preset gets its own rows with its own fix button, and **Fix all** asks you which presets it should touch. Maybe you want threads on for your own server, thats your call. With only one preset it just does it.

Under every problem there is a **Where:** line with the path to the setting, so you can also change it yourself. For project settings it shows what to type in the filter box, that works in every language.

One thing to know: godot only picks up export preset changes after a restart. The plugin asks you, and if you click "Later" a yellow "Restart needed" box stays at the top of the dock until you really restarted (also if you turn the plugin off and on). Until then dont save anything in the export dialog, otherwise godot overwrites the fix again.

The build folder also gets a `.gdignore` so godot doesnt try to import your exported files.

## Click to start

Browsers dont play any audio before the player clicked something. So in your main scene:

```gdscript
func _ready() -> void:
	await WebToolkit.wait_for_start()   # you can pass your own text
	$Music.play()
```

In the browser you get a simple start screen ("Click to start" in the players language), in the editor it just continues. Want to see it in the editor? Set `WebToolkit.force_click_to_start = true` before.

## API

| Call | What for |
| --- | --- |
| `WebToolkit.is_web()` | `true` in the browser |
| `await WebToolkit.wait_for_start(text)` | waits for the first click/tap |
| `WebToolkit.is_started` / `started` | already started? / signal after the start |

## Demo

Open `addons/web_export_toolkit/demo/demo.tscn` and run it to see the start screen.

Tested with Godot 4.5, 4.6 and 4.7. Found a bug or missing something? Write me at gdplugin@impact-cores.de or just leave a comment on the itch.io page.

## Updates

Once a day greenlight looks at a small `version.json` on GitHub to see if there is a newer version. No data about you or your project gets sent, its a normal file download (GitHub sees your IP like with any website). If there is an update you get a small green box in the dock with a link to the store. Dont want that? Project Settings → Greenlight → Updates → Check For Updates off.

Source code: https://github.com/impactcores/greenlight

## License

MIT, do whatever you want with it. See `LICENSE`.

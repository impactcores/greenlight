# Greenlight – Web Export Toolkit for Godot (v1.1.0)

*Deutsch: [README.de.md](README.de.md)*

I make small games with Godot and put them on CrazyGames and itch.io. And the web export was always the part that ate my time. Threads on by accident, wrong file name, crackling audio, no sound until you click, game gets cut off on the portal... and finding the right setting for all of that in the editor is its own little adventure.

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

Got more than one web preset (like one for CrazyGames and one for itch.io)? Then every preset gets its own rows with its own fix button, and **Fix all** asks you which presets it should touch. Maybe you want threads on for your own server, thats your call. With only one preset it just does it.

Under every problem there is a **Where:** line with the path to the setting, so you can also change it yourself. For project settings it shows what to type in the filter box, that works in every language.

One thing to know: godot only picks up export preset changes after a restart. The plugin asks you, and if you click "Later" a yellow "Restart needed" box stays at the top of the dock until you really restarted (also if you turn the plugin off and on). Until then dont save anything in the export dialog, otherwise godot overwrites the fix again.

The build folder also gets a `.gdignore` so godot doesnt try to import your exported files.

## Test in the browser

At the bottom of the dock there is **Test in browser**. Pick your web preset and hit **Export & open**: Greenlight exports it in the background (the editor stays usable), starts a small local server and opens the game in your browser. **Open last export** skips the export if you just want to look again.

Why not just double click the index.html? Browsers dont load the .wasm from a file, and with threads on you need special headers. The server does both, only on 127.0.0.1 so nobody else sees it.

With **CrazyGames test ads** ticked the url gets `?useLocalSdk=true`, then the CrazyGames SDK shows test ads and you can try the whole ad flow before uploading anything.

## Upload to itch.io

Below that is **Upload to itch.io**. It uses [butler](https://itch.io/docs/butler/), the official upload tool from itch.io – and it works for all your export presets, not only web.

1. Type your page as `user/game` (or paste the link, `https://user.itch.io/game` works too).
2. Tick the presets you want to upload. Every preset gets its own channel: `html5`, `windows`, `linux`, `mac`, `android`. itch.io tags downloads by the channel name, so keep those words in there.
3. No butler yet? Click **Download butler**, Greenlight gets it from itch.io (about 15 MB, into the Godot editor data folder). If you have the itch app installed or butler in your PATH, Greenlight uses that one.
4. Click **Log in** once. Your browser opens the itch.io login, butler saves the key itself. Greenlight never sees it. (On Linux/macOS butler wants a real terminal for that, Greenlight puts the command into your clipboard.)
5. **Export & upload** exports every ticked preset into `build/itch/<channel>/` and pushes it, one after the other. If you set a version in Project Settings › Application › Config › Version, itch.io shows it. Uploads with no changes are skipped. If an export fails you see Godots reason right in the dock (missing export templates and so on).

For web there is one thing to do once per page on the website: **Edit game** → *Kind of project* = HTML, and tick *This file will be played in the browser* at the upload. Windows/Linux/Mac/Android downloads show up by themselves. macOS gets uploaded as .zip, butler unpacks it.

## Click to start

Browsers dont play any audio before the player clicked something. So in your main scene:

```gdscript
func _ready() -> void:
	await WebToolkit.wait_for_start()   # you can pass your own text
	$Music.play()
```

In the browser you get a simple start screen ("Click to start" in the players language), in the editor it just continues. Want to see it in the editor? Set `WebToolkit.force_click_to_start = true` before.

## Portal stuff: CrazyGames

One API for ads and game events. The CrazyGames SDK (v3) is loaded at runtime, you dont have to touch the html.

```gdscript
func _ready() -> void:
	await WebToolkit.wait_for_start()
	WebToolkit.gameplay_start()

func _on_level_finished() -> void:
	WebToolkit.gameplay_stop()
	await WebToolkit.show_midgame_ad()      # game is paused + muted meanwhile
	WebToolkit.gameplay_start()

func _on_extra_life_pressed() -> void:
	if await WebToolkit.show_rewarded_ad():
		lives += 1                           # only if the ad was watched till the end
```

**What it handles for you**

- Player switches the tab or minimizes the browser? Game gets paused and muted, and comes back when the tab is visible again. Portals want that and its easy to forget. Works everywhere in the browser, not only on CrazyGames. Project Settings → Greenlight → Web → When Tab Hidden: `pause_and_mute` (default), `mute` or `off`.
- During ads the game is paused (`get_tree().paused`) and the Master bus is muted. Afterwards everything is back like before.
- If the player turns the sound off on CrazyGames, your game stays muted. Also after an ad.
- If the SDK doesnt answer, the game continues after 90 seconds anyway.
- Adblock or no ad available? You get `false` and the game just continues. CrazyGames wants games to work with adblock anyway.

**Which portal is used** – Project Settings → Greenlight → Portal:

| Setting | What happens |
| --- | --- |
| `auto` (default) | CrazyGames SDK only on CrazyGames, nothing elsewhere (itch.io etc) |
| `crazygames` | always load the CrazyGames SDK |
| `none` | no portal at all |
| Simulate Outside Browser (on) | fake 2 second test ad in the editor/on desktop |

Testing in the browser: easiest is **Test in browser** in the dock with CrazyGames test ads ticked. By hand: open your game with `?useLocalSdk=true` at the end of the url, then the CrazyGames SDK shows test ads.

## API

| Call | What for |
| --- | --- |
| `WebToolkit.is_web()` | `true` in the browser |
| `await WebToolkit.wait_for_start(text)` | waits for the first click/tap |
| `WebToolkit.is_started` / `started` | already started? / signal after the start |
| `WebToolkit.gameplay_start()` / `gameplay_stop()` | playing / pause, menu, level end |
| `WebToolkit.loading_start()` / `loading_stop()` | loading / done loading |
| `WebToolkit.happytime()` | big moment (dont overuse it) |
| `await WebToolkit.show_midgame_ad()` | ad between levels, `true` if shown |
| `await WebToolkit.show_rewarded_ad()` | rewarded ad, `true` = give the reward |
| `await WebToolkit.has_adblock()` | adblock on? |
| `WebToolkit.get_portal_name()` | `"crazygames"`, `"simulation"` or `"none"` |
| `await WebToolkit.wait_for_portal()` | wait for the SDK (you rarely need this) |
| `WebToolkit.is_tab_hidden` | player is in another tab right now |
| Signals `ad_started(kind)`, `ad_finished(kind, success)`, `portal_mute_changed(muted)`, `portal_ready(name)`, `tab_visibility_changed(hidden)` | if you want to react yourself |

Portal calls are safe everywhere, without a portal they just do nothing.

## Demo

Open `addons/web_export_toolkit/demo/demo.tscn` and run it. Buttons for both ad types, happytime and the adblock check. The spinning square stops during ads so you can see the pause works.

Tested with Godot 4.5, 4.6 and 4.7. Found a bug or missing something? Write me at gdplugin@impact-cores.de or just leave a comment on the itch.io page.

## Updates

Once a day greenlight looks at a small `version.json` on GitHub to see if there is a newer version. No data about you or your project gets sent, its a normal file download (GitHub sees your IP like with any website). If there is an update you get a small green box in the dock with a link to the store. Dont want that? Project Settings → Greenlight → Updates → Check For Updates off.

Source code: https://github.com/impactcores/greenlight

## License

MIT, do whatever you want with it. See `LICENSE`.

Greenlight is not affiliated with CrazyGames. Using CrazyGames and their SDK is subject to their own terms.

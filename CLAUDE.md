# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An Omarchy shell plugin (bar widget) for Plexamp: previous / play-pause / next buttons, a clickable 5-star rating, and a `Title · Artist` label that opens an info popup. It is a single QML file (`BarWidget.qml`) loaded by Omarchy's Quickshell-based bar, described by `manifest.json`. There is no build step, package manager, or test suite.

## Commands

```bash
omarchy plugin validate .                                   # validate manifest.json against the plugin schema
omarchy plugin list                                         # confirm it is discovered
omarchy plugin disable|enable io.github.inxeo.plexamp-simple-player
omarchy bar move io.github.inxeo.plexamp-simple-player --section left
omarchy restart shell                                       # reload the bar after editing
```

## Testing workflow

The live install is a plain copy (not a git checkout or symlink) at `~/.config/omarchy/plugins/io.github.inxeo.plexamp-simple-player/`. It has drifted ahead of this repo before, so diff it against the repo before editing. To test, copy `BarWidget.qml` there. The shell logs "Local plugin changed, reloading" but keeps the cached component, so run `omarchy restart shell` to see changes. Check QML errors with `journalctl --user -o cat | grep plexamp`. Screenshot the bar with `grim -g "x,y wxh" out.png`.

Plexamp must be running (it exposes MPRIS by default). Inspect what it publishes with:

```bash
busctl --user get-property org.mpris.MediaPlayer2.Plexamp /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Metadata
```

## Architecture notes

- `manifest.json` `id` must match `moduleName` in `BarWidget.qml`. Bump `version` when releasing.
- `BarWidget.qml` extends Omarchy's `BarWidget` (`qs.Ui`, source in `/usr/share/omarchy/shell/Ui/`). `Style`, `Color`, `BarIconButton`, `PopupCard`, `Button`, `BorderSurface`, and the `root.bar` API (`vertical`, `barSize`, `fontFamily`, `barForeground`, `showTooltip`/`hideTooltip`) come from the Omarchy shell, not this repo. `/usr/share/omarchy/shell/plugins/services/media/BarWidget.qml` is a useful reference widget.
- Player discovery: scans `Mpris.players` for one whose `dbusName`, `desktopEntry`, or `identity` contains `plexamp`. The widget is visible and sized only while such a player exists.
- Layout: the top-level `Grid` (`row`) is one row on horizontal bars and one column on vertical bars. The buttons and stars use nested `Grid`s that flip the same way; vertically the stars run bottom to top (star 1 at the bottom). The track label (`scrollClip`) swaps width and height when vertical and rotates the `marquee` Text -90° (reads bottom to top) inside it. Children of a `Grid` cannot use anchors; use the Grid's item alignment instead.
- Rating: reads `xesam:userRating` (0.0–1.0) from MPRIS metadata. Plexamp's MPRIS metadata is read-only, so writing runs an external script (`PLEXAMP_RATER_SCRIPT`, default `~/dev/plexamp-controller/rate-track.sh`) that calls the Plex server. The widget keeps an optimistic per-track value until Plexamp refreshes.
- Star glyphs are Material Design Icons codepoints in fixed-width boxes. Font Awesome star codepoints and concatenated glyph strings render badly in this font.
- `IpcHandler` exposes `toggleInfo` on target `io.github.inxeo.plexamp-simple-player` to open the info popup.

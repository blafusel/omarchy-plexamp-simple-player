# Plexamp

A compact Omarchy bar widget for [Plexamp](https://www.plex.tv/plexamp/): previous, play/pause, next, and a looping marquee of the current track.

The controls only appear while Plexamp is running. Track title and artist scroll as a continuous ticker, so long names come back in from the right instead of jumping.

Made with [Grok Build](https://x.ai/).

![Plexamp widget on the Omarchy bar](preview.png)

## Requirements

- [Omarchy](https://omarchy.org/) (Quattro / shell plugins)
- Plexamp playing through MPRIS (the desktop app does this by default)

No extra packages or API keys.

## Install

```bash
omarchy plugin add https://github.com/Inxeo/omarchy-plexamp.git --enable
```

The widget defaults to the **left** side of the bar. To move it:

```bash
omarchy bar move io.github.inxeo.plexamp --section left
```

## Remove

```bash
omarchy plugin remove io.github.inxeo.plexamp
```

To disable it but keep the files:

```bash
omarchy plugin disable io.github.inxeo.plexamp
```

## How it works

The widget talks to Plexamp over MPRIS (`playerctl`-style desktop media controls). It looks for a player whose D-Bus name, desktop entry, or identity contains `plexamp`, then:

- **Previous / play-pause / next** call that player directly
- **Marquee** shows `Title · Artist` and loops the string when it is wider than the bar slot
- **Tooltip** on hover shows the full `Title — Artist`

## License

MIT. See [LICENSE](LICENSE).

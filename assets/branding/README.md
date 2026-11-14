# Branding artwork

The user supplied these two images for the companion's identity. The source PNGs
are preserved byte-for-byte; no OpenAI logo is incorporated by this integration.

| Repository source | Supplied filename | SHA-256 |
| --- | --- | --- |
| `codex-project-router.png` | `Navy Folder Branching Arrows Icon.png` | `dce0a2d6e486622ed741b902eb3c43d71f2b5d685d24aa82726d6ca40725723b` |
| `menu-bar-source.png` | `Folder Routing Branch Icon.png` | `71343bcb526218ab25a0a9f06a525f5986b68a34d8cecd556874f978a9561d1d` |

From the repository root on macOS, regenerate the committed app resources with:

```sh
swift scripts/generate-companion-icons.swift
```

The script uses AppKit/ImageIO and `/usr/bin/iconutil`; it needs no Python, image
package, network access, or Downloads files. It writes:

- `companion/Resources/AppIcon.icns`: standard 16–1024-pixel representations.
- `companion/Resources/CompanionIcon.png`: the unchanged navy source, used in the header.
- `companion/Resources/MenuBarIconTemplate.tiff`: cropped artwork fitted proportionally
  within a 26 × 18-point canvas with transparent margins and 1×/2× representations.
  Bounds ignore barely visible alpha noise (below 16/255), with one source-pixel
  guard for antialiased edges; the visible shape and source files are preserved.

Ordinary app builds copy these committed resources without regenerating them.
The menu image is a macOS template; the navy artwork retains its colors. The
README uses the navy source directly. Updating artwork requires regenerating,
rebuilding, and checking the packaged resources and their small-size appearance.

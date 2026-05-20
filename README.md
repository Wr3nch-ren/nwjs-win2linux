# nwjs-win2linux

Convert Windows NW.js games/apps to run natively on Linux.

## How it works

Windows NW.js apps bundle the game files (`package.json`, `www/`, etc.) alongside the Windows NW.js runtime (`.exe`, `.dll`s). This script replaces the Windows runtime with a Linux NW.js runtime while preserving the game assets.

```
Windows app                    Linux app
┌────────────────────┐         ┌──────────────────────┐
│  Game.exe          │  ──→   │  nw (ELF binary)     │
│  nw.dll            │  ──→   │  lib/libnw.so        │
│  node.dll          │  ──→   │  lib/libnode.so      │
│  ffmpeg.dll        │  ──→   │  lib/libffmpeg.so    │
│  d3dcompiler_47.dll│  ✂──   │  (not needed)        │
│  www/              │  ──→   │  www/                │
│  package.json      │  ──→   │  package.json        │
└────────────────────┘         └──────────────────────┘
```

## Requirements

- Linux (any distro)
- `rsync` (preinstalled on most distro)
- A base Linux NW.js runtime (e.g. from [nwjs.io](https://nwjs.io))
- Optional: `jq` for cleaner `package.json` updates

## Setup

1. Download the **Linux x64** NW.js runtime from [nwjs.io](https://nwjs.io)
2. Extract it to `~/Downloads/nwjs-v<version>-linux-x64/`

The script looks for the base runtime at `~/Downloads/nwjs-v0.110.1-linux-x64/` by default. Pass a different path as the third argument if needed.

## Usage

```bash
# Interactive mode — scans ~/Downloads for Windows NW.js apps
./convert-nwjs.sh

# Direct mode — convert a specific app
./convert-nwjs.sh ~/Downloads/SomeApp/

# Custom download dir and base runtime
./convert-nwjs.sh ~/Downloads/SomeApp/ ~/Downloads ~/nwjs/sdk-v0.120.0-linux-x64
```

Output goes to `~/Downloads/nwjs-<normalized-name>/`.

### Detection

The script identifies Windows NW.js apps by looking for:
- `nw.dll` or `nw_elf.dll` (Windows NW.js runtime marker)
- Any `.exe` file in the same directory

## How to run a converted app

```bash
cd ~/Downloads/nwjs-my-game/
./nw
```

Or create a `.desktop` entry pointing to the `nw` binary.

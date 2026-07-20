# Introduction
Arcadey FPS inspired by modern 2D platformers.
- [Roadmap](doc/roadmap.md)
- [Odin_Reference](doc/odin.md)

# Quickstart
```bash
# Win11
.\script\run.bat
# Linux
./script/run.sh
```

# Toolchain
- Odin: dev-2026-07-nightly:819fdc7
- raylib: vendor:raylib 6.0
- Box3D: vendor:box3d bundled with Odin
- Primary platform: Windows 11 x86-64
- Asset authoring: Blender

# Folder Structure
src/
├── main/
│   └── main.odin
├── world/
│   ├── gamestate.odin
│   ├── menu.odin
│   ├── level.odin
│   └── hud.odin
├── player/
│   ├── player.odin
│   └── camera.odin
├── gameplay/
│   ├── aiming.odin
│   ├── gun.odin (merge weapon/projectile into it)
│   ├── flashfield.odin
│   └── zap.odin
└── npc/
    └── enemy.odin


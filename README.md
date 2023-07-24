# Dynamic Layouts System: A Don't Starve Together modification empowering modders with in-game setpiece tools. 

## Overview

This mod and the systems it contains allows you to create setpieces in-game, procedurally generated dungeons, spawn and revert setpieces, and more!

## How to use
### Creating setpieces:
To create setpieces, simply build, spawn in and project what you want in-game, then spawn in the `dl_recorder` prefab.
To save tiles, give yourself some `dl_tileflag`s and place them on the tiles you wish to save.
To increase the range of capturing, insert logs or boards into the spawner. Logs increase range by 1 unit (1/4 of a tile), Boards increase it by 1 tile.

After that, write the name of the setpiece you want on the `dl_recorder` prefab and right click on it, the saved data will be stored in `%MODROOT%/scripts/capture_output.json`

### Spawning in setpieces:
For testing pourposes, you can spawn setpieces inside the capture_output.json folder by simply writing the name of the setpiece in the spawner prefab (`dl_spawner`) and right clicking it.
For setpieces outside of the output folder, you may define a custom path, as the third argument of the [SpawnLayout function](https://github.com/AtobaAzul/dst-dynamic-layouts/blob/307f0d64a3f17e4a0f4d78dcde5f43d86e49cc81/scripts/prefabs/dl_prefabs.lua#L278-L434C1) or as a variable in the spawner itself (`spawner.file_path_override`)

### Setpiece options:
These are automatically created in the json, and you can alter them manually to fit your needs.

- `has_tiles`: Set automatically to `true` if a setpiece has a tileflag, I advise not changing it. Locks setpiece rotation to multiples of 90° (default: `false`)
- `spawn_in_water`: Set automatically to `true` if a setpiece has a tileflag. Allows the layout to spawn prefabs and tiles on water. (default: `false`)
- `only_spawn_in_water`: Prevents prefabs and tiles from spawning on land. (default: `false`)
- `smooth_rotate`: Allows the setpiece to rotate on a random angle between 0° and 360°. If `false`, and `has_tiles` also is false, setpiece rotation happens on multiples of 45° (default: `false`)
- `no_rotation`: Prevents the setpiece from rotating. (default: `false`)
- `use_angle_away_from_spawn`: Rotates any spawners spawned by this setpiece away from the this setpiece's spawner. (default: `false`)
  - `angle_offset`: The angle offset that gets added to the angle away from the setpiece, in degrees. (default: `0`)
- `prevent_overlap`: Prevents the setpiece from creating if a `dl_blocker` prefab is found next to it. (default: `true`)
- `reversible`: Governs whether the setpiece's data will be stored for reverting later. Additionally, allows the setpiece to remove prefabs on it's way. (default: `false`)
- `group`: Used for grouping setpieces for reverting, and spawning setpieces.. (default: `nil`)
- `worldborder_buffer`: Controls how close the setpiece can spawn it's prefabs and tiles to the world's border. (default: `0`)
- `autotrigger_spawners`: Controls if the setpiece will automatically spawn other setpieces. if `false`, spawners listen for the `spawn_dl_%group%` event to spawn. (default: `true`)

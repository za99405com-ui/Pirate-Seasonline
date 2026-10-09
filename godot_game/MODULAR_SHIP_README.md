# Modular Pirate Ship — Levels 1–3 (Godot 4.3)

This branch **replaces the active legacy player-ship scene** with a small modular ship and a self-contained starboard anchor rig. The rest of the game (world, islands, HUD, enemy ships, loot, and `Legacy_Android`) is preserved.

## Level 1

- One Level 1 wooden hull, no side-by-side overlapping legacy geometry.
- Main sail mounted on the hull. It opens/closes over time.
- Visible steering wheel.
- One *low* cannon on the port (left) side, one on starboard (right).
- One anchor and fixed holder on starboard, forward of the cannon, around the middle of the ship's front half.
- Dynamic rope: it updates from the holder to the anchor on each physics frame; not a static GLB rope.
- Three-dimensional anchor model lowers to `sea_floor_y`, stays at a world position, and rises again.
- When set, turning the helm rotates the **ship's world position** around the anchored seabed point — not just the ship mesh.

## Upgrades (same hull)

- Level 2: decorative sail seams/cuts, speed 11.5 (from 10).
- Level 3: subtle hull reinforcement, speed 12.5, travel ×1.5.

## Asset paths

This PR contains the *integration code and temporary procedural fallback visuals*, but **does not contain the user-supplied GLB binary files yet**. To see the final optimized assets in the GitHub build, add these exact files:

| Required GitHub path | User's optimized asset |
| --- | --- |
| `godot_game/assets/models/Pirate_Boat_A_Level1_Mobile_2048.glb` | `Pirate_Boat_A_Level1_Mobile_2048.glb` |
| `godot_game/assets/models/Anchor_Mobile_2048.glb` | `Anchor_Mobile_2048.glb` |
| `godot_game/assets/models/Anchor_Holder_Mobile_2048.glb` | `Anchor_Holder_Mobile_2048.glb` |

The engine will load those `.glb` models automatically when present. If absent, a visible procedural placeholder is rendered instead, so CI can validate code independently. The GLB scale and orientation will need visual calibration in Godot after import.

Do **not** import an animated 3D rope: `anchor_rig.gd` creates a low-cost flexible endpoint-to-endpoint cylindrical rope.

## Active files

- `scenes/player/player_ship.tscn`: lean scene (player, hull visuals, anchor rig)
- `scripts/player/player_ship.gd`: controls, levels, anchor orbit gameplay
- `scripts/player/modular_ship_visuals.gd`: hull, mast, sail, steering, cannons, visual level upgrades
- `scripts/player/anchor_rig.gd`: movable anchor, fixed hull bracket, world-space rope
- `scripts/data/ship_progression_data.gd`: Level 1–3 stats
- `scripts/ui/hud.gd`: sailing controls and level feedback

## Controls

- Right: SAIL OPEN / CLOSED
- Right: ANCHOR READY / DROPPING / SET
- Left: helm wheel, turn the ship. With a set anchor and open sail, the hull orbits the anchor position.
- Camera: drag to orbit view.

## Testing notes

Test mobile framerate with the real 49K-triangle hull and optimized anchor textures once uploaded. Current `sea_floor_y=-3.5` is a flat seabed approximation. Rope simulation is a cheap straight segment with length updated continuously, *not* full soft-body physics. The rotation is a deliberate gameplay mechanic, not a physically exact mooring simulation.

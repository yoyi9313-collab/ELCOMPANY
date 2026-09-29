# Soldier assets

Copied from the user's local packages; the originals remain in the parent workspace.

- `american/*.fbx`: current Allied character from the user's `americano.zip`, with its own textures and walking clip. Used by Rangers, Rifle Squad and U.S. Machine Gun Team. Shared animation retargeting supplies aim, fire, hit and throw poses, cached independently from the German rig. Weapons and ammunition cases are cosmetic role-specific placeholders (Thompson, Garand, BAR, Carbine and M1919); squad weapon stats are unchanged.
- `us/soldado_ww2.glb`: previous ToonSoldiers WW2 demo by PolygonBlacksmith, retained as an original source asset but no longer instantiated.
- `grenadier/*.fbx`: replacement Meshy grenadier from the user's `NAZI.zip`, including the original textured character and native running clip.
- `../weapons/kar98/*.fbx`: textured rifle from the user's `KAR98.zip`, used by every Kar98k rifleman in both German squads. The MP40 leader and MG42 gunner retain their role-specific placeholder weapons.
- `german/*.fbx`: Basic Shooter Pack remains the source of aim, fire, hit and throw animation clips. Its old GermanCombat mesh is no longer instantiated.

`scripts/german_visual_assets.gd` maps the former Mixamo rig onto the replacement's 24-bone skeleton, including its different spine order and Z-up coordinates. It generates a shared animation library once. Native running retains the new asset's lower-body motion with an upper-body rifle hold; all clips lock horizontal root travel, and aim/fire restore the standing root position. The replacement supplies its own helmet, equipment and textures. The Kar98 is scaled to approximately 1.11 m, positioned between the hands, and follows their movement. Source FBXs and texture files are preserved.

`scripts/soldier_visual.gd` renders cosmetic models into transparent viewports, then the existing battlefield draws those textures in the same depth order as cover. Root travel is removed from copied animations so grid movement remains authoritative. Feet are grounded after animation updates and viewport ground is projected onto the formation anchor. Fallen members use hit/fall/fade visuals, never separate health or controls.

Disable `imported_soldier_visuals` on the battlefield to use the previous procedural artwork. Headless tactical tests use that fallback; `tests/soldier_assets_test.gd` explicitly tests both imported rigs and animation states.

# Operation Hedgerow

A self-contained WWII-inspired isometric squad tactics demo for Godot 4.7. Open project.godot and press **F5**, or open scenes/battlefield.tscn and press **F6**. The battlefield is procedural. Allied squads use the supplied americano character and native walking; German squads use the replacement character from NAZI with KAR98 rifles for riflemen and native running. Both share adapted Basic Shooter combat animations. The assets are included in the project; no plugin is required. See `assets/soldiers/README.md` for animation mapping and equipment details.

## Mission: Secure the Hedgerow

### Playable demo flow

The demo opens with **START MISSION**, followed by Allied deployment. Select each squad in the deployment roster (or on the map), then click a free highlighted tile in **B8–F10** to confirm its position. Cover and other squads block placement. All three squads must be confirmed before **BEGIN BATTLE** becomes available; confirmed squads can still be repositioned without spending AP. German deployment remains fixed. Restart returns to the introduction and restores all squad resources.

Allied and German phases have brief, nonblocking banners. Objective state changes and capture gains appear as queued notifications so movement cannot immediately overwrite a capture message. The result panel reports victory/defeat, turns used, surviving Allied squads, health-derived Allied casualties and destroyed German squads.

Combat presentation includes directional muzzle flashes, short MG bursts, dust/chip impacts, nonlethal hit reactions and visibly lower SUPPRESSED/PINNED postures. Small camera offsets accompany MG fire, grenades and casualties without moving the HUD or pausing control. Set `camera_feedback_strength` to zero to disable them. These effects never consume combat RNG, AP or health.

There are no audio files in the supplied project. Optional `audio_cues` on the battlefield accept local AudioStreams under `rifle`, `machine_gun`, `grenade`, `move`, and `ui`. The feedback node also emits `audio_cue` for future routing. Empty hooks remain silent; no external sounds were downloaded.

The 10×10 cover layout is retained after reviewing two distinct approaches: **D8 → D7 → D6 → E6** reaches the western objective around light crate cover, while **F8 → G8 → G7 → G6 → F6** approaches from the east beside the H7 sandbags. Crates interrupt the MG42's LOS to the western approach. Both paths remain traversable and offer cover; the east route is slightly longer but offers heavy cover on the approach. `vertical_slice_test.gd` checks these routes, setup flow, phase transitions, notifications and result summaries. `mission_start_flow = false` bypasses setup for focused battle tests; normal play leaves it enabled.

The playable mission is **SECURE THE HEDGEROW**. Capture the central 2×2 zone at **E5, F5, E6 and F6**. Its outlines are muted when neutral, green under Allied control and amber when contested. Status follows living occupants: Allies alone mean ALLIED CONTROL, both factions mean CONTESTED, otherwise NEUTRAL. German-only occupation denies capture without creating a separate German capture meter.

Press **NEXT TURN** to close the entire Allied phase. If at least one living Ally occupies the zone and no German does, gain exactly one Capture Point, regardless of squad count or unused AP. Two points win immediately before the Germans act. Points are cumulative and are not lost when the zone is vacated or contested; those phases simply add nothing. Entering a tile or spending all AP does not score until NEXT TURN.

Each numbered turn includes the Allied and German phases. If capture has not succeeded by the **end of the German phase of Turn 8**, the Allies lose; no Turn 9 begins. Securing the zone at the end of Allied Turn 8 still wins. Eliminating every opposing squad also ends the mission. Results lock tactical actions and show the outcome, reason, turn and capture score. **RESTART MISSION / R** restores all five squads and starts at Turn 1, neutral, 0/2.

Grenadiers prioritize advancing into an available objective tile to contest, then hold and fire. MG42 prefers covered positions outside the zone with LOS and range over it, retaining a useful stationary firing position instead of rushing in. Combat, occupancy, AP, LOS, suppression and reactions still constrain these movements. The mission uses `mission_state.gd` for capture and outcomes, plus the shared AI planner for objective routes. `mission_enabled` defaults to true; older focused combat tests disable only the mission layer to keep their isolated scenarios meaningful. There are no reinforcements, extra objectives or campaign progression.

## Controls and Action Points

- **Left click any Allied soldier or its tile:** select that whole squad. Switch between Rangers, Rifle Squad and Machine Gun Team during the Allied phase.
- **Hover a highlighted tile:** preview the route and its **1 AP** cost.
- **Click a highlighted tile:** move, spending **1 AP** regardless of distance.
- **Hover / click either German squad:** inspect / lock that target, then use **FIRE [1 AP]**. The enemy panel follows the targeted squad.
- **OVERWATCH [1 AP]:** reserve one reaction shot during enemy movement. Hover or keyboard-focus the button to preview its range.
- **Space / NEXT TURN:** end the entire Allied phase, including unused AP on all three Allied squads, and run the enemy turn.
- **Q/E or the rotate buttons:** turn the selected squad by 45 degrees for free.
- **F3:** toggle the optional LOS debug line for the selected squad and current enemy target. Green means clear; red means blocked. Disabled by default, also configurable with the scene's `show_los_debug` property.
- **Right click a different battlefield tile:** face that tile for free. **Escape:** deselect.
- **R / RESET EXERCISE:** restore the initial battlefield, all three Allied squads, Grenadiers and MG42 Team.

Every squad begins its turn with **2 AP**. Each move action allows up to **4 tiles** along an orthogonal path, except the MG Team's **2 tiles**. A second move gets a fresh allowance; moving fewer tiles still costs one AP. Valid action orders include move + fire, fire + move, and move + move. Every current squad has a **one-attack-per-turn limit**, so a second shot is blocked even if AP remains. Misses spend the firing action. Invalid orders spend nothing.

Allied squads independently track AP, health, casualties, facing, suppression, grenades, attacks and Overwatch. At the next Allied phase, every surviving ally resets its turn state. Selecting a squad never resets it. The bottom panel follows selection, and two small dots above each friendly show remaining AP. Squads with zero AP remain selectable for inspection. If one Allied squad is destroyed, the survivors can continue fighting. Grenades reset only with a fresh battle.

The **U.S. Rifle Squad** has five visual members: a leader with M1 Carbine, three M1 Garand riflemen and one BAR gunner. It has **450 HP, 4-tile attack/Overwatch range, 80% exposed / 55% frontal covered accuracy and 70–95 damage**. It shares movement, the 120-degree firing arc, one grenade, suppression and all other actions with the Rangers. Rifle casualties use the shared proportional health thresholds (one visual member per 90 HP). Rangers keep their 400 HP, 3-tile range, 85% / 60% accuracy and 80–110 damage. Profiles configure the same SquadData class rather than separate gameplay controllers.

The HUD shows **ACTION POINTS: ● ●**, **● ○**, or **○ ○**. At zero AP, movement highlighting and firing are unavailable; NEXT TURN remains available. Player controls are locked while a movement/volley resolves or during the enemy turn.

## Combat and cover

The **U.S. Machine Gun Team** is a 320-HP, three-member SUPPORT / SUPPRESSION unit with a Browning M1919 gunner, assistant and ammunition bearer. Its profile shares the same squad, action, targeting and casualty code. It has no grenade inventory or grenade controls. Base fire is **range 5, 75% exposed / 50% frontal cover accuracy, 55–75 damage**. A hit applies **2 suppression** and a valid in-range miss applies **1**, for both normal fire and Overwatch. Suppression still caps at 2. Overwatch has only a **5-point accuracy penalty** and still uses one prepaid attack and the frontal arc.

At the start of its own turn, the MG is **DEPLOYED**: +10 accuracy points and +1 normal/Overwatch range. That gives range 6, normal accuracy 85% / 60%, and Overwatch accuracy 80% / 55% before suppression/flanking. Any valid move changes it to **MOVED** and removes both bonuses until the next Allied phase; invalid moves, facing changes and selecting another squad do not affect deployment. Its two-tile movement drops to one or zero under suppression. Incoming firearm damage is multiplied by **1.10 from a flank** or **1.20 from the rear**, rounded to whole HP, on top of existing directional cover rules. Grenades retain their nondirectional blast rules. Visual strength is **214–320 HP: 3; 107–213: 2; 1–106: 1; 0: destroyed**.

Every squad has a normalized facing direction in grid space, shown by a small ground arrow. Each movement segment turns the squad toward its direction of travel, so it finishes facing the last step. Infantry has a **120-degree frontal firing arc** (±60 degrees). A selected squad shows a subtle arc preview, and targets outside it are marked **OUT OF ARC**. Rotating costs no AP and works even at zero AP, but is locked during movement, firing and the enemy turn. The AI follows its travel direction and freely turns toward its existing target before firing; it does not seek flanking routes.

Target direction is measured from the defender's facing: **FRONT** is its frontal 120-degree sector, **REAR** is a 60-degree cone centered directly behind it, and the remaining side sectors are **FLANK**. Cover's normal 25-point accuracy penalty becomes **12.5 points from a flank** and **0 from the rear**. For unsuppressed Rangers this gives 60% / 72.5% / 85% against covered targets. Exposed targets gain no extra bonus. Targeting and floating feedback show **FLANKED** or **REAR ATTACK**. The probability roll supports fractional percentages. Cover and suppression modifiers apply to both factions and reaction shots.

Sandbags, crates and every other living squad's tile block movement for both factions. An orthogonally adjacent sandbag or crate provides cover; squad bodies do not. Attack range uses Manhattan distance, independently of path length: **3 grid steps for Rangers/Grenadiers, 4 for Rifle Squad, 5–6 for MG Team**. The target panel shows the selected squad's range, hit chance, cover and blocking reasons.

| Squad | Open / covered target accuracy | Damage per hit |
| --- | --- | --- |
| U.S. Rangers | 85% / 60% | 80–110 |
| U.S. Rifle Squad | 80% / 55% | 70–95 |
| U.S. Machine Gun Team (moved / deployed) | 75% / 50% · 85% / 60% | 55–75 |
| Grenadiers | 80% / 55% | 70–100 |
| MG42 Team (moved / deployed) | 80% / 55% · 90% / 65% | 60–80 |

Each volley has **one squad-level hit roll and one damage roll**. Every living member can produce a cosmetic muzzle flash and trace, but there is no per-member accuracy or HP. Damage, MISS and suppression states appear as floating combat text. Normal fire requires range, frontal arc and clear line of sight before spending AP; the shared damage resolver checks LOS too. Projectile visuals remain placeholders.

## Line of sight and terrain

All units share `line_of_sight.gd`, which traces between logical grid-tile centers using integer supercover traversal. Intermediate crates block LOS completely; sandbags provide heavy cover without blocking LOS. At exact diagonal corners both touching cells are checked, preventing shots through blocked corners. The trace is reciprocal and ignores the attacker's and target's endpoint tiles. Other squad bodies do not block vision, and visual member offsets never affect LOS.

The target panel separately shows RANGE, ARC, LOS and COVER (NONE/LIGHT/HEAVY), plus hit chance and attack direction. **NO LINE OF SIGHT** disables FIRE without spending AP, rolling accuracy, dealing damage or applying suppression. Overwatch checks LOS on each entered movement tile before consuming its reaction. A hidden target can cross into a visible tile and trigger there; blocked attempts leave Overwatch ready.

Both enemy types use the same LOS rules when selecting shots and choosing movement destinations. A visible in-range target outranks a hidden target. Within reachable positions, useful covered firing tiles are preferred, with exposed firing tiles as a fallback; clear LOS is required for a firing position. AI still rotates freely to face its chosen target before shooting. Grenades retain their arcing tile-targeted behavior and do not require weapon LOS.

`terrain_rules.gd` defines reusable `blocks_los`, `blocks_movement`, `provides_cover` and `cover_strength` properties. Cover strength is 0/1/2 for none/light/heavy. The battlefield stores these dictionaries; legacy string fixtures are still accepted. Movement, cover, grenade protection and LOS read the same properties. Future wall/building definitions can use this schema without changing ray tracing. No buildings, smoke, elevation or destructible terrain have been added.

## Suppression

Suppression points now name tactical states: **0 = NORMAL**, **1 = SUPPRESSED**, **2 = PINNED**. SUPPRESSED loses one movement tile. PINNED loses two movement tiles and 15 accuracy points, cannot activate or fire Overwatch, and receives no DEPLOYED / SET UP accuracy or range bonus. Becoming pinned immediately cancels an existing Overwatch without refunding its AP; the cancelled shot is not counted as fired. The MG's hit/miss suppression remains 2/1.

A **PINNED squad currently in cover** imposes an additional **−10 accuracy points** on incoming ranged attacks, including Overwatch. This is separate from normal cover: it stacks with the front/flank/rear cover calculations, including rear attacks that ignore the normal cover penalty. Exposed pinned squads receive no defensive bonus. Grenade damage remains governed by blast cover reductions, without an accuracy roll.

Suppression persists throughout the affected squad's next full own phase and clears at its end. New suppression refreshes this duration even at the two-point cap. Suppression received during the squad's own phase lasts through the following own phase too. Selecting another unit or beginning either phase does not clear it. World labels show SUPPRESSED in gold and PINNED as a larger red badge. Detailed panels include the state and numeric value, with a duration indicator distinguishing ACTIVE THIS PHASE from ACTIVE + NEXT OWN PHASE. Pinned MGs remain unable to deploy throughout the affected phase.

A successful ranged hit normally applies **1 suppression point**; MG attacks apply 2 on a hit and 1 on a miss. The cap remains 2. Each suppression point reduces movement allowance by one tile (minimum zero); at level 2, the shooter's accuracy also loses **15 percentage points**. Suppression never spends AP. Cover penalties do not stack. Each squad restores 2 AP and its attack allowance at the start of its own turn, independently of suppression recovery.

## Overwatch

OVERWATCH costs 1 AP on activation. It stays active until firing, squad destruction, or the start of that squad's next turn. While the hostile squad moves, each entered tile is checked against **both range and the frontal firing arc**. A valid entry pauses movement for one automatic volley. Movement behind the watcher never triggers a shot. A surviving enemy continues; a destroyed enemy stops at the casualty tile. Stationary enemies do not trigger it. The AI makes the same decisions as before and does not avoid watched tiles. The cyan preview shows only the watched arc; free rotation before the enemy turn changes that arc.

Rangers use **70% against exposed targets / 45% against cover**, with the existing shooter suppression penalty on top. Damage, suppression and casualties use the normal squad-level resolver. There is no additional AP cost when the reaction fires, even at zero AP, and a miss also consumes the single reaction. OVERWATCH status and OVERWATCH FIRE feedback accompany the existing shot visuals.

Activation reserves an available attack slot. Current squads permit one attack per turn, so MOVE + OVERWATCH works, while FIRE + OVERWATCH does not. A future profile with max_attacks_per_turn of 2 can permit FIRE + OVERWATCH. Double activation and repeated reactions are blocked. SquadData owns the state, overwatch_range and overwatch_accuracy_penalty, allowing future teams to change range or accuracy without replacing the movement-trigger integration.

## Enemy turn behavior

NEXT TURN displays **ENEMY TURN**, resets all surviving Germans at the start of their phase, and runs Grenadiers followed by MG42 Team. The Grenadiers retain their original nearest-target behavior (Allied roster order resolves ties), independently of player selection. In range, they fire and end their turn. Otherwise they prefer reachable cover advancing toward firing range; without useful cover, breadth-first search finds the shortest valid approach. Fixed neighbor order resolves ties deterministically. Paths block all other living squads without treating their bodies as cover. After moving, Grenadiers fire if they have range, AP, and an unused attack; otherwise they can spend their second AP on another move. All Allied squads check Overwatch on every entered enemy tile, resolving in roster order and stopping if the mover dies.

The **MG42 TEAM** is a three-member, 300-HP **HEAVY SUPPORT / SUPPRESSION** squad: MG42 gunner, assistant and ammunition bearer/rifleman. It starts at G4 beside existing sandbags, separated from the Grenadiers. Its shared profile gives 2 AP, movement 2, base range 5, damage 60–80, accuracy 80% exposed / 55% frontal cover, and no grenade. Stationary setup adds 10 accuracy points and one range; a move removes both for the rest of its turn. Hits apply 2 suppression, misses 1. PINNED cancels setup and Overwatch just as for other squads. Its proportional casualties show 3 members at 201–300 HP, 2 at 101–200, and 1 at 1–100.

MG42 AI prioritizes valid firing lanes, then exposed targets, lower suppression and shorter distance. It stays stationary when it can shoot, preserving deployment and current cover. Without a shot it moves up to two tiles toward a useful covered firing lane, using the post-move range of five. It then fires if possible; otherwise it spends its remaining AP on Overwatch and faces the approach. Blocked units may set Overwatch without moving. The support role is data-driven and uses the shared AI planner and squad actions.

MG42 Overwatch costs 1 AP and uses only a 5-point accuracy penalty (85% exposed / 60% frontal cover while deployed, before other modifiers). Allied movement now resolves each entered tile against hostile watchers as well. A stored reaction fires at most once, never once per member or per crossed tile, and obeys the existing one-attack-per-turn cap. It does not rearm on a second movement command. Suppression can shorten the remaining route; lethal reactions stop movement safely. Enemy Overwatch survives the Allied phase and expires at the next German phase. Frontal arcs, PINNED cancellation and suppression-on-hit/miss use the shared resolver.

Movement and firing have short readable pauses. Blocked or destroyed enemies safely pass. After both Germans finish, the next Allied phase begins automatically with 2 AP per survivor. Destroyed squads cannot act, while Reset remains available after the enemy turn. Active AI flank planning, AI grenades and morale are not included.

## Grenade

Select the Rangers, press **GRENADE [1 AP]**, hover a grid tile to preview the blast, then click to throw. Escape, right-click or the cancel button cancels without spending anything. Gold tiles show the 2-step Manhattan throwing range; red tiles show the target and its four orthogonal neighbors. Empty, occupied, cover and the squad's own tiles are valid targets. Firing arcs do not restrict grenades. The blast can extend beyond throwing range and affects allies too.

Each battle gives Rangers and Rifle Squad one grenade each at squad level; MG Team has none. A throw spends 1 AP and that squad's grenade immediately; damage occurs at the end of the visible arcing flight. The direct tile takes 170–210 damage and 2 suppression points; adjacent squads take 85–110 damage and 1 point, capped at 2. There is no accuracy roll. Adjacent sandbags count as heavy cover (25% damage reduction); crates count as light cover (10%). The strongest protection applies once, with damage rounded to the nearest whole HP. Facing and flanking do not change blast protection. Squad health drives the same casualty animations and roster indicators as gunfire.

The grenade is independent of the one-firearm-attack limit, allowing FIRE + GRENADE, MOVE + GRENADE or GRENADE + OVERWATCH when AP permits. GRENADE READY changes to GRENADE SPENT; turns do not replenish inventory, while Reset starts a fresh battle. Controls are locked during flight and explosion. The AI has no grenade inventory or grenade actions, and terrain remains intact. `grenade_rules.gd` shares blast geometry and cover rules between preview and resolution; `SquadData` owns inventory and AP spending.

## Squad data, casualties and extension points

Rangers, Rifle Squad, U.S. MG Team, Grenadiers and MG42 Team are each **one logical tactical unit occupying one grid tile**, with four, five, three, four and three visual members respectively. They use the same scripts/squad_data.gd and scripts/squad_member.gd. Individual soldiers cannot be selected or commanded independently. The Rifle and both MG rosters and combat profiles are configured in scripts/squad_profiles.gd; shared actions read squad data.

For the current 400-HP squads, visible strength is **301–400 HP → 4**, **201–300 → 3**, **101–200 → 2**, **1–100 → 1**, **0 → destroyed**. Health changes alone drive casualties. Dead members immediately leave targeting and firing, then fall and fade over 0.75 seconds. Survivors smoothly reform; roster icons dim. Death locations stay fixed if the squad moves. The destroyed unit releases its tile immediately.

SquadData.new(is_enemy, squad_size, display_name, squad_type, total_health, roster) supports future sizes such as Rifle Squad (5), Bazooka Team (2), and Machine Gun Team (3). Roster entries can specify id, role, weapon and facing. Default total health is size × 100, and living count is ceil(health / max_health * roster_size).

The reusable AP ledger is action_costs, can_perform(action) and spend_action(action). begin_turn() resets AP, attacks and overwatch while preserving suppression; end_turn() advances suppression recovery once per own phase. max_attacks_per_turn is 1 for all current squads; a later weapon profile can change that independently of AP. Future actions can register a positive AP cost in the ledger and use the same spending method. Reload and defensive-stance actions are not implemented yet.

SquadData also owns facing, firing_arc_degrees, front_sector_degrees and rear_sector_degrees. face_direction(), face_cell(), in_firing_arc() and incoming_sector() provide shared geometry for normal fire, overwatch and cover modifiers. Future machine gun teams or vehicles can use narrower or wider firing arcs, up to 360 degrees, without replacing these systems.

## Verification

Run each check with: godot --headless --path . --script res://tests/<name>_test.gd

- movement: grid selection, collision, pathfinding and squad movement.
- combat: range, accuracy, damage variance, suppression, elimination and reset.
- casualty: exact health thresholds, animation lifecycle and configurable roster sizes.
- enemy_ai: deterministic cover decisions, routes, input locking and turn recovery.
- action_points: action orders, two full moves, attack caps, invalid orders, suppression, AI budgets and extensible action costs.
- overwatch: AP reservations, movement-trigger reactions, accuracy modifiers, misses, expiry, lethal interrupts and configurable range.
- facing: arc boundaries, free rotation, travel direction, front/flank/rear cover modifiers, OUT OF ARC rejection and rear-overwatch prevention.
- grenade: blast geometry, cover reductions, AP and inventory, arc-independent throws, cancellation, friendly damage, suppression, casualties, animation locking and battle reset.
- multi_squad: click selection, independent resources, friendly occupancy and routes, Rifle combat profile and grenade, multiple Overwatch reactions, Allied phase reset and survival after losing Rangers.
- machine_gun: independent AP, deployment and movement, normal/Overwatch accuracy and range, hit/miss suppression, no grenades, three-member casualties, flank/rear damage and turn/battle resets.
- suppression_states: NORMAL/SUPPRESSED/PINNED, Overwatch cancellation and rejection, deployment loss/recovery, pinned-cover defense and modifier stacking, UI and phase recovery.
- suppression_duration: full-phase persistence, end-of-phase recovery, at-cap refresh during either phase, repeated phase-end safety, duration labels and battle reset for both factions.
- mg42: deployment, target selection/UI, independent enemy occupancy and damage, firing-lane and cover AI, hit/miss suppression, hostile Overwatch through multi-tile movement, lethal interruptions, both-enemy phase flow and reset. Older focused scenarios explicitly retain their original single-Grenadier roster; this suite exercises the full two-enemy roster.
- los: horizontal/vertical/diagonal tracing, reciprocal rays, blocked corners, sandbag transparency, reusable terrain properties, UI and AP rejection, Overwatch retention and visible-tile reactions, LOS-aware AI and the F3 debug toggle.
- mission: capture timing and once-per-phase scoring, contested/vacant zones, dead occupants, final-turn capture, full-turn deadline, elimination outcomes, objective-aware AI, result UI, post-mission action locks and restart.

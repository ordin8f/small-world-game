extends SceneTree
## One-shot generator: wires courtyard, player, camera rig, interaction
## zones, ball, NPC placeholders, UI, and perception into scenes/main.tscn.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_main_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "Main"

	var courtyard_packed: PackedScene = load("res://scenes/courtyard.tscn")
	var courtyard: Node = courtyard_packed.instantiate()
	root.add_child(courtyard)
	courtyard.owner = root

	# M1.3: the real player, positioned at the courtyard's "Start" key point
	# (player.gd's own START_POSITION -- the home porch, 2026-08-28 world
	# expansion). Not script-loaded via load() here -- same reason as
	# player.tscn's own generator: `Game` autoload isn't registered this
	# early in a bare --script run. Since player.tscn already carries its
	# own script reference (attached as a plain ExtResource text edit after
	# generation), instantiating the PackedScene picks that up without
	# needing to load the script here too.
	var player_packed: PackedScene = load("res://scenes/player.tscn")
	var player: Node3D = player_packed.instantiate()
	root.add_child(player)
	player.owner = root
	player.position = Vector3(0.0, 0.0, 10.0)

	# M1.4: the real play camera -- pivot -> SpringArm3D -> Camera3D, driven
	# every physics tick by CameraProfile.profile(player.z). Not script-
	# loaded via load() here, same reason as player.tscn's generator.
	var camera_rig_packed: PackedScene = load("res://scenes/camera_rig.tscn")
	var camera_rig: Node3D = camera_rig_packed.instantiate()
	root.add_child(camera_rig)
	camera_rig.owner = root

	# Gate 0 frame (S0/S1/S6): the title/ending cinematic camera -- its own
	# independent path (title_camera.gd), never touching camera_rig above.
	var title_camera_packed: PackedScene = load("res://scenes/title_camera.tscn")
	var title_camera: Node3D = title_camera_packed.instantiate()
	root.add_child(title_camera)
	title_camera.owner = root

	# M2.2: interaction zones, one per game.mjs:170-188 trigger. Positions
	# match courtyard.tscn's own Marker3D key points exactly (see
	# _bootstrap_courtyard.gd); radii live in interaction_zone.gd's
	# ZONE_DATA, keyed by node .name -- same --script-mode script-compile
	# limitation as player/camera_rig above (see interaction_zone.gd's doc
	# comment for why this is a plain distance check, not an Area3D).
	var zones_container := Node3D.new()
	zones_container.name = "InteractionZones"
	root.add_child(zones_container)
	zones_container.owner = root

	# Positions match courtyard.tscn's own KeyPoints markers exactly (2026-08-28
	# world expansion -- see world_bounds.gd's doc comment for the four-room
	# layout these were relocated into).
	var zone_packed: PackedScene = load("res://scenes/interaction_zone.tscn")
	_interaction_zone(zone_packed, zones_container, root, "Watch", 0.0, -8.0)
	_interaction_zone(zone_packed, zones_container, root, "BallEnd", 14.0, -12.0)
	_interaction_zone(zone_packed, zones_container, root, "Return", 0.0, -11.0)
	_interaction_zone(zone_packed, zones_container, root, "Join", 0.0, -10.3)
	_interaction_zone(zone_packed, zones_container, root, "Door", 0.0, 13.0)

	# M2.3: the real ball -- starts at ballStart (game.mjs:115), flies to
	# ballEnd on BALL_IN_FLIGHT, carried/rest-positioned by state changes.
	var ball_packed: PackedScene = load("res://scenes/ball.tscn")
	var ball: Node3D = ball_packed.instantiate()
	root.add_child(ball)
	ball.owner = root

	# M3.1: three NPCs (real Kenney character models) at game.mjs:89-93's
	# NPC_DEFS positions/headings; glb path/tint/reaction data live in
	# character_visual.gd's CHARACTER_DATA, keyed by node .name.
	var npcs_container := Node3D.new()
	npcs_container.name = "NPCs"
	root.add_child(npcs_container)
	npcs_container.owner = root

	# Same offsets from the Group marker as before the 2026-08-28 world
	# expansion, just applied at Group's new position (0, -11).
	var character_visual_packed: PackedScene = load("res://scenes/character_visual.tscn")
	_npc(npcs_container, root, character_visual_packed, "Mina", -0.95, -11.0, 0.2)
	_npc(npcs_container, root, character_visual_packed, "Arun", 0.35, -11.45, -0.1)
	_npc(npcs_container, root, character_visual_packed, "Third", 1.45, -10.75, -0.4)

	# M2.4: UI -- CanvasLayer overlays, independent of Main's 3D transform.
	# Not script-loaded via load() here, same reason as player/camera_rig/
	# interaction_zone above.
	_instance_child(root, "res://scenes/ui/vignette.tscn")
	_instance_child(root, "res://scenes/ui/hud.tscn")
	_instance_child(root, "res://scenes/ui/title_card.tscn")
	# Gate 0 frame: S6 held-shot ending (replaces the removed feedback-survey
	# end_card.tscn), S7 credits, and S8 pause -- see each script's own doc
	# comment.
	_instance_child(root, "res://scenes/ui/ending_screen.tscn")
	_instance_child(root, "res://scenes/ui/credits_screen.tscn")
	_instance_child(root, "res://scenes/ui/pause_menu.tscn")

	# M2.5: perception -- fog/light/color driven by the emotional lens
	# (also the only thing that ever calls lens.set_target()/update(), so
	# without this comfort/energy/curiosity never move at all), plus the
	# fireflies (FIND_BALL) and home glow (GO_HOME/COMPLETE) visual
	# reactions to state.
	_instance_child(root, "res://scenes/perception.tscn")
	_instance_child(root, "res://scenes/fireflies.tscn")
	_instance_child(root, "res://scenes/home_glow.tscn")

	# Gate 0 verbs (81eb659): the floor-is-lava stepping stones and the
	# splashable puddles, both pure pollers with no transform of their own
	# (see each script's doc comment). NOTE: this generator had drifted out
	# of sync with the real main.tscn before this fix -- these two were
	# already shipped there (added directly, not through this file) with no
	# generator update to match. Restored here so a from-scratch rebuild is
	# accurate again; today's actual main.tscn edit (TitleCamera/
	# EndingScreen/CreditsScreen/PauseMenu) was applied as a direct text
	# edit instead, specifically to avoid re-running this (until now stale)
	# generator over already-shipped work. A load()+instantiate()+pack()
	# "patch" script was tried first and rejected: packing a loaded
	# main.tscn after add_child()-ing freshly instanced children onto it
	# reproducibly duplicated each newly-added instance under an
	# auto-generated `@Type@N` name alongside the correctly-named one --
	# real nodes in the saved file, each running its own _ready(), not just
	# a text artifact. Root cause not fully isolated; treat mixing "load an
	# already-built scene" with "instance new children into it, then
	# re-pack" as unreliable until it is.
	_instance_child(root, "res://scenes/stepping_stones.tscn")
	_instance_child(root, "res://scenes/puddles.tscn")

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		printerr("Failed to save main.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/main.tscn with courtyard + player + camera rig + title camera + interaction zones + ball + NPCs + UI (incl. ending/credits/pause) + perception")
	quit()


func _instance_child(scene_root: Node, path: String) -> void:
	var packed: PackedScene = load(path)
	var node: Node = packed.instantiate()
	scene_root.add_child(node)
	node.owner = scene_root


func _interaction_zone(zone_packed: PackedScene, parent: Node3D, scene_root: Node, zone_name: String, x: float, z: float) -> void:
	var zone: Node3D = zone_packed.instantiate()
	zone.name = zone_name
	parent.add_child(zone)
	zone.owner = scene_root
	zone.position = Vector3(x, 0.0, z)


func _npc(parent: Node3D, scene_root: Node, character_visual_packed: PackedScene, npc_name: String, x: float, z: float, heading: float) -> void:
	# character_visual.gd applies its own +PI flip to the loaded model
	# internally (characters.mjs:126), so this only needs the NPC's own
	# authored heading -- not heading + PI (matches game.mjs:106's
	# `character.root.rotation.y = def.heading + Math.PI`, which
	# OVERWRITES loadCharacter's own PI rotation with this single combined
	# value; the two-node split here (this transform + the model's own
	# internal PI) composes to the same net rotation instead).
	var visual: Node3D = character_visual_packed.instantiate()
	visual.name = npc_name
	parent.add_child(visual)
	visual.owner = scene_root
	visual.position = Vector3(x, 0.0, z)
	visual.rotation.y = heading

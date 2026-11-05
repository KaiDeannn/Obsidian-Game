extends Node
## Renders the card picture of every Engineer weapon from its real in-game model, so the
## Weapons app shows exactly what the player will carry.
##   godot --path . res://tools/RenderWeaponCards.tscn
##   godot --headless --path . --import --quit      (afterwards, to import the pictures)

const OUT := "res://assets/weapons/engineer/cards/"
const SIZE := Vector2i(960, 540)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for w: Dictionary in CityData.PREMIUM_WEAPONS:
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_8X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var yaw := deg_to_rad(112.0) if WeaponModels.is_launcher(w) else deg_to_rad(24.0)
		WeaponModels.stage(vp, w, yaw, float(SIZE.x) / float(SIZE.y))
		for i in range(16):                    # let the sky reflections settle
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_jpg(ProjectSettings.globalize_path(OUT + str(w["id"]) + ".jpg"), 0.92)
		print("card: ", w["id"])
		vp.queue_free()
	get_tree().quit()

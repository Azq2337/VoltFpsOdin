package main

import rl "vendor:raylib"

CROSSHAIR_GAP              :: 5
CROSSHAIR_LENGTH           :: 16
CROSSHAIR_LINE_THICKNESS   :: 2.0
CROSSHAIR_BORDER_THICKNESS :: 4.0
HIT_HINT_RADIUS            :: 8.0
HIT_HINT_COLOR_INTERVAL    :: 0.1

ENEMY_HEALTH_BAR_WIDTH  :: 80
ENEMY_HEALTH_BAR_HEIGHT :: 8
ENEMY_HEALTH_BAR_OFFSET :: 0.4

TAG_RING_RADIUS :: 58.0

AUTO_TARGET_WEDGE_INNER_RADIUS :: TAG_RING_RADIUS + 10.0
AUTO_TARGET_WEDGE_OUTER_RADIUS :: TAG_RING_RADIUS + 28.0
AUTO_TARGET_WEDGE_HALF_WIDTH   :: 11.0

hit_hint_color := rl.WHITE
hit_hint_color_timer: f32 = 0

draw_pause_menu :: proc() {
	center_x :=
		rl.GetScreenWidth() /
		2

	left_x :=
		center_x -
		320

	right_x :=
		center_x +
		20

	rl.DrawRectangle(
		0,
		0,
		rl.GetScreenWidth(),
		rl.GetScreenHeight(),
		rl.Color{
			0,
			0,
			0,
			160,
		},
	)

	rl.DrawText(
		"PAUSED",
		center_x - 75,
		120,
		40,
		rl.WHITE,
	)

	if menu_button(
		left_x,
		220,
		300,
		50,
		"Continue",
	) {
		toggle_pause()
		return
	}

	if menu_button(
		left_x,
		290,
		300,
		50,
		"Restart",
	) {
		restart_game()
		toggle_pause()
		return
	}

	if menu_button(
		left_x,
		360,
		300,
		50,
		"Exit",
	) {
		game_running = false
		return
	}

	rl.DrawText(
		"DEBUG",
		right_x,
		180,
		20,
		rl.LIGHTGRAY,
	)

	tps_text: cstring =
		"Third Person: OFF"

	if third_person_enabled {
		tps_text =
			"Third Person: ON"
	}

	if menu_button(
		right_x,
		220,
		300,
		50,
		tps_text,
	) {
		toggle_third_person_camera()
		return
	}

	debug_text: cstring =
		"Debug Camera: OFF"

	if debug_camera_enabled {
		debug_text =
			"Debug Camera: ON"
	}

	if menu_button(
		right_x,
		290,
		300,
		50,
		debug_text,
	) {
		toggle_debug_camera()
		return
	}
}

draw_free_aim_debug_ellipse :: proc() {
	if !aim_debug_rays_enabled ||
	   !auto_aim_enabled {
		return
	}

	radii :=
		get_floating_crosshair_radii()

	center_x :=
		rl.GetScreenWidth() /
		2

	center_y :=
		rl.GetScreenHeight() /
		2

	rl.DrawEllipseLines(
		center_x,
		center_y,
		radii.x,
		radii.y,
		rl.Color{
			40,
			160,
			220,
			150,
		},
	)
}

draw_crosshair :: proc() {
	center :=
		get_crosshair_screen_position()

	x := center.x
	y := center.y

	draw_crosshair_segment(
		{
			x,
			y -
				f32(
					CROSSHAIR_GAP +
					CROSSHAIR_LENGTH,
				),
		},
		{
			x,
			y -
				f32(
					CROSSHAIR_GAP,
				),
		},
	)

	draw_crosshair_segment(
		{
			x,
			y +
				f32(
					CROSSHAIR_GAP,
				),
		},
		{
			x,
			y +
				f32(
					CROSSHAIR_GAP +
					CROSSHAIR_LENGTH,
				),
		},
	)

	draw_crosshair_segment(
		{
			x -
				f32(
					CROSSHAIR_GAP +
					CROSSHAIR_LENGTH,
				),
			y,
		},
		{
			x -
				f32(
					CROSSHAIR_GAP,
				),
			y,
		},
	)

	draw_crosshair_segment(
		{
			x +
				f32(
					CROSSHAIR_GAP,
				),
			y,
		},
		{
			x +
				f32(
					CROSSHAIR_GAP +
						CROSSHAIR_LENGTH,
				),
			y,
		},
	)

	if auto_aim_enabled {
		rl.DrawCircleLines(
			i32(x),
			i32(y),
			14,
			rl.SKYBLUE,
		)
	}

	// Secondary circle: physical projectile impact prediction from the gun.
	direction :=
		get_gun_projectile_direction()

	origin :=
		get_gun_muzzle_position()

	translation :=
		direction *
		PROJECTILE_MAX_RANGE

	hit :=
		cast_projectile(
			origin,
			translation,
		)

	if hit.hit {
		impact_position :=
			origin +
			translation *
				hit.fraction

		to_hit :=
			impact_position -
			camera.position

		camera_forward :=
			camera.target -
			camera.position

		dot :=
			to_hit.x *
				camera_forward.x +
			to_hit.y *
				camera_forward.y +
			to_hit.z *
				camera_forward.z

		if dot > 0 {
			screen_pos :=
				rl.GetWorldToScreen(
					impact_position,
					camera,
				)

			hit_hint_color_timer -=
				TIME_STEP

			if hit_hint_color_timer <= 0 {
				hit_hint_color =
					get_screen_contrast_color(
						screen_pos,
					)

				hit_hint_color_timer =
					HIT_HINT_COLOR_INTERVAL
			}

			rl.DrawCircleLines(
				i32(screen_pos.x),
				i32(screen_pos.y),
				HIT_HINT_RADIUS,
				hit_hint_color,
			)
		}
	}
}

draw_crosshair_segment :: proc(
	start_pos,
	end_pos: rl.Vector2,
) {
	rl.DrawLineEx(
		start_pos,
		end_pos,
		CROSSHAIR_BORDER_THICKNESS,
		rl.WHITE,
	)

	rl.DrawLineEx(
		start_pos,
		end_pos,
		CROSSHAIR_LINE_THICKNESS,
		rl.BLACK,
	)
}

get_screen_contrast_color :: proc(
	screen_pos: rl.Vector2,
) -> rl.Color {
	image :=
		rl.LoadImageFromScreen()

	defer rl.UnloadImage(
		image,
	)

	x :=
		clamp(
			i32(screen_pos.x),
			0,
			image.width - 1,
		)

	y :=
		clamp(
			i32(screen_pos.y),
			0,
			image.height - 1,
		)

	background :=
		rl.GetImageColor(
			image,
			x,
			y,
		)

	luminance :=
		(
			i32(background.r) *
				299 +
			i32(background.g) *
				587 +
			i32(background.b) *
				114
		) /
		1000

	if luminance >= 128 {
		return rl.BLACK
	}

	return rl.WHITE
}

draw_enemy_health_bars :: proc() {
	for i in 0..<MAX_ENEMIES {
		if !enemies[i].active ||
		   !enemies[i].alive {
			continue
		}

		enemy_pos :=
			get_enemy_lock_position(i)

		world_pos :=
			rl.Vector3{
				enemy_pos.x,
				enemy_pos.y +
					ENEMY_HALF_HEIGHT +
					ENEMY_RADIUS +
					ENEMY_HEALTH_BAR_OFFSET,
				enemy_pos.z,
			}

		to_enemy :=
			world_pos -
			camera.position

		camera_forward :=
			camera.target -
			camera.position

		dot :=
			to_enemy.x *
				camera_forward.x +
			to_enemy.y *
				camera_forward.y +
			to_enemy.z *
				camera_forward.z

		if dot <= 0 {
			continue
		}

		screen_pos :=
			rl.GetWorldToScreen(
				world_pos,
				camera,
			)

		health_ratio :=
			enemies[i].health /
			enemies[i].max_health

		bar_x :=
			i32(screen_pos.x) -
			ENEMY_HEALTH_BAR_WIDTH /
				2

		bar_y :=
			i32(screen_pos.y)

		rl.DrawRectangle(
			bar_x,
			bar_y,
			ENEMY_HEALTH_BAR_WIDTH,
			ENEMY_HEALTH_BAR_HEIGHT,
			rl.DARKGRAY,
		)

		rl.DrawRectangle(
			bar_x,
			bar_y,
			i32(
				f32(
					ENEMY_HEALTH_BAR_WIDTH,
				) *
					health_ratio,
			),
			ENEMY_HEALTH_BAR_HEIGHT,
			rl.RED,
		)
	}
}

draw_enemy_tags :: proc() {
	for i in 0..<MAX_ENEMIES {
		if !enemies[i].active ||
		   !enemies[i].alive ||
		   enemies[i].tag_count <= 0 {
			continue
		}

		world_pos :=
			get_enemy_lock_position(i)

		to_enemy :=
			world_pos -
			camera.position

		camera_forward :=
			camera.target -
			camera.position

		dot :=
			to_enemy.x *
				camera_forward.x +
			to_enemy.y *
				camera_forward.y +
			to_enemy.z *
				camera_forward.z

		if dot <= 0 {
			continue
		}

		center :=
			rl.GetWorldToScreen(
				world_pos,
				camera,
			)

		color :=
			rl.Color{
				40,
				150,
				255,
				255,
			}

		if enemies[i].tag_count == 2 {
			color =
				rl.Color{
					255,
					210,
					30,
					255,
				}
		} else if enemies[i].tag_count >= 3 {
			color =
				rl.Color{
					255,
					40,
					40,
					255,
				}
		}

		rl.DrawRing(
			center,
			TAG_RING_RADIUS - 8,
			TAG_RING_RADIUS + 12,
			0,
			360,
			64,
			rl.Fade(
				color,
				0.20,
			),
		)

		rl.DrawRing(
			center,
			TAG_RING_RADIUS - 5,
			TAG_RING_RADIUS + 5,
			0,
			360,
			64,
			rl.Color{
				0,
				0,
				0,
				220,
			},
		)

		rl.DrawRing(
			center,
			TAG_RING_RADIUS - 3,
			TAG_RING_RADIUS + 3,
			0,
			360,
			64,
			color,
		)
	}
}

draw_auto_aim_target_wedge :: proc(
	center: rl.Vector2,
	direction: rl.Vector2,
	color: rl.Color,
) {
	tangent :=
		rl.Vector2{
			-direction.y,
			direction.x,
		}

	tip :=
		center +
		direction *
			AUTO_TARGET_WEDGE_INNER_RADIUS

	base_center :=
		center +
		direction *
			AUTO_TARGET_WEDGE_OUTER_RADIUS

	base_a :=
		base_center +
		tangent *
			AUTO_TARGET_WEDGE_HALF_WIDTH

	base_b :=
		base_center -
		tangent *
			AUTO_TARGET_WEDGE_HALF_WIDTH

	rl.DrawTriangle(
		base_a,
		base_b,
		tip,
		color,
	)
}

draw_auto_aim_target :: proc() {
	if !auto_aim_enabled ||
	   !is_auto_aim_target_valid(
			current_auto_aim_target,
		) {
		return
	}

	world_pos :=
		get_enemy_lock_position(
			current_auto_aim_target,
		)

	to_enemy :=
		world_pos -
		camera.position

	camera_forward :=
		camera.target -
		camera.position

	dot :=
		to_enemy.x *
			camera_forward.x +
		to_enemy.y *
			camera_forward.y +
		to_enemy.z *
			camera_forward.z

	if dot <= 0 {
		return
	}

	center :=
		rl.GetWorldToScreen(
			world_pos,
			camera,
		)

	color :=
		rl.Color{
			80,
			230,
			255,
			235,
		}

	diagonal: f32 = 0.70710678

	// Four inward-facing target wedges. They sit outside the colored tag ring,
	// so auto-target selection and electrical tag count remain distinct.
	draw_auto_aim_target_wedge(
		center,
		{-diagonal, -diagonal},
		color,
	)

	draw_auto_aim_target_wedge(
		center,
		{diagonal, -diagonal},
		color,
	)

	draw_auto_aim_target_wedge(
		center,
		{-diagonal, diagonal},
		color,
	)

	draw_auto_aim_target_wedge(
		center,
		{diagonal, diagonal},
		color,
	)
}

draw_training_status :: proc() {
	mode_text: cstring =
		"TRADITIONAL AIM [MMB]"

	if auto_aim_enabled {
		mode_text =
			"AUTO AIM [MMB]"
	}

	respawn_text: cstring =
		"RESPAWN OFF [F5]"

	if enemy_auto_respawn_enabled {
		respawn_text =
			"RESPAWN ON [F5]"
	}

	rl.DrawText(
		mode_text,
		10,
		60,
		18,
		rl.DARKGRAY,
	)

	rl.DrawText(
		respawn_text,
		10,
		82,
		18,
		rl.DARKGRAY,
	)

	rl.DrawText(
		"F2 TPS | F3 DEBUG | F4 AIM RAYS",
		10,
		104,
		18,
		rl.DARKGRAY,
	)
}

menu_button :: proc(
	x,
	y,
	width,
	height: i32,
	text: cstring,
) -> bool {
	rect :=
		rl.Rectangle{
			f32(x),
			f32(y),
			f32(width),
			f32(height),
		}

	hovered :=
		rl.CheckCollisionPointRec(
			rl.GetMousePosition(),
			rect,
		)

	color :=
		rl.LIGHTGRAY

	if hovered {
		color =
			rl.GRAY
	}

	rl.DrawRectangle(
		x,
		y,
		width,
		height,
		color,
	)

	rl.DrawRectangleLines(
		x,
		y,
		width,
		height,
		rl.DARKGRAY,
	)

	text_width :=
		rl.MeasureText(
			text,
			20,
		)

	rl.DrawText(
		text,
		x +
			(width - text_width) /
				2,
		y + 15,
		20,
		rl.BLACK,
	)

	return (
		hovered &&
		rl.IsMouseButtonPressed(
			.LEFT,
		)
	)
}

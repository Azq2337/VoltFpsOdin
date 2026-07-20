package world

import rl "vendor:raylib"

CROSSHAIR_GAP              :: 5
CROSSHAIR_LENGTH           :: 16
CROSSHAIR_LINE_THICKNESS   :: 2.0
CROSSHAIR_BORDER_THICKNESS :: 4.0
HIT_HINT_RADIUS            :: 8.0
HIT_HINT_COLOR_INTERVAL    :: 0.1

ENEMY_HEALTH_BAR_WIDTH  :: 80
ENEMY_HEALTH_BAR_HEIGHT :: 8

TAG_RING_RADIUS :: 58.0

AUTO_TARGET_WEDGE_INNER_RADIUS :: TAG_RING_RADIUS + 10.0
AUTO_TARGET_WEDGE_OUTER_RADIUS :: TAG_RING_RADIUS + 28.0
AUTO_TARGET_WEDGE_HALF_WIDTH   :: 11.0

hit_hint_color := rl.WHITE
hit_hint_color_timer: f32 = 0

draw_free_aim_debug_circle :: proc(
	enabled: bool,
	radius: f32,
) {
	if !enabled {
		return
	}

	rl.DrawCircleLines(
		rl.GetScreenWidth() /
			2,
		rl.GetScreenHeight() /
			2,
		radius,
		rl.Color{
			40,
			160,
			220,
			150,
		},
	)
}

draw_crosshair :: proc(
	center: rl.Vector2,
) {
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
}

draw_crosshair_segment :: proc(
	start_pos,
	end_pos: rl.Vector2,
) {
	// Black outer border, white inner crosshair.
	rl.DrawLineEx(
		start_pos,
		end_pos,
		CROSSHAIR_BORDER_THICKNESS,
		rl.BLACK,
	)

	rl.DrawLineEx(
		start_pos,
		end_pos,
		CROSSHAIR_LINE_THICKNESS,
		rl.WHITE,
	)
}

draw_hit_hint :: proc(
	screen_pos: rl.Vector2,
) {
	hit_hint_color_timer -=
		TIME_STEP

	if hit_hint_color_timer <= 0 {
		hit_hint_color =
			get_screen_contrast_color(
				screen_pos,
			)

		hit_hint_color_timer =
			0.1
	}

	rl.DrawCircleLines(
		i32(screen_pos.x),
		i32(screen_pos.y),
		HIT_HINT_RADIUS,
		hit_hint_color,
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

draw_enemy_health_bar :: proc(
	screen_pos: rl.Vector2,
	health_ratio: f32,
) {
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

draw_enemy_tag :: proc(
	center: rl.Vector2,
	tag_count: int,
) {
	if tag_count <= 0 {
		return
	}

	color :=
		rl.Color{
			40,
			150,
			255,
			255,
		}

	if tag_count == 2 {
		color =
			rl.Color{
				255,
				210,
				30,
				255,
			}
	} else if tag_count >= 3 {
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

draw_auto_aim_target :: proc(
	center: rl.Vector2,
) {
	color :=
		rl.Color{
			80,
			230,
			255,
			235,
		}

	diagonal: f32 = 0.70710678

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

draw_training_status :: proc(
	auto_aim_enabled,
	enemy_auto_respawn_enabled,
	aim_debug_rays_enabled: bool,
) {
	aim_text: cstring =
		"TRADITIONAL AIM [MMB]"

	if auto_aim_enabled {
		aim_text =
			"AUTO AIM [MMB]"
	}

	respawn_text: cstring =
		"RESPAWN OFF [F5]"

	if enemy_auto_respawn_enabled {
		respawn_text =
			"RESPAWN ON [F5]"
	}

	ray_text: cstring =
		"AIM RAYS OFF [F4]"

	if aim_debug_rays_enabled {
		ray_text =
			"AIM RAYS ON [F4]"
	}

	rl.DrawText(
		aim_text,
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
		"F2 TPS | F3 DEBUG",
		10,
		104,
		18,
		rl.DARKGRAY,
	)

	rl.DrawText(
		ray_text,
		10,
		126,
		18,
		rl.DARKGRAY,
	)
}

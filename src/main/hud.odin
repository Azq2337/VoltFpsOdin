package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

CROSSHAIR_GAP              :: 5
CROSSHAIR_LENGTH           :: 20
CROSSHAIR_LINE_THICKNESS   :: 2.0
CROSSHAIR_BORDER_THICKNESS :: 4.0
HIT_HINT_RADIUS            :: 8.0
HIT_HINT_COLOR_INTERVAL    :: 0.1
ENEMY_HEALTH_BAR_WIDTH     :: 80
ENEMY_HEALTH_BAR_HEIGHT    :: 8
ENEMY_HEALTH_BAR_OFFSET    :: 0.4
ENEMY_TAG_RADIUS           :: 6.0
ENEMY_TAG_SPACING          :: 18.0
ENEMY_TAG_OFFSET           :: 0.65
TAG_RING_RADIUS            :: 58.0

hit_hint_color := rl.WHITE
hit_hint_color_timer: f32 = 0

draw_pause_menu :: proc() {
	center_x := rl.GetScreenWidth() / 2

	left_x  := center_x - 320
	right_x := center_x + 20

	rl.DrawRectangle(
		0,
		0,
		rl.GetScreenWidth(),
		rl.GetScreenHeight(),
		rl.Color{0, 0, 0, 160},
	)

	rl.DrawText("PAUSED", center_x - 75, 120, 40, rl.WHITE)

	// Left column: main actions
	if menu_button(left_x, 220, 300, 50, "Continue") {
		toggle_pause()
		return
	}

	if menu_button(left_x, 290, 300, 50, "Restart") {
		restart_game()
		toggle_pause()
		return
	}

	if menu_button(left_x, 360, 300, 50, "Exit") {
		game_running = false
		return
	}

	// Right column: camera options
	rl.DrawText("DEBUG", right_x, 180, 20, rl.LIGHTGRAY)

	tps_text: cstring = "Third Person: OFF"
	if third_person_enabled {
		tps_text = "Third Person: ON"
	}

	if menu_button(right_x, 220, 300, 50, tps_text) {
		toggle_third_person_camera()
		return
	}

	debug_text: cstring = "Debug Camera: OFF"
	if debug_camera_enabled {
		debug_text = "Debug Camera: ON"
	}

	if menu_button(right_x, 290, 300, 50, debug_text) {
		toggle_debug_camera()
		return
	}
}

draw_crosshair :: proc() {
	if debug_camera_enabled {
		return
	}

	x := rl.GetScreenWidth() / 2
	y := rl.GetScreenHeight() / 2

	// Primary crosshair: always the exact center of the active camera.
	draw_crosshair_segment(
		{f32(x), f32(y - CROSSHAIR_GAP - CROSSHAIR_LENGTH)},
		{f32(x), f32(y - CROSSHAIR_GAP)},
	)
	draw_crosshair_segment(
		{f32(x), f32(y + CROSSHAIR_GAP)},
		{f32(x), f32(y + CROSSHAIR_GAP + CROSSHAIR_LENGTH)},
	)
	draw_crosshair_segment(
		{f32(x - CROSSHAIR_GAP - CROSSHAIR_LENGTH), f32(y)},
		{f32(x - CROSSHAIR_GAP), f32(y)},
	)
	draw_crosshair_segment(
		{f32(x + CROSSHAIR_GAP), f32(y)},
		{f32(x + CROSSHAIR_GAP + CROSSHAIR_LENGTH), f32(y)},
	)

	// Secondary circle: where the physical projectile sphere will first stop.
	direction := get_projectile_direction()
	origin := get_aim_origin() + direction * PROJECTILE_SPAWN_OFFSET
	translation := direction * PROJECTILE_MAX_RANGE
	hit := cast_projectile(origin, translation)

	if hit.hit {
		impact_position :=
			origin +
			translation * hit.fraction

		to_hit := impact_position - camera.position
		camera_forward := camera.target - camera.position
		dot :=
			to_hit.x * camera_forward.x +
			to_hit.y * camera_forward.y +
			to_hit.z * camera_forward.z

		if dot > 0 {
			screen_pos := rl.GetWorldToScreen(impact_position, camera)

			hit_hint_color_timer -= TIME_STEP
			if hit_hint_color_timer <= 0 {
				hit_hint_color = get_screen_contrast_color(screen_pos)
				hit_hint_color_timer = HIT_HINT_COLOR_INTERVAL
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

draw_crosshair_segment :: proc(start_pos, end_pos: rl.Vector2) {
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

get_screen_contrast_color :: proc(screen_pos: rl.Vector2) -> rl.Color {
	image := rl.LoadImageFromScreen()
	defer rl.UnloadImage(image)

	x := clamp(i32(screen_pos.x), 0, image.width - 1)
	y := clamp(i32(screen_pos.y), 0, image.height - 1)
	background := rl.GetImageColor(image, x, y)

	// Pick whichever of black or white has stronger luminance contrast.
	luminance :=
		(i32(background.r) * 299 +
		 i32(background.g) * 587 +
		 i32(background.b) * 114) / 1000

	if luminance >= 128 {
		return rl.BLACK
	}

	return rl.WHITE
}

draw_enemy_health_bar :: proc() {
	enemy_pos := b3.Body_GetPosition(enemy.body_id)

	world_pos := rl.Vector3{
		enemy_pos.x,
		enemy_pos.y + ENEMY_HALF_HEIGHT + ENEMY_RADIUS + ENEMY_HEALTH_BAR_OFFSET,
		enemy_pos.z,
	}

	// check if enemy is behind player so health bar is not drawn
	to_enemy := world_pos - camera.position
	camera_forward := camera.target - camera.position
	dot :=
		to_enemy.x * camera_forward.x +
		to_enemy.y * camera_forward.y +
		to_enemy.z * camera_forward.z
	if dot <= 0 {
		return
	}

	screen_pos := rl.GetWorldToScreen(world_pos, camera)

	health_ratio := enemy.health / enemy.max_health

	bar_x := i32(screen_pos.x) - ENEMY_HEALTH_BAR_WIDTH / 2
	bar_y := i32(screen_pos.y)

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
		i32(f32(ENEMY_HEALTH_BAR_WIDTH) * health_ratio),
		ENEMY_HEALTH_BAR_HEIGHT,
		rl.RED,
	)
}

draw_enemy_tags :: proc() {
	if enemy.tag_count <= 0 {
		return
	}

	world_pos := get_enemy_lock_position()

	// Don't draw when the lock point is behind the camera.
	to_enemy := world_pos - camera.position
	camera_forward := camera.target - camera.position

	dot :=
		to_enemy.x * camera_forward.x +
		to_enemy.y * camera_forward.y +
		to_enemy.z * camera_forward.z

	if dot <= 0 {
		return
	}

	center := rl.GetWorldToScreen(world_pos, camera)

	color := rl.Color{40, 150, 255, 255}

	if enemy.tag_count == 2 {
		color = rl.Color{255, 210, 30, 255}
	} else if enemy.tag_count >= 3 {
		color = rl.Color{255, 40, 40, 255}
	}

	// Soft outer glow.
	rl.DrawRing(
		center,
		TAG_RING_RADIUS - 8,
		TAG_RING_RADIUS + 12,
		0,
		360,
		64,
		rl.Fade(color, 0.20),
	)

	// Dark border prevents red/yellow/blue disappearing into the enemy.
	rl.DrawRing(
		center,
		TAG_RING_RADIUS - 5,
		TAG_RING_RADIUS + 5,
		0,
		360,
		64,
		rl.Color{0, 0, 0, 220},
	)

	// Bright actual tag ring.
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

menu_button :: proc(x, y, width, height: i32, text: cstring) -> bool {
	rect := rl.Rectangle{
		f32(x),
		f32(y),
		f32(width),
		f32(height),
	}

	hovered := rl.CheckCollisionPointRec(
		rl.GetMousePosition(),
		rect,
	)

	color := rl.LIGHTGRAY
	if hovered {
		color = rl.GRAY
	}

	rl.DrawRectangle(x, y, width, height, color)
	rl.DrawRectangleLines(x, y, width, height, rl.DARKGRAY)

	text_width := rl.MeasureText(text, 20)
	rl.DrawText(
		text,
		x + (width - text_width) / 2,
		y + 15,
		20,
		rl.BLACK,
	)

	return hovered && rl.IsMouseButtonPressed(.LEFT)
}


package main

import rl "vendor:raylib"

MENU_BUTTON_WIDTH  :: 320
MENU_BUTTON_HEIGHT :: 50
MENU_BUTTON_GAP    :: 14

draw_menu_background :: proc(alpha: u8) {
	rl.DrawRectangle(
		0,
		0,
		rl.GetScreenWidth(),
		rl.GetScreenHeight(),
		rl.Color{
			0,
			0,
			0,
			alpha,
		},
	)
}

draw_centered_menu_button :: proc(
	y: i32,
	text: cstring,
) -> bool {
	x :=
		rl.GetScreenWidth() /
			2 -
		MENU_BUTTON_WIDTH /
			2

	return menu_button(
		x,
		y,
		MENU_BUTTON_WIDTH,
		MENU_BUTTON_HEIGHT,
		text,
	)
}

draw_main_menu :: proc() {
	center_x :=
		rl.GetScreenWidth() /
		2

	rl.DrawText(
		"VOLT FPS ODIN",
		center_x - 170,
		110,
		42,
		rl.DARKGRAY,
	)

	rl.DrawText(
		"Phase 2 Training Build",
		center_x - 120,
		165,
		20,
		rl.GRAY,
	)

	y: i32 = 245

	if draw_centered_menu_button(
		y,
		"Start Game",
	) {
		start_new_game()
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Options",
	) {
		open_options_menu(
			.MAIN_MENU,
		)
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Exit",
	) {
		game_running = false
		return
	}
}

draw_pause_screen :: proc() {
	draw_menu_background(
		165,
	)

	center_x :=
		rl.GetScreenWidth() /
		2

	rl.DrawText(
		"PAUSED",
		center_x - 75,
		100,
		40,
		rl.WHITE,
	)

	y: i32 = 185

	if draw_centered_menu_button(
		y,
		"Continue",
	) {
		resume_game()
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Restart",
	) {
		restart_game()
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Options",
	) {
		open_options_menu(
			.PAUSED,
		)
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Main Menu",
	) {
		leave_game_to_main_menu()
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Exit",
	) {
		game_running = false
		return
	}
}

draw_options_menu :: proc() {
	if world_initialized {
		draw_menu_background(
			165,
		)
	}

	center_x :=
		rl.GetScreenWidth() /
		2

	title_color :=
		rl.DARKGRAY

	if world_initialized {
		title_color =
			rl.WHITE
	}

	rl.DrawText(
		"OPTIONS",
		center_x - 85,
		110,
		40,
		title_color,
	)

	y: i32 = 205

	auto_aim_text: cstring =
		"Auto Aim: OFF"

	if auto_aim_enabled {
		auto_aim_text =
			"Auto Aim: ON"
	}

	if draw_centered_menu_button(
		y,
		auto_aim_text,
	) {
		toggle_auto_aim()
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	aim_ray_text: cstring =
		"Show Aim Rays: OFF"

	if aim_debug_rays_enabled {
		aim_ray_text =
			"Show Aim Rays: ON"
	}

	if draw_centered_menu_button(
		y,
		aim_ray_text,
	) {
		toggle_aim_debug_rays()
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	respawn_text: cstring =
		"Enemy Respawn: OFF"

	if enemy_auto_respawn_enabled {
		respawn_text =
			"Enemy Respawn: ON"
	}

	if draw_centered_menu_button(
		y,
		respawn_text,
	) {
		toggle_enemy_auto_respawn()
		return
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Back",
	) {
		close_options_menu()
		return
	}
}

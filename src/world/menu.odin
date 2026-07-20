package world

import rl "vendor:raylib"

MENU_BUTTON_WIDTH  :: 320
MENU_BUTTON_HEIGHT :: 50
MENU_BUTTON_GAP    :: 14

Menu_Action :: enum {
	NONE,
	START_GAME,
	OPTIONS,
	EXIT,
	CONTINUE,
	RESTART,
	MAIN_MENU,
	BACK,
	TOGGLE_AUTO_AIM,
	TOGGLE_AIM_RAYS,
	TOGGLE_RESPAWN,
}

menu_button :: proc(
	x,
	y,
	width,
	height: i32,
	text: cstring,
) -> bool {
	mouse :=
		rl.GetMousePosition()

	hovered :=
		rl.CheckCollisionPointRec(
			mouse,
			{
				f32(x),
				f32(y),
				f32(width),
				f32(height),
			},
		)

	color := rl.LIGHTGRAY

	if hovered {
		color = rl.GRAY
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
			(
				width -
				text_width
			) /
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

draw_main_menu :: proc() -> Menu_Action {
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
		return .START_GAME
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Options",
	) {
		return .OPTIONS
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Exit",
	) {
		return .EXIT
	}

	return .NONE
}

draw_pause_screen :: proc() -> Menu_Action {
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
		return .CONTINUE
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Restart",
	) {
		return .RESTART
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Options",
	) {
		return .OPTIONS
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Main Menu",
	) {
		return .MAIN_MENU
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Exit",
	) {
		return .EXIT
	}

	return .NONE
}

draw_options_menu :: proc(
	auto_aim_enabled,
	aim_debug_rays_enabled,
	enemy_auto_respawn_enabled,
	has_game_world: bool,
) -> Menu_Action {
	if has_game_world {
		draw_menu_background(
			165,
		)
	}

	center_x :=
		rl.GetScreenWidth() /
		2

	title_color :=
		rl.DARKGRAY

	if has_game_world {
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
		return .TOGGLE_AUTO_AIM
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
		return .TOGGLE_AIM_RAYS
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
		return .TOGGLE_RESPAWN
	}

	y += MENU_BUTTON_HEIGHT +
		MENU_BUTTON_GAP

	if draw_centered_menu_button(
		y,
		"Back",
	) {
		return .BACK
	}

	return .NONE
}

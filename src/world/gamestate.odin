package world

import rl "vendor:raylib"
import b3 "vendor:box3d"

FRAMERATE      :: 60
TIME_STEP      :: 1. / FRAMERATE
SUB_STEP_COUNT :: 4

Game_Screen :: enum {
	MAIN_MENU,
	OPTIONS,
	PLAYING,
	PAUSED,
}

game_screen: Game_Screen = .MAIN_MENU
options_return_screen: Game_Screen = .MAIN_MENU

game_running      := true
world_initialized := false

world_id: b3.WorldId

cursor_capture_delay_frames := 0
mouse_delta_ignore_frames   := 0

request_gameplay_cursor_capture :: proc() {
	cursor_capture_delay_frames = 2
	mouse_delta_ignore_frames = 4
}

release_gameplay_cursor :: proc() {
	cursor_capture_delay_frames = 0
	rl.EnableCursor()
}

enter_playing_state :: proc() {
	game_screen = .PLAYING
	request_gameplay_cursor_capture()
}

pause_game :: proc() {
	if game_screen != .PLAYING {
		return
	}

	game_screen = .PAUSED
	release_gameplay_cursor()
}

resume_game :: proc() {
	if game_screen != .PAUSED {
		return
	}

	enter_playing_state()
}

show_main_menu :: proc() {
	game_screen = .MAIN_MENU
	options_return_screen = .MAIN_MENU
	release_gameplay_cursor()
}

open_options_menu :: proc(return_screen: Game_Screen) {
	options_return_screen = return_screen
	game_screen = .OPTIONS
	release_gameplay_cursor()
}

close_options_menu :: proc() {
	game_screen = options_return_screen
}

update_window_and_cursor_state :: proc() {
	if game_screen == .PLAYING &&
	   !rl.IsWindowFocused() {
		pause_game()
		return
	}

	if game_screen != .PLAYING {
		return
	}

	if cursor_capture_delay_frames > 0 {
		cursor_capture_delay_frames -= 1

		if cursor_capture_delay_frames == 0 &&
		   rl.IsWindowFocused() {
			rl.DisableCursor()
		}

		return
	}
}

get_gameplay_mouse_delta :: proc() -> rl.Vector2 {
	mouse_delta := rl.GetMouseDelta()

	if mouse_delta_ignore_frames > 0 {
		mouse_delta_ignore_frames -= 1
		return {}
	}

	return mouse_delta
}

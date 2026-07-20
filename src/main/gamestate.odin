package main

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

// Kept for compatibility with older menu/helper code.
paused := false

game_running     := true
world_initialized := false

world_id: b3.WorldId

// Delaying cursor capture avoids grabbing relative mouse input on the same
// Linux frame that clicked Start/Continue. The first mouse deltas after capture
// are also discarded so the camera always begins from a deterministic angle.
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
	paused = false
	request_gameplay_cursor_capture()
}

pause_game :: proc() {
	if game_screen != .PLAYING {
		return
	}

	game_screen = .PAUSED
	paused = true
	release_gameplay_cursor()
}

resume_game :: proc() {
	if game_screen != .PAUSED {
		return
	}

	enter_playing_state()
}

toggle_pause :: proc() {
	switch game_screen {
	case .MAIN_MENU:
		return
	case .OPTIONS:
		return
	case .PLAYING:
		pause_game()
	case .PAUSED:
		resume_game()
	}
}

show_main_menu :: proc() {
	game_screen = .MAIN_MENU
	paused = false
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

	if game_screen == .PAUSED {
		paused = true
	} else {
		paused = false
	}
}

update_window_and_cursor_state :: proc() {
	// Losing focus during gameplay always pauses before any further input is
	// processed. This prevents relative-mouse capture from behaving badly when
	// switching windows on Linux.
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

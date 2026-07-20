package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

main :: proc() {
	init()
	defer shutdown()
	loop()
}

create_game_world :: proc() {
	world_def :=
		b3.DefaultWorldDef()

	world_def.gravity =
		{0, -9.8, 0}

	world_id =
		b3.CreateWorld(
			world_def,
		)

	world_initialized = true

	player =
		create_player(
			world_id,
		)

	init_enemies(
		world_id,
	)

	for box in ROOM_BOXES {
		_ = create_static_box(
			world_id,
			box.center,
			box.half_size,
		)
	}
}

destroy_game_world :: proc() {
	if !world_initialized {
		return
	}

	b3.DestroyWorld(
		world_id,
	)

	world_initialized = false
}

reset_runtime_gameplay_state :: proc() {
	projectiles = {}
	surface_smoke_particles = {}

	reset_aiming_state()
	reset_zap_state()
	reset_camera()
}

start_new_game :: proc() {
	destroy_game_world()
	create_game_world()
	reset_runtime_gameplay_state()
	enter_playing_state()
}

leave_game_to_main_menu :: proc() {
	destroy_game_world()

	projectiles = {}
	surface_smoke_particles = {}

	show_main_menu()
}

init :: proc() {
	rl.InitWindow(
		1280,
		720,
		"Volt FPS Odin",
	)

	init_flashfield()

	rl.SetTargetFPS(
		FRAMERATE,
	)

	rl.SetExitKey(.KEY_NULL)

	// Do not capture the mouse at application startup. The main menu owns a
	// normal cursor, and gameplay captures it only after Start/Continue.
	rl.EnableCursor()

	show_main_menu()
}

update_gameplay :: proc() {
	update_aim_mode_input()

	if rl.IsKeyPressed(.F2) {
		toggle_third_person_camera()
	}

	if rl.IsKeyPressed(.F3) {
		toggle_debug_camera()
	}

	if rl.IsKeyPressed(.F4) {
		toggle_aim_debug_rays()
	}

	if rl.IsKeyPressed(.F5) {
		toggle_enemy_auto_respawn()
	}

	if !debug_camera_enabled {
		update_player()
	}

	b3.World_Step(
		world_id,
		TIME_STEP,
		SUB_STEP_COUNT,
	)

	update_camera()
	update_aiming()

	if !debug_camera_enabled {
		shoot_projectile()
		update_zap()
	} else {
		flashfield_active = false
		zap_active = false
	}

	update_projectiles()
	update_enemies()
}

loop :: proc() {
	for game_running &&
	    !rl.WindowShouldClose() {
		update_window_and_cursor_state()

		switch game_screen {
		case .PLAYING:
			if rl.IsKeyPressed(.ESCAPE) {
				pause_game()
			}

			if game_screen == .PLAYING {
				update_gameplay()
			}

		case .PAUSED:
			if rl.IsKeyPressed(.ESCAPE) {
				resume_game()
			}

		case .OPTIONS:
			if rl.IsKeyPressed(.ESCAPE) {
				close_options_menu()
			}

		case .MAIN_MENU:
		}

		rl.BeginDrawing()

		rl.ClearBackground(
			rl.RAYWHITE,
		)

		if world_initialized {
			rl.BeginMode3D(
				camera,
			)

			{
				defer rl.EndMode3D()

				draw_room()
				draw_enemies()
				draw_player()
				draw_projectiles()
				draw_flashfield()
				draw_gun()
				draw_zap_arcs()
				draw_aim_debug_ray()
			}
		}

		switch game_screen {
		case .MAIN_MENU:
			draw_main_menu()

		case .OPTIONS:
			draw_options_menu()

		case .PAUSED:
			draw_pause_screen()

		case .PLAYING:
			draw_free_aim_debug_ellipse()
			draw_crosshair()
			draw_auto_aim_target()
			draw_enemy_health_bars()
			draw_enemy_tags()
			draw_training_status()

			rl.DrawFPS(
				10,
				10,
			)

			rl.DrawText(
				"Volt FPS Odin",
				10,
				35,
				20,
				rl.DARKGRAY,
			)
		}

		rl.EndDrawing()
	}
}

shutdown :: proc() {
	destroy_game_world()

	shutdown_flashfield()
	rl.CloseWindow()
}

restart_game :: proc() {
	destroy_game_world()

	create_game_world()
	reset_runtime_gameplay_state()
	enter_playing_state()
}

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

	rl.DisableCursor()
	rl.SetExitKey(.KEY_NULL)

	create_game_world()
	reset_aiming_state()
	reset_zap_state()
}

loop :: proc() {
	for game_running &&
	    !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.ESCAPE) {
			toggle_pause()
		}

		if !paused {
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

		rl.BeginDrawing()
		rl.ClearBackground(
			rl.RAYWHITE,
		)

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

		if paused {
			draw_pause_menu()
		} else {
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
	b3.DestroyWorld(
		world_id,
	)

	shutdown_flashfield()
	rl.CloseWindow()
}

restart_game :: proc() {
	b3.DestroyWorld(
		world_id,
	)

	projectiles = {}
	wall_smoke_particles = {}

	create_game_world()

	reset_aiming_state()
	reset_zap_state()
}

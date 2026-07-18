package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

main :: proc() {
	init()
	defer shutdown()
	loop()
}

init :: proc() {
	rl.InitWindow(1280, 720, "Volt FPS Odin")
	rl.SetTargetFPS(FRAMERATE)
	rl.DisableCursor()
	rl.SetExitKey(.KEY_NULL)

	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -9.8, 0}
	world_id = b3.CreateWorld(world_def)

	player = create_player(world_id)

	for box in ROOM_BOXES {
		_ = create_static_box(
			world_id,
			box.center,
			box.half_size,
		)
	}
}

loop :: proc() {
	for game_running && !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.ESCAPE) do toggle_pause()
		if !paused {
			if rl.IsKeyPressed(.F3) do toggle_debug_camera()
			if !debug_camera_enabled do update_player()
			b3.World_Step(world_id, TIME_STEP, SUB_STEP_COUNT)
			update_camera()
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode3D(camera)
		{
			defer rl.EndMode3D()
			draw_room()
			draw_player_debug()
		}
		if paused {
			draw_pause_menu()
		} else {
			rl.DrawFPS(10, 10)
			rl.DrawText("Volt FPS Odin", 10, 35, 20, rl.DARKGRAY)
		}
		rl.EndDrawing()
	}
}

shutdown :: proc() {
	b3.DestroyWorld(world_id)
	rl.CloseWindow()
}


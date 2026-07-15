package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

main :: proc() {
	rl.InitWindow(1280, 720, "Volt FPS Odin")
	rl.SetTargetFPS(60)

	camera := rl.Camera3D{
		position   = {0, 4, 10},
		target     = {0, 2, 0},
		up         = {0, 1, 0},
		fovy       = 70,
		projection = .PERSPECTIVE,
	}

	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -9.8, 0}
	world_id := b3.CreateWorld(world_def)

	for box in ROOM_BOXES {
		_ = create_static_box(
			world_id,
			box.center,
			box.half_size,
		)
	}

	time_step:      f32 = 1. / 60.
	sub_step_count: i32 = 4

	for !rl.WindowShouldClose() {
		b3.World_Step(world_id, time_step, sub_step_count)
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode3D(camera)
		draw_room()
		rl.EndMode3D()
		rl.DrawFPS(10, 10)
		rl.DrawText("Volt FPS Odin", 10, 35, 20, rl.DARKGRAY)
		rl.EndDrawing()
	}

	b3.DestroyWorld(world_id)
	rl.CloseWindow()
}


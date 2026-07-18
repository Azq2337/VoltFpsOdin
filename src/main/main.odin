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

	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -9.8, 0}
	world_id = b3.CreateWorld(world_def)

	for box in ROOM_BOXES {
		_ = create_static_box(
			world_id,
			box.center,
			box.half_size,
		)
	}
}

loop :: proc() {
	for !rl.WindowShouldClose() {
		update_camera()

		b3.World_Step(world_id, TIME_STEP, SUB_STEP_COUNT)
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.BeginMode3D(camera)
		{
			defer rl.EndMode3D()
			draw_room()
		}
		rl.DrawFPS(10, 10)
		rl.DrawText("Volt FPS Odin", 10, 35, 20, rl.DARKGRAY)
		rl.EndDrawing()
	}
}

shutdown :: proc() {
	b3.DestroyWorld(world_id)
	rl.CloseWindow()
}


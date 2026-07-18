package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:math"

create_static_box :: proc(
	world_id: b3.WorldId,
	center, half_size: rl.Vector3,
) -> b3.BodyId 
{
	body_def := b3.DefaultBodyDef()
	body_def.position = {center.x, center.y, center.z}

	body_id := b3.CreateBody(world_id, body_def)

	hull := b3.MakeBoxHull(
		half_size.x,
		half_size.y,
		half_size.z,
	)

	shape_def := b3.DefaultShapeDef()
	_ = b3.CreateHullShape(body_id, shape_def, &hull.base)

	return body_id
}

draw_room :: proc() {
	for box in ROOM_BOXES {
		size := box.half_size * 2
		rl.DrawCube(box.center, size.x, size.y, size.z, box.color)
		rl.DrawCubeWires(box.center, size.x, size.y, size.z, rl.DARKGRAY)
	}

	rl.DrawGrid(20, 1)
}

update_camera :: proc() {
	mouse_delta := rl.GetMouseDelta()

	camera_yaw   += mouse_delta.x * MOUSE_SENSITIVITY
	camera_pitch -= mouse_delta.y * MOUSE_SENSITIVITY

	camera_pitch = clamp(camera_pitch, -89, 89)

	yaw   := math.to_radians(camera_yaw)
	pitch := math.to_radians(camera_pitch)

	direction := rl.Vector3{
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		-math.cos(pitch) * math.cos(yaw),
	}

	camera.target = {
		camera.position.x + direction.x,
		camera.position.y + direction.y,
		camera.position.z + direction.z,
	}
}

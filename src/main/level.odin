package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

Room_Box :: struct {
	center:    rl.Vector3,
	half_size: rl.Vector3,
	color:     rl.Color,
}

ROOM_BOX_COUNT :: 5

ROOM_BOXES :: [ROOM_BOX_COUNT]Room_Box{
	{
		center    = {0, -0.5, 0},
		half_size = {10, 0.5, 15},
		color     = rl.LIGHTGRAY,
	},
	{
		center    = {-10.5, 2.5, 0},
		half_size = {0.5, 2.5, 15.5},
		color     = rl.GRAY,
	},
	{
		center    = {10.5, 2.5, 0},
		half_size = {0.5, 2.5, 15.5},
		color     = rl.GRAY,
	},
	{
		center    = {0, 2.5, -15.5},
		half_size = {10, 2.5, 0.5},
		color     = rl.GRAY,
	},
	{
		center    = {0, 2.5, 15.5},
		half_size = {10, 2.5, 0.5},
		color     = rl.GRAY,
	},
}

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
}

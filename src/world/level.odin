package world

import rl "vendor:raylib"
import b3 "vendor:box3d"

Room_Box :: struct {
	center:             rl.Vector3,
	half_size:          rl.Vector3,
	color:              rl.Color,
	zap_route_obstacle: bool,
}

ROOM_BOX_COUNT :: 14

ROOM_BOXES :: [ROOM_BOX_COUNT]Room_Box{
	// One continuous safe floor. Falling from traversal platforms always
	// returns the player to the training ground.
	{
		center    = {0, -0.5, 0},
		half_size = {18, 0.5, 30},
		color     = rl.LIGHTGRAY,
	},

	// Outer walls.
	{
		center    = {-18.5, 3, 0},
		half_size = {0.5, 3, 30.5},
		color     = rl.GRAY,
	},
	{
		center    = {18.5, 3, 0},
		half_size = {0.5, 3, 30.5},
		color     = rl.GRAY,
	},
	{
		center    = {0, 3, -30.5},
		half_size = {18, 3, 0.5},
		color     = rl.GRAY,
	},
	{
		center    = {0, 3, 30.5},
		half_size = {18, 3, 0.5},
		color     = rl.GRAY,
	},

	// Off-axis zap-routing wall.
	{
		center             = {4, 2, -4},
		half_size          = {0.5, 2, 2.5},
		color              = rl.DARKGRAY,
		zap_route_obstacle = true,
	},

	// Wall-bounce practice corridor.
	{
		center             = {-7, 3, -10},
		half_size          = {0.5, 3, 3.5},
		color              = rl.DARKGRAY,
		zap_route_obstacle = true,
	},
	{
		center             = {-11, 3, -10},
		half_size          = {0.5, 3, 3.5},
		color              = rl.DARKGRAY,
		zap_route_obstacle = true,
	},

	// Elevated target platform.
	{
		center             = {10, 1, -5},
		half_size          = {2.5, 1, 2.5},
		color              = rl.GRAY,
		zap_route_obstacle = true,
	},

	// Step used to reach the dash-jump / hover course.
	{
		center             = {0, 0.5, -7},
		half_size          = {3, 0.5, 2},
		color              = rl.GRAY,
		zap_route_obstacle = true,
	},

	// First raised traversal platform.
	{
		center             = {0, 1, -12},
		half_size          = {3, 1, 3},
		color              = rl.GRAY,
		zap_route_obstacle = true,
	},

	// Second raised platform. There is a gap between the elevated platforms,
	// but safe ground remains underneath.
	{
		center             = {0, 1, -22},
		half_size          = {3, 1, 3},
		color              = rl.GRAY,
		zap_route_obstacle = true,
	},

	// High side platform for combined wall-bounce / hover experiments.
	{
		center             = {10, 2, -18},
		half_size          = {3, 2, 3},
		color              = rl.GRAY,
		zap_route_obstacle = true,
	},

	// Additional low platform for mixed-height target selection.
	{
		center             = {-10, 0.75, -20},
		half_size          = {3, 0.75, 3},
		color              = rl.GRAY,
		zap_route_obstacle = true,
	},
}

create_static_box :: proc(
	world_id: b3.WorldId,
	center,
	half_size: rl.Vector3,
) -> b3.BodyId {
	body_def :=
		b3.DefaultBodyDef()

	body_def.position = {
		center.x,
		center.y,
		center.z,
	}

	body_id :=
		b3.CreateBody(
			world_id,
			body_def,
		)

	hull :=
		b3.MakeBoxHull(
			half_size.x,
			half_size.y,
			half_size.z,
		)

	shape_def :=
		b3.DefaultShapeDef()

	_ = b3.CreateHullShape(
		body_id,
		shape_def,
		&hull.base,
	)

	return body_id
}

draw_room :: proc() {
	for box in ROOM_BOXES {
		size :=
			box.half_size *
			2

		rl.DrawCube(
			box.center,
			size.x,
			size.y,
			size.z,
			box.color,
		)

		rl.DrawCubeWires(
			box.center,
			size.x,
			size.y,
			size.z,
			rl.DARKGRAY,
		)
	}
}

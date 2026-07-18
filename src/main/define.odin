package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

Room_Box :: struct {
	center:    rl.Vector3,
	half_size: rl.Vector3,
	color:     rl.Color,
}

Player :: struct {
	body_id: b3.BodyId,

	dash_time_left:     f32,
	dash_cooldown_left: f32,
	dash_direction:     rl.Vector3,
}

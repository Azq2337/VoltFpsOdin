package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

/* constants */
// backend
FRAMERATE :: 60
TIME_STEP :: 1. / FRAMERATE
SUB_STEP_COUNT :: 4
// control
MOUSE_SENSITIVITY :: 0.1

/* global variable - initialized */
// camera
camera := rl.Camera3D {
	position   = {0, 4, 10},
	target     = {0, 2, 0},
	up         = {0, 1, 0},
	fovy       = 70,
	projection = .PERSPECTIVE,
}
camera_yaw:   f32 = 0
camera_pitch: f32 = 0

/* global variable - uninitialized */
world_id :      b3.WorldId


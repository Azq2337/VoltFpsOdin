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
// player
PLAYER_RADIUS           :: 0.4
PLAYER_HALF_HEIGHT      :: 0.6
PLAYER_EYE_HEIGHT       :: 0.7
PLAYER_SPEED            :: 6.0
PLAYER_JUMP_SPEED       :: 6.0
PLAYER_DASH_SPEED       :: 14.0
PLAYER_DASH_DURATION    :: 0.18
PLAYER_DASH_COOLDOWN    :: 0.35
// camera
DEBUG_CAMERA_SPEED :: 8.0

/* global variable - initialized */
// game state
paused       := false
game_running := true
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
debug_camera_enabled := false

/* global variable - uninitialized */
world_id :      b3.WorldId
player:         Player


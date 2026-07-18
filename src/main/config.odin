package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

/* constants */
// backend
FRAMERATE               :: 60
TIME_STEP               :: 1. / FRAMERATE
SUB_STEP_COUNT          :: 4
// camera
DEBUG_CAMERA_SPEED      :: 8.0
TPS_CAMERA_DISTANCE     :: 5.0
TPS_TARGET_HEIGHT       :: 2.0
// control
MOUSE_SENSITIVITY       :: 0.1
AIM_MAX_RANGE           :: 1000.0
// player
PLAYER_RADIUS           :: 0.4
PLAYER_HALF_HEIGHT      :: 0.6
PLAYER_EYE_HEIGHT       :: 0.7
PLAYER_SPEED            :: 6.0
PLAYER_JUMP_SPEED       :: 6.0
PLAYER_DASH_SPEED       :: 14.0
PLAYER_DASH_DURATION    :: 0.18
PLAYER_DASH_COOLDOWN    :: 0.35
// enemy
ENEMY_RADIUS            :: 0.4
ENEMY_HALF_HEIGHT       :: 0.6
ENEMY_MAX_HEALTH        :: 100.0
// projectile
MAX_PROJECTILES         :: 64
PROJECTILE_RADIUS       :: 0.08
PROJECTILE_SPEED        :: 25.0
PROJECTILE_DAMAGE       :: 25.0
PROJECTILE_MAX_RANGE    :: 50.0
PROJECTILE_SPAWN_OFFSET :: 0.5
// HUD
CROSSHAIR_GAP              :: 5
CROSSHAIR_LENGTH           :: 20
CROSSHAIR_LINE_THICKNESS   :: 2.0
CROSSHAIR_BORDER_THICKNESS :: 4.0
HIT_HINT_RADIUS            :: 8.0
HIT_HINT_COLOR_INTERVAL    :: 0.1
ENEMY_HEALTH_BAR_WIDTH :: 80
ENEMY_HEALTH_BAR_HEIGHT :: 8
ENEMY_HEALTH_BAR_OFFSET :: 0.4

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
third_person_enabled := false
hit_hint_color := rl.WHITE
hit_hint_color_timer: f32 = 0
aim_target: rl.Vector3
aim_target_initialized := false
camera_mode_changed := false

/* global variable - uninitialized */
world_id :      b3.WorldId
player:         Player
enemy:          Enemy
projectiles: 	[MAX_PROJECTILES]Projectile


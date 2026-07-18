package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

FRAMERATE      :: 60
TIME_STEP      :: 1. / FRAMERATE
SUB_STEP_COUNT :: 4

paused       := false
game_running := true

world_id: b3.WorldId

toggle_pause :: proc() {
	paused = !paused

	if paused {
		rl.EnableCursor()
	} else {
		rl.DisableCursor()
	}
}

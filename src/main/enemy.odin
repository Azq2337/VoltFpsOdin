package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

ENEMY_RADIUS      :: 0.4
ENEMY_HALF_HEIGHT :: 0.6
ENEMY_MAX_HEALTH  :: 100.0

Enemy :: struct {
	body_id:    b3.BodyId,
	health:     f32,
	max_health: f32,
}

enemy: Enemy

create_enemy :: proc(world_id: b3.WorldId, position: rl.Vector3) -> Enemy {
	body_def := b3.DefaultBodyDef()
	body_def.type = .kinematicBody
	body_def.position = {position.x, position.y, position.z}

	body_id := b3.CreateBody(world_id, body_def)

	capsule := b3.Capsule{
		center1 = {0, -ENEMY_HALF_HEIGHT, 0},
		center2 = {0,  ENEMY_HALF_HEIGHT, 0},
		radius  = ENEMY_RADIUS,
	}

	shape_def := b3.DefaultShapeDef()
	_ = b3.CreateCapsuleShape(body_id, shape_def, &capsule)

	return Enemy{
		body_id    = body_id,
		health     = ENEMY_MAX_HEALTH,
		max_health = ENEMY_MAX_HEALTH,
	}
}

draw_enemy :: proc() {
	pos := b3.Body_GetPosition(enemy.body_id)

	start := rl.Vector3{
		pos.x,
		pos.y - ENEMY_HALF_HEIGHT,
		pos.z,
	}

	end := rl.Vector3{
		pos.x,
		pos.y + ENEMY_HALF_HEIGHT,
		pos.z,
	}

	rl.DrawCapsule(
		start,
		end,
		ENEMY_RADIUS,
		8,
		8,
		rl.RED,
	)

	rl.DrawCapsuleWires(
		start,
		end,
		ENEMY_RADIUS,
		8,
		8,
		rl.MAROON,
	)
}

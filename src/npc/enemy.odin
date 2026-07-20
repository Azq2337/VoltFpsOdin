package npc

import rl "vendor:raylib"
import b3 "vendor:box3d"
import world "../world"

ENEMY_RADIUS             :: 0.4
ENEMY_HALF_HEIGHT        :: 0.6
ENEMY_MAX_HEALTH         :: 100.0
GLOBAL_MAX_TAGS          :: 3
ENEMY_MAX_TAGS           :: GLOBAL_MAX_TAGS
ENEMY_LOCK_HEIGHT_OFFSET :: 0.4
ENEMY_RESPAWN_DELAY      :: 2.0

MAX_ENEMIES :: 8

@(rodata)
ENEMY_SPAWN_POSITIONS := [MAX_ENEMIES]rl.Vector3{
	{0,   1, -5},
	{5,   1, -2},
	{-5,  1, -6},
	{10,  3, -5},
	{0,   3, -12},
	{0,   3, -22},
	{10,  5, -18},
	{-10, 2.5, -20},
}

Enemy :: struct {
	body_id:        b3.BodyId,
	health:         f32,
	max_health:     f32,
	tag_count:      int,
	spawn_position: rl.Vector3,
	respawn_timer:  f32,
	active:         bool,
	alive:          bool,
}

enemies: [MAX_ENEMIES]Enemy

// Gunvolt-style global rolling tag slots.
// A fourth tag removes the oldest tag, regardless of which enemy owns it.
tag_slots: [GLOBAL_MAX_TAGS]int = {-1, -1, -1}
tag_slot_count: int
tag_revision: u64

enemy_auto_respawn_enabled := false

create_enemy_body :: proc(
	physics_world_id: b3.WorldId,
	position: rl.Vector3,
) -> b3.BodyId {
	body_def := b3.DefaultBodyDef()
	body_def.type = .kinematicBody
	body_def.position = {
		position.x,
		position.y,
		position.z,
	}

	body_id := b3.CreateBody(physics_world_id, body_def)

	capsule := b3.Capsule{
		center1 = {0, -ENEMY_HALF_HEIGHT, 0},
		center2 = {0,  ENEMY_HALF_HEIGHT, 0},
		radius  = ENEMY_RADIUS,
	}

	shape_def := b3.DefaultShapeDef()
	_ = b3.CreateCapsuleShape(body_id, shape_def, &capsule)

	return body_id
}

create_enemy :: proc(
	physics_world_id: b3.WorldId,
	position: rl.Vector3,
) -> Enemy {
	return Enemy{
		body_id =
			create_enemy_body(
				physics_world_id,
				position,
			),
		health         = ENEMY_MAX_HEALTH,
		max_health     = ENEMY_MAX_HEALTH,
		tag_count      = 0,
		spawn_position = position,
		active         = true,
		alive          = true,
	}
}

init_enemies :: proc(
	physics_world_id: b3.WorldId,
) {
	for i in 0..<MAX_ENEMIES {
		enemies[i] =
			create_enemy(
				physics_world_id,
				ENEMY_SPAWN_POSITIONS[i],
			)
	}
}

reset_tags :: proc() {
	tag_slots = {-1, -1, -1}
	tag_slot_count = 0
	tag_revision += 1

	for i in 0..<MAX_ENEMIES {
		enemies[i].tag_count = 0
	}
}

rebuild_enemy_tag_counts :: proc() {
	for i in 0..<MAX_ENEMIES {
		enemies[i].tag_count = 0
	}

	for slot in 0..<tag_slot_count {
		enemy_index := tag_slots[slot]

		if enemy_index < 0 ||
		   enemy_index >= MAX_ENEMIES ||
		   !enemies[enemy_index].active ||
		   !enemies[enemy_index].alive {
			continue
		}

		enemies[enemy_index].tag_count += 1
	}
}

add_enemy_tag :: proc(
	enemy_index: int,
) {
	if enemy_index < 0 ||
	   enemy_index >= MAX_ENEMIES ||
	   !enemies[enemy_index].active ||
	   !enemies[enemy_index].alive {
		return
	}

	if tag_slot_count < GLOBAL_MAX_TAGS {
		tag_slots[tag_slot_count] = enemy_index
		tag_slot_count += 1
	} else {
		for i in 0..<GLOBAL_MAX_TAGS - 1 {
			tag_slots[i] = tag_slots[i + 1]
		}

		tag_slots[GLOBAL_MAX_TAGS - 1] =
			enemy_index
	}

	rebuild_enemy_tag_counts()
	tag_revision += 1
}

remove_enemy_tags :: proc(
	enemy_index: int,
) {
	write_index := 0

	for read_index in 0..<tag_slot_count {
		if tag_slots[read_index] == enemy_index {
			continue
		}

		tag_slots[write_index] =
			tag_slots[read_index]

		write_index += 1
	}

	for i in write_index..<GLOBAL_MAX_TAGS {
		tag_slots[i] = -1
	}

	tag_slot_count = write_index

	rebuild_enemy_tag_counts()
	tag_revision += 1
}

toggle_enemy_auto_respawn :: proc() {
	enemy_auto_respawn_enabled =
		!enemy_auto_respawn_enabled
}

update_enemies :: proc() {
	for i in 0..<MAX_ENEMIES {
		if !enemies[i].active ||
		   enemies[i].alive ||
		   !enemy_auto_respawn_enabled {
			continue
		}

		enemies[i].respawn_timer -=
			world.TIME_STEP

		if enemies[i].respawn_timer <= 0 {
			respawn_enemy(i)
		}
	}
}

respawn_enemy :: proc(index: int) {
	if index < 0 ||
	   index >= MAX_ENEMIES ||
	   !enemies[index].active {
		return
	}

	enemies[index].body_id =
		create_enemy_body(
			world.world_id,
			enemies[index].spawn_position,
		)

	enemies[index].health =
		enemies[index].max_health

	enemies[index].tag_count = 0
	enemies[index].respawn_timer = 0
	enemies[index].alive = true
}

kill_enemy :: proc(index: int) {
	if index < 0 ||
	   index >= MAX_ENEMIES ||
	   !enemies[index].active ||
	   !enemies[index].alive {
		return
	}

	remove_enemy_tags(index)

	b3.DestroyBody(
		enemies[index].body_id,
	)

	enemies[index].alive = false
	enemies[index].health = 0
	enemies[index].tag_count = 0
	enemies[index].respawn_timer =
		ENEMY_RESPAWN_DELAY

}

damage_enemy :: proc(
	index: int,
	damage: f32,
) {
	if index < 0 ||
	   index >= MAX_ENEMIES ||
	   !enemies[index].active ||
	   !enemies[index].alive {
		return
	}

	enemies[index].health =
		max(
			enemies[index].health -
				damage,
			0,
		)

	if enemies[index].health <= 0 {
		kill_enemy(index)
	}
}

get_enemy_index_from_body :: proc "contextless" (
	body_id: b3.BodyId,
) -> int {
	for i in 0..<MAX_ENEMIES {
		if enemies[i].active &&
		   enemies[i].alive &&
		   enemies[i].body_id == body_id {
			return i
		}
	}

	return -1
}

draw_enemies :: proc() {
	for i in 0..<MAX_ENEMIES {
		if !enemies[i].active ||
		   !enemies[i].alive {
			continue
		}

		pos :=
			b3.Body_GetPosition(
				enemies[i].body_id,
			)

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
}

get_enemy_lock_position :: proc(
	index: int,
) -> rl.Vector3 {
	if index < 0 ||
	   index >= MAX_ENEMIES ||
	   !enemies[index].active ||
	   !enemies[index].alive {
		return {}
	}

	pos :=
		b3.Body_GetPosition(
			enemies[index].body_id,
		)

	return {
		pos.x,
		pos.y + ENEMY_LOCK_HEIGHT_OFFSET,
		pos.z,
	}
}

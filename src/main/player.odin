package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:math"
import "core:c"

PLAYER_RADIUS         :: 0.4
PLAYER_HALF_HEIGHT    :: 0.6
PLAYER_EYE_HEIGHT     :: 0.7
PLAYER_SPEED          :: 6.0
PLAYER_JUMP_SPEED     :: 6.0
PLAYER_DASH_SPEED     :: 14.0
PLAYER_DASH_DURATION  :: 0.18
PLAYER_DASH_COOLDOWN  :: 0.35
GROUND_CHECK_RADIUS   :: PLAYER_RADIUS * 0.9
GROUND_CHECK_DISTANCE :: 0.12
GROUND_NORMAL_MIN_Y   :: 0.5

Player :: struct {
	body_id: b3.BodyId,

	dash_time_left:     f32,
	dash_cooldown_left: f32,
	dash_direction:     rl.Vector3,
}

player: Player

create_player :: proc(world_id: b3.WorldId) -> Player {
	body_def := b3.DefaultBodyDef()
	body_def.type = .dynamicBody
	body_def.position = {0, 2, 5}
	body_def.enableSleep = false
	body_def.enableContactRecycling = false

	// FPS character should stay upright.
	body_def.motionLocks.angularX = true
	body_def.motionLocks.angularY = true
	body_def.motionLocks.angularZ = true

	body_id := b3.CreateBody(world_id, body_def)

	capsule := b3.Capsule{
		center1 = {0, -PLAYER_HALF_HEIGHT, 0},
		center2 = {0,  PLAYER_HALF_HEIGHT, 0},
		radius  = PLAYER_RADIUS,
	}

	shape_def := b3.DefaultShapeDef()
	shape_def.density = 1
	shape_def.baseMaterial.friction = 0

	_ = b3.CreateCapsuleShape(body_id, shape_def, &capsule)

	return Player{
		body_id = body_id,
	}
}

draw_player :: proc() {
	if !debug_camera_enabled && !third_person_enabled {
		return
	}

	pos := b3.Body_GetPosition(player.body_id)

	start := rl.Vector3{
		pos.x,
		pos.y - PLAYER_HALF_HEIGHT,
		pos.z,
	}

	end := rl.Vector3{
		pos.x,
		pos.y + PLAYER_HALF_HEIGHT,
		pos.z,
	}

	if third_person_enabled {
		rl.DrawCapsule(
			start,
			end,
			PLAYER_RADIUS,
			8,
			8,
			rl.BLUE,
		)
	}

	if debug_camera_enabled {
		rl.DrawCapsuleWires(
			start,
			end,
			PLAYER_RADIUS,
			8,
			8,
			rl.RED,
		)
	}
}

update_player :: proc() {
	velocity := b3.Body_GetLinearVelocity(player.body_id)

	/* Move */
	move := rl.Vector3{}
	yaw := math.to_radians(camera_yaw)
	forward := rl.Vector3{math.sin(yaw), 0, -math.cos(yaw)}
	right := rl.Vector3{math.cos(yaw), 0, math.sin(yaw)}
	if rl.IsKeyDown(.W) { move += forward }
	if rl.IsKeyDown(.S) { move -= forward }
	if rl.IsKeyDown(.D) { move += right }
	if rl.IsKeyDown(.A) { move -= right }
	move_length := math.sqrt(move.x * move.x + move.z * move.z) // normalize
	if move_length > 0 do move /= move_length

	/* Jump */
	if rl.IsKeyPressed(.SPACE) && is_player_grounded() {
		velocity.y = PLAYER_JUMP_SPEED
	}

	/* Dash */
	player.dash_time_left     = max(player.dash_time_left - TIME_STEP, 0)
	player.dash_cooldown_left = max(player.dash_cooldown_left - TIME_STEP, 0)
	if rl.IsKeyPressed(.LEFT_SHIFT) && player.dash_cooldown_left <= 0 {
		player.dash_direction = move
		if move_length == 0 do player.dash_direction = forward
		player.dash_time_left     = PLAYER_DASH_DURATION
		player.dash_cooldown_left = PLAYER_DASH_COOLDOWN
	}
	if player.dash_time_left > 0 {
		move = player.dash_direction * PLAYER_DASH_SPEED
	} else {
		move *= PLAYER_SPEED
	}
	velocity.x = move.x
	velocity.z = move.z

	b3.Body_SetLinearVelocity(player.body_id, velocity)
}

is_player_grounded :: proc() -> bool {
	velocity := b3.Body_GetLinearVelocity(player.body_id)
	if velocity.y > 0.1 {
		return false
	}

	player_pos := b3.Body_GetPosition(player.body_id)
	origin := rl.Vector3{
		player_pos.x,
		player_pos.y - PLAYER_HALF_HEIGHT,
		player_pos.z,
	}

	center := b3.Vec3{}
	proxy := b3.ShapeProxy{
		points = &center,
		count  = 1,
		radius = GROUND_CHECK_RADIUS,
	}

	result := Projectile_Cast_Result{}
	filter := b3.DefaultQueryFilter()

	_ = b3.World_CastShape(
		world_id,
		{origin.x, origin.y, origin.z},
		proxy,
		{0, -GROUND_CHECK_DISTANCE, 0},
		filter,
		ground_cast_callback,
		&result,
	)

	return result.hit
}

ground_cast_callback :: proc "c" (
	shape_id: b3.ShapeId,
	point: b3.Pos,
	normal: b3.Vec3,
	fraction: f32,
	user_material_id: u64,
	triangle_index: c.int,
	child_index: c.int,
	ctx: rawptr,
) -> f32 {
	body_id := b3.Shape_GetBody(shape_id)

	if body_id == player.body_id {
		return -1
	}

	// Ignore walls and steep surfaces. Only upward-facing surfaces count
	// as ground for jumping.
	if normal.y < GROUND_NORMAL_MIN_Y {
		return -1
	}

	result := cast(^Projectile_Cast_Result)ctx
	result.hit = true
	result.shape_id = shape_id
	result.point = point
	result.fraction = fraction

	return fraction
}

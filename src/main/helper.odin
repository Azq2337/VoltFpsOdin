package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:math"

/* Create */
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

draw_room :: proc() {
	for box in ROOM_BOXES {
		size := box.half_size * 2
		rl.DrawCube(box.center, size.x, size.y, size.z, box.color)
		rl.DrawCubeWires(box.center, size.x, size.y, size.z, rl.DARKGRAY)
	}
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

/* Update */
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

update_camera :: proc() {
	mouse_delta := rl.GetMouseDelta()

	camera_yaw   += mouse_delta.x * MOUSE_SENSITIVITY
	camera_pitch -= mouse_delta.y * MOUSE_SENSITIVITY

	camera_pitch = clamp(camera_pitch, -89, 89)

	yaw   := math.to_radians(camera_yaw)
	pitch := math.to_radians(camera_pitch)

	direction := rl.Vector3{
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		-math.cos(pitch) * math.cos(yaw),
	}

	player_pos := b3.Body_GetPosition(player.body_id)
	camera.position = {
		player_pos.x,
		player_pos.y + PLAYER_EYE_HEIGHT,
		player_pos.z,
	}
	camera.target = {
		camera.position.x + direction.x,
		camera.position.y + direction.y,
		camera.position.z + direction.z,
	}
}

/* Check */
is_player_grounded :: proc() -> bool {
	contact_count := b3.Body_GetContactCapacity(player.body_id)
	velocity := b3.Body_GetLinearVelocity(player.body_id)

	return contact_count > 0 && velocity.y <= 0.1
}



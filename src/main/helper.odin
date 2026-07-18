package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:math"
import "core:c"

/* Create */
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

/* Draw*/
draw_pause_menu :: proc() {
	center_x := rl.GetScreenWidth() / 2
	menu_x := center_x - 150

	rl.DrawRectangle(
		0,
		0,
		rl.GetScreenWidth(),
		rl.GetScreenHeight(),
		rl.Color{0, 0, 0, 160},
	)

	rl.DrawText("PAUSED", menu_x, 120, 40, rl.WHITE)

	if menu_button(menu_x, 200, 300, 50, "Continue") {
		toggle_pause()
		return
	}

	rl.DrawText("DEBUG", menu_x, 290, 20, rl.LIGHTGRAY)

	debug_text: cstring = "Debug Camera: OFF"
	if debug_camera_enabled {
		debug_text = "Debug Camera: ON"
	}

	if menu_button(menu_x, 320, 300, 50, debug_text) {
		toggle_debug_camera()
		return
	}

	if menu_button(menu_x, 420, 300, 50, "Exit") {
		game_running = false
		return
	}
}

draw_room :: proc() {
	for box in ROOM_BOXES {
		size := box.half_size * 2
		rl.DrawCube(box.center, size.x, size.y, size.z, box.color)
		rl.DrawCubeWires(box.center, size.x, size.y, size.z, rl.DARKGRAY)
	}
}

draw_player_debug :: proc() {
	if !debug_camera_enabled {
		return
	}

	pos := b3.Body_GetPosition(player.body_id)

	rl.DrawCapsuleWires(
		{pos.x, pos.y - PLAYER_HALF_HEIGHT, pos.z},
		{pos.x, pos.y + PLAYER_HALF_HEIGHT, pos.z},
		PLAYER_RADIUS,
		8,
		8,
		rl.RED,
	)
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

draw_projectiles :: proc() {
	for projectile in projectiles {
		if projectile.active {
			rl.DrawSphere(
				projectile.position,
				PROJECTILE_RADIUS,
				rl.YELLOW,
			)
		}
	}
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
	forward := rl.Vector3{
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		-math.cos(pitch) * math.cos(yaw),
	}

	if debug_camera_enabled {
		update_debug_camera(forward)
	} else {
		player_pos := b3.Body_GetPosition(player.body_id)
		camera.position = {
			player_pos.x,
			player_pos.y + PLAYER_EYE_HEIGHT,
			player_pos.z,
		}
	}

	camera.target = camera.position + forward
}

update_debug_camera :: proc(forward: rl.Vector3) {
	right := rl.Vector3{
		math.cos(math.to_radians(camera_yaw)),
		0,
		math.sin(math.to_radians(camera_yaw)),
	}

	move := rl.Vector3{}
	if rl.IsKeyDown(.W) { move += forward }
	if rl.IsKeyDown(.S) { move -= forward }
	if rl.IsKeyDown(.D) { move += right }
	if rl.IsKeyDown(.A) { move -= right }
	if rl.IsKeyDown(.E) { move.y += 1 }
	if rl.IsKeyDown(.Q) { move.y -= 1 }

	length := math.sqrt(move.x * move.x + move.y * move.y + move.z * move.z)
	if length > 0 do move /= length

	camera.position += move * DEBUG_CAMERA_SPEED * TIME_STEP
}

update_projectiles :: proc() {
	for i in 0..<MAX_PROJECTILES {
		if !projectiles[i].active {
			continue
		}

		translation := projectiles[i].velocity * TIME_STEP

		hit := cast_projectile(
			projectiles[i].position,
			translation,
		)

		if hit.hit {
			hit_body := b3.Shape_GetBody(hit.shape_id)

			if hit_body == enemy.body_id {
				enemy.health = max(
					enemy.health - PROJECTILE_DAMAGE,
					0,
				)
			}

			projectiles[i].active = false
			continue
		}

		projectiles[i].position += translation
		projectiles[i].distance_traveled += PROJECTILE_SPEED * TIME_STEP

		if projectiles[i].distance_traveled >= PROJECTILE_MAX_RANGE {
			projectiles[i].active = false
		}
	}
}

/* Check */
is_player_grounded :: proc() -> bool {
	contact_count := b3.Body_GetContactCapacity(player.body_id)
	velocity := b3.Body_GetLinearVelocity(player.body_id)

	return contact_count > 0 && velocity.y <= 0.1
}

cast_projectile :: proc(
	position: rl.Vector3,
	translation: rl.Vector3,
) -> Projectile_Cast_Result {
	center := b3.Vec3{}

	proxy := b3.ShapeProxy{
		points = &center,
		count  = 1,
		radius = PROJECTILE_RADIUS,
	}

	result := Projectile_Cast_Result{}
	filter := b3.DefaultQueryFilter()

	_ = b3.World_CastShape(
		world_id,
		{position.x, position.y, position.z},
		proxy,
		{translation.x, translation.y, translation.z},
		filter,
		projectile_cast_callback,
		&result,
	)

	return result
}

/* Toggle */
toggle_debug_camera :: proc() {
	debug_camera_enabled = !debug_camera_enabled

	if debug_camera_enabled {
		velocity := b3.Body_GetLinearVelocity(player.body_id)
		velocity.x = 0
		velocity.z = 0
		b3.Body_SetLinearVelocity(player.body_id, velocity)
	}
}

toggle_pause :: proc() {
	paused = !paused

	if paused {
		rl.EnableCursor()
	} else {
		rl.DisableCursor()
	}
}

/* UI */
menu_button :: proc(x, y, width, height: i32, text: cstring) -> bool {
	rect := rl.Rectangle{
		f32(x),
		f32(y),
		f32(width),
		f32(height),
	}

	hovered := rl.CheckCollisionPointRec(
		rl.GetMousePosition(),
		rect,
	)

	color := rl.LIGHTGRAY
	if hovered {
		color = rl.GRAY
	}

	rl.DrawRectangle(x, y, width, height, color)
	rl.DrawRectangleLines(x, y, width, height, rl.DARKGRAY)

	text_width := rl.MeasureText(text, 20)
	rl.DrawText(
		text,
		x + (width - text_width) / 2,
		y + 15,
		20,
		rl.BLACK,
	)

	return hovered && rl.IsMouseButtonPressed(.LEFT)
}

/* Action */
shoot_projectile :: proc() {
	if !rl.IsMouseButtonPressed(.LEFT) {
		return
	}

	for i in 0..<MAX_PROJECTILES {
		if projectiles[i].active {
			continue
		}

		direction := camera.target - camera.position

		projectiles[i] = Projectile{
			position = camera.position + direction * PROJECTILE_SPAWN_OFFSET,
			velocity = direction * PROJECTILE_SPEED,
			active   = true,
		}

		break
	}
}

projectile_cast_callback :: proc "c" (
	shape_id: b3.ShapeId,
	point: b3.Pos,
	normal: b3.Vec3,
	fraction: f32,
	user_material_id: u64,
	triangle_index: c.int,
	child_index: c.int,
	ctx: rawptr,
) -> f32 {
	result := cast(^Projectile_Cast_Result)ctx

	// Do not let the projectile hit its own player.
	body_id := b3.Shape_GetBody(shape_id)
	if body_id == player.body_id {
		return -1
	}

	result.hit = true
	result.shape_id = shape_id
	result.fraction = fraction

	// Clip the cast to this hit.
	return fraction
}

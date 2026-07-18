package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:math"
import "core:c"

DEBUG_CAMERA_SPEED          :: 8.0
TPS_CAMERA_DISTANCE         :: 4.0
TPS_TARGET_HEIGHT           :: 1.8
TPS_CAMERA_COLLISION_RADIUS :: 0.25
MOUSE_SENSITIVITY           :: 0.1

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
camera_mode_changed   := false

update_camera :: proc() {
	mouse_delta := rl.GetMouseDelta()

	if !debug_camera_enabled &&
	   camera_mode_changed &&
	   aim_target_initialized {
		// Preserve the same world-space target when switching FPS/TPS.
		// TPS uses its elevated pivot; FPS uses the player's eye position.
		pivot := get_camera_pivot()
		direction := normalize_vector3(aim_target - pivot)
		set_aim_direction(direction)
		camera_mode_changed = false
	}

	camera_yaw   += mouse_delta.x * MOUSE_SENSITIVITY
	camera_pitch -= mouse_delta.y * MOUSE_SENSITIVITY
	camera_pitch = clamp(camera_pitch, -89, 89)

	forward := get_aim_direction()

	if debug_camera_enabled {
		update_debug_camera(forward)
		camera.target = camera.position + forward
		return
	}

	if third_person_enabled {
		pivot := get_camera_pivot()
		desired_position :=
			pivot -
			forward * TPS_CAMERA_DISTANCE
		translation :=
			desired_position -
			pivot

		hit := cast_camera(
			pivot,
			translation,
		)

		if hit.hit {
			camera.position =
				pivot +
				translation * hit.fraction
		} else {
			camera.position =
				desired_position
		}
	} else {
		camera.position = get_aim_origin()
	}

	aim_target = get_camera_aim_target(
		camera.position,
		forward,
	)
	aim_target_initialized = true
	camera.target = aim_target
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

get_camera_pivot :: proc() -> rl.Vector3 {
	if !third_person_enabled {
		return get_aim_origin()
	}

	player_pos := b3.Body_GetPosition(player.body_id)

	return {
		player_pos.x,
		player_pos.y + TPS_TARGET_HEIGHT,
		player_pos.z,
	}
}

cast_camera :: proc(
	position: rl.Vector3,
	translation: rl.Vector3,
) -> Projectile_Cast_Result {
	center := b3.Vec3{}

	proxy := b3.ShapeProxy{
		points = &center,
		count  = 1,
		radius = TPS_CAMERA_COLLISION_RADIUS,
	}

	result := Projectile_Cast_Result{}
	filter := b3.DefaultQueryFilter()

	_ = b3.World_CastShape(
		world_id,
		{position.x, position.y, position.z},
		proxy,
		{translation.x, translation.y, translation.z},
		filter,
		camera_cast_callback,
		&result,
	)

	return result
}

toggle_debug_camera :: proc() {
	debug_camera_enabled = !debug_camera_enabled

	if debug_camera_enabled {
		velocity := b3.Body_GetLinearVelocity(player.body_id)
		velocity.x = 0
		velocity.z = 0
		b3.Body_SetLinearVelocity(player.body_id, velocity)
	}
}

toggle_third_person_camera :: proc() {
	third_person_enabled = !third_person_enabled
	camera_mode_changed = true
}

camera_cast_callback :: proc "c" (
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

	// Camera should react to room geometry, not the player or enemy capsule.
	if body_id == player.body_id ||
	   body_id == enemy.body_id {
		return -1
	}

	result := cast(^Projectile_Cast_Result)ctx
	result.hit = true
	result.shape_id = shape_id
	result.point = point
	result.fraction = fraction

	return fraction
}

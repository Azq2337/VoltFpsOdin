package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:math"

AIM_MAX_RANGE :: 1000.0

aim_target: rl.Vector3
aim_target_initialized := false

get_aim_direction :: proc() -> rl.Vector3 {
	yaw := math.to_radians(camera_yaw)
	pitch := math.to_radians(camera_pitch)

	return {
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		-math.cos(pitch) * math.cos(yaw),
	}
}

set_aim_direction :: proc(direction: rl.Vector3) {
	normalized_direction := normalize_vector3(direction)

	camera_yaw =
		math.to_degrees(
			math.atan2(
				normalized_direction.x,
				-normalized_direction.z,
			),
		)

	camera_pitch =
		math.to_degrees(
			math.asin(
				clamp(normalized_direction.y, -1, 1),
			),
		)
}

normalize_vector3 :: proc(vector: rl.Vector3) -> rl.Vector3 {
	length := math.sqrt(
		vector.x * vector.x +
		vector.y * vector.y +
		vector.z * vector.z,
	)

	if length <= 0 {
		return {}
	}

	return vector / length
}

get_aim_origin :: proc() -> rl.Vector3 {
	player_pos := b3.Body_GetPosition(player.body_id)

	return {
		player_pos.x,
		player_pos.y + PLAYER_EYE_HEIGHT,
		player_pos.z,
	}
}

get_camera_aim_target :: proc(
	origin: rl.Vector3,
	direction: rl.Vector3,
) -> rl.Vector3 {
	translation := direction * AIM_MAX_RANGE

	hit := cast_aim_ray(
		origin,
		translation,
	)

	if hit.hit {
		return origin + translation * hit.fraction
	}

	return origin + translation
}

get_projectile_direction :: proc() -> rl.Vector3 {
	if !aim_target_initialized {
		return get_aim_direction()
	}

	return normalize_vector3(
		aim_target -
		get_aim_origin(),
	)
}

cast_aim_ray :: proc(
	position: rl.Vector3,
	translation: rl.Vector3,
) -> Projectile_Cast_Result {
	result := Projectile_Cast_Result{}
	filter := b3.DefaultQueryFilter()

	_ = b3.World_CastRay(
		world_id,
		{position.x, position.y, position.z},
		{translation.x, translation.y, translation.z},
		filter,
		projectile_cast_callback,
		&result,
	)

	return result
}

draw_aim_debug_ray :: proc() {
	if !third_person_enabled || debug_camera_enabled {
		return
	}

	direction := get_projectile_direction()
	origin := get_aim_origin() + direction * PROJECTILE_SPAWN_OFFSET
	translation := direction * PROJECTILE_MAX_RANGE
	hit := cast_projectile(origin, translation)

	end := origin + translation

	if hit.hit {
		end =
			origin +
			translation * hit.fraction
	}

	rl.DrawLine3D(origin, end, rl.BLUE)
}

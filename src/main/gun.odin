package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

GUN_BARREL_LENGTH :: 0.58

get_camera_right_vector :: proc() -> rl.Vector3 {
	forward :=
		normalize_vector3(
			camera.target -
			camera.position,
		)

	right :=
		rl.Vector3CrossProduct(
			forward,
			camera.up,
		)

	if vector3_length_squared(
		right,
	) <= 0.0001 {
		return {
			1,
			0,
			0,
		}
	}

	return normalize_vector3(
		right,
	)
}

get_gun_base_position :: proc() -> rl.Vector3 {
	camera_forward :=
		normalize_vector3(
			camera.target -
			camera.position,
		)

	camera_right :=
		get_camera_right_vector()

	camera_up :=
		normalize_vector3(
			camera.up,
		)

	if !third_person_enabled &&
	   !debug_camera_enabled {
		// First-person right-hand position.
		return (
			camera.position +
			camera_forward * 0.42 +
			camera_right * 0.30 -
			camera_up * 0.20
		)
	}

	player_pos :=
		b3.Body_GetPosition(
			player.body_id,
		)

	// World-space hand position for TPS/debug observation.
	return (
		rl.Vector3{
			player_pos.x,
			player_pos.y + 0.45,
			player_pos.z,
		} +
		camera_right * 0.48
	)
}

get_gun_aim_direction :: proc() -> rl.Vector3 {
	base :=
		get_gun_base_position()

	direction :=
		normalize_vector3(
			get_final_aim_target() -
			base,
		)

	if vector3_length_squared(
		direction,
	) <= 0.0001 {
		return get_aim_direction()
	}

	return direction
}

get_gun_muzzle_position :: proc() -> rl.Vector3 {
	base :=
		get_gun_base_position()

	return (
		base +
		get_gun_aim_direction() *
			GUN_BARREL_LENGTH
	)
}

get_gun_projectile_direction :: proc() -> rl.Vector3 {
	muzzle :=
		get_gun_muzzle_position()

	return normalize_vector3(
		get_final_aim_target() -
		muzzle,
	)
}

draw_gun :: proc() {
	base :=
		get_gun_base_position()

	direction :=
		get_gun_aim_direction()

	muzzle :=
		base +
		direction *
			GUN_BARREL_LENGTH

	// Temporary visible gun: a rotating barrel plus grip.
	// The barrel physically points at the selected target.
	rl.DrawCylinderEx(
		base,
		muzzle,
		0.075,
		0.055,
		8,
		rl.DARKGRAY,
	)

	rl.DrawSphere(
		muzzle,
		0.065,
		rl.GRAY,
	)

	grip_top :=
		base +
		direction *
			0.12

	grip_bottom :=
		grip_top +
		rl.Vector3{
			0,
			-0.28,
			0,
		} -
		direction *
			0.07

	rl.DrawCylinderEx(
		grip_top,
		grip_bottom,
		0.065,
		0.050,
		6,
		rl.GRAY,
	)
}

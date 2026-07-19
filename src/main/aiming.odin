package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import rlgl "vendor:raylib/rlgl"
import "core:math"
import "core:c"

AIM_MAX_RANGE :: 1000.0

// Circular free-aim region sized from screen height, so its physical
// screen-space shape stays circular on every aspect ratio.
FLOATING_CROSSHAIR_RADIUS_RATIO :: 0.38
FLOATING_CROSSHAIR_SPEED        :: 1.20
CAMERA_FOLLOW_START_RATIO       :: 0.93

aim_target: rl.Vector3
aim_target_initialized := false

auto_aim_enabled := true
floating_crosshair_offset: rl.Vector2
current_auto_aim_target := -1

// Debug rays are visible by default.
aim_debug_rays_enabled := true

Aim_Visibility_Result :: struct {
	hit: bool,
}

toggle_auto_aim :: proc() {
	auto_aim_enabled = !auto_aim_enabled
	floating_crosshair_offset = {}
	current_auto_aim_target = -1
}

toggle_aim_debug_rays :: proc() {
	aim_debug_rays_enabled = !aim_debug_rays_enabled
}

reset_aiming_state :: proc() {
	aim_target = {}
	aim_target_initialized = false
	floating_crosshair_offset = {}
	current_auto_aim_target = -1
}

update_aim_mode_input :: proc() {
	if rl.IsMouseButtonPressed(.MIDDLE) {
		toggle_auto_aim()
	}
}

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
	length :=
		math.sqrt(
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
	player_pos :=
		b3.Body_GetPosition(
			player.body_id,
		)

	return {
		player_pos.x,
		player_pos.y + PLAYER_EYE_HEIGHT,
		player_pos.z,
	}
}

get_floating_crosshair_radii :: proc() -> rl.Vector2 {
	radius :=
		f32(
			rl.GetScreenHeight(),
		) *
		FLOATING_CROSSHAIR_RADIUS_RATIO

	return {
		radius,
		radius,
	}
}

get_crosshair_screen_position :: proc() -> rl.Vector2 {
	center :=
		rl.Vector2{
			f32(rl.GetScreenWidth()) * 0.5,
			f32(rl.GetScreenHeight()) * 0.5,
		}

	if !auto_aim_enabled {
		return center
	}

	return center + floating_crosshair_offset
}

get_camera_follow_strength :: proc(
	normalized_radius: f32,
) -> f32 {
	if normalized_radius <=
	   CAMERA_FOLLOW_START_RATIO {
		return 0
	}

	t :=
		clamp(
			(
				normalized_radius -
				CAMERA_FOLLOW_START_RATIO
			) /
				(
					1.0 -
					CAMERA_FOLLOW_START_RATIO
				),
			0.0,
			1.0,
		)

	// Smoothstep.
	return t * t * (3.0 - 2.0 * t)
}

// The floating reticle is constrained to an ellipse. Mouse motion inside most
// of the ellipse moves only the reticle. Continuing to push outward near the
// boundary progressively rotates the camera.
update_floating_crosshair :: proc(
	mouse_delta: rl.Vector2,
) -> rl.Vector2 {
	if !auto_aim_enabled {
		floating_crosshair_offset = {}
		return mouse_delta
	}

	radii :=
		get_floating_crosshair_radii()

	floating_crosshair_offset +=
		mouse_delta *
		FLOATING_CROSSHAIR_SPEED

	normalized_x :=
		floating_crosshair_offset.x /
		radii.x

	normalized_y :=
		floating_crosshair_offset.y /
		radii.y

	normalized_radius :=
		math.sqrt(
			normalized_x * normalized_x +
			normalized_y * normalized_y,
		)

	if normalized_radius > 1.0 {
		floating_crosshair_offset /=
			normalized_radius

		normalized_radius = 1.0
	}

	// Elliptical radial dot product. Positive means the mouse is pushing
	// farther outward. Moving inward recenters the reticle without dragging
	// the camera back with it.
	outward_motion :=
		mouse_delta.x *
			floating_crosshair_offset.x /
			(radii.x * radii.x) +
		mouse_delta.y *
			floating_crosshair_offset.y /
			(radii.y * radii.y)

	if outward_motion <= 0 {
		return {}
	}

	follow_strength :=
		get_camera_follow_strength(
			normalized_radius,
		)

	return mouse_delta * follow_strength
}

get_raw_aim_ray :: proc() -> (
	origin,
	direction: rl.Vector3,
) {
	screen_position :=
		get_crosshair_screen_position()

	ray :=
		rl.GetScreenToWorldRay(
			screen_position,
			camera,
		)

	origin = ray.position
	direction =
		normalize_vector3(
			ray.direction,
		)

	return
}

get_raw_aim_target :: proc() -> rl.Vector3 {
	origin, direction :=
		get_raw_aim_ray()

	translation :=
		direction *
		AIM_MAX_RANGE

	hit :=
		cast_aim_ray(
			origin,
			translation,
		)

	if hit.hit {
		return (
			origin +
			translation *
				hit.fraction
		)
	}

	return origin + translation
}

get_final_aim_target :: proc() -> rl.Vector3 {
	if auto_aim_enabled &&
	   is_auto_aim_target_valid(
			current_auto_aim_target,
		) {
		return get_enemy_lock_position(
			current_auto_aim_target,
		)
	}

	if aim_target_initialized {
		return aim_target
	}

	return (
		get_aim_origin() +
		get_aim_direction() *
			AIM_MAX_RANGE
	)
}

update_aiming :: proc() {
	aim_target =
		get_raw_aim_target()

	aim_target_initialized =
		true

	update_auto_aim_target()
}

is_auto_aim_target_valid :: proc(
	index: int,
) -> bool {
	return (
		index >= 0 &&
		index < MAX_ENEMIES &&
		enemies[index].active &&
		enemies[index].alive
	)
}

// Auto aim is intentionally simple: among eligible on-screen enemies, select
// only the one whose lock point is closest to the floating crosshair in 2D.
// World-space distance does not affect selection.
update_auto_aim_target :: proc() {
	if !auto_aim_enabled {
		current_auto_aim_target = -1
		return
	}

	crosshair :=
		get_crosshair_screen_position()

	best_index := -1
	best_screen_distance: f32 = 1.0e30

	screen_width :=
		f32(rl.GetScreenWidth())

	screen_height :=
		f32(rl.GetScreenHeight())

	for i in 0..<MAX_ENEMIES {
		if !enemies[i].active ||
		   !enemies[i].alive {
			continue
		}

		lock_position :=
			get_enemy_lock_position(i)

		to_enemy :=
			lock_position -
			camera.position

		camera_forward :=
			camera.target -
			camera.position

		dot :=
			to_enemy.x * camera_forward.x +
			to_enemy.y * camera_forward.y +
			to_enemy.z * camera_forward.z

		if dot <= 0 {
			continue
		}

		if !is_enemy_visible_for_auto_aim(i) {
			continue
		}

		screen_position :=
			rl.GetWorldToScreen(
				lock_position,
				camera,
			)

		if screen_position.x < 0 ||
		   screen_position.x > screen_width ||
		   screen_position.y < 0 ||
		   screen_position.y > screen_height {
			continue
		}

		dx :=
			screen_position.x -
			crosshair.x

		dy :=
			screen_position.y -
			crosshair.y

		screen_distance :=
			math.sqrt(
				dx * dx +
				dy * dy,
			)

		if screen_distance <
		   best_screen_distance {
			best_screen_distance =
				screen_distance

			best_index = i
		}
	}

	current_auto_aim_target =
		best_index
}

is_enemy_visible_for_auto_aim :: proc(
	index: int,
) -> bool {
	if !is_auto_aim_target_valid(
		index,
	) {
		return false
	}

	target :=
		get_enemy_lock_position(
			index,
		)

	translation :=
		target -
		camera.position

	if vector3_length_squared(
		translation,
	) <= 0.000001 {
		return true
	}

	result :=
		Aim_Visibility_Result{}

	filter :=
		b3.DefaultQueryFilter()

	_ = b3.World_CastRay(
		world_id,
		{
			camera.position.x,
			camera.position.y,
			camera.position.z,
		},
		{
			translation.x,
			translation.y,
			translation.z,
		},
		filter,
		auto_aim_visibility_callback,
		&result,
	)

	return !result.hit
}

auto_aim_visibility_callback :: proc "c" (
	shape_id: b3.ShapeId,
	point: b3.Pos,
	normal: b3.Vec3,
	fraction: f32,
	user_material_id: u64,
	triangle_index: c.int,
	child_index: c.int,
	ctx: rawptr,
) -> f32 {
	body_id :=
		b3.Shape_GetBody(
			shape_id,
		)

	if body_id == player.body_id ||
	   get_enemy_index_from_body(
			body_id,
		) >= 0 {
		return -1
	}

	result := cast(^Aim_Visibility_Result)ctx

	result.hit = true

	return fraction
}

get_projectile_direction :: proc() -> rl.Vector3 {
	return normalize_vector3(
		get_final_aim_target() -
		get_aim_origin(),
	)
}

cast_aim_ray :: proc(
	position: rl.Vector3,
	translation: rl.Vector3,
) -> Projectile_Cast_Result {
	result :=
		Projectile_Cast_Result{}

	filter :=
		b3.DefaultQueryFilter()

	_ = b3.World_CastRay(
		world_id,
		{
			position.x,
			position.y,
			position.z,
		},
		{
			translation.x,
			translation.y,
			translation.z,
		},
		filter,
		projectile_cast_callback,
		&result,
	)

	return result
}

draw_debug_ray_segment :: proc(
	start,
	end: rl.Vector3,
	color: rl.Color,
) {
	if vector3_distance(
		start,
		end,
	) <= 0.0001 {
		return
	}

	rl.DrawLine3D(
		start,
		end,
		color,
	)
}

draw_aim_debug_ray :: proc() {
	if !aim_debug_rays_enabled {
		return
	}

	raw_origin, raw_direction :=
		get_raw_aim_ray()

	raw_translation :=
		raw_direction *
		PROJECTILE_MAX_RANGE

	raw_hit :=
		cast_aim_ray(
			raw_origin,
			raw_translation,
		)

	raw_end :=
		raw_origin +
		raw_translation

	if raw_hit.hit {
		raw_end =
			raw_origin +
			raw_translation *
				raw_hit.fraction
	}

	// Both debug rays deliberately start at the visible gun muzzle.
	// Cyan shows where the floating crosshair itself points.
	// Yellow shows the final auto-aim firing direction.
	visual_origin :=
		get_gun_muzzle_position()

	final_direction :=
		get_gun_projectile_direction()

	final_translation :=
		final_direction *
		PROJECTILE_MAX_RANGE

	final_hit :=
		cast_projectile(
			visual_origin,
			final_translation,
		)

	final_end :=
		visual_origin +
		final_translation

	if final_hit.hit {
		final_end =
			visual_origin +
			final_translation *
				final_hit.fraction
	}

	rlgl.DisableDepthTest()

	draw_debug_ray_segment(
		visual_origin,
		raw_end,
		rl.SKYBLUE,
	)

	draw_debug_ray_segment(
		visual_origin,
		final_end,
		rl.YELLOW,
	)

	rlgl.EnableDepthTest()
}

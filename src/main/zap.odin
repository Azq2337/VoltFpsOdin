package main

import rl "vendor:raylib"
import "core:math"

MAX_ZAP_ARCS          :: 3
ZAP_POINT_COUNT       :: 12
ZAP_REFRESH_INTERVAL  :: 0.04
ZAP_JITTER            :: 0.35
ZAP_RING_RADIUS       :: 0.8

zap_active := false
zap_refresh_timer: f32

zap_points: [MAX_ZAP_ARCS][ZAP_POINT_COUNT]rl.Vector3

update_zap :: proc() {
	zap_active =
		rl.IsMouseButtonDown(.RIGHT) &&
		enemy.tag_count > 0

	if !zap_active {
		zap_refresh_timer = 0
		return
	}

	zap_refresh_timer -= TIME_STEP

	if zap_refresh_timer <= 0 {
		generate_zap_arcs()
		zap_refresh_timer = ZAP_REFRESH_INTERVAL
	}
}

generate_zap_arcs :: proc() {
	target := get_enemy_lock_position()

	for arc in 0..<enemy.tag_count {
		start := get_zap_anchor(arc)

		zap_points[arc][0] = start

		// Completely different initial direction for each bolt.
		launch_direction := normalize_vector3(
			rl.Vector3{
				random_zap_offset(),
				random_zap_offset(),
				random_zap_offset(),
			},
		)

		current := start

		for i in 1..<ZAP_POINT_COUNT - 1 {
			t := f32(i) / f32(ZAP_POINT_COUNT - 1)

			to_target := normalize_vector3(target - current)

			// Weak attraction initially, very strong attraction near the end.
			target_pull := t * t

			direction := normalize_vector3(
				launch_direction * (1.0 - target_pull) +
				to_target * target_pull,
			)

			// Keep introducing chaos throughout the path.
			random_direction := normalize_vector3(
				rl.Vector3{
					random_zap_offset(),
					random_zap_offset(),
					random_zap_offset(),
				},
			)

			direction = normalize_vector3(
				direction +
				random_direction * 0.65 * (1.0 - t),
			)

			distance_left := vector3_distance(current, target)
			points_left := f32(ZAP_POINT_COUNT - i)

			step_length := distance_left / points_left

			current += direction * step_length

			zap_points[arc][i] = current
		}

		zap_points[arc][ZAP_POINT_COUNT - 1] = target
	}
}

vector3_distance :: proc(a, b: rl.Vector3) -> f32 {
	d := b - a
	return math.sqrt(
		d.x * d.x +
		d.y * d.y +
		d.z * d.z,
	)
}

random_zap_offset :: proc() -> f32 {
	return f32(rl.GetRandomValue(-1000, 1000)) / 1000.0
}

get_zap_origin :: proc() -> rl.Vector3 {
	direction := get_projectile_direction()

	return get_aim_origin() +
		direction * 0.6 +
		rl.Vector3{0, -0.2, 0}
}

draw_zap_arcs :: proc() {
	if !zap_active {
		return
	}

	for arc in 0..<enemy.tag_count {
		for i in 0..<ZAP_POINT_COUNT - 1 {
			start := zap_points[arc][i]
			end   := zap_points[arc][i + 1]

			// Wide glow.
			rl.DrawCylinderEx(
				start,
				end,
				0.065,
				0.065,
				6,
				rl.Color{30, 100, 255, 70},
			)

			// Electric-blue body.
			rl.DrawCylinderEx(
				start,
				end,
				0.032,
				0.032,
				6,
				rl.Color{30, 200, 255, 220},
			)

			// Hot white core.
			rl.DrawCylinderEx(
				start,
				end,
				0.012,
				0.012,
				6,
				rl.Color{220, 250, 255, 255},
			)
		}
	}
}

get_zap_anchor :: proc(arc_index: int) -> rl.Vector3 {
	center := get_aim_origin()

	to_target := normalize_vector3(
		get_enemy_lock_position() - center,
	)

	world_up := rl.Vector3{0, 1, 0}

	right := normalize_vector3(
		rl.Vector3CrossProduct(world_up, to_target),
	)

	up := normalize_vector3(
		rl.Vector3CrossProduct(to_target, right),
	)

	angle := f32(arc_index) * 120.0

	offset :=
		right * math.cos(math.to_radians(angle)) +
		up    * math.sin(math.to_radians(angle))

	return center + offset * ZAP_RING_RADIUS
}


package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import rlgl "vendor:raylib/rlgl"
import "core:c"
import "core:math"

MAX_ZAP_ARCS          :: 3
ZAP_POINT_COUNT       :: 12
ZAP_REFRESH_INTERVAL  :: 0.04
ZAP_JITTER            :: 0.35
ZAP_RING_RADIUS       :: 0.8
FLASHFIELD_INNER_RADIUS_RATIO :: 0.38
FLASHFIELD_BANDS              :: 16
FLASHFIELD_RADIUS             :: 2.5

zap_active := false
zap_refresh_timer: f32
flashfield_active := false

zap_points: [MAX_ZAP_ARCS][ZAP_POINT_COUNT]rl.Vector3
flashfield_model:  rl.Model
flashfield_shader: rl.Shader
flashfield_camera_pos_loc: c.int
flashfield_center_loc:     c.int
flashfield_camera_forward_loc: c.int

update_zap :: proc() {
	flashfield_active = rl.IsMouseButtonDown(.RIGHT)

	zap_active =
		flashfield_active &&
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

init_flashfield :: proc() {
	mesh := rl.GenMeshSphere(
		FLASHFIELD_RADIUS,
		32,
		32,
	)

	flashfield_model =
		rl.LoadModelFromMesh(mesh)

	flashfield_shader =
		rl.LoadShader(
			"asset/shader/flashfield.vs",
			"asset/shader/flashfield.fs",
		)

	flashfield_model.materials[0].shader =
		flashfield_shader

	flashfield_camera_pos_loc =
		rl.GetShaderLocation(
			flashfield_shader,
			"cameraPos",
		)

	flashfield_center_loc =
		rl.GetShaderLocation(
			flashfield_shader,
			"fieldCenter",
		)

	flashfield_camera_forward_loc =
	rl.GetShaderLocation(
		flashfield_shader,
		"cameraForward",
	)
}

draw_flashfield :: proc() {
	if !flashfield_active {
		return
	}

	player_pos :=
		b3.Body_GetPosition(player.body_id)

	center := rl.Vector3{
		player_pos.x,
		player_pos.y,
		player_pos.z,
	}

	camera_pos := camera.position

	rl.SetShaderValue(
		flashfield_shader,
		flashfield_camera_pos_loc,
		&camera_pos,
		.VEC3,
	)

	rl.SetShaderValue(
		flashfield_shader,
		flashfield_center_loc,
		&center,
		.VEC3,
	)

	camera_forward := normalize_vector3(
		camera.target - camera.position,
	)

	rl.SetShaderValue(
		flashfield_shader,
		flashfield_camera_forward_loc,
		&camera_forward,
		.VEC3,
	)

	rl.BeginBlendMode(.ADDITIVE)

	// Required because FPS camera is inside the sphere.
	rlgl.DisableBackfaceCulling()

	// Transparent sphere should not block lightning drawn later.
	rlgl.DisableDepthMask()

	rl.DrawModel(
		flashfield_model,
		center,
		1.0,
		rl.WHITE,
	)

	rlgl.EnableDepthMask()
	rlgl.EnableBackfaceCulling()

	rl.EndBlendMode()
}

shutdown_flashfield :: proc() {
	rl.UnloadShader(flashfield_shader)
	rl.UnloadModel(flashfield_model)
}


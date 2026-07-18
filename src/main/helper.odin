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

	tps_text: cstring = "Third Person: OFF"
	if third_person_enabled {
		tps_text = "Third Person: ON"
	}

	if menu_button(menu_x, 320, 300, 50, tps_text) {
		toggle_third_person_camera()
		return
	}

	debug_text: cstring = "Debug Camera: OFF"
	if debug_camera_enabled {
		debug_text = "Debug Camera: ON"
	}

	if menu_button(menu_x, 390, 300, 50, debug_text) {
		toggle_debug_camera()
		return
	}

	if menu_button(menu_x, 490, 300, 50, "Exit") {
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

draw_crosshair :: proc() {
	if debug_camera_enabled {
		return
	}

	x := rl.GetScreenWidth() / 2
	y := rl.GetScreenHeight() / 2

	// Primary crosshair: always the exact center of the active camera.
	draw_crosshair_segment(
		{f32(x), f32(y - CROSSHAIR_GAP - CROSSHAIR_LENGTH)},
		{f32(x), f32(y - CROSSHAIR_GAP)},
	)
	draw_crosshair_segment(
		{f32(x), f32(y + CROSSHAIR_GAP)},
		{f32(x), f32(y + CROSSHAIR_GAP + CROSSHAIR_LENGTH)},
	)
	draw_crosshair_segment(
		{f32(x - CROSSHAIR_GAP - CROSSHAIR_LENGTH), f32(y)},
		{f32(x - CROSSHAIR_GAP), f32(y)},
	)
	draw_crosshair_segment(
		{f32(x + CROSSHAIR_GAP), f32(y)},
		{f32(x + CROSSHAIR_GAP + CROSSHAIR_LENGTH), f32(y)},
	)

	// Secondary circle: where the physical projectile sphere will first stop.
	direction := get_projectile_direction()
	origin := get_aim_origin() + direction * PROJECTILE_SPAWN_OFFSET
	translation := direction * PROJECTILE_MAX_RANGE
	hit := cast_projectile(origin, translation)

	if hit.hit {
		impact_position :=
			origin +
			translation * hit.fraction

		to_hit := impact_position - camera.position
		camera_forward := camera.target - camera.position
		dot :=
			to_hit.x * camera_forward.x +
			to_hit.y * camera_forward.y +
			to_hit.z * camera_forward.z

		if dot > 0 {
			screen_pos := rl.GetWorldToScreen(impact_position, camera)

			hit_hint_color_timer -= TIME_STEP
			if hit_hint_color_timer <= 0 {
				hit_hint_color = get_screen_contrast_color(screen_pos)
				hit_hint_color_timer = HIT_HINT_COLOR_INTERVAL
			}

			rl.DrawCircleLines(
				i32(screen_pos.x),
				i32(screen_pos.y),
				HIT_HINT_RADIUS,
				hit_hint_color,
			)
		}
	}
}

draw_crosshair_segment :: proc(start_pos, end_pos: rl.Vector2) {
	rl.DrawLineEx(
		start_pos,
		end_pos,
		CROSSHAIR_BORDER_THICKNESS,
		rl.WHITE,
	)

	rl.DrawLineEx(
		start_pos,
		end_pos,
		CROSSHAIR_LINE_THICKNESS,
		rl.BLACK,
	)
}

get_screen_contrast_color :: proc(screen_pos: rl.Vector2) -> rl.Color {
	image := rl.LoadImageFromScreen()
	defer rl.UnloadImage(image)

	x := clamp(i32(screen_pos.x), 0, image.width - 1)
	y := clamp(i32(screen_pos.y), 0, image.height - 1)
	background := rl.GetImageColor(image, x, y)

	// Pick whichever of black or white has stronger luminance contrast.
	luminance :=
		(i32(background.r) * 299 +
		 i32(background.g) * 587 +
		 i32(background.b) * 114) / 1000

	if luminance >= 128 {
		return rl.BLACK
	}

	return rl.WHITE
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

	rl.DrawLine3D(origin, end, rl.GREEN)
}

draw_enemy_health_bar :: proc() {
	enemy_pos := b3.Body_GetPosition(enemy.body_id)

	world_pos := rl.Vector3{
		enemy_pos.x,
		enemy_pos.y + ENEMY_HALF_HEIGHT + ENEMY_RADIUS + ENEMY_HEALTH_BAR_OFFSET,
		enemy_pos.z,
	}

	// check if enemy is behind player so health bar is not drawn
	to_enemy := world_pos - camera.position
	camera_forward := camera.target - camera.position
	dot :=
		to_enemy.x * camera_forward.x +
		to_enemy.y * camera_forward.y +
		to_enemy.z * camera_forward.z
	if dot <= 0 {
		return
	}

	screen_pos := rl.GetWorldToScreen(world_pos, camera)

	health_ratio := enemy.health / enemy.max_health

	bar_x := i32(screen_pos.x) - ENEMY_HEALTH_BAR_WIDTH / 2
	bar_y := i32(screen_pos.y)

	rl.DrawRectangle(
		bar_x,
		bar_y,
		ENEMY_HEALTH_BAR_WIDTH,
		ENEMY_HEALTH_BAR_HEIGHT,
		rl.DARKGRAY,
	)

	rl.DrawRectangle(
		bar_x,
		bar_y,
		i32(f32(ENEMY_HEALTH_BAR_WIDTH) * health_ratio),
		ENEMY_HEALTH_BAR_HEIGHT,
		rl.RED,
	)
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

/* Aim */
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

/* Check */
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

toggle_third_person_camera :: proc() {
	third_person_enabled = !third_person_enabled
	camera_mode_changed = true
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

		direction := get_projectile_direction()
		spawn_pos := get_aim_origin() + direction * PROJECTILE_SPAWN_OFFSET

		projectiles[i] = Projectile{
			position = spawn_pos,
			velocity = direction * PROJECTILE_SPEED,
			active   = true,
		}

		break
	}
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
	result.point = point
	result.fraction = fraction

	// Clip the cast to this hit.
	return fraction
}

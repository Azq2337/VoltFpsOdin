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
PLAYER_DASH_DURATION  :: 0.20
PLAYER_DASH_COOLDOWN  :: 0.10

HOVER_GRAVITY_SCALE   :: 0.20
HOVER_MAX_FALL_SPEED  :: 2.2

GROUND_CHECK_RADIUS   :: PLAYER_RADIUS * 0.9
GROUND_CHECK_DISTANCE :: 0.12
GROUND_NORMAL_MIN_Y   :: 0.5

// Any sufficiently vertical surface can participate in sliding/bouncing.
// This includes room walls, platform/road-bump faces, and enemy capsule sides.
SURFACE_CHECK_RADIUS          :: PLAYER_RADIUS * 0.95
SURFACE_CHECK_DISTANCE        :: 0.14
SURFACE_NORMAL_MAX_Y          :: 0.5
SURFACE_SLIDE_MIN_FALL_SPEED  :: 2.5
SURFACE_JUMP_UP_SPEED         :: 7.0
SURFACE_JUMP_AWAY_SPEED       :: 4.5
SURFACE_RESTICK_COOLDOWN      :: 0.18

MAX_SURFACE_SMOKE_PARTICLES :: 64
SURFACE_SMOKE_INTERVAL      :: 0.06

Player :: struct {
	body_id: b3.BodyId,

	dash_time_left:     f32,
	dash_cooldown_left: f32,
	dash_direction:     rl.Vector3,

	dash_jump_active: bool,

	surface_contact:          bool,
	surface_normal:           rl.Vector3,
	surface_contact_point:    rl.Vector3,
	surface_restick_cooldown: f32,
	surface_smoke_timer:      f32,
}

Surface_Cast_Result :: struct {
	hit:      bool,
	point:    rl.Vector3,
	normal:   rl.Vector3,
	fraction: f32,
}

Surface_Smoke_Particle :: struct {
	active:   bool,
	position: rl.Vector3,
	velocity: rl.Vector3,
	life:     f32,
	max_life: f32,
	radius:   f32,
}

player: Player

surface_smoke_particles : [MAX_SURFACE_SMOKE_PARTICLES]Surface_Smoke_Particle

create_player :: proc(
	world_id: b3.WorldId,
) -> Player {
	body_def :=
		b3.DefaultBodyDef()

	body_def.type =
		.dynamicBody

	body_def.position =
		{0, 2, 5}

	body_def.enableSleep =
		false

	body_def.enableContactRecycling =
		false

	// FPS character should stay upright.
	body_def.motionLocks.angularX = true
	body_def.motionLocks.angularY = true
	body_def.motionLocks.angularZ = true

	body_id :=
		b3.CreateBody(
			world_id,
			body_def,
		)

	capsule := b3.Capsule{
		center1 = {
			0,
			-PLAYER_HALF_HEIGHT,
			0,
		},
		center2 = {
			0,
			PLAYER_HALF_HEIGHT,
			0,
		},
		radius = PLAYER_RADIUS,
	}

	shape_def :=
		b3.DefaultShapeDef()

	shape_def.density = 1
	shape_def.baseMaterial.friction = 0

	_ = b3.CreateCapsuleShape(
		body_id,
		shape_def,
		&capsule,
	)

	return Player{
		body_id = body_id,
	}
}

draw_player :: proc() {
	draw_surface_smoke()

	if !debug_camera_enabled &&
	   !third_person_enabled {
		return
	}

	pos :=
		b3.Body_GetPosition(
			player.body_id,
		)

	start := rl.Vector3{
		pos.x,
		pos.y -
			PLAYER_HALF_HEIGHT,
		pos.z,
	}

	end := rl.Vector3{
		pos.x,
		pos.y +
			PLAYER_HALF_HEIGHT,
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
	update_surface_smoke()

	velocity :=
		b3.Body_GetLinearVelocity(
			player.body_id,
		)

	grounded :=
		is_player_grounded()

	/* Movement input */

	move := rl.Vector3{}

	yaw :=
		math.to_radians(
			camera_yaw,
		)

	forward :=
		rl.Vector3{
			math.sin(yaw),
			0,
			-math.cos(yaw),
		}

	right :=
		rl.Vector3{
			math.cos(yaw),
			0,
			math.sin(yaw),
		}

	if rl.IsKeyDown(.W) { move += forward }
	if rl.IsKeyDown(.S) { move -= forward }
	if rl.IsKeyDown(.D) { move += right }
	if rl.IsKeyDown(.A) { move -= right }

	move_length :=
		math.sqrt(
			move.x * move.x +
			move.z * move.z,
		)

	if move_length > 0 {
		move /= move_length
	}

	/* Timers */

	player.dash_time_left =
		max(
			player.dash_time_left -
				TIME_STEP,
			0,
		)

	player.dash_cooldown_left =
		max(
			player.dash_cooldown_left -
				TIME_STEP,
			0,
		)

	player.surface_restick_cooldown =
		max(
			player.surface_restick_cooldown -
				TIME_STEP,
			0,
		)

	/* Dash */

	if rl.IsKeyPressed(.LEFT_SHIFT) &&
	   player.dash_cooldown_left <= 0 {
		player.dash_direction = move

		if move_length == 0 {
			player.dash_direction =
				forward
		}

		player.dash_time_left =
			PLAYER_DASH_DURATION

		player.dash_cooldown_left =
			PLAYER_DASH_COOLDOWN
	}

	/* Nearby blocking-surface detection.
	   This is independent of movement input so airborne bounce still works
	   when the player releases WASD before pressing Space. */

	player.surface_contact = false

	if player.surface_restick_cooldown <= 0 {
		surface_hit :=
			find_player_blocking_surface()

		if surface_hit.hit {
			player.surface_contact = true
			player.surface_normal = surface_hit.normal
			player.surface_contact_point = surface_hit.point
		}
	}

	if grounded {
		player.dash_jump_active = false
	}

	/* Jump / surface bounce */

	surface_jumped := false
	jumped := false

	if rl.IsKeyPressed(.SPACE) {
		if !grounded &&
		   player.surface_contact {
			velocity.y =
				SURFACE_JUMP_UP_SPEED

			velocity.x =
				player.surface_normal.x *
				SURFACE_JUMP_AWAY_SPEED

			velocity.z =
				player.surface_normal.z *
				SURFACE_JUMP_AWAY_SPEED

			player.surface_contact = false

			player.surface_restick_cooldown =
				SURFACE_RESTICK_COOLDOWN

			player.dash_jump_active =
				false

			spawn_surface_smoke(
				player.surface_contact_point,
				player.surface_normal,
				10,
			)

			surface_jumped = true
		} else if grounded {
			velocity.y =
				PLAYER_JUMP_SPEED

			jumped = true

			// Dash-jump does not lock momentum. Instead it unlocks
			// dash-speed air control while movement keys are held.
			player.dash_jump_active =
				player.dash_time_left >
				0
		}
	}

	/* Horizontal movement */

	if !surface_jumped {
		if player.dash_jump_active &&
		   (jumped || !grounded) {
			velocity.x =
				move.x *
				PLAYER_DASH_SPEED

			velocity.z =
				move.z *
				PLAYER_DASH_SPEED
		} else if player.dash_time_left > 0 {
			velocity.x =
				player.dash_direction.x *
				PLAYER_DASH_SPEED

			velocity.z =
				player.dash_direction.z *
				PLAYER_DASH_SPEED
		} else {
			velocity.x =
				move.x *
				PLAYER_SPEED

			velocity.z =
				move.z *
				PLAYER_SPEED
		}

		// Explicitly remove only the component that pushes into a nearby
		// blocking surface. Tangential velocity is preserved at full speed,
		// so the player slides along walls, obstacle faces, and enemies instead
		// of relying on Box3D's platform-dependent contact response.
		horizontal_speed :=
			math.sqrt(
				velocity.x * velocity.x +
				velocity.z * velocity.z,
			)

		if horizontal_speed > 0.0001 {
			horizontal_direction :=
				rl.Vector3{
					velocity.x / horizontal_speed,
					0,
					velocity.z / horizontal_speed,
				}

			movement_hit :=
				cast_player_blocking_surface(
					horizontal_direction,
				)

			if movement_hit.hit {
				normal :=
					normalize_horizontal(
						movement_hit.normal,
					)

				into_surface :=
					velocity.x * normal.x +
					velocity.z * normal.z

				if into_surface < 0 {
					velocity.x -=
						normal.x *
						into_surface

					velocity.z -=
						normal.z *
						into_surface

					projected_speed :=
						math.sqrt(
							velocity.x * velocity.x +
							velocity.z * velocity.z,
						)

					// Keep full requested speed along the tangent. A direct
					// push into the surface still correctly results in zero.
					if projected_speed > 0.0001 {
						scale :=
							horizontal_speed /
							projected_speed

						velocity.x *= scale
						velocity.z *= scale
					}
				}
			}
		}
	}

	/* Vertical surface slide.
	   Keep a minimum downward speed so contacts cannot pin the player in
	   place. This is deliberately generic rather than wall-specific. */

	if !grounded &&
	   player.surface_contact &&
	   velocity.y < 0 {
		if velocity.y >
		   -SURFACE_SLIDE_MIN_FALL_SPEED {
			velocity.y =
				-SURFACE_SLIDE_MIN_FALL_SPEED
		}

		player.surface_smoke_timer -=
			TIME_STEP

		if player.surface_smoke_timer <= 0 {
			spawn_surface_smoke(
				player.surface_contact_point,
				player.surface_normal,
				2,
			)

			player.surface_smoke_timer =
				SURFACE_SMOKE_INTERVAL
		}
	} else {
		player.surface_smoke_timer = 0
	}

	/* Flashfield hover */

	if rl.IsMouseButtonDown(.RIGHT) &&
	   !player.surface_contact &&
	   velocity.y < 0 {
		// Flashfield is available even without a tagged enemy.
		// Cancel most of the gravity Box3D will apply this frame.
		velocity.y +=
			9.8 *
			(1.0 -
				HOVER_GRAVITY_SCALE) *
			TIME_STEP

		if velocity.y <
		   -HOVER_MAX_FALL_SPEED {
			velocity.y =
				-HOVER_MAX_FALL_SPEED
		}
	}

	b3.Body_SetLinearVelocity(
		player.body_id,
		velocity,
	)
}

normalize_horizontal :: proc(
	value: rl.Vector3,
) -> rl.Vector3 {
	length :=
		math.sqrt(
			value.x * value.x +
			value.z * value.z,
		)

	if length <= 0.0001 {
		return rl.Vector3{}
	}

	return rl.Vector3{
		value.x / length,
		0,
		value.z / length,
	}
}

find_player_blocking_surface :: proc() -> Surface_Cast_Result {
	directions := [8]rl.Vector3{
		{ 1, 0,  0},
		{-1, 0,  0},
		{ 0, 0,  1},
		{ 0, 0, -1},
		{ 0.7071068, 0,  0.7071068},
		{-0.7071068, 0,  0.7071068},
		{ 0.7071068, 0, -0.7071068},
		{-0.7071068, 0, -0.7071068},
	}

	best := Surface_Cast_Result{
		fraction = 2.0,
	}

	for direction in directions {
		result :=
			cast_player_blocking_surface(
				direction,
			)

		if result.hit &&
		   result.fraction < best.fraction {
			best = result
		}
	}

	return best
}

cast_player_blocking_surface :: proc(
	direction: rl.Vector3,
) -> Surface_Cast_Result {
	player_pos :=
		b3.Body_GetPosition(
			player.body_id,
		)

	// Cast a capsule-shaped proxy instead of a single sphere so low obstacle
	// faces and taller blockers are detected across the player's full body.
	proxy_points := [2]b3.Vec3{
		{0, -PLAYER_HALF_HEIGHT, 0},
		{0,  PLAYER_HALF_HEIGHT, 0},
	}

	proxy := b3.ShapeProxy{
		points = &proxy_points[0],
		count  = 2,
		radius =
			SURFACE_CHECK_RADIUS,
	}

	result :=
		Surface_Cast_Result{}

	filter :=
		b3.DefaultQueryFilter()

	translation :=
		direction *
		SURFACE_CHECK_DISTANCE

	_ = b3.World_CastShape(
		world_id,
		{
			player_pos.x,
			player_pos.y,
			player_pos.z,
		},
		proxy,
		{
			translation.x,
			translation.y,
			translation.z,
		},
		filter,
		blocking_surface_cast_callback,
		&result,
	)

	return result
}

blocking_surface_cast_callback :: proc "c" (
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

	// Ignore only the player's own capsule. Enemy bodies intentionally count
	// as blocking surfaces, exactly like level geometry.
	if body_id == player.body_id {
		return -1
	}

	// Floors and ceilings do not participate in horizontal surface sliding or
	// wall-style bouncing. Steep/vertical faces do.
	if normal.y >
	   SURFACE_NORMAL_MAX_Y ||
	   normal.y <
	   -SURFACE_NORMAL_MAX_Y {
		return -1
	}

	result :=
		cast(^Surface_Cast_Result)ctx

	result.hit = true
	result.point = {
		point.x,
		point.y,
		point.z,
	}
	result.normal = {
		normal.x,
		normal.y,
		normal.z,
	}
	result.fraction = fraction

	return fraction
}

is_player_grounded :: proc() -> bool {
	velocity :=
		b3.Body_GetLinearVelocity(
			player.body_id,
		)

	if velocity.y > 0.1 {
		return false
	}

	player_pos :=
		b3.Body_GetPosition(
			player.body_id,
		)

	origin :=
		rl.Vector3{
			player_pos.x,
			player_pos.y -
				PLAYER_HALF_HEIGHT,
			player_pos.z,
		}

	center := b3.Vec3{}

	proxy := b3.ShapeProxy{
		points = &center,
		count  = 1,
		radius =
			GROUND_CHECK_RADIUS,
	}

	result :=
		Projectile_Cast_Result{}

	filter :=
		b3.DefaultQueryFilter()

	_ = b3.World_CastShape(
		world_id,
		{
			origin.x,
			origin.y,
			origin.z,
		},
		proxy,
		{
			0,
			-GROUND_CHECK_DISTANCE,
			0,
		},
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
	body_id :=
		b3.Shape_GetBody(
			shape_id,
		)

	if body_id == player.body_id ||
	   get_enemy_index_from_body(body_id) >= 0 {
		return -1
	}

	if normal.y <
	   GROUND_NORMAL_MIN_Y {
		return -1
	}

	result :=
		cast(^Projectile_Cast_Result)ctx

	result.hit = true
	result.shape_id = shape_id
	result.point = point
	result.fraction = fraction

	return fraction
}

spawn_surface_smoke :: proc(
	contact: rl.Vector3,
	normal: rl.Vector3,
	count: int,
) {
	for _ in 0..<count {
		for i in 0..<MAX_SURFACE_SMOKE_PARTICLES {
			if surface_smoke_particles[i].active {
				continue
			}

			random_x :=
				f32(
					rl.GetRandomValue(
						-100,
						100,
					),
				) /
				100.0

			random_y :=
				f32(
					rl.GetRandomValue(
						0,
						100,
					),
				) /
				100.0

			random_z :=
				f32(
					rl.GetRandomValue(
						-100,
						100,
					),
				) /
				100.0

			life :=
				0.25 +
				f32(
					rl.GetRandomValue(
						0,
						25,
					),
				) /
					100.0

			surface_smoke_particles[i] =
				Surface_Smoke_Particle{
					active = true,
					position =
						contact +
						normal *
							0.05 +
						rl.Vector3{
							random_x *
								0.08,
							-PLAYER_HALF_HEIGHT *
								0.35 +
								random_y *
									0.12,
							random_z *
								0.08,
						},
					velocity =
						normal *
							(
								0.25 +
								random_y *
									0.35
							) +
						rl.Vector3{
							random_x *
								0.25,
							0.30 +
								random_y *
									0.50,
							random_z *
								0.25,
						},
					life = life,
					max_life = life,
					radius =
						0.035 +
						random_y *
							0.035,
				}

			break
		}
	}
}

update_surface_smoke :: proc() {
	for i in 0..<MAX_SURFACE_SMOKE_PARTICLES {
		if !surface_smoke_particles[i].active {
			continue
		}

		particle :=
			&surface_smoke_particles[i]

		particle.life -=
			TIME_STEP

		if particle.life <= 0 {
			particle.active =
				false

			continue
		}

		particle.position +=
			particle.velocity *
			TIME_STEP

		particle.velocity.y +=
			0.5 *
			TIME_STEP

		particle.velocity.x *=
			0.97

		particle.velocity.z *=
			0.97
	}
}

draw_surface_smoke :: proc() {
	for particle in surface_smoke_particles {
		if !particle.active {
			continue
		}

		fade :=
			clamp(
				particle.life /
					particle.max_life,
				0.0,
				1.0,
			)

		rl.DrawSphere(
			particle.position,
			particle.radius,
			rl.Color{
				180,
				180,
				180,
				u8(
					fade *
						180.0,
				),
			},
		)
	}
}

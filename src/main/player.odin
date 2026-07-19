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
// ground check
GROUND_CHECK_RADIUS   :: PLAYER_RADIUS * 0.9
GROUND_CHECK_DISTANCE :: 0.12
GROUND_NORMAL_MIN_Y   :: 0.5
// hover
HOVER_GRAVITY_SCALE   :: 0.20
HOVER_MAX_FALL_SPEED  :: 2.2
// wall bounce
WALL_CHECK_RADIUS        :: PLAYER_RADIUS * 0.95
WALL_CHECK_DISTANCE      :: 0.14
WALL_NORMAL_MAX_Y        :: 0.25
WALL_SLIDE_START_GRAVITY :: 1.0
WALL_SLIDE_GRAVITY_RAMP  :: 10.0
WALL_JUMP_UP_SPEED       :: 7.0
WALL_JUMP_AWAY_SPEED     :: 4.5
WALL_RESTICK_COOLDOWN    :: 0.18
MAX_WALL_SMOKE_PARTICLES :: 64
WALL_SMOKE_INTERVAL      :: 0.06

Player :: struct {
	body_id: b3.BodyId,

	dash_time_left:     f32,
	dash_cooldown_left: f32,
	dash_direction:     rl.Vector3,
	dash_jump_active:    bool,

	wall_sliding:          bool,
	wall_normal:           rl.Vector3,
	wall_slide_gravity:    f32,
	wall_restick_cooldown: f32,
	wall_contact_point: rl.Vector3,
	wall_smoke_timer:   f32,
}
Wall_Cast_Result :: struct {
	hit:    bool,
	point:  rl.Vector3,
	normal: rl.Vector3,
}
Wall_Smoke_Particle :: struct {
	active:   bool,
	position: rl.Vector3,
	velocity: rl.Vector3,
	life:     f32,
	max_life: f32,
	radius:   f32,
}

player: Player
wall_smoke_particles: [MAX_WALL_SMOKE_PARTICLES]Wall_Smoke_Particle

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
		wall_slide_gravity = WALL_SLIDE_START_GRAVITY,
	}
}

draw_player :: proc() {
	draw_wall_smoke()

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

update_player :: proc() {
	velocity := b3.Body_GetLinearVelocity(player.body_id)
	grounded := is_player_grounded()
	update_wall_smoke()

	/* Movement input */

	move := rl.Vector3{}

	yaw := math.to_radians(camera_yaw)

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

	player.wall_restick_cooldown =
		max(
			player.wall_restick_cooldown -
				TIME_STEP,
			0,
		)

	/*
	Dash.

	Cooldown is shorter than duration, so pressing Shift again
	restarts the dash before the previous one has finished.
	*/

	if rl.IsKeyPressed(.LEFT_SHIFT) &&
	   player.dash_cooldown_left <= 0 {
		player.dash_direction = move

		if move_length == 0 {
			player.dash_direction = forward
		}

		player.dash_time_left =
			PLAYER_DASH_DURATION

		player.dash_cooldown_left =
			PLAYER_DASH_COOLDOWN
	}

	/* Wall detection */

	was_wall_sliding :=
		player.wall_sliding

	player.wall_sliding = false

	if !grounded &&
	   move_length > 0 &&
	   player.wall_restick_cooldown <= 0 {
		wall_hit :=
			cast_player_wall(move)

		if wall_hit.hit {
			player.wall_sliding = true
			player.wall_normal = wall_hit.normal
			player.wall_contact_point = wall_hit.point
		}
	}

	// Only reset stickiness when we actually touch/re-touch
	// a wall, not every frame we remain on it.
	if player.wall_sliding &&
	   !was_wall_sliding {
		player.wall_slide_gravity =
			WALL_SLIDE_START_GRAVITY
	}

	if grounded {
		player.wall_sliding = false

		player.wall_slide_gravity =
			WALL_SLIDE_START_GRAVITY

		player.dash_jump_active =
			false
	}

	/* Jump */

	wall_jumped := false

	if rl.IsKeyPressed(.SPACE) {
		if player.wall_sliding {
			/*
			Wall bounce:
			upward + away from wall.
			*/

			velocity.y =
				WALL_JUMP_UP_SPEED

			velocity.x =
				player.wall_normal.x *
				WALL_JUMP_AWAY_SPEED

			velocity.z =
				player.wall_normal.z *
				WALL_JUMP_AWAY_SPEED

			player.wall_sliding = false

			player.wall_restick_cooldown =
				WALL_RESTICK_COOLDOWN

			player.wall_slide_gravity =
				WALL_SLIDE_START_GRAVITY

			player.dash_jump_active =
				false

			spawn_wall_smoke(
				player.wall_contact_point,
				player.wall_normal,
				10,
			)
			
			wall_jumped = true

		} else if grounded {
			velocity.y =
				PLAYER_JUMP_SPEED

			/*
			Dash-jump:
			jumping while the dash is active carries the
			dash's horizontal speed into the air.
			*/
			if player.dash_time_left > 0 {
				player.dash_jump_active = true
			} else {
				player.dash_jump_active = false
			}
		}
	}

	/* Horizontal movement */
	if !wall_jumped {
		if player.dash_time_left > 0 {
			// Active dash.
			velocity.x =
				player.dash_direction.x *
				PLAYER_DASH_SPEED

			velocity.z =
				player.dash_direction.z *
				PLAYER_DASH_SPEED

		} else if !grounded &&
				player.dash_jump_active {
			/*
			Dash-jump gives the player access to dash-speed
			air movement, but only while movement input is held.

			The direction remains fully controllable in the air.
			*/

			velocity.x =
				move.x *
				PLAYER_DASH_SPEED

			velocity.z =
				move.z *
				PLAYER_DASH_SPEED

		} else {
			velocity.x =
				move.x *
				PLAYER_SPEED

			velocity.z =
				move.z *
				PLAYER_SPEED
		}
	}

	/* Wall slide */

	if player.wall_sliding &&
	   velocity.y < 0 {
		/*
		Box3D applies normal gravity later in World_Step().

		We compensate for some gravity here. The compensation
		gradually disappears as wall_slide_gravity approaches 9.8.
		*/

		player.wall_slide_gravity =
			min(
				player.wall_slide_gravity +
					WALL_SLIDE_GRAVITY_RAMP *
						TIME_STEP,
				9.8,
			)

		velocity.y +=
			(
				9.8 -
				player.wall_slide_gravity
			) *
			TIME_STEP

		player.wall_smoke_timer -= TIME_STEP
		if player.wall_smoke_timer <= 0 {
			spawn_wall_smoke(
				player.wall_contact_point,
				player.wall_normal,
				2,
			)
			player.wall_smoke_timer = WALL_SMOKE_INTERVAL
		}
	}

	/* Flashfield hover */

	if rl.IsMouseButtonDown(.RIGHT) &&
	   !player.wall_sliding &&
	   velocity.y < 0 {
		/*
		Cancel most of Box3D's upcoming gravity.

		This works with Flashfield itself, regardless of whether
		an enemy is tagged.
		*/

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

cast_player_wall :: proc(
	direction: rl.Vector3,
) -> Wall_Cast_Result {
	player_pos := b3.Body_GetPosition(player.body_id)

	center := b3.Vec3{}

	proxy := b3.ShapeProxy{
		points = &center,
		count  = 1,
		radius = WALL_CHECK_RADIUS,
	}

	result := Wall_Cast_Result{}
	filter := b3.DefaultQueryFilter()

	translation :=
		direction * WALL_CHECK_DISTANCE

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
		wall_cast_callback,
		&result,
	)

	return result
}

wall_cast_callback :: proc "c" (
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

	if body_id == player.body_id ||
	   body_id == enemy.body_id {
		return -1
	}

	// Ground and ceilings are not walls.
	if normal.y > WALL_NORMAL_MAX_Y ||
	   normal.y < -WALL_NORMAL_MAX_Y {
		return -1
	}

	result := cast(^Wall_Cast_Result)ctx

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

	return fraction
}

spawn_wall_smoke :: proc(
	contact: rl.Vector3,
	normal: rl.Vector3,
	count: int,
) {
	for _ in 0..<count {
		for i in 0..<MAX_WALL_SMOKE_PARTICLES {
			if wall_smoke_particles[i].active {
				continue
			}

			random_x :=
				f32(rl.GetRandomValue(-100, 100)) /
				100.0

			random_y :=
				f32(rl.GetRandomValue(0, 100)) /
				100.0

			random_z :=
				f32(rl.GetRandomValue(-100, 100)) /
				100.0

			life :=
				0.25 +
				f32(rl.GetRandomValue(0, 25)) /
				100.0

			wall_smoke_particles[i] = Wall_Smoke_Particle{
				active   = true,
				position = contact + normal * 0.05,
				velocity =
					normal * 0.4 +
					rl.Vector3{
						random_x * 0.3,
						0.3 + random_y * 0.5,
						random_z * 0.3,
					},
				life     = life,
				max_life = life,
				radius   = 0.04 + random_y * 0.04,
			}

			break
		}
	}
}

update_wall_smoke :: proc() {
	for i in 0..<MAX_WALL_SMOKE_PARTICLES {
		particle := &wall_smoke_particles[i]

		if !particle.active {
			continue
		}

		particle.life -= TIME_STEP

		if particle.life <= 0 {
			particle.active = false
			continue
		}

		particle.position +=
			particle.velocity * TIME_STEP

		particle.velocity.y +=
			0.5 * TIME_STEP

		particle.velocity.x *= 0.97
		particle.velocity.z *= 0.97
	}
}

draw_wall_smoke :: proc() {
	for particle in wall_smoke_particles {
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
				u8(fade * 180.0),
			},
		)
	}
}


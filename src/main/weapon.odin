package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:c"

MAX_PROJECTILES         :: 64
PROJECTILE_RADIUS       :: 0.08
PROJECTILE_SPEED        :: 25.0
PROJECTILE_DAMAGE       :: 1.0
PROJECTILE_MAX_RANGE    :: 50.0
PROJECTILE_SPAWN_OFFSET :: 0.5

Projectile :: struct {
	position:          rl.Vector3,
	velocity:          rl.Vector3,
	distance_traveled: f32,
	active:            bool,
}

Projectile_Cast_Result :: struct {
	hit:      bool,
	shape_id: b3.ShapeId,
	point:    b3.Pos,
	fraction: f32,
}

projectiles: [MAX_PROJECTILES]Projectile

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
				enemy.tag_count = min(
					enemy.tag_count + 1,
					ENEMY_MAX_TAGS,
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

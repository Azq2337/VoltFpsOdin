package gameplay

import rl "vendor:raylib"
import b3 "vendor:box3d"
import "core:c"
import world "../world"
import player "../player"
import npc "../npc"

GUN_BARREL_LENGTH :: 0.58

get_camera_right_vector :: proc() -> rl.Vector3 {
	forward :=
		normalize_vector3(
			player.camera.target -
			player.camera.position,
		)

	right :=
		rl.Vector3CrossProduct(
			forward,
			player.camera.up,
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
			player.camera.target -
			player.camera.position,
		)

	camera_right :=
		get_camera_right_vector()

	camera_up :=
		normalize_vector3(
			player.camera.up,
		)

	if !player.third_person_enabled &&
	   !player.debug_camera_enabled {
		// First-person right-hand position.
		return (
			player.camera.position +
			camera_forward * 0.42 +
			camera_right * 0.30 -
			camera_up * 0.20
		)
	}

	player_pos :=
		b3.Body_GetPosition(
			player.player.body_id,
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
		return player.get_aim_direction()
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

MAX_PROJECTILES         :: 64
PROJECTILE_RADIUS       :: 0.08
PROJECTILE_SPEED        :: 120.0
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

		translation :=
			projectiles[i].velocity *
			world.TIME_STEP

		hit :=
			cast_projectile(
				projectiles[i].position,
				translation,
			)

		if hit.hit {
			hit_body :=
				b3.Shape_GetBody(
					hit.shape_id,
				)

			enemy_index :=
				npc.get_enemy_index_from_body(
					hit_body,
				)

			if enemy_index >= 0 {
				// Projectile damage is intentionally tiny. The shot's
				// primary purpose is building tags for Flashfield damage.
				npc.add_enemy_tag(
					enemy_index,
				)

				npc.damage_enemy(
					enemy_index,
					PROJECTILE_DAMAGE,
				)
			}

			projectiles[i].active =
				false

			continue
		}

		projectiles[i].position +=
			translation

		projectiles[i].distance_traveled +=
			PROJECTILE_SPEED *
			world.TIME_STEP

		if projectiles[i].distance_traveled >=
		   PROJECTILE_MAX_RANGE {
			projectiles[i].active =
				false
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
		world.world_id,
		{
			position.x,
			position.y,
			position.z,
		},
		proxy,
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

shoot_projectile :: proc() {
	if !rl.IsMouseButtonPressed(.LEFT) {
		return
	}

	for i in 0..<MAX_PROJECTILES {
		if projectiles[i].active {
			continue
		}

		spawn_pos :=
			get_gun_muzzle_position()

		direction :=
			get_gun_projectile_direction()

		projectiles[i] =
			Projectile{
				position = spawn_pos,
				velocity =
					direction *
					PROJECTILE_SPEED,
				active = true,
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
	result :=
		cast(^Projectile_Cast_Result)ctx

	body_id :=
		b3.Shape_GetBody(
			shape_id,
		)

	// Do not let a projectile hit its own player.
	if body_id == player.player.body_id {
		return -1
	}

	result.hit = true
	result.shape_id = shape_id
	result.point = point
	result.fraction = fraction

	return fraction
}

reset_projectiles :: proc() {
	projectiles = {}
}

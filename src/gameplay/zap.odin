package gameplay

import rl "vendor:raylib"
import b3 "vendor:box3d"
import rlgl "vendor:raylib/rlgl"
import "core:c"
import "core:math"
import world "../world"
import player "../player"
import npc "../npc"

MAX_ZAP_ARCS                  :: npc.GLOBAL_MAX_TAGS
ZAP_BACKBONE_POINT_COUNT      :: 32
ZAP_RENDER_POINT_COUNT        :: 30
ZAP_BACKBONE_REFRESH_INTERVAL :: 0.24
ZAP_BACKBONE_MORPH_SPEED      :: 6.0
ZAP_FINE_NOISE_AMPLITUDE      :: 0.18
ZAP_FINE_NOISE_REFRESH        :: 0.055
ZAP_RING_RADIUS               :: FLASHFIELD_RADIUS * 0.82
ZAP_ANCHOR_ROTATION_SPEED     :: 14.0
ZAP_DAMAGE_PER_TAG_PER_SECOND :: 15.0
ZAP_TAU                       :: 6.28318530718
ZAP_OBSTACLE_CLEARANCE        :: 0.10
ZAP_ROUTE_CLEARANCE           :: 0.30
MAX_ZAP_ROUTE_NODES           :: 2 + world.ROOM_BOX_COUNT * 12

flashfield_active := false
zap_active        := false
zap_visual_time: f32
last_tag_revision: u64

zap_backbone_refresh_timer: [MAX_ZAP_ARCS]f32
zap_paths_initialized: [MAX_ZAP_ARCS]bool
zap_backbone_current: [MAX_ZAP_ARCS][ZAP_BACKBONE_POINT_COUNT]rl.Vector3
zap_backbone_target: [MAX_ZAP_ARCS][ZAP_BACKBONE_POINT_COUNT]rl.Vector3

zap_render_points: [MAX_ZAP_ARCS][ZAP_RENDER_POINT_COUNT]rl.Vector3
zap_render_refresh_timer: [MAX_ZAP_ARCS]f32
zap_render_initialized: [MAX_ZAP_ARCS]bool

Zap_Cast_Result :: struct {
	hit:      bool,
	point:    rl.Vector3,
	normal:   rl.Vector3,
	fraction: f32,
}

Zap_Route :: struct {
	points:       [MAX_ZAP_ROUTE_NODES]rl.Vector3,
	count:        int,
	total_length: f32,
}

invalidate_zap_paths :: proc() {
	zap_backbone_refresh_timer = {}
	zap_paths_initialized = {}
	zap_backbone_current = {}
	zap_backbone_target = {}

	zap_render_points = {}
	zap_render_refresh_timer = {}
	zap_render_initialized = {}
}

reset_zap_state :: proc() {
	flashfield_active = false
	zap_active = false
	zap_visual_time = 0

	npc.reset_tags()
	last_tag_revision = npc.tag_revision
	invalidate_zap_paths()
}

update_zap :: proc() {
	if last_tag_revision != npc.tag_revision {
		last_tag_revision = npc.tag_revision
		invalidate_zap_paths()
	}

	flashfield_active =
		rl.IsMouseButtonDown(
			.RIGHT,
		)

	if flashfield_active {
		zap_visual_time +=
			world.TIME_STEP
	}

	zap_active =
		flashfield_active &&
		npc.tag_slot_count > 0

	if !zap_active {
		return
	}

	// Exactly one lightning arc belongs to each global tag slot.
	for slot in 0..<npc.tag_slot_count {
		enemy_index :=
			npc.tag_slots[slot]

		if enemy_index < 0 ||
		   enemy_index >= npc.MAX_ENEMIES ||
		   !npc.enemies[enemy_index].active ||
		   !npc.enemies[enemy_index].alive {
			continue
		}

		if !zap_paths_initialized[slot] {
			initialize_zap_path(
				slot,
			)
		}

		zap_backbone_refresh_timer[slot] -=
			world.TIME_STEP

		if zap_backbone_refresh_timer[slot] <= 0 {
			generate_zap_backbone_target(
				slot,
			)

			zap_backbone_refresh_timer[slot] =
				ZAP_BACKBONE_REFRESH_INTERVAL
		}

		update_zap_backbone(
			slot,
		)

		zap_render_refresh_timer[slot] -=
			world.TIME_STEP

		if !zap_render_initialized[slot] ||
		   zap_render_refresh_timer[slot] <= 0 {
			generate_zap_render_points(
				slot,
			)

			zap_render_refresh_timer[slot] =
				ZAP_FINE_NOISE_REFRESH

			zap_render_initialized[slot] =
				true
		}
	}

	// Damage is calculated from each enemy's derived global tag count.
	// This is done after path updates so an enemy dying cannot shift the tag
	// slots while the slot loop above is still using them.
	for enemy_index in 0..<npc.MAX_ENEMIES {
		if !npc.enemies[enemy_index].active ||
		   !npc.enemies[enemy_index].alive ||
		   npc.enemies[enemy_index].tag_count <= 0 {
			continue
		}

		damage :=
			ZAP_DAMAGE_PER_TAG_PER_SECOND *
			f32(
				npc.enemies[enemy_index].tag_count,
			) *
			world.TIME_STEP

		npc.damage_enemy(
			enemy_index,
			damage,
		)
	}
}

initialize_zap_path :: proc(
	slot: int,
) {
	generate_zap_backbone_target(
		slot,
	)

	for i in 0..<ZAP_BACKBONE_POINT_COUNT {
		zap_backbone_current[slot][i] =
			zap_backbone_target[slot][i]
	}

	zap_paths_initialized[slot] =
		true

	zap_backbone_refresh_timer[slot] =
		ZAP_BACKBONE_REFRESH_INTERVAL

	generate_zap_render_points(
		slot,
	)

	zap_render_refresh_timer[slot] =
		ZAP_FINE_NOISE_REFRESH

	zap_render_initialized[slot] =
		true
}

generate_zap_backbone_target :: proc(
	slot: int,
) {
	enemy_index :=
		npc.tag_slots[slot]

	start :=
		get_zap_anchor(
			slot,
			enemy_index,
		)

	target, _ :=
		get_zap_contact(
			enemy_index,
		)

	route :=
		find_zap_route(
			start,
			target,
		)

	bend_a :=
		random_zap_direction()

	bend_b :=
		random_zap_direction()

	for i in 0..<ZAP_BACKBONE_POINT_COUNT {
		t :=
			f32(i) /
			f32(
				ZAP_BACKBONE_POINT_COUNT -
					1,
			)

		if i == 0 {
			zap_backbone_target[slot][i] =
				start
			continue
		}

		if i ==
		   ZAP_BACKBONE_POINT_COUNT -
		   1 {
			zap_backbone_target[slot][i] =
				target
			continue
		}

		guide :=
			sample_zap_route(
				&route,
				t,
			)

		envelope :=
			4.0 *
			t *
			(1.0 - t)

		// The shortest route controls the structure. These modest bends keep
		// the bolt alive without letting it wander across the whole screen.
		curve_offset :=
			bend_a *
				math.sin(
					t *
						ZAP_TAU,
				) *
				0.16 *
				envelope +
			bend_b *
				math.sin(
					t *
						ZAP_TAU *
						2.0,
				) *
				0.085 *
				envelope

		candidate :=
			guide +
			curve_offset

		offset_hit :=
			cast_zap_environment(
				guide,
				candidate -
					guide,
			)

		if offset_hit.hit {
			candidate =
				guide
		}

		previous :=
			zap_backbone_target[slot][i - 1]

		segment_hit :=
			cast_zap_environment(
				previous,
				candidate -
					previous,
			)

		if segment_hit.hit {
			candidate =
				guide
		}

		zap_backbone_target[slot][i] =
			candidate
	}
}

find_zap_route :: proc(
	start, target: rl.Vector3,
) -> Zap_Route {
	nodes: [MAX_ZAP_ROUTE_NODES]rl.Vector3
	node_count := 0

	start_index := node_count
	nodes[node_count] = start
	node_count += 1

	target_index := node_count
	nodes[node_count] = target
	node_count += 1

	route_height :=
		(start.y + target.y) *
		0.5

	for box in world.ROOM_BOXES {
		if !box.zap_route_obstacle {
			continue
		}

		x0 :=
			box.center.x -
			box.half_size.x -
			ZAP_ROUTE_CLEARANCE

		x1 :=
			box.center.x +
			box.half_size.x +
			ZAP_ROUTE_CLEARANCE

		z0 :=
			box.center.z -
			box.half_size.z -
			ZAP_ROUTE_CLEARANCE

		z1 :=
			box.center.z +
			box.half_size.z +
			ZAP_ROUTE_CLEARANCE

		top_y :=
			box.center.y +
			box.half_size.y +
			ZAP_ROUTE_CLEARANCE

		bottom_y :=
			box.center.y -
			box.half_size.y -
			ZAP_ROUTE_CLEARANCE

		nodes[node_count] = {x0, route_height, z0}
		node_count += 1
		nodes[node_count] = {x0, route_height, z1}
		node_count += 1
		nodes[node_count] = {x1, route_height, z0}
		node_count += 1
		nodes[node_count] = {x1, route_height, z1}
		node_count += 1

		nodes[node_count] = {x0, top_y, z0}
		node_count += 1
		nodes[node_count] = {x0, top_y, z1}
		node_count += 1
		nodes[node_count] = {x1, top_y, z0}
		node_count += 1
		nodes[node_count] = {x1, top_y, z1}
		node_count += 1

		nodes[node_count] = {x0, bottom_y, z0}
		node_count += 1
		nodes[node_count] = {x0, bottom_y, z1}
		node_count += 1
		nodes[node_count] = {x1, bottom_y, z0}
		node_count += 1
		nodes[node_count] = {x1, bottom_y, z1}
		node_count += 1
	}

	distances: [MAX_ZAP_ROUTE_NODES]f32
	previous: [MAX_ZAP_ROUTE_NODES]int
	visited: [MAX_ZAP_ROUTE_NODES]bool

	for i in 0..<node_count {
		distances[i] = 1.0e30
		previous[i] = -1
	}

	distances[start_index] = 0

	for _ in 0..<node_count {
		current := -1
		best_distance: f32 = 1.0e30

		for i in 0..<node_count {
			if visited[i] {
				continue
			}

			if distances[i] <
			   best_distance {
				best_distance =
					distances[i]

				current = i
			}
		}

		if current < 0 {
			break
		}

		if current ==
		   target_index {
			break
		}

		visited[current] = true

		for next in 0..<node_count {
			if next == current ||
			   visited[next] {
				continue
			}

			if !zap_route_visible(
				nodes[current],
				nodes[next],
			) {
				continue
			}

			new_distance :=
				distances[current] +
				vector3_distance(
					nodes[current],
					nodes[next],
				)

			if new_distance <
			   distances[next] {
				distances[next] =
					new_distance

				previous[next] =
					current
			}
		}
	}

	route :=
		Zap_Route{}

	if previous[target_index] < 0 {
		route.points[0] =
			start

		route.points[1] =
			target

		route.count = 2

		route.total_length =
			vector3_distance(
				start,
				target,
			)

		return route
	}

	reversed: [MAX_ZAP_ROUTE_NODES]rl.Vector3

	reversed_count := 0
	current := target_index

	for current >= 0 {
		reversed[reversed_count] =
			nodes[current]

		reversed_count += 1

		if current ==
		   start_index {
			break
		}

		current =
			previous[current]
	}

	for i in 0..<reversed_count {
		route.points[i] =
			reversed[
				reversed_count -
				1 -
				i
			]
	}

	route.count =
		reversed_count

	for i in 0..<route.count - 1 {
		route.total_length +=
			vector3_distance(
				route.points[i],
				route.points[i + 1],
			)
	}

	return route
}

zap_route_visible :: proc(
	start,
	end: rl.Vector3,
) -> bool {
	hit :=
		cast_zap_environment(
			start,
			end - start,
		)

	return !hit.hit
}

sample_zap_route :: proc(
	route: ^Zap_Route,
	t: f32,
) -> rl.Vector3 {
	if route.count <= 1 {
		return route.points[0]
	}

	target_distance :=
		clamp(
			t,
			0.0,
			1.0,
		) *
		route.total_length

	distance_so_far: f32 = 0

	for i in 0..<route.count - 1 {
		start :=
			route.points[i]

		end :=
			route.points[i + 1]

		segment_length :=
			vector3_distance(
				start,
				end,
			)

		if distance_so_far +
		   segment_length >=
		   target_distance {
			if segment_length <=
			   0.0001 {
				return start
			}

			local_t :=
				(
					target_distance -
					distance_so_far
				) /
				segment_length

			return (
				start +
				(
					end -
					start
				) *
				local_t
			)
		}

		distance_so_far +=
			segment_length
	}

	return route.points[
		route.count -
		1
	]
}

cast_zap_environment :: proc(
	position,
	translation: rl.Vector3,
) -> Zap_Cast_Result {
	result :=
		Zap_Cast_Result{}

	if vector3_length_squared(
		translation,
	) <= 0.000001 {
		return result
	}

	filter :=
		b3.DefaultQueryFilter()

	_ = b3.World_CastRay(
		world.world_id,
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
		zap_cast_callback,
		&result,
	)

	return result
}

zap_cast_callback :: proc "c" (
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

	if body_id ==
	   player.player.body_id ||
	   npc.get_enemy_index_from_body(
			body_id,
		) >= 0 {
		return -1
	}

	result :=
		cast(^Zap_Cast_Result)ctx

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

	result.fraction =
		fraction

	return fraction
}

update_zap_backbone :: proc(
	slot: int,
) {
	enemy_index :=
		npc.tag_slots[slot]

	if enemy_index < 0 ||
	   enemy_index >= npc.MAX_ENEMIES ||
	   !npc.enemies[enemy_index].active ||
	   !npc.enemies[enemy_index].alive {
		return
	}

	blend: f32 =
		min(
			world.TIME_STEP *
				ZAP_BACKBONE_MORPH_SPEED,
			1.0,
		)

	target, _ :=
		get_zap_contact(
			enemy_index,
		)

	for i in 0..<ZAP_BACKBONE_POINT_COUNT {
		current :=
			zap_backbone_current[slot][i]

		destination :=
			zap_backbone_target[slot][i]

		candidate :=
			current +
			(
				destination -
				current
			) *
			blend

		hit :=
			cast_zap_environment(
				current,
				candidate -
					current,
			)

		if hit.hit {
			candidate =
				hit.point +
				hit.normal *
					ZAP_OBSTACLE_CLEARANCE
		}

		zap_backbone_current[slot][i] =
			candidate
	}

	anchor :=
		get_zap_anchor(
			slot,
			enemy_index,
		)

	zap_backbone_current[slot][0] =
		anchor

	zap_backbone_target[slot][0] =
		anchor

	zap_backbone_current[slot][ZAP_BACKBONE_POINT_COUNT - 1] =
		target

	zap_backbone_target[slot][ZAP_BACKBONE_POINT_COUNT - 1] =
		target

	if zap_render_initialized[slot] {
		zap_render_points[slot][0] =
			anchor

		zap_render_points[slot][ZAP_RENDER_POINT_COUNT - 1] =
			target
	}
}

draw_zap_arc_segments :: proc(
	glow_pass: bool,
) {
	for slot in 0..<npc.tag_slot_count {
		enemy_index :=
			npc.tag_slots[slot]

		if enemy_index < 0 ||
		   enemy_index >= npc.MAX_ENEMIES ||
		   !npc.enemies[enemy_index].active ||
		   !npc.enemies[enemy_index].alive ||
		   !zap_paths_initialized[slot] {
			continue
		}

		for i in 0..<ZAP_RENDER_POINT_COUNT - 1 {
			segment_start :=
				zap_render_points[slot][i]

			segment_end :=
				zap_render_points[slot][i + 1]

			if glow_pass {
				draw_zap_glow_segment(
					segment_start,
					segment_end,
				)
			} else {
				draw_zap_core_segment(
					segment_start,
					segment_end,
				)
			}
		}
	}
}

draw_zap_arcs :: proc() {
	if !zap_active {
		return
	}

	// Glow is additive, but deliberately narrow and subtle.
	rl.BeginBlendMode(
		.ADDITIVE,
	)

	draw_zap_arc_segments(
		true,
	)

	rl.EndBlendMode()

	// The actual electrical body is drawn with normal alpha blending.
	// This prevents white backgrounds from washing the entire bolt out.
	draw_zap_arc_segments(
		false,
	)

	// One contact burst per tagged enemy rather than one burst per tag slot.
	rlgl.DisableDepthTest()

	for enemy_index in 0..<npc.MAX_ENEMIES {
		if npc.enemies[enemy_index].active &&
		   npc.enemies[enemy_index].alive &&
		   npc.enemies[enemy_index].tag_count > 0 {
			draw_zap_contact_effect(
				enemy_index,
			)
		}
	}

	rlgl.EnableDepthTest()
}

draw_zap_glow_segment :: proc(
	start,
	end: rl.Vector3,
) {
	if vector3_distance(
		start,
		end,
	) <= 0.0001 {
		return
	}

	rl.DrawCylinderEx(
		start,
		end,
		0.050,
		0.050,
		6,
		rl.Color{
			20,
			110,
			255,
			90,
		},
	)
}

draw_zap_core_segment :: proc(
	start,
	end: rl.Vector3,
) {
	if vector3_distance(
		start,
		end,
	) <= 0.0001 {
		return
	}

	rl.DrawCylinderEx(
		start,
		end,
		0.032,
		0.032,
		6,
		rl.Color{
			20,
			210,
			255,
			255,
		},
	)

	rl.DrawCylinderEx(
		start,
		end,
		0.014,
		0.014,
		5,
		rl.Color{
			245,
			255,
			255,
			255,
		},
	)
}

generate_zap_render_points :: proc(
	slot: int,
) {
	if slot < 0 ||
	   slot >= npc.tag_slot_count {
		return
	}

	enemy_index :=
		npc.tag_slots[slot]

	if enemy_index < 0 ||
	   enemy_index >= npc.MAX_ENEMIES ||
	   !npc.enemies[enemy_index].active ||
	   !npc.enemies[enemy_index].alive {
		return
	}

	for i in 0..<ZAP_RENDER_POINT_COUNT {
		t :=
			f32(i) /
			f32(
				ZAP_RENDER_POINT_COUNT -
					1,
			)

		base :=
			sample_zap_backbone(
				slot,
				t,
			)

		if i == 0 ||
		   i == ZAP_RENDER_POINT_COUNT - 1 {
			zap_render_points[slot][i] =
				base
			continue
		}

		prev_t :=
			max(
				t -
					0.035,
				0.0,
			)

		next_t :=
			min(
				t +
					0.035,
				1.0,
			)

		tangent :=
			normalize_vector3(
				sample_zap_backbone(
					slot,
					next_t,
				) -
				sample_zap_backbone(
					slot,
					prev_t,
				),
			)

		world_up :=
			rl.Vector3{
				0,
				1,
				0,
			}

		right :=
			rl.Vector3CrossProduct(
				world_up,
				tangent,
			)

		if vector3_length_squared(
			right,
		) <= 0.0001 {
			right =
				rl.Vector3{
					1,
					0,
					0,
				}
		}

		right =
			normalize_vector3(
				right,
			)

		up :=
			normalize_vector3(
				rl.Vector3CrossProduct(
					tangent,
					right,
				),
			)

		envelope :=
			4.0 *
			t *
			(1.0 - t)

		zigzag_sign: f32 = 1.0

		if i % 2 == 0 {
			zigzag_sign = -1.0
		}

		side_scale :=
			0.70 +
			f32(
				rl.GetRandomValue(
					0,
					100,
				),
			) /
				100.0 *
				0.55

		side_offset :=
			zigzag_sign *
			side_scale *
			ZAP_FINE_NOISE_AMPLITUDE *
			envelope

		vertical_offset :=
			random_zap_offset() *
			ZAP_FINE_NOISE_AMPLITUDE *
			0.60 *
			envelope

		candidate :=
			base +
			right *
				side_offset +
			up *
				vertical_offset

		// Keep the local visual jitter outside geometry.
		offset_hit :=
			cast_zap_environment(
				base,
				candidate -
					base,
			)

		if offset_hit.hit {
			candidate =
				base
		}

		// Also make sure the segment from the previous cached lightning point
		// to this one does not cut through a wall.
		previous :=
			zap_render_points[slot][i - 1]

		segment_hit :=
			cast_zap_environment(
				previous,
				candidate -
					previous,
			)

		if segment_hit.hit {
			candidate =
				base
		}

		zap_render_points[slot][i] =
			candidate
	}
}

sample_zap_backbone :: proc(
	slot: int,
	t: f32,
) -> rl.Vector3 {
	clamped_t :=
		clamp(
			t,
			0.0,
			1.0,
		)

	scaled :=
		clamped_t *
		f32(
			ZAP_BACKBONE_POINT_COUNT -
				1,
		)

	index :=
		int(
			scaled,
		)

	if index >=
	   ZAP_BACKBONE_POINT_COUNT -
	   1 {
		return zap_backbone_current[slot][ZAP_BACKBONE_POINT_COUNT - 1]
	}

	local_t :=
		scaled -
		f32(index)

	start :=
		zap_backbone_current[slot][index]

	end :=
		zap_backbone_current[slot][index + 1]

	return (
		start +
		(
			end -
				start
		) *
		local_t
	)
}

get_zap_contact :: proc(
	enemy_index: int,
) -> (
	position,
	normal: rl.Vector3,
) {
	lock_center :=
		npc.get_enemy_lock_position(
			enemy_index,
		)

	source :=
		get_flashfield_center()

	normal =
		normalize_vector3(
			source -
				lock_center,
		)

	if vector3_length_squared(
		normal,
	) <= 0.0001 {
		normal = {
			0,
			0,
			1,
		}
	}

	position =
		lock_center +
		normal *
			(
				npc.ENEMY_RADIUS +
					0.03
			)

	return
}

draw_zap_contact_effect :: proc(
	enemy_index: int,
) {
	if !zap_active ||
	   !npc.enemies[enemy_index].alive {
		return
	}

	contact, contact_normal :=
		get_zap_contact(
			enemy_index,
		)

	rl.DrawSphere(
		contact,
		0.09,
		rl.Color{
			240,
			255,
			255,
			255,
		},
	)

	world_up := rl.Vector3{
		0,
		1,
		0,
	}

	right :=
		rl.Vector3CrossProduct(
			world_up,
			contact_normal,
		)

	if vector3_length_squared(
		right,
	) < 0.001 {
		right = {
			1,
			0,
			0,
		}
	}

	right =
		normalize_vector3(
			right,
		)

	up :=
		normalize_vector3(
			rl.Vector3CrossProduct(
				contact_normal,
				right,
			),
		)

	spark_count :=
		12 +
		npc.enemies[enemy_index].tag_count *
			6

	for i in 0..<spark_count {
		sideways :=
			random_zap_offset() *
			0.65

		vertical :=
			random_zap_offset() *
			0.65

		direction :=
			normalize_vector3(
				contact_normal *
					1.5 +
				right *
					sideways +
				up *
					vertical,
			)

		start_distance :=
			f32(
				rl.GetRandomValue(
					0,
					8,
				),
			) /
			100.0

		length :=
			0.20 +
			f32(
				rl.GetRandomValue(
					0,
					50,
				),
			) /
				100.0

		start :=
			contact +
			direction *
				start_distance

		end :=
			start +
			direction *
				length

		color :=
			rl.Color{
				110,
				225,
				255,
				220,
			}

		if i % 4 == 0 {
			color =
				rl.Color{
					255,
					255,
					230,
					255,
				}
		}

		rl.DrawCylinderEx(
			start,
			end,
			0.018,
			0.005,
			4,
			color,
		)
	}
}

get_zap_anchor :: proc(
	slot,
	enemy_index: int,
) -> rl.Vector3 {
	center :=
		get_flashfield_center()

	target, _ :=
		get_zap_contact(
			enemy_index,
		)

	to_target :=
		normalize_vector3(
			target -
				center,
		)

	world_up := rl.Vector3{
		0,
		1,
		0,
	}

	right :=
		rl.Vector3CrossProduct(
			world_up,
			to_target,
		)

	if vector3_length_squared(
		right,
	) <= 0.0001 {
		right = {
			1,
			0,
			0,
		}
	}

	right =
		normalize_vector3(
			right,
		)

	up :=
		normalize_vector3(
			rl.Vector3CrossProduct(
				to_target,
				right,
			),
		)

	angle :=
		f32(slot) *
			120.0 +
		zap_visual_time *
			ZAP_ANCHOR_ROTATION_SPEED

	offset :=
		right *
			math.cos(
				math.to_radians(
					angle,
				),
			) +
		up *
			math.sin(
				math.to_radians(
					angle,
				),
			)

	candidate :=
		center +
		offset *
			ZAP_RING_RADIUS

	hit :=
		cast_zap_environment(
			center,
			candidate -
				center,
		)

	if hit.hit {
		return (
			hit.point +
			hit.normal *
				ZAP_OBSTACLE_CLEARANCE
		)
	}

	return candidate
}

random_zap_direction :: proc() -> rl.Vector3 {
	direction := rl.Vector3{
		random_zap_offset(),
		random_zap_offset(),
		random_zap_offset(),
	}

	if vector3_length_squared(
		direction,
	) <= 0.0001 {
		return {
			1,
			0,
			0,
		}
	}

	return normalize_vector3(
		direction,
	)
}

random_zap_offset :: proc() -> f32 {
	return (
		f32(
			rl.GetRandomValue(
				-1000,
				1000,
			),
		) /
		1000.0
	)
}

vector3_distance :: proc(
	a,
	b: rl.Vector3,
) -> f32 {
	delta :=
		b -
		a

	return math.sqrt(
		delta.x * delta.x +
		delta.y * delta.y +
		delta.z * delta.z,
	)
}

vector3_length_squared :: proc(
	v: rl.Vector3,
) -> f32 {
	return (
		v.x * v.x +
		v.y * v.y +
		v.z * v.z
	)
}

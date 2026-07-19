package main

import rl "vendor:raylib"
import b3 "vendor:box3d"
import rlgl "vendor:raylib/rlgl"
import "core:c"
import "core:math"

MAX_ZAP_ARCS                  :: 3
ZAP_BACKBONE_POINT_COUNT      :: 32
ZAP_RENDER_POINT_COUNT        :: 32
ZAP_STRANDS_PER_ARC           :: 3
ZAP_BACKBONE_REFRESH_INTERVAL :: 0.16
ZAP_BACKBONE_MORPH_SPEED      :: 7.0
ZAP_FINE_NOISE_AMPLITUDE      :: 0.14
ZAP_RING_RADIUS               :: FLASHFIELD_RADIUS * 0.82
ZAP_ANCHOR_ROTATION_SPEED     :: 28.0
ZAP_DAMAGE_PER_TAG_PER_SECOND :: 15.0
ZAP_TAU                       :: 6.28318530718
ZAP_OBSTACLE_CLEARANCE        :: 0.10
ZAP_ROUTE_CLEARANCE           :: 0.30
MAX_ZAP_ROUTE_NODES           :: 2 + ROOM_BOX_COUNT * 12

flashfield_active := false
zap_active        := false
zap_visual_time: f32
zap_backbone_refresh_timer: f32
zap_paths_initialized := false

zap_backbone_current: [MAX_ZAP_ARCS][ZAP_BACKBONE_POINT_COUNT]rl.Vector3
zap_backbone_target:  [MAX_ZAP_ARCS][ZAP_BACKBONE_POINT_COUNT]rl.Vector3

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

update_zap :: proc() {
	flashfield_active = rl.IsMouseButtonDown(.RIGHT)

	if flashfield_active {
		zap_visual_time += TIME_STEP
	}

	zap_active =
		flashfield_active &&
		enemy.tag_count > 0 &&
		enemy.health > 0

	if !zap_active {
		zap_backbone_refresh_timer = 0
		zap_paths_initialized = false
		return
	}

	if !zap_paths_initialized {
		initialize_zap_paths()
	}

	zap_backbone_refresh_timer -= TIME_STEP
	if zap_backbone_refresh_timer <= 0 {
		for arc in 0..<enemy.tag_count {
			generate_zap_backbone_target(arc)
		}
		zap_backbone_refresh_timer = ZAP_BACKBONE_REFRESH_INTERVAL
	}

	update_zap_backbones()
	apply_zap_damage()
}

initialize_zap_paths :: proc() {
	for arc in 0..<enemy.tag_count {
		generate_zap_backbone_target(arc)
		for i in 0..<ZAP_BACKBONE_POINT_COUNT {
			zap_backbone_current[arc][i] = zap_backbone_target[arc][i]
		}
	}

	zap_paths_initialized = true
	zap_backbone_refresh_timer = ZAP_BACKBONE_REFRESH_INTERVAL
}

generate_zap_backbone_target :: proc(arc: int) {
	start := get_zap_anchor(arc)
	target, _ := get_zap_contact()

	route := find_zap_route(start, target)

	bend_a := random_zap_direction()
	bend_b := random_zap_direction()

	for i in 0..<ZAP_BACKBONE_POINT_COUNT {
		t := f32(i) / f32(ZAP_BACKBONE_POINT_COUNT - 1)

		if i == 0 {
			zap_backbone_target[arc][i] = start
			continue
		}

		if i == ZAP_BACKBONE_POINT_COUNT - 1 {
			zap_backbone_target[arc][i] = target
			continue
		}

		guide := sample_zap_route(&route, t)

		// The route controls the large-scale path around obstacles.
		// These offsets only make the lightning itself look alive.
		envelope := 4.0 * t * (1.0 - t)

		curve_offset :=
			bend_a *
				math.sin(t * ZAP_TAU) *
				0.35 * envelope +
			bend_b *
				math.sin(t * ZAP_TAU * 2.0) *
				0.20 * envelope

		candidate := guide + curve_offset

		// Do not let decorative curvature push the guide point into geometry.
		offset_hit := cast_zap_environment(
			guide,
			candidate - guide,
		)

		if offset_hit.hit {
			candidate = guide
		}

		// Also make sure the actual backbone segment remains collision-free.
		previous := zap_backbone_target[arc][i - 1]

		segment_hit := cast_zap_environment(
			previous,
			candidate - previous,
		)

		if segment_hit.hit {
			candidate = guide
		}

		zap_backbone_target[arc][i] = candidate
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

	route_height := (start.y + target.y) * 0.5

	// Candidate nodes sit outside expanded obstacle corners.
	// Dijkstra later chooses the shortest mutually-visible sequence.
	for box in ROOM_BOXES {
		if !box.zap_route_obstacle {
			continue
		}

		x0 := box.center.x - box.half_size.x - ZAP_ROUTE_CLEARANCE
		x1 := box.center.x + box.half_size.x + ZAP_ROUTE_CLEARANCE

		z0 := box.center.z - box.half_size.z - ZAP_ROUTE_CLEARANCE
		z1 := box.center.z + box.half_size.z + ZAP_ROUTE_CLEARANCE

		top_y :=
			box.center.y +
			box.half_size.y +
			ZAP_ROUTE_CLEARANCE

		bottom_y :=
			box.center.y -
			box.half_size.y -
			ZAP_ROUTE_CLEARANCE

		// Around the four sides.
		nodes[node_count] = {x0, route_height, z0}
		node_count += 1
		nodes[node_count] = {x0, route_height, z1}
		node_count += 1
		nodes[node_count] = {x1, route_height, z0}
		node_count += 1
		nodes[node_count] = {x1, route_height, z1}
		node_count += 1

		// Over the obstacle.
		nodes[node_count] = {x0, top_y, z0}
		node_count += 1
		nodes[node_count] = {x0, top_y, z1}
		node_count += 1
		nodes[node_count] = {x1, top_y, z0}
		node_count += 1
		nodes[node_count] = {x1, top_y, z1}
		node_count += 1

		// Under floating obstacles. Grounded obstacles naturally have these
		// routes rejected because the floor blocks visibility.
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
	previous:  [MAX_ZAP_ROUTE_NODES]int
	visited:   [MAX_ZAP_ROUTE_NODES]bool

	for i in 0..<node_count {
		distances[i] = 1.0e30
		previous[i] = -1
	}

	distances[start_index] = 0

	// Dijkstra over a tiny visibility graph.
	for _ in 0..<node_count {
		current := -1
		best_distance: f32 = 1.0e30

		for i in 0..<node_count {
			if visited[i] {
				continue
			}

			if distances[i] < best_distance {
				best_distance = distances[i]
				current = i
			}
		}

		if current < 0 {
			break
		}

		if current == target_index {
			break
		}

		visited[current] = true

		for next in 0..<node_count {
			if next == current || visited[next] {
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

			if new_distance < distances[next] {
				distances[next] = new_distance
				previous[next] = current
			}
		}
	}

	route := Zap_Route{}

	// Safety fallback: preserve the electrical connection even if the graph
	// unexpectedly cannot find a route.
	if previous[target_index] < 0 {
		route.points[0] = start
		route.points[1] = target
		route.count = 2
		route.total_length = vector3_distance(start, target)

		return route
	}

	// Reconstruct target -> start, then reverse it.
	reversed: [MAX_ZAP_ROUTE_NODES]rl.Vector3
	reversed_count := 0
	current := target_index

	for current >= 0 {
		reversed[reversed_count] = nodes[current]
		reversed_count += 1

		if current == start_index {
			break
		}

		current = previous[current]
	}

	for i in 0..<reversed_count {
		route.points[i] =
			reversed[reversed_count - 1 - i]
	}

	route.count = reversed_count

	for i in 0..<route.count - 1 {
		route.total_length += vector3_distance(
			route.points[i],
			route.points[i + 1],
		)
	}

	return route
}

zap_route_visible :: proc(
	start, end: rl.Vector3,
) -> bool {
	hit := cast_zap_environment(
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
		clamp(t, 0.0, 1.0) *
		route.total_length

	distance_so_far: f32 = 0

	for i in 0..<route.count - 1 {
		start := route.points[i]
		end := route.points[i + 1]

		segment_length :=
			vector3_distance(start, end)

		if distance_so_far + segment_length >= target_distance {
			if segment_length <= 0.0001 {
				return start
			}

			local_t :=
				(target_distance - distance_so_far) /
				segment_length

			return (
				start +
					(end - start) *
					local_t
			)
		}

		distance_so_far += segment_length
	}

	return route.points[route.count - 1]
}

cast_zap_environment :: proc(
	position: rl.Vector3,
	translation: rl.Vector3,
) -> Zap_Cast_Result {
	result := Zap_Cast_Result{}

	if vector3_length_squared(translation) <= 0.000001 {
		return result
	}

	filter := b3.DefaultQueryFilter()

	_ = b3.World_CastRay(
		world_id,
		{position.x, position.y, position.z},
		{translation.x, translation.y, translation.z},
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
	body_id := b3.Shape_GetBody(shape_id)

	// Tagged enemies and the player do not block the electric route. The
	// environment does, causing the generated backbone to crawl around it.
	if body_id == player.body_id ||
	   body_id == enemy.body_id {
		return -1
	}

	result := cast(^Zap_Cast_Result)ctx
	result.hit = true
	result.point = {point.x, point.y, point.z}
	result.normal = {normal.x, normal.y, normal.z}
	result.fraction = fraction

	return fraction
}

update_zap_backbones :: proc() {
	blend : f32 = min(TIME_STEP * ZAP_BACKBONE_MORPH_SPEED, 1.0)
	target, _ := get_zap_contact()

	for arc in 0..<enemy.tag_count {
		for i in 0..<ZAP_BACKBONE_POINT_COUNT {
			current := zap_backbone_current[arc][i]
			destination := zap_backbone_target[arc][i]
			candidate :=
				current +
				(destination - current) * blend

			// Do not let interpolation between two safe routes morph straight
			// through a wall.
			hit := cast_zap_environment(
				current,
				candidate - current,
			)

			if hit.hit {
				candidate =
					hit.point +
					hit.normal * ZAP_OBSTACLE_CLEARANCE
			}

			zap_backbone_current[arc][i] = candidate
		}

		// Keep the ends physically attached even while the large-scale curve
		// is morphing between two shapes.
		anchor := get_zap_anchor(arc)
		zap_backbone_current[arc][0] = anchor
		zap_backbone_target[arc][0] = anchor
		zap_backbone_current[arc][ZAP_BACKBONE_POINT_COUNT - 1] = target
		zap_backbone_target[arc][ZAP_BACKBONE_POINT_COUNT - 1] = target
	}
}

apply_zap_damage :: proc() {
	damage :=
		ZAP_DAMAGE_PER_TAG_PER_SECOND *
		f32(enemy.tag_count) *
		TIME_STEP

	enemy.health = max(enemy.health - damage, 0)
}

draw_zap_arcs :: proc() {
	if !zap_active || !zap_paths_initialized {
		return
	}

	rl.BeginBlendMode(.ADDITIVE)
	defer rl.EndBlendMode()

	for arc in 0..<enemy.tag_count {
		for strand in 0..<ZAP_STRANDS_PER_ARC {
			for i in 0..<ZAP_RENDER_POINT_COUNT - 1 {
				t0 := f32(i) / f32(ZAP_RENDER_POINT_COUNT - 1)
				t1 := f32(i + 1) / f32(ZAP_RENDER_POINT_COUNT - 1)

				start := get_zap_strand_point(arc, strand, t0)
				end := get_zap_strand_point(arc, strand, t1)

				draw_zap_segment(start, end, strand == 0)
			}
		}
	}

	// The contact burst is a readability effect attached to the target
	// surface, so let it render over the enemy mesh rather than being buried
	// inside it by the depth buffer.
	rlgl.DisableDepthTest()
	draw_zap_contact_effect()
	rlgl.EnableDepthTest()
}

draw_zap_segment :: proc(start, end: rl.Vector3, main_strand: bool) {
	if vector3_distance(start, end) <= 0.0001 {
		return
	}

	glow_radius: f32 = 0.048
	body_radius: f32 = 0.021
	core_radius: f32 = 0.006
	glow_alpha: u8 = 30
	body_alpha: u8 = 130
	core_alpha: u8 = 210

	if main_strand {
		glow_radius = 0.080
		body_radius = 0.036
		core_radius = 0.011
		glow_alpha = 45
		body_alpha = 190
		core_alpha = 255
	}

	// Wide additive glow.
	rl.DrawCylinderEx(
		start,
		end,
		glow_radius,
		glow_radius,
		6,
		rl.Color{25, 90, 255, glow_alpha},
	)

	// Saturated electric body.
	rl.DrawCylinderEx(
		start,
		end,
		body_radius,
		body_radius,
		6,
		rl.Color{20, 205, 255, body_alpha},
	)

	// Hot core.
	rl.DrawCylinderEx(
		start,
		end,
		core_radius,
		core_radius,
		5,
		rl.Color{225, 250, 255, core_alpha},
	)
}

get_zap_strand_point :: proc(arc, strand: int, t: f32) -> rl.Vector3 {
	base := sample_zap_backbone(arc, t)

	prev_t := max(t - 0.02, 0.0)
	next_t := min(t + 0.02, 1.0)
	tangent := normalize_vector3(
		sample_zap_backbone(arc, next_t) -
		sample_zap_backbone(arc, prev_t),
	)

	world_up := rl.Vector3{0, 1, 0}
	right := rl.Vector3CrossProduct(world_up, tangent)
	if vector3_length_squared(right) <= 0.0001 {
		right = rl.Vector3{1, 0, 0}
	}
	right = normalize_vector3(right)
	up := normalize_vector3(
		rl.Vector3CrossProduct(tangent, right),
	)

	envelope := 4.0 * t * (1.0 - t)
	phase :=
		f32(arc) * 2.17 +
		f32(strand) * 3.31

	// Several unrelated frequencies create rapid fine jitter without
	// replacing the whole path every frame.
	noise_a := math.sin(
		t * 47.0 +
		zap_visual_time * 24.0 +
		phase,
	)
	noise_b := math.sin(
		t * 83.0 -
		zap_visual_time * 31.0 +
		phase * 1.7,
	)
	micro := math.sin(
		t * 151.0 +
		zap_visual_time * 43.0 -
		phase * 0.8,
	)

	amplitude : f32 = ZAP_FINE_NOISE_AMPLITUDE
	if strand > 0 {
		amplitude *= 1.35
	}

	offset :=
		right *
		(noise_a + micro * 0.28) *
		amplitude * envelope +
		up *
		(noise_b - micro * 0.22) *
		amplitude * envelope

	// Secondary strands drift around the main electrical channel but
	// converge at both the Flashfield and the target.
	if strand > 0 {
		spread_phase :=
			t * 25.0 +
			zap_visual_time * (12.0 + f32(strand) * 3.0) +
			phase

		offset +=
			right * math.sin(spread_phase) * 0.08 * envelope +
			up * math.cos(spread_phase * 0.73) * 0.08 * envelope
	}

	candidate := base + offset

	// Fine visual jitter must not poke back through a wall even when the
	// collision-safe backbone runs tightly around an obstacle.
	hit := cast_zap_environment(
		base,
		candidate - base,
	)

	if hit.hit {
		return (
			hit.point +
				hit.normal * ZAP_OBSTACLE_CLEARANCE
		)
	}

	return candidate
}

sample_zap_backbone :: proc(arc: int, t: f32) -> rl.Vector3 {
	clamped_t := clamp(t, 0.0, 1.0)
	scaled := clamped_t * f32(ZAP_BACKBONE_POINT_COUNT - 1)
	index := int(scaled)

	if index >= ZAP_BACKBONE_POINT_COUNT - 1 {
		return zap_backbone_current[arc][ZAP_BACKBONE_POINT_COUNT - 1]
	}

	local_t := scaled - f32(index)
	start := zap_backbone_current[arc][index]
	end := zap_backbone_current[arc][index + 1]

	return start + (end - start) * local_t
}

get_zap_contact :: proc() -> (position, normal: rl.Vector3) {
	lock_center := get_enemy_lock_position()
	source := get_flashfield_center()

	// Surface point on the tagged enemy facing the incoming electrical field.
	normal = normalize_vector3(source - lock_center)
	if vector3_length_squared(normal) <= 0.0001 {
		normal = rl.Vector3{0, 0, 1}
	}

	position =
		lock_center +
		normal * (ENEMY_RADIUS + 0.03)

	return
}

draw_zap_contact_effect :: proc() {
	if !zap_active {
		return
	}

	contact, contact_normal := get_zap_contact()

	// Small white-hot contact core. The directional spark spray below does
	// most of the visual work; this is intentionally not a large pulsing orb.
	rl.DrawSphere(
		contact,
		0.09,
		rl.Color{240, 255, 255, 255},
	)

	world_up := rl.Vector3{0, 1, 0}
	right := rl.Vector3CrossProduct(world_up, contact_normal)
	if vector3_length_squared(right) < 0.001 {
		right = rl.Vector3{1, 0, 0}
	}
	right = normalize_vector3(right)

	up := normalize_vector3(
		rl.Vector3CrossProduct(contact_normal, right),
	)

	for i in 0..<24 {
		// Strongly bias every spark away from the struck surface. The random
		// side/up components turn that into a directional cone instead of a
		// radial firework.
		sideways := random_zap_offset() * 0.65
		vertical := random_zap_offset() * 0.65

		direction := normalize_vector3(
			contact_normal * 1.5 +
			right * sideways +
			up * vertical,
		)

		start_distance :=
			f32(rl.GetRandomValue(0, 8)) /
			100.0

		length :=
			0.20 +
			f32(rl.GetRandomValue(0, 50)) /
			100.0

		start :=
			contact +
			direction * start_distance

		end :=
			start +
			direction * length

		color := rl.Color{110, 225, 255, 220}
		if i % 4 == 0 {
			color = rl.Color{255, 255, 230, 255}
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

get_zap_anchor :: proc(arc_index: int) -> rl.Vector3 {
	center := get_flashfield_center()
	target, _ := get_zap_contact()
	to_target := normalize_vector3(target - center)

	world_up := rl.Vector3{0, 1, 0}
	right := rl.Vector3CrossProduct(world_up, to_target)
	if vector3_length_squared(right) <= 0.0001 {
		right = rl.Vector3{1, 0, 0}
	}
	right = normalize_vector3(right)
	up := normalize_vector3(
		rl.Vector3CrossProduct(to_target, right),
	)

	angle :=
		f32(arc_index) * 120.0 +
		zap_visual_time * ZAP_ANCHOR_ROTATION_SPEED

	offset :=
		right * math.cos(math.to_radians(angle)) +
		up * math.sin(math.to_radians(angle))

	candidate := center + offset * ZAP_RING_RADIUS

	// If the Flashfield overlaps a wall or floor, keep the anchor on the
	// visible side rather than letting a strand begin inside geometry.
	hit := cast_zap_environment(
		center,
		candidate - center,
	)

	if hit.hit {
		return (
			hit.point +
				hit.normal * ZAP_OBSTACLE_CLEARANCE
		)
	}

	return candidate
}

cubic_bezier :: proc(
	p0, p1, p2, p3: rl.Vector3,
	t: f32,
) -> rl.Vector3 {
	u := 1.0 - t
	u2 := u * u
	t2 := t * t

	return (
		p0 * (u2 * u) +
		p1 * (3.0 * u2 * t) +
		p2 * (3.0 * u * t2) +
		p3 * (t2 * t)
	)
}

random_zap_direction :: proc() -> rl.Vector3 {
	direction := rl.Vector3{
		random_zap_offset(),
		random_zap_offset(),
		random_zap_offset(),
	}

	if vector3_length_squared(direction) <= 0.0001 {
		return rl.Vector3{1, 0, 0}
	}

	return normalize_vector3(direction)
}

random_zap_offset :: proc() -> f32 {
	return f32(rl.GetRandomValue(-1000, 1000)) / 1000.0
}

vector3_distance :: proc(a, b: rl.Vector3) -> f32 {
	d := b - a
	return math.sqrt(vector3_length_squared(d))
}

vector3_length_squared :: proc(v: rl.Vector3) -> f32 {
	return (
		v.x * v.x +
		v.y * v.y +
		v.z * v.z
	)
}

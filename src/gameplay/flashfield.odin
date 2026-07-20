package gameplay

import rl "vendor:raylib"
import b3 "vendor:box3d"
import rlgl "vendor:raylib/rlgl"
import "core:c"
import player "../player"

FLASHFIELD_RADIUS :: 2.5

flashfield_model:  rl.Model
flashfield_shader: rl.Shader

flashfield_camera_pos_loc:     c.int
flashfield_center_loc:         c.int
flashfield_camera_forward_loc: c.int
flashfield_time_loc:           c.int
flashfield_radius_loc:         c.int

init_flashfield :: proc() {
	mesh := rl.GenMeshSphere(
		FLASHFIELD_RADIUS,
		32,
		32,
	)

	flashfield_model = rl.LoadModelFromMesh(mesh)
	flashfield_shader = rl.LoadShader(
		"asset/shader/flashfield.vs",
		"asset/shader/flashfield.fs",
	)

	flashfield_model.materials[0].shader = flashfield_shader

	flashfield_camera_pos_loc =
		rl.GetShaderLocation(flashfield_shader, "cameraPos")
	flashfield_center_loc =
		rl.GetShaderLocation(flashfield_shader, "fieldCenter")
	flashfield_camera_forward_loc =
		rl.GetShaderLocation(flashfield_shader, "cameraForward")
	flashfield_time_loc =
		rl.GetShaderLocation(flashfield_shader, "time")
	flashfield_radius_loc =
		rl.GetShaderLocation(flashfield_shader, "fieldRadius")
}

get_flashfield_center :: proc() -> rl.Vector3 {
	player_pos :=
		b3.Body_GetPosition(
			player.player.body_id,
		)

	return {
		player_pos.x,
		player_pos.y,
		player_pos.z,
	}
}

draw_flashfield :: proc() {
	if !flashfield_active {
		return
	}

	center := get_flashfield_center()
	camera_pos := player.camera.position
	camera_forward :=
		normalize_vector3(
			player.camera.target -
				player.camera.position,
		)

	time_value: f32 = zap_visual_time
	radius_value: f32 = FLASHFIELD_RADIUS

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

	rl.SetShaderValue(
		flashfield_shader,
		flashfield_camera_forward_loc,
		&camera_forward,
		.VEC3,
	)

	rl.SetShaderValue(
		flashfield_shader,
		flashfield_time_loc,
		&time_value,
		.FLOAT,
	)

	rl.SetShaderValue(
		flashfield_shader,
		flashfield_radius_loc,
		&radius_value,
		.FLOAT,
	)

	rl.BeginBlendMode(.ADDITIVE)

	rlgl.DisableBackfaceCulling()
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

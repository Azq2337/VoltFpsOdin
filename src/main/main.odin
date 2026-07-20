package main

import rl "vendor:raylib"
import b3 "vendor:box3d"

import world "../world"
import player "../player"
import gameplay "../gameplay"
import npc "../npc"

main :: proc() {
	init()
	defer shutdown()
	loop()
}

create_game_world :: proc() {
	world_def :=
		b3.DefaultWorldDef()

	world_def.gravity =
		{0, -9.8, 0}

	world.world_id =
		b3.CreateWorld(
			world_def,
		)

	world.world_initialized = true

	player.player =
		player.create_player(
			world.world_id,
		)

	npc.init_enemies(
		world.world_id,
	)

	for box in world.ROOM_BOXES {
		_ = world.create_static_box(
			world.world_id,
			box.center,
			box.half_size,
		)
	}
}

destroy_game_world :: proc() {
	if !world.world_initialized {
		return
	}

	b3.DestroyWorld(
		world.world_id,
	)

	world.world_initialized = false
}

reset_runtime_gameplay_state :: proc() {
	gameplay.reset_projectiles()
	player.reset_player_runtime_state()

	gameplay.reset_aiming_state()
	gameplay.reset_zap_state()
	player.reset_camera()
}

start_new_game :: proc() {
	destroy_game_world()
	create_game_world()
	reset_runtime_gameplay_state()
	world.enter_playing_state()
}

leave_game_to_main_menu :: proc() {
	destroy_game_world()

	gameplay.reset_projectiles()
	player.reset_player_runtime_state()

	world.show_main_menu()
}

init :: proc() {
	rl.InitWindow(
		1280,
		720,
		"Volt FPS Odin",
	)

	gameplay.init_flashfield()

	rl.SetTargetFPS(
		world.FRAMERATE,
	)

	rl.SetExitKey(.KEY_NULL)
	rl.EnableCursor()

	world.show_main_menu()
}

update_gameplay :: proc() {
	gameplay.update_aim_mode_input()

	if rl.IsKeyPressed(.F2) {
		player.toggle_third_person_camera()
	}

	if rl.IsKeyPressed(.F3) {
		player.toggle_debug_camera()
	}

	if rl.IsKeyPressed(.F4) {
		gameplay.toggle_aim_debug_rays()
	}

	if rl.IsKeyPressed(.F5) {
		npc.toggle_enemy_auto_respawn()
	}

	if !player.debug_camera_enabled {
		player.update_player()
	}

	b3.World_Step(
		world.world_id,
		world.TIME_STEP,
		world.SUB_STEP_COUNT,
	)

	mouse_delta :=
		world.get_gameplay_mouse_delta()

	camera_mouse_delta :=
		gameplay.update_floating_crosshair(
			mouse_delta,
		)

	player.update_camera(
		camera_mouse_delta,
	)

	gameplay.update_aiming()

	if !player.debug_camera_enabled {
		gameplay.shoot_projectile()
		gameplay.update_zap()
	} else {
		gameplay.flashfield_active = false
		gameplay.zap_active = false
	}

	gameplay.update_projectiles()
	npc.update_enemies()
}

is_world_position_in_front :: proc(
	position: rl.Vector3,
) -> bool {
	to_position :=
		position -
		player.camera.position

	camera_forward :=
		player.camera.target -
		player.camera.position

	dot :=
		to_position.x *
			camera_forward.x +
		to_position.y *
			camera_forward.y +
		to_position.z *
			camera_forward.z

	return dot > 0
}

draw_gameplay_hud :: proc() {
	radii :=
		gameplay.get_floating_crosshair_radii()

	world.draw_free_aim_debug_circle(
		gameplay.aim_debug_rays_enabled &&
			gameplay.auto_aim_enabled,
		radii.x,
	)

	world.draw_crosshair(
		gameplay.get_crosshair_screen_position(),
	)

	// Projectile impact hint.
	projectile_origin :=
		gameplay.get_gun_muzzle_position()

	projectile_direction :=
		gameplay.get_gun_projectile_direction()

	projectile_translation :=
		projectile_direction *
			gameplay.PROJECTILE_MAX_RANGE

	projectile_hit :=
		gameplay.cast_projectile(
			projectile_origin,
			projectile_translation,
		)

	if projectile_hit.hit {
		impact_position :=
			projectile_origin +
			projectile_translation *
				projectile_hit.fraction

		if is_world_position_in_front(
			impact_position,
		) {
			world.draw_hit_hint(
				rl.GetWorldToScreen(
					impact_position,
					player.camera,
				),
			)
		}
	}

	for i in 0..<npc.MAX_ENEMIES {
		if !npc.enemies[i].active ||
		   !npc.enemies[i].alive {
			continue
		}

		lock_position :=
			npc.get_enemy_lock_position(i)

		if !is_world_position_in_front(
			lock_position,
		) {
			continue
		}

		health_position :=
			rl.Vector3{
				lock_position.x,
				lock_position.y +
					npc.ENEMY_HALF_HEIGHT +
					npc.ENEMY_RADIUS +
					0.4,
				lock_position.z,
			}

		world.draw_enemy_health_bar(
			rl.GetWorldToScreen(
				health_position,
				player.camera,
			),
			npc.enemies[i].health /
				npc.enemies[i].max_health,
		)

		if npc.enemies[i].tag_count > 0 {
			world.draw_enemy_tag(
				rl.GetWorldToScreen(
					lock_position,
					player.camera,
				),
				npc.enemies[i].tag_count,
			)
		}
	}

	if gameplay.auto_aim_enabled &&
	   gameplay.is_auto_aim_target_valid(
			gameplay.current_auto_aim_target,
		) {
		target_position :=
			npc.get_enemy_lock_position(
				gameplay.current_auto_aim_target,
			)

		if is_world_position_in_front(
			target_position,
		) {
			world.draw_auto_aim_target(
				rl.GetWorldToScreen(
					target_position,
					player.camera,
				),
			)
		}
	}

	world.draw_training_status(
		gameplay.auto_aim_enabled,
		npc.enemy_auto_respawn_enabled,
		gameplay.aim_debug_rays_enabled,
	)

	rl.DrawFPS(
		10,
		10,
	)

	rl.DrawText(
		"Volt FPS Odin",
		10,
		35,
		20,
		rl.DARKGRAY,
	)
}

handle_menu_action :: proc(
	action: world.Menu_Action,
) {
	switch action {
	case .NONE:
		return

	case .START_GAME:
		start_new_game()

	case .OPTIONS:
		world.open_options_menu(
			world.game_screen,
		)

	case .EXIT:
		world.game_running = false

	case .CONTINUE:
		world.resume_game()

	case .RESTART:
		restart_game()

	case .MAIN_MENU:
		leave_game_to_main_menu()

	case .BACK:
		world.close_options_menu()

	case .TOGGLE_AUTO_AIM:
		gameplay.toggle_auto_aim()

	case .TOGGLE_AIM_RAYS:
		gameplay.toggle_aim_debug_rays()

	case .TOGGLE_RESPAWN:
		npc.toggle_enemy_auto_respawn()
	}
}

loop :: proc() {
	for world.game_running &&
	    !rl.WindowShouldClose() {
		world.update_window_and_cursor_state()

		switch world.game_screen {
		case .PLAYING:
			if rl.IsKeyPressed(.ESCAPE) {
				world.pause_game()
			}

			if world.game_screen == .PLAYING {
				update_gameplay()
			}

		case .PAUSED:
			if rl.IsKeyPressed(.ESCAPE) {
				world.resume_game()
			}

		case .OPTIONS:
			if rl.IsKeyPressed(.ESCAPE) {
				world.close_options_menu()
			}

		case .MAIN_MENU:
		}

		rl.BeginDrawing()

		rl.ClearBackground(
			rl.RAYWHITE,
		)

		if world.world_initialized {
			rl.BeginMode3D(
				player.camera,
			)

			{
				defer rl.EndMode3D()

				world.draw_room()
				npc.draw_enemies()
				player.draw_player()
				gameplay.draw_projectiles()
				gameplay.draw_flashfield()
				gameplay.draw_gun()
				gameplay.draw_zap_arcs()
				gameplay.draw_aim_debug_ray()
			}
		}

		switch world.game_screen {
		case .MAIN_MENU:
			handle_menu_action(
				world.draw_main_menu(),
			)

		case .OPTIONS:
			handle_menu_action(
				world.draw_options_menu(
					gameplay.auto_aim_enabled,
					gameplay.aim_debug_rays_enabled,
					npc.enemy_auto_respawn_enabled,
					world.world_initialized,
				),
			)

		case .PAUSED:
			handle_menu_action(
				world.draw_pause_screen(),
			)

		case .PLAYING:
			draw_gameplay_hud()
		}

		rl.EndDrawing()
	}
}

shutdown :: proc() {
	destroy_game_world()

	gameplay.shutdown_flashfield()
	rl.CloseWindow()
}

restart_game :: proc() {
	destroy_game_world()

	create_game_world()
	reset_runtime_gameplay_state()
	world.enter_playing_state()
}

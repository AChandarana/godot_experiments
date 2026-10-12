extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func tick() -> void:
	await physics_frame
	await process_frame

func run_test() -> void:
	if "turn" in OS.get_cmdline_user_args():
		quit(0 if await jump_test(Vector3.DOWN) else 1)
		return
	if "visual" in OS.get_cmdline_user_args():
		if await walk_lap("move_forward") and await jump_test(Vector3.UP):
			print("PASS: rendered lap and jump")
			quit()
		else:
			quit(1)
		return
	for action in ["move_forward", "move_backward", "move_left", "move_right", "diagonal"]:
		if not await walk_lap(action):
			quit(1)
			return
	for start_up in [Vector3.UP, Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD]:
		if not await jump_test(start_up):
			quit(1)
			return
	print("PASS: all planet playtests completed")
	quit()

func make_level(start_up: Vector3 = Vector3.UP) -> Node3D:
	var level: Node3D = load("res://level_1.tscn").instantiate()
	if start_up == Vector3.FORWARD:
		level.position = Vector3(35, -12, 8)
	level.get_node("Player").position = start_up * 11.3
	root.add_child(level)
	return level

func walk_lap(action: String) -> bool:
	var level := make_level()
	var player: CharacterBody3D = level.get_node("Player")
	var planet: Node3D = level.get_node("Planet")
	for i in range(90):
		await tick()
	var previous := (player.global_position - planet.global_position).normalized()
	var travel := 0.0
	var airborne_frames := 0
	var min_radius := INF
	var max_radius := 0.0
	var actions: Array[String] = [action]
	if action == "diagonal":
		actions = ["move_forward", "move_right"]
	for key in actions:
		Input.action_press(key)
	for frame in range(1200):
		await tick()
		var offset := player.global_position - planet.global_position
		travel += previous.angle_to(offset.normalized())
		previous = offset.normalized()
		min_radius = minf(min_radius, offset.length())
		max_radius = maxf(max_radius, offset.length())
		if not player.is_on_floor():
			airborne_frames += 1
		if offset.length() > 16.0 or offset.length() < 10.0:
			print("FAIL: left planet at frame ", frame, "; radius=", offset.length(), "; travel=", rad_to_deg(travel), " degrees; airborne=", airborne_frames)
			return false
		if absf(player.global_basis.determinant() - 1.0) > 0.001:
			print("FAIL: player scale changed during walking")
			return false
	for key in actions:
		Input.action_release(key)
	if travel < TAU:
		print("FAIL: could not complete a lap; travel=", rad_to_deg(travel))
		return false
	if airborne_frames > 0 or max_radius - min_radius > 0.02:
		print("FAIL: contact jitter during ", action, "; airborne=", airborne_frames, "; radius range=", max_radius - min_radius)
		return false
	for i in range(60):
		await tick()
	var stopped_position := player.global_position
	for i in range(60):
		await tick()
	if stopped_position.distance_to(player.global_position) > 0.005:
		print("FAIL: drifting after releasing movement")
		return false
	print("PASS: ", action, "; travel=", rad_to_deg(travel), "; airborne=", airborne_frames, "; radius range=", max_radius - min_radius)
	level.queue_free()
	await tick()
	return true

func jump_test(start_up: Vector3) -> bool:
	var level := make_level(start_up)
	var player: CharacterBody3D = level.get_node("Player")
	var planet: Node3D = level.get_node("Planet")
	for i in range(90):
		await tick()
	if not player.is_on_floor():
		print("FAIL: cannot settle at ", start_up)
		return false
	var initial_radius := player.global_position.distance_to(planet.global_position)
	if start_up == Vector3.FORWARD:
		# Exercise the airborne fallback without a ray hit.
		player.get_node("RayCast3D").collision_mask = 0
	Input.action_press("move_forward")
	Input.action_press("ui_accept")
	await tick()
	Input.action_release("ui_accept")
	var peak_radius := initial_radius
	var was_airborne := false
	for frame in range(180):
		await tick()
		var radius := player.global_position.distance_to(planet.global_position)
		peak_radius = maxf(peak_radius, radius)
		was_airborne = was_airborne or not player.is_on_floor()
		if radius > 16.0 or radius < 10.0:
			print("FAIL: jump escaped planet at ", start_up)
			return false
		if frame == 20:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var mouse := InputEventMouseMotion.new()
			mouse.relative = Vector2(150, 0)
			var prior_up := player.global_basis.y
			var prior_heading := player.global_basis.z
			if DisplayServer.get_name() == "headless":
				player.pending_yaw = -0.75
			else:
				player._input(mouse)
			await tick()
			if player.global_basis.y.dot(prior_up) < 0.99 or player.global_basis.z.angle_to(prior_heading) < 0.7:
				print("FAIL: turning check; up dot=", player.global_basis.y.dot(prior_up), "; heading angle=", player.global_basis.z.angle_to(prior_heading), "; pending yaw=", player.pending_yaw)
				return false
	Input.action_release("move_forward")
	if not was_airborne or peak_radius - initial_radius < 2.0 or not player.is_on_floor():
		print("FAIL: jump/landing at ", start_up, "; height=", peak_radius - initial_radius, "; grounded=", player.is_on_floor())
		return false
	print("PASS: jump and landing at ", start_up, "; height=", peak_radius - initial_radius)
	level.queue_free()
	await tick()
	return true

extends CarBase
class_name PlayerCar

@export_category("Player Head Controls")
@export var head_control_enabled : bool = true
@export var look_around_sensitivity : float = 0.01

@export_category("Player Input")
@export var input_steering_sensitivity : float = 1.0
@export var input_acceleration_sensitivity : float = 1.0

var manual_head_rotation: Vector2 = Vector2.ZERO

func calculate_desired_input(delta: float):
	# Get player movement input
	var input_vector: Vector2 = Vector2.ZERO
	input_vector.x = Input.get_axis("right", "left") * input_steering_sensitivity
	input_vector.y = Input.get_axis("down", "up") * input_acceleration_sensitivity
	_target_input = input_vector
	
	if head_control_enabled and _head_node:
		handle_head_controls(delta)
	
	# Manual recovery
	if Input.is_action_just_pressed("recovery"):
		start_recovery()
		
	# Head bash attack
	if Input.is_action_just_pressed("attack") and has_combat:
		try_head_bash()
		
func handle_head_controls(delta: float):
	# Mouse look for head
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion: Vector2 = Input.get_last_mouse_velocity() * look_around_sensitivity
		manual_head_rotation.x = clamp(manual_head_rotation.x - mouse_motion.y, -1.0, 1.0)
		manual_head_rotation.y = clamp(manual_head_rotation.y - mouse_motion.x, -1.0, 1.0)
		
	# Reset head look with middle mouse
	if Input.is_action_just_pressed("reset_head_rot"):
		manual_head_rotation = Vector2.ZERO
	
	# Apply manual head rotation
	if manual_head_rotation.length() > 0.01:
		_head_target_rotation = Vector3(
			manual_head_rotation.x * deg_to_rad(45),
			manual_head_rotation.y * deg_to_rad(90),
			0
		)
	else:
		# Auto-look in driving direction when not manually controlling
		var look_ahead_amount : float = clamp(get_speed_kmh() / 50.0, 0.0, 1.0)
		_head_target_rotation.y = _current_steer * deg_to_rad(30) * look_ahead_amount

func try_head_bash():
	# Find nearst enemy in front 
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy_cars")
	var best_target = null
	var best_distance: float = 15.0 # Max bash range
	
	for enemy in enemies:
		if enemy == self:
			continue
		var direction = enemy.global_position - global_position
		var distance = direction.length()
		var forward_dot: float = global_basis.z.dot(direction.normalized())
		
		# Must be in front and close enough
		if forward_dot > 0.7 and distance < best_distance:
			best_distance = distance
			best_target = enemy
	
	if best_target:
		perform_head_bash(best_target)
	
	
func get_desired_input() -> Vector2:
	return _target_input
	
func check_combat_collisions():
	pass
	
func start_damage_flash() -> void:
	pass
	
func explode() -> void:
	pass	
	
# Add player-specific methods
func boost_power(amount: float, duration: float):
	pass
	
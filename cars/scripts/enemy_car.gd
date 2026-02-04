extends CarBase
class_name EnemyCar

@export_category("AI Settings")
@export var target_path : NodePath
@export var attack_distance : float = 10.0
@export var follow_distance : float = 5.0
@export var ramming_distance : float = 3.0
@export var use_pathfinding : bool = true
enum Behavior { CHASER, BLOCKER, PATROLLER }
@export var behavior: Behavior

@export_category("Enemy AI - Head Behavior")
@export var use_head_for_recovery : bool = true
@export var use_head_for_combat: bool = true

var target : Node3D = null
var nav_agent : NavigationAgent3D
var current_waypoint : Vector3

func _ready() -> void:
	super._ready()
	
	if target_path:
		target = get_node(target_path)
	
	if use_pathfinding:
		setup_pathfinding()
		
	set_ai_behavior(behavior)
		
func setup_pathfinding():
	nav_agent = NavigationAgent3D.new()
	add_child(nav_agent)
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	nav_agent.path_max_distance = 50.0
	
func calculate_desired_input(delta: float) -> void:
	if not target:
		_target_input = Vector2.ZERO
		return
		
	# Calculate desired movement
	var desired_input: Vector2 = Vector2.ZERO
	
	if use_pathfinding and nav_agent:
		update_pathfinding()
		desired_input = calculate_path_input()
	else:
		desired_input = calculate_pursuit_input()
		
	# Modify based on difficulty/behaviour params
	desired_input.x *= skill_level
	desired_input.y *= aggressiveness
	
	_target_input = desired_input
	
	
func get_desired_input() -> Vector2:
	return _target_input
	
func update_pathfinding():
	if target and nav_agent:
		nav_agent.target_position = target.global_transform.origin
		if nav_agent.is_navigation_finished():
			current_waypoint = nav_agent.get_next_path_position()
			
func calculate_path_input() -> Vector2:
	var input_vector: Vector2 = Vector2.ZERO
	
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_point: Vector3 = nav_agent.get_next_path_position()
		var direction: Vector3 = (next_point - global_transform.origin).normalized()
		
		# Calculate steeering based on dieraction
		var local_direction: Vector3 = global_transform.basis.inverse() * direction
		input_vector.x = clamp(local_direction.x, -1.0, 1.0)
		
		# Calculate acceleration based on distance
		var distance_to_target: float = global_transform.origin.distance_to(target.global_transform.origin)
		if distance_to_target > follow_distance:
			input_vector.y = 1.0 # Accelerate
		elif distance_to_target < ramming_distance:
			input_vector.y = -0.5 # Brake/Reverse 
		else: 
			input_vector.y = 0.3
			
	return input_vector	

func calculate_pursuit_input() -> Vector2:
	var input_vector: Vector2 = Vector2.ZERO	
	var to_target: Vector3 = target.global_transform.origin - global_transform.origin
	var distance: float = to_target.length()
	
	# Calculate steering using pursuit prediction
	var target_velocity = target.linear_velocity if target.has_method("get_linear_velocity") else Vector3.ZERO
	
	var prediction_time = distance / max(1.0, get_speed_kmh() / 3.6)
	var predicted_position = target.global_transform.origin + target_velocity * prediction_time
	var to_predicted = predicted_position - global_transform.origin
	var local_direction = global_transform.basis.inverse() * to_predicted.normalized()
	
	input_vector.x = clamp(local_direction.x, -1.0, 1.0)
	
	# Acceleration logic
	if distance > attack_distance:
		input_vector.y = 1.0 # Pursue aggressively
	elif distance > follow_distance:
		input_vector.y = 0.5 # Close in
	else:
		input_vector.y = 0.0 # Match speed
		
	return input_vector

func check_combat_collisions():
	pass
	
func start_damage_flash() -> void:
	pass
	
func explode() -> void:
	pass
	
func set_target(new_target: Node3D):
	target = new_target
	
func set_ai_behavior(behavior_type: Behavior):
	# Different enemy behaviors (chaser, blocker, patroller, etc.)
	match behavior_type:
		Behavior.CHASER:
			aggressiveness = 1.5
			follow_distance = 3.0
		Behavior.BLOCKER:
			aggressiveness = 1.2
			follow_distance = 2.0
		Behavior.PATROLLER:
			aggressiveness = 0.8
			follow_distance = 8.0

@abstract
class_name CarBase
extends VehicleBody3D

@export_category("Car Settings")
## Max steer in radians for the front wheels- defaults to 0.45
@export var max_steer : float = 0.45
## The maximum torque that the engine will sent to the rear wheels- defaults to 300
@export var max_torque : float = 300.0
## The maximum amount of braking force applied to the wheel. Default is 1.0
@export var max_brake_force : float = 1.0
## The maximum rear wheel rpm. The default value is 600rpm
## The actual engine torque is scaled in a linear vector to ensure the rear wheels will never go beyond this given rpm.
@export var max_wheel_rpm : float = 600.0
## How quickly the wheel responds to player input- equates to seconds to reach maximum steer. Default is 2.0
@export var steer_damping : float = 2.0
## How sticky are the front wheels. Default is 5. 0 is frictionless._add_constant_central_force
@export var front_wheel_grip : float = 5.0
## How sticky are the rear wheel. Default is 5. Try lower value for a more drift experience
@export var rear_wheel_grip : float = 5.0
## How front wheels resist vehicle body roll, 0.0 value means prone to roll over.
@export var front_wheel_roll_influence : float = 1.0
## How rear wheels resist vehicle body roll. If set 1.0 for all wheels, vehicle will resist to roll. 
@export var rear_wheel_roll_influence : float = 1.0
## Car mass for physics calculations
@export var weight : float = 200.0

## Head/Recovery Settings
@export_category("Head & Recovery")
@export var head_node_path : NodePath
@export var head_rotation_speed : float = 3.0
@export var head_max_torque : float = 50.0
## Degrees from upright
@export var recovery_trigger_angle : float = 45.0
## Seconds before auto-recovery
@export var auto_recovery_delay : float = 2.0
## Cooldown between recoveries
@export var recovery_cooldown : float = 1.0

## Combat Settings
@export_category("Combat")
@export var has_combat : bool = false
@export var head_bash_damage : float = 10.0
@export var head_bash_force : float = 15.0
@export var head_bash_cooldown : float = 1.0
@export var health : float = 100.0
@export var max_health : float = 100.0

## Difficulty/Behavior Settings
@export_category("Behaviour Settings")
## How aggressive the car is (0 - 2)
@export var aggressiveness : float = 1.0
## Affects steering precision, braking timing (0.5 - 1.5)	
@export var skill_level : float = 1.0
## Delay in reaction (seconds)		
@export var reaction_time : float = 0.2	

# Protected variables for derived classes
var _current_acceleration : float = 0.0
var _current_braking : float = 0.0
var _current_steer : float = 0.0
var _target_input : Vector2 = Vector2.ZERO

# Head/Recovery variables
var _head_node : Node3D
var _head_target_rotation : Vector3 = Vector3.ZERO
var _head_current_rotation : Vector3 = Vector3.ZERO
var _is_recovering : bool = false
var _recovery_cooldown_timer : float = 0.0
var _time_upside_down : float = 0.0

# Combat variables
var _can_bash : bool = true
var _bash_cooldown_timer : float = 0.0
var _is_invincible : bool = false
var _invisibility_timer : float = 0.0

# References to wheels
# An exporetd array of driving wheels so we can limit rom of each wheel when we process input
@onready var driving_wheels : Array[VehicleWheel3D] = [$WheelBackLeft,$WheelBackRight]
@onready var steering_wheels : Array[VehicleWheel3D] = [$WheelFrontLeft,$WheelFrontRight]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_head()
	initialize_vehicle()
	
func setup_head():
	if head_node_path:
		_head_node = get_node(head_node_path)
		if _head_node:
			_head_current_rotation = _head_node.rotation
	
func initialize_vehicle():
	# Set mass
	mass = weight
	# Set wheel friction slip and roll influence
	for wheel in steering_wheels:
		wheel.wheel_friction_slip = front_wheel_grip * skill_level
		wheel.wheel_roll_influence = front_wheel_roll_influence * skill_level
	for wheel in driving_wheels:
		wheel.wheel_friction_slip = rear_wheel_grip * skill_level
		wheel.wheel_roll_influence = rear_wheel_roll_influence * skill_level
		
func _physics_process(delta: float) -> void:
	update_timers(delta)
	update_recovery_state(delta)
	calculate_desired_input(delta)	
	# Apply reaction time delay
	_target_input = lerp(_target_input, get_desired_input(), delta / (reaction_time + 0.01))
	process_input(delta)
	# Apply to vehicle
	apply_controls(delta)
	update_head_rotation(delta)
	
	if has_combat:
		update_combat(delta)
		
func update_timers(delta: float):
	# Recovery cooldown
	if _recovery_cooldown_timer > 0:
		_recovery_cooldown_timer	-= delta
	
	# Bash cooldown
	if _bash_cooldown_timer > 0:
		_bash_cooldown_timer -= delta
	else: 
		_can_bash = true
	
	# Invincivility
	if _invisibility_timer > 0:
		_invisibility_timer -= delta
	else: 
		_is_invincible = false
		
func update_recovery_state(delta: float):
	# Check if car is flipped
	var up_dot: float = global_basis.y.dot(Vector3.UP)
	var tilt_angle: float = rad_to_deg(acos(clamp(up_dot, -1.0, 1.0)))
	print("Tilt angle: %s" % tilt_angle)
	
	if tilt_angle > recovery_trigger_angle:
		_time_upside_down += delta
		#Auto-recovery after delay
		if _time_upside_down >= auto_recovery_delay and _recovery_cooldown_timer <= 0:
			start_recovery()
	else:
		_time_upside_down = 0.0
		_is_recovering = false
		
@abstract func calculate_desired_input(delta: float)

@abstract func get_desired_input() -> Vector2
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func process_input(delta: float) -> void:
	if _is_recovering: 
		# During recover, reduce control
		_current_steer *= 0.3
		_current_acceleration *= 0.5
		return
		
	# Process stering with damping 
	var desired_steer : float = _target_input.x * max_steer	* skill_level
	_current_steer = move_toward(_current_steer, desired_steer, steer_damping * delta)
	
	# Process acceleration/braking
	if _target_input.y > 0.01:
		# Accelerating
		_current_acceleration = _target_input.y * aggressiveness
		_current_braking = 0.0
	elif _target_input.y < -0.01:
		# Braking or reversing
		if going_forward():
			_current_braking = -_target_input.y * max_brake_force * aggressiveness
			_current_acceleration = 0.0
		else:
			_current_braking = 0.0
			_current_acceleration = _target_input.y
	else: 
		_current_acceleration = 0.0
		_current_braking = 0.0
		
func apply_controls(delta: float):
	steering = _current_steer
	brake = _current_braking
	
	# Apply recovery torque if active
	if _is_recovering:
		apply_recovery_torque(delta)
		
	# Apply engine force with RPM limiting
	for wheel in driving_wheels:
		var actual_force : float = _current_acceleration * max_torque * skill_level
		actual_force *= clamp(1.0 - abs(wheel.get_rpm()) / max_wheel_rpm, 0.1, 1.0)
		wheel.engine_force = actual_force
		
func update_head_rotation(delta: float) -> void:
	if not _head_node:
		return
		
	# Smoothly rotate head toward target
	_head_current_rotation = _head_current_rotation.lerp(_head_target_rotation, head_rotation_speed * delta)
	_head_node.rotation = _head_current_rotation	
	
func update_combat(delta: float):
	# Check for collisions with other cars
	check_combat_collisions()
	
@abstract func check_combat_collisions()

# RECOVERY SYSTEM
func start_recovery() -> void:
	if _recovery_cooldown_timer > 0:
		return
	_is_recovering = true
	_recovery_cooldown_timer = recovery_cooldown
	
	# Set head rotation for recovery
	_head_target_rotation = Vector3(0, 0, deg_to_rad(180)) # Look backward
	# Add a small upward impulse to help
	apply_central_impulse(Vector3.UP * weight * 0.5)
	
func apply_recovery_torque(delta: float):
	# Apply torque to upright the car using head momentum
	var up_dot: float = global_basis.y.dot(Vector3.UP)
	var torque_direction: float = sign(global_basis.z.dot(Vector3.UP))
	
	# Apply torque based on head rotation
	var recovery_torque = head_max_torque * (1.0 - abs(up_dot)) * torque_direction
	apply_torque_impulse(Vector3.UP * recovery_torque * delta)
	
	# Check if recovery is complete
	if up_dot > 0.8:
		end_recovery()
		
func end_recovery():
	_is_recovering = false
	_head_target_rotation = Vector3.ZERO
	_time_upside_down = 0.0
	
# COMBAT SYSTEM
func perform_head_bash(target_car: CarBase) -> void:
	if not _can_bash or not has_combat:
		return
	_can_bash = false
	_bash_cooldown_timer = head_bash_cooldown
	
	# Animate head bash
	_head_target_rotation = Vector3(deg_to_rad(45), 0, 0) # Nod forward
	
	# Apply force to target
	var direction_to_target: Vector3 = (target_car.global_position - global_position).normalized()
	target_car.take_damage(head_bash_damage, direction_to_target * head_bash_force)
	
	# Recoil effect
	apply_central_impulse(-direction_to_target * head_bash_force * 0.5)
	
	# Return head to normal after short delay
	await get_tree().create_timer(0.3).timeout
	_head_target_rotation = Vector3.ZERO
	
	
func take_damage(damage: float, knockback_force: Vector3 = Vector3.ZERO) -> void:
	if _is_invincible:
		return
		
	health -= damage
	
	# Apply knockback
	if knockback_force.length() > 0:
		apply_central_impulse(knockback_force)
		
	# Flash effect or other visual feedback
	start_damage_flash()
	
	if health <= 0:
		explode()
	else:
		# Brief invicibility after taking damage
		_is_invincible = true
		_invisibility_timer = 0.5

@abstract func start_damage_flash() -> void

@abstract func explode() -> void

func going_forward() -> bool:
	var relative_speed : float = basis.z.dot(linear_velocity.normalized())
	return relative_speed > 0.01
	
func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6
	
func look_at_target(target_position: Vector3) -> void:
	if not _head_node:
		return
		
	# Calculate direction to target in local space
	var local_target: Vector3 = to_local(target_position)
	_head_target_rotation.y = atan2(local_target.x, local_target.z)
	_head_target_rotation.x = -atan2(local_target.y, Vector2(local_target.z, local_target.x).length())
	# Clamp rotation
	_head_target_rotation.y = clamp(_head_target_rotation.y, deg_to_rad(-90), deg_to_rad(90))
	_head_target_rotation.x = clamp(_head_target_rotation.x, deg_to_rad(-45), deg_to_rad(45))
	
func set_difficulty_params(agressive: float, skill: float, reaction: float):
	self.aggressiveness = agressive
	self.skill_level = skill
	self.reaction_time = reaction
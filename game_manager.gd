extends Node
class_name GameManager

@export_category("Difficulty Settings")
@export_range(0, 2) var global_difficulty : float = 1.0
@export var player_skill_modifier : float = 1.0
@export var enemy_count : int = 3

var player_car : PlayerCar
var enemy_cars : Array[EnemyCar] = []

func setup_difficulty() -> void:
	if not player_car:
		return
		
	# Adjust player car based on difficulty
	player_car.skill_level = player_skill_modifier * (1.0 + (global_difficulty - 1.0) * 0.2)
	
	# Adjust enemies based on difficulty 
	for enemy in enemy_cars:
		var diff_multiplier: float = global_difficulty
		
		enemy.skill_level = 0.8 + (diff_multiplier * 0.4)
		enemy.aggressiveness = 0.7 + (diff_multiplier * 0.6)
		enemy.reaction_time = 0.3 - (diff_multiplier * 0.15)
		
		# Randomize slightly for variety
		enemy.skill_level += randf_range(-0.1, 0.1)
		enemy.aggressiveness += randf_range(-0.1, 0.1)

func set_difficulty_level(level: int):
	# Easy, Medium, Hard presets
	match level:
		0: # Easey
			global_difficulty = 0.7
			player_skill_modifier = 1.2
		1: # Medium 
			global_difficulty = 1.0
			player_skill_modifier = 1.0
		2: # Hard
			global_difficulty = 1.5
			player_skill_modifier = 0.9
			
	setup_difficulty()
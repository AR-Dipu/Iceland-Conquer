class_name GameConfig
extends Resource

@export var player_speed: float = 150.0
@export var bot_speed: float = 91.0
@export var acceleration: float = 680.0
@export var win_fraction: float = 0.60
@export var trail_spacing: float = 7.0
@export var trail_hit_radius: float = 9.0
@export var protection_seconds: float = 2.5
@export var max_trail_points: int = 1024
@export var team_colors: Array[Color] = [Color("9b5cff"), Color("ff5b68"), Color("ffd33d")]
@export var spawn_points: Array[Vector2] = [Vector2(235, 710), Vector2(462, 453), Vector2(466, 842)]

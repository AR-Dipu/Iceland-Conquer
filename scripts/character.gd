class_name ConquerCharacter
extends Node2D

var active: bool = true
var team: int = 0
var config: GameConfig
var velocity := Vector2.ZERO
var heading := Vector2.ZERO
var protection: float = 0.0
var clock: float = 0.0
var previous := Vector2.ZERO
var movement_path := PackedVector2Array()
var trail: ConquerTrail
var sprite: Sprite2D
var atlas: Texture2D = preload("res://assets/characters/cats.png")
const Collection = preload("res://scripts/character_collection.gd")
var speed_multiplier := 1.0
var acceleration_multiplier := 1.0
var revival_shield_bonus := 0.0
var appearance_id := "cat"
var pose_time := 0.0
var pose := ""
var art_scale := 1.0

func apply_character(id: String) -> void:
	if not Collection.CATALOG.has(id): return
	var entry: Array = Collection.CATALOG[id]
	if team == 0:
		speed_multiplier = entry[4]
		acceleration_multiplier = entry[5]
		revival_shield_bonus = entry[6]
	appearance_id = id
	sprite.texture = Collection.artwork(id)
	art_scale = 94.0 / float(sprite.texture.get_width())
	sprite.scale = Vector2.ONE * art_scale

func react(event: String) -> void:
	pose = event
	pose_time = 0.32

func movement_speed() -> float:
	return config.player_speed * speed_multiplier if team == 0 else config.bot_speed

func movement_acceleration() -> float:
	return config.player_acceleration * acceleration_multiplier if team == 0 else config.acceleration

func setup(index: int, settings: GameConfig) -> void:
	team = index
	config = settings
	position = config.spawn_points[team]
	previous = position
	z_index = 20
	trail = ConquerTrail.new()
	trail.tint = config.team_colors[team]
	sprite = Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	var cell: float = float(atlas.get_width()) / 4.0
	var cat_index: int = config.cat_indices[team]
	texture.region = Rect2(Vector2(cat_index % 4 * cell, cat_index / 4 * atlas.get_height() / 2), Vector2(cell, atlas.get_height() / 2))
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (94.0 / float(sprite.texture.get_width()))
	art_scale = sprite.scale.x
	sprite.position.y = -34.0
	add_child(sprite)

func reset_actor() -> void:
	position = config.spawn_points[team]
	previous = position
	velocity = Vector2.ZERO
	movement_path = PackedVector2Array([position])
	heading = Vector2.ZERO
	protection = config.protection_seconds
	trail.clear()

func advance(direction: Vector2, delta: float, island: PackedVector2Array) -> void:
	var was_protected := protection > 0
	previous = position
	velocity = velocity.move_toward(direction.limit_length() * movement_speed(), movement_acceleration() * delta)
	var motion := ShoreMotion.solve(position,velocity,delta,island)
	position = motion.position
	velocity = motion.velocity
	movement_path = motion.path
	if velocity.length() > 2.0:
		heading = velocity.normalized()
	clock += delta
	protection = maxf(0.0, protection - delta)
	pose_time = maxf(0.0,pose_time-delta)
	var moving := velocity.length_squared() > 100
	var stride := sin(clock * (16.0 if moving else 3.0) + team)
	var reaction := sin(PI*pose_time/0.32)
	var lift := reaction * (11.0 if pose == "capture" else 8.0)
	sprite.position.y = -34.0 - lift - (absf(stride)*6.0 if moving else stride*1.8)
	var squash := stride*0.05 if moving else stride*0.02
	sprite.scale = Vector2(1.0-squash,1.0+squash+reaction*0.12)*art_scale
	if absf(heading.x) > 0.2: sprite.flip_h = heading.x < 0
	sprite.rotation = lerpf(sprite.rotation, heading.x * 0.09, 0.12)
	sprite.modulate.a = 0.6 + 0.4 * absf(sin(clock * 9.0)) if protection > 0.0 else 1.0
	if protection > 0 or was_protected: queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 30, Color(0.02, 0.13, 0.20, 0.17))
	draw_circle(Vector2.ZERO, 21, Color(0.02, 0.13, 0.20, 0.12))
	draw_set_transform(Vector2.ZERO)
	if protection > 0.0:
		draw_arc(Vector2(0, -12), 41, 0, TAU, 48, Color(1, 1, 1, 0.55), 2.0, true)
		if pose == "revive" and pose_time > 0.0:
			draw_arc(Vector2(0,-12),42.0+(1.0-pose_time/0.32)*24.0,0,TAU,32,Color(0.72,0.94,1.0,pose_time/0.32),3,true)

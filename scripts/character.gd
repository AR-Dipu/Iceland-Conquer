class_name ConquerCharacter
extends Node2D

var active: bool = true
var team: int = 0
var config: GameConfig
var velocity := Vector2.ZERO
var heading := Vector2.ZERO
var protection: float = 0.0
var previous := Vector2.ZERO
var movement_path := PackedVector2Array()
var trail: ConquerTrail
var sprite: Sprite2D
var visual: Node2D
var facing := 1.0
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
	visual = Node2D.new()
	visual.draw.connect(_draw_presentation)
	add_child(visual)
	visual.add_child(sprite)

func reset_actor() -> void:
	position = config.spawn_points[team]
	previous = position
	velocity = Vector2.ZERO
	movement_path = PackedVector2Array([position])
	heading = Vector2.ZERO
	protection = config.protection_seconds
	trail.clear()
	facing = 1.0
	sprite.scale = Vector2.ONE * art_scale
	pose_time = 0.0
	snap_visual()

func advance(direction: Vector2, delta: float, island: PackedVector2Array) -> void:
	var was_protected := protection > 0
	var ripple_active := pose == "revive" and pose_time > 0.0
	previous = position
	velocity = velocity.move_toward(direction.limit_length() * movement_speed(), movement_acceleration() * delta)
	var motion := ShoreMotion.solve(position,velocity,delta,island)
	position = motion.position
	velocity = motion.velocity
	movement_path = motion.path
	if velocity.length() > 2.0:
		heading = velocity.normalized()
	protection = maxf(0.0, protection - delta)
	pose_time = maxf(0.0,pose_time-delta)
	if was_protected != (protection > 0) or ripple_active: visual.queue_redraw()

func visual_world_position() -> Vector2:
	return previous.lerp(position, Engine.get_physics_interpolation_fraction())

func snap_visual() -> void:
	previous = position
	if visual != null:
		visual.position = Vector2.ZERO
		visual.queue_redraw()

func _process(delta: float) -> void:
	if not active or visual == null: return
	visual.position = visual_world_position() - position
	if absf(heading.x) > 0.28: facing = signf(heading.x)
	var reaction := sin(PI * pose_time / 0.32)
	sprite.position.y = -34.0 - reaction * (11.0 if pose == "capture" else 8.0)
	sprite.scale.x = lerpf(sprite.scale.x, facing * art_scale, 1.0 - exp(-delta * 30.0))
	sprite.scale.y = (1.0 + reaction * 0.12) * art_scale


func _draw_presentation() -> void:
	visual.draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	visual.draw_circle(Vector2.ZERO, 30, Color(0.02, 0.13, 0.20, 0.17))
	visual.draw_circle(Vector2.ZERO, 21, Color(0.02, 0.13, 0.20, 0.12))
	visual.draw_set_transform(Vector2.ZERO)
	if protection > 0.0:
		visual.draw_arc(Vector2(0, -12), 41, 0, TAU, 48, Color(1, 1, 1, 0.55), 2.0, true)
		if pose == "revive" and pose_time > 0.0:
			visual.draw_arc(Vector2(0,-12),42.0+(1.0-pose_time/0.32)*24.0,0,TAU,32,Color(0.72,0.94,1.0,pose_time/0.32),3,true)

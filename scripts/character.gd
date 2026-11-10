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
var trail: ConquerTrail
var sprite: Sprite2D
var atlas: Texture2D = preload("res://assets/characters/cats.png")

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
	var index: int = config.cat_indices[team]
	texture.region = Rect2(Vector2(index % 4 * cell, index / 4 * atlas.get_height() / 2), Vector2(cell, atlas.get_height() / 2))
	sprite.texture = texture
	sprite.scale = Vector2.ONE * (94.0 / float(sprite.texture.get_width()))
	sprite.position.y = -34.0
	add_child(sprite)

func reset_actor() -> void:
	position = config.spawn_points[team]
	previous = position
	velocity = Vector2.ZERO
	heading = Vector2.ZERO
	protection = config.protection_seconds
	trail.clear()

func advance(direction: Vector2, delta: float, island: PackedVector2Array) -> void:
	previous = position
	var speed: float = config.player_speed if team == 0 else config.bot_speed
	velocity = velocity.move_toward(direction.limit_length() * speed, (config.player_acceleration if team == 0 else config.acceleration) * delta)
	var target: Vector2 = position + velocity * delta
	var hit_distance: float = INF
	var hit_point: Vector2 = target
	for i in island.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(position, target, island[i], island[(i + 1) % island.size()])
		if hit != null and position.distance_to(hit) > 0.001 and position.distance_to(hit) < hit_distance:
			hit_distance = position.distance_to(hit)
			hit_point = hit
	if hit_distance < INF:
		position = IslandGeometry.clamp_inside(island, hit_point)
		velocity = Vector2.ZERO
	elif Geometry2D.is_point_in_polygon(target, island):
		position = target
	else:
		var boundary: Dictionary = IslandGeometry.nearest(island, target)
		position = IslandGeometry.clamp_inside(island, target)
		velocity *= 0.35
	if velocity.length() > 2.0:
		heading = velocity.normalized()
	clock += delta
	protection = maxf(0.0, protection - delta)
	sprite.position.y = -34.0 + sin(clock * (10.0 if velocity.length() > 10.0 else 3.0) + team) * (2.2 if velocity.length() > 10.0 else 1.1)
	sprite.rotation = lerpf(sprite.rotation, heading.x * 0.09, 0.12)
	sprite.modulate.a = 0.6 + 0.4 * absf(sin(clock * 9.0)) if protection > 0.0 else 1.0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 30, Color(0.02, 0.13, 0.20, 0.17))
	draw_circle(Vector2.ZERO, 21, Color(0.02, 0.13, 0.20, 0.12))
	draw_set_transform(Vector2.ZERO)
	if protection > 0.0:
		draw_arc(Vector2(0, -12), 41, 0, TAU, 48, Color(1, 1, 1, 0.55), 2.0, true)

class_name IslandWorld
extends Node2D
## Legacy class name retained. All rendered geography now represents countries.
var map: CountryMap
var outline := PackedVector2Array()
var props: Texture2D = preload("res://assets/environment/atlas_landmarks.svg")
var context: CountryPresentation
var land_mesh: ArrayMesh
var flag_mesh: ArrayMesh
var flag_texture: Texture2D
var border_contour: PackedVector2Array
static var flag_codes: Dictionary = {}
const TERRAIN_COLOR := Color("c8df92")
var decorative_meshes: Array[ArrayMesh] = []
var relief := PackedVector2Array()
var waves := PackedVector2Array()
func setup(country: CountryMap) -> void:
	map = country
	outline = country.outline
	z_index = -10
	context = CountryPresentation.for_country(country)
	var land_indices := Geometry2D.triangulate_polygon(outline)
	land_mesh = CountryPresentation._mesh(outline,land_indices)
	border_contour = rounded_contour(outline)
	_prepare_flag(land_indices)
	for ring in country.decorative_islands:
		var indices := Geometry2D.triangulate_polygon(ring)
		if not indices.is_empty(): decorative_meshes.append(CountryPresentation._mesh(ring,indices))
	_prepare_atlas_marks()
	for prop in map.scenery:
		var cell := int(prop.cell)
		if (cell == 0 or cell == 3) and absf(map.latitude) > 32: cell = 3
		elif cell == 3: cell = 0
		_add_prop(cell,prop.position,float(prop.width))
	# Actual shared borders receive a narrow land apron to cover the visual
	# smoothing offset; this changes no collision or ownership geometry.
	queue_redraw()

func _prepare_flag(indices: PackedInt32Array) -> void:
	if flag_codes.is_empty():
		flag_codes = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/flags.json"))
	var code: String = flag_codes.get(map.country_id, "")
	if code.is_empty() or indices.is_empty(): return
	var texture := load("res://assets/flags/%s.svg" % code) as Texture2D
	if texture == null: return
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if maxi(image.get_width(), image.get_height()) > 512:
		var ratio := 512.0 / maxi(image.get_width(), image.get_height())
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var padded := Image.create_empty(image.get_width() + 4, image.get_height() + 4, false, Image.FORMAT_RGBA8)
	padded.fill(TERRAIN_COLOR)
	for y in image.get_height():
		for x in image.get_width():
			var ink := image.get_pixel(x, y)
			padded.set_pixel(x + 2, y + 2, TERRAIN_COLOR.lerp(ink, ink.a * 0.34))
	flag_texture = ImageTexture.create_from_image(padded)
	var bounds := map.land_bounds
	var size := texture.get_size()
	size *= minf(bounds.size.x / size.x, bounds.size.y / size.y)
	var center := IslandGeometry.interior_point(outline)
	var origin := (center - size * 0.5).clamp(bounds.position, bounds.end - size)
	var uv := PackedVector2Array()
	for point in outline:
		uv.append(((point - origin) / size * Vector2(image.get_size()) + Vector2(2, 2)) / flag_texture.get_size())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = outline
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	flag_mesh = ArrayMesh.new()
	flag_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func rounded_contour(ring: PackedVector2Array) -> PackedVector2Array:
	var contour := PackedVector2Array()
	for i in ring.size():
		var corner := ring[i]
		var incoming := ring[posmod(i - 1, ring.size())] - corner
		var outgoing := ring[(i + 1) % ring.size()] - corner
		var a := corner + incoming.limit_length(minf(3.0, incoming.length() * 0.2))
		var b := corner + outgoing.limit_length(minf(3.0, outgoing.length() * 0.2))
		contour.append(a)
		contour.append(a.lerp(corner, 0.5).lerp(corner.lerp(b, 0.5), 0.5))
		contour.append(b)
	if not contour.is_empty(): contour.append(contour[0])
	return contour

func _prepare_atlas_marks() -> void:
	var bounds := map.land_bounds
	for i in 180:
		var point := bounds.position + Vector2(fmod(i*173.7,bounds.size.x),fmod(i*271.3,bounds.size.y))
		if not Geometry2D.is_point_in_polygon(point,outline): continue
		for stripe in 3:
			var a := point + Vector2(stripe*6,-stripe*2)
			var b := a + Vector2(9,-8)
			if ShoreIndex.segment_inside(outline,a,b):
				relief.append(a)
				relief.append(b)
	for coast in context.coasts:
		for i in range(0,coast.size()-1,3):
			var direction := coast[i].direction_to(coast[i+1])
			var offset := direction.orthogonal()*15
			if Geometry2D.is_point_in_polygon(coast[i]+offset,outline): offset = -offset
			waves.append(coast[i]+offset)
			waves.append(coast[i].lerp(coast[i+1],0.65)+offset)
func _add_prop(cell: int, foot: Vector2, width: float) -> void:
	var sprite := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = props
	var cell_size := Vector2(props.get_width(),props.get_height())/2.0
	texture.region = Rect2(Vector2(cell%2,cell/2)*cell_size,cell_size)
	sprite.texture = texture
	sprite.scale = Vector2.ONE*width/cell_size.x
	sprite.position = foot-Vector2(0,width*0.44)
	sprite.z_index = 21
	add_child(sprite)
func _draw() -> void:
	if map == null or context == null: return
	for item in context.lands: draw_mesh(item.mesh,null,Transform2D.IDENTITY,Color("9b9a76"))
	for border in context.borders:
		if border.size() > 1: draw_polyline(border,Color("9b9a76"),42,true)
	for mesh in decorative_meshes: draw_mesh(mesh,null,Transform2D.IDENTITY,Color("c7c297"))
	if flag_mesh != null:
		draw_mesh(flag_mesh,flag_texture)
	else:
		draw_mesh(land_mesh,null,Transform2D.IDENTITY,TERRAIN_COLOR)
	if not waves.is_empty(): draw_multiline(waves,Color("83a9a4"),1.3,true)
	if not relief.is_empty(): draw_multiline(relief,Color(0.42,0.34,0.20,0.24),1.25,true)
	for coast in context.coasts:
		if coast.size() > 1: draw_polyline(coast,Color("e6d5ac"),4,true)
	draw_polyline(border_contour,Color("343f37"),5,true)
	draw_polyline(border_contour,Color("c1a76e"),1.2,true)
	for item in context.lands:
		if item.show_label and map.land_bounds.grow(1000).has_point(item.label) and not Geometry2D.is_point_in_polygon(item.label,outline):
			draw_string(ConquestTheme.get_font(),item.label,item.name.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,220,19,Color("e0e7c8"))

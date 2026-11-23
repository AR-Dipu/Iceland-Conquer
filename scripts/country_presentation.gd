class_name CountryPresentation
extends Resource
## Immutable, presentation-only geography; never used for movement/ownership.
static var source: Dictionary = {}
static var cache: Dictionary = {}
var lands: Array[Dictionary] = []
var coasts: Array[PackedVector2Array] = []
var borders: Array[PackedVector2Array] = []
static func for_country(country: CountryMap) -> CountryPresentation:
	var key := country.country_id+":"+str(hash([country.outline,country.presentation_origin,country.presentation_scale]))
	if cache.has(key): return cache[key]
	if cache.size() >= 4: cache.erase(cache.keys()[0])
	var result := CountryPresentation.new()
	result.setup(country)
	cache[key] = result
	return result
func setup(country: CountryMap) -> void:
	if source.is_empty(): source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/country-context.json"))
	var entry: Dictionary = source.get("countries",{}).get(country.country_id,{})
	var label_ids: Dictionary = {}
	for item in entry.get("lands",[]):
		var polygon := _polygon(item.ring,country)
		var indices := Geometry2D.triangulate_polygon(polygon)
		if indices.is_empty(): continue
		var label := (Vector2(item.label[0],item.label[1])-country.presentation_origin)*country.presentation_scale
		lands.append({"polygon":polygon,"mesh":_mesh(polygon,indices),"name":str(item.name),"label":label,"show_label":not label_ids.has(item.id)})
		label_ids[item.id] = true
	for ring in entry.get("coast",[]): coasts.append(_polygon(ring,country))
	for ring in entry.get("borders",[]): borders.append(_polygon(ring,country))
func _polygon(points: Array,country: CountryMap) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for p in points: polygon.append((Vector2(p[0],p[1])-country.presentation_origin)*country.presentation_scale)
	return polygon
static func _mesh(polygon: PackedVector2Array,indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = polygon
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

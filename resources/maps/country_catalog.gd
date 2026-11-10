class_name CountryCatalog
extends RefCounted

var maps: Array[CountryMap] = []
var world: Array = []

func _init() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/countries.json"))
	world = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/world.json"))
	for entry in entries:
		var map := CountryMap.new()
		map.country_id = entry.id
		map.display_name = entry.name
		map.outline = polygon(entry.outline)
		for ring in entry.decorative_islands:
			map.decorative_islands.append(polygon(ring))
		map.build()
		assert(map.valid(), "Invalid bundled country map: " + map.country_id)
		maps.append(map)

static func polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(Vector2(p[0], p[1]))
	return result

func find(country_id: String) -> CountryMap:
	for map in maps:
		if map.country_id == country_id:
			return map
	return null

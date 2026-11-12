class_name CampaignProgress
extends RefCounted
var path: String = "user://campaign.cfg"
var player_name: String = "Captain"
var starting: String = ""
var conquered: Array[String] = []
var previous_names: Array[String] = []

func open(wallet: PracticeWallet) -> void:
	var file := ConfigFile.new()
	if file.load(path) == OK:
		player_name = str(file.get_value("profile", "name", "Captain"))
		starting = str(file.get_value("campaign", "starting", ""))
		for id in file.get_value("campaign", "conquered", []): conquered.append(str(id))
	for key in wallet.data.get("claims", {}):
		if str(key).begins_with("country:"):
			var id: String = str(key).trim_prefix("country:")
			if not conquered.has(id): conquered.append(id)

func save() -> bool:
	var file := ConfigFile.new()
	file.set_value("profile", "name", player_name)
	file.set_value("campaign", "starting", starting)
	file.set_value("campaign", "conquered", conquered)
	if file.save(path + ".tmp") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func set_name(value: String) -> bool:
	value = value.strip_edges().replace("\n", " ").replace("\r", " ").left(16)
	if value.is_empty(): return false
	var old := player_name
	player_name = value
	if save(): return true
	player_name = old
	return false

func can_attack(id: String, catalog: CountryCatalog) -> bool:
	if catalog.find(id) == null or conquered.has(id): return false
	if conquered.is_empty(): return starting.is_empty() or starting == id
	for owned in conquered:
		var country := catalog.find(owned)
		if country != null and country.neighbors.has(id): return true
	return false

func begin(id: String) -> bool:
	if not starting.is_empty(): return true
	starting = id
	if save(): return true
	starting = ""
	return false

func conquer(id: String) -> bool:
	if conquered.has(id): return true
	conquered.append(id)
	if save(): return true
	conquered.erase(id)
	return false

func round_names(count: int) -> Array[String]:
	var pool: Array[String] = ["Mango", "Coral", "Coco", "Sunny", "Kiki", "Pebble", "Finn", "Tiki", "Luna", "Reef", "Mochi", "Pip", "Nori", "Breeze", "Nova", "Rio", "Ziggy", "Sandy", "Milo", "Pearl", "Echo", "Kiwi", "Skipper", "Bubbles"]
	pool.shuffle()
	var result: Array[String] = [player_name]
	for name in pool:
		if name.to_lower() == player_name.to_lower() or previous_names.has(name): continue
		result.append(name)
		if result.size() == count: break
	previous_names = result.slice(1)
	return result

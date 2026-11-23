extends RefCounted

const CATALOG := {
	"cat": ["Crowned Cat", 0, "Balanced movement", "Standard revival shield", 1.0, 1.0, 0.0],
	"hare": ["Swift Hare", 150, "+15% acceleration", "−5% top speed", 0.95, 1.15, 0.0],
	"otter": ["River Otter", 225, "+8% top speed", "−15% acceleration", 1.08, 0.85, 0.0],
	"turtle": ["Atlas Turtle", 300, "+1 second revival shield", "−8% top speed", 0.92, 1.0, 1.0],
}
var wallet: PracticeWallet
var path: String
var equipped := "cat"

func open(existing_wallet: PracticeWallet, equipment_path: String) -> void:
	wallet = existing_wallet
	path = equipment_path
	equipped = "cat"
	var saved := FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""
	if owns(saved): equipped = saved

func owns(id: String) -> bool:
	return CATALOG.has(id) and (id == "cat" or wallet.claimed("character:" + id))

func buy(id: String) -> bool:
	if not CATALOG.has(id): return false
	if owns(id): return true
	return wallet.transact("character:" + id, -int(CATALOG[id][1]))

func equip(id: String) -> bool:
	if not owns(id): return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(id)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK: return false
	equipped = id
	return true

static func artwork(id: String) -> Texture2D:
	match id:
		"hare": return preload("res://assets/characters/hare.svg")
		"otter": return preload("res://assets/characters/otter.svg")
		"turtle": return preload("res://assets/characters/turtle.svg")
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/characters/cats.png")
	texture.region = Rect2(0, 0, texture.atlas.get_width() / 4.0, texture.atlas.get_height() / 2.0)
	return texture

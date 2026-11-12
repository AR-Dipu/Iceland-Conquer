extends RefCounted
class_name PracticeWallet
signal changed(balance: int)
var settings := EconomyConfig.new()
var path: String = "user://practice_wallet.json"
var data: Dictionary = {}
var healthy: bool = false
var balance: int:
	get: return int(data.get("balance", 0))

func open(save_path: String = "user://practice_wallet.json") -> bool:
	path = save_path
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
			var parsed: Variant = parser.data
			if _valid(parsed):
				if candidate != path and DirAccess.copy_absolute(candidate,path) != OK: return false
				data = parsed
				healthy = true
				return true
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		return false
	data = {"version": 1, "balance": settings.starting_coins, "claims": {}}
	healthy = _save(data)
	return healthy

func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or not value.get("claims") is Dictionary: return false
	var amount: Variant = value.get("balance")
	if not (amount is float or amount is int): return false
	if not is_finite(float(amount)) or amount < 0 or amount > 1000000000 or amount != floor(amount): return false
	for key in value.claims:
		var delta: Variant = value.claims[key]
		if not key is String or not (delta is float or delta is int): return false
		if not is_finite(float(delta)) or absf(float(delta)) > 1000000000 or delta != floor(delta): return false
	return true

func _save(next: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(next))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, path + ".bak") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func transact(id: String, amount: int) -> bool:
	if not healthy or id.is_empty(): return false
	if data.claims.has(id): return int(data.claims[id]) == amount
	if amount < -1000000000 or amount > 1000000000 or balance + amount < 0 or balance + amount > 1000000000: return false
	var next: Dictionary = data.duplicate(true)
	next.balance = balance + amount
	next.claims[id] = amount
	if not _save(next): return false
	data = next
	changed.emit(balance)
	return true

func claimed(id: String) -> bool:
	return data.get("claims", {}).has(id)

func daily_login() -> bool:
	var day: int = int(Time.get_unix_time_from_system() / 86400)
	var highest: int = -1
	for key in data.get("claims", {}):
		if str(key).begins_with("daily:"):
			highest = maxi(highest, int(str(key).trim_prefix("daily:")))
	if highest < 0:
		return transact("daily:" + str(day), 0)
	if day <= highest: return false
	return transact("daily:" + str(day), settings.daily_coins)

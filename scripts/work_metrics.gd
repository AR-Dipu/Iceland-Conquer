class_name WorkMetrics
extends RefCounted
## Opt-in internal CPU measurements; disabled in ordinary play.
static var enabled: bool = false
static var samples: Dictionary = {}
static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0
static func finish(label: String, began: int) -> void:
	if not enabled: return
	if not samples.has(label): samples[label] = []
	if samples[label].size() < 12000: samples[label].append(Time.get_ticks_usec()-began)
static func report() -> Dictionary:
	var result: Dictionary = {}
	for label in samples:
		var values: Array = samples[label].duplicate()
		values.sort()
		if not values.is_empty(): result[label] = {"count":values.size(),"median_us":values[values.size()/2],"p95_us":values[mini(values.size()-1,int(values.size()*0.95))],"worst_us":values[-1]}
	return result

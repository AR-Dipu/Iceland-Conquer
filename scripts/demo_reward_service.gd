class_name DemoRewardService
extends Node
signal completed(token: int)
signal progress(remaining: float)
var token: int = 0
var remaining: float = 0
var active: bool = false
var foreground: bool = true
func begin() -> int:
	token += 1
	remaining = 3.0
	active = true
	return token
func cancel() -> void:
	active = false
	token += 1
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		foreground = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		foreground = true
func _process(delta: float) -> void:
	if not active or not foreground:
		return
	remaining = maxf(0, remaining - minf(delta, 0.1))
	progress.emit(remaining)
	if remaining <= 0:
		active = false
		completed.emit(token)

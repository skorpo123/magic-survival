@tool

extends Node2D

class_name BurstParticleGroup2D

@export var repeat = true
@export var free_when_finished = true
@export var autostart = true

var lifetime = 0
var finished = true
var _group_timer: SceneTreeTimer = null

func _ready():
	child_entered_tree.connect(_on_child_entered_tree)
	for child in get_children():
		child.tree_exited.connect(_on_child_exited_tree)
		if child is BurstParticles2D:
			child.finished_burst.connect(_on_child_finished)
		update_children()
	if autostart or Engine.is_editor_hint():
		burst()

func _on_child_entered_tree(child: Node):
	if !child.tree_exited.is_connected(_on_child_exited_tree):
		child.tree_exited.connect(_on_child_exited_tree)
	if child is BurstParticles2D:
		if !child.finished_burst.is_connected(_on_child_finished):
			child.finished_burst.connect(_on_child_finished)
		if autostart or Engine.is_editor_hint():
			burst()

func update_children():
	lifetime = 0
	for child in get_children():
		if child is BurstParticles2D:
			if child.lifetime > lifetime:
				lifetime = child.lifetime
			child.repeat = repeat
			child.free_when_finished = free_when_finished
			child.autostart = autostart

func burst():
	finished = false
	update_children()
	for child in get_children():
		if child is BurstParticles2D and child.is_inside_tree():
			child.burst()
	if is_inside_tree():
		if _group_timer and is_instance_valid(_group_timer):
			if _group_timer.timeout.is_connected(_finish):
				_group_timer.timeout.disconnect(_finish)
		_group_timer = get_tree().create_timer(lifetime, false)
		_group_timer.timeout.connect(_finish)

func _on_child_exited_tree():
	pass

func _on_child_finished():
	for child in get_children():
		if child is BurstParticles2D:
			if !child.finished:
				return
	_finish()

func _finish():
	if finished:
		return
	finished = true
	if (repeat or Engine.is_editor_hint()):
		burst()
	elif free_when_finished:
		queue_free()

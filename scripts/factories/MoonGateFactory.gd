extends RefCounted
class_name MoonGateFactory


static func add_moon_gate_trigger(parent: Node3D, on_body_entered: Callable) -> void:
	var area := Area3D.new()
	area.name = "MoonGateTrigger"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = true
	area.position = Vector3(0.0, 3.0, 0.0)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 5.0, 2.2)
	shape_node.shape = shape
	area.add_child(shape_node)
	parent.add_child(area)
	# Activation is driven by Main's MoonGateTrigger proximity polling, not this
	# Area3D signal (the poll reads this node's position — keep the Area3D).

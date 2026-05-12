extends RefCounted
class_name CollisionFactory


static func add_box(parent: Node3D, local_position: Vector3, size: Vector3) -> StaticBody3D:
	var body := _base_body("BoxCollisionBody", local_position)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


static func add_cylinder(parent: Node3D, local_position: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := _base_body("CylinderCollisionBody", local_position)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	body.add_child(shape)
	parent.add_child(body)
	return body


static func add_sphere(parent: Node3D, local_position: Vector3, radius: float) -> StaticBody3D:
	var body := _base_body("SphereCollisionBody", local_position)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	body.add_child(shape)
	parent.add_child(body)
	return body


static func _base_body(node_name: String, local_position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = local_position
	return body

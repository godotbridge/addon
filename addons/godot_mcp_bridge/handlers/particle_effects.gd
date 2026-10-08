## Handlers for the particle_effects tool category. add_particles/set_particle_*
## target GPUParticles2D/3D — Godot 4's default particle system.
class_name GodotMCPParticleEffectsHandlers
extends RefCounted

const NodeResolver = preload("res://addons/godot_mcp_bridge/utils/node_resolver.gd")

## A small starting set of ready-made ParticleProcessMaterial configs, not an
## exhaustive VFX library — add more entries as real usage calls for them.
const PRESETS := ["sparks", "smoke", "fire"]


static func register(dispatch: Dictionary) -> void:
	dispatch["add_particles"] = add_particles
	dispatch["add_particle_collision"] = add_particle_collision
	dispatch["set_particle_process"] = set_particle_process
	dispatch["set_particle_color_ramp"] = set_particle_color_ramp
	dispatch["get_particle_info"] = get_particle_info
	dispatch["add_gpu_particles_preset"] = add_gpu_particles_preset


static func _create(params: Dictionary, ei: EditorInterface, node_type: String) -> Variant:
	var parent := NodeResolver.resolve(params, ei, "parent_path")
	if parent is Dictionary:
		return parent
	var root: Node = ei.get_edited_scene_root()
	return NodeResolver.add_child_node(parent, root, node_type, params.get("node_name", ""))


static func _describe(ei: EditorInterface, node: Node) -> Dictionary:
	var root: Node = ei.get_edited_scene_root()
	return {"node_path": NodeResolver.relative_path(root, node), "type": node.get_class()}


static func _get_or_create_material(node: Node) -> ParticleProcessMaterial:
	if node.process_material is ParticleProcessMaterial:
		return node.process_material
	var material := ParticleProcessMaterial.new()
	node.process_material = material
	return material


static func add_particles(params: Dictionary, ei: EditorInterface) -> Variant:
	var dimension: String = params.get("dimension", "2d")
	var node_type := "GPUParticles3D" if dimension == "3d" else "GPUParticles2D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node

	node.amount = int(params.get("amount", 8))
	node.process_material = ParticleProcessMaterial.new()
	if params.has("lifetime"):
		node.lifetime = float(params["lifetime"])
	if params.has("emitting"):
		node.emitting = bool(params["emitting"])
	return _describe(ei, node)


## 3D-only: Godot's 2D particle collision is configured on the process
## material's collision bitmask against regular physics bodies, not a
## dedicated node type the way 3D has GPUParticlesCollisionBox3D/Sphere3D/etc.
static func add_particle_collision(params: Dictionary, ei: EditorInterface) -> Variant:
	var shape: String = params.get("shape", "sphere")
	var node_type := "GPUParticlesCollisionBox3D" if shape == "box" else "GPUParticlesCollisionSphere3D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node
	if params.has("radius") and node is GPUParticlesCollisionSphere3D:
		node.radius = float(params["radius"])
	return _describe(ei, node)


static func set_particle_process(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("process_material" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no process_material property" % node.get_class()}

	var material := _get_or_create_material(node)
	var properties: Dictionary = params.get("properties", {})
	for property in properties.keys():
		var value: Variant = properties[property]
		if typeof(value) == TYPE_DICTIONARY and value.has("x"):
			if value.has("z"):
				material.set(property, Vector3(value.get("x", 0.0), value.get("y", 0.0), value.get("z", 0.0)))
			else:
				material.set(property, Vector2(value.get("x", 0.0), value.get("y", 0.0)))
		else:
			material.set(property, value)
	return {"node_path": params.get("node_path", ""), "properties": properties.keys()}


static func set_particle_color_ramp(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not ("process_material" in node):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s has no process_material property" % node.get_class()}

	var colors: Array = params.get("colors", [])
	if colors.is_empty():
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "colors is required and must be non-empty"}

	var gradient := Gradient.new()
	var gcolors := PackedColorArray()
	for c in colors:
		gcolors.append(Color(c.get("r", 1.0), c.get("g", 1.0), c.get("b", 1.0), c.get("a", 1.0)))
	gradient.colors = gcolors
	if params.has("offsets"):
		var offsets := PackedFloat32Array()
		for o in params["offsets"]:
			offsets.append(float(o))
		gradient.offsets = offsets

	var texture := GradientTexture1D.new()
	texture.gradient = gradient

	var material := _get_or_create_material(node)
	material.color_ramp = texture
	return {"node_path": params.get("node_path", ""), "color_count": colors.size()}


static func get_particle_info(params: Dictionary, ei: EditorInterface) -> Variant:
	var node := NodeResolver.resolve(params, ei)
	if node is Dictionary:
		return node
	if not (node is GPUParticles2D or node is GPUParticles3D):
		return {"__error_code__": "INVALID_PARAMS", "__error_message__": "%s is not a GPUParticles2D/3D" % node.get_class()}

	return {
		"type": node.get_class(),
		"amount": node.amount,
		"emitting": node.emitting,
		"lifetime": node.lifetime,
		"one_shot": node.one_shot,
		"has_process_material": node.process_material != null,
	}


static func add_gpu_particles_preset(params: Dictionary, ei: EditorInterface) -> Variant:
	var preset: String = params.get("preset", "")
	if not PRESETS.has(preset):
		return {
			"__error_code__": "INVALID_PARAMS",
			"__error_message__": "Unknown preset '%s'. Available: %s" % [preset, ", ".join(PRESETS)],
		}

	var dimension: String = params.get("dimension", "2d")
	var node_type := "GPUParticles3D" if dimension == "3d" else "GPUParticles2D"
	var node := _create(params, ei, node_type)
	if node is Dictionary:
		return node

	var material := ParticleProcessMaterial.new()
	match preset:
		"sparks":
			node.amount = 32
			node.lifetime = 0.6
			material.initial_velocity_min = 80.0
			material.initial_velocity_max = 160.0
			material.spread = 180.0
			material.gravity = Vector3(0, 200, 0)
			material.scale_min = 0.5
			material.scale_max = 1.0
		"smoke":
			node.amount = 16
			node.lifetime = 2.0
			material.initial_velocity_min = 10.0
			material.initial_velocity_max = 20.0
			material.spread = 20.0
			material.gravity = Vector3(0, -20, 0)
			material.scale_min = 1.0
			material.scale_max = 2.5
		"fire":
			node.amount = 24
			node.lifetime = 0.8
			material.initial_velocity_min = 30.0
			material.initial_velocity_max = 50.0
			material.spread = 15.0
			material.gravity = Vector3(0, -60, 0)
			material.scale_min = 0.4
			material.scale_max = 1.2

	node.process_material = material
	return {"node_path": NodeResolver.relative_path(ei.get_edited_scene_root(), node), "type": node_type, "preset": preset}

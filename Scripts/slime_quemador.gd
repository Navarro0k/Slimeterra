class_name SlimeQuemador
extends RefCounted
## Poder del slime de fuego: quema los tiles "rompible_por_fuego" que toca.

var _slime: RigidBody2D
## Forma y consulta reutilizadas: quemar corre en cada paso de física.
var _forma: CircleShape2D
var _consulta: PhysicsShapeQueryParameters2D


func _init(slime: RigidBody2D, mascara_colision: int) -> void:
	_slime = slime
	_forma = CircleShape2D.new()
	_consulta = PhysicsShapeQueryParameters2D.new()
	_consulta.shape = _forma
	_consulta.collision_mask = mascara_colision
	_consulta.collide_with_bodies = true
	_consulta.collide_with_areas = false
	var excluidos: Array[RID] = [_slime.get_rid()]
	_consulta.exclude = excluidos


## Quema lo que toca el slime ahora y lo que tocará en este paso de física.
func quemar(posicion: Vector2, v_motor: Vector2, delta: float, radio: float) -> void:
	_quemar_en(posicion, radio)
	_quemar_en(posicion + v_motor * delta, radio)


func _quemar_en(centro: Vector2, radio: float) -> void:
	_forma.radius = radio
	_consulta.transform = Transform2D(0.0, centro)
	for choque in _slime.get_world_2d().direct_space_state.intersect_shape(_consulta, 8):
		var capa = choque["collider"]
		if capa is TileMapLayer:
			_quemar_celdas(capa, centro, radio)


func _quemar_celdas(capa: TileMapLayer, centro: Vector2, radio: float) -> void:
	var mitad := Vector2(capa.tile_set.tile_size) * 0.5
	var local := capa.to_local(centro)
	var celda_min := capa.local_to_map(local - Vector2(radio, radio))
	var celda_max := capa.local_to_map(local + Vector2(radio, radio))
	for x in range(celda_min.x, celda_max.x + 1):
		for y in range(celda_min.y, celda_max.y + 1):
			var celda := Vector2i(x, y)
			var datos := capa.get_cell_tile_data(celda)
			if datos == null:
				continue
			var es_rompible: bool = datos.get_custom_data("rompible_por_fuego")
			if not es_rompible:
				continue
			var d := (local - capa.map_to_local(celda)).abs() - mitad
			var fuera := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()
			if fuera <= radio:
				capa.erase_cell(celda)
				_efecto_quemar(capa, celda)


func _efecto_quemar(capa: TileMapLayer, celda: Vector2i) -> void:
	var arbol := _slime.get_tree()
	_particulas_fuego(arbol, capa.to_global(capa.map_to_local(celda)))
	SlimeSonidos.quemar(arbol)


func _particulas_fuego(arbol: SceneTree, centro_global: Vector2) -> void:
	var escena := arbol.current_scene
	if escena == null:
		return
	var particulas := CPUParticles2D.new()
	particulas.global_position = centro_global
	particulas.emitting = true
	particulas.one_shot = true
	particulas.explosiveness = 0.9
	particulas.amount = 12
	particulas.lifetime = 0.5
	particulas.local_coords = false
	particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particulas.emission_sphere_radius = 4.0
	particulas.direction = Vector2(0, -1)
	particulas.spread = 180.0
	particulas.gravity = Vector2(0, -40)
	particulas.initial_velocity_min = 10.0
	particulas.initial_velocity_max = 30.0
	particulas.scale_amount_min = 0.5
	particulas.scale_amount_max = 1.5
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 1.0])
	degradado.colors = PackedColorArray([Color(1.0, 0.6, 0.2, 1.0), Color(1.0, 0.2, 0.0, 0.0)])
	particulas.color_ramp = degradado
	escena.add_child(particulas)
	arbol.create_timer(1.0).timeout.connect(particulas.queue_free)

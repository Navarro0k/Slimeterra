class_name SlimeVisual
extends RefCounted
## Efectos visuales del slime: estela de vuelo, brillo y burbujas de tensión en la resortera.
## No decide nada del juego: slime.gd le avisa qué está pasando
## (actualizar_rastro, actualizar_pulso, set_tension).

var _rastro: CPUParticles2D
var _brillo: Sprite2D
var _burbujas: CPUParticles2D
var _tension: float = 0.0


func _init(slime: Node2D, sprite: Sprite2D, rastro: CPUParticles2D, color: Color, burbujas_cantidad: int, radio: float) -> void:
	_rastro = rastro
	_configurar_rastro(color)
	_brillo = _crear_brillo(slime, sprite)
	_burbujas = _crear_burbujas(slime, color, burbujas_cantidad, radio)


# ---------------------------------------------------------------------------
# API para slime.gd
# ---------------------------------------------------------------------------

## La estela solo se emite mientras el slime se mueve.
func actualizar_rastro(velocidad: Vector2) -> void:
	_rastro.emitting = velocidad.length() > 5.0


## Pulso del brillo: más intenso y rápido a más tensión.
func actualizar_pulso() -> void:
	if _tension > 0.0 and _brillo != null and _brillo.visible:
		var pulso := 0.65 + 0.25 * sin(Time.get_ticks_msec() * 0.001 * lerpf(8.0, 18.0, _tension))
		_brillo.modulate.a = _tension * pulso


## t: 0..1 (potencia acumulada). Solo controla el brillo y las burbujas;
## el sprite NO se deforma ni rota.
func set_tension(t: float, direccion_tiron: Vector2 = Vector2.ZERO) -> void:
	if _brillo == null or _burbujas == null:
		return
	t = clampf(t, 0.0, 1.0)
	if t <= 0.01 or direccion_tiron == Vector2.ZERO:
		_tension = 0.0
		_brillo.visible = false
		_burbujas.emitting = false
		return

	_tension = t
	_brillo.visible = true
	_burbujas.emitting = t > 0.08
	_burbujas.speed_scale = lerpf(0.7, 2.2, t)  # más potencia = más burbujas por segundo
	_burbujas.scale_amount_max = lerpf(1.5, 3.0, t)


# ---------------------------------------------------------------------------
# Construcción de los efectos
# ---------------------------------------------------------------------------

func _configurar_rastro(color: Color) -> void:
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 1.0])
	degradado.colors = PackedColorArray([Color(color, 0.9), Color(color, 0.0)])
	_rastro.color_ramp = degradado
	_rastro.local_coords = false  # Las particulas se quedan en el mundo (estela), no siguen al slime.
	_rastro.amount = 12
	_rastro.lifetime = 0.6
	_rastro.scale_amount_min = 0.6
	_rastro.scale_amount_max = 1.0
	_rastro.initial_velocity_min = 0.0
	_rastro.initial_velocity_max = 0.0
	_rastro.gravity = Vector2(0, 20)  # Ligera caida para que la estela se disperse.
	_rastro.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	_rastro.spread = 15.0
	_rastro.show_behind_parent = false
	_rastro.z_index = 5  # Visible por encima de tiles y resortera.


func _crear_brillo(slime: Node2D, sprite: Sprite2D) -> Sprite2D:
	var brillo := Sprite2D.new()
	brillo.texture = sprite.texture
	brillo.scale = sprite.scale * 1.08
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	brillo.material = mat
	brillo.modulate = Color(1, 1, 1, 0)
	brillo.visible = false
	slime.add_child(brillo)
	return brillo


func _crear_burbujas(slime: Node2D, color: Color, cantidad: int, radio: float) -> CPUParticles2D:
	var burbujas := CPUParticles2D.new()
	burbujas.emitting = false
	burbujas.amount = cantidad
	burbujas.lifetime = 0.7
	burbujas.local_coords = false  # las burbujas se quedan flotando donde nacen
	burbujas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burbujas.emission_sphere_radius = radio + 2.0
	burbujas.direction = Vector2.UP
	burbujas.spread = 60.0
	burbujas.gravity = Vector2(0, -14)  # suben
	burbujas.initial_velocity_min = 2.0
	burbujas.initial_velocity_max = 8.0
	burbujas.scale_amount_min = 1.0
	burbujas.scale_amount_max = 1.5
	var degradado := Gradient.new()
	degradado.offsets = PackedFloat32Array([0.0, 1.0])
	degradado.colors = PackedColorArray([Color(color, 0.95), Color(color, 0.0)])
	burbujas.color_ramp = degradado
	burbujas.z_index = 1
	slime.add_child(burbujas)
	return burbujas

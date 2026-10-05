extends Node2D

@export var slime_scene: PackedScene 
@export var multiplicador_fuerza: float = 15.0 
@export var max_stretch: float = 30.0
@export var grosor_reposo: float = 2.0 
@export var grosor_estirado: float = 1.0 
@export var caida_reposo: float = 5.0 
@export var puntos_trayectoria: int = 15
@export var paso_tiempo: float = 0.08

var is_dragging: bool = false
var current_drag_position: Vector2
var slime_actual: RigidBody2D 

@onready var anchor_left = $AnchorLeft
@onready var anchor_right = $AnchorRight
@onready var center_marker = $CenterMarker
@onready var band_left = $BandLeft
@onready var band_right = $BandRight
@onready var holder = $Holder

func _ready():
	current_drag_position = center_marker.position
	actualizar_cuerdas(current_drag_position)
	cargar_nuevo_slime()

func _input(event):
	if not is_dragging:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		soltar_resortera()
		return
	
	if event is InputEventMouseMotion:
		var mouse_pos = get_local_mouse_position()
		var drag_vector = mouse_pos - center_marker.position
		current_drag_position = center_marker.position + drag_vector.limit_length(max_stretch)
		
		actualizar_cuerdas(current_drag_position)
		queue_redraw()

func _draw():
	if is_dragging and slime_actual != null:
		var vector_disparo = center_marker.position - current_drag_position
		
		if vector_disparo.length() > 5.0:
			var velocidad_inicial = vector_disparo * multiplicador_fuerza
			var gravedad = ProjectSettings.get_setting("physics/2d/default_gravity")
			
			for i in range(1, puntos_trayectoria + 1):
				var t = i * paso_tiempo
				var desp_x = velocidad_inicial.x * t
				var desp_y = (velocidad_inicial.y * t) + (0.5 * gravedad * t * t)
				var pos_punto = holder.position + Vector2(desp_x, desp_y)
				
				draw_rect(Rect2(pos_punto - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 1.0, 1.0, 0.6))

func _on_holder_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if slime_actual != null:
			is_dragging = true

func cargar_nuevo_slime():
	if slime_scene != null:
		slime_actual = slime_scene.instantiate()
		holder.add_child(slime_actual)
		slime_actual.position = Vector2.ZERO
		slime_actual.freeze = true

func actualizar_cuerdas(pos: Vector2):
	holder.position = pos
	
	var distancia = center_marker.position.distance_to(pos)
	var tension_ratio = clamp(distancia / max_stretch, 0.0, 1.0)
	var grosor_actual = lerp(grosor_reposo, grosor_estirado, tension_ratio)
	
	band_left.width = grosor_actual
	band_right.width = grosor_actual
	
	dibujar_banda_curva(band_left, anchor_left.position, pos, tension_ratio)
	dibujar_banda_curva(band_right, anchor_right.position, pos, tension_ratio)

func dibujar_banda_curva(linea: Line2D, p_inicio: Vector2, p_fin: Vector2, tension: float):
	var puntos = PackedVector2Array()
	
	if tension > 0.05:
		puntos.append(p_inicio)
		puntos.append(p_fin)
	else:
		var hundimiento = lerp(caida_reposo, 0.0, tension)
		var medio = p_inicio.lerp(p_fin, 0.5)
		medio.y += hundimiento
		
		puntos.append(p_inicio)
		puntos.append(medio)
		puntos.append(p_fin)
		
	linea.points = puntos

func soltar_resortera():
	is_dragging = false
	var vector_disparo = center_marker.position - current_drag_position
	
	queue_redraw()
	
	var tween = create_tween()
	tween.tween_method(actualizar_cuerdas, current_drag_position, center_marker.position, 0.3)\
		 .set_trans(Tween.TRANS_SPRING)\
		 .set_ease(Tween.EASE_OUT)
	
	if vector_disparo.length() > 5.0 and slime_actual != null:
		slime_actual.reparent(get_tree().current_scene)
		slime_actual.freeze = false
		
		if slime_actual.has_method("lanzar"):
			slime_actual.lanzar(vector_disparo * multiplicador_fuerza)
			
		slime_actual = null
		get_tree().create_timer(1.5).timeout.connect(cargar_nuevo_slime)

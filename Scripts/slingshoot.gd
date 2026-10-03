extends Node2D

@export var max_stretch: float = 150.0
@export var grosor_reposo: float = 8.0 # Grosor cuando la liga está suelta
@export var grosor_estirado: float = 3.0 # Grosor cuando está a máxima tensión

@onready var anchor_left = $AnchorLeft
@onready var anchor_right = $AnchorRight
@onready var center_marker = $CenterMarker
@onready var band_left = $BandLeft
@onready var band_right = $BandRight
@onready var holder = $Holder

var is_dragging: bool = false
var current_drag_position: Vector2

func _ready():
	current_drag_position = center_marker.position
	actualizar_cuerdas(current_drag_position)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if is_dragging:
				soltar_resortera()
	
	if event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_local_mouse_position()
		var drag_vector = mouse_pos - center_marker.position
		current_drag_position = center_marker.position + drag_vector.limit_length(max_stretch)
		
		actualizar_cuerdas(current_drag_position)

func _on_holder_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true

func actualizar_cuerdas(pos: Vector2):
	holder.position = pos
	
	# Calculamos qué tan tensa está la cuerda (0.0 = reposo, 1.0 = estirada al límite)
	var distancia = center_marker.position.distance_to(pos)
	var tension_ratio = clamp(distancia / max_stretch, 0.0, 1.0)
	
	# 1. Efecto de adelgazamiento: La cuerda se hace más fina al estirarse
	var grosor_actual = lerp(grosor_reposo, grosor_estirado, tension_ratio)
	band_left.width = grosor_actual
	band_right.width = grosor_actual
	
	# 2. Efecto de gravedad y curva
	dibujar_banda_curva(band_left, anchor_left.position, pos, tension_ratio)
	dibujar_banda_curva(band_right, anchor_right.position, pos, tension_ratio)

func dibujar_banda_curva(linea: Line2D, p_inicio: Vector2, p_fin: Vector2, tension: float):
	var puntos = []
	var segmentos = 10 # Cantidad de puntos que componen la curva
	
	# El hundimiento es de 20 píxeles en reposo, y se vuelve 0 al estirar al 100%
	var hundimiento_maximo = lerp(20.0, 0.0, tension)
	
	for i in range(segmentos + 1):
		var t = i / float(segmentos)
		var x = lerp(p_inicio.x, p_fin.x, t)
		var y_base = lerp(p_inicio.y, p_fin.y, t)
		
		# Fórmula parabólica para hacer que caiga en el centro (t=0.5)
		var curva = 4.0 * t * (1.0 - t) 
		var y = y_base + (curva * hundimiento_maximo)
		
		puntos.append(Vector2(x, y))
		
	linea.points = puntos

func soltar_resortera():
	is_dragging = false
	var vector_disparo = center_marker.position - current_drag_position
	
	# Aumentamos el tiempo del Tween a 0.3s y le damos EASE_OUT para un "temblor" más notorio
	var tween = create_tween()
	tween.tween_method(actualizar_cuerdas, current_drag_position, center_marker.position, 0.3)\
		 .set_trans(Tween.TRANS_SPRING)\
		 .set_ease(Tween.EASE_OUT)
	
	if vector_disparo.length() > 10.0:
		print("¡Disparo! Vector inicial: ", vector_disparo)

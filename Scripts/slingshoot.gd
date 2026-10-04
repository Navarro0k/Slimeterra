extends Node2D

@export var slime_scene: PackedScene 
@export var multiplicador_fuerza: float = 15.0 
@export var max_stretch: float = 30.0
@export var grosor_reposo: float = 2.0 
@export var grosor_estirado: float = 1.0 
@export var caida_reposo: float = 5.0 

@onready var anchor_left = $AnchorLeft
@onready var anchor_right = $AnchorRight
@onready var center_marker = $CenterMarker
@onready var band_left = $BandLeft
@onready var band_right = $BandRight
@onready var holder = $Holder

var is_dragging: bool = false
var current_drag_position: Vector2
var slime_actual: RigidBody2D # Variable para guardar el slime que está montado

func _ready():
	current_drag_position = center_marker.position
	actualizar_cuerdas(current_drag_position)
	cargar_nuevo_slime() # Cargamos el primer slime en el parche (Holder)

func cargar_nuevo_slime():
	if slime_scene != null:
		slime_actual = slime_scene.instantiate()
		holder.add_child(slime_actual) # Ahora el slime viaja con el parche de cuero
		slime_actual.position = Vector2.ZERO # Lo centramos visualmente en el holder
		
		# IMPORTANTE: Congelamos su física. Así no se ve afectado por la gravedad mientras apuntas
		slime_actual.freeze = true 
	else:
		print("Error: No has asignado la escena del Slime en el Inspector de la resortera.")

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

func _on_holder_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Solo permitimos que el jugador arrastre si hay un slime listo
		if slime_actual != null:
			is_dragging = true

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
	
	var tween = create_tween()
	tween.tween_method(actualizar_cuerdas, current_drag_position, center_marker.position, 0.3)\
		 .set_trans(Tween.TRANS_SPRING)\
		 .set_ease(Tween.EASE_OUT)
	
	if vector_disparo.length() > 5.0 and slime_actual != null:
		print("¡Disparo! Vector inicial: ", vector_disparo)
		
		# 1. Separación: Reparent pasará el slime al Mundo manteniendo la posición que tiene al estirarse
		slime_actual.reparent(get_tree().current_scene)
		
		# 2. Despertar: Descongelamos el slime para que la gravedad actúe
		slime_actual.freeze = false
		
		# 3. Disparo: Le pasamos el vector (dirección y fuerza)
		if slime_actual.has_method("lanzar"):
			slime_actual.lanzar(vector_disparo * multiplicador_fuerza)
			
		# 4. Vaciamos la honda para bloquear el input temporalmente
		slime_actual = null
		
		# 5. RECARGA: Esperamos 1.5 segundos y llamamos a la función de cargar un nuevo slime
		get_tree().create_timer(1.5).timeout.connect(cargar_nuevo_slime)

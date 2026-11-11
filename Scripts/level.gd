class_name NivelSlimes
extends Node2D
## Script del nivel: conecta resortera, UI, cámara y pantalla de fin.

## Orden de los niveles. El último cierra el juego.
const ORDEN_NIVELES: Array[String] = [
	"res://Scenes/Levels/jungleLevel.tscn",
	"res://Scenes/Levels/Level_Ice.tscn",
]

## Si es false, la explicación nunca se abre sola (solo con el botón ?).
const AUTOABRIR_PRIMERA_VEZ: bool = true

@export_group("Límites del nivel")
@export var mostrar_limites: bool = false

@export_group("Estrellas")
## Tiempo (s) máximo para 3 estrellas.
@export var tiempo_3_estrellas: float = 45.0
## Tiempo (s) máximo para 2 estrellas.
@export var tiempo_2_estrellas: float = 90.0

@export_group("Intro")
## Reproduce el paneo de entrada al cerrar la cartilla inicial.
@export var intro_camara: bool = true
## Tiempo mínimo antes de que un clic/tecla pueda saltar la intro.
@export var espera_salto_intro: float = 0.3

@export_group("Cámara")
## Aire horizontal extra para la cámara. No cambia los rebotes del slime.
@export var margen_camara_h: float = 160.0
## Aire vertical extra. 0 = la cámara nunca muestra fondo arriba ni abajo.
@export var margen_camara_v: float = 0.0

@export_group("Fondo")
## Color del cielo que se ve tras el mapa (evita el gris por defecto).
@export var color_cielo: Color = Color(0.06, 0.13, 0.10)
## Siluetas opcionales que se dibujan al pie de la pantalla.
@export var textura_fondo: Texture2D
## Tinte de las siluetas para adaptarlas a la paleta del nivel.
@export var tinte_fondo: Color = Color(1, 1, 1)

## Slimes disponibles: { tipo: cantidad }. Cada nivel concreto lo redefine.
var slimes_nivel: Dictionary = {
	SlimeCatalogo.Tipo.BASE: 3,
	SlimeCatalogo.Tipo.FUEGO: 1,
}

var limites_globales: Rect2 = Rect2()
## Rect ampliado solo para la cámara: la física sigue usando limites_globales.
var limites_camara: Rect2 = Rect2()
var tiempo_transcurrido: float = 0.0
var _hud_tiempo: NivelHudTiempo
## true solo cuando la cartilla inicial y la intro ya terminaron.
var _explicacion_completada: bool = false
## Evita relanzar el arranque si la cartilla vuelve a emitir el cierre.
var _cartilla_inicial_cerrada: bool = false
## true solo si la cartilla inicial llegó a mostrarse: entonces sí se marca como vista.
var _cartilla_inicial_mostrada: bool = false
## "inicial" o "ayuda": motivo de la cartilla actualmente abierta.
var _motivo_cartilla: String = ""
## true mientras la cinemática de entrada está en curso.
var _en_intro: bool = false
var _tiempo_intro: float = 0.0

@onready var slingshoot: Node2D = $Slingshoot
@onready var ui: SlimeSelectorUI = $SlimeSelectorUI
@onready var camara: CamaraSeguimiento = $Camara

var pantalla: PantallaFin
## true cuando el nivel ya terminó: evita que una pantalla pise a la otra.
var _terminado: bool = false

func _ready() -> void:
	_crear_fondo()
	_conectar_resortera()
	_crear_pantalla_fin()
	_conectar_metas()
	_agrupar_musica()
	_aplicar_limites()

	# Primero la UI (crea los slots), luego la resortera (emite inventario_cambiado).
	ui.configurar(slimes_nivel)
	slingshoot.configurar(slimes_nivel)

	camara.seguir(slingshoot, true)

	_hud_tiempo = NivelHudTiempo.new(self)

	pantalla.bloquear_pausa(true)

	# Primero se lee la cartilla (solo la primera vez); luego va la intro.
	slingshoot.set_interactivo(false)
	slingshoot.mostrar_hud(false)
	ui.visible = false
	_preparar_arranque()


## Abre la cartilla si es la primera vez; si no, pasa directo a la intro.
func _preparar_arranque() -> void:
	if not slingshoot.esta_hud_listo():
		await slingshoot.hud_listo

	if AUTOABRIR_PRIMERA_VEZ and not ProgresoTutorial.visto(scene_file_path):
		_motivo_cartilla = "inicial"
		slingshoot.mostrar_hud(true)
		_cartilla_inicial_mostrada = slingshoot.abrir_cartilla("inicial")
		return

	# Ya conoce la explicación: no se vuelve a abrir sola.
	_cartilla_inicial_cerrada = true
	_iniciar_intro()


func _process(delta: float) -> void:
	if _en_intro:
		_tiempo_intro += delta
		return
	if _terminado or not _explicacion_completada or _hud_tiempo == null:
		return
	tiempo_transcurrido += delta
	_hud_tiempo.mostrar(tiempo_transcurrido)


func _unhandled_input(event: InputEvent) -> void:
	if not _en_intro or _tiempo_intro < espera_salto_intro:
		return
	var saltar := false
	if event is InputEventMouseButton:
		saltar = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		saltar = (event as InputEventScreenTouch).pressed
	elif event is InputEventJoypadButton:
		saltar = (event as InputEventJoypadButton).pressed
	elif event is InputEventKey:
		var tecla := event as InputEventKey
		saltar = tecla.pressed and not tecla.echo
	if not saltar:
		return
	camara.saltar_intro()
	get_viewport().set_input_as_handled()


func _conectar_resortera() -> void:
	slingshoot.inventario_cambiado.connect(ui.actualizar)
	ui.slime_elegido.connect(slingshoot.seleccionar)
	slingshoot.sin_municion.connect(_on_sin_municion)
	slingshoot.slime_lanzado.connect(_on_slime_lanzado)
	slingshoot.slime_cargado.connect(_on_slime_cargado)
	slingshoot.explicacion_completada.connect(_on_explicacion_completada)
	slingshoot.ayuda_solicitada.connect(_on_ayuda_solicitada)

func _crear_pantalla_fin() -> void:
	pantalla = get_node_or_null("PantallaFin") as PantallaFin
	if pantalla == null:
		pantalla = PantallaFin.new()
		add_child(pantalla)
	_configurar_progresion()

func _conectar_metas() -> void:
	var metas := get_tree().get_nodes_in_group("meta")
	if metas.is_empty():
		push_warning("Este nivel no tiene ninguna Meta (instancia Scenes/Meta.tscn): no se podrá ganar.")
	for meta in metas:
		meta.meta_alcanzada.connect(_on_meta_alcanzada)

func _agrupar_musica() -> void:
	var musicos := get_tree().get_nodes_in_group("musica_nivel")
	if musicos.is_empty():
		var audio_nodes := find_children("*", "AudioStreamPlayer", true, false)
		for a in audio_nodes:
			a.add_to_group("musica_nivel")

func _aplicar_limites() -> void:
	limites_globales = NivelLimites.calcular(self)
	limites_camara = NivelLimites.ampliar(
		limites_globales, margen_camara_h, margen_camara_v
	)
	camara.aplicar_limites(limites_camara)
	if mostrar_limites:
		print("%s límites: %s" % [name, limites_globales])
		NivelLimites.crear_marco(self, limites_globales)

## Cielo a pantalla completa y siluetas: nunca se ve el gris por defecto.
func _crear_fondo() -> void:
	var capa := CanvasLayer.new()
	capa.name = "FondoPantalla"
	capa.layer = -100
	add_child(capa)

	var cielo := ColorRect.new()
	cielo.name = "Cielo"
	cielo.color = color_cielo
	cielo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(cielo)
	cielo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if textura_fondo == null:
		return
	var siluetas := TextureRect.new()
	siluetas.name = "Siluetas"
	siluetas.texture = textura_fondo
	siluetas.modulate = tinte_fondo
	siluetas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	siluetas.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	siluetas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(siluetas)
	siluetas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _configurar_progresion() -> void:
	var posicion := ORDEN_NIVELES.find(scene_file_path)
	if posicion < 0:
		return
	pantalla.primer_nivel = ORDEN_NIVELES[0]
	if posicion + 1 < ORDEN_NIVELES.size():
		pantalla.siguiente_nivel = ORDEN_NIVELES[posicion + 1]
	else:
		pantalla.es_final_del_juego = true


## Se cerró una cartilla: la inicial inicia la intro; la ayuda reanuda el juego.
func _on_explicacion_completada() -> void:
	if _motivo_cartilla == "ayuda":
		_motivo_cartilla = ""
		_reanudar_juego()
		return

	if _cartilla_inicial_cerrada:
		return
	_cartilla_inicial_cerrada = true
	# Solo cuenta como vista si de verdad se mostró; si falló, se reintenta al volver.
	if _cartilla_inicial_mostrada:
		ProgresoTutorial.marcar_visto(scene_file_path)
	_cartilla_inicial_mostrada = false
	_motivo_cartilla = ""
	_iniciar_intro()


## Oculta el HUD, recorre el mapa y deja el nivel listo para jugar.
func _iniciar_intro() -> void:
	slingshoot.set_interactivo(false)
	slingshoot.mostrar_hud(false)
	ui.visible = false

	if intro_camara:
		_en_intro = true
		_tiempo_intro = 0.0
		camara.seguir(slingshoot, true)
		camara.reproducir_intro(limites_camara)
		await camara.intro_terminada
		camara.seguir(slingshoot, true)
		_en_intro = false

	slingshoot.mostrar_hud(true)
	ui.visible = true
	_comenzar_juego()


## Habilita el disparo, el cronómetro y la pausa tras la intro.
func _comenzar_juego() -> void:
	_explicacion_completada = true
	tiempo_transcurrido = 0.0
	if _hud_tiempo != null:
		_hud_tiempo.mostrar(0.0)
	if pantalla != null:
		pantalla.bloquear_pausa(false)
	slingshoot.set_interactivo(true)


## El botón ? pide releer la explicación en mitad de la partida.
func _on_ayuda_solicitada() -> void:
	if _terminado or not _explicacion_completada or _en_intro:
		return
	# Nunca encimar la cartilla sobre la pausa o el resultado del nivel.
	if pantalla != null and pantalla.modo != PantallaFin.Modo.OCULTA:
		return
	if _motivo_cartilla == "ayuda":
		return
	_motivo_cartilla = "ayuda"
	if not slingshoot.abrir_cartilla("ayuda"):
		_motivo_cartilla = ""
		return
	slingshoot.set_interactivo(false)
	if pantalla != null:
		pantalla.bloquear_pausa(true)


## Vuelve al juego tras cerrar una cartilla de ayuda.
func _reanudar_juego() -> void:
	if _terminado:
		return
	slingshoot.set_interactivo(true)
	if pantalla != null:
		pantalla.bloquear_pausa(false)


func _calcular_estrellas() -> int:
	if tiempo_transcurrido <= tiempo_3_estrellas:
		return 3
	if tiempo_transcurrido <= tiempo_2_estrellas:
		return 2
	return 1


func _on_slime_lanzado(slime: Node2D) -> void:
	slime.set("limites", limites_globales)
	camara.seguir(slime)

func _on_slime_cargado(_slime: Node2D) -> void:
	camara.seguir(slingshoot)

func _on_sin_municion() -> void:
	camara.seguir(slingshoot)
	if _terminado:
		return
	_terminado = true
	pantalla.mostrar_derrota.call_deferred("Te quedaste sin slimes")

func _on_meta_alcanzada() -> void:
	if _terminado:
		return
	_terminado = true
	var mensaje := "Tiempo: %s\nSlimes sobrantes: %d" % [NivelHudTiempo.formatear(tiempo_transcurrido), _slimes_restantes()]
	pantalla.mostrar_victoria.call_deferred(mensaje, _calcular_estrellas())

func _slimes_restantes() -> int:
	return SlimeInventario.total(slingshoot.get_inventario())

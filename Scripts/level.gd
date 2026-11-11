class_name NivelSlimes
extends Node2D
## Script del nivel: conecta resortera, UI, cámara y pantalla de fin.

## Orden de los niveles. El último cierra el juego.
const ORDEN_NIVELES: Array[String] = [
	"res://Scenes/Levels/jungleLevel.tscn",
	"res://Scenes/Levels/Level_Ice.tscn",
]

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

## Slimes disponibles: { tipo: cantidad }. Cada nivel concreto lo redefine.
var slimes_nivel: Dictionary = {
	SlimeCatalogo.Tipo.BASE: 3,
	SlimeCatalogo.Tipo.FUEGO: 1,
}

var limites_globales: Rect2 = Rect2()
var tiempo_transcurrido: float = 0.0
var _hud_tiempo: NivelHudTiempo
## true solo cuando la cartilla inicial y la intro ya terminaron.
var _explicacion_completada: bool = false
## Evita relanzar el arranque si la cartilla vuelve a emitir el cierre.
var _cartilla_inicial_cerrada: bool = false
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

	# Primero se lee la cartilla; al cerrarla arranca la intro y después el juego.
	slingshoot.set_interactivo(false)
	slingshoot.mostrar_hud(false)
	ui.visible = false
	_mostrar_cartilla_inicial()


## Espera al HUD y abre la cartilla explicativa antes de la cinemática.
func _mostrar_cartilla_inicial() -> void:
	if not slingshoot.esta_hud_listo():
		await slingshoot.hud_listo
	slingshoot.mostrar_hud(true)
	slingshoot.abrir_cartilla("inicial")


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
	camara.aplicar_limites(limites_globales)
	if mostrar_limites:
		print("%s límites: %s" % [name, limites_globales])
		NivelLimites.crear_marco(self, limites_globales)

func _configurar_progresion() -> void:
	var posicion := ORDEN_NIVELES.find(scene_file_path)
	if posicion < 0:
		return
	pantalla.primer_nivel = ORDEN_NIVELES[0]
	if posicion + 1 < ORDEN_NIVELES.size():
		pantalla.siguiente_nivel = ORDEN_NIVELES[posicion + 1]
	else:
		pantalla.es_final_del_juego = true


## La cartilla inicial se cerró: recién ahora se reproduce la intro.
func _on_explicacion_completada() -> void:
	if _cartilla_inicial_cerrada:
		return
	_cartilla_inicial_cerrada = true
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
		camara.reproducir_intro(limites_globales)
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

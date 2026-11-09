class_name NivelSlimes
extends Node2D
## Script del nivel: conecta resortera, UI, cámara y pantalla de fin.

## Orden de los niveles. El último cierra el juego.
const ORDEN_NIVELES: Array[String] = [
	"res://Scenes/Levels/jungleLevel.tscn",
	"res://Scenes/Levels/Level_Ice.tscn",
]

## Slimes disponibles: { tipo: cantidad }. Cada nivel concreto lo redefine.
var slimes_nivel: Dictionary = {
	SlimeCatalogo.Tipo.BASE: 3,
	SlimeCatalogo.Tipo.FUEGO: 1,
}

@export_group("Límites del nivel")
@export var mostrar_limites: bool = false

@export_group("Estrellas")
## Tiempo (s) máximo para 3 estrellas.
@export var tiempo_3_estrellas: float = 45.0
## Tiempo (s) máximo para 2 estrellas.
@export var tiempo_2_estrellas: float = 90.0

var limites_globales: Rect2 = Rect2()
var tiempo_transcurrido: float = 0.0
var _hud_tiempo: NivelHudTiempo
## false mientras la cartilla está abierta: el nivel aún no ha comenzado.
var _explicacion_completada: bool = false

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


func _process(delta: float) -> void:
	if _terminado or not _explicacion_completada or _hud_tiempo == null:
		return
	tiempo_transcurrido += delta
	_hud_tiempo.mostrar(tiempo_transcurrido)


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


func _on_explicacion_completada() -> void:
	if _explicacion_completada:
		return
	_explicacion_completada = true
	tiempo_transcurrido = 0.0
	if _hud_tiempo != null:
		_hud_tiempo.mostrar(0.0)
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

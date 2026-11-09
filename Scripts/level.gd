class_name NivelSlimes
extends Node2D
## Script del nivel: es el único que conoce a la resortera y a la UI.
## Les entrega el inventario de slimes y los comunica entre sí.
## También decide cuándo termina el nivel: victoria al tocar una Meta, derrota al quedarse sin slimes.
## Clases auxiliares:
##   NivelLimites   -> rectángulo de límites del nivel
##   NivelHudTiempo -> cronómetro en pantalla
##   SlimeInventario -> conteo de slimes restantes

## Orden de los niveles del juego. Al ganar se pasa al siguiente de esta lista y el último
## cierra el juego. Para añadir un nivel basta con añadirlo aquí.
const ORDEN_NIVELES: Array[String] = [
	"res://Scenes/Levels/jungleLevel.tscn",
	"res://Scenes/Levels/Level_Ice.tscn",
]

## Slimes disponibles en este nivel: { tipo de slime: cantidad }.
## Los tipos están definidos en SlimeCatalogo.Tipo.
## Cada nivel concreto lo redefine en su propio script (ver jungle_level.gd).
var slimes_nivel: Dictionary = {
	SlimeCatalogo.Tipo.BASE: 3,
	SlimeCatalogo.Tipo.FUEGO: 1,
}

@export_group("Límites del nivel")
@export var mostrar_limites: bool = false

@export_group("Estrellas")
## Tiempo (s) máximo para conseguir 3 estrellas.
@export var tiempo_3_estrellas: float = 45.0
## Tiempo (s) máximo para conseguir 2 estrellas. Más que esto = 1 estrella.
@export var tiempo_2_estrellas: float = 90.0

var limites_globales: Rect2 = Rect2()
var tiempo_transcurrido: float = 0.0
var _hud_tiempo: NivelHudTiempo
## false mientras el tablero explicativo está abierto: el nivel aún no ha comenzado.
var _explicacion_completada: bool = false

@onready var slingshoot: Node2D = $Slingshoot
@onready var ui: SlimeSelectorUI = $SlimeSelectorUI
@onready var camara: CamaraSeguimiento = $Camara

## Pantalla de pausa / fin de nivel. Si el nivel no tiene un nodo "PantallaFin", se crea sola.
var pantalla: PantallaFin
## true cuando el nivel ya terminó (victoria o derrota): evita que una pantalla pise a la otra.
var _terminado: bool = false

func _ready() -> void:
	_conectar_resortera()
	_crear_pantalla_fin()
	_conectar_metas()
	_agrupar_musica()
	_aplicar_limites()

	# Mismo diccionario para los dos. Primero la UI (crea los slots) y luego la
	# resortera (emite inventario_cambiado y la UI se rellena).
	ui.configurar(slimes_nivel)
	slingshoot.configurar(slimes_nivel)

	# La cámara arranca ya sobre la resortera (sin paneo inicial).
	camara.seguir(slingshoot, true)

	_hud_tiempo = NivelHudTiempo.new(self)

	# Mientras se lee el tablero no se puede pausar ni contar tiempo: el nivel
	# empieza realmente cuando la cartilla emite su cierre.
	pantalla.bloquear_pausa(true)


func _process(delta: float) -> void:
	if _terminado or not _explicacion_completada or _hud_tiempo == null:
		return
	tiempo_transcurrido += delta
	_hud_tiempo.mostrar(tiempo_transcurrido)

# ---------------------------------------------------------------------------
# Preparación del nivel (se llama desde _ready)
# ---------------------------------------------------------------------------

func _conectar_resortera() -> void:
	# Resortera -> UI: cambió la munición o la selección.
	slingshoot.inventario_cambiado.connect(ui.actualizar)
	# UI -> Resortera: el jugador eligió otro tipo de slime.
	ui.slime_elegido.connect(slingshoot.seleccionar)
	# Resortera -> Nivel: ya no queda munición.
	slingshoot.sin_municion.connect(_on_sin_municion)
	# Resortera -> Cámara: sigue al slime en vuelo y vuelve a la resortera al recargar.
	slingshoot.slime_lanzado.connect(_on_slime_lanzado)
	slingshoot.slime_cargado.connect(_on_slime_cargado)
	# Resortera -> Nivel: el tablero explicativo inicial ya se leyó por completo.
	slingshoot.explicacion_completada.connect(_on_explicacion_completada)

func _crear_pantalla_fin() -> void:
	pantalla = get_node_or_null("PantallaFin") as PantallaFin
	if pantalla == null:
		pantalla = PantallaFin.new()
		add_child(pantalla)
	_configurar_progresion()

## Meta(s) del nivel: cualquier nodo Meta en la escena se encuentra por su grupo.
func _conectar_metas() -> void:
	var metas := get_tree().get_nodes_in_group("meta")
	if metas.is_empty():
		push_warning("Este nivel no tiene ninguna Meta (instancia Scenes/Meta.tscn): no se podrá ganar.")
	for meta in metas:
		meta.meta_alcanzada.connect(_on_meta_alcanzada)

## La musica del nivel se agrupa para que la cartilla pueda pausarla.
func _agrupar_musica() -> void:
	var musicos := get_tree().get_nodes_in_group("musica_nivel")
	if musicos.is_empty():
		var audio_nodes := find_children("*", "AudioStreamPlayer", true, false)
		for a in audio_nodes:
			a.add_to_group("musica_nivel")

## Límites: la cámara no sale del nivel y el slime rebota en sus bordes.
func _aplicar_limites() -> void:
	limites_globales = NivelLimites.calcular(self)
	camara.aplicar_limites(limites_globales)
	if mostrar_limites:
		print("%s límites: %s" % [name, limites_globales])
		NivelLimites.crear_marco(self, limites_globales)

## Le dice a la pantalla de fin qué viene después de este nivel según ORDEN_NIVELES.
## Un nivel que no esté en la lista (por ejemplo Level_1) solo ofrece repetirse.
func _configurar_progresion() -> void:
	var posicion := ORDEN_NIVELES.find(scene_file_path)
	if posicion < 0:
		return
	pantalla.primer_nivel = ORDEN_NIVELES[0]
	if posicion + 1 < ORDEN_NIVELES.size():
		pantalla.siguiente_nivel = ORDEN_NIVELES[posicion + 1]
	else:
		pantalla.es_final_del_juego = true

# ---------------------------------------------------------------------------
# Tiempo y estrellas
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Eventos del juego
# ---------------------------------------------------------------------------

func _on_slime_lanzado(slime: Node2D) -> void:
	# El slime en vuelo rebota en los límites del nivel y la cámara lo sigue.
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

## Slimes que aún no se han disparado (el que está volando ya se descontó).
func _slimes_restantes() -> int:
	return SlimeInventario.total(slingshoot.get_inventario())

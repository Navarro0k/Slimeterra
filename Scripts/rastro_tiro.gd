class_name RastroTiro
extends Node2D
## Rastro del último tiro. Dibuja, uno encima del otro:
##   - los puntos que PREDIJO la resortera con RK4 (cuadritos huecos blancos), y
##   - las posiciones REALES del slime en vuelo en esos mismos instantes (puntos celestes).
## Si RK4 predice bien, los puntos reales caen dentro de los cuadritos de la predicción.
## También mide la altura máxima, el alcance y el tiempo reales para compararlos en la
## tarjeta "¿Cómo se calculó este salto?". El rastro se mantiene hasta el siguiente tiro.

## Se emite cuando el slime termina su vuelo (se pegó, cayó o se perdió).
signal vuelo_terminado(datos: Dictionary, resumen: Dictionary)

const COLOR_PREDICCION := Color(1, 1, 1, 0.55)
const COLOR_REAL := Color(0.35, 0.95, 1.0, 0.95)
const COLOR_CIMA := Color(1.0, 0.95, 0.4, 0.95)

var _slime: Node2D
var _datos: Dictionary = {}
var _activo: bool = false

var _t: float = 0.0
var _dt_muestra: float = 0.08
var _pos0: Vector2
var _anterior: Vector2
var _t_anterior: float = 0.0
var _siguiente_muestra: int = 1

var _prediccion: PackedVector2Array = PackedVector2Array()
var _reales: PackedVector2Array = PackedVector2Array()
var _cima: Vector2
var _hubo_cima: bool = false
var _caida: Vector2
var _t_caida: float = 0.0
var _cruzo: bool = false
var _t_cima: float = 0.0

## Vuelo libre simulado en paralelo con el mismo RK4 y el mismo paso que el slime. Mientras
## el slime real no choque, rebote ni se pegue, ambos coinciden; el instante en que se separan
## es cuando el vuelo real dejó de ser "vuelo libre".
var _libre_pos: Vector2
var _libre_vel: Vector2
var _t_desvio: float = INF
const TOLERANCIA_DESVIO_PX := 0.5

func _ready() -> void:
	z_index = 5
	# El rastro vive en coordenadas globales: el nodo debe quedar sin transformación.
	top_level = true
	global_transform = Transform2D.IDENTITY

## Empieza a registrar el vuelo de `slime`, que salió con la predicción `datos` de la resortera.
func iniciar(slime: Node2D, datos: Dictionary) -> void:
	_terminar_sin_avisar()
	_datos = datos
	_slime = slime
	_prediccion = datos.get("puntos_global", PackedVector2Array())
	_dt_muestra = datos.get("dt", 0.08)
	_pos0 = datos.get("pos0_global", slime.global_position)
	_reales = PackedVector2Array([_pos0])
	_anterior = _pos0
	_t = 0.0
	_t_anterior = 0.0
	_siguiente_muestra = 1
	_cima = _pos0
	_hubo_cima = false
	_cruzo = false
	_t_cima = 0.0
	_libre_pos = _pos0
	_libre_vel = datos.get("v0", Vector2.ZERO)
	_t_desvio = INF
	_activo = true
	slime.tree_exiting.connect(_finalizar, CONNECT_ONE_SHOT)
	queue_redraw()

func limpiar() -> void:
	_terminar_sin_avisar()
	_prediccion = PackedVector2Array()
	_reales = PackedVector2Array()
	queue_redraw()

func _terminar_sin_avisar() -> void:
	if _activo and is_instance_valid(_slime) and _slime.tree_exiting.is_connected(_finalizar):
		_slime.tree_exiting.disconnect(_finalizar)
	_activo = false
	_slime = null

func _physics_process(delta: float) -> void:
	if not _activo or not is_instance_valid(_slime):
		return
	var pos := _slime.global_position
	var t := _t
	_t += delta
	if t <= 0.0:
		return # Primer frame: el slime aún está en el punto de lanzamiento.

	# Avanza el vuelo libre un paso y compara con la posición real.
	var r: Array = SolverNumerico.paso(SolverNumerico.Metodo.RK4, _libre_pos, _libre_vel, delta,
			_datos.get("gravedad", 980.0), _datos.get("k", 0.0))
	_libre_pos = r[0]
	_libre_vel = r[1]
	if _t_desvio == INF and pos.distance_to(_libre_pos) > TOLERANCIA_DESVIO_PX:
		_t_desvio = _t_anterior

	# Muestras cada Δt (los mismos instantes de los puntos predichos), interpolando
	# entre los dos frames de física que rodean cada instante.
	while _siguiente_muestra * _dt_muestra <= t:
		var t_m := _siguiente_muestra * _dt_muestra
		var f := (t_m - _t_anterior) / maxf(t - _t_anterior, 0.000001)
		_reales.append(_anterior.lerp(pos, f))
		_siguiente_muestra += 1

	# Cima real: el slime deja de subir (en Godot subir es y decreciente).
	if pos.y < _cima.y:
		_cima = pos
		_t_cima = t
	elif not _hubo_cima and pos.y > _anterior.y and _cima.y < _pos0.y:
		_hubo_cima = true

	# Vuelta a la altura de lanzamiento, bajando.
	if _hubo_cima and not _cruzo and _anterior.y < _pos0.y and pos.y >= _pos0.y:
		var f := (_pos0.y - _anterior.y) / maxf(pos.y - _anterior.y, 0.000001)
		_caida = _anterior.lerp(pos, f)
		_t_caida = _t_anterior + f * (t - _t_anterior)
		_cruzo = true

	_anterior = pos
	_t_anterior = t
	queue_redraw()

func _finalizar() -> void:
	if not _activo:
		return
	_activo = false
	_slime = null
	var resumen := {
		"duracion": _t_anterior,
		"altura_real": maxf(_pos0.y - _cima.y, 0.0),
		"llego_a_cima": _hubo_cima,
		# true si el vuelo real se separó del vuelo libre (choque, rebote o se pegó) y en qué instante.
		"se_desvio": _t_desvio != INF,
		"t_desvio": _t_desvio,
		"cima_valida": _hubo_cima and _t_cima <= _t_desvio,
		"caida_valida": _cruzo and _t_caida <= _t_desvio,
		"cruzo": _cruzo,
		"alcance_real": absf(_caida.x - _pos0.x) if _cruzo else 0.0,
		"tiempo_real": _t_caida if _cruzo else 0.0,
		"puntos_reales": _reales.size(),
	}
	queue_redraw()
	vuelo_terminado.emit(_datos, resumen)

func _draw() -> void:
	for p in _prediccion:
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), COLOR_PREDICCION, false, 1.0)
	for p in _reales:
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), COLOR_REAL)
	if _hubo_cima:
		# Marca de la altura máxima real: una rayita horizontal amarilla.
		draw_line(_cima + Vector2(-4, 0), _cima + Vector2(4, 0), COLOR_CIMA, 1.0)

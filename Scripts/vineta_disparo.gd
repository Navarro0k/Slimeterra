class_name VinetaDisparo
extends Control
## Viñeta esquemática de la cartilla: la honda dispara un slime en bucle.
## No es interactiva y no cambia el contenido del tablero: solo lo apoya.

const DURACION_CICLO: float = 6.0
const DT_RUTA: float = 1.0 / 60.0
const PASOS_MAX: int = 180
const PASOS_IDEAL: int = 40
const MARGEN: float = 5.0
## Semiancho de la honda: margen lateral para que no se recorte.
const MARGEN_HONDA: float = 17.0
## Altura reservada bajo el punto de lanzamiento (honda + suelo).
const SUELO_MARGEN: float = 18.0
const LINEA_SUELO: float = 6.0
const ESCALA_MIN: float = 0.06
const ESCALA_MAX: float = 1.0
## Rapidez de referencia del disparo (max_stretch * multiplicador_fuerza).
const RAPIDEZ_REF: float = 450.0

const T_FIN_TENSION: float = 0.22
const T_FIN_SUELTA: float = 0.26
const T_FIN_VUELO: float = 0.78
const T_FIN_IMPACTO: float = 0.86
const T_REAPARECE: float = 0.94

const TAM_SLIME: float = 18.0
const TAM_HONDA: float = 32.0
const TAM_PARCHE: float = 12.0

const TEXTURA_HONDA := preload("res://Assets/pngs/Honda madera.png")
const TEXTURA_PARCHE := preload("res://Assets/pngs/parche honda.png")
const TEXTURA_SLIME := preload("res://Assets/pngs/slime-base.png")
const FUENTE := preload("res://Assets/fonts/JetBrainsMono-Regular.ttf")

var _modo: String = "parabola"
var _pagina: int = 0
var _textura_slime: Texture2D = TEXTURA_SLIME

var _pos0: Vector2 = Vector2(120.0, 200.0)
var _vel0: Vector2 = Vector2(260.0, -260.0)
var _gravedad: float = 980.0
var _k: float = 0.0

var _t: float = 0.0
var _angulo_grados: float = 45.0
var _angulo_visual: float = -0.785398
var _potencia: float = 0.65

var _ruta: PackedVector2Array = PackedVector2Array()
var _vel_ruta: PackedVector2Array = PackedVector2Array()
var _ruta_ideal: PackedVector2Array = PackedVector2Array()
var _pantalla: PackedVector2Array = PackedVector2Array()
var _pantalla_ideal: PackedVector2Array = PackedVector2Array()
var _origen: Vector2 = Vector2.ZERO
var _escala: float = 1.0
var _valido: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	_actualizar_lecturas()
	_recalcular()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recalcular()


func _process(delta: float) -> void:
	if not _valido or not is_visible_in_tree():
		return
	_t = fmod(_t + delta, DURACION_CICLO)
	queue_redraw()


## Modo y modelo real del disparo. No reinicia el ciclo.
func configurar(modo: String, pos0: Vector2, vel0: Vector2, gravedad: float, amortiguamiento: float) -> void:
	_modo = "matrices" if modo == "matrices" else "parabola"
	_pos0 = pos0
	if vel0.length() > 1.0:
		_vel0 = vel0
	if gravedad > 0.0:
		_gravedad = gravedad
	_k = maxf(amortiguamiento, 0.0)
	_actualizar_lecturas()
	_recalcular()


## Página visible (0..2). Solo reinicia el ciclo cuando cambia de verdad.
func set_pagina(pagina: int) -> void:
	var nueva := clampi(pagina, 0, 2)
	if nueva == _pagina and _t > 0.0:
		return
	_pagina = nueva
	_t = 0.0
	queue_redraw()


## Slime que el jugador tiene cargado (por defecto, el base).
func set_textura_slime(textura: Texture2D) -> void:
	if textura == null:
		return
	_textura_slime = textura
	queue_redraw()


func reiniciar() -> void:
	_t = 0.0
	set_process(true)
	queue_redraw()


func detener() -> void:
	set_process(false)


## ---------------------------------------------------------------------------
## Modelo y encuadre
## ---------------------------------------------------------------------------

func _actualizar_lecturas() -> void:
	_angulo_grados = fposmod(rad_to_deg(atan2(-_vel0.y, _vel0.x)), 360.0)
	_angulo_visual = atan2(_vel0.y, _vel0.x)
	_potencia = clampf(_vel0.length() / RAPIDEZ_REF, 0.0, 1.0)


func _recalcular() -> void:
	_ruta = _simular_vuelo()
	_ruta_ideal = _simular_ideal()
	_encajar()
	queue_redraw()


## Vuelo esquemático: termina cuando el slime vuelve a la altura de salida
## (o cuando cae lo suficiente si el tiro es descendente).
func _simular_vuelo() -> PackedVector2Array:
	var puntos := PackedVector2Array()
	_vel_ruta = PackedVector2Array()
	var pos := _pos0
	var vel := _vel0
	var subio := false
	for _i in range(PASOS_MAX):
		var r: Array = SolverNumerico.paso(pos, vel, DT_RUTA, _gravedad, _k)
		pos = r[0]
		vel = r[1]
		puntos.append(pos)
		_vel_ruta.append(vel)
		if pos.y < _pos0.y - 1.0:
			subio = true
		if subio and pos.y >= _pos0.y:
			break
		if not subio and pos.y > _pos0.y + 60.0:
			break
	return puntos


## Curva ideal sin aire, solo para el nivel 1 (modo parábola).
func _simular_ideal() -> PackedVector2Array:
	if _modo == "matrices" or _ruta.size() < 2:
		return PackedVector2Array()
	var modelo := SolverNumerico.ecuacion_parabolica(_pos0, _vel0, _gravedad)
	if not bool(modelo.get("valida", false)):
		return PackedVector2Array()
	var a: float = float(modelo["a"])
	var b: float = float(modelo["b"])
	var c: float = float(modelo["c"])
	var t_total := DT_RUTA * float(_ruta.size())
	var puntos := PackedVector2Array()
	for i in range(PASOS_IDEAL):
		var t := t_total * float(i) / float(PASOS_IDEAL - 1)
		var x := _pos0.x + _vel0.x * t
		var y := a * x * x + b * x + c
		puntos.append(Vector2(x, y))
	return puntos


## Normaliza ruta real + ideal al lienzo, sin deformar la curva.
func _encajar() -> void:
	_valido = false
	if size.x < 32.0 or size.y < 32.0 or _ruta.is_empty():
		return

	var puntos := PackedVector2Array()
	puntos.append(_pos0)
	puntos.append_array(_ruta)
	puntos.append_array(_ruta_ideal)

	var min_x := puntos[0].x
	var max_x := puntos[0].x
	var min_y := puntos[0].y
	var max_y := puntos[0].y
	for p in puntos:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)

	var izq := absf(minf(0.0, min_x - _pos0.x))
	var der := maxf(0.0, max_x - _pos0.x)
	var arriba := absf(minf(0.0, min_y - _pos0.y))
	var abajo := maxf(0.0, max_y - _pos0.y)
	var ancho := maxf(izq + der, 1.0)
	var alto := maxf(arriba + abajo, 1.0)

	var util_ancho := maxf(size.x - 2.0 * MARGEN_HONDA, 4.0)
	var util_alto := maxf(size.y - MARGEN - SUELO_MARGEN - 4.0, 4.0)
	var escala := minf(util_ancho / ancho, util_alto / alto)
	_escala = clampf(escala, ESCALA_MIN, ESCALA_MAX)

	_origen = Vector2(
		MARGEN_HONDA + izq * _escala,
		size.y - SUELO_MARGEN - abajo * _escala
	)
	_pantalla = _mapear(_ruta)
	_pantalla_ideal = _mapear(_ruta_ideal)
	_valido = true


func _mapear(puntos: PackedVector2Array) -> PackedVector2Array:
	var salida := PackedVector2Array()
	for p in puntos:
		salida.append(_origen + (p - _pos0) * _escala)
	return salida


func _direccion_tiro() -> Vector2:
	if _vel0.length() < 0.001:
		return Vector2.RIGHT
	return _vel0.normalized()


## ---------------------------------------------------------------------------
## Dibujo
## ---------------------------------------------------------------------------

func _draw() -> void:
	_dibujar_fondo()
	if not _valido or _pantalla.size() < 2:
		return
	_dibujar_suelo()
	_dibujar_pedestal()
	_dibujar_honda()
	_dibujar_rutas()
	_dibujar_impacto()
	_dibujar_slime()
	match _pagina:
		0:
			_anotar_modelo()
		1:
			_anotar_curva()
		_:
			_anotar_disparo()


func _dibujar_fondo() -> void:
	var paso := 12.0
	var y := paso
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), HudTema.VINETA_CUADRICULA, 1.0)
		y += paso
	var x := paso
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), HudTema.VINETA_CUADRICULA, 1.0)
		x += paso


func _dibujar_suelo() -> void:
	var y := size.y - LINEA_SUELO
	draw_line(Vector2(0.0, y), Vector2(size.x, y), HudTema.VINETA_TRAZO, 1.0)
	var x := 2.0
	while x < size.x:
		draw_line(Vector2(x, y), Vector2(x + 3.0, y + 3.0), HudTema.VINETA_CUADRICULA, 1.0)
		x += 6.0


## Si el tiro sale desde una altura (ángulo bajo), la honda se apoya en un
## pedestal hasta la línea de suelo: nada queda flotando.
func _dibujar_pedestal() -> void:
	var suelo := size.y - LINEA_SUELO
	var tope := _origen.y + 12.0
	if tope >= suelo - 1.0:
		return
	var izq := _origen.x - 10.0
	var rect := Rect2(Vector2(izq, tope), Vector2(20.0, suelo - tope))
	draw_rect(rect, Color(HudTema.PAPEL_APAGADO, 0.55))
	draw_rect(rect, HudTema.VINETA_CUADRICULA, false, 1.0)
	var y := tope + 4.0
	while y < suelo:
		draw_line(Vector2(izq, y), Vector2(izq + 20.0, y), HudTema.VINETA_CUADRICULA, 1.0)
		y += 5.0


func _dibujar_honda() -> void:
	var centro := _origen
	var parche := _pouch()
	var anclas: Array[Vector2] = [
		centro + Vector2(-8.0, -7.0),
		centro + Vector2(8.0, -6.0),
	]
	for ancla in anclas:
		draw_line(ancla, parche, HudTema.VINETA_TRAZO, 1.0)
	draw_texture_rect(
		TEXTURA_HONDA,
		Rect2(centro - Vector2(TAM_HONDA * 0.5, TAM_HONDA * 0.5), Vector2(TAM_HONDA, TAM_HONDA)),
		false
	)
	draw_texture_rect(
		TEXTURA_PARCHE,
		Rect2(parche - Vector2(TAM_PARCHE * 0.5, TAM_PARCHE * 0.5), Vector2(TAM_PARCHE, TAM_PARCHE)),
		false
	)


func _dibujar_rutas() -> void:
	var alpha := _alpha_estela()
	if alpha <= 0.01:
		return
	var progreso := _progreso_vuelo()
	var cabeza := _indice_cabeza()

	if _pantalla_ideal.size() >= 2:
		var cabeza_ideal := int(floor(progreso * float(_pantalla_ideal.size() - 1)))
		for i in range(mini(cabeza_ideal + 1, _pantalla_ideal.size())):
			draw_rect(
				Rect2(_pantalla_ideal[i] - Vector2(0.5, 0.5), Vector2(1.0, 1.0)),
				Color(HudTema.VINETA_IDEAL, HudTema.VINETA_IDEAL.a * alpha)
			)

	var salto := 2 if _modo == "matrices" else 1
	for i in range(0, cabeza + 1, salto):
		var avance := float(i) / float(maxi(_pantalla.size() - 1, 1))
		var a := clampf(0.95 - 0.55 * avance, 0.0, 0.95) * alpha
		draw_rect(
			Rect2(_pantalla[i] - Vector2(1.0, 1.0), Vector2(2.0, 2.0)),
			Color(HudTema.VINETA_TRAZO, a)
		)


func _dibujar_slime() -> void:
	var alpha := _alpha_slime()
	if alpha <= 0.01:
		return
	var pos := _posicion_slime()
	var squash := _squash_slime()
	var mitad := Vector2(TAM_SLIME * 0.5 * squash.x, TAM_SLIME * 0.5 * squash.y)
	draw_texture_rect(
		_textura_slime,
		Rect2(pos - mitad, mitad * 2.0),
		false,
		Color(1.0, 1.0, 1.0, alpha)
	)


func _dibujar_impacto() -> void:
	if _t < T_FIN_VUELO or _t > T_FIN_VUELO + 0.12 or _pantalla.is_empty():
		return
	var avance := (_t - T_FIN_VUELO) / 0.12
	var centro := _pantalla[_pantalla.size() - 1]
	var radio := 2.0 + 5.0 * avance
	var polvo: Array[Vector2] = [
		Vector2(-1.0, -1.0),
		Vector2(1.0, -0.5),
		Vector2(0.3, 0.4),
	]
	for dir in polvo:
		var desplazamiento := dir.normalized() * radio
		draw_circle(centro + desplazamiento, 0.8, Color(HudTema.TINTA_SUAVE, 1.0 - avance))


func _anotar_modelo() -> void:
	var tinta := HudTema.TINTA_SUAVE
	var origen := _origen
	# Punto de lanzamiento.
	draw_line(origen - Vector2(3.0, 0.0), origen + Vector2(3.0, 0.0), tinta, 1.0)
	draw_line(origen - Vector2(0.0, 3.0), origen + Vector2(0.0, 3.0), tinta, 1.0)
	_texto(origen + Vector2(4.0, -4.0), "p0", tinta)
	# Velocidad inicial.
	var dir := _direccion_tiro()
	_flecha(origen, origen + dir * 16.0, HudTema.VINETA_TRAZO)
	_texto(origen + dir * 16.0 + Vector2(2.0, -3.0), "v0", tinta)
	# Fuerzas durante el vuelo.
	if _t < T_FIN_SUELTA or _t >= T_FIN_IMPACTO:
		return
	var pos := _posicion_slime()
	_flecha(pos, pos + Vector2(0.0, 10.0), tinta)
	_texto(pos + Vector2(2.0, 10.0), "g", tinta)
	if _k > 0.005:
		var cabeza := _indice_cabeza()
		if cabeza < _vel_ruta.size():
			var vel := _vel_ruta[cabeza]
			if vel.length() > 1.0:
				var contra := -vel.normalized()
				_flecha(pos, pos + contra * 8.0, HudTema.VINETA_TRAZO.darkened(0.15))
				_texto(pos + contra * 8.0 + Vector2(2.0, -3.0), "k*v", tinta)


func _anotar_curva() -> void:
	var tinta := HudTema.TINTA_SUAVE
	if _modo == "matrices":
		if _t < T_FIN_SUELTA or _t >= T_FIN_VUELO:
			return
		var cabeza := _indice_cabeza()
		if cabeza >= _pantalla.size() or cabeza >= _vel_ruta.size():
			return
		var vel := _vel_ruta[cabeza]
		if vel.length() <= 1.0:
			return
		var pos := _pantalla[cabeza]
		var dir := vel.normalized()
		_flecha(pos, pos + dir * 11.0, HudTema.VINETA_TRAZO)
		_texto(pos + dir * 11.0 + Vector2(2.0, -3.0), "s'", tinta)
		return

	if _progreso_vuelo() < 0.62:
		return
	if _pantalla_ideal.size() >= 2:
		var i := int(float(_pantalla_ideal.size()) * 0.62)
		_texto(_pantalla_ideal[i] + Vector2(-16.0, -4.0), "sin aire", HudTema.VINETA_IDEAL)
	if _k > 0.005 and _pantalla.size() >= 2:
		var j := int(float(_pantalla.size()) * 0.62)
		_texto(_pantalla[j] + Vector2(2.0, 7.0), "con aire", tinta)


func _anotar_disparo() -> void:
	var a := minf(0.0, _angulo_visual)
	var b := maxf(0.0, _angulo_visual)
	if absf(b - a) > 0.02:
		draw_arc(_origen, 14.0, a, b, 20, HudTema.VINETA_TRAZO, 1.0)
		draw_line(_origen, _origen + Vector2(14.0, 0.0), HudTema.VINETA_CUADRICULA, 1.0)
	_texto(_origen + Vector2(11.0, -17.0), "%d°" % roundi(_angulo_grados), HudTema.TINTA_SUAVE)

	# Barra de potencia (v0) en el borde derecho.
	var x := size.x - 6.0
	var arriba := 12.0
	var abajo := size.y - 26.0
	draw_line(Vector2(x, arriba), Vector2(x, abajo), HudTema.VINETA_CUADRICULA, 2.0)
	var alto := (abajo - arriba) * _potencia
	if alto > 0.5:
		draw_line(Vector2(x, abajo), Vector2(x, abajo - alto), HudTema.VINETA_TRAZO, 2.0)


## ---------------------------------------------------------------------------
## Estado del ciclo
## ---------------------------------------------------------------------------

func _progreso_vuelo() -> float:
	if _t <= T_FIN_SUELTA:
		return 0.0
	if _t >= T_FIN_VUELO:
		return 1.0
	return clampf((_t - T_FIN_SUELTA) / maxf(T_FIN_VUELO - T_FIN_SUELTA, 0.001), 0.0, 1.0)


func _indice_cabeza() -> int:
	if _pantalla.is_empty():
		return 0
	var i := int(floor(_progreso_vuelo() * float(_pantalla.size() - 1)))
	return clampi(i, 0, _pantalla.size() - 1)


func _tension_actual() -> float:
	if _t >= T_FIN_TENSION:
		return 0.0
	return smoothstep(0.0, T_FIN_TENSION, _t)


func _pouch() -> Vector2:
	return _origen - _direccion_tiro() * (7.0 * _tension_actual())


func _posicion_slime() -> Vector2:
	if _t < T_FIN_SUELTA or _t >= T_REAPARECE:
		return _pouch()
	if _pantalla.is_empty():
		return _origen
	if _t <= T_FIN_VUELO:
		return _pantalla[_indice_cabeza()]
	return _pantalla[_pantalla.size() - 1]


func _squash_slime() -> Vector2:
	var t := _tension_actual()
	return Vector2(1.0 + 0.10 * t, 1.0 - 0.10 * t)


func _alpha_estela() -> float:
	if _t < T_FIN_VUELO:
		return 1.0
	return clampf(1.0 - (_t - T_FIN_VUELO) / 0.14, 0.0, 1.0)


func _alpha_slime() -> float:
	if _t < T_FIN_IMPACTO:
		return 1.0
	if _t < T_REAPARECE:
		return clampf(1.0 - (_t - T_FIN_IMPACTO) / (T_REAPARECE - T_FIN_IMPACTO), 0.0, 1.0)
	return smoothstep(T_REAPARECE, 1.0, _t)


## ---------------------------------------------------------------------------
## Utilidades de dibujo
## ---------------------------------------------------------------------------

func _flecha(desde: Vector2, hasta: Vector2, color: Color, cabeza: float = 3.0) -> void:
	draw_line(desde, hasta, color, 1.0)
	var delta := hasta - desde
	if delta.length() < 0.01:
		return
	var dir := delta.normalized()
	var perp := Vector2(-dir.y, dir.x)
	draw_line(hasta, hasta - dir * cabeza + perp * cabeza * 0.6, color, 1.0)
	draw_line(hasta, hasta - dir * cabeza - perp * cabeza * 0.6, color, 1.0)


func _texto(pos: Vector2, txt: String, color: Color) -> void:
	var ancho := FUENTE.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6).x
	var x := clampf(pos.x, 1.0, maxf(size.x - ancho - 1.0, 1.0))
	draw_string(FUENTE, Vector2(x, pos.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, color)

class_name CartillaContenido
extends RefCounted
## Texto de las 4 páginas de la cartilla (tablero explicativo), con formato BBCode.
## No conoce nodos ni navegación: cartilla.gd le pide titulo/subtitulo/contenido de una página.
##
## El contenido es breve y cambia según el nivel: parábola (nivel 1) o espacio de
## estados con amortiguamiento (nivel 2). Las ecuaciones se destacan con un formato
## propio para que no se confundan con el texto normal.

## Colores del bloque de ecuaciones: cada nivel tiene su propia tinta, de modo
## que la explicación de parábola y la de matrices se distinguen de un vistazo.
const EQ_TINTA_PARABOLA := "#245112"
const EQ_FONDO_PARABOLA := "#DCEBC4"
const EQ_TINTA_MATRICES := "#0B4A6F"
const EQ_FONDO_MATRICES := "#D3E6F2"

## "parabola" (nivel 1) o "matrices" (nivel 2).
var modo_ecuacion: String = "parabola"

# Condiciones reales del disparo actual, enviadas por ShotHUD.
var _pos0: Vector2 = Vector2.ZERO
var _vel0: Vector2 = Vector2.ZERO
var _gravedad: float = 980.0
var _amortiguamiento: float = 0.0
var _hay_modelo: bool = false


## Condiciones iniciales y parámetros físicos reales del disparo actual.
func poner_modelo(pos: Vector2, vel: Vector2, gravedad: float, amortiguamiento: float) -> void:
	_pos0 = pos
	_vel0 = vel
	_gravedad = gravedad
	_amortiguamiento = amortiguamiento
	_hay_modelo = true


func es_matrices() -> bool:
	return modo_ecuacion == "matrices"


# ---------------------------------------------------------------------------
# Textos por página
# ---------------------------------------------------------------------------

func titulo(pagina: int) -> String:
	match pagina:
		0:
			return "El modelo del nivel"
		1:
			return "El sistema lineal" if es_matrices() else "La parábola del disparo"
		2:
			return "El método RK4"
		_:
			return "Listo para disparar"


func subtitulo(pagina: int) -> String:
	match pagina:
		0:
			return (
				"Gravedad, amortiguamiento y estado inicial"
				if es_matrices()
				else "Gravedad, aire y condiciones iniciales"
			)
		1:
			return (
				"Por qué ya no existe una sola parábola"
				if es_matrices()
				else "De las ecuaciones horarias a y(x)"
			)
		2:
			return "Cuatro pendientes por paso de simulación"
		_:
			return "Tu disparo actual y cómo apuntar"


func contenido(pagina: int) -> String:
	match pagina:
		0:
			return _pagina_modelo()
		1:
			return _pagina_ecuacion()
		2:
			return _pagina_rk4()
		_:
			return _pagina_listo()


# ---------------------------------------------------------------------------
# Páginas
# ---------------------------------------------------------------------------

func _pagina_modelo() -> String:
	var s := _chip_nivel() + "\n"
	s += "El slime se trata como una partícula: la gravedad tira hacia abajo y el "
	s += "aire lo frena proporcionalmente a su velocidad.\n"
	s += _eq("a = g − k·v")

	if not _hay_modelo:
		s += "[i]Esperando las condiciones del disparo...[/i]\n"
		return s

	s += "x crece a la derecha e y hacia abajo, así que g = (0, +" + _n(_gravedad, 0) + ").\n"
	s += _eq(
		"p0 = (" + _n(_pos0.x, 1) + ", " + _n(_pos0.y, 1) + ")\n"
		+ "v0 = (" + _n(_vel0.x, 1) + ", " + _n(_vel0.y, 1) + ")\n"
		+ "g = " + _n(_gravedad, 0) + " px/s²      k = " + _n(_amortiguamiento, 2) + " 1/s",
		13
	)

	if es_matrices():
		s += "Con k > 0 la aceleración depende de la velocidad y la curva no es una "
		s += "parábola: hace falta un sistema de estado."
	else:
		s += "El tablero usa el modelo ideal (k = 0): la aceleración es constante y "
		s += "la curva es una parábola."
	return s


func _pagina_ecuacion() -> String:
	if es_matrices():
		return _pagina_ecuacion_matrices()
	return _pagina_ecuacion_parabola()


func _pagina_ecuacion_parabola() -> String:
	var s := _chip_nivel() + "\n"
	s += "Sin amortiguamiento, la posición en cada instante es:\n"
	s += _eq("x(t) = x0 + vx0·t\ny(t) = y0 + vy0·t + ½g·t²", 14)
	s += "Despejando t de x(t) y sustituyéndolo en y(t) queda la parábola:\n"
	s += _eq("y(x) = a·x² + b·x + c", 18)

	if not _hay_modelo:
		s += "[i]Esperando los datos del disparo...[/i]\n"
		return s

	var modelo := SolverNumerico.ecuacion_parabolica(_pos0, _vel0, _gravedad)
	if not bool(modelo.get("valida", false)):
		s += "Con vx0 ≈ 0 la trayectoria es vertical y no puede escribirse como y(x).\n"
		return s

	var a: float = float(modelo["a"])
	var b: float = float(modelo["b"])
	var c: float = float(modelo["c"])
	s += _eq(
		"a = " + _n(a, 4) + "      b = " + _n(b, 4) + "      c = " + _n(c, 2),
		13
	)
	s += "a mide la curvatura, b la pendiente inicial y c la altura de salida. "
	s += "El HUD recalcula estos valores al mover ángulo o potencia."
	return s


func _pagina_ecuacion_matrices() -> String:
	var s := _chip_nivel() + "\n"
	s += "El estado reúne posición y velocidad, y su derivada es lineal:\n"
	s += _eq("s = (x, y, vx, vy)\ns' = A·s + b", 15)
	s += _eq(
		"A = [  0   0   1   0 ]\n"
		+ "    [  0   0   0   1 ]\n"
		+ "    [  0   0  −k   0 ]\n"
		+ "    [  0   0   0  −k ]\n"
		+ "b = (0, 0, 0, g)",
		13
	)
	s += "Las dos primeras filas copian v; las dos últimas aplican el "
	s += "amortiguamiento; b aporta la gravedad.\n"
	s += _eq(
		"k = " + _n(_amortiguamiento, 3) + " 1/s      g = " + _n(_gravedad, 0) + " px/s²",
		13
	)
	s += "Como la aceleración cambia con v, no existe una única y(x): la curva se "
	s += "obtiene integrando el sistema."
	return s


func _pagina_rk4() -> String:
	var h := 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	var s := _chip_nivel() + "\n"
	s += "RK4 avanza el estado en pasos h, evalúa la derivada cuatro veces y las "
	s += "combina con pesos 1–2–2–1:\n"
	s += _eq(
		"k1 = f(t, s)\n"
		+ "k2 = f(t + h/2, s + h·k1/2)\n"
		+ "k3 = f(t + h/2, s + h·k2/2)\n"
		+ "k4 = f(t + h,   s + h·k3)\n"
		+ "s_next = s + h·(k1 + 2k2 + 2k3 + k4)/6",
		13
	)

	if es_matrices():
		s += "Aquí f(s) = A·s + b: RK4 integra el sistema amortiguado y la curva "
		s += "dibujada es su solución numérica."
	else:
		s += "La parábola es la lectura ideal; el slime real se mueve integrando "
		s += "a = g − k·v con este mismo método."

	s += " El paso real es h = " + _n(h, 5) + " s, idéntico en la vista previa y en el slime."
	return s


func _pagina_listo() -> String:
	var s := _chip_nivel() + "\n"
	if _hay_modelo:
		var rapidez := _vel0.length()
		var angulo := fposmod(rad_to_deg(atan2(-_vel0.y, _vel0.x)), 360.0)
		s += _eq(
			"|v0| = " + _n(rapidez, 1) + " px/s      ángulo = " + _n(angulo, 1) + "°\n"
			+ "v0 = (" + _n(_vel0.x, 1) + ", " + _n(_vel0.y, 1) + ") px/s",
			13
		)
	else:
		s += "[i]Esperando las condiciones del disparo...[/i]\n"

	s += "• Más potencia → más rapidez y más alcance.\n"
	s += "• Más ángulo → más altura; menos ángulo → más alcance horizontal.\n"
	s += "• El amortiguamiento frena el slime y deforma la curva.\n\n"
	s += "El cronómetro aún no corre: arranca al pulsar COMENZAR NIVEL."
	return s


# ---------------------------------------------------------------------------
# Formato enriquecido
# ---------------------------------------------------------------------------

## Bloque de ecuación: centrado, monoespaciado, más grande y con resalte propio.
func _eq(texto: String, tamano: int = 16) -> String:
	var tinta := EQ_TINTA_MATRICES if es_matrices() else EQ_TINTA_PARABOLA
	var fondo := EQ_FONDO_MATRICES if es_matrices() else EQ_FONDO_PARABOLA
	var s := "\n[center][font_size=" + str(tamano) + "][color=" + tinta + "]"
	s += "[bgcolor=" + fondo + "][b]" + texto + "[/b][/bgcolor][/color][/font_size][/center]\n"
	return s


## Distintivo del nivel: deja claro de un vistazo qué modelo se está explicando.
func _chip_nivel() -> String:
	if es_matrices():
		return (
			"[center][color=#123A56][bgcolor=#CFE6F5][b]"
			+ "  NIVEL 2 · MATRICES  "
			+ "[/b][/bgcolor][/color][/center]\n"
		)
	return (
		"[center][color=#24420F][bgcolor=#D8EBB0][b]"
		+ "  NIVEL 1 · PARÁBOLA  "
		+ "[/b][/bgcolor][/color][/center]\n"
	)


func _n(valor: float, decimales: int = 2) -> String:
	return String.num(valor, decimales)

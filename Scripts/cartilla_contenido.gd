class_name CartillaContenido
extends RefCounted
## Texto BBCode de las 3 páginas de la cartilla.

const EQ_TINTA_PARABOLA := "#245112"
const EQ_FONDO_PARABOLA := "#DCEBC4"
const EQ_TINTA_MATRICES := "#0B4A6F"
const EQ_FONDO_MATRICES := "#D3E6F2"

## "parabola" (nivel 1) o "matrices" (nivel 2).
var modo_ecuacion: String = "parabola"

var _pos0: Vector2 = Vector2.ZERO
var _vel0: Vector2 = Vector2.ZERO
var _gravedad: float = 980.0
var _amortiguamiento: float = 0.0
var _hay_modelo: bool = false


func poner_modelo(pos: Vector2, vel: Vector2, gravedad: float, amortiguamiento: float) -> void:
	_pos0 = pos
	_vel0 = vel
	_gravedad = gravedad
	_amortiguamiento = amortiguamiento
	_hay_modelo = true


func es_matrices() -> bool:
	return modo_ecuacion == "matrices"


func titulo(pagina: int) -> String:
	match pagina:
		0:
			return "El modelo del nivel"
		1:
			return "El sistema lineal" if es_matrices() else "La curva del tiro ideal"
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
				"Cómo cambia la curva cuando hay aire"
				if es_matrices()
				else "De las ecuaciones horarias a y(x)"
			)
		_:
			return "Ajusta ángulo y potencia antes de disparar"


func contenido(pagina: int) -> String:
	match pagina:
		0:
			return _pagina_modelo()
		1:
			return _pagina_ecuacion()
		_:
			return _pagina_listo()


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
		s += "Con k > 0 la aceleración depende de la velocidad, así que la curva no es "
		s += "una parábola: hace falta un sistema de estado para describirla."
	else:
		s += "Este nivel se presenta como un tiro ideal: sin aire, la aceleración es "
		s += "constante y la curva es una parábola. El slime real no vuela en el vacío: "
		s += "su amortiguamiento es el k de arriba, así que su trayectoria se separa poco "
		s += "a poco de esa parábola."
	return s


func _pagina_ecuacion() -> String:
	if es_matrices():
		return _pagina_ecuacion_matrices()
	return _pagina_ecuacion_parabola()


func _pagina_ecuacion_parabola() -> String:
	var s := _chip_nivel() + "\n"
	s += "Sin aire, la posición en cada instante es:\n"
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
	s += "a mide la curvatura; b y c fijan la posición de la curva dentro del nivel. "
	s += "No deben leerse como el ángulo de salida ni como la altura del slime, "
	s += "porque el disparo no parte de x = 0. El HUD recalcula estos valores al "
	s += "mover ángulo o potencia."
	s += _mencion_motor()
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
	s += "Con aire la curva no es una parábola: se obtiene integrando el sistema "
	s += "paso a paso."
	s += _mencion_motor()
	return s


## Única mención al integrador: no se explica el método.
func _mencion_motor() -> String:
	return "\n[i]Motor de simulación: RK4. La línea punteada y el slime usan el mismo cálculo.[/i]\n"


func _pagina_listo() -> String:
	var s := _chip_nivel() + "\n"
	if _hay_modelo:
		var rapidez := _vel0.length()
		var angulo := fposmod(rad_to_deg(atan2(-_vel0.y, _vel0.x)), 360.0)
		s += "Estos son los valores con los que vas a disparar:\n"
		s += _eq(
			"|v0| = " + _n(rapidez, 1) + " px/s      ángulo = " + _n(angulo, 1) + "°\n"
			+ "v0 = (" + _n(_vel0.x, 1) + ", " + _n(_vel0.y, 1) + ") px/s",
			13
		)
	else:
		s += "[i]Esperando las condiciones del disparo...[/i]\n"

	s += "• Más potencia → más rapidez y más alcance.\n"
	s += "• Con la misma potencia, un ángulo cercano a 45° aprovecha mejor el alcance; "
	s += "subir el ángulo gana altura.\n"
	if es_matrices():
		s += "• El aire frena el slime: cuanto más dura el vuelo, más se curva la trayectoria.\n\n"
	else:
		s += "• El aire frena el slime: cuanto más dura el vuelo, más se separa de la parábola ideal.\n\n"
	s += "El cronómetro aún no corre: arranca al pulsar COMENZAR NIVEL."
	return s


func _eq(texto: String, tamano: int = 16) -> String:
	var tinta := EQ_TINTA_MATRICES if es_matrices() else EQ_TINTA_PARABOLA
	var fondo := EQ_FONDO_MATRICES if es_matrices() else EQ_FONDO_PARABOLA
	var s := "\n[center][font_size=" + str(tamano) + "][color=" + tinta + "]"
	s += "[bgcolor=" + fondo + "][b]" + texto + "[/b][/bgcolor][/color][/font_size][/center]\n"
	return s


func _chip_nivel() -> String:
	if es_matrices():
		return (
			"[center][color=#123A56][bgcolor=#CFE6F5][b]"
			+ "  NIVEL 2 · TIRO CON AIRE  "
			+ "[/b][/bgcolor][/color][/center]\n"
		)
	return (
		"[center][color=#24420F][bgcolor=#D8EBB0][b]"
		+ "  NIVEL 1 · TIRO IDEAL  "
		+ "[/b][/bgcolor][/color][/center]\n"
	)


func _n(valor: float, decimales: int = 2) -> String:
	return String.num(valor, decimales)

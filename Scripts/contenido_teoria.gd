class_name ContenidoTeoria
extends RefCounted
## Textos de las tarjetas "¿Sabías que…?". Cada tarjeta es una lista de páginas
## { "titulo": String, "texto": String con BBCode }.
## Para cambiar o añadir teoría basta con editar este archivo.

const Resortera := preload("res://Scripts/slingshoot.gd")

# ---------------------------------------------------------------------------
# Tarjetas al iniciar cada nivel
# ---------------------------------------------------------------------------

## Páginas de introducción del nivel con identificador `id` ("jungla", "hielo", ...).
static func intro(id: String) -> Array[Dictionary]:
	match id:
		"hielo":
			return _intro_hielo()
		_:
			return _intro_jungla()

static func _intro_jungla() -> Array[Dictionary]:
	var g := Unidades.num(Unidades.gravedad())
	var k := Unidades.num(Unidades.arrastre())
	return [
		{
			"titulo": "¿Sabías que tu salto es una ecuación diferencial?",
			"texto": (
				"Cuando sueltas la resortera, el slime obedece la segunda ley de Newton. "
				+ "En el juego se escribe así:\n\n"
				+ "[center][b]dx/dt = v          dv/dt = g − k·v[/b][/center]\n\n"
				+ "• [b]g = %s m/s²[/b]: la gravedad, siempre hacia abajo.\n" % g
				+ "• [b]k = %s s⁻¹[/b]: la resistencia del aire; frena más cuanto más rápido vas.\n\n" % k
				+ "Es una [b]EDO[/b] (ecuación diferencial ordinaria): no dice dónde estará el slime, "
				+ "sino cómo [i]cambia[/i] su movimiento en cada instante. Para saber dónde estará "
				+ "hay que resolverla."
			),
		},
		{
			"titulo": "¿Cómo la resuelve el juego? Con Runge-Kutta 4",
			"texto": (
				"El juego avanza en pasos pequeños de tiempo [b]Δt[/b]. En cada paso, RK4 mide la "
				+ "pendiente (la velocidad) en cuatro lugares:\n\n"
				+ _color_k(0, "k1") + ": al inicio del paso.\n"
				+ _color_k(1, "k2") + ": a mitad del paso, avanzando con k1.\n"
				+ _color_k(2, "k3") + ": a mitad del paso, avanzando con k2.\n"
				+ _color_k(3, "k4") + ": al final del paso, avanzando con k3.\n\n"
				+ "Y avanza con su promedio ponderado:\n"
				+ "[center][b]x(n+1) = x(n) + Δt · (k1 + 2k2 + 2k3 + k4) / 6[/b][/center]\n\n"
				+ "Las pendientes del medio pesan el doble porque representan mejor todo el intervalo."
			),
		},
		{
			"titulo": "¿Qué estás viendo en pantalla?",
			"texto": (
				"• Los [b]15 puntos blancos[/b] son 15 pasos de RK4 con Δt = 0.08 s: "
				+ "la predicción de 1.2 s de vuelo.\n"
				+ "• El [b]panel[/b] de la esquina muestra lo que RK4 predice: altura máxima, "
				+ "alcance y tiempo de vuelo, en metros y segundos.\n"
				+ "• Pulsa [b]K[/b] (o el botón del panel) para ver las flechas k1…k4 de un paso. "
				+ "Con [b]Q / E[/b] o la [b]rueda del ratón[/b] eliges cuál paso, mientras apuntas.\n"
				+ "• Después de cada tiro, los [color=#5af2ff]puntos celestes[/color] muestran por dónde "
				+ "pasó el slime de verdad. Si caen dentro de los cuadritos blancos, RK4 acertó.\n"
				+ "• El botón [b]¿Cómo se calculó?[/b] te explica tu último salto con sus números."
			),
		},
	]

static func _intro_hielo() -> Array[Dictionary]:
	var g := Unidades.gravedad()
	var k := Unidades.arrastre()
	return [
		{
			"titulo": "¿Sabías que los puntos no están igual de separados?",
			"texto": (
				"Todos los puntos de la predicción están separados por el [b]mismo tiempo[/b] "
				+ "(Δt = 0.08 s), pero no por la misma distancia.\n\n"
				+ "• En [b]vertical[/b], la gravedad cambia la velocidad: cerca de la cima el slime "
				+ "casi no sube, así que los puntos se juntan; al caer se vuelven a separar.\n"
				+ "• En [b]horizontal[/b] solo frena el aire, muy poco: vx se reduce como e^(−k·t). "
				+ "Por eso los puntos avanzan hacia el lado casi al mismo ritmo.\n\n"
				+ "Fíjate en eso la próxima vez que apuntes."
			),
		},
		{
			"titulo": "Si existe una fórmula, ¿para qué RK4?",
			"texto": (
				"Sin aire, el tiro tiene fórmula cerrada, la parábola:\n"
				+ "[center][b]y = x·tan θ − g·x² / (2·v₀²·cos² θ)[/b][/center]\n"
				+ "Con aire (k > 0) la curva ya no es una parábola perfecta: baja más empinada de "
				+ "lo que sube. Para este modelo sencillo todavía hay solución exacta, y el panel la "
				+ "usa para medir el error de RK4: [b]menos de 0.1 mm[/b].\n\n"
				+ "Pero si el modelo se complica (aire proporcional a v², viento, rebotes…) ya no hay "
				+ "fórmula, y métodos como RK4 son la forma de predecir el movimiento."
			),
		},
		{
			"titulo": "¿Sabías que RK4 es de orden 4?",
			"texto": (
				"El error de RK4 se comporta como [b]Δt⁴[/b]: si divides el paso a la mitad, "
				+ "el error total se reduce unas [b]2⁴ = 16 veces[/b].\n\n"
				+ "Por eso basta con 15 pasos de 0.08 s para que la predicción sea casi exacta, "
				+ "mientras que el slime real se mueve con pasos de 1/60 s.\n\n"
				+ "Dato: la velocidad máxima que podría alcanzar el slime cayendo (velocidad "
				+ "terminal) es g / k = %s m/s. Nunca llega a ella en estos saltos cortos." % Unidades.num(g / k, 0)
			),
		},
	]

# ---------------------------------------------------------------------------
# Tarjeta "¿Cómo se calculó este salto?" (con los números del último tiro)
# ---------------------------------------------------------------------------

static func explicacion_tiro(d: Dictionary, r: Dictionary) -> Array[Dictionary]:
	var v0: Vector2 = Unidades.vec(d["v0"])
	var theta := Unidades.angulo_grados(d["v0"])
	var g := Unidades.m(d["gravedad"])
	var k: float = d["k"]
	var ax := -k * v0.x
	var ay := -g - k * v0.y
	var e: Dictionary = d["primer_paso"]
	var kp: Array = e["kp"]
	var avance := Unidades.vec(e["pos_nueva"] - e["pos"])
	var pred: Dictionary = d["prediccion"]

	var p1 := (
		"Al soltar, la resortera le dio al slime:\n"
		+ "• [b]v₀ = %s m/s[/b] con un ángulo [b]θ = %d°[/b]\n" % [Unidades.num(v0.length()), roundi(theta)]
		+ "• vx = v₀·cos θ = [b]%s m/s[/b]\n" % Unidades.num(v0.x)
		+ "• vy = v₀·sen θ = [b]%s m/s[/b]\n\n" % Unidades.num(v0.y)
		+ "Con esa velocidad, la EDO da la aceleración en t = 0:\n"
		+ "• ax = −k·vx = −%s·%s = [b]%s m/s²[/b]\n" % [Unidades.num(k), Unidades.num(v0.x), Unidades.num(ax)]
		+ "• ay = −g − k·vy = −%s − %s·%s = [b]%s m/s²[/b]\n\n" % [
			Unidades.num(g), Unidades.num(k), Unidades.num(v0.y), Unidades.num(ay)]
		+ "La gravedad domina: el aire apenas cambia la aceleración en estos saltos."
	)

	var p2 := "Con Δt = %s s, RK4 calcula cuatro pendientes (velocidades, en m/s):\n\n" % Unidades.num(d["dt"])
	for i in 4:
		p2 += _color_k(i, "k%d = %s" % [i + 1, _par(Unidades.vec(kp[i]))]) + "\n"
	p2 += (
		"\n[color=#%s]promedio = (k1 + 2k2 + 2k3 + k4) / 6 = %s[/color]\n\n" % [
			Resortera.COLOR_PROMEDIO.to_html(false), _par(Unidades.vec(e["pendiente_p"]))]
		+ "Avance en el primer paso = Δt · promedio = [b]%s m[/b]\n\n" % _par(avance, 3)
		+ "Ese cálculo se repitió %d veces para dibujar la predicción, y [b]%d veces por segundo[/b] "
		% [d["n"], roundi(1.0 / d["dt_motor"])]
		+ "para mover al slime de verdad."
	)

	var p3 := "Lo que predijo RK4 frente a lo que pasó en el vuelo:\n\n"
	if pred["sube"]:
		var h_pred := Unidades.num(Unidades.m(pred["altura_max"]))
		if r["cima_valida"]:
			p3 += "• Altura máxima: predicha [b]%s m[/b] · real [b]%s m[/b]\n" % [
				h_pred, Unidades.num(Unidades.m(r["altura_real"]))]
		else:
			p3 += "• Altura máxima predicha: [b]%s m[/b]. El slime no llegó libre a la cima.\n" % h_pred
		if pred["completo"]:
			var a_pred := Unidades.num(Unidades.m(pred["alcance"]))
			var t_pred := Unidades.num(pred["tiempo"])
			if r["caida_valida"]:
				p3 += "• Alcance: predicho [b]%s m[/b] · real [b]%s m[/b]\n" % [
					a_pred, Unidades.num(Unidades.m(r["alcance_real"]))]
				p3 += "• Tiempo de vuelo: predicho [b]%s s[/b] · real [b]%s s[/b]\n" % [
					t_pred, Unidades.num(r["tiempo_real"])]
			else:
				p3 += "• Alcance predicho: [b]%s m[/b] en [b]%s s[/b]. " % [a_pred, t_pred]
				p3 += "El vuelo real se cortó antes de volver a la altura de lanzamiento.\n"
	else:
		p3 += "• Fue un tiro hacia abajo: no hay altura máxima ni alcance que comparar.\n"
	if r["se_desvio"]:
		p3 += "• A los [b]%s s[/b] el slime chocó, rebotó en un borde o se pegó: " % Unidades.num(r["t_desvio"])
		p3 += "desde ahí ya no es vuelo libre.\n"
	else:
		p3 += "• El slime voló libre todo el tiempo: siguió la predicción de RK4 punto por punto.\n"
	p3 += "• Error de RK4 frente a la solución exacta (a los %s s): [b]%s[/b]\n\n" % [
		Unidades.num(d["dt"] * d["n"], 1), PanelTiro.texto_error(d["error_px"])]
	p3 += "\nRK4 predice el [i]vuelo libre[/i]: lo que pasaría si nada se interpone en el camino."

	return [
		{"titulo": "¿Cómo se calculó este salto? (1/3)", "texto": p1},
		{"titulo": "El primer paso de RK4 (2/3)", "texto": p2},
		{"titulo": "Predicción vs. realidad (3/3)", "texto": p3},
	]

# ---------------------------------------------------------------------------
# Datos curiosos para la pantalla de victoria
# ---------------------------------------------------------------------------

const DATOS_CURIOSOS: Array[String] = [
	"RK4 lo publicaron Carl Runge (1895) y Wilhelm Kutta (1901), mucho antes de que existieran los computadores.",
	"Los simuladores de vuelo y de órbitas usan métodos de la familia Runge-Kutta para predecir trayectorias.",
	"Sin aire, el mayor alcance se logra a 45°, y 30° y 60° llegan al mismo punto. Con aire, el mejor ángulo es un poco menor.",
	"En cada segundo de vuelo, el juego calcula 60 pasos de RK4, es decir, 240 evaluaciones de la EDO.",
	"Si duplicas el paso Δt, el error de RK4 crece unas 16 veces: por eso el tamaño del paso importa tanto.",
]

static func dato_curioso() -> String:
	return DATOS_CURIOSOS[randi() % DATOS_CURIOSOS.size()]

# ---------------------------------------------------------------------------

static func _color_k(i: int, texto: String) -> String:
	return "[color=#%s][b]%s[/b][/color]" % [Resortera.COLORES_K[i].to_html(false), texto]

static func _par(v: Vector2, decimales: int = 2) -> String:
	return "(%s, %s)" % [Unidades.num(v.x, decimales), Unidades.num(v.y, decimales)]

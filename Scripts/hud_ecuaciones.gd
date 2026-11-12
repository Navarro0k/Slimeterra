class_name HudEcuaciones
extends RefCounted
## Texto BBCode del panel de ecuaciones del HUD, con la paleta de la cartilla.

const _RESET := "[/color]"


static func _c(color: Color) -> String:
	return "[color=#%s]" % color.to_html(false)


static func texto(modo: String, posicion: Vector2, velocidad: Vector2, gravedad: float, amortiguamiento: float) -> String:
	if modo == "matrices":
		return _espacio_de_estados(posicion, velocidad, gravedad, amortiguamiento)
	return _parabola(posicion, velocidad, gravedad)


static func _espacio_de_estados(posicion: Vector2, velocidad: Vector2, gravedad: float, amortiguamiento: float) -> String:
	var tinta := _c(HudTema.TINTA_FUERTE)
	var suave := _c(HudTema.TINTA_SUAVE)
	var valor := _c(HudTema.AZUL)
	var s := ""
	s += suave + "s  = [ x  y  vx  vy ]^T" + _RESET + "\n"
	s += valor + "s0 = [%.0f  %.0f  %.0f  %.0f]^T" % [posicion.x, posicion.y, velocidad.x, velocidad.y] + _RESET + "\n"
	s += tinta + "s' = A s + b" + _RESET + "\n"
	s += valor + "[b]A[/b] = [ 0  0  1  0 ]\n    [ 0  0  0  1 ]\n    [ 0  0 -k  0 ]\n    [ 0  0  0 -k ]" + _RESET + "\n"
	s += valor + "[b]b[/b] = [ 0  0  0  g ]^T" + _RESET + "\n"
	s += suave + "k=%.2f   g=%.0f" % [amortiguamiento, gravedad] + _RESET
	return s


static func _parabola(posicion: Vector2, velocidad: Vector2, gravedad: float) -> String:
	var tinta := _c(HudTema.TINTA_FUERTE)
	var suave := _c(HudTema.TINTA_SUAVE)
	var valor := _c(HudTema.AZUL)
	var s := ""
	var modelo: Dictionary = SolverNumerico.ecuacion_parabolica(posicion, velocidad, gravedad)
	s += tinta + "y(x) = a x² + b x + c" + _RESET + "\n"
	if bool(modelo.get("valida", false)):
		var a: float = float(modelo["a"])
		var b: float = float(modelo["b"])
		var c: float = float(modelo["c"])
		s += valor + "a = %.4f\nb = %.4f\nc = %.2f" % [a, b, c] + _RESET + "\n"
		s += tinta + "y(x) = %.4f x² %s %.4f x %s %.2f" % [a, "+" if b >= 0.0 else "-", absf(b), "+" if c >= 0.0 else "-", absf(c)] + _RESET
	else:
		s += suave + "Trayectoria casi vertical; no se expresa como y(x)." + _RESET
	return s

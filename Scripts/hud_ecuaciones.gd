class_name HudEcuaciones
extends RefCounted
## Texto BBCode del panel de ecuaciones del HUD.
## Muestra la matemática del nivel: parábola (cinemática) en el nivel 1, y el sistema
## lineal en espacio de estados (matrices) en el nivel 2, donde el amortiguamiento hace
## que el tiro ya no sea una parábola perfecta.


static func texto(modo: String, posicion: Vector2, velocidad: Vector2, gravedad: float, amortiguamiento: float) -> String:
	if modo == "matrices":
		return _espacio_de_estados(posicion, velocidad, gravedad, amortiguamiento)
	return _parabola(posicion, velocidad, gravedad)


static func _espacio_de_estados(posicion: Vector2, velocidad: Vector2, gravedad: float, amortiguamiento: float) -> String:
	var texto := ""
	texto += "[color=#FFFFFF][b]Espacio de estados[/b][/color]\n"
	texto += "[color=#A6B8D0]s  = [ x  y  vx  vy ]^T[/color]\n"
	texto += "[color=#62D9C7]s0 = [%.0f  %.0f  %.0f  %.0f]^T[/color]\n" % [posicion.x, posicion.y, velocidad.x, velocidad.y]
	texto += "[color=#FFFFFF]s' = A s + b[/color]\n"
	texto += "[color=#62D9C7][b]A[/b] = [ 0  0  1  0 ]\n    [ 0  0  0  1 ]\n    [ 0  0 -k  0 ]\n    [ 0  0  0 -k ][/color]\n"
	texto += "[color=#62D9C7][b]b[/b] = [ 0  0  0  g ]^T[/color]\n"
	texto += "[color=#A6B8D0]k=%.2f   g=%.0f[/color]" % [amortiguamiento, gravedad]
	return texto


static func _parabola(posicion: Vector2, velocidad: Vector2, gravedad: float) -> String:
	var texto := ""
	var modelo: Dictionary = SolverNumerico.ecuacion_parabolica(posicion, velocidad, gravedad)
	texto += "[color=#FFFFFF]y(x) = a x² + b x + c[/color]\n"
	if bool(modelo.get("valida", false)):
		var a: float = float(modelo["a"])
		var b: float = float(modelo["b"])
		var c: float = float(modelo["c"])
		texto += "[color=#62D9C7]a = %.4f\nb = %.4f\nc = %.2f[/color]\n" % [a, b, c]
		texto += "[color=#FFFFFF]y(x) = %.4f x² %s %.4f x %s %.2f[/color]" % [a, "+" if b >= 0.0 else "-", absf(b), "+" if c >= 0.0 else "-", absf(c)]
	else:
		texto += "[color=#A6B8D0]Trayectoria casi vertical; no se expresa como y(x).[/color]"
	return texto

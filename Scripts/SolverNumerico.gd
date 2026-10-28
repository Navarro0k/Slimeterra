class_name SolverNumerico
extends RefCounted

enum Metodo { EULER, EULER_MEJORADO, RK4 }


## Aceleración del sistema: a(p, v) = g - k*v
static func aceleracion(_pos: Vector2, vel: Vector2, gravedad: float, k: float) -> Vector2:
	return Vector2(0.0, gravedad) - vel * k


## Un solo paso de integración. Devuelve [nueva_pos, nueva_vel].
static func paso(metodo: Metodo, pos: Vector2, vel: Vector2, dt: float, gravedad: float, k: float) -> Array:
	match metodo:
		Metodo.EULER:
			# y_{n+1} = y_n + h * f(y_n)          (orden 1)
			var a: Vector2 = aceleracion(pos, vel, gravedad, k)
			return [pos + vel * dt, vel + a * dt]

		Metodo.EULER_MEJORADO:
			# Heun: promedia la pendiente al inicio y al final (orden 2)
			var a1: Vector2 = aceleracion(pos, vel, gravedad, k)
			var pos_pred: Vector2 = pos + vel * dt
			var vel_pred: Vector2 = vel + a1 * dt
			var a2: Vector2 = aceleracion(pos_pred, vel_pred, gravedad, k)
			return [
				pos + (vel + vel_pred) * 0.5 * dt,
				vel + (a1 + a2) * 0.5 * dt,
			]

		_:  # Metodo.RK4 (orden 4)
			var e: Dictionary = etapas_rk4(pos, vel, dt, gravedad, k)
			return [e["pos_nueva"], e["vel_nueva"]]


## Un paso de RK4 devolviendo TODAS sus etapas, para poder enseñarlas en pantalla.
## Las k*p son pendientes de la posición (velocidades) y las k*v pendientes de la velocidad
## (aceleraciones). Los puntos_eval son las posiciones donde se evaluó cada pendiente:
##   k1 al inicio, k2 y k3 a mitad del paso, k4 al final.
static func etapas_rk4(pos: Vector2, vel: Vector2, dt: float, gravedad: float, k: float) -> Dictionary:
	var k1p: Vector2 = vel
	var k1v: Vector2 = aceleracion(pos, vel, gravedad, k)

	var p2: Vector2 = pos + k1p * (dt * 0.5)
	var k2p: Vector2 = vel + k1v * (dt * 0.5)
	var k2v: Vector2 = aceleracion(p2, k2p, gravedad, k)

	var p3: Vector2 = pos + k2p * (dt * 0.5)
	var k3p: Vector2 = vel + k2v * (dt * 0.5)
	var k3v: Vector2 = aceleracion(p3, k3p, gravedad, k)

	var p4: Vector2 = pos + k3p * dt
	var k4p: Vector2 = vel + k3v * dt
	var k4v: Vector2 = aceleracion(p4, k4p, gravedad, k)

	var pendiente_p: Vector2 = (k1p + k2p * 2.0 + k3p * 2.0 + k4p) / 6.0
	var pendiente_v: Vector2 = (k1v + k2v * 2.0 + k3v * 2.0 + k4v) / 6.0
	return {
		"pos": pos, "vel": vel, "dt": dt,
		"kp": [k1p, k2p, k3p, k4p],
		"kv": [k1v, k2v, k3v, k4v],
		"puntos_eval": [pos, p2, p3, p4],
		"pendiente_p": pendiente_p,
		"pendiente_v": pendiente_v,
		"pos_nueva": pos + pendiente_p * dt,
		"vel_nueva": vel + pendiente_v * dt,
	}


## Etapas del paso número `indice` (0 = primer paso) de una trayectoria RK4.
static func etapas_en_paso(
		pos0: Vector2, vel0: Vector2, gravedad: float, k: float, dt: float, indice: int
) -> Dictionary:
	var pos := pos0
	var vel := vel0
	for i in range(indice):
		var r: Array = paso(Metodo.RK4, pos, vel, dt, gravedad, k)
		pos = r[0]
		vel = r[1]
	return etapas_rk4(pos, vel, dt, gravedad, k)


## Predice con RK4 las magnitudes clásicas del tiro parabólico (en píxeles y segundos):
##   altura_max  -> cuánto sube por encima del punto de lanzamiento
##   alcance     -> distancia horizontal al volver a la altura de lanzamiento
##   tiempo      -> tiempo de vuelo hasta volver a esa altura
##   t_cima      -> instante en que la velocidad vertical se hace cero
## Usa el mismo paso dt que el motor de física para que coincida con el vuelo real.
## Si el tiro no sube (sale horizontal o hacia abajo), "sube" es false y no hay alcance.
static func predecir_tiro(
		pos0: Vector2, vel0: Vector2, gravedad: float, k: float,
		dt: float = 1.0 / 60.0, t_max: float = 15.0
) -> Dictionary:
	var resultado := {
		"sube": vel0.y < 0.0, "altura_max": 0.0, "punto_cima": pos0, "t_cima": 0.0,
		"alcance": 0.0, "tiempo": 0.0, "punto_caida": pos0, "completo": false,
	}
	if not resultado["sube"]:
		return resultado

	var pos := pos0
	var vel := vel0
	var t := 0.0
	while t < t_max:
		var r: Array = paso(Metodo.RK4, pos, vel, dt, gravedad, k)
		var pos_n: Vector2 = r[0]
		var vel_n: Vector2 = r[1]
		var t_n := t + dt

		# Cima: la velocidad vertical cambia de signo (en Godot "subir" es y negativa).
		if vel.y < 0.0 and vel_n.y >= 0.0:
			var f := -vel.y / (vel_n.y - vel.y)
			var cima := pos.lerp(pos_n, f)
			resultado["punto_cima"] = cima
			resultado["altura_max"] = pos0.y - cima.y
			resultado["t_cima"] = t + f * dt

		# Caída: vuelve a cruzar la altura de lanzamiento bajando.
		if vel_n.y > 0.0 and pos.y < pos0.y and pos_n.y >= pos0.y:
			var f := (pos0.y - pos.y) / (pos_n.y - pos.y)
			var caida := pos.lerp(pos_n, f)
			resultado["punto_caida"] = caida
			resultado["alcance"] = absf(caida.x - pos0.x)
			resultado["tiempo"] = t + f * dt
			resultado["completo"] = true
			return resultado

		pos = pos_n
		vel = vel_n
		t = t_n
	return resultado


## Calcula 'pasos' puntos de la trayectoria (sin incluir el punto inicial).
static func trayectoria(
		pos0: Vector2, vel0: Vector2, gravedad: float, k: float,
		dt: float, pasos: int, metodo: Metodo = Metodo.RK4
) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	var pos := pos0
	var vel := vel0
	for i in range(pasos):
		var r: Array = paso(metodo, pos, vel, dt, gravedad, k)
		pos = r[0]
		vel = r[1]
		puntos.append(pos)
	return puntos


static func solucion_exacta(pos0: Vector2, vel0: Vector2, gravedad: float, k: float, t: float) -> Vector2:
	var g := Vector2(0.0, gravedad)
	if k < 0.00001:
		return pos0 + vel0 * t + g * (0.5 * t * t)
	var vt: Vector2 = g / k
	return pos0 + vt * t + (vel0 - vt) * ((1.0 - exp(-k * t)) / k)


## Error (en píxeles) de un método al tiempo t = dt * pasos, comparado con la solución exacta.
static func error_en(
		metodo: Metodo, pos0: Vector2, vel0: Vector2, gravedad: float, k: float,
		dt: float, pasos: int
) -> float:
	var puntos := trayectoria(pos0, vel0, gravedad, k, dt, pasos, metodo)
	var exacta := solucion_exacta(pos0, vel0, gravedad, k, dt * pasos)
	return puntos[pasos - 1].distance_to(exacta)


## Aplica una matriz de rotación 2D a un vector de velocidad o posición 
## usando un ángulo en radianes.
static func aplicar_matriz_rotacion(vector: Vector2, angulo_radianes: float) -> Vector2:
	var cos_a = cos(angulo_radianes)
	var sin_a = sin(angulo_radianes)
	
	var x_rotado = vector.x * cos_a - vector.y * sin_a
	var y_rotado = vector.x * sin_a + vector.y * cos_a
	
	return Vector2(x_rotado, y_rotado)

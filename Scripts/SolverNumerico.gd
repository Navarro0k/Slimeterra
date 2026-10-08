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
			var k1p: Vector2 = vel
			var k1v: Vector2 = aceleracion(pos, vel, gravedad, k)

			var k2p: Vector2 = vel + k1v * (dt * 0.5)
			var k2v: Vector2 = aceleracion(pos + k1p * (dt * 0.5), k2p, gravedad, k)

			var k3p: Vector2 = vel + k2v * (dt * 0.5)
			var k3v: Vector2 = aceleracion(pos + k2p * (dt * 0.5), k3p, gravedad, k)

			var k4p: Vector2 = vel + k3v * dt
			var k4v: Vector2 = aceleracion(pos + k3p * dt, k4p, gravedad, k)

			return [
				pos + (k1p + k2p * 2.0 + k3p * 2.0 + k4p) * (dt / 6.0),
				vel + (k1v + k2v * 2.0 + k3v * 2.0 + k4v) * (dt / 6.0),
			]


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
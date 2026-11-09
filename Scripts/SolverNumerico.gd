class_name SolverNumerico
extends RefCounted
## Integrador RK4 y utilidades de trayectoria.


## Aceleración del sistema: a(p, v) = g - k*v
static func aceleracion(_pos: Vector2, vel: Vector2, gravedad: float, k: float) -> Vector2:
	return Vector2(0.0, gravedad) - vel * k


## Un paso de Runge-Kutta 4. Devuelve [nueva_pos, nueva_vel].
static func paso(pos: Vector2, vel: Vector2, dt: float, gravedad: float, k: float) -> Array:
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


## Calcula 'pasos' puntos de la trayectoria (sin incluir el inicial).
static func trayectoria(
		pos0: Vector2, vel0: Vector2, gravedad: float, k: float,
		dt: float, pasos: int
) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	var pos := pos0
	var vel := vel0
	for i in range(pasos):
		var r: Array = paso(pos, vel, dt, gravedad, k)
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


## Error (px) de RK4 al tiempo t = dt * pasos frente a la solución exacta.
static func error_en(
		pos0: Vector2, vel0: Vector2, gravedad: float, k: float,
		dt: float, pasos: int
) -> float:
	var puntos := trayectoria(pos0, vel0, gravedad, k, dt, pasos)
	var exacta := solucion_exacta(pos0, vel0, gravedad, k, dt * pasos)
	return puntos[pasos - 1].distance_to(exacta)


## Aplica una matriz de rotación 2D usando un ángulo en radianes.
static func aplicar_matriz_rotacion(vector: Vector2, angulo_radianes: float) -> Vector2:
	var cos_a = cos(angulo_radianes)
	var sin_a = sin(angulo_radianes)

	var x_rotado = vector.x * cos_a - vector.y * sin_a
	var y_rotado = vector.x * sin_a + vector.y * cos_a

	return Vector2(x_rotado, y_rotado)


## Ecuación parabólica y(x) = a x² + b x + c para tiro sin amortiguamiento.
static func ecuacion_parabolica(posicion_inicial: Vector2, velocidad_inicial: Vector2, gravedad: float) -> Dictionary:
	if absf(velocidad_inicial.x) < 0.0001:
		return {"valida": false}
	var pendiente: float = velocidad_inicial.y / velocidad_inicial.x
	var a: float = gravedad / (2.0 * velocidad_inicial.x * velocidad_inicial.x)
	var b: float = pendiente - 2.0 * a * posicion_inicial.x
	var c: float = posicion_inicial.y - pendiente * posicion_inicial.x + a * posicion_inicial.x * posicion_inicial.x
	return {"valida": true, "a": a, "b": b, "c": c, "vx": velocidad_inicial.x, "vy": velocidad_inicial.y}

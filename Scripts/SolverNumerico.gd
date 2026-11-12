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
	for _i in range(maxi(pasos, 0)):
		var r: Array = paso(pos, vel, dt, gravedad, k)
		pos = r[0]
		vel = r[1]
		puntos.append(pos)
	return puntos


## Ecuación parabólica y(x) = a x² + b x + c para tiro sin amortiguamiento.
static func ecuacion_parabolica(posicion_inicial: Vector2, velocidad_inicial: Vector2, gravedad: float) -> Dictionary:
	if absf(velocidad_inicial.x) < 0.0001:
		return {"valida": false}
	var pendiente: float = velocidad_inicial.y / velocidad_inicial.x
	var a: float = gravedad / (2.0 * velocidad_inicial.x * velocidad_inicial.x)
	var b: float = pendiente - 2.0 * a * posicion_inicial.x
	var c: float = posicion_inicial.y - pendiente * posicion_inicial.x + a * posicion_inicial.x * posicion_inicial.x
	return {"valida": true, "a": a, "b": b, "c": c, "vx": velocidad_inicial.x, "vy": velocidad_inicial.y}

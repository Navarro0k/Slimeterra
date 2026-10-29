class_name ModeloDisparo
extends RefCounted
## Modelo físico desacoplado de la interfaz.
## Coordenadas de Godot: X positiva a la derecha y Y positiva hacia abajo.

static func aceleracion(velocidad: Vector2, gravedad: float, amortiguamiento: float) -> Vector2:
	return Vector2(0.0, gravedad) - velocidad * amortiguamiento

static func paso_rk4(posicion: Vector2, velocidad: Vector2, dt: float, gravedad: float, k: float) -> Array:
	var k1p: Vector2 = velocidad
	var k1v: Vector2 = aceleracion(velocidad, gravedad, k)

	var k2p: Vector2 = velocidad + k1v * (dt * 0.5)
	var k2v: Vector2 = aceleracion(k2p, gravedad, k)

	var k3p: Vector2 = velocidad + k2v * (dt * 0.5)
	var k3v: Vector2 = aceleracion(k3p, gravedad, k)

	var k4p: Vector2 = velocidad + k3v * dt
	var k4v: Vector2 = aceleracion(k4p, gravedad, k)

	var nueva_posicion: Vector2 = posicion + (k1p + 2.0 * k2p + 2.0 * k3p + k4p) * (dt / 6.0)
	var nueva_velocidad: Vector2 = velocidad + (k1v + 2.0 * k2v + 2.0 * k3v + k4v) * (dt / 6.0)
	return [nueva_posicion, nueva_velocidad]

static func trayectoria(posicion_inicial: Vector2, velocidad_inicial: Vector2, gravedad: float, k: float, dt: float, pasos: int) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	var posicion := posicion_inicial
	var velocidad := velocidad_inicial
	for i in range(maxi(1, pasos)):
		var estado: Array = paso_rk4(posicion, velocidad, dt, gravedad, k)
		posicion = estado[0]
		velocidad = estado[1]
		puntos.append(posicion)
	return puntos

static func ecuacion_parabolica(posicion_inicial: Vector2, velocidad_inicial: Vector2, gravedad: float) -> Dictionary:
	# La ecuación está expresada en coordenadas de pantalla (Y hacia abajo).
	if absf(velocidad_inicial.x) < 0.0001:
		return {"valida": false}
	var pendiente: float = velocidad_inicial.y / velocidad_inicial.x
	var a: float = gravedad / (2.0 * velocidad_inicial.x * velocidad_inicial.x)
	var b: float = pendiente - 2.0 * a * posicion_inicial.x
	var c: float = posicion_inicial.y - pendiente * posicion_inicial.x + a * posicion_inicial.x * posicion_inicial.x
	return {"valida": true, "a": a, "b": b, "c": c, "vx": velocidad_inicial.x, "vy": velocidad_inicial.y}

static func posicion_exacta(posicion_inicial: Vector2, velocidad_inicial: Vector2, tiempo: float, gravedad: float, k: float) -> Vector2:
	var g := Vector2(0.0, gravedad)
	if absf(k) < 0.00001:
		return posicion_inicial + velocidad_inicial * tiempo + g * (0.5 * tiempo * tiempo)
	var velocidad_terminal: Vector2 = g / k
	return posicion_inicial + velocidad_terminal * tiempo + (velocidad_inicial - velocidad_terminal) * ((1.0 - exp(-k * tiempo)) / k)

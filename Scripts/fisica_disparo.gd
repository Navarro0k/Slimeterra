class_name FisicaDisparo
extends RefCounted
## Parámetros físicos compartidos entre la vista previa y el slime real.


## Velocidad inicial (px/s) para un ángulo/potencia dados.
static func velocidad_inicial(angulo: float, potencia: float, desvio_grados: float, max_stretch: float, multiplicador_fuerza: float) -> Vector2:
	var theta := deg_to_rad(fposmod(angulo, 360.0) + desvio_grados)
	var intensidad := clampf(potencia, 0.0, 100.0) / 100.0
	return Vector2(cos(theta), -sin(theta)) * max_stretch * intensidad * multiplicador_fuerza


## Ángulo de salida (0..360) de un vector de velocidad, en coordenadas de pantalla.
static func angulo_grados(velocidad: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(-velocidad.y, velocidad.x)), 360.0)


static func gravedad() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


## Amortiguamiento que usa el slime (propio + global, o solo el propio).
static func arrastre(slime) -> float:
	if is_instance_valid(slime):
		var valor: Variant = slime.get("arrastre")
		if valor != null:
			return float(valor)
	return float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.0))


static func paso_fisica() -> float:
	return 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)


## Simula la trayectoria con el mismo RK4 del slime real.
## Devuelve { "puntos": Array[Vector2], "final": Vector2 }.
static func simular_trayectoria(slime, pos_inicial: Vector2, velocidad: Vector2, total_puntos: int, paso_tiempo: float) -> Dictionary:
	var dt := paso_fisica()
	var pasos_por_punto := maxi(1, roundi(paso_tiempo / dt))
	var pasos_totales := pasos_por_punto * maxi(total_puntos, 0)

	var todos := SolverNumerico.trayectoria(
		pos_inicial, velocidad, gravedad(), arrastre(slime), dt, pasos_totales
	)
	var puntos: Array[Vector2] = []
	for paso in range(todos.size()):
		if (paso + 1) % pasos_por_punto == 0:
			puntos.append(todos[paso])
	var final := pos_inicial if todos.is_empty() else todos[todos.size() - 1]
	return {"puntos": puntos, "final": final}

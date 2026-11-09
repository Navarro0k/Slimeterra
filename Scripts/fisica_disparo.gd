class_name FisicaDisparo
extends RefCounted
## Parámetros físicos compartidos entre la vista previa de la resortera y el slime real.
## Todo lo que influye en la trayectoria sale de AQUÍ, para que lo dibujado
## y lo simulado por slime.gd no puedan divergir.


## Velocidad inicial (px/s, coordenadas globales) para un ángulo/potencia dados.
static func velocidad_inicial(angulo: float, potencia: float, desvio_grados: float, max_stretch: float, multiplicador_fuerza: float) -> Vector2:
	var theta := deg_to_rad(fposmod(angulo, 360.0) + desvio_grados)
	var intensidad := clampf(potencia, 0.0, 100.0) / 100.0
	return Vector2(cos(theta), -sin(theta)) * max_stretch * intensidad * multiplicador_fuerza


static func gravedad() -> float:
	# slime.gd integra con esta misma configuración (ignora gravity_scale).
	return float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))


## Amortiguamiento que realmente usa el slime (linear_damp + global, o solo el propio).
static func arrastre(slime) -> float:
	if is_instance_valid(slime):
		var valor: Variant = slime.get("arrastre")
		if valor != null:
			return float(valor)
	return float(ProjectSettings.get_setting("physics/2d/default_linear_damp", 0.0))


## Paso de simulación real del motor de física (el mismo que recibe slime.gd en state.step).
static func paso_fisica() -> float:
	return 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)


## Simula la trayectoria con el mismo integrador RK4 que usa el slime real
## (con el amortiguamiento del `slime` dado, o el global si no es válido).
## Devuelve { "puntos": Array[Vector2], "final": Vector2 } en coordenadas globales:
## un punto cada `paso_tiempo` segundos, `total_puntos` en total.
static func simular_trayectoria(slime, pos_inicial: Vector2, velocidad: Vector2, total_puntos: int, paso_tiempo: float) -> Dictionary:
	var g := gravedad()
	var k := arrastre(slime)
	var dt := paso_fisica()
	var pasos_por_punto := maxi(1, roundi(paso_tiempo / dt))
	var pasos_totales := pasos_por_punto * total_puntos

	var pos := pos_inicial
	var vel := velocidad
	var puntos: Array[Vector2] = []
	for paso in range(pasos_totales):
		var r: Array = SolverNumerico.paso(pos, vel, dt, g, k)
		pos = r[0]
		vel = r[1]
		if (paso + 1) % pasos_por_punto == 0:
			puntos.append(pos)
	return {"puntos": puntos, "final": pos}

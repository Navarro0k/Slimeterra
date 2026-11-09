class_name SlimeLimites
extends RefCounted
## Rebote del slime contra el rectángulo de límites del nivel.


## Devuelve { "pos": Vector2, "vel": Vector2, "perdido": bool }.
## `perdido` es true si rebota en el suelo y sale demasiado lento.
static func rebotar(pos: Vector2, vel: Vector2, limites: Rect2, radio: float, rebote: float, velocidad_minima_suelo: float) -> Dictionary:
	var izquierda := limites.position.x + radio
	var derecha := limites.end.x - radio
	var arriba := limites.position.y + radio
	var abajo := limites.end.y - radio
	var perdido := false

	if pos.x < izquierda:
		pos.x = izquierda
		if vel.x < 0.0:
			vel.x = -vel.x * rebote
	elif pos.x > derecha:
		pos.x = derecha
		if vel.x > 0.0:
			vel.x = -vel.x * rebote

	if pos.y < arriba:
		pos.y = arriba
		if vel.y < 0.0:
			vel.y = -vel.y * rebote
	elif pos.y > abajo:
		pos.y = abajo
		if vel.y > 0.0:
			vel.y = -vel.y * rebote
		if absf(vel.y) < velocidad_minima_suelo:
			perdido = true

	return {"pos": pos, "vel": vel, "perdido": perdido}

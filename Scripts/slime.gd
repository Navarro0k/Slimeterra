extends RigidBody2D

func lanzar(vector_impulso: Vector2):
	apply_central_impulse(vector_impulso)
	print("Slime lanzado con fuerza: ", vector_impulso)

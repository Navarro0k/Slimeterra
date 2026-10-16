class_name Coin
extends Area2D

signal recolectada

var _ya_recolectada: bool = false

func _ready() -> void:
# Nos registramos en el grupo "monedas" para que el nivel sepa cuántas hay
	add_to_group("monedas")
	body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo: Node2D) -> void:
	if _ya_recolectada:
		return  
																											
		# Verificamos si lo que tocó la moneda es un slime (los slimes tienen la función "lanzar")
	if cuerpo.has_method("lanzar"):
		_recolectar()                                                                                               

func _recolectar() -> void:
	if _ya_recolectada:
		return
	_ya_recolectada = true

		# Desactivamos la colisión para no recolectarla dos veces
	$CollisionShape2D.set_deferred("disabled", true)

		# Avisamos que fue recolectada
	recolectada.emit()

		# Efecto visual: la moneda sube un poquito y se vuelve transparente suavemente
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 16.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
		# Cuando termina el efecto, se elimina de la escena
	tween.chain().tween_callback(queue_free)

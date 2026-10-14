class_name SlimeCatalogo
extends RefCounted
## Catálogo central de slimes: único lugar que conoce las escenas, iconos y nombres.
## El resto del código (nivel, resortera, UI) solo maneja el enum Tipo.
## Para añadir un slime nuevo: agregar el valor al enum y su entrada en DATOS.

enum Tipo { BASE, FUEGO }

const DATOS := {
	Tipo.BASE: {
		"nombre": "Base",
		"escena": preload("res://Scenes/slime.tscn"),
		"icono": preload("res://Assets/pngs/slime-base.png"),
	},
	Tipo.FUEGO: {
		"nombre": "Fuego",
		"escena": preload("res://Scenes/slime_fire.tscn"),
		"icono": preload("res://Assets/pngs/slime_fuego.png"),
	},
}

static func existe(tipo: int) -> bool:
	return DATOS.has(tipo)

static func escena(tipo: int) -> PackedScene:
	return DATOS[tipo]["escena"]

static func icono(tipo: int) -> Texture2D:
	return DATOS[tipo]["icono"]

static func nombre(tipo: int) -> String:
	return DATOS[tipo]["nombre"]

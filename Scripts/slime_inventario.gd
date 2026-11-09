class_name SlimeInventario
extends RefCounted
## Utilidad compartida para interpretar el inventario de slimes.


## Convierte { tipo: cantidad } en [{ "tipo": int, "cantidad": int }].
## Ignora tipos desconocidos y cantidades <= 0.
static func desde_diccionario(slimes: Dictionary) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for tipo in slimes:
		var cantidad := int(slimes[tipo])
		if cantidad <= 0:
			continue
		if not SlimeCatalogo.existe(tipo):
			push_warning("SlimeInventario: tipo de slime desconocido: %s" % str(tipo))
			continue
		resultado.append({"tipo": int(tipo), "cantidad": cantidad})
	return resultado

static func total(inventario: Array) -> int:
	var suma := 0
	for entrada in inventario:
		suma += int(entrada["cantidad"])
	return suma

## Índice de la primera entrada con munición, o -1 si no queda ninguna.
static func primer_con_stock(inventario: Array) -> int:
	for i in inventario.size():
		if inventario[i]["cantidad"] > 0:
			return i
	return -1

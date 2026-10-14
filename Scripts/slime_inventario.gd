class_name SlimeInventario
extends RefCounted
## Utilidad compartida por la resortera y la UI para que ambas interpreten
## el diccionario del nivel exactamente igual (mismo orden, mismos índices).

## Convierte { SlimeCatalogo.Tipo: cantidad } en una lista ordenada de entradas
## [{ "tipo": int, "cantidad": int }, ...] siguiendo el orden del diccionario.
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

## Total de slimes restantes en un inventario.
static func total(inventario: Array) -> int:
	var suma := 0
	for entrada in inventario:
		suma += int(entrada["cantidad"])
	return suma

#!/usr/bin/env python3
"""Añade el nodo Meta a Scenes/Levels/Level_Ice.tscn.
Uso (desde la raíz del proyecto):  python3 parchear_level_ice.py
Es seguro ejecutarlo dos veces: no duplica nada."""
import re, sys
RUTA = "Scenes/Levels/Level_Ice.tscn"
EXT = '[ext_resource type="PackedScene" path="res://Scenes/Meta.tscn" id="14_meta"]\n'
NODO = '\n[node name="Meta" parent="." instance=ExtResource("14_meta")]\nposition = Vector2(0, -440)\n'
try:
    t = open(RUTA, encoding="utf-8").read()
except FileNotFoundError:
    sys.exit("No encuentro " + RUTA + ". Ejecuta el script desde la raíz del proyecto.")
if "Scenes/Meta.tscn" in t:
    sys.exit("Level_Ice.tscn ya tiene la Meta. Nada que hacer.")
ultimo = list(re.finditer(r'^\[ext_resource [^\n]*\n', t, re.M))[-1]
t = t[:ultimo.end()] + EXT + t[ultimo.end():]
if not t.endswith("\n"):
    t += "\n"
t += NODO
open(RUTA, "w", encoding="utf-8", newline="\n").write(t)
print("Listo: Meta añadida en (0, -440). Muévela en el editor a donde quieras la llegada.")

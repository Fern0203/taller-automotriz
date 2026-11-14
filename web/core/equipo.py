"""
Datos del grupo. Editen SOLO este archivo para cambiar nombres, carnés o curso:
la página "Equipo", el login y el menú lateral los toman de aquí.
El logo va en: core/static/core/logo_universidad.png
"""

UNIVERSIDAD = "Universidad Mariano Gálvez de Guatemala"
CARRERA = "Ingeniería en Sistemas de Información"
CURSO = "Bases de Datos"
PROYECTO = "Sistema de Órdenes de Trabajo — Taller Automotriz"
CICLO = "Sexto semestre · 2026"

INTEGRANTES = [
    {"nombre": "Fernando José Batz Marroquín", "carne": "0903-23-463"},
    {"nombre": "Emerson Desaylí Orozco Salvador", "carne": "0903-24-16049"},
    {"nombre": "Harold Jose Gonzalez Ochoa", "carne": "0903-24-21104"},
    {"nombre": "José Daniel Fuentes García", "carne": "0903-23-7050"},
    {"nombre": "Darwin Danilo Castro Garcia", "carne": "0903-20-6780"},
]


def contexto_equipo(request):
    """Context processor: deja estos datos disponibles en todas las plantillas."""
    return {"equipo": {"universidad": UNIVERSIDAD, "carrera": CARRERA, "curso": CURSO,
                       "proyecto": PROYECTO, "ciclo": CICLO, "integrantes": INTEGRANTES}}

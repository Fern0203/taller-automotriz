from django.urls import path
from . import views

urlpatterns = [
    path("", views.inicio, name="inicio"),
    path("consulta/", views.consulta_publica, name="consulta"),

    path("clientes/", views.clientes, name="clientes"),
    path("clientes/nuevo/", views.cliente_nuevo, name="cliente_nuevo"),
    path("clientes/<int:idc>/", views.cliente_editar, name="cliente_editar"),
    path("clientes/<int:idc>/eliminar/", views.cliente_eliminar, name="cliente_eliminar"),
    path("clientes/<int:idc>/telefonos/<str:accion>/", views.telefono_accion, name="telefono_agregar"),
    path("clientes/<int:idc>/telefonos/<int:idt>/<str:accion>/", views.telefono_accion, name="telefono_accion"),
    path("clientes/<int:idc>/vehiculos/nuevo/", views.vehiculo_guardar, name="vehiculo_nuevo"),
    path("clientes/<int:idc>/vehiculos/<int:idv>/", views.vehiculo_guardar, name="vehiculo_editar"),
    path("clientes/<int:idc>/vehiculos/<int:idv>/eliminar/", views.vehiculo_eliminar, name="vehiculo_eliminar"),
    path("historial/", views.historial_vehiculo, name="historial"),

    path("ordenes/", views.ordenes, name="ordenes"),
    path("ordenes/nueva/", views.orden_nueva, name="orden_nueva"),
    path("ordenes/<int:ido>/", views.orden_detalle, name="orden_detalle"),
    path("ordenes/<int:ido>/imprimir/", views.orden_imprimir, name="orden_imprimir"),
    path("ordenes/<int:ido>/<str:accion>/", views.orden_accion, name="orden_accion"),

    path("catalogos/<str:nombre>/", views.catalogo, name="catalogo"),
    path("catalogos/<str:nombre>/<int:idx>/", views.catalogo, name="catalogo_editar"),

    path("reportes/", views.reportes, name="reportes"),
    path("equipo/", views.equipo, name="equipo"),
]

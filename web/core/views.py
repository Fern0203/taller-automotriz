"""
Vistas del sistema. Cada vista llama a SQL Server mediante core/db.py
usando consultas con INNER JOIN, vistas (vw_*) y procedimientos (sp_*).
"""
import re
from datetime import date
from itertools import groupby

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect, render

from .db import ErrorNegocio, consultar, ejecutar, procedimiento, uno


# ------------------------------------------------------------------ utilidades
def _texto(request, campo, requerido=False, largo=None):
    valor = request.POST.get(campo, "").strip()
    if requerido and not valor:
        raise ErrorNegocio(f"El campo «{campo}» es obligatorio.")
    if largo and len(valor) > largo:
        raise ErrorNegocio(f"El campo «{campo}» admite máximo {largo} caracteres.")
    return valor


def _numero(request, campo, tipo=int, minimo=0):
    try:
        valor = tipo(request.POST.get(campo, ""))
    except (TypeError, ValueError):
        raise ErrorNegocio(f"El campo «{campo}» debe ser numérico.")
    if valor < minimo:
        raise ErrorNegocio(f"El campo «{campo}» no puede ser menor que {minimo}.")
    return valor


def _opcional(request, campo):
    """Número entero opcional (select o campo vacío -> None)."""
    valor = request.POST.get(campo, "").strip()
    if not valor:
        return None
    if not valor.isdigit():
        raise ErrorNegocio(f"El campo «{campo}» debe ser numérico.")
    return int(valor)


def _telefono(request, campo="telefono", requerido=True):
    """Guarda solo dígitos (atomicidad): '5511-2233' -> '55112233'."""
    numero = re.sub(r"\D", "", request.POST.get(campo, ""))
    if requerido and not 8 <= len(numero) <= 15:
        raise ErrorNegocio("El teléfono debe tener entre 8 y 15 dígitos.")
    return numero


def _catalogos_cliente():
    """Opciones de los selects: municipios agrupados por departamento,
    modelos agrupados por marca y colores."""
    municipios = consultar("""SELECT m.IdMunicipio, m.Nombre, d.Nombre AS Departamento
                              FROM Municipio m INNER JOIN Departamento d ON d.IdDepartamento = m.IdDepartamento
                              ORDER BY d.IdDepartamento, m.Nombre""")
    modelos = consultar("""SELECT mo.IdModelo, mo.Nombre, ma.Nombre AS Marca
                           FROM Modelo mo INNER JOIN Marca ma ON ma.IdMarca = mo.IdMarca
                           ORDER BY ma.Nombre, mo.Nombre""")
    return {
        "municipios": [(k, list(g)) for k, g in groupby(municipios, key=lambda r: r["Departamento"])],
        "modelos": [(k, list(g)) for k, g in groupby(modelos, key=lambda r: r["Marca"])],
        "colores": consultar("SELECT * FROM Color ORDER BY Nombre"),
        "tipos_tel": ["Móvil", "Casa", "Trabajo"],
    }


def _datos_cliente(request):
    return [_texto(request, "nombres", True, 60), _texto(request, "apellidos", largo=60) or None,
            _texto(request, "nit", largo=15) or "CF", _texto(request, "correo", largo=100) or None,
            _texto(request, "calle", largo=100) or None, _opcional(request, "zona"),
            _opcional(request, "municipio")]


def _datos_vehiculo(request):
    return [_texto(request, "placa", True, 10).upper().replace("-", "").replace(" ", ""),
            _numero(request, "modelo", int, 1), _numero(request, "anio", int, 1950),
            _opcional(request, "color"), _numero(request, "kilometraje")]


def _eliminar(sql, idx, nombre):
    try:
        ejecutar(sql, [idx])
        return f"{nombre} eliminado."
    except ErrorNegocio:
        raise ErrorNegocio(f"No se puede eliminar: el {nombre.lower()} tiene registros relacionados.")


# ------------------------------------------------------------------ inicio
@login_required
def inicio(request):
    contexto = {
        "por_estado": consultar("""
            SELECT e.IdEstado, e.Nombre, COUNT(o.IdOrden) AS Cantidad
            FROM EstadoOrden e LEFT JOIN OrdenTrabajo o ON o.IdEstado = e.IdEstado
            GROUP BY e.IdEstado, e.Nombre, e.Secuencia ORDER BY e.Secuencia"""),
        "activas": consultar("""
            SELECT TOP 10 * FROM vw_OrdenesDetalle
            WHERE IdEstado IN (1,2,3,4) ORDER BY FechaIngreso"""),
        "carga": consultar("SELECT * FROM vw_CargaMecanicos ORDER BY OrdenesActivas DESC"),
        "ingreso_mes": uno("""
            SELECT ISNULL(SUM(Monto),0) AS Total, COUNT(*) AS Pagos FROM Pago
            WHERE YEAR(FechaPago)=YEAR(GETDATE()) AND MONTH(FechaPago)=MONTH(GETDATE())"""),
        "stock_bajo": uno("SELECT COUNT(*) AS N FROM Repuesto WHERE Stock <= StockMinimo")["N"],
    }
    return render(request, "core/inicio.html", contexto)


# ------------------------------------------------------------------ clientes
@login_required
def clientes(request):
    buscar = request.GET.get("q", "").strip()
    filas = consultar("""
        SELECT c.IdCliente, c.Nombre, c.NIT, c.Telefono, c.Correo, c.Municipio,
               COUNT(v.IdVehiculo) AS Vehiculos
        FROM vw_Cliente c LEFT JOIN Vehiculo v ON v.IdCliente = c.IdCliente
        WHERE c.Nombre LIKE %s OR c.NIT LIKE %s
           OR EXISTS (SELECT 1 FROM TelefonoCliente t WHERE t.IdCliente = c.IdCliente AND t.Numero LIKE %s)
        GROUP BY c.IdCliente, c.Nombre, c.Apellidos, c.Nombres, c.NIT, c.Telefono, c.Correo, c.Municipio
        ORDER BY c.Apellidos, c.Nombres""", [f"%{buscar}%"] * 3)
    return render(request, "core/clientes.html", {"clientes": filas, "q": buscar})


@login_required
def cliente_nuevo(request):
    """Alta de cliente + primer vehículo con sp_RegistrarClienteVehiculo (transacción)."""
    if request.method == "POST":
        try:
            procedimiento(
                "sp_RegistrarClienteVehiculo",
                *_datos_cliente(request),
                _telefono(request), _texto(request, "tipo_tel") or "Móvil",
                *_datos_vehiculo(request),
            )
            messages.success(request, "Cliente y vehículo registrados.")
            return redirect("clientes")
        except ErrorNegocio as e:
            messages.error(request, str(e))
    return render(request, "core/cliente_nuevo.html", _catalogos_cliente())


@login_required
def cliente_editar(request, idc):
    cliente = uno("SELECT * FROM vw_Cliente WHERE IdCliente = %s", [idc])
    if not cliente:
        messages.error(request, "Cliente no encontrado.")
        return redirect("clientes")
    if request.method == "POST":
        try:
            ejecutar("""UPDATE Cliente SET Nombres=%s, Apellidos=%s, NIT=%s, Correo=%s,
                               Calle=%s, Zona=%s, IdMunicipio=%s
                        WHERE IdCliente=%s""", _datos_cliente(request) + [idc])
            messages.success(request, "Cliente actualizado.")
            return redirect("cliente_editar", idc=idc)
        except ErrorNegocio as e:
            messages.error(request, str(e))
    return render(request, "core/cliente_editar.html", {
        "c": cliente,
        "vehiculos": consultar("SELECT * FROM vw_Vehiculo WHERE IdCliente = %s ORDER BY Placa", [idc]),
        "telefonos": consultar("""SELECT * FROM TelefonoCliente WHERE IdCliente = %s
                                  ORDER BY Principal DESC, IdTelefono""", [idc]),
        **_catalogos_cliente(),
    })


@login_required
def telefono_accion(request, idc, accion, idt=None):
    """Agregar, marcar como principal o eliminar un teléfono (cada uno con su procedimiento)."""
    if request.method == "POST":
        try:
            if accion == "agregar":
                tipo = request.POST.get("tipo_tel", "Móvil")
                procedimiento("sp_AgregarTelefonoCliente", idc, _telefono(request), tipo)
                messages.success(request, "Teléfono agregado.")
            elif accion == "principal":
                procedimiento("sp_MarcarTelefonoPrincipal", idt)
                messages.success(request, "Teléfono principal actualizado.")
            elif accion == "eliminar":
                procedimiento("sp_EliminarTelefonoCliente", idt)
                messages.success(request, "Teléfono eliminado.")
        except ErrorNegocio as e:
            messages.error(request, str(e))
    return redirect("cliente_editar", idc=idc)


@login_required
def cliente_eliminar(request, idc):
    if request.method == "POST":
        try:
            messages.success(request, _eliminar("DELETE FROM Cliente WHERE IdCliente=%s", idc, "Cliente"))
        except ErrorNegocio as e:
            messages.error(request, str(e))
    return redirect("clientes")


# ------------------------------------------------------------------ vehículos
@login_required
def vehiculo_guardar(request, idc, idv=None):
    """Agregar (idv=None) o editar un vehículo de un cliente."""
    if request.method == "POST":
        try:
            datos = _datos_vehiculo(request)
            if idv:
                ejecutar("""UPDATE Vehiculo SET Placa=%s, IdModelo=%s, Anio=%s, IdColor=%s,
                            Kilometraje=%s WHERE IdVehiculo=%s AND IdCliente=%s""", datos + [idv, idc])
            else:
                ejecutar("""INSERT INTO Vehiculo (Placa, IdModelo, Anio, IdColor, Kilometraje, IdCliente)
                            VALUES (%s,%s,%s,%s,%s,%s)""", datos + [idc])
            messages.success(request, "Vehículo guardado.")
        except ErrorNegocio as e:
            msg = str(e)
            messages.error(request, "Esa placa ya está registrada." if "UQ_Vehiculo_Placa" in msg else msg)
    return redirect("cliente_editar", idc=idc)


@login_required
def vehiculo_eliminar(request, idc, idv):
    if request.method == "POST":
        try:
            messages.success(request, _eliminar("DELETE FROM Vehiculo WHERE IdVehiculo=%s", idv, "Vehículo"))
        except ErrorNegocio as e:
            messages.error(request, str(e))
    return redirect("cliente_editar", idc=idc)


@login_required
def historial_vehiculo(request):
    placa = request.GET.get("placa", "").strip().upper()
    vehiculo, filas, ordenes = None, [], []
    if placa:
        vehiculo = uno("SELECT * FROM vw_Vehiculo WHERE Placa = %s", [placa])
        filas = procedimiento("sp_HistorialVehiculo", placa)
        ordenes = consultar("SELECT * FROM vw_OrdenesDetalle WHERE Placa=%s ORDER BY FechaIngreso DESC", [placa])
    return render(request, "core/historial.html",
                  {"placa": placa, "v": vehiculo, "filas": filas, "ordenes": ordenes})


# ------------------------------------------------------------------ órdenes
@login_required
def ordenes(request):
    estado = request.GET.get("estado", "")
    buscar = request.GET.get("q", "").strip()
    sql = "SELECT * FROM vw_OrdenesDetalle WHERE (Placa LIKE %s OR Cliente LIKE %s)"
    params = [f"%{buscar}%", f"%{buscar}%"]
    if estado.isdigit():
        sql += " AND IdEstado = %s"
        params.append(int(estado))
    sql += " ORDER BY IdOrden DESC"
    return render(request, "core/ordenes.html", {
        "ordenes": consultar(sql, params),
        "estados": consultar("SELECT * FROM EstadoOrden ORDER BY Secuencia"),
        "estado": estado, "q": buscar,
    })


@login_required
def orden_nueva(request):
    if request.method == "POST":
        try:
            fila = procedimiento("sp_CrearOrden",
                                 _numero(request, "vehiculo", int, 1), _numero(request, "km"),
                                 _texto(request, "falla", True, 500),
                                 _texto(request, "observaciones", largo=1000) or None,
                                 request.user.username)
            messages.success(request, f"Orden #{fila[0]['IdOrden']} creada.")
            return redirect("orden_detalle", ido=fila[0]["IdOrden"])
        except ErrorNegocio as e:
            messages.error(request, str(e))
    vehiculos = consultar("""SELECT IdVehiculo, Placa, Marca, Modelo, Kilometraje, Cliente
                             FROM vw_Vehiculo ORDER BY Placa""")
    return render(request, "core/orden_nueva.html",
                  {"vehiculos": vehiculos, "sel": request.GET.get("vehiculo", "")})


@login_required
def orden_detalle(request, ido, plantilla="core/orden_detalle.html"):
    orden = uno("""SELECT d.*, o.KmIngreso, o.Diagnostico, o.Observaciones, o.Descuento,
                          co.TotalServicios, co.TotalManoObra, co.TotalRepuestos
                   FROM vw_OrdenesDetalle d
                   INNER JOIN OrdenTrabajo o ON o.IdOrden = d.IdOrden
                   INNER JOIN vw_CostoOrden co ON co.IdOrden = d.IdOrden
                   WHERE d.IdOrden = %s""", [ido])
    if not orden:
        messages.error(request, "Orden no encontrada.")
        return redirect("ordenes")

    abierta = orden["IdEstado"] in (1, 2, 3)
    siguiente = uno("SELECT * FROM EstadoOrden WHERE IdEstado = %s", [orden["IdEstado"] + 1]) \
        if orden["IdEstado"] < 5 else None

    return render(request, plantilla, {
        "o": orden, "abierta": abierta, "siguiente": siguiente,
        "puede_cancelar": orden["IdEstado"] < 4,
        "servicios": consultar("""
            SELECT os.*, s.Nombre AS Servicio, m.Nombre AS Mecanico,
                   os.Precio + os.HorasManoObra * os.TarifaHora AS Subtotal
            FROM OrdenServicio os
            INNER JOIN Servicio s ON s.IdServicio = os.IdServicio
            INNER JOIN Mecanico m ON m.IdMecanico = os.IdMecanico
            WHERE os.IdOrden = %s""", [ido]),
        "repuestos": consultar("""
            SELECT r.Codigo, r.Nombre, orp.Cantidad, orp.PrecioUnitario,
                   orp.Cantidad * orp.PrecioUnitario AS Subtotal
            FROM OrdenRepuesto orp INNER JOIN Repuesto r ON r.IdRepuesto = orp.IdRepuesto
            WHERE orp.IdOrden = %s""", [ido]),
        "pagos": consultar("""
            SELECT p.*, mp.Nombre AS Metodo FROM Pago p
            INNER JOIN MetodoPago mp ON mp.IdMetodoPago = p.IdMetodoPago
            WHERE p.IdOrden = %s ORDER BY p.FechaPago""", [ido]),
        "historial": consultar("""
            SELECT h.FechaCambio, h.Usuario, h.Comentario,
                   ea.Nombre AS Anterior, en.Nombre AS Nuevo
            FROM HistorialEstado h
            INNER JOIN EstadoOrden en ON en.IdEstado = h.EstadoNuevo
            LEFT JOIN EstadoOrden ea  ON ea.IdEstado = h.EstadoAnterior
            WHERE h.IdOrden = %s ORDER BY h.FechaCambio""", [ido]),
        "cat_servicios": consultar("SELECT * FROM Servicio WHERE Activo = 1 ORDER BY Nombre"),
        "cat_mecanicos": consultar("SELECT * FROM Mecanico WHERE Activo = 1 ORDER BY Apellidos, Nombres"),
        "cat_repuestos": consultar("SELECT * FROM Repuesto WHERE Stock > 0 ORDER BY Nombre"),
        "metodos": consultar("SELECT * FROM MetodoPago ORDER BY IdMetodoPago"),
    })


@login_required
def orden_accion(request, ido, accion):
    """Todas las operaciones sobre una orden pasan por un procedimiento almacenado."""
    if request.method != "POST":
        return redirect("orden_detalle", ido=ido)
    try:
        if accion == "diagnostico":
            procedimiento("sp_ActualizarDiagnostico", ido, _texto(request, "diagnostico", largo=1000),
                          _texto(request, "observaciones", largo=1000) or None,
                          _numero(request, "descuento", float))
            messages.success(request, "Diagnóstico actualizado.")
        elif accion == "servicio":
            procedimiento("sp_AgregarServicioOrden", ido, _numero(request, "servicio", int, 1),
                          _numero(request, "mecanico", int, 1), _numero(request, "horas", float))
            messages.success(request, "Servicio asignado.")
        elif accion == "repuesto":
            procedimiento("sp_AgregarRepuestoOrden", ido, _numero(request, "repuesto", int, 1),
                          _numero(request, "cantidad", int, 1))
            messages.success(request, "Repuesto agregado y descontado del inventario.")
        elif accion == "pago":
            procedimiento("sp_RegistrarPago", ido, _numero(request, "metodo", int, 1),
                          _numero(request, "monto", float), _texto(request, "referencia", largo=50) or None)
            messages.success(request, "Pago registrado.")
        elif accion == "estado":
            procedimiento("sp_CambiarEstadoOrden", ido, _numero(request, "estado", int, 1),
                          request.user.username, _texto(request, "comentario", largo=300) or None)
            messages.success(request, "Estado actualizado.")
    except ErrorNegocio as e:
        messages.error(request, str(e))
    return redirect("orden_detalle", ido=ido)


@login_required
def orden_imprimir(request, ido):
    return orden_detalle(request, ido, "core/orden_imprimir.html")


# ------------------------------------------------------------------ catálogos
CATALOGOS = {
    "mecanicos": {
        "titulo": "Mecánicos", "tabla": "Mecanico", "pk": "IdMecanico",
        "campos": [("Nombres", "Nombres", "text", True), ("Apellidos", "Apellidos", "text", True),
                   ("Telefono", "Teléfono (solo dígitos)", "tel", False),
                   ("TarifaHora", "Tarifa por hora (Q)", "number", True), ("Activo", "Activo", "bool", False)],
        "orden": "Apellidos, Nombres",
    },
    "servicios": {
        "titulo": "Servicios", "tabla": "Servicio", "pk": "IdServicio",
        "campos": [("Nombre", "Nombre", "text", True), ("Descripcion", "Descripción", "text", False),
                   ("PrecioBase", "Precio base (Q)", "number", True), ("Activo", "Activo", "bool", False)],
    },
    "repuestos": {
        "titulo": "Repuestos", "tabla": "Repuesto", "pk": "IdRepuesto",
        "campos": [("Codigo", "Código", "text", True), ("Nombre", "Nombre", "text", True),
                   ("Precio", "Precio (Q)", "number", True), ("Stock", "Stock", "number", True),
                   ("StockMinimo", "Stock mínimo", "number", True)],
    },
    "marcas": {
        "titulo": "Marcas", "tabla": "Marca", "pk": "IdMarca",
        "campos": [("Nombre", "Nombre", "text", True)],
    },
    "modelos": {
        "titulo": "Modelos", "tabla": "Modelo", "pk": "IdModelo",
        "campos": [("IdMarca", "Marca", "select", True), ("Nombre", "Modelo", "text", True)],
        "opciones": {"IdMarca": "SELECT IdMarca AS id, Nombre AS txt FROM Marca ORDER BY Nombre"},
        "orden": "IdMarca, Nombre",
    },
    "colores": {
        "titulo": "Colores", "tabla": "Color", "pk": "IdColor",
        "campos": [("Nombre", "Nombre", "text", True)],
    },
}


@login_required
def catalogo(request, nombre, idx=None):
    """CRUD genérico para Mecánicos, Servicios y Repuestos (los nombres de tabla y columnas
    vienen del diccionario CATALOGOS, nunca del usuario, por eso es seguro armar el SQL)."""
    cfg = CATALOGOS.get(nombre)
    if not cfg:
        return redirect("inicio")
    tabla, pk, campos = cfg["tabla"], cfg["pk"], cfg["campos"]

    if request.method == "POST":
        try:
            if request.POST.get("_eliminar"):
                messages.success(request, _eliminar(f"DELETE FROM {tabla} WHERE {pk}=%s", idx, cfg["titulo"][:-1]))
                return redirect("catalogo", nombre=nombre)
            valores = []
            for col, etiqueta, tipo, req in campos:
                if tipo == "bool":
                    valores.append(1 if request.POST.get(col) else 0)
                elif tipo == "select":
                    valores.append(_numero(request, col, int, 1))
                elif tipo == "tel":
                    valores.append(_telefono(request, col, requerido=False) or None)
                elif tipo == "number":
                    valores.append(_numero(request, col, float))
                else:
                    valores.append(_texto(request, col, req, 300) or None)
            cols = [c[0] for c in campos]
            if idx:
                ejecutar(f"UPDATE {tabla} SET {', '.join(c + '=%s' for c in cols)} WHERE {pk}=%s", valores + [idx])
            else:
                ejecutar(f"INSERT INTO {tabla} ({', '.join(cols)}) VALUES ({', '.join(['%s'] * len(cols))})", valores)
            messages.success(request, "Registro guardado.")
            return redirect("catalogo", nombre=nombre)
        except ErrorNegocio as e:
            msg = str(e)
            messages.error(request, "Ya existe un registro con ese nombre o código." if "UNIQUE" in msg.upper() else msg)

    registros = consultar(f"SELECT * FROM {tabla} ORDER BY {cfg.get('orden', '2')}")
    editar = uno(f"SELECT * FROM {tabla} WHERE {pk}=%s", [idx]) if idx else None
    # Para las columnas FK (tipo select) se carga la lista de opciones y se muestra el texto, no el id
    opciones = {col: consultar(sql) for col, sql in cfg.get("opciones", {}).items()}
    textos = {col: {o["id"]: o["txt"] for o in ops} for col, ops in opciones.items()}
    filas = [{"id": r[pk],
              "valores": [textos[c[0]].get(r[c[0]]) if c[0] in textos else r[c[0]] for c in campos],
              "bajo": nombre == "repuestos" and r["Stock"] <= r["StockMinimo"]}
             for r in registros]
    form = [{"col": c[0], "etiqueta": c[1], "tipo": c[2], "req": c[3], "opciones": opciones.get(c[0], []),
             "valor": (editar or {}).get(c[0], 1 if c[2] == "bool" else "")} for c in campos]
    return render(request, "core/catalogo.html",
                  {"cfg": cfg, "nombre": nombre, "filas": filas, "form": form, "editar": editar})


# ------------------------------------------------------------------ reportes
@login_required
def reportes(request):
    hoy = date.today()
    desde = request.GET.get("desde") or hoy.replace(month=1, day=1).isoformat()
    hasta = request.GET.get("hasta") or hoy.isoformat()
    return render(request, "core/reportes.html", {
        "desde": desde, "hasta": hasta,
        "ingresos": procedimiento("sp_ReporteIngresos", desde, hasta),
        "servicios": consultar("""
            SELECT s.Nombre, COUNT(os.IdOrdenServicio) AS Veces,
                   SUM(os.Precio + os.HorasManoObra * os.TarifaHora) AS Ingreso
            FROM Servicio s
            INNER JOIN OrdenServicio os ON os.IdServicio = s.IdServicio
            INNER JOIN OrdenTrabajo o ON o.IdOrden = os.IdOrden
            WHERE o.IdEstado <> 6 AND CAST(o.FechaIngreso AS DATE) BETWEEN %s AND %s
            GROUP BY s.Nombre ORDER BY Veces DESC, Ingreso DESC""", [desde, hasta]),
        "mecanicos": consultar("""
            SELECT m.Nombre, COUNT(DISTINCT os.IdOrden) AS Ordenes, SUM(os.HorasManoObra) AS Horas,
                   SUM(os.HorasManoObra * os.TarifaHora) AS ManoObra, AVG(os.HorasManoObra) AS PromHoras
            FROM Mecanico m
            INNER JOIN OrdenServicio os ON os.IdMecanico = m.IdMecanico
            INNER JOIN OrdenTrabajo o ON o.IdOrden = os.IdOrden
            WHERE o.IdEstado <> 6 AND CAST(o.FechaIngreso AS DATE) BETWEEN %s AND %s
            GROUP BY m.IdMecanico, m.Nombre ORDER BY ManoObra DESC""", [desde, hasta]),
        "tiempos": uno("""
            SELECT AVG(DATEDIFF(MINUTE, h1.FechaCambio, h4.FechaCambio) / 60.0) AS Prom,
                   MAX(DATEDIFF(MINUTE, h1.FechaCambio, h4.FechaCambio) / 60.0) AS Maximo,
                   MIN(DATEDIFF(MINUTE, h1.FechaCambio, h4.FechaCambio) / 60.0) AS Minimo,
                   COUNT(*) AS N
            FROM HistorialEstado h1
            INNER JOIN HistorialEstado h4 ON h4.IdOrden = h1.IdOrden AND h4.EstadoNuevo = 4
            WHERE h1.EstadoNuevo = 1"""),
        "saldos": consultar("""SELECT * FROM vw_OrdenesDetalle
                               WHERE Saldo > 0 AND IdEstado <> 6 ORDER BY Saldo DESC"""),
        "stock": consultar("SELECT * FROM Repuesto WHERE Stock <= StockMinimo ORDER BY Stock"),
    })


# ------------------------------------------------------------------ consulta pública
def consulta_publica(request):
    """Funcionalidad extra: el cliente consulta el avance sin iniciar sesión (placa + No. de orden)."""
    orden, historial = None, []
    placa = request.GET.get("placa", "").strip().upper()
    num = request.GET.get("orden", "").strip()
    if placa and num.isdigit():
        orden = uno("""SELECT IdOrden, Placa, Marca, Modelo, Estado, IdEstado, FechaIngreso, Total, Pagado, Saldo
                       FROM vw_OrdenesDetalle WHERE Placa = %s AND IdOrden = %s""", [placa, int(num)])
        if orden:
            historial = consultar("""SELECT h.FechaCambio, e.Nombre FROM HistorialEstado h
                                     INNER JOIN EstadoOrden e ON e.IdEstado = h.EstadoNuevo
                                     WHERE h.IdOrden = %s ORDER BY h.FechaCambio""", [orden["IdOrden"]])
        else:
            messages.error(request, "No se encontró una orden con esos datos.")
    return render(request, "core/consulta.html",
                  {"o": orden, "historial": historial, "placa": placa, "num": num,
                   "pasos": ["Recibido", "Diagnóstico", "Reparación", "Terminado", "Entregado"]})

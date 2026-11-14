# Sistema de Órdenes de Trabajo — Taller Automotriz

<p align="center">
  <b>Universidad Mariano Gálvez de Guatemala</b><br>
  Ingeniería en Sistemas de Información · Curso: Bases de Datos · Sexto semestre 2026
</p>

Proyecto final de Bases de Datos (Ejercicio 4). Python + Django + **SQL Server**.

## Integrantes

| No. | Nombre | Carné |
|---|---|---|
| 1 | Fernando José Batz Marroquín | 0903-23-463 |
| 2 | Emerson Desaylí Orozco Salvador | 0903-24-16049 |
| 3 | Harold Jose Gonzalez Ochoa | 0903-24-21104 |
| 4 | José Daniel Fuentes García | 0903-23-7050 |
| 5 | Darwin Danilo Castro Garcia | 0903-20-6780 |

> Los mismos datos se muestran en la aplicación (menú **Equipo del proyecto** y pantalla de login).
> Para cambiarlos en la app se edita `web/core/equipo.py`.

```
taller/
├── sql/
│   ├── 01_tablas.sql             20 tablas normalizadas (1FN–3FN) con PK, FK, UNIQUE, CHECK e índices
│   ├── 02_datos.sql              catálogos y datos de prueba
│   ├── 03_funciones_vistas.sql   fn_TotalOrden, fn_PagadoOrden y 6 vistas
│   ├── 04_procedimientos.sql     12 procedimientos (+ órdenes de ejemplo)
│   ├── 05_reportes.sql           consultas de los reportes para probar en SSMS
│   └── 06_datos_masivos.sql      (opcional) ~25 clientes, ~40 vehículos y ~60 órdenes de prueba
├── web/                          proyecto Django
│   ├── .env.example              plantilla de la conexión (copiar como .env)
│   ├── taller_web/settings.py    configuración (lee los datos de .env)
│   └── core/
│       ├── equipo.py             datos del grupo (nombres, carnés, curso)
│       ├── db.py                 acceso a datos (SQL directo, vistas y SP)
│       ├── views.py              lógica de cada pantalla
│       ├── urls.py               rutas
│       ├── templates/            HTML
│       └── static/core/app.css   estilos
└── docs/
    ├── documentacion_tecnica.md  modelo ER, diccionario y reglas de negocio
    └── plan_pruebas.md           casos de prueba para llenar con evidencias
```

## 1. Instalación (Windows)

> **Usen PowerShell**, no WSL. En VS Code: panel de la terminal → flechita **˅** junto al **+** → **PowerShell**.
> Si el prompt empieza con `PS C:\...` está bien; si es `➜` o dice `wsl`, es la terminal equivocada.

### Requisitos
- SQL Server (Express sirve) + SQL Server Management Studio (SSMS)
- Python 3.11 o superior: https://www.python.org/downloads/ (marcar **"Add python.exe to PATH"** al instalar)
- [ODBC Driver 18 for SQL Server](https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server)

### Paso 1. Clonar el repositorio
```powershell
git clone <URL-del-repositorio>
cd <carpeta-del-repositorio>
```

### Paso 2. Crear la base de datos
Abrir SSMS y ejecutar **en orden**, una sola vez:
`sql/01_tablas.sql` → `sql/02_datos.sql` → `sql/03_funciones_vistas.sql` → `sql/04_procedimientos.sql`

Para verificar, ejecutar en SSMS:
```sql
USE TallerDB;
SELECT type_desc, COUNT(*) AS Cantidad FROM sys.objects
WHERE type IN ('V','P','FN') GROUP BY type_desc;
```
Debe mostrar **VIEW 6**, **SQL_STORED_PROCEDURE 12** y **SQL_SCALAR_FUNCTION 2**.

> 💡 **Opcional:** después del 04, ejecuten `sql/06_datos_masivos.sql` para llenar la app con muchos datos de prueba. Solo una vez.

> ⚠️ `01_tablas.sql` **borra y vuelve a crear** TallerDB. Para empezar de cero, ejecuten de nuevo los 4 scripts en orden.
> No ejecuten `02_datos.sql` solo una segunda vez: da errores de datos duplicados.

### Paso 3. Crear el entorno virtual e instalar dependencias
```powershell
cd web
py -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```
Al activarlo, la línea de la terminal empieza con **`(venv)`**. Desde ese momento ya funciona `python` normalmente.

### Paso 4. Configurar SU conexión a SQL Server
Copiar el archivo de ejemplo y poner **su propia contraseña** de `sa` (la misma con la que entran a SSMS):
```powershell
copy .env.example .env
notepad .env
```
```
DB_HOST=localhost
DB_USER=sa
DB_PASSWORD=su_contraseña
```
El archivo `.env` **no se sube a GitHub**, así cada integrante tiene su contraseña sin afectar a los demás.
No modifiquen la contraseña dentro de `settings.py`.

### Paso 5. Preparar Django y ejecutar
```powershell
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```
- `migrate` crea **solo** las tablas de usuarios y sesiones de Django; no toca las del taller. Todas las líneas deben terminar en `OK`.
- `createsuperuser` crea el usuario para entrar a la app (pueden inventarlo). Pide usuario, correo (opcional, Enter) y contraseña dos veces.
  **La contraseña no se ve al escribirla**, es normal. Si dice que es débil, respondan `y`.

Abrir **http://127.0.0.1:8000** y entrar con ese usuario.

### Cada vez que vuelvan a trabajar
```powershell
cd web
venv\Scripts\activate
python manage.py runserver
```

## 1.1 Solución de problemas

| Error / mensaje | Causa | Solución |
|---|---|---|
| `Python was not found; run without arguments to install from the Microsoft Store...` | Python no está en el PATH | Usar `py` en lugar de `python` (ej. `py -m venv venv`). Si `py` tampoco existe, instalar Python marcando **"Add python.exe to PATH"** y reiniciar VS Code. También se puede apagar el alias en *Configuración → Aplicaciones → Configuración avanzada de aplicaciones → Alias de ejecución* (python.exe y python3.exe). |
| `zsh: command not found: python` o `command not found: py` | La terminal abierta es **WSL (Linux)**, no Windows | Abrir una terminal **PowerShell** (ver nota al inicio). |
| `...la ejecución de scripts está deshabilitada en este sistema` al activar el venv | Política de PowerShell | Ejecutar una vez `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` y volver a activar. |
| Aviso de VS Code: *"You may have installed Python packages into your global environment... Create?"* | Falsa alarma si la terminal muestra `(venv)` | Cerrar el aviso o elegir **Don't show again**. **No** presionar *Create*. |
| `pip install` falla con *"building wheel"* o *"Microsoft Visual C++ required"* | Versión de Python demasiado nueva sin paquetes compilados | Instalar Python 3.12, borrar la carpeta `venv` y crearla con `py -3.12 -m venv venv`. |
| `Login failed for user 'sa'. (18456)` | Contraseña incorrecta en `.env` (o no existe el `.env`) | Revisar el Paso 4: el archivo debe llamarse exactamente `.env`, estar dentro de `web` y tener la contraseña correcta. Guardar con Ctrl+S. |
| `Login failed` y en SSMS entran **sin contraseña** | Usan autenticación de Windows | En `.env` dejar `DB_USER=` vacío. |
| `Data source name not found` / `Can't open lib 'ODBC Driver 18 for SQL Server'` | Falta el driver ODBC | Instalar **ODBC Driver 18 for SQL Server** (link en requisitos). |
| `A network-related or instance-specific error` / `Named Pipes Provider` | El servidor o la instancia no es el correcto, o SQL Server está apagado | Usar el mismo nombre de servidor que aparece en SSMS. Si es Express: `DB_HOST=localhost\SQLEXPRESS`. Verificar en *Servicios de Windows* que **SQL Server** esté iniciado. |
| `Invalid column name 'Marca'` / `'Telefono'` / `'Direccion'` u otra columna | La base es de la versión anterior (sin atributos atómicos) | Ejecutar de nuevo los 4 scripts en orden; `01_tablas.sql` recrea la base. |
| `Cannot open database "TallerDB"` | No se ejecutaron los scripts SQL | Hacer el Paso 2. |
| `Could not find stored procedure 'sp_...'` o `Invalid object name 'vw_...'` | Faltan los scripts 03 o 04 | Ejecutar `03_funciones_vistas.sql` y `04_procedimientos.sql`. |
| `Error: That port is already in use` | Ya hay otro `runserver` abierto | Cerrar la otra terminal o usar `python manage.py runserver 8001`. |
| `ModuleNotFoundError: No module named 'django'` | El entorno virtual no está activado | Ejecutar `venv\Scripts\activate` (debe aparecer `(venv)`). |

## 2. Cumplimiento de los requisitos

| Requisito | Dónde está |
|---|---|
| SQL Server | `settings.py` (motor `mssql`) |
| ≥ 8 tablas con PK y FK | 20 tablas en `01_tablas.sql`, atributos atómicos |
| Diagrama ER y modelo relacional | `docs/documentacion_tecnica.md` |
| CRUD con validaciones | Clientes, teléfonos, vehículos, mecánicos, servicios, repuestos, marcas, modelos y colores (HTML + Python + CHECK/UNIQUE en SQL) |
| ≥ 5 procedimientos | 12 en `04_procedimientos.sql`, todos llamados desde `views.py` |
| ≥ 3 vistas | `vw_CostoOrden`, `vw_Cliente`, `vw_Vehiculo`, `vw_OrdenesDetalle`, `vw_HistorialServiciosVehiculo`, `vw_CargaMecanicos` |
| JOIN, filtros, orden, agregación | `views.reportes`, `views.inicio`, `05_reportes.sql` |
| Transacción con reversión | `sp_CambiarEstadoOrden`, `sp_AgregarRepuestoOrden`, `sp_RegistrarClienteVehiculo`, `sp_CrearOrden`, `sp_RegistrarPago` |
| ≥ 4 reportes | 6 en la pantalla Reportes |
| Reto: historial de estados | Tabla `HistorialEstado`, llenada por `sp_CrearOrden` y `sp_CambiarEstadoOrden` |
| Reto: costo total | `fn_TotalOrden` + `vw_CostoOrden` |

**Funcionalidades extra (punto 10):** consulta pública del avance para clientes (`/consulta/`),
control de inventario de repuestos con alerta de stock bajo, impresión de la orden,
devolución de repuestos al cancelar, bloqueo de entrega con saldo pendiente y panel con indicadores.

## 3. Reparto sugerido

| Integrante | Archivos |
|---|---|
| A — Modelado | `01_tablas.sql`, `02_datos.sql`, diagrama ER |
| B — Lógica SQL | `03_funciones_vistas.sql`, `04_procedimientos.sql` |
| C — Django: clientes, vehículos y catálogos | `db.py`, vistas y plantillas de esos módulos |
| D — Órdenes, pagos y reportes | `orden_*`, `reportes`, `05_reportes.sql` |

Todos deben poder explicar `db.py`, `fn_TotalOrden` y `sp_CambiarEstadoOrden`: son las piezas centrales.

## 4. Pendientes del equipo
- Dibujar el diagrama ER en una herramienta (draw.io, SSMS o dbdiagram.io); el texto base está en `docs/`.
- Manual de usuario con capturas.
- Ejecutar el plan de pruebas y guardar evidencias.
- Revisar y adaptar el código: el docente puede pedir cambios en vivo durante la defensa.

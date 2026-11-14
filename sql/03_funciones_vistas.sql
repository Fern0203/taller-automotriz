/* Script 03: funciones y vistas (Reto 2: costo total de la orden) */
USE TallerDB;
GO

-- Total de una orden = servicios + mano de obra + repuestos - descuento
CREATE OR ALTER FUNCTION fn_TotalOrden (@IdOrden INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Servicios DECIMAL(12,2), @Repuestos DECIMAL(12,2), @Descuento DECIMAL(12,2);

    SELECT @Servicios = ISNULL(SUM(Precio + HorasManoObra * TarifaHora), 0)
    FROM OrdenServicio WHERE IdOrden = @IdOrden;

    SELECT @Repuestos = ISNULL(SUM(Cantidad * PrecioUnitario), 0)
    FROM OrdenRepuesto WHERE IdOrden = @IdOrden;

    SELECT @Descuento = Descuento FROM OrdenTrabajo WHERE IdOrden = @IdOrden;

    RETURN @Servicios + @Repuestos - ISNULL(@Descuento, 0);
END;
GO

CREATE OR ALTER FUNCTION fn_PagadoOrden (@IdOrden INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN (SELECT ISNULL(SUM(Monto), 0) FROM Pago WHERE IdOrden = @IdOrden);
END;
GO

/* Vista 1: costo desglosado de cada orden */
CREATE OR ALTER VIEW vw_CostoOrden AS
SELECT o.IdOrden,
       ISNULL(s.TotalServicios, 0) AS TotalServicios,
       ISNULL(s.TotalManoObra, 0)  AS TotalManoObra,
       ISNULL(r.TotalRepuestos, 0) AS TotalRepuestos,
       o.Descuento,
       dbo.fn_TotalOrden(o.IdOrden)  AS Total,
       dbo.fn_PagadoOrden(o.IdOrden) AS Pagado,
       dbo.fn_TotalOrden(o.IdOrden) - dbo.fn_PagadoOrden(o.IdOrden) AS Saldo
FROM OrdenTrabajo o
LEFT JOIN (SELECT IdOrden, SUM(Precio) AS TotalServicios,
                  SUM(HorasManoObra * TarifaHora) AS TotalManoObra
           FROM OrdenServicio GROUP BY IdOrden) s ON s.IdOrden = o.IdOrden
LEFT JOIN (SELECT IdOrden, SUM(Cantidad * PrecioUnitario) AS TotalRepuestos
           FROM OrdenRepuesto GROUP BY IdOrden) r ON r.IdOrden = o.IdOrden;
GO

/* Vista 2: cliente con nombre completo, teléfono principal y dirección armada
   (los datos se guardan atómicos; esta vista solo los presenta juntos) */
CREATE OR ALTER VIEW vw_Cliente AS
SELECT c.IdCliente, c.Nombres, c.Apellidos, c.Nombre, c.NIT, c.Correo,
       c.Calle, c.Zona, c.IdMunicipio, m.Nombre AS Municipio,
       d.IdDepartamento, d.Nombre AS Departamento,
       CONCAT_WS(', ', c.Calle, 'Zona ' + CAST(c.Zona AS VARCHAR(2)), m.Nombre, d.Nombre) AS Direccion,
       t.Numero AS Telefono, c.FechaRegistro
FROM Cliente c
LEFT JOIN Municipio m       ON m.IdMunicipio    = c.IdMunicipio
LEFT JOIN Departamento d    ON d.IdDepartamento = m.IdDepartamento
LEFT JOIN TelefonoCliente t ON t.IdCliente = c.IdCliente AND t.Principal = 1;
GO

/* Vista 3: vehículo con marca, modelo, color y propietario */
CREATE OR ALTER VIEW vw_Vehiculo AS
SELECT v.IdVehiculo, v.IdCliente, v.Placa, v.Anio, v.VIN, v.Kilometraje,
       v.IdModelo, mo.Nombre AS Modelo, ma.IdMarca, ma.Nombre AS Marca,
       v.IdColor, co.Nombre AS Color, c.Nombre AS Cliente
FROM Vehiculo v
INNER JOIN Modelo mo  ON mo.IdModelo = v.IdModelo
INNER JOIN Marca ma   ON ma.IdMarca  = mo.IdMarca
LEFT JOIN Color co    ON co.IdColor  = v.IdColor
INNER JOIN Cliente c  ON c.IdCliente = v.IdCliente;
GO

/* Vista 4: listado de órdenes con cliente, vehículo, estado y saldo */
CREATE OR ALTER VIEW vw_OrdenesDetalle AS
SELECT o.IdOrden, o.FechaIngreso, o.FechaEntrega, o.FallaReportada,
       c.IdCliente, c.Nombre AS Cliente, c.Telefono,
       v.IdVehiculo, v.Placa, v.Marca, v.Modelo,
       e.IdEstado, e.Nombre AS Estado,
       DATEDIFF(DAY, o.FechaIngreso, ISNULL(o.FechaEntrega, SYSDATETIME())) AS DiasEnTaller,
       co.Total, co.Pagado, co.Saldo
FROM OrdenTrabajo o
INNER JOIN vw_Vehiculo v    ON v.IdVehiculo = o.IdVehiculo
INNER JOIN vw_Cliente c     ON c.IdCliente  = v.IdCliente
INNER JOIN EstadoOrden e    ON e.IdEstado   = o.IdEstado
INNER JOIN vw_CostoOrden co ON co.IdOrden   = o.IdOrden;
GO

/* Vista 5: historial de servicios por vehículo */
CREATE OR ALTER VIEW vw_HistorialServiciosVehiculo AS
SELECT v.Placa, v.Marca, v.Modelo, o.IdOrden, o.FechaIngreso, o.KmIngreso,
       s.Nombre AS Servicio, m.Nombre AS Mecanico,
       os.Precio + os.HorasManoObra * os.TarifaHora AS CostoServicio,
       e.Nombre AS EstadoOrden
FROM OrdenServicio os
INNER JOIN OrdenTrabajo o ON o.IdOrden    = os.IdOrden
INNER JOIN vw_Vehiculo v  ON v.IdVehiculo = o.IdVehiculo
INNER JOIN Servicio s     ON s.IdServicio = os.IdServicio
INNER JOIN Mecanico m     ON m.IdMecanico = os.IdMecanico
INNER JOIN EstadoOrden e  ON e.IdEstado   = o.IdEstado;
GO

/* Vista 6: carga de trabajo de mecánicos (órdenes sin terminar) */
CREATE OR ALTER VIEW vw_CargaMecanicos AS
SELECT m.IdMecanico, m.Nombre,
       COUNT(DISTINCT CASE WHEN o.IdEstado IN (1,2,3) THEN o.IdOrden END) AS OrdenesActivas,
       ISNULL(SUM(CASE WHEN o.IdEstado IN (1,2,3) THEN os.HorasManoObra END), 0) AS HorasPendientes
FROM Mecanico m
LEFT JOIN OrdenServicio os ON os.IdMecanico = m.IdMecanico
LEFT JOIN OrdenTrabajo o   ON o.IdOrden = os.IdOrden
WHERE m.Activo = 1
GROUP BY m.IdMecanico, m.Nombre;
GO

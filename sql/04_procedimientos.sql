/* Script 04: procedimientos almacenados (todos con transacción y manejo de errores) */
USE TallerDB;
GO

/* 1. Registrar cliente + teléfono principal + vehículo en UNA transacción (afecta 3 tablas) */
CREATE OR ALTER PROCEDURE sp_RegistrarClienteVehiculo
    @Nombres NVARCHAR(60), @Apellidos NVARCHAR(60), @NIT NVARCHAR(15), @Correo NVARCHAR(100),
    @Calle NVARCHAR(100), @Zona TINYINT, @IdMunicipio INT,
    @Telefono NVARCHAR(15), @TipoTelefono NVARCHAR(10),
    @Placa NVARCHAR(10), @IdModelo INT, @Anio SMALLINT, @IdColor INT, @Kilometraje INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Vehiculo WHERE Placa = @Placa)
            THROW 50001, 'Ya existe un vehículo con esa placa.', 1;
        IF NOT EXISTS (SELECT 1 FROM Modelo WHERE IdModelo = @IdModelo)
            THROW 50005, 'Seleccione un modelo válido.', 1;

        BEGIN TRAN;
            INSERT INTO Cliente (Nombres, Apellidos, NIT, Correo, Calle, Zona, IdMunicipio)
            VALUES (@Nombres, NULLIF(@Apellidos,''), ISNULL(NULLIF(@NIT,''),'CF'), NULLIF(@Correo,''),
                    NULLIF(@Calle,''), @Zona, @IdMunicipio);

            DECLARE @IdCliente INT = SCOPE_IDENTITY();

            INSERT INTO TelefonoCliente (IdCliente, Numero, Tipo, Principal)
            VALUES (@IdCliente, @Telefono, ISNULL(@TipoTelefono, N'Móvil'), 1);

            INSERT INTO Vehiculo (IdCliente, Placa, IdModelo, Anio, IdColor, Kilometraje)
            VALUES (@IdCliente, UPPER(@Placa), @IdModelo, @Anio, @IdColor, @Kilometraje);
        COMMIT;

        SELECT @IdCliente AS IdCliente;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* 1b. Agregar teléfono a un cliente (si es el primero queda como principal) */
CREATE OR ALTER PROCEDURE sp_AgregarTelefonoCliente
    @IdCliente INT, @Numero NVARCHAR(15), @Tipo NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM TelefonoCliente WHERE IdCliente = @IdCliente AND Numero = @Numero)
        THROW 50060, 'Ese teléfono ya está registrado para el cliente.', 1;

    INSERT INTO TelefonoCliente (IdCliente, Numero, Tipo, Principal)
    VALUES (@IdCliente, @Numero, @Tipo,
            CASE WHEN EXISTS (SELECT 1 FROM TelefonoCliente WHERE IdCliente = @IdCliente) THEN 0 ELSE 1 END);
END;
GO

/* 1c. Marcar un teléfono como principal (transacción: quita el anterior y pone el nuevo) */
CREATE OR ALTER PROCEDURE sp_MarcarTelefonoPrincipal @IdTelefono INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
            DECLARE @IdCliente INT = (SELECT IdCliente FROM TelefonoCliente WITH (UPDLOCK) WHERE IdTelefono = @IdTelefono);
            IF @IdCliente IS NULL THROW 50061, 'Teléfono no encontrado.', 1;

            UPDATE TelefonoCliente SET Principal = 0 WHERE IdCliente = @IdCliente AND Principal = 1;
            UPDATE TelefonoCliente SET Principal = 1 WHERE IdTelefono = @IdTelefono;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* 1d. Eliminar teléfono: no deja al cliente sin teléfonos; si era el principal, promueve otro */
CREATE OR ALTER PROCEDURE sp_EliminarTelefonoCliente @IdTelefono INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
            DECLARE @IdCliente INT, @EraPrincipal BIT;
            SELECT @IdCliente = IdCliente, @EraPrincipal = Principal
            FROM TelefonoCliente WITH (UPDLOCK) WHERE IdTelefono = @IdTelefono;

            IF @IdCliente IS NULL THROW 50061, 'Teléfono no encontrado.', 1;
            IF (SELECT COUNT(*) FROM TelefonoCliente WHERE IdCliente = @IdCliente) = 1
                THROW 50062, 'El cliente debe conservar al menos un teléfono.', 1;

            DELETE FROM TelefonoCliente WHERE IdTelefono = @IdTelefono;

            IF @EraPrincipal = 1
                UPDATE TOP (1) TelefonoCliente SET Principal = 1 WHERE IdCliente = @IdCliente;
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* 2. Crear orden de trabajo + primer registro del historial + actualizar km */
CREATE OR ALTER PROCEDURE sp_CrearOrden
    @IdVehiculo INT, @KmIngreso INT, @FallaReportada NVARCHAR(500),
    @Observaciones NVARCHAR(1000), @Usuario NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @KmActual INT = (SELECT Kilometraje FROM Vehiculo WHERE IdVehiculo = @IdVehiculo);
        IF @KmActual IS NULL
            THROW 50002, 'El vehículo no existe.', 1;
        IF @KmIngreso < @KmActual
            THROW 50003, 'El kilometraje de ingreso no puede ser menor al registrado.', 1;
        IF EXISTS (SELECT 1 FROM OrdenTrabajo WHERE IdVehiculo = @IdVehiculo AND IdEstado IN (1,2,3,4))
            THROW 50004, 'El vehículo ya tiene una orden abierta.', 1;

        BEGIN TRAN;
            INSERT INTO OrdenTrabajo (IdVehiculo, KmIngreso, FallaReportada, Observaciones)
            VALUES (@IdVehiculo, @KmIngreso, @FallaReportada, @Observaciones);

            DECLARE @IdOrden INT = SCOPE_IDENTITY();

            INSERT INTO HistorialEstado (IdOrden, EstadoAnterior, EstadoNuevo, Usuario, Comentario)
            VALUES (@IdOrden, NULL, 1, @Usuario, 'Vehículo recibido');

            UPDATE Vehiculo SET Kilometraje = @KmIngreso WHERE IdVehiculo = @IdVehiculo;
        COMMIT;

        SELECT @IdOrden AS IdOrden;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* 3. Cambiar estado con validación del flujo + historial (TRANSACCIÓN PRINCIPAL) */
CREATE OR ALTER PROCEDURE sp_CambiarEstadoOrden
    @IdOrden INT, @EstadoNuevo TINYINT, @Usuario NVARCHAR(50), @Comentario NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
            DECLARE @EstadoActual TINYINT;
            -- UPDLOCK evita que dos usuarios cambien la misma orden al mismo tiempo
            SELECT @EstadoActual = IdEstado FROM OrdenTrabajo WITH (UPDLOCK) WHERE IdOrden = @IdOrden;

            IF @EstadoActual IS NULL
                THROW 50010, 'La orden no existe.', 1;
            IF @EstadoActual IN (5,6)
                THROW 50011, 'La orden ya está cerrada (entregada o cancelada).', 1;

            -- Reglas del flujo: solo avanzar un paso, o cancelar antes de terminar
            IF NOT ( (@EstadoNuevo = @EstadoActual + 1 AND @EstadoNuevo <= 5)
                  OR (@EstadoNuevo = 6 AND @EstadoActual < 4) )
                THROW 50012, 'Cambio de estado no permitido por el flujo del taller.', 1;

            IF @EstadoNuevo = 3 AND NOT EXISTS (SELECT 1 FROM OrdenServicio WHERE IdOrden = @IdOrden)
                THROW 50013, 'Asigne al menos un servicio y mecánico antes de pasar a Reparación.', 1;

            IF @EstadoNuevo = 3 AND EXISTS (SELECT 1 FROM OrdenTrabajo WHERE IdOrden = @IdOrden AND Diagnostico IS NULL)
                THROW 50014, 'Registre el diagnóstico antes de pasar a Reparación.', 1;

            IF @EstadoNuevo = 5 AND dbo.fn_TotalOrden(@IdOrden) - dbo.fn_PagadoOrden(@IdOrden) > 0
                THROW 50015, 'No se puede entregar: la orden tiene saldo pendiente.', 1;

            UPDATE OrdenTrabajo
               SET IdEstado = @EstadoNuevo,
                   FechaEntrega = CASE WHEN @EstadoNuevo = 5 THEN SYSDATETIME() ELSE FechaEntrega END
             WHERE IdOrden = @IdOrden;

            -- Si se cancela, devolver repuestos al inventario
            IF @EstadoNuevo = 6
                UPDATE r SET r.Stock = r.Stock + x.Cant
                FROM Repuesto r
                INNER JOIN (SELECT IdRepuesto, SUM(Cantidad) AS Cant FROM OrdenRepuesto
                            WHERE IdOrden = @IdOrden GROUP BY IdRepuesto) x ON x.IdRepuesto = r.IdRepuesto;

            INSERT INTO HistorialEstado (IdOrden, EstadoAnterior, EstadoNuevo, Usuario, Comentario)
            VALUES (@IdOrden, @EstadoActual, @EstadoNuevo, @Usuario, @Comentario);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* 4. Agregar servicio con mecánico asignado (copia precio y tarifa del momento) */
CREATE OR ALTER PROCEDURE sp_AgregarServicioOrden
    @IdOrden INT, @IdServicio INT, @IdMecanico INT, @HorasManoObra DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM OrdenTrabajo WHERE IdOrden = @IdOrden AND IdEstado IN (1,2,3))
            THROW 50020, 'Solo se pueden agregar servicios a órdenes abiertas (antes de Terminado).', 1;
        IF NOT EXISTS (SELECT 1 FROM Mecanico WHERE IdMecanico = @IdMecanico AND Activo = 1)
            THROW 50021, 'Mecánico no válido o inactivo.', 1;

        INSERT INTO OrdenServicio (IdOrden, IdServicio, IdMecanico, Precio, HorasManoObra, TarifaHora)
        SELECT @IdOrden, s.IdServicio, @IdMecanico, s.PrecioBase, @HorasManoObra, m.TarifaHora
        FROM Servicio s CROSS JOIN Mecanico m
        WHERE s.IdServicio = @IdServicio AND s.Activo = 1 AND m.IdMecanico = @IdMecanico;

        IF @@ROWCOUNT = 0 THROW 50022, 'Servicio no válido.', 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* 5. Agregar repuesto: descuenta inventario (transacción, afecta 2 tablas) */
CREATE OR ALTER PROCEDURE sp_AgregarRepuestoOrden
    @IdOrden INT, @IdRepuesto INT, @Cantidad INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
            IF NOT EXISTS (SELECT 1 FROM OrdenTrabajo WHERE IdOrden = @IdOrden AND IdEstado IN (1,2,3))
                THROW 50030, 'Solo se pueden agregar repuestos a órdenes abiertas.', 1;

            DECLARE @Stock INT, @Precio DECIMAL(10,2);
            SELECT @Stock = Stock, @Precio = Precio FROM Repuesto WITH (UPDLOCK) WHERE IdRepuesto = @IdRepuesto;

            IF @Stock IS NULL THROW 50031, 'Repuesto no existe.', 1;
            IF @Stock < @Cantidad THROW 50032, 'Stock insuficiente para el repuesto.', 1;

            UPDATE Repuesto SET Stock = Stock - @Cantidad WHERE IdRepuesto = @IdRepuesto;

            INSERT INTO OrdenRepuesto (IdOrden, IdRepuesto, Cantidad, PrecioUnitario)
            VALUES (@IdOrden, @IdRepuesto, @Cantidad, @Precio);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* 6. Registrar pago: no permite pagar más que el saldo */
CREATE OR ALTER PROCEDURE sp_RegistrarPago
    @IdOrden INT, @IdMetodoPago TINYINT, @Monto DECIMAL(10,2), @Referencia NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;
            IF NOT EXISTS (SELECT 1 FROM OrdenTrabajo WITH (UPDLOCK) WHERE IdOrden = @IdOrden AND IdEstado <> 6)
                THROW 50040, 'Orden no válida o cancelada.', 1;

            DECLARE @Saldo DECIMAL(12,2) = dbo.fn_TotalOrden(@IdOrden) - dbo.fn_PagadoOrden(@IdOrden);
            IF @Monto <= 0 THROW 50041, 'El monto debe ser mayor a cero.', 1;
            IF @Monto > @Saldo THROW 50042, 'El monto excede el saldo pendiente de la orden.', 1;
            IF @IdMetodoPago <> 1 AND ISNULL(@Referencia,'') = ''
                THROW 50043, 'Los pagos con tarjeta o transferencia requieren referencia.', 1;

            INSERT INTO Pago (IdOrden, IdMetodoPago, Monto, Referencia)
            VALUES (@IdOrden, @IdMetodoPago, @Monto, @Referencia);
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
GO

/* 7. Actualizar diagnóstico / observaciones / descuento */
CREATE OR ALTER PROCEDURE sp_ActualizarDiagnostico
    @IdOrden INT, @Diagnostico NVARCHAR(1000), @Observaciones NVARCHAR(1000), @Descuento DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM OrdenTrabajo WHERE IdOrden = @IdOrden AND IdEstado IN (1,2,3,4))
        THROW 50050, 'La orden está cerrada y no puede modificarse.', 1;
    IF @Descuento < 0 OR @Descuento > dbo.fn_TotalOrden(@IdOrden) + (SELECT Descuento FROM OrdenTrabajo WHERE IdOrden=@IdOrden)
        THROW 50051, 'Descuento no válido.', 1;

    UPDATE OrdenTrabajo
       SET Diagnostico = NULLIF(@Diagnostico,''), Observaciones = @Observaciones, Descuento = @Descuento
     WHERE IdOrden = @IdOrden;
END;
GO

/* 8. Historial completo de un vehículo por placa */
CREATE OR ALTER PROCEDURE sp_HistorialVehiculo @Placa NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_HistorialServiciosVehiculo WHERE Placa = @Placa ORDER BY FechaIngreso DESC;
END;
GO

/* 9. Reportes: un SP con parámetro de rango de fechas */
CREATE OR ALTER PROCEDURE sp_ReporteIngresos @Desde DATE, @Hasta DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT mp.Nombre AS Metodo, COUNT(*) AS Pagos, SUM(p.Monto) AS Total,
           AVG(p.Monto) AS Promedio, MAX(p.Monto) AS Mayor, MIN(p.Monto) AS Menor
    FROM Pago p INNER JOIN MetodoPago mp ON mp.IdMetodoPago = p.IdMetodoPago
    WHERE CAST(p.FechaPago AS DATE) BETWEEN @Desde AND @Hasta
    GROUP BY mp.Nombre
    ORDER BY Total DESC;
END;
GO

/* ---------------------------------------------------------------
   Datos de prueba de órdenes (usa los SP anteriores)
   --------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM OrdenTrabajo)
BEGIN
    EXEC sp_CrearOrden 1, 85500, N'Ruido al frenar', NULL, 'admin';
    EXEC sp_AgregarServicioOrden 1, 3, 2, 1.5;
    EXEC sp_AgregarRepuestoOrden 1, 3, 1;
    EXEC sp_ActualizarDiagnostico 1, N'Pastillas delanteras gastadas', NULL, 0;
    EXEC sp_CambiarEstadoOrden 1, 2, 'admin';
    EXEC sp_CambiarEstadoOrden 1, 3, 'admin';
    EXEC sp_CambiarEstadoOrden 1, 4, 'admin';
    DECLARE @t DECIMAL(12,2) = dbo.fn_TotalOrden(1);
    EXEC sp_RegistrarPago 1, 1, @t;
    EXEC sp_CambiarEstadoOrden 1, 5, 'admin', N'Entregado al cliente';

    EXEC sp_CrearOrden 3, 61000, N'Servicio de mantenimiento', NULL, 'admin';
    EXEC sp_AgregarServicioOrden 2, 1, 1, 0.5;
    EXEC sp_AgregarServicioOrden 2, 5, 1, 2;
    EXEC sp_AgregarRepuestoOrden 2, 1, 2;
    EXEC sp_AgregarRepuestoOrden 2, 2, 1;
    EXEC sp_AgregarRepuestoOrden 2, 4, 4;
    EXEC sp_CambiarEstadoOrden 2, 2, 'admin';

    EXEC sp_CrearOrden 2, 121000, N'No enciende en las mañanas', NULL, 'admin';
END;
GO

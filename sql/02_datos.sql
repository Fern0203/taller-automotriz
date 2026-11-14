/* Script 02: catálogos y datos de prueba */
USE TallerDB;
GO

/* ---- Departamentos de Guatemala ---- */
INSERT INTO Departamento (IdDepartamento, Nombre) VALUES
(1,N'Guatemala'),(2,N'El Progreso'),(3,N'Sacatepéquez'),(4,N'Chimaltenango'),(5,N'Escuintla'),
(6,N'Santa Rosa'),(7,N'Sololá'),(8,N'Totonicapán'),(9,N'Quetzaltenango'),(10,N'Suchitepéquez'),
(11,N'Retalhuleu'),(12,N'San Marcos'),(13,N'Huehuetenango'),(14,N'Quiché'),(15,N'Baja Verapaz'),
(16,N'Alta Verapaz'),(17,N'Petén'),(18,N'Izabal'),(19,N'Zacapa'),(20,N'Chiquimula'),
(21,N'Jalapa'),(22,N'Jutiapa');

/* ---- Municipios: los 17 del departamento de Guatemala + cabeceras del resto ---- */
INSERT INTO Municipio (IdDepartamento, Nombre) VALUES
(1,N'Guatemala'),(1,N'Santa Catarina Pinula'),(1,N'San José Pinula'),(1,N'San José del Golfo'),
(1,N'Palencia'),(1,N'Chinautla'),(1,N'San Pedro Ayampuc'),(1,N'Mixco'),(1,N'San Pedro Sacatepéquez'),
(1,N'San Juan Sacatepéquez'),(1,N'San Raymundo'),(1,N'Chuarrancho'),(1,N'Fraijanes'),(1,N'Amatitlán'),
(1,N'Villa Nueva'),(1,N'Villa Canales'),(1,N'San Miguel Petapa'),
(2,N'Guastatoya'),(3,N'Antigua Guatemala'),(4,N'Chimaltenango'),(5,N'Escuintla'),(6,N'Cuilapa'),
(7,N'Sololá'),(8,N'Totonicapán'),(9,N'Quetzaltenango'),(10,N'Mazatenango'),(11,N'Retalhuleu'),
(12,N'San Marcos'),(13,N'Huehuetenango'),(14,N'Santa Cruz del Quiché'),(15,N'Salamá'),
(16,N'Cobán'),(17,N'Flores'),(18,N'Puerto Barrios'),(19,N'Zacapa'),(20,N'Chiquimula'),
(21,N'Jalapa'),(22,N'Jutiapa');

/* ---- Vehículos: marcas, modelos y colores ---- */
INSERT INTO Marca (Nombre) VALUES (N'Toyota'),(N'Honda'),(N'Nissan'),(N'Mazda'),(N'Hyundai'),
                                  (N'Kia'),(N'Mitsubishi'),(N'Isuzu'),(N'Suzuki'),(N'Chevrolet');

INSERT INTO Modelo (IdMarca, Nombre) VALUES
(1,N'Corolla'),(1,N'Hilux'),(1,N'Yaris'),(1,N'RAV4'),
(2,N'Civic'),(2,N'CR-V'),(2,N'Fit'),
(3,N'Sentra'),(3,N'Frontier'),(3,N'Versa'),
(4,N'Mazda 3'),(4,N'CX-5'),
(5,N'H100'),(5,N'Tucson'),(5,N'Accent'),
(6,N'Rio'),(6,N'Sportage'),
(7,N'L200'),(7,N'Montero'),
(8,N'NPR'),(8,N'D-Max'),
(9,N'Swift'),(9,N'Vitara'),
(10,N'Aveo'),(10,N'Spark');

INSERT INTO Color (Nombre) VALUES (N'Blanco'),(N'Negro'),(N'Gris'),(N'Plateado'),(N'Rojo'),
                                  (N'Azul'),(N'Verde'),(N'Beige'),(N'Café'),(N'Amarillo');

/* ---- Otros catálogos ---- */
INSERT INTO EstadoOrden (IdEstado, Nombre, Secuencia) VALUES
(1,N'Recibido',1),(2,N'Diagnóstico',2),(3,N'Reparación',3),(4,N'Terminado',4),(5,N'Entregado',5),(6,N'Cancelado',9);

INSERT INTO MetodoPago (Nombre) VALUES (N'Efectivo'),(N'Tarjeta'),(N'Transferencia');

INSERT INTO Especialidad (Nombre) VALUES (N'Motor'),(N'Frenos'),(N'Electricidad'),(N'Suspensión'),(N'Transmisión');

INSERT INTO Servicio (Nombre, Descripcion, PrecioBase) VALUES
(N'Cambio de aceite',N'Aceite y filtro',250),
(N'Alineación y balanceo',N'Cuatro llantas',200),
(N'Cambio de pastillas de freno',N'Eje delantero',300),
(N'Diagnóstico computarizado',N'Escáner OBD-II',150),
(N'Afinamiento mayor',N'Bujías, filtros, limpieza de inyectores',650),
(N'Revisión eléctrica',N'Batería, alternador y cableado',180);

INSERT INTO Repuesto (Codigo, Nombre, Precio, Stock, StockMinimo) VALUES
(N'ACE-5W30',N'Aceite 5W-30 (galón)',180,20,5),
(N'FIL-ACE',N'Filtro de aceite',45,30,10),
(N'PAS-DEL',N'Pastillas de freno delanteras',320,8,4),
(N'BUJ-IR',N'Bujía de iridio',75,40,12),
(N'BAT-12V',N'Batería 12V',850,3,4);

/* ---- Mecánicos ---- */
INSERT INTO Mecanico (Nombres, Apellidos, Telefono, TarifaHora) VALUES
(N'Carlos',N'López',N'55112233',60),
(N'Mario',N'Pérez',N'55223344',55),
(N'Luis',N'Ajú',N'55334455',70);

INSERT INTO MecanicoEspecialidad VALUES (1,1),(1,5),(2,2),(2,4),(3,3),(3,1);

/* ---- Clientes, teléfonos y vehículos ---- */
INSERT INTO Cliente (Nombres, Apellidos, NIT, Correo, Calle, Zona, IdMunicipio) VALUES
(N'Ana Lucía',N'García Morales',N'12345678',N'ana@correo.com',N'5a. Av. 10-25',1,1),
(N'José Miguel',N'Méndez',N'CF',NULL,N'Calzada San Juan 15-40',4,8),
(N'Transportes El Rápido S.A.',NULL,N'98765432',N'info@elrapido.com',N'Av. Petapa 45-10',12,1);

INSERT INTO TelefonoCliente (IdCliente, Numero, Tipo, Principal) VALUES
(1,N'44556677',N'Móvil',1),(1,N'22334455',N'Casa',0),
(2,N'33445566',N'Móvil',1),
(3,N'22334400',N'Trabajo',1),(3,N'55667788',N'Móvil',0);

INSERT INTO Vehiculo (IdCliente, Placa, IdModelo, Anio, IdColor, Kilometraje) VALUES
(1,N'P123ABC',1,2018,3,85000),     -- Toyota Corolla gris
(2,N'P456DEF',5,2015,2,120000),    -- Honda Civic negro
(3,N'C789GHI',20,2020,1,60000),    -- Isuzu NPR blanco
(3,N'C321JKL',13,2019,1,95000);    -- Hyundai H100 blanco
GO

/* Las órdenes de ejemplo se crean al final del script 04 usando los procedimientos */

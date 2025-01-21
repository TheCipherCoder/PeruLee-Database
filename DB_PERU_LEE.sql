CREATE DATABASE DB_Peru_Lee
GO

USE DB_Peru_Lee

GO

/********************************************************************************************/
-- TABLAS 
/********************************************************************************************/
CREATE TABLE tbl_rol(
	id_rol INT IDENTITY(1,1) PRIMARY KEY,
	rol NVARCHAR(10) NOT NULL
);
GO
CREATE TABLE tbl_usuario (
    id_usuario INT IDENTITY(1000,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    apellido NVARCHAR(100) NOT NULL,
    email NVARCHAR(100) UNIQUE NOT NULL,
    contrasena NVARCHAR(7) NOT NULL,
    telefono NVARCHAR(9),
	imagen NVARCHAR(400) DEFAULT 'https://svgsilh.com/png-512/2098873.png',
    rol INT REFERENCES tbl_rol(id_rol), -- Administrador : 1, Trabajador:2, Usuario:3
    fecha_registro DATETIME DEFAULT GETDATE()
);
GO
CREATE TABLE tbl_categoria (
    id_categoria INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL
);
GO
CREATE TABLE tbl_autor (
    id_autor INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    apellido NVARCHAR(100) NOT NULL
);
GO
CREATE TABLE tbl_libro (
    id_libro INT IDENTITY(10000,1) PRIMARY KEY,
    titulo NVARCHAR(200) NOT NULL,
    fecha_publicacion DATETIME,
    id_categoria_fk INT,
    id_autor_fk INT,
    copias_disponibles INT NOT NULL DEFAULT 1 CHECK (copias_disponibles >= 0),
    estado BIT DEFAULT 1, -- Disponible : 1 , No disponible : 0
    CONSTRAINT FK_Libro_Categoria FOREIGN KEY (id_categoria_fk) REFERENCES tbl_categoria(id_categoria) ON DELETE SET NULL,    
    CONSTRAINT FK_Libro_Autor FOREIGN KEY (id_autor_fk) REFERENCES tbl_autor(id_autor) ON DELETE SET NULL
);
GO
CREATE TABLE tbl_prestamo (
    id_prestamo INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario_fk INT,
    id_libro_fk INT,
    fecha_prestamo DATETIME DEFAULT GETDATE(),
    fecha_devolucion DATETIME,
    fecha_devolucion_real DATETIME,
    estado TINYINT DEFAULT 0, -- Pendiente : 0 , Entregado: 1, Libro Eliminado: 2
    CONSTRAINT FK_Prestamo_Usuario FOREIGN KEY (id_usuario_fk) REFERENCES tbl_usuario(id_usuario),
    CONSTRAINT FK_Prestamo_Libro FOREIGN KEY (id_libro_fk) REFERENCES tbl_libro(id_libro) ON DELETE SET NULL
);
GO
CREATE TABLE tbl_solicitud (
    id_solicitud INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario_fk INT,
    id_libro_fk INT,
    fecha_solicitud DATETIME DEFAULT GETDATE(),
    estado TINYINT DEFAULT 0, -- 0: Pendiente, 1: Procesada, 2: Cancelada, 3: Expirada
    reclamada BIT DEFAULT 0, -- 0: No Reclamada, 1: Reclamada
    fecha_expiracion DATETIME, -- La reserva expira si no se reclama en cierto tiempo
    fecha_procesamiento DATETIME, -- Cuando se convierte en préstamo o se cancela
    CONSTRAINT FK_Solicitud_Usuario FOREIGN KEY (id_usuario_fk) REFERENCES tbl_usuario(id_usuario),
    CONSTRAINT FK_Solicitud_Libro FOREIGN KEY (id_libro_fk) REFERENCES tbl_libro(id_libro) ON DELETE CASCADE
);
GO

/********************************************************************************************/
-- STORE PROCEDURES (CRUD) por cada tabla
/********************************************************************************************/

-- Store Procedures para Usuario
CREATE OR ALTER PROCEDURE sp_crear_usuario
    @nombre NVARCHAR(100),
    @apellido NVARCHAR(100),
    @email NVARCHAR(100),
    @contrasena NVARCHAR(7),
    @telefono NVARCHAR(9),
    @imagen NVARCHAR(400),
    @rol INT, 
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        -- Validar el rol (1: Administrador, 2: Trabajador, 3: Usuario)
        IF @rol NOT IN (1, 2, 3)
        BEGIN
            SET @mensaje = 'Rol inválido. Debe ser 1 (Administrador), 2 (Trabajador) o 3 (Usuario)';
            RETURN;
        END

        INSERT INTO tbl_usuario (nombre, apellido, email, contrasena, telefono, imagen, rol)
        VALUES (@nombre, @apellido, @email, @contrasena, @telefono, @imagen, @rol);
        
        SET @mensaje = 'Usuario creado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_actualizar_usuario
    @id_usuario INT,
    @nombre NVARCHAR(100),
    @apellido NVARCHAR(100),
    @email NVARCHAR(100),
    @contrasena NVARCHAR(7),
    @telefono NVARCHAR(9),
    @imagen NVARCHAR(400),
    @rol INT, -- Cambiado de BIT a INT
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        -- Validar el rol
        IF @rol NOT IN (1, 2, 3)
        BEGIN
            SET @mensaje = 'Rol inválido. Debe ser 1 (Administrador), 2 (Trabajador) o 3 (Usuario)';
            RETURN;
        END

        UPDATE tbl_usuario
        SET nombre = @nombre,
            apellido = @apellido,
            email = @email,
            contrasena = @contrasena,
            telefono = @telefono,
            imagen = @imagen,
            rol = @rol
        WHERE id_usuario = @id_usuario;
        
        SET @mensaje = 'Usuario actualizado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_listar_usuarios
AS
BEGIN
    SELECT id_usuario, nombre, apellido, email, telefono, imagen ,rol, fecha_registro
    FROM tbl_usuario;
END;
GO

CREATE OR ALTER PROCEDURE sp_actualizar_usuario
    @id_usuario INT,
    @nombre NVARCHAR(100),
    @apellido NVARCHAR(100),
    @email NVARCHAR(100),
    @contrasena NVARCHAR(7),
    @telefono NVARCHAR(9),
	@imagen NVARCHAR(200),
    @rol BIT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        UPDATE tbl_usuario
        SET nombre = @nombre,
            apellido = @apellido,
            email = @email,
            contrasena = @contrasena,
            telefono = @telefono,
			imagen = @imagen,
            rol = @rol
        WHERE id_usuario = @id_usuario;
        SET @mensaje = 'Usuario actualizado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_eliminar_usuario
    @id_usuario INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        -- Verificar si el usuario tiene préstamos pendientes
        IF EXISTS (
            SELECT 1 
            FROM tbl_prestamo 
            WHERE id_usuario_fk = @id_usuario 
            AND estado = 0
        )
        BEGIN
            SET @mensaje = 'No se puede eliminar el usuario porque tiene préstamos pendientes.';
            RETURN;
        END

        DELETE FROM tbl_usuario WHERE id_usuario = @id_usuario;
        SET @mensaje = 'Usuario eliminado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Store Procedures para Categoria
CREATE OR ALTER PROCEDURE sp_crear_categoria
    @nombre NVARCHAR(100),
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        INSERT INTO tbl_categoria (nombre)
        VALUES (@nombre);
        SET @mensaje = 'Categoría creada exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_listar_categorias
AS
BEGIN
    SELECT id_categoria, nombre FROM tbl_categoria;
END;
GO

CREATE OR ALTER PROCEDURE sp_actualizar_categoria
    @id_categoria INT,
    @nombre NVARCHAR(100),
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        UPDATE tbl_categoria
        SET nombre = @nombre
        WHERE id_categoria = @id_categoria;
        SET @mensaje = 'Categoría actualizada exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_eliminar_categoria
    @id_categoria INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        -- Los libros quedarán con categoría NULL (ya está manejado por ON DELETE SET NULL)
        DELETE FROM tbl_categoria WHERE id_categoria = @id_categoria;
        SET @mensaje = 'Categoría eliminada exitosamente. Los libros asociados han quedado sin categoría.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Store Procedures para Autor
CREATE OR ALTER PROCEDURE sp_crear_autor
    @nombre NVARCHAR(100),
    @apellido NVARCHAR(100),
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        INSERT INTO tbl_autor (nombre, apellido)
        VALUES (@nombre, @apellido);
        SET @mensaje = 'Autor creado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_listar_autores
AS
BEGIN
    SELECT id_autor, nombre, apellido FROM tbl_autor;
END;
GO

CREATE OR ALTER PROCEDURE sp_actualizar_autor
    @id_autor INT,
    @nombre NVARCHAR(100),
    @apellido NVARCHAR(100),
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        UPDATE tbl_autor
        SET nombre = @nombre,
            apellido = @apellido
        WHERE id_autor = @id_autor;
        SET @mensaje = 'Autor actualizado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_eliminar_autor
    @id_autor INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        -- Los libros quedarán con autor NULL (ya está manejado por ON DELETE SET NULL)
        DELETE FROM tbl_autor WHERE id_autor = @id_autor;
        SET @mensaje = 'Autor eliminado exitosamente. Los libros asociados han quedado sin autor.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Store Procedures para Libro
CREATE OR ALTER PROCEDURE sp_crear_libro
    @titulo NVARCHAR(200),
    @fecha_publicacion DATETIME,
    @id_categoria_fk INT,
    @id_autor_fk INT,
    @copias_disponibles INT,
    @estado BIT = 1,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        INSERT INTO tbl_libro (titulo, fecha_publicacion, id_categoria_fk, id_autor_fk, copias_disponibles, estado)
        VALUES (@titulo, @fecha_publicacion, @id_categoria_fk, @id_autor_fk, @copias_disponibles, @estado);
        SET @mensaje = 'Libro creado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_listar_libros
AS
BEGIN
    SELECT 
        l.id_libro, 
        l.titulo, 
        l.fecha_publicacion, 
        ISNULL(c.nombre, 'Sin categoría') AS categoria, 
        ISNULL(a.nombre + ' ' + a.apellido, 'Autor desconocido') AS autor, 
        l.copias_disponibles,
        CASE 
            WHEN l.estado = 1 THEN 'Disponible'
            ELSE 'No Disponible'
        END AS estado
    FROM tbl_libro l
    LEFT JOIN tbl_categoria c ON l.id_categoria_fk = c.id_categoria
    LEFT JOIN tbl_autor a ON l.id_autor_fk = a.id_autor;
END;
GO

CREATE OR ALTER PROCEDURE sp_actualizar_libro
    @id_libro INT,
    @titulo NVARCHAR(200),
    @fecha_publicacion DATETIME,
    @id_categoria_fk INT,
    @id_autor_fk INT,
    @copias_disponibles INT,
    @estado BIT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        UPDATE tbl_libro
        SET titulo = @titulo,
            fecha_publicacion = @fecha_publicacion,
            id_categoria_fk = @id_categoria_fk,
            id_autor_fk = @id_autor_fk,
            copias_disponibles = @copias_disponibles,
            estado = @estado
        WHERE id_libro = @id_libro;
        SET @mensaje = 'Libro actualizado exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_eliminar_libro
    @id_libro INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
            -- Verificar si el libro tiene préstamos pendientes
            IF EXISTS (
                SELECT 1 
                FROM tbl_prestamo 
                WHERE id_libro_fk = @id_libro 
                AND estado = 0
            )
            BEGIN
                SET @mensaje = 'No se puede eliminar el libro porque tiene préstamos pendientes.';
                ROLLBACK;
                RETURN;
            END

            -- Marcar préstamos históricos como "libro eliminado"
            UPDATE tbl_prestamo
            SET estado = 2  -- Libro Eliminado
            WHERE id_libro_fk = @id_libro 
            AND estado = 1; -- Solo los entregados

            -- Eliminar el libro
            DELETE FROM tbl_libro WHERE id_libro = @id_libro;

            SET @mensaje = 'Libro eliminado exitosamente.';
            COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

/********************************************************************************************/
-- STORE PROCEDURES para las TRANSACCIONES
/********************************************************************************************/

-- Store Procedure para Préstamo
CREATE OR ALTER PROCEDURE sp_prestar_libro
    @id_usuario INT,
    @id_libro INT,
    @fecha_devolucion DATETIME,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validar que la fecha de devolución no exceda 30 días
        IF DATEDIFF(day, GETDATE(), @fecha_devolucion) > 30
        BEGIN
            SET @mensaje = 'El período máximo de préstamo es de 30 días.';
            ROLLBACK;
            RETURN;
        END

        -- Verificar si hay una reserva pendiente para este libro
        DECLARE @id_usuario_primera_reserva INT;
        SELECT TOP 1 @id_usuario_primera_reserva = id_usuario_fk
        FROM tbl_reserva
        WHERE id_libro_fk = @id_libro
        AND estado = 0
        ORDER BY fecha_reserva;

        -- Si hay una reserva pendiente, verificar si corresponde al usuario actual
        IF @id_usuario_primera_reserva IS NOT NULL 
        AND @id_usuario_primera_reserva != @id_usuario
        BEGIN
            SET @mensaje = 'Este libro está reservado para otro usuario.';
            ROLLBACK;
            RETURN;
        END

        -- Verificar límite de préstamos activos (5)
        DECLARE @prestamos_activos INT;
        SELECT @prestamos_activos = COUNT(*)
        FROM tbl_prestamo
        WHERE id_usuario_fk = @id_usuario 
        AND estado = 0;

        IF @prestamos_activos >= 5
        BEGIN
            SET @mensaje = 'El usuario ya tiene el máximo de 5 préstamos activos permitidos.';
            ROLLBACK;
            RETURN;
        END

        -- Verificar si el usuario ya tiene un préstamo activo de este libro
        IF EXISTS (
            SELECT 1 
            FROM tbl_prestamo 
            WHERE id_usuario_fk = @id_usuario 
            AND id_libro_fk = @id_libro 
            AND estado = 0
        )
        BEGIN
            SET @mensaje = 'El usuario ya tiene un préstamo activo de este libro.';
            ROLLBACK;
            RETURN;
        END

        -- Verificar si hay copias disponibles
        DECLARE @copias_disponibles INT;
        SELECT @copias_disponibles = copias_disponibles
        FROM tbl_libro
        WHERE id_libro = @id_libro;

        IF @copias_disponibles <= 0
        BEGIN
            SET @mensaje = 'No hay copias disponibles de este libro.';
            ROLLBACK;
            RETURN;
        END

        -- Si el usuario tenía una reserva, marcarla como procesada
        IF @id_usuario_primera_reserva = @id_usuario
        BEGIN
            UPDATE tbl_reserva
            SET estado = 1,
                fecha_procesamiento = GETDATE()
            WHERE id_usuario_fk = @id_usuario
            AND id_libro_fk = @id_libro
            AND estado = 0;
        END

        -- Registrar el préstamo
        INSERT INTO tbl_prestamo (id_usuario_fk, id_libro_fk, fecha_devolucion, estado)
        VALUES (@id_usuario, @id_libro, @fecha_devolucion, 0);

        -- Actualizar copias disponibles
        UPDATE tbl_libro
        SET copias_disponibles = copias_disponibles - 1
        WHERE id_libro = @id_libro;

        SET @mensaje = 'Préstamo registrado exitosamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Procedimiento para devolver libro
CREATE OR ALTER PROCEDURE sp_devolver_libro
    @id_prestamo INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @id_libro INT;
        DECLARE @estado_actual TINYINT;
        
        -- Obtener información del préstamo
        SELECT 
            @id_libro = id_libro_fk,
            @estado_actual = estado
        FROM tbl_prestamo 
        WHERE id_prestamo = @id_prestamo;

        -- Validaciones
        IF @id_libro IS NULL
        BEGIN
            SET @mensaje = 'No se encontró el préstamo especificado.';
            ROLLBACK;
            RETURN;
        END

        IF @estado_actual = 1
        BEGIN
            SET @mensaje = 'Este préstamo ya fue devuelto.';
            ROLLBACK;
            RETURN;
        END

        IF @estado_actual = 2
        BEGIN
            SET @mensaje = 'No se puede procesar la devolución porque el libro fue eliminado.';
            ROLLBACK;
            RETURN;
        END
        
        -- Actualizar el préstamo
        UPDATE tbl_prestamo
        SET estado = 1, -- Entregado
            fecha_devolucion_real = GETDATE()
        WHERE id_prestamo = @id_prestamo;
        
        -- Incrementar copias disponibles
        UPDATE tbl_libro
        SET copias_disponibles = copias_disponibles + 1
        WHERE id_libro = @id_libro;
        
        SET @mensaje = 'Devolución procesada exitosamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Procedimiento para consultar todos los préstamos
CREATE OR ALTER PROCEDURE sp_consultar_prestamos
    @estado TINYINT = NULL -- Parámetro opcional para filtrar por estado
AS
BEGIN
    SELECT 
        p.id_prestamo,
        -- Información del Usuario
        u.id_usuario,
        CONCAT(u.nombre, ' ', u.apellido) AS nombre_usuario,
        u.email,
        -- Información del Libro
        l.id_libro,
        l.titulo AS titulo_libro,
        -- Información del Autor y Categoría
        ISNULL(CONCAT(a.nombre, ' ', a.apellido), 'Autor desconocido') AS autor,
        ISNULL(c.nombre, 'Sin categoría') AS categoria,
        -- Información del Préstamo
        p.fecha_prestamo,
        p.fecha_devolucion,
        p.fecha_devolucion_real,
        CASE 
            WHEN p.estado = 0 THEN 'Pendiente'
            WHEN p.estado = 1 THEN 'Entregado'
            WHEN p.estado = 2 THEN 'Libro Eliminado'
            ELSE 'Desconocido'
        END AS estado_prestamo,
        -- Indicador de atraso
        CASE 
            WHEN p.estado = 0 AND GETDATE() > p.fecha_devolucion THEN 'ATRASADO'
            WHEN p.estado = 0 AND DATEDIFF(day, GETDATE(), p.fecha_devolucion) <= 3 THEN 'POR VENCER'
            ELSE ''
        END AS alerta
    FROM tbl_prestamo p
    INNER JOIN tbl_usuario u ON p.id_usuario_fk = u.id_usuario
    LEFT JOIN tbl_libro l ON p.id_libro_fk = l.id_libro
    LEFT JOIN tbl_autor a ON l.id_autor_fk = a.id_autor
    LEFT JOIN tbl_categoria c ON l.id_categoria_fk = c.id_categoria
    WHERE (@estado IS NULL OR p.estado = @estado)
    ORDER BY 
        CASE 
            WHEN p.estado = 0 AND GETDATE() > p.fecha_devolucion THEN 0
            ELSE p.estado 
        END,
        p.fecha_prestamo DESC;
END;
GO

-- Procedimiento para consultar préstamos por usuario
CREATE OR ALTER PROCEDURE sp_consultar_prestamos_por_usuario
    @id_usuario INT,
    @incluir_historico BIT = 1  -- 1: muestra todos los préstamos, 0: solo activos
AS
BEGIN
    -- Verificar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM tbl_usuario WHERE id_usuario = @id_usuario)
    BEGIN
        RAISERROR ('El usuario especificado no existe.', 16, 1);
        RETURN;
    END

    -- Obtener préstamos del usuario
    SELECT 
        p.id_prestamo,
        -- Información del Libro
        l.id_libro,
        l.titulo AS titulo_libro,
        ISNULL(CONCAT(a.nombre, ' ', a.apellido), 'Autor desconocido') AS autor,
        ISNULL(c.nombre, 'Sin categoría') AS categoria,
        -- Información del Préstamo
        p.fecha_prestamo,
        p.fecha_devolucion,
        p.fecha_devolucion_real,
        CASE 
            WHEN p.estado = 0 THEN 'Pendiente'
            WHEN p.estado = 1 THEN 'Entregado'
            WHEN p.estado = 2 THEN 'Libro Eliminado'
            ELSE 'Desconocido'
        END AS estado_prestamo,
        -- Días de atraso (si aplica)
        CASE 
            WHEN p.estado = 0 AND GETDATE() > p.fecha_devolucion 
            THEN DATEDIFF(day, p.fecha_devolucion, GETDATE())
            WHEN p.estado = 1 AND p.fecha_devolucion_real > p.fecha_devolucion 
            THEN DATEDIFF(day, p.fecha_devolucion, p.fecha_devolucion_real)
            ELSE 0
        END AS dias_atraso,
        -- Alerta
        CASE 
            WHEN p.estado = 0 AND GETDATE() > p.fecha_devolucion THEN 'ATRASADO'
            WHEN p.estado = 0 AND DATEDIFF(day, GETDATE(), p.fecha_devolucion) <= 3 THEN 'POR VENCER'
            ELSE ''
        END AS alerta
    FROM tbl_prestamo p
    LEFT JOIN tbl_libro l ON p.id_libro_fk = l.id_libro
    LEFT JOIN tbl_autor a ON l.id_autor_fk = a.id_autor
    LEFT JOIN tbl_categoria c ON l.id_categoria_fk = c.id_categoria
    WHERE 
        p.id_usuario_fk = @id_usuario
        AND (@incluir_historico = 1 OR p.estado = 0) -- Solo préstamos activos si @incluir_historico = 0
    ORDER BY 
        CASE 
            WHEN p.estado = 0 AND GETDATE() > p.fecha_devolucion THEN 0
            ELSE p.estado 
        END,
        p.fecha_prestamo DESC;

    -- Mostrar resumen
    SELECT
        COUNT(CASE WHEN estado = 0 THEN 1 END) AS prestamos_pendientes,
        COUNT(CASE WHEN estado = 1 THEN 1 END) AS prestamos_entregados,
        COUNT(CASE WHEN estado = 2 THEN 1 END) AS prestamos_libro_eliminado,
        COUNT(*) AS total_prestamos
    FROM tbl_prestamo
    WHERE id_usuario_fk = @id_usuario;
END;
GO

-- Procedimiento para crear una reserva
CREATE OR ALTER PROCEDURE sp_solicitar
    @id_usuario INT,
    @id_libro INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Verificar si el libro existe y está disponible
        IF NOT EXISTS (SELECT 1 FROM tbl_libro WHERE id_libro = @id_libro AND estado = 1)
        BEGIN
            SET @mensaje = 'El libro no está disponible para reservas.';
            ROLLBACK;
            RETURN;
        END;

        -- 2. Eliminar solicitudes expiradas (FIFO: solicitudes más antiguas tienen prioridad)
        DELETE FROM tbl_reserva
        WHERE id_usuario_fk = @id_usuario
        AND DATEDIFF(DAY, fecha_expiracion, GETDATE()) > 1
        AND estado = 0;

        -- 3. Verificar límite de reservas activas por usuario (máximo 5)
        DECLARE @reservas_activas INT;
        SELECT @reservas_activas = COUNT(*) 
        FROM tbl_reserva 
        WHERE id_usuario_fk = @id_usuario 
        AND estado = 0;

        IF @reservas_activas >= 5
        BEGIN
            SET @mensaje = 'Has alcanzado el límite máximo de 5 reservas activas.';
            ROLLBACK;
            RETURN;
        END;

        -- 4. Verificar si el usuario ya tiene una reserva activa para este libro
        IF EXISTS (
            SELECT 1 
            FROM tbl_reserva 
            WHERE id_usuario_fk = @id_usuario 
            AND id_libro_fk = @id_libro 
            AND estado = 0
        )
        BEGIN
            SET @mensaje = 'Ya tienes una reserva activa para este libro.';
            ROLLBACK;
            RETURN;
        END;

        -- 5. Verificar si el usuario ya tiene el libro prestado
        IF EXISTS (
            SELECT 1 
            FROM tbl_prestamo 
            WHERE id_usuario_fk = @id_usuario 
            AND id_libro_fk = @id_libro 
            AND estado = 0
        )
        BEGIN
            SET @mensaje = 'Ya tienes este libro en préstamo.';
            ROLLBACK;
            RETURN;
        END;

        -- 6. Establecer fecha de expiración (1 día)
        DECLARE @fecha_expiracion DATETIME = DATEADD(DAY, 1, GETDATE());

        -- 7. Insertar la reserva en orden FIFO
        INSERT INTO tbl_reserva (id_usuario_fk, id_libro_fk, fecha_expiracion)
        VALUES (@id_usuario, @id_libro, @fecha_expiracion);

        SET @mensaje = 'Reserva creada exitosamente. Expira el ' + 
                      FORMAT(@fecha_expiracion, 'dd/MM/yyyy HH:mm:ss');

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        SET @mensaje = ERROR_MESSAGE();
    END CATCH;
END;
GO

-- Procedimiento para procesar reservas pendientes
CREATE OR ALTER PROCEDURE sp_procesar_solicitud
    @id_reserva INT
AS
BEGIN
    BEGIN TRY
        DECLARE @estado_actual TINYINT, @fecha_expiracion DATE;

        -- Verificar si la reserva existe
        IF NOT EXISTS (SELECT 1 FROM tbl_reserva WHERE id_reserva = @id_reserva)
        BEGIN
            THROW 50001, 'La reserva no existe.', 1;
        END

        -- Obtener el estado y la fecha de expiración de la reserva
        SELECT @estado_actual = estado, @fecha_expiracion = fecha_expiracion
        FROM tbl_reserva
        WHERE id_reserva = @id_reserva;

        -- Validar si la reserva ya fue procesada o cancelada
        IF @estado_actual IN (1, 2)
        BEGIN
            THROW 50002, 'La reserva ya fue procesada o cancelada.', 1;
        END

        -- Validar si la reserva ha expirado
        IF @estado_actual = 0 AND @fecha_expiracion < GETDATE()
        BEGIN
            THROW 50003, 'La reserva ha expirado y no puede ser procesada.', 1;
        END

        -- Marcar la reserva como procesada
        UPDATE tbl_reserva
        SET estado = 1,
            fecha_procesamiento = GETDATE()
        WHERE id_reserva = @id_reserva;

        PRINT 'Reserva procesada correctamente.';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Procedimiento para cancelar una reserva
CREATE OR ALTER PROCEDURE sp_cancelar_solicitud
    @id_solicitud INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        -- Verificar si la solicitud existe y está pendiente
        IF NOT EXISTS (
            SELECT 1 
            FROM tbl_solicitud 
            WHERE id_solicitud = @id_solicitud 
            AND estado = 0
        )
        BEGIN
            SET @mensaje = 'La solicitud no existe o ya no está pendiente.';
            RETURN;
        END

        -- Cancelar la solicitud
        UPDATE tbl_solicitud
        SET estado = 2,
            fecha_procesamiento = GETDATE()
        WHERE id_solicitud = @id_solicitud;

        SET @mensaje = 'Solicitud cancelada exitosamente.';
    END TRY
    BEGIN CATCH
        SET @mensaje = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Procedimiento para consultar solicitudes de un usuario
CREATE OR ALTER PROCEDURE sp_consultar_solicitudes_usuario
    @id_usuario INT
AS
BEGIN
    SELECT 
        s.id_solicitud,
        l.titulo AS libro,
        s.fecha_solicitud,
        CASE s.estado
            WHEN 0 THEN 'Pendiente'
            WHEN 1 THEN 'Procesada'
            WHEN 2 THEN 'Cancelada'
            WHEN 3 THEN 'Expirada'
        END AS estado,
        l.copias_disponibles,
        CASE 
            WHEN s.estado = 0 AND l.copias_disponibles > 0 THEN 'Disponible para préstamo'
            WHEN s.estado = 0 THEN 'En espera de disponibilidad'
            ELSE ''
        END AS observacion
    FROM tbl_solicitud s
    INNER JOIN tbl_libro l ON s.id_libro_fk = l.id_libro
    WHERE s.id_usuario_fk = @id_usuario
    ORDER BY s.fecha_solicitud DESC;
END;
GO

CREATE OR ALTER PROCEDURE sp_listar_solicitudes
    @estado TINYINT = NULL -- Parámetro opcional para filtrar por estado
AS
BEGIN
    SELECT 
        s.id_solicitud,
        -- Información del Usuario
        u.id_usuario,
        CONCAT(u.nombre, ' ', u.apellido) AS nombre_usuario,
        u.email,
        u.telefono,
        
        -- Información del Libro
        l.id_libro,
        l.titulo AS titulo_libro,
        ISNULL(CONCAT(a.nombre, ' ', a.apellido), 'Autor desconocido') AS autor,
        ISNULL(c.nombre, 'Sin categoría') AS categoria,
        l.copias_disponibles,
        
        -- Información de la Solicitud
        s.fecha_solicitud,
        s.fecha_expiracion,
        s.fecha_procesamiento,
        CASE s.estado
            WHEN 0 THEN 'Pendiente'
            WHEN 1 THEN 'Procesada'
            WHEN 2 THEN 'Cancelada'
            WHEN 3 THEN 'Expirada'
        END AS estado_solicitud,
        
        -- Información adicional
        CASE 
            WHEN s.estado = 0 AND l.copias_disponibles > 0 THEN 'Libro disponible para préstamo'
            WHEN s.estado = 0 AND l.copias_disponibles = 0 THEN 'En espera de disponibilidad'
            WHEN s.estado = 0 AND s.fecha_expiracion < GETDATE() THEN 'Por expirar'
            ELSE ''
        END AS observaciones,
        
        -- Tiempo de espera
        CASE 
            WHEN s.estado = 0 THEN 
                DATEDIFF(day, s.fecha_solicitud, GETDATE())
            ELSE
                DATEDIFF(day, s.fecha_solicitud, ISNULL(s.fecha_procesamiento, GETDATE()))
        END AS dias_espera,
        
        -- Posición en la cola (solo para solicitudes pendientes)
        CASE 
            WHEN s.estado = 0 THEN (
                SELECT COUNT(*) 
                FROM tbl_solicitud s2 
                WHERE s2.id_libro_fk = s.id_libro_fk 
                AND s2.estado = 0 
                AND s2.fecha_solicitud <= s.fecha_solicitud
            )
            ELSE NULL
        END AS posicion_cola

    FROM tbl_solicitud s
    INNER JOIN tbl_usuario u ON s.id_usuario_fk = u.id_usuario
    INNER JOIN tbl_libro l ON s.id_libro_fk = l.id_libro
    LEFT JOIN tbl_autor a ON l.id_autor_fk = a.id_autor
    LEFT JOIN tbl_categoria c ON l.id_categoria_fk = c.id_categoria
    WHERE (@estado IS NULL OR s.estado = @estado)
    ORDER BY 
        s.estado,  -- Primero las pendientes
        s.fecha_solicitud ASC;  -- Las más antiguas primero
        
    -- Mostrar resumen de solicitudes
    SELECT 
        COUNT(CASE WHEN estado = 0 THEN 1 END) as solicitudes_pendientes,
        COUNT(CASE WHEN estado = 1 THEN 1 END) as solicitudes_procesadas,
        COUNT(CASE WHEN estado = 2 THEN 1 END) as solicitudes_canceladas,
        COUNT(CASE WHEN estado = 3 THEN 1 END) as solicitudes_expiradas,
        COUNT(*) as total_solicitudes
    FROM tbl_solicitud;
END;
GO

/********************************************************************************************/
-- INSERCIONES INICIALES
/********************************************************************************************/

-- Insertar Usuarios (incluyendo al menos un administrador)
DECLARE @mensaje NVARCHAR(200)
EXEC sp_crear_usuario 'Admin', 'Sistema', 'admin@biblioteca.com', 'admin123', '999999999', 1, @mensaje OUTPUT
EXEC sp_crear_usuario 'Juan', 'Pérez', 'juan@email.com', 'jp12345', '987654321', 0, @mensaje OUTPUT
EXEC sp_crear_usuario 'María', 'García', 'maria@email.com', 'mg12345', '912345678', 0, @mensaje OUTPUT
EXEC sp_crear_usuario 'Carlos', 'López', 'carlos@email.com', 'cl12345', '923456789', 0, @mensaje OUTPUT
EXEC sp_crear_usuario 'Ana', 'Martínez', 'ana@email.com', 'am12345', '934567890', 0, @mensaje OUTPUT

-- Insertar Categorías
EXEC sp_crear_categoria 'Novela', @mensaje OUTPUT
EXEC sp_crear_categoria 'Ciencia Ficción', @mensaje OUTPUT
EXEC sp_crear_categoria 'Historia', @mensaje OUTPUT
EXEC sp_crear_categoria 'Ciencia', @mensaje OUTPUT
EXEC sp_crear_categoria 'Literatura Clásica', @mensaje OUTPUT
EXEC sp_crear_categoria 'Poesía', @mensaje OUTPUT
EXEC sp_crear_categoria 'Biografía', @mensaje OUTPUT
EXEC sp_crear_categoria 'Informática', @mensaje OUTPUT

-- Insertar Autores
EXEC sp_crear_autor 'Gabriel', 'García Márquez', @mensaje OUTPUT
EXEC sp_crear_autor 'Isaac', 'Asimov', @mensaje OUTPUT
EXEC sp_crear_autor 'Jane', 'Austen', @mensaje OUTPUT
EXEC sp_crear_autor 'William', 'Shakespeare', @mensaje OUTPUT
EXEC sp_crear_autor 'Jorge Luis', 'Borges', @mensaje OUTPUT
EXEC sp_crear_autor 'Mario', 'Vargas Llosa', @mensaje OUTPUT
EXEC sp_crear_autor 'Stephen', 'Hawking', @mensaje OUTPUT
EXEC sp_crear_autor 'César', 'Vallejo', @mensaje OUTPUT

-- Insertar Libros
EXEC sp_crear_libro 'Cien años de soledad', '1967-05-30', 1, 1, 3, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'Yo, Robot', '1950-12-02', 2, 2, 2, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'Orgullo y Prejuicio', '1813-01-28', 1, 3, 4, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'Romeo y Julieta', '1597-01-01', 5, 4, 2, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'El Aleph', '1949-06-15', 1, 5, 3, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'La ciudad y los perros', '1963-10-10', 1, 6, 2, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'Breve historia del tiempo', '1988-04-01', 4, 7, 3, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'Los heraldos negros', '1919-07-19', 6, 8, 2, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'Fundación', '1951-05-01', 2, 2, 2, 1, @mensaje OUTPUT;
EXEC sp_crear_libro 'La Casa Verde', '1966-01-01', 1, 6, 3, 1, @mensaje OUTPUT;

-- Insertar algunos préstamos iniciales
DECLARE @fecha_devolucion DATETIME = DATEADD(day, 14, GETDATE()) -- 14 días después

--Insertar algunas reservas iniciales
DECLARE @fecha_actual DATETIME = GETDATE();
DECLARE @fecha_pasada_7dias DATETIME = DATEADD(DAY, -7, @fecha_actual);
DECLARE @fecha_pasada_5dias DATETIME = DATEADD(DAY, -5, @fecha_actual);
DECLARE @fecha_pasada_3dias DATETIME = DATEADD(DAY, -3, @fecha_actual);
DECLARE @fecha_pasada_1dia DATETIME = DATEADD(DAY, -1, @fecha_actual);
DECLARE @fecha_futura_7dias DATETIME = DATEADD(DAY, 7, @fecha_actual);

EXEC sp_crear_reserva 1001, 10003, @mensaje OUTPUT;
PRINT @mensaje;

EXEC sp_crear_reserva 1002, 10003, @mensaje OUTPUT; 
PRINT @mensaje;

EXEC sp_crear_reserva 1003, 10005, @mensaje OUTPUT; 
PRINT @mensaje;

EXEC sp_crear_reserva 1001, 10001, @mensaje OUTPUT;
UPDATE tbl_reserva 
SET fecha_reserva = @fecha_pasada_7dias, fecha_expiracion = @fecha_actual, fecha_procesamiento = @fecha_pasada_1dia, estado = 1
WHERE id_usuario_fk = 1001 AND id_libro_fk = 10001;
PRINT @mensaje;

EXEC sp_crear_reserva 1002, 10002, @mensaje OUTPUT;
UPDATE tbl_reserva 
SET fecha_reserva = @fecha_pasada_5dias, fecha_expiracion = @fecha_actual, fecha_procesamiento = @fecha_actual, estado = 1
WHERE id_usuario_fk = 1002 AND id_libro_fk = 10002;
PRINT @mensaje;

EXEC sp_crear_reserva 1003, 10004, @mensaje OUTPUT;
UPDATE tbl_reserva 
SET fecha_reserva = @fecha_pasada_5dias, fecha_expiracion = @fecha_futura_7dias, fecha_procesamiento = @fecha_pasada_1dia, estado = 2
WHERE id_usuario_fk = 1003 AND id_libro_fk = 10004;
PRINT @mensaje;

EXEC sp_crear_reserva 1004, 10006, @mensaje OUTPUT;
UPDATE tbl_reserva 
SET fecha_reserva = @fecha_pasada_3dias, fecha_expiracion = @fecha_futura_7dias, fecha_procesamiento = @fecha_actual, estado = 2
WHERE id_usuario_fk = 1004 AND id_libro_fk = 10006;
PRINT @mensaje;

EXEC sp_crear_reserva 1001, 10007, @mensaje OUTPUT;
UPDATE tbl_reserva 
SET fecha_reserva = @fecha_pasada_7dias, fecha_expiracion = @fecha_pasada_1dia, fecha_procesamiento = @fecha_actual, estado = 3
WHERE id_usuario_fk = 1001 AND id_libro_fk = 10007;
PRINT @mensaje;

EXEC sp_crear_reserva 1002, 10008, @mensaje OUTPUT;
UPDATE tbl_reserva 
SET fecha_reserva = @fecha_pasada_7dias, fecha_expiracion = @fecha_pasada_1dia, fecha_procesamiento = @fecha_actual, estado = 3
WHERE id_usuario_fk = 1002 AND id_libro_fk = 10008;
PRINT @mensaje;

-- Préstamos activos
EXEC sp_prestar_libro 1001, 10000, @fecha_devolucion, @mensaje OUTPUT
EXEC sp_prestar_libro 1002, 10001, @fecha_devolucion, @mensaje OUTPUT
EXEC sp_prestar_libro 1003, 10002, @fecha_devolucion, @mensaje OUTPUT

-- Préstamos históricos (ya devueltos)
DECLARE @id_prestamo INT
INSERT INTO tbl_prestamo (id_usuario_fk, id_libro_fk, fecha_prestamo, fecha_devolucion, fecha_devolucion_real, estado)
VALUES 
(1001, 10003, DATEADD(month, -2, GETDATE()), DATEADD(month, -1, GETDATE()), DATEADD(month, -1, GETDATE()), 1),
(1002, 10004, DATEADD(month, -3, GETDATE()), DATEADD(month, -2, GETDATE()), DATEADD(month, -2, GETDATE()), 1),
(1003, 10005, DATEADD(month, -4, GETDATE()), DATEADD(month, -3, GETDATE()), DATEADD(month, -3, GETDATE()), 1)

GO

/********************************************************************************************/
-- TESTING - Probar StoreProcedures
-- Importante¡ -> La mayoria por no decir todos , los store procedures devuelven algun mensaje de
-- confirmacion, es importante que antes declaren una variable y luego la muestren, ejem:
--		DECLARE @mensaje VARCHAR(200);
--		EXEC sp_nombreDelStoreProcedure
--		PRINT @mensaje
/********************************************************************************************/

-- Consultar Inserciones
EXEC sp_listar_autores;
EXEC sp_listar_categorias;
EXEC sp_listar_libros;
EXEC sp_listar_usuarios;

-- Consultar Prestamos
EXEC sp_consultar_prestamos

-- Consultar Prestamos Por Usuarios
EXEC sp_consultar_prestamos_por_usuario 1002, 1;

-- Consultar reservas activas
EXEC sp_listar_reservas;

-- Consultar reservas actibva Por Usuarios
EXEC sp_consultar_reservas_usuario 1001;

-- Devolver libro
EXEC sp_devolver_libro 2;
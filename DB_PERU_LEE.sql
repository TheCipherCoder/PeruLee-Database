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
	caratula NVARCHAR(400) DEFAULT 'https://cdn-icons-png.flaticon.com/512/2780/2780068.png',
    fecha_publicacion DATETIME,
    id_categoria_fk INT,
    id_autor_fk INT,
    copias_disponibles INT NOT NULL DEFAULT 1 CHECK (copias_disponibles >= 0),
    estado VARCHAR(20) DEFAULT 'Disponible' CHECK (estado IN ('Disponible', 'No disponible')), -- Pendiente, Entregado, Libro Eliminado
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
    estado VARCHAR(20) DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente', 'Entregado', 'Libro Eliminado')), -- Pendiente, Entregado, Libro Eliminado
    CONSTRAINT FK_Prestamo_Usuario FOREIGN KEY (id_usuario_fk) REFERENCES tbl_usuario(id_usuario),
    CONSTRAINT FK_Prestamo_Libro FOREIGN KEY (id_libro_fk) REFERENCES tbl_libro(id_libro) ON DELETE SET NULL
);
GO

CREATE TABLE tbl_solicitud (
    id_solicitud INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario_fk INT,
    id_libro_fk INT,
    fecha_solicitud DATETIME DEFAULT GETDATE(),
	estado VARCHAR(20) DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente', 'Procesada', 'Cancelada', 'Expirada')), -- Pendiente, Entregado, Libro Eliminado
    reclamada BIT DEFAULT 0, -- 0: No Reclamada, 1: Reclamada
    fecha_expiracion DATETIME, -- La reserva expira si no se reclama en cierto tiempo
    fecha_procesamiento DATETIME, -- Cuando se convierte en préstamo o se cancela
    CONSTRAINT FK_Solicitud_Usuario FOREIGN KEY (id_usuario_fk) REFERENCES tbl_usuario(id_usuario),
    CONSTRAINT FK_Solicitud_Libro FOREIGN KEY (id_libro_fk) REFERENCES tbl_libro(id_libro) ON DELETE CASCADE
);
GO

/********************************************************************************************/
/* STORE PROCEDURES (CRUD) ajustados después de cambios en las tablas */
/********************************************************************************************/

-- Store Procedures para Rol
CREATE OR ALTER PROCEDURE sp_crear_rol
    @rol NVARCHAR(10)
AS
BEGIN
    INSERT INTO tbl_rol (rol)
    VALUES (@rol);
    
    PRINT 'Rol creado exitosamente';
END;
GO

CREATE OR ALTER PROCEDURE sp_listar_roles
AS
BEGIN
    SELECT id_rol, rol
    FROM tbl_rol;
END;
GO

CREATE OR ALTER PROCEDURE sp_eliminar_rol
    @id_rol INT
AS
BEGIN
    DELETE FROM tbl_rol
    WHERE id_rol = @id_rol;
    
    IF @@ROWCOUNT > 0
    BEGIN
        PRINT 'Rol eliminado exitosamente';
    END
    ELSE
    BEGIN
        PRINT 'No se encontró el rol con el id especificado';
    END
END;
GO

CREATE OR ALTER PROCEDURE sp_actualizar_rol
    @id_rol INT,
    @nuevo_rol NVARCHAR(10)
AS
BEGIN
    UPDATE tbl_rol
    SET rol = @nuevo_rol
    WHERE id_rol = @id_rol;
    
    IF @@ROWCOUNT > 0
    BEGIN
        PRINT 'Rol actualizado exitosamente';
    END
    ELSE
    BEGIN
        PRINT 'No se encontró el rol con el id especificado';
    END
END;
GO

-- Store Procedures para Usuario
CREATE OR ALTER PROCEDURE sp_crear_usuario
    @nombre NVARCHAR(100),
    @apellido NVARCHAR(100),
    @email NVARCHAR(100),
    @contrasena NVARCHAR(7),
    @telefono NVARCHAR(9),
    @imagen NVARCHAR(400) = 'https://svgsilh.com/png-512/2098873.png',
    @rol INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    -- Verificar si el email ya existe
    IF EXISTS (SELECT 1 FROM tbl_usuario WHERE email = @email)
    BEGIN
        SET @mensaje = 'El correo electrónico ya está registrado.';
        RETURN;
    END
    
    -- Insertar un nuevo usuario
    INSERT INTO tbl_usuario (nombre, apellido, email, contrasena, telefono, imagen, rol)
    VALUES (@nombre, @apellido, @email, @contrasena, @telefono, @imagen, @rol);
    
    -- Asignar mensaje de éxito
    SET @mensaje = 'Usuario creado exitosamente.';
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
    SELECT id_usuario, nombre, apellido, email, telefono, imagen ,
	CASE
	WHEN rol = 1 THEN 'Admin'
	WHEN rol = 2 THEN 'Bibliotecario'
	WHEN rol = 3 THEN 'Usuario'
	END
	fecha_registro
    FROM tbl_usuario;
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
    @estado VARCHAR(20) = 'Disponible',
    @caratula NVARCHAR(400) = NULL,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        INSERT INTO tbl_libro (titulo, fecha_publicacion, id_categoria_fk, id_autor_fk, copias_disponibles, estado, caratula)
        VALUES (@titulo, @fecha_publicacion, @id_categoria_fk, @id_autor_fk, @copias_disponibles, @estado, COALESCE(@caratula, 'https://cdn-icons-png.flaticon.com/512/2780/2780068.png'));
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
        l.estado,
        l.caratula  
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
    @estado VARCHAR(20),
    @caratula NVARCHAR(400) = NULL,
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
            estado = @estado,
            caratula = COALESCE(@caratula, caratula) 
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

        -- Verificar si hay una solicitud pendiente para este libro
        DECLARE @id_usuario_primera_solicitud INT;
        SELECT TOP 1 @id_usuario_primera_solicitud = id_usuario_fk
        FROM tbl_solicitud
        WHERE id_libro_fk = @id_libro
        AND estado = 0 -- 0: Pendiente
        ORDER BY fecha_solicitud;

        -- Si hay una solicitud pendiente, verificar si corresponde al usuario actual
        IF @id_usuario_primera_solicitud IS NOT NULL 
        AND @id_usuario_primera_solicitud != @id_usuario
        BEGIN
            SET @mensaje = 'Este libro está solicitado por otro usuario.';
            ROLLBACK;
            RETURN;
        END

        -- Verificar límite de préstamos activos (5)
        DECLARE @prestamos_activos INT;
        SELECT @prestamos_activos = COUNT(*)
        FROM tbl_prestamo
        WHERE id_usuario_fk = @id_usuario 
        AND estado = 0; -- 0: Activo

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
            AND estado = 0 -- 0: Activo
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

        -- Si el usuario tenía una solicitud pendiente, marcarla como procesada
        IF @id_usuario_primera_solicitud = @id_usuario
        BEGIN
            UPDATE tbl_solicitud
            SET estado = 1, -- 1: Procesada
                fecha_procesamiento = GETDATE()
            WHERE id_usuario_fk = @id_usuario
            AND id_libro_fk = @id_libro
            AND estado = 0; -- 0: Pendiente
        END

        -- Registrar el préstamo
        INSERT INTO tbl_prestamo (id_usuario_fk, id_libro_fk, fecha_devolucion, estado)
        VALUES (@id_usuario, @id_libro, @fecha_devolucion, 0); -- 0: Activo

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
    @estado VARCHAR(20) = NULL -- Parámetro opcional para filtrar por estado
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
        ISNULL(a.nombre + ' ' + a.apellido, 'Autor desconocido') AS autor,
        ISNULL(c.nombre, 'Sin categoría') AS categoria,
        -- Información del Préstamo
        p.fecha_prestamo,
        p.fecha_devolucion,
        p.fecha_devolucion_real,
        p.estado AS estado_prestamo,
        -- Indicador de atraso
        CASE 
            WHEN p.estado = 'Pendiente' AND GETDATE() > p.fecha_devolucion THEN 'ATRASADO'
            WHEN p.estado = 'Pendiente' AND DATEDIFF(day, GETDATE(), p.fecha_devolucion) <= 3 THEN 'POR VENCER'
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
            WHEN p.estado = 'Pendiente' AND GETDATE() > p.fecha_devolucion THEN 0
            ELSE 1 
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
        p.estado AS estado_prestamo,
        -- Días de atraso (si aplica)
        CASE 
            WHEN p.estado = 'Pendiente' AND GETDATE() > p.fecha_devolucion 
            THEN DATEDIFF(day, p.fecha_devolucion, GETDATE())
            WHEN p.estado = 'Entregado' AND p.fecha_devolucion_real > p.fecha_devolucion 
            THEN DATEDIFF(day, p.fecha_devolucion, p.fecha_devolucion_real)
            ELSE 0
        END AS dias_atraso,
        -- Alerta
        CASE 
            WHEN p.estado = 'Pendiente' AND GETDATE() > p.fecha_devolucion THEN 'ATRASADO'
            WHEN p.estado = 'Pendiente' AND DATEDIFF(day, GETDATE(), p.fecha_devolucion) <= 3 THEN 'POR VENCER'
            ELSE ''
        END AS alerta
    FROM tbl_prestamo p
    LEFT JOIN tbl_libro l ON p.id_libro_fk = l.id_libro
    LEFT JOIN tbl_autor a ON l.id_autor_fk = a.id_autor
    LEFT JOIN tbl_categoria c ON l.id_categoria_fk = c.id_categoria
    WHERE 
        p.id_usuario_fk = @id_usuario
        AND (@incluir_historico = 1 OR p.estado = 'Pendiente') -- Solo préstamos activos si @incluir_historico = 0
    ORDER BY 
        CASE 
            WHEN p.estado = 'Pendiente' AND GETDATE() > p.fecha_devolucion THEN 0
            ELSE 1 
        END,
        p.fecha_prestamo DESC;

    -- Mostrar resumen
    SELECT
        COUNT(CASE WHEN estado = 'Pendiente' THEN 1 END) AS prestamos_pendientes,
        COUNT(CASE WHEN estado = 'Entregado' THEN 1 END) AS prestamos_entregados,
        COUNT(CASE WHEN estado = 'Libro Eliminado' THEN 1 END) AS prestamos_libro_eliminado,
        COUNT(*) AS total_prestamos
    FROM tbl_prestamo
    WHERE id_usuario_fk = @id_usuario;
END;
GO


-- Procedimiento para crear una solicitud
CREATE OR ALTER PROCEDURE sp_solicitar
    @id_usuario INT,
    @id_libro INT,
    @mensaje NVARCHAR(200) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Verificar si el libro existe y está disponible
        IF NOT EXISTS (SELECT 1 FROM tbl_libro WHERE id_libro = @id_libro AND estado = 'Disponible')
        BEGIN
            SET @mensaje = 'El libro no está disponible para reservas.';
            ROLLBACK;
            RETURN;
        END;

        -- 2. Verificar límite de reservas activas por usuario (máximo 5)
        DECLARE @reservas_activas INT;
        SELECT @reservas_activas = COUNT(*) 
        FROM tbl_solicitud 
        WHERE id_usuario_fk = @id_usuario 
        AND estado = 'Pendiente';

        IF @reservas_activas >= 5
        BEGIN
            SET @mensaje = 'Has alcanzado el límite máximo de 5 reservas activas.';
            ROLLBACK;
            RETURN;
        END;

        -- 3. Verificar si el usuario ya tiene una reserva activa para este libro
        IF EXISTS (
            SELECT 1 
            FROM tbl_solicitud 
            WHERE id_usuario_fk = @id_usuario 
            AND id_libro_fk = @id_libro 
            AND estado = 'Pendiente'
        )
        BEGIN
            SET @mensaje = 'Ya tienes una reserva activa para este libro.';
            ROLLBACK;
            RETURN;
        END;

        -- 4. Verificar si el usuario ya tiene el libro prestado
        IF EXISTS (
            SELECT 1 
            FROM tbl_prestamo 
            WHERE id_usuario_fk = @id_usuario 
            AND id_libro_fk = @id_libro 
            AND estado = 'Pendiente'
        )
        BEGIN
            SET @mensaje = 'Ya tienes este libro en préstamo.';
            ROLLBACK;
            RETURN;
        END;

        -- 5. Establecer fecha de expiración
        DECLARE @fecha_expiracion DATETIME;
        DECLARE @copias_disponibles INT;

        -- Obtener número de copias disponibles
        SELECT @copias_disponibles = copias_disponibles
        FROM tbl_libro
        WHERE id_libro = @id_libro;

        IF @copias_disponibles > 0
        BEGIN
            -- Si hay copias disponibles, la reserva expira en 1 día
            SET @fecha_expiracion = DATEADD(DAY, 1, GETDATE());
        END
        ELSE
        BEGIN
            -- Si no hay copias disponibles, la reserva expira en la fecha de la próxima devolución
            SELECT TOP 1 @fecha_expiracion = fecha_devolucion
            FROM tbl_prestamo
            WHERE id_libro_fk = @id_libro
            AND estado = 'Pendiente'
            ORDER BY fecha_devolucion ASC;

            IF @fecha_expiracion IS NULL
            BEGIN
                SET @mensaje = 'No se puede determinar la fecha de expiración para la reserva.';
                ROLLBACK;
                RETURN;
            END;
        END;

        -- 6. Insertar la reserva
        INSERT INTO tbl_solicitud (id_usuario_fk, id_libro_fk, fecha_solicitud, estado, fecha_expiracion)
        VALUES (@id_usuario, @id_libro, GETDATE(), 'Pendiente', @fecha_expiracion);

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



-- Procedimiento para actualizar solicitudes
CREATE OR ALTER PROCEDURE sp_actualizar_solicitudes
AS
BEGIN
    BEGIN TRY
        -- Actualizar solicitudes expiradas
        UPDATE tbl_solicitud
        SET estado = 'Expirada'
        WHERE fecha_expiracion < GETDATE()
        AND estado = 'Pendiente';
    END TRY
    BEGIN CATCH
        PRINT ERROR_MESSAGE();
    END CATCH
END;
GO


-- Procedimiento para procesar reservas pendientes
CREATE OR ALTER PROCEDURE sp_procesar_solicitud
    @id_solicitud INT
AS
BEGIN
    BEGIN TRY
        DECLARE @estado_actual VARCHAR(20), @fecha_expiracion DATETIME;

        -- Verificar si la solicitud existe
        IF NOT EXISTS (SELECT 1 FROM tbl_solicitud WHERE id_solicitud = @id_solicitud)
        BEGIN
            THROW 50001, 'La solicitud no existe.', 1;
        END

        -- Obtener el estado y la fecha de expiración de la solicitud
        SELECT @estado_actual = estado, @fecha_expiracion = fecha_expiracion
        FROM tbl_solicitud
        WHERE id_solicitud = @id_solicitud;

        -- Validar si la solicitud ya fue procesada o cancelada
        IF @estado_actual IN ('Procesada', 'Cancelada')
        BEGIN
            THROW 50002, 'La solicitud ya fue procesada o cancelada.', 1;
        END

        -- Validar si la solicitud ha expirado
        IF @estado_actual = 'Pendiente' AND @fecha_expiracion < GETDATE()
        BEGIN
            EXEC sp_actualizar_solicitudes;
            THROW 50003, 'La solicitud ha expirado y no puede ser procesada.', 1;
        END

        -- Marcar la solicitud como procesada
        UPDATE tbl_solicitud
        SET estado = 'Procesada', 
            fecha_procesamiento = GETDATE()
        WHERE id_solicitud = @id_solicitud;

        PRINT 'Solicitud procesada correctamente.';
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
        -- Verificar si la solicitud existe y está en estado 'Pendiente'
        IF NOT EXISTS (
            SELECT 1 
            FROM tbl_solicitud 
            WHERE id_solicitud = @id_solicitud 
            AND estado = 'Pendiente'
        )
        BEGIN
            SET @mensaje = 'La solicitud no existe o ya no está pendiente.';
            RETURN;
        END

        -- Cancelar la solicitud
        UPDATE tbl_solicitud
        SET estado = 'Cancelada',
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
        s.estado AS estado, -- Estado ya es VARCHAR(20)
        l.copias_disponibles,
        CASE 
            WHEN s.estado = 'Pendiente' AND l.copias_disponibles > 0 THEN 'Disponible para préstamo'
            WHEN s.estado = 'Pendiente' THEN 'En espera de disponibilidad'
            ELSE ''
        END AS observacion
    FROM tbl_solicitud s
    INNER JOIN tbl_libro l ON s.id_libro_fk = l.id_libro
    WHERE s.id_usuario_fk = @id_usuario
    ORDER BY s.fecha_solicitud DESC;
END;
GO


CREATE OR ALTER PROCEDURE sp_listar_solicitudes
    @estado VARCHAR(20) = NULL -- Parámetro opcional para filtrar por estado
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Ejecutar actualización de solicitudes antes de listar
    EXEC sp_actualizar_solicitudes;

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
        s.estado AS estado_solicitud,
        
        -- Información adicional
        CASE 
            WHEN s.estado = 'Pendiente' AND l.copias_disponibles > 0 THEN 'Libro disponible para préstamo'
            WHEN s.estado = 'Pendiente' AND l.copias_disponibles = 0 THEN 'En espera de disponibilidad'
            WHEN s.estado = 'Pendiente' AND s.fecha_expiracion < GETDATE() THEN 'Por expirar'
            ELSE ''
        END AS observaciones,
        
        -- Tiempo de espera
        CASE 
            WHEN s.estado = 'Pendiente' THEN DATEDIFF(day, s.fecha_solicitud, GETDATE())
            ELSE DATEDIFF(day, s.fecha_solicitud, ISNULL(s.fecha_procesamiento, GETDATE()))
        END AS dias_espera,
        
        -- Posición en la cola (solo para solicitudes pendientes)
        CASE 
            WHEN s.estado = 'Pendiente' THEN (
                SELECT COUNT(*) 
                FROM tbl_solicitud s2 
                WHERE s2.id_libro_fk = s.id_libro_fk 
                AND s2.estado = 'Pendiente'
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
        CASE s.estado
            WHEN 'Pendiente' THEN 0
            WHEN 'Expirada' THEN 1
            WHEN 'Cancelada' THEN 2
            WHEN 'Procesada' THEN 3
            ELSE 4
        END,
        s.fecha_solicitud ASC;
        
    -- Mostrar resumen de solicitudes
    SELECT 
        COUNT(CASE WHEN estado = 'Pendiente' THEN 1 END) AS solicitudes_pendientes,
        COUNT(CASE WHEN estado = 'Procesada' THEN 1 END) AS solicitudes_procesadas,
        COUNT(CASE WHEN estado = 'Cancelada' THEN 1 END) AS solicitudes_canceladas,
        COUNT(CASE WHEN estado = 'Expirada' THEN 1 END) AS solicitudes_expiradas,
        COUNT(*) AS total_solicitudes
    FROM tbl_solicitud;
END;
GO


/********************************************************************************************/
-- INSERCIONES INICIALES
/********************************************************************************************/
--Insertar Roles
EXEC sp_crear_rol 'ADMIN';
EXEC sp_crear_rol 'WORKER';
EXEC sp_crear_rol 'USER';

-- Insertar Usuarios
DECLARE @mensaje NVARCHAR(200);
EXEC sp_crear_usuario 'Admin', 'Sistema', 'admin@biblioteca.com','admin123', '999999999','https://lh3.googleusercontent.com/fife/ALs6j_FptcfzAjJy-KeNGwO25Oo-Gh5Gz4EsarIFzpSVc4s8M7BVh9TVb44Ziv-yD-H31-vDnEKM_NSGkIxniu4yNyVOuox3XWwky9excgicC4jh6rJlyG3pD8NZEi7oDMXMEPfS1t6FjFWOQIhYb0saMsgPt6Vn48YDw6W9rFnleY_NZgWRY82ubZsVhtmHI8NMHt2jUmJaXmx5xXBnfRRRvqr1xl16zUKwQRzCose_HZ04BOfNcDTEgf78M7PFW0sioZKZiypx2ozBRKkk-snK56FBwgZhOViMbtKNB3af7cEJ27YG6Y6PYSxAGCBVm0uXJWdccIrlZePzANq7PlTlztOwwCRUPHG6-2I_U6KnUGSf7ejawtV4hgFG123t2x8INnAGvq0C_g-6Q7yQhTA1o7V8gcGksRdjcZG5BsVJ_5Pe0qqY5J-Id0UYrGtmWB3AavY_dix1ZUgvFzfRZ5E4dPOJaCwgQ6eYGulv1vk76XjNYjPlzcekA_ydyBrC0HE-XjwU0qL8SkuWP4CAoda8KrG3m5mqH3R1gi5bgl2gevoBQQQO7r4Y5nUvROhcK8F0bEpEhdy98z4eP3zzJ38wMvZloqar12irxY2cYbZEDtXSbPpfnnyH4T9RjAf9ChpB7S7qCbUvSe8V4POUrZrXUel-YLiO0qTtcSiiECjdHT4Ih-5Y6qkdQH00w3eQ7bu-SjdCYh7n6SKwNLl5no9qoFeNDvzkI_NxUjgf79HjnPHziT079xCEXJzlrQXV_WkcWmUxN2MVTJ_zEKz9JGU6lYJ9qOtlIKv0zZ0mmRe1s3KYuVQBpt-NbX90sJsBeEZd0rrfyBSP1IP81wZbpZeTIp01k1xEZERSA9TLBII2_3be4Lnjh04zZ_UOOmCMVpNdd1lMN0MioH_r60BFr0vVATWVlKRo4ACHpRDPkzNcgs6R4SUv4rAi30Rz6KCnYhOytcXNuf7o87G5KWaBDadXrpcY98WLO4mNdesk0WndVb_gx9TLSuO_yR2V6tRyR_ErgJ5EhvPRHImpM31hiZXpG-vlPKeyV1TTC9sb6PZvb1nKg2YTUePS80930JvZhc7Z3JOvuZWg6-udvhqVtZs6wHdaoSE2hT1d4MY0Im2BNHOigr-3v--e8Po-K2baqP2hge7VRS3eEt2h4Y3AEnB5VtRhOw4Jy_vasUi5pKAQKP6BZdaIOkvEKxSCca2sayuvZcOGLccbJfiaXyGKDsoGheVfSTwXRMwv7YGt8bb4nW3DnaPgUV_pFLJ9xShq9pr5uwunPnpJP2_qstUz5LtVMWESZlhHlFJfQbGEpMI8P0Dy9Dae80VJ7XNY4uD_QyFjlCoeD8RoRZsJny-TZd68pg8UA1JgGxe6UtNAC1flV_j9-XCLLWAXDgxYNxisPeSVt9rtCUJjsKpqiop1v_tuLM0AHkJNkFkHSA45gpehqZ6AtJsGoOCxiXgdUPdBGTloVz9XB_cOb8Dw_E5W0GbbEblqOW6SI73L2qXTOq6YS0IpTEpu6G2cIU5Du3w9S-RLbldqTwfjV_y5eu7gM1crWEYb1U2Ye4r3BYWRZo1qLvYdzVb1vHnpFZytSxgLQWzpUvPssLz0mfDYtzgJsjUZOGP_fPe8eh8B_Rv9B5PDnzryZmGPlGlTXyBq8wXU3yrQ0EZdmvlNfufP5GTOsszJpDFcrhw=w1910-h957', 1, @mensaje OUTPUT;
EXEC sp_crear_usuario 'Juan', 'Pérez', 'juan@email.com', 'jp12345', '987654321','https://lh3.googleusercontent.com/fife/ALs6j_H0IkUEm-f3uYJTOFYBWIXmXCjT6teOY9wnArHbXJE64hd8JwvL4MRyEZ8IIAwTwBVWp7yPyU5KCZKQDWbBMO2Ieta__yS057icLKD2WgAZKPYCSw0Mjrj_2ZjoUElGDCoCxnXOxjvCmJBwx-6T3Y4s3d1dd-J7edhDIxGEAP3vlhbEM3algR6UYvtxF_hL4z55slVCycJFDZuYPC1UoZpbFXZW9iYo8YaC4elZSobGJ3wbMuissVcN-994-TL_aVRzOt519D5hheEGNeo8bJHtzz68AHPYnoKpaox7l1ZoZi3Yd4n9v_eAHWgHehnitROel_OM4Ot4P1amUXrT9MXPj1-kFZsgC5fJb90z32iEgTJQIHUV5_o2xZ-u_KdriqQb_rlq5v1dPC33z4g-mBfU0ZyTBsO1TL2X3DSarO8l104bp8SqycELfypTmhbyArwR0ejhuqIA1coX4FqD8hYxnBIA1WFoIHTPTP8mHICciYokH7ZvfGyoj7pcVAywqGk9w-gq7WlKsDoBAFNbVSWhhMQ13UsrS4RNfaxCcChMhitatOVqmdQl0DUqJCyubLVi9RjS_hCqMFF1_eJkazu7lvNw8IPmGQNXPHJ-m3OsR8QE5masWKLb9NXtbkevtQVVcS9pPpfk7-qwicrKiO2PkzUQXaOeaQzvm-qWM8JTBwH9vzps9qgps3IDeMi6thcLfbhy72X6J1Hd12Nsw4hFb6vTVixvFj0L42qLLdNnggwKH5qDJ8TpYBR2qs2QpKloygEAhMkiO3uED4HbsBW_yfc0ZIpuRPc1SaR1lx05GNdzlA1vF6S8Xqmb5fwNgou2shtlRVFSt2tcdKsFh_qYFn0ohBEqAXv_h2PsaSM2-1kI9rorIMAwXHu7tT-Q5zCmgzoQj32h7m1ystzkELunoJJRBhn06M5NnSgrvrYmmeEr7jiESR24OTEowOJjqJdcsCqMHRgfg4ocEoPT3oghEYWnSQf6nyB2hqsB2QityK8VEFA0-8e23npnmS2OALIq0befg8OVvqFn0gSZM_gVlt1Xjxz1t5kxgkg-lUCAHdRT_vNpg0isDW6of_LxvpxF9K6t9QXFyEE1z-w9smX4jCesbZvrVSqqJnq_ZMX7QFRV6WPpDO_o4ieQfF-AyGdhh6Ze_jmRfspBqV2s3IGFwBEnY45-faLOzD2O3RPxDFvAj3q8xyJrmwOC6Jr545E8L7zbrgRRanGBNQJfhF6k5PYjGW1rtRZqhB1rQ82tD5MOEH14xQCaNtY3TXIVv9QXNR6_HZS0kkCOW7ulHxyXTfGl4iFvJWhkkjvY3sO1cjcY8D2Sre_n6wLzgaTcJrd-V7Oow5W7upBKy68xFvriOG6FchSjaIi55bPj8ZePSXf63ESfcbYxXJHGdkYHhIhByZ6bH8xCGkLsSFQWnUoG1QJj64A3sJOdlo0PvTWlG7MzycXscYJsANLgZv5LN5ycVEKIlcuk8FIKDOZqJ8BNZWhTppoZ_p4TM7dixKq_mlST2vsCw4lBhRS42szS2XydQKS94gEfMcE_k4ZyRyfH4GgMqm6BnA_nY5qxtcm0dQYzkv6C6jIbp1Md5BMBx-VdR4MF0TUWVK4oHT8lSgQ1U8eVwSxQDNOCyAb7k9pSo0rmuZ0yAqaJgIcxBNTUEuQPJXBAXQdHS-7DS1EfJof7p9QF=w1910-h957', 3, @mensaje OUTPUT;
EXEC sp_crear_usuario 'María', 'García', 'maria@email.com', 'mg12345', '912345678','https://lh3.googleusercontent.com/fife/ALs6j_EzoenOfPFiUcXEPZ9m-YFV0O3QzM8JD9th3cXe5XCs_5eRoOXBPDRNXETV2t6Y2rexRkV7zO7_tQdSUfhS3J3TbiCq1-xl6vLfOnDc-UFFSlXsydiXbr8fGeaxv07y_Sa8g05U4oc8MGVaq1yLEPNSmQQPRLj8ESn3N3Nyp1vF7QOvDpv_asCDhy8owkG05OJYtLucvdACt9ZMLr0vTOPn2a0ik04k7E2iqxhBPmn3SU8UNRf29fkERSQNKyLowIgsKsz8vbxTpOI81MfmT8SVhXBFwd0LdLGYFpMG-pqcL-1GonuDOiBVtuqWkAs-sUw02_bmsKmhwj2OnLPEnnvBCMjqy9mlYhEWn6zGUa8y7Jc2TnLrLRcYuVRa3X62eP4BAAbZuPLNXi2UvSCCLxVx19ycqJa7kt4J2zvXi-EQUdCYjFfY12AHqpoGIr8B0iz7Q7QWNZ_KSS_QRB8jeQHhwWiWw3-rFd2dhivKw-BNl7l6ZJCq73qy3aqr4Y3AGuBt2Ut3YI8oIJX3qcMmMcj0u8f2UfStNj8-yk8KKoM2Ys5kfEKyvlrCx7GhVpHvjV8qN6FgdjvDC7a3vhgMUWTtDLflSrI1MxY_IuJSp3I3oP6N6kjHvox7ip0sn7KIZqMs_lnm9O0kjxfF0CqvDBClhwe_EWpmqipU1fIReGBtXC1g5Y0gv9xeOQ9cd7zrOdjZo-HQgVGlqCDi1tNle3hj6ojVRSJ5w5IMMpKmzuSbjNFaWw78Mf2LqGSBOBwdyORa20q4iAe_EyvRZpB11omn4DEphaflxCu_1jmTuUeZVqpS85PKD5hFXWJB4VqC59Qs7rC-8twg9SrAfq2LXBCeLR6kypvh7E6Jwg6Wzrvdy5cyOd46vfmp2DbDZHPvL0ScOFlpU3SnqUToafAYmGz8Pj1S9peioUe-BLMBzAiTvJwwh9oq53cLZolVBmm-sVIZx890pxT9BRkTfmXZHKEzLdZQ6SZl3gmhf8FbNaX_wKiSgX4BOjbOcug2EiftD-CgtPCLfcsNQzNvCrLLtd1Prz9ZQhYRR9aaaoSIEutgk-gcGJTK4bbeXWIGvcywPUcUokPiqWPtmJZoKsr__yhKnZTxq7Mf2qmropGKFamtga14-nrhggeJIm1H4CCl6D7uoV8bs_LpHKq5SUJu0TW76pUcUjO3SGIqFGw7nOPKYZqcIzu7hed9BiEKeKqss0HaXuykvpIWuAVIvwXMlf93_VqNzvY56UKPynph3epYGxr2MVn85viSEINNBpum-g_bOoGqI4XODQ_MF7p0I2fcR3b0Iion2Bv2lNEcFFTO8BS8XE5ddOS1YLgBn5BK1ZAkqYm4cVxvtxYg20hQPoxn_cR9VEaGI41CFQeN0FBDf27pTtnNR_-VvP10TsVib3_Zd2IdOIhbkAnWuEA_Zph36ucy7F5tqrEb3XXZAvrk3yPCqJM41bhT5aBiR6AqXMpYLz2M2_u0RT3BFA7MrD1FsEQFx2fP29eGhZCf-NJ2QzLf2FhVhkV2wxF5k8wIYZ3ooAZNsGC_JdVdutqu2nSIKQohqS75l0fO-6EhcHcTZtHRfdo_qPp0734U6eXXtCwC8zHQmj0MYww9AQ_omMg39ZNEch-eIcy-IDxSbxjJ-nObrGXgrDiJ4Mp5Vd2L2_VEMiXqsaVHYrGH768DadjxWv8=w1910-h957' ,3, @mensaje OUTPUT;
EXEC sp_crear_usuario 'Carlos', 'López', 'carlos@email.com', 'cl12345', '923456789','https://lh3.googleusercontent.com/fife/ALs6j_EGJygP57ZlNyOjzGuCO3mZCOpRdZJNL-MjNX244Y1uTjOc0xWzN-sOY63Z7OBYGQghtN9X6BtnZXLa_6f8Yg_5ySAerXlFnC5Ccjf9eiYKR49q8kw6y-qzG7-NwbKqgqvfQjTqtqDCQ5-mOgmI8XRsnJgx9ngm8w4MFLaD7BAhseAA-0mf5n30QyTzlF7cXifsemY-VhArq79X8N2I2mG2dHU5PESKWnHFrXtG-866eBA4oBfIvwUoD5hsz1DZ-qJ08sxap5o0j8sG-hfPdfQ7IbDem0YM52G0SUNWrvxRs3oLN4zr00JWWjVHcTX1qzKrtp-hZVrv2r55j2Yra7N2w-JM6kPE1iCuwYQRIugaq6zJwbzXKxmWGe5qLezciA7Tani79c-S3JvJGozJVpyFefi1XlpJS34K1RsdhftheEMj_4nj7RMCfE4lAzcINdEX-3dEubaeZAlbXT5cEjfVrVFjumWCybc9l8cidH6mB6ZE5SfBht-I-SKvOdo-jeD1EkCK0NwsZhu9xafJEzI6x3SIvSKNcz839YC1CYGQBPnh3Eucy0rACXJQHtChibRU48f9rHCoxyRYdJJuA7sYH4nahIbsE6hwbxuW8kLPd2WYuWCzLLTxz8G8vJ4qRQEoeYCv-c1DkAycEXaaTGr8HVyI27U1IsaGVy3zlLFkwBHFt3IH7GYBNJqq5KzcdUUPnUOLypjwfwwz1rj1luNPfRDKAZRdj_LCp_v6OwhohITozPC2YG5uzBMZNY3phwrpg72Nn1URYt7yf11G6t-h3PHWCg99RPEv3_x0OYceLo73V7MbGDRZ3XrNA6YxTEnI4DP1FRL-ObYJIu0cquozFwKzniY2Xos1xo113YZcs8FZ4xU9Bf0Q1oabGhFH3WvKwFNM7jhlRYr_BuGEkqnF9zrRCOtxZs6EjQZKryEmsRKZXOPoU6i1DnHag8jFg-2eSYqc-MfBtcuhrT-k7Z0ELkw6fikAatNx419gfBrO4C4LQd-E4Vl9gpqZY4r6f14MAK6TVDe4-w7_3Hj2NvE-jNM6V_1jQznhHoitnaBmftOjLTWlLjMRTf_9g9UTgf9feACDJaHiScp9hDoHAM7PNJE2wF_8_2z61zvGkUzRAgeMiB2Q_SlBYBqS-E6rNrHohRu2FrwUCXqQUUCgRgWDzW1GhhdT4_OL5YdHgPoMwPAtyG8GTdPGnjtLO53UfKCuMMp2WfbqfYxj0_7k-sfEUUUSmHfXjvPOZjhzF1oCc0u1HPtMBUNNb0QdVZ3jMOfM6O2fRq6jbDn1jCMJ8xMpKCEnEc22htYo34bIiQtcyv_DsRqpm0luA62GC_HYQz0k0Mz-KgSA8XS0IO0iWbxb56UrtET--Buori-ldaUcqivCswei0FFUHy_fIHBbRef2o-sitGl0_dinl7TJiFsZFRD9ope3AhPEHDS-SUPe3atv9xvLjE3T_9rgW38oQtjTyxYY_IGUzRsmdwqSXtle1Q8aVKNf59WrI7oTrZeXN21ILpNTZ24WziObqmOQhL9O-51WHy2WqOeWFo6xBhG-HPTchyvrQOEZoOX0XQXTV7Ww5ewTHNlRx_jRq-JysQ1h7DnQyFj9IyecJ-eODux9Yi32OgIGfsUMUq5PGeFfO6mcOH8bOQA2QVAvBgJcVbP3zghESY1Adld2-we34zX5-zFH=w1910-h957' ,3, @mensaje OUTPUT;
EXEC sp_crear_usuario 'Ana', 'Martínez', 'ana@email.com', 'am12345', '934567890','https://lh3.googleusercontent.com/fife/ALs6j_FVzV8W2v0xgovwLS18sxWyTmnr9NaeZmkcJwEcizuYtLN7c8XdRQcBmbT5RmiNcsQqvs_bcRz7pZhW9O8ZbgUdAJSnnHFF7VabUKurhMdWNjJBeGMeVgFn7_EH2QjOLs9qrOW9HpSlUwfclF9sHLBUNzmwTuJxYANB0Uvm1y_MxxiFaWFDnXyDQHRCNWdK2DTMRWGpIYLVv8LpFj0tQzo12ni0r7XFPj3jp1IusT42l6DW9-bhEuQN2X1sFpT5WA5KJZRRSoflC5jc5BmPPGFvn3ABaSpsRVLgFSWyFT0najCKa_0kUiQmDddzdR4aqLzcgJ-74WItI3PKddben_YY362IQyBa_oeSt2iND_dGs05uxBBtA8I12jIA4dwqwQBvLhk80NhDKVjHWiWJsuWZZkUTI_lwS1Lq2HsnAKKfnH9rXVgG_byu0tU9jBcqyd5m6wQw5FMqIZgLsk1ObIIttNv64oQ383wJ0_KxU5CETax0J2BOvVqF_pF5N-MlqlWAXFVwQuOOsy0MzFWys3_IxJOttT3ReMAa1C0jr1-zvXbexJmA9IWz65kD-R5SRNrsB2OKo-qvuaklHzxj62BFD5A5NDWAZd2q3I0vWlFcKFCJizfPqFGH_c9agT9MArXFdva8S1JZxGc6yNMetyB1JwpH_HVvnGdFu3_5OJIj0Cr9NSNCSjIObslTlAwMRN33j8lr1AR76mVRkYcZSNDkrkiKz7pOhuZoiT7Uv0oiNliYDzMJwL6YmlwRa1sufR8dYnTbcGFYry5o8UHt1bNhFV6Wy89twNGYH5MXEZ59e5_3LCfX60JHvlwsmSUena90hVNWcu8lIZKuQvnp13UpWeDPQU6w8jYzhSr14O7m4d2l5y_nKFAGxcyhZ9Zku0lic5l5ubtYaErB8YuDEiisNMnSkvlovP5Dk2UN8wBRAdrs_dzPkVXT2UAc3bIB6dK0WoCFwEx9W4rPjvCBogZojaUNwBX0e0qNDz5SAOBaKS99HPEqSrgxQVoiRX1bkplislHHEWzQ3VCxu5gq4abyj4Q4Fd0PZBG68G_kqurgepCt2ZoyeNqiNj41naqiWR7S_7dvguz6xrjWn2EkGLjo7Or10GibP5YXgBek_DulEgSSgLz5lkpYG7dLBwpXmGKaF_lkFO0wHsrXHwqsOJsmy2IGO5D7TCsHgXJZkoEuGU0kYEdH22w15X7dt47xLxbsp3YKukUwfZFef9m5BjlrJJs2859wd2JUS6X0WnlDIAQdKsmGwv-f8yp5JHK2gTwYrOgWISxJeeDYS9AR08cpcpsUWyfrcGDixxE9X8OK4dFYBXeJBxoTO8WuBVLXyKt2zYoqi0oXYNFC8l4aPO4G3vHy6hMlwA976RSieQWn7weC7VmRa3_d4S_wmgG04OK-Q50jQDw-hqPHaWt3tpV4uxEQSEm0KtZOJ6QrV1i6cHYKPLsqoCbQpvVJB8OpUhG5mwfA9ICEGtktOD4rpZARdy-7Ep2fbeH6Q9YseX8u-qBqu2qsGt4E2HhSxCUc_DHkBBWqZuTSi6XrAkP73yjZKftq7w8qR3RtQXa_NUQ2InRi4caW6Q3RNBoX7r65jqEdIbdctTolDG5RuuV5-Mbl-V00s82ybJaac0CspiBma--n-wz45j7nwCO8RvTBaTU25Prk4FV4SXdQLNV2EPOHCqlI=w1910-h957' ,3, @mensaje OUTPUT;
EXEC sp_crear_usuario 'Luis', 'Ramírez', 'luis@email.com', 'lr12345', '956789012','https://lh3.googleusercontent.com/fife/ALs6j_E_BxA1-pEWL16n9J4ySQXfqE54vS0cf4UiKr2b6oDejiyWZ7D9ED8LwYhRG0wKgh0WMsMJWpx4axvMMEt5ZMUmgixFtXYzw8prWA_jpdBc_iws1Tcn9G7OpnJyiBaiArO-Z64POJXkJprB-b1Bxm4RlUnjqr2LPsUTSVW254PHZsWMZvNlhNSs17CjdxvGsZ9zmQBZxY79ZRNmLGNo9g_TpWHvbJN6Yun9-IGooIJb4lrwzq6b4-_qH18FW7YD5tZ8QA7obVGtiEaUGXaBBxD2i8V9DcM2Tca_jsisJu26RhXY5JPaKcyl6vOq7KdUBBNmvkqmev_6owXEDZuzxG886GvEk88ZvoJau5vtuMukOLs9mR1KXlPlIrJ_-oTxOmeqJudufJ7whQjROwYG9LbRZX_DVQJdlfR2jiuaRmbz35diqEIFMoOc4saPmNFLc1c6xSkswMVIqltbHt8tBf6VZW3w46ZEHyesJc3HVyEkA2SKhIQhDmOZtg7V8SC1bFWnoS3ZwNYdvYYQiLMp444rKrtEyI6wOILzzEYjcRvC0yRO6S_8EBuqkXFsjtl4B3q76FZ8XTZcNaBsaMo6KuYEM05Ms7HqA5sMh1cJehDqTRgKxFapVYoANta_IS3SxiJL51ITBIV8H6w_plYMv_-kd411pkdUj-njN-AV6h-dX1ucLRTg_Sxv2AZmMoKyRg3J4zzO8XxPybEWYVg2Daoj5SOt4c7cjaWv-h9gKda--lT8ZjZFEi7WDrH6rA-TryjAdjMhJ-PFK4-Jo6x7iuHfu6bG73EL-4dJ2fYDB-qJSOvda24Aym80vKU0lj2CO1YVPuzh-zIMxZOWp797Zkl1pEZ5RpLsDpNfyJjFUuPETg8f-XX_HUyjoc0U74NQwCsIN75X7VK0lh5FXEca6xlXMmoqUXF4oBXtBBjsERNEhTIQw4ix71MvH4DV_-SLQk7dO0MSbDErg-TLhIHkpqY30C_vxcrd8ZfShEUkfFbOfIgENfjgEg0BrHQa62yFExEu_UQjsJVYWLnrk8rxz_AqdS_LTrDxmg2Gn7KkBGwv41qv6uT4RqRmVKnCy0Xw0sKsnKBK0EqCoMRfHIA-GsNHD7XFjBEEXqNTICZtm-rX5arRaEoN9nhX835JzgdJeUWFm9I6_qnTmIISqIxtcIeWfZ-sicI9eT_3WpiEiAoN9METE1yLwJrpdjG8UYSve43RIHlnXSDYgIjcwD4MD6pfUn15-7dFvQk-JPQRUsfNgVAUejHHFdDXvz4aqwQJDYw96YQxwM2WIp5GbjfROjcwUzWbvI4g2TGqSRLiDjwiPDsRTGAdy02A8C64vjfJ1Y-Z1SIVMQx5Vj6IXE31sgInpa2W7Lo238tRL22pezOhtjQTUkqj4tNmLJQKa7rcxT-7hSSTtgdkkdsLoiSEnkXIHTYzx_MBvkQMrJNqJt9GVkZpKMQZoby4bPgoPmAL5b08Tmj2UzB2umbKO21NjJ2qUt8Kp2TBZGIbYyu6N_YNVtooSJYnBeyZbs09HxKkBYePRnIDSl_7PNnxfmiIsT3lgUaoUDL7pmK6906EP0muJayrlpmvvTMPd6hasqfoY2sTXFNY2vVRnbqEtW3tTi9bLzy-Gm0hZ2wz1qAqOS3tOjny6EYNY0gMad48f0hXUb3Arf5dSQ-kfrSAbRXEXZXHp2tf=w1910-h957' ,3, @mensaje OUTPUT;
EXEC sp_crear_usuario 'Sofía', 'Fernández', 'sofia@email.com', 'sf12345', '967890123', 'https://lh3.googleusercontent.com/fife/ALs6j_ETX5c9KkOsC8LHJ33kw5-ZOKs9Zc2rhDQR0d9CLlCr6QYkNs3yIqtOVhqaJ42XE9BvlrdNbvkQJC5dxtF7jM4EdVVW4Wvqpz8oq7ZZ8zmQx458nBvsEcOHY8iyBdjB6PB9HZwcQrtwnaDX2qEHlAVGap12wM1WVSaWDdrNAPlme-obGs8EizZMxwJSAd8EmI5VuBnnmCLnuVB6GJ-UcLgcg5ehquhp_IuGU3gbKNwidg_jO0j8NQcS1M32NlIXpobOmBpUozXxlRHOkirlPIcK8CQJJduW0KFICK-OpVw_cZXTFJUPzK6INt7lUqwU99Z8eSfK7OXKl26OhTFbGR_WyqUWpEXqo4huwuG59nw-mJHr2WN3meKa8-nI0fxz9s-MegAqYjVa8AwGY7Z699VWKh9fcdhs31ryPsb8bk2VHyLlUH2zkt_ofNgIH6qwrRcRHC-R62Poy0qqroNqSohYSm1SzMCErK43n13c45lsixv0A2ofmLs1__IiDHkyW3voG1aVmRgdMse0lLxq3NSIeJ1cWrWgETmjggBInVMi-IooFiLV_aZ6ZdOhdTHEzdfyADfNf7O6fmqKYGzI2FbHBLWrziUnbcpeUy8tW4xYD06hpv05xn81OnS9w2zMSarQx3U-QRQ4pvgLmKL6AKnv5ZJRBmPaVPdv8V-iQKJsJQlYGDkmQuOMhnPOEA5f6b_XuToe0AJ60f4rYPfpuQDjcNCHmvQM_BmwQAOAnLjKCoBlmfM95GCM1IP0McRoL6uCHwY3Lbu7QEAliN40VkRfzHIfx7_hDG4Ak5BkdmWXAlSUEj_yfx3WU3vK96IiUvLmC-pZM6tL0Jhlsbhh4C2_W_TFYKkcZuC-CprlOImUV-cHXvssYvtqH1mMz4Xo1ViK-L_BK-FXVJWjMuyz6Yt94xtz20ctiJSFt1fKI-JboWibe7g66YjpI6apBEOgG7A3mk6U2in77Twr1-DhsjVvoS8RN9NTmdbNxBnAP1Bf9PkedLcCS_pEaPckxP9Y-r7USJzIKgC1-O-1FSaQGKEUgk-pQTXIe3n0ES4MTj2yQUF0Y3Zr7yZbFy3kn6_eQGtAiQBowoggQFfsSLh9utYsEgyHaK92bXUCVjVHFk0_4hUkcAGD2ooTzo_fGI9M3Xuh7lYNrv-iR9T-irs9uphzEGTSg3ke_0OEjTWSIVIjznc30Fb52bO5uZHGoPFnNHn-Dgg4kitZlyrD8707jxKFDg3X0DhMiYdfgWzAVp1EaI9CWZFO_lUbHvYC-kLHAnwDExsSEw14wuc6GQD7Eqi-XAHxrYoix4VyLUSarMEwKTA6PgCAhIX_Du9XBiEwNIMDtUHDUQvbLMLUYOkn0Hl681AVuGTKRBywNw3-HY8UcpqZ-ow6bKkBysXH44GsoF2FeeAixoW5ULuou-x9-fzs5JtYyk_5zTLfyQ5z3EEm7svmO0fCQZNss-N-OWzksY76TbFmcTvn3izvzClkcRjc2Bwj-1v_YW1Pu9StBq7D9mn-yqGOcBOa7006OmuuMwOn8GjDDSHvmCPfxDCeVnoPPeeAh7PcdtLWgI3HODQpFyqMLaoDW0gltM8dLg38kfmrW9vhTo33nNJFINYDgzmZmxiyuOckdfYPut9UtK4UHUhlp7Tnt3rHAnoJTnhPf12N-ZT4nAv4uJvEkqJ9NweQDxAL=w1910-h957',3, @mensaje OUTPUT;
EXEC sp_crear_usuario 'Worker', 'Sistema', 'worker@biblioteca.com','worker3412', '999887653','https://lh3.googleusercontent.com/fife/ALs6j_G6BxkH_HcGo0HAGvKtRzGCoj0g-vs02L-7a6-ZZgfW_BwugAv5UPtL-1ziXOHKB9BdGxmcsbgRwyFwfcZwn7hXaefWpRTLx8Fyj5ps5fkkEiiyWXKjf46vdH-Ju3BeXVByT75ibq1A1Hk7p7Zl7o_XRt41gvaKJ61Fu09tQkuSPiJJk4ZXbSvRa1km9VMxrnzEZGsyCuCZKX9W1ZKNiv3zqRaKEvIek-LzbEZpyzxEFtKWK5mzJkTu0Sl1nU5p46wlr2XHcBwnrfE53bW7lzZYLNH6oFHXfT406Our5lVIuZ8CJTQy0ooJZXTDZ53fpKLhxzQGCjsJOAPHUhS8orV34HCgq98RuiUkbr7mktTeOGa1W7zDvq0Zcg_eNtiLENlmk_QLldyQKIFWZKoNg2cQdC_TlJ7cGSBcLIsNA924FBzZndKT3veKEGV4dDQrWwlhls1mA_jOJaUVmZpcvJVAKLKlCDzvmYH5OQyPpeWl-NthvhsYJWjepBRGMWQrgr8fz2ZMthMdEZz_3jjrH2tAxhRETfvOIqVzMfumjdZJ6r69XedSfopRbjy8UdV7r1dvLlbu6T-BahA-GQs824EO1KkiBbhDYIbrQyoD_bC7OHU-acVB5e92qkE2-1bZWNM7cuqj3MEFjT7sGPNjSo_ygeX0ukdBgV8yQNcQINGq155lhSO46AUp8UOKmr_CGcoW1IRxmlpkdPQKOsxoP-p5ILoexzl_-7kKDYeuj4EkkbRPtjZo8WRfghOvBV4VpGcHsPF75RjmJetUa5CE2kCc-YhUd-u8Ar644nOoMA3vKaaAPcwhyy80bwr6BPKusGUIJxJ9eaOero7B4ru6GtsA6mncu5iSdTnjbwIPLZDQcZ5LVVxAPbZvmiAsATo00vxJHhr3MTW1wG_EirqU1BupfzeEv4pfX6A3rXzJtKRHwQ3dYMjtP2-hVoAia-LzVb_7fEGvGZHfuhXjz4dsGctIMxrGhjkOUHgSrGGL-zV1F8i6OgOYYVBO_PQYLWD94pKzHXbc_Yg5fsRarB6FPGp-hUVXIwPTUuy4U44hao9bj-f8-n7PgG65MiAzDlG-JlL50nMcRj06WZTAjjESyfkQZBp2k9muMmN7YHqCFi0rbj7wHbMZwAJdVhhuIMGwp7jltV9zFbDRR0s9rcVTEHxCrB7g-3jujhN35bl_V7kJJEybc1IWhFPLf8-8Z1_4hLgUNeY81U9gw5-uR-OCw2NlHRiVyS4SXK-zv6vYT_v_ldtljD9b_yGUIDd2drkVsNUEKxyi8bqs4cpb20Wr4wnE7GijzpRHPqD3tzrZDVHEfAvPI2gS05mFhdtb7JehaKIaB8NncCWGl5PwMCIipQVkvOj_Pla0HaVTj6DSx0UeVUX95SVM9ocweokVqad2VYqG_cWng6tZarA2T9LlBCfbXLeVjZsotZ0UHlQJ2Hq2ooQPmlqoLVjKr9FNXU4S225VTfMJ4kxt_TSrY5-3j2UD-VtsQje-oDWuF1LqQq_b-bHVVpDMO2n07SRNg0poaR1FP49794p0yrHa2UPjUITMQREK3gg51-FdiRqrBHj37RZWHR93gWF3hJ7GTS-zFzgqQs7uvBKqO9qCMksa8fOwWx02s41rkUdf0QbT3F6bTaCyB-54xH-RPKvrHtZvmrdr7FiG4SzNno5IAR6J8MWFf7K7=w1910-h957', 2, @mensaje OUTPUT;

-- Insertar Categorías
EXEC sp_crear_categoria 'Novela', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Ciencia Ficción', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Historia', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Ciencia', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Literatura Clásica', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Poesía', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Biografía', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Informática', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Filosofía', @mensaje OUTPUT;
EXEC sp_crear_categoria 'Psicología', @mensaje OUTPUT;

-- Insertar Autores
EXEC sp_crear_autor 'Gabriel', 'García Márquez', @mensaje OUTPUT;
EXEC sp_crear_autor 'Isaac', 'Asimov', @mensaje OUTPUT;
EXEC sp_crear_autor 'Jane', 'Austen', @mensaje OUTPUT;
EXEC sp_crear_autor 'William', 'Shakespeare', @mensaje OUTPUT;
EXEC sp_crear_autor 'Jorge Luis', 'Borges', @mensaje OUTPUT;
EXEC sp_crear_autor 'Mario', 'Vargas Llosa', @mensaje OUTPUT;
EXEC sp_crear_autor 'Stephen', 'Hawking', @mensaje OUTPUT;
EXEC sp_crear_autor 'César', 'Vallejo', @mensaje OUTPUT;
EXEC sp_crear_autor 'Platón', '', @mensaje OUTPUT;
EXEC sp_crear_autor 'Sigmund', 'Freud', @mensaje OUTPUT;

-- Insertar Libros
EXEC sp_crear_libro 'Cien años de soledad', '1967-05-30', 1, 1, 3, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_G_NK7GAj7_jKZ7REHia4hZpFk6HsSkOqebWrEvSpyFgVqsSVRpJiZaoqrBZ1-LXTXurqh2ExGEXNeFcvTRyUyAiiXA64YXZD25PPCqQJc-mubN6FjxkBuLgpZp-_pNMjknfZy9PWNbv5laZO55yc8BJ7--311cAq2vQvmXp6hHOa70XVIDvkT_ESRzrzdspwc7Q4-vhn6rEbq4hMrHrJHG6k4-rB-1zVA6yJPyBvgMytf_5xsHQSeg-gG0JMxOOjyAjvJcHIxot308eg6djIkmlPOONjmJI2GwdfrJlmFDRnxKpfaA-OlWUYQm9MoXqwWg63hubyuiYxWDYs3hZtfiww2MTfBYY9axn3rx4OO0zE9l9jGK7Tg5JSFQoIGB69XDUaSnahTXUi4iYFBPxvAafXxgjmNZDaABR4rTBoYGrO2JT5LT2-G0Q1oiew8QWP75P7OnJZd0FwnBYWaE1bcVDRuoClYHXbboVsA6fGllZHDiAA5yOGp5vk5CThKooV5qDHJQDc4wXnIv-deiLoWZ30KcCqpSplLRevujGtBBrb8Rmyx-JaLCYrIDGLs_8nF4oO4k5nFW3q3c21fFs-b9YuEOmg9dV0BowodCMLf8HamVVy5o-XD4Hv0cDB6m-vVSUxw1QTbhOuoaAIJD2vadhRP4fpOwu7kCjNVKMlBKDObIYQrmsAdPhw_fAUotghFcm5gW9QsE4QBXsY_JkNnr-5l7jRanryC-zyyBGHF3TjHzNC2-3gu-pcgQ5MMDf3M2KaLhHZEOjGhZtUnwrmd01O5wlH4TW5m5n5_Pj1qsgLmD4SFrTwHB3mTkk_qYmluGIqDxBHm3qOsYf4_eYxHlGAPrJm4NjiNfMHeX5SdAJcaxDrxiSqq2jbgYdfJAxEREPgT8PKSx9bzCdzAP6deNjzzZqhJMvehG2hAMy7zo5RQFKhliK0N2U-aUYV-UOnrTsbaE0TGVHLg9wojvPhv3TFxRYslkd9fkz6gPw63eRh7iFU-MSksCzJSum54jpPPmd6DgkYAktLZnlmq-YbJPdfA-Cm9YsFhjlsxcP4x4r6y_mgW1itTidRsbz6eKDLQ6t4dTKNhUwlQYToaIuNH2n_tyXMXERn2GS019tRZCXe9BLF4M_e13wSDI21N_Dtl_GLONR_VBzzjGqEx6f7ASbVnp1UhlrVEbGU-FenS8AXYky0N5DJy91vzEu2ey_IM8l34qDaqhP7A6FacXMpqWOmVmHGSHLAMVj93kjpr4sY4uCXcKjZePjv62qfljNm9VfqxSpGHuRL3YKfzPhXdBVpMUl1zna3CHLkUT95XW9cSCIzXBPw1-mlAPPerpg7gKx_6X_91uB_epNTtYv2_5J8PAWxINJiiJdmglrRbhnC2vf8lWg-gVEjxkILB_ElN6ZqfjPQS7fLKnpSQSzfuWyI4EKOloVkPF-YXG0bYdfibs4Nh69cg1FiV-Ji-MzEYX-ifRN_1HUGKfq8GYzpSZV2OrZLksHLH2_-0KO3SK7fq8no52I-vPrNJVUjuwIwGM1wk4RhD27I638fMtAEIEfHbak2esJcaRqsPa1X_qgBwohdSIHhju0p0OtKlxe2vEOebN0651ybxwEBes_8bKTOOKAslLRmr2JQ_afrrs0zw5djItak6wX1C6VNKgmvUe2-B_HYQPkmPprt7OZ1RPSQVx=w1910-h957', @mensaje OUTPUT;
EXEC sp_crear_libro 'Yo, Robot', '1950-12-02', 2, 2, 2, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_Hu458PbzeCzE2Iw51Y1IIJYcoIxgN3nqNd7v8EHMlQVYwGwYRsraSERCxPrZKEu-uXxru_72drtSdSHTgvpfRrj-Vmq0Jiv-XGPCRtCbhtgl4yYROILV4yM_5GhU9DvkbB7N0VZ_WesMRCrTSbWZsAZgsk2S6OdU9NaZ3ML24iamqJ0ZqJwgaUTIlrZx5-rWV80L-lCa_x1T4btitLaWWCDxyuOiETqbEElvd4kEhMfa580dDqn4AUAZsEHXwfheQwc117XWnY0Ms0PmYqfUY0uFN6JxvILfokT5uqpJhmICYPtDb3MO_SCjPYf89NjdFGFHvTdGw2j6tih7GibP55lC04ov_U1prK1CS5v-uGaRr9bO2xKZnqJZGRSZRayNwomvtdI-67_KV7I8Rgx47IW08Y37ij0YsqoqCm1rH646UHU6UNHXDoULt-ZSyaiOlx1Tv28Ft2FNOnqbRryAXrKWuSw9T_cZdy55f3oEbcG9OTq21KCdWOtGgGYOCkfMtZDG8Qd3BPNancA7bmqFgyZWjCMKzaFVgbr3R69tgUcFTYPQy0mXn-BMK_nBydE-H6-eSY7q4-3rrwSkT1pWfrQoevq9bv3mBW0A01FAyoErkxAHXQSjash6b2VqIpcLt9bCokMDS914J3IY8rH8xImgMkTcNv8RTQhMN8tsJp7Wgo3P6wtJ5fSCqe3pBUNTcCaMB7qKRaoHGWoCarMdqQ3-98CUnvaFsd3h6Vxg0dfhnHsGz_Hg0XTcmFAW2xAxUCjPxDegAjJq0-FESzFuv9w5y9w3uIj96G-A5ffnf6rJd7m9XYDEAHi84miyyzKA0f-NjjgEBuqY5KbKlX9MVmYn2FkTAp_54WQK9ZasHguSu4G6sEWS8LzlqWr3uWGZbVk20BX2ZnK4CJQMW73AcTtE3OrSleuy4nI7fZjObTUkWLj2IwYq0Q61WfwYfJ7ZmCKK2e6RiMB80x3P6pjhIqeDmPLOG4ZZoB2ArKRryEJ4G9lvRYNA-BfKyFmRBBTngTGRtnVaHzXq42VXMq3Znv6bjT3k7w_YwzexJuiOzT7J-5HO_twQQTpXxaK16GFXgITbX7M3QiI0n_S7NMpu_u4H3KRmFJdQvJTgaXyTcBFSaaO7JX4jusu7f7i-SXS_wkVm343gVZl5FLKJldLta2BnGPDp9leDaYRG3DQQuxF_--31ozyLp-E552PnQSnKv8Nrvio8UBr21QqZGZsTIG6h18JcYizICA0n2MYFWwI3n13caalDm1KIT4USBiH-2QkYjwDTUJjWEtw5KELCwP4-rCU4xJ4PeEtYAxHVUyPUuCYt_D5hSBpEMOA9ZJDmyA8lETR80RJQgez_suGx5fdfejAEfZcezch2QSJ4lgYs2lRLGl-rXFTwMKVKnDZu-q9P3aM0_90fDagk0-v0DjrtGOqQm5fHWABqShDISm8IUJtnf_pH6FvYmbXpUGRA1QZoduLGlxS8pVwXuLM0I-rTsblSXa_MTtK3hhTP15dua0N0SNY8lzSxxZWhGkd39foYdqRX9PTGldtXWN3BwiWY8NeP17Fs8vefsakRhJhlRlsYIcMPmkU9NPhSbdwdU31jqtymlooQ-UGSSp43xMwgfbhvNkzpVJJc0n9Kle_jYzJYba7dsXrbKXu4wmIm-AVLXZOY6FnIAELUJVUzubX_SR=w1910-h957' ,@mensaje OUTPUT;
EXEC sp_crear_libro 'Orgullo y Prejuicio', '1813-01-28', 1, 3, 4, 'Disponible', 'https://lh3.googleusercontent.com/fife/ALs6j_GEwOLkgkpbu1yLRKVxMiqo7EBr_osnF6iwkSFbEk66c3kR9t18T-TUCKwNABhePq6A7hgADN3aClCvcbnE8x9wviYM9dAEJA0bym6bTezPwUtuc3JQaFZJRNLNWw1vIRxNmikJfmcSHIRn3aNmS5x5tX3Bu1nJUHPG80qwqVNSa5E-GYVamHz1rZcEOk8VqL17C4hQHM728dgmfmOd5dY8mRrOO8CwZImx2eXkaeWm-0-cnNNqS_UU2_wXJxnmiIqSljSPie1CXP_9ZHaVNqyRadvAuoHuEVPhrtjBZ7pC6ocqaXD8ARQooFgLdKxAEExBIagSyxauob8B4VtpQMMLUUlm58CrBku5nhDUj11sgfElopeU38hUSJpERCNdBUUY1Z1pKXWT7Oclgr_SzhRzv_a8BF5yNZ4Pqia99Gqtv4mu8bATdrJoNrKNLsdg0GEc8dZ_GkDDeebjTig2--iw1sb6dmLHhQe-jk8TPsSwiTKjYQ6IryQIWvFb8wD90GhozOkl6p0NE3WgmOrKzWZwikYlT0TH488Y135MNOHVXzfoVfJT4KHov8D5aI6shGK8eq5mq8GaYKC3fKWZgURezi-CEmYYDENp3L60mdlOAqyRJP-YbpciFtgjalE3BSUtRvxKpkiY3tJfzVS2ybv70y6gFeU6l3KyJlBh3jnxEJOszj_d4MZD5J7Yo5CsMTHGsM_v08ZVVi-kLBZafuy_5lCq3EDus7NULbwly7euWgDjp81qOPIxcQqR3tn4idXpf9-V7kMPDt6UZ8wiu_0S3pCRQK-MxLZHAj4JTNagfKYb6Okli67vnL9vhRKeyN25kPdrzQkZN0D5ZyBb7jrAPdQ0UjSNrVnqfsB2yXMVMHGahGkLo9T2I_xIfSwJIAegUF9xLAdUcWxF8hRLY4mEqWMSnuQPj9JaMq4zJjzJAAUxwuViQEn7IyuLsoKvXgu6VDM-FkPZX_OA4rxjAvIE2TUc5Vjnr_wJTrObAsul4AWQCYQrpqWKjaBz_VN9zn8pr0zZsMMi1jvwkDnAOw38Q3j_0G_U9Ll9u6eU0o8htH1NoXZAWlo3PD9iNO8YfxindYx5mOUwmClxxmS0nB7pNHsS_tnJ3Bmrk8N3he595MPCyQ2C2TY5xm6HQYjeuZm2F65V9dyV3XwC2r-751TZqFGm1rehQfVJLl9d137WeDbTsbEZHjwAZaqqottWWtc6-5THkrIkylj4B4jIWCwwNWW7MUjHDYCbEsUfyZBO7T0ermyH5lL0YRiphuGRP34wjgd_eSk1OQ_3YmF-KjA7pvuPrN8MDQqw7nvE927OMlvrj4YWIUL12rYMxEGpSaHNsqAu3Mxa5da3H7_gnbrm989Qvfa8iHWaEzFNPL_nsBm5NHEbj5Eue2OBWC0Anlz9Qfe4LD5HRm5Yf3m3EizSsi4rja8vzyvtXiDxXGLluUH23eIm6RXfC1rJ6UAS3wqWfpUVRtieLP5a0scTgar6U4Mw8LERmAkeKvtHWClz1hjYEUshvgoY56vsLVtoSSsJ9jlCOCkiAAxJ_IeEwqKKvzJgadF4LlA-UjMwg3tzo7Y0McjdJAgxcEgB3nHuFTXWxZVdwFkG1A9kI-sDO3_1QcH2c8VVeMe40m5Lh2yGAUnxEz1ngBBvsRw1S9e21E52e-TMq0KFNL6_CY7R5osdQjk=w1910-h957',@mensaje OUTPUT;
EXEC sp_crear_libro 'Romeo y Julieta', '', 5, 4, 2, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_FPmwbg3W24fvgfF-RYCf3BzZJTpB0LheLbtFaokt1d0x5JkB4rx0P0VqhyUaCt8V58c716N5h6ldDdzPEcs-MujT9Tq1Ew7HHEsmTrfLlzV0EODqqnS8gOaqD8W2eq9RXAy8kH9gWQ15AOY2sDlTv3bIRZ7f5KWLcqLJ-dtR1MD4cZpn4RpGZrffiFQL06zR6clIYEWQjlT2BEgjyorfP3wijTGcABG-mPjxodIy-hNvkh9U-AUjceoWWXaCBxxpMtLWjm-qejDnL2FWifcoNRc91tEkBivIpT_rA5E7ZnSH3FCSMEVwwghjncRt1vBo4nT71kLspV7bDNKSD6OpLHuXRD6l_VO_wsm5kzAdV2wyEAEkIsBGakLHSvkXLqtTD37qDTerDpy4L6XWV8w0RifARxmcvBnkWPGE15FIEklcxg_kGZqUr7I-3_-tqkhj2Qk6rS_6O30ssbatu8yRbZSvcZLg4_tlfVxOk07NvAtWLeFqIuhAqSbGvy7nQAyEqD65fMOR3EjvNCsUESdpQcVqciZZpr_XE-CxRSISEblai00gIDAhCHLGK9TjK9bANdT09PLvPWIltEcXo3BVsd9JkHzA5sVg5eZWnDye64TNIrzwxqTHH3U5sSE6Pv2FUN30ELQAx7d48ukK0wc81Eyqwp-Hl56Dv97dFNILNeqbj_dKSCdDpiIHb_r33UX5TID48la2hthpCU_pYwLXX7h4T32ZawHCeH1A9iKzQvhdSXwtZpePKn5tmV7T0w3eAkVAQxFXJEEJZnpV_0P2rdOW1NPfN_JmdtjJFFnIPlkX9QpTU6hKsiEE2I5EQbVCupSc_P9EA3H3yNi3HmMj3XhHynmMt4_I7atw3wNhknppkkam9ItXSWbS84KObS0ARwOH4iO399BVwrEzCUw4heO96fe0eSj_W-euFlbs4gyA-Rdrp96xJ-yhYsB2owZ8XGUB3VZIUkOwkkIa2KXFj177rRH9VVrvqqGMnYAq5SU36kbJk_U2ybLN7TtJgVL--c_B5AECKJSk5eBOPjPpc6TnP41TL0JaaIUJCpE6VXe-u1VGgF5kfULCU3KzyjvdgN8CX1tDgSMxP2-u2hJIjM_KlLhaiEywSdynUXEbkaFYSAHVitwp4Am24j-zu-lwlBxvgCocYISXAxkTDhcv__tZ58B5JSgGnWJxzlNN0nq6aQ3AnwDuB5EfvwnWsWt0qHBYFCS43KFPnvq1UTOAovlVUtRLuetNmbipFrTQlyxGEUoxOCrkdQdWOMnU9gG-uRYAMu4U9hS18mjLb5rUs8G3JD_7f0lDFc-bGX_Oql4-N2CCQBiNqHzBcSnZMLjQd6HhX0jztug0d3EtmV_EQJqGk1hpXGIaXgJrDdMAuUPp94Bvg1vrNCGXW01g1GQclElCB7r2-bd81sq-zef6ePKrvlwfOA6zczZDhRFM-d3ywsHmVYIY8_e645X-FyzsZGfVM9hN5Y12A1sgGlMJGUY3tDAFIs150iBO71GBYmine1Ffiblp7dyjksCUlBHan_cj4u4GxOrCiFV0EJhZjCgbDhgf9ABMTnZIznZ_UhZKtR99b8uNha2BDU1B4zLGMvYTECWleAPh_v5BHfEK1fs_ymERAmbttpHyCK73d6VE4Ba6KTpkgh8j61teflPtYgDfVLOKvRfKT98j0u8tcVKwo=w1910-h957' ,@mensaje OUTPUT;
EXEC sp_crear_libro 'El Aleph', '1949-06-15', 1, 5, 3, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_F-wly31ZhUIq5sdVrcHHuu4q22OotUi3Rf0Mh19uqzWxRxVQ8-JNuowMOWrpy8dMAcXHGmLzZKMnzRZUiYOQYM4bCcTu5apiWmPIFDXraWkwwmIbHm3OIAftT_a_DF98y6-Ek41GWC8kKwZ00hx1FDcbOTBNDEYoyvdPBfDmNg3tBDpOEgENhkd0tyLtg8TWZSOIEUPliRO4ZeutUruwVHJF3s8UCrLu5stYuC3b4tNnViYGaZTj0t4OwrDHFTjYgtH3qVNx4TbBuAT20pyluhFp7FAnKEiOKOH4XpQChz86M9P6QHDYLap_0kNzENSkXgOrsmtjKTs20hOez5tP7e0VRbvbytwk1D9RBDOkFjUZV2WtFzoEEwBWDmlYtluSkNjah8MTXXj6ksTKVXSrx9FnlbAFG9nLb9ayr1SMKZB9YMzGN9BFesRCqgeljQ1U_Ff_VrwmWUJc82ug6SfhGBeXybJwJHzep--IdeIZMIS4b_uG0gg9X6o-qDhq8ol6DOC-UHnxr4Fsa_SB3yRN6VjXrpxi1mpmTlQ84aZi4DYVRS0FSVTMGc5yT6kKTdPEfsFnGea3Woy_j_fgQN1xTllDWSK1jbZVFg490FzDfsND90qCz0jdeXCqJnxr1oe7s8ubm0sjfzKwa5ztny3bfd0KgQKcYQTWZ3hUDAPhciel162oa8wr2w4ul3T5mJXe_6QONQRY3NAbBj8jLdLVJP63Jr-L4yeZF_IDWC6hjsNwd0MvKa_w5Yk0af6i4GXe3pHppGkGdiZIO9XTXdM0d6OPqaXnlQyPaoYl6I74tQ6V_5YeN315AnDtTjthSEqXcNSF_ovSl0b5Msh0VUpUKeLw9Z4n_o9It5ENVbQ-VNNwNSwlNrUTCydMb2NVDlDU47rzSntjOutBni2FpEK7o705wkNFStj5t8FHW_J6yj5kyVFWIXShxKIpGiLbqEoq3BmrIH5ZV2YQe41ekzZ-Pig1HeRXsfBsXLTMl9OBHSQR_vDKIH_TTUIIV83PuD8cleVqkh_rFNEPGEsUdFb0Hh4nrVe6lzrZ6-NqWWg0oFZy6D3AQLOO-il6iZAbTw3fViZJLNh6L0R7XV6C2qGCWP9d87YvQA5QO4NBP7x54N2E12bYMLGn5r5mXygnu8zJoqHbbtTv4DQXpVZaB5ykNzaeXv21M5JirzmZd5cM2Cop4CtukdEsdKs0TVCX3U6llwQYTZ78h-UdhFlHjswj33pOCr7P72SyXUT1GII_jH83jl2BSdgfbkfiPS9lpQckK5e_fV8Un9beVBZYL57CSl6YRVuwSLhg3y8fwBShcPnaSifVNpklcIAS16Bw54PKR_owsdLGWuRHKHZe1-tfYv8WmkgOJLDsCyHpiI6vfUGDmKOO9Y9IswIzfuqpjqzQDZSBEGF5zBa9Yc5GYZ8tj6mQt3Fb58RjTUCzZyHMRDCjTHYgAHegUc1uzh1hKRrsm3xvnNbNqo1dlZSU_ZOMKYI6N1u4lNBTq-Hp8z2Ar1Ru3XJdl_kZYdP9QqQzitvnAuxV3a7qY7F-9jq_lY_-9gnw67oEIlVVqiCqryfnRS6VwMrj37Ls3rmDhULhFzQkv9QIyZXu8bfrSVZ9qS8tbauijGBlTnTX14jHZtdmdjuVMB9GhBs3JGKYD6ve7C-spBmINz-7vbOtQyryPsK5psHfxu=w1910-h957' ,@mensaje OUTPUT;
EXEC sp_crear_libro 'La ciudad y los perros', '1963-10-10', 1, 6, 2, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_GVSTyVg_5GDR0KT4xfVcJiiKgMVnAXE4dWLgYA7F3fHn9ObLiEA8MGSKKxwTK-BCKrexQt_4APzcSZBSVU0oKO9O5cJ0K7EoY8KmlllclSx1sMhYigxzEMueK8KQcUZKL_Dt97T91s4TrqHk8We0BqY9JzNUlHNttt3zclAWZ3y17WKYtIm3YjYDHMFa_5iRwXpvdXQXTUekXW1fZQQafY5vsjDoaLkqZX7WVnZJ42_4OTmR4qtg8Uwj4DMxqxdJyqdX6IS_ylCxhadMca-33ntGDm95GPviiRp2uyF86_xrRoSYqv6TcAfDxfyNg9f-8dq8V7_4HtVN25RqhlBnyCG014TzRHw6rsaA7KvJk7MtFel1L3lyaIj9DliJ8fM--5BDW8jPftFCa6t-OWxFN26jEyC-egxpRZUHfbwD6I9fPr5lGpyC8diDxc4t6asiKtk_zlEdOA-QmXQSeVVEf4nwb93-pM66LZwmQVY5ikTW0LAio8zbL0jse7pMbPBLwwOChorMPuT8Ayd4WtxNTQrHLi3-uWbcN7Qr1yBR8Egc0oRNb1HNInErRRhFeiL79Jly_9GIv1E4dr00rMPycq1ZApH8PSeGwlYbYyj64jo7digpsymvHwRxkCnEMhHBoXDXp8ztr6qQcOuF7nRzJWtTdd33rnMIxgomYKBukO1cMJ_mMb23rJtsHGWYT4a2hd3LiRGIhdpqOTesJhatXL6wk37ITdE18UTdOge0ibqYVt1AanW0O3VKGILHmla2xJKBjzOKCuxGvixJuv-PS5TQ31mPan4oGhR6YLozNI43K4_TyxC1POAWUL_9wv6FszlbRqQih-KwMYxa300kzv587LZWKHIvUZ2eBhmKUrHGOfnaD0bjeIHWnRqLNYAUi_OP00z5BwNqHdDxljcNVmmbPQSIBbMjeBiGdNrq90TIe1NTY3v8d0fXnIBeBd1BEiK4JtlsB9vXfwu7Kt_QTzeuEDeE4ZXR8ziKMa3zN1riC7eVlAlWM7JyHJSlCODYkrIt-ZlqrK1-AdJLJ1JZB0z-l_6YX9e832Ma7e3n2eNpQVWksP-VNgCCEOdNHnfx5lKbMcye4xWS2Gqiw0PpX0xXnLRohFA1-lJnTVnsiX2CQtNkNQo6kYR3FUYFYNOmz5a_UltTpOCjvN2qK61LVxjLHC6iQrfrRor6DLAfNFGZO96hAvcL68pkWaFSPBTLc2kgHHxIhFzWrsApGRbrmOxP4n4GmGJgvzncVwUGWfLcUnFYslbH_qBH1vTz98QxGjugLiOaedLud4KuUz5B3JTuLVMWKQI-7Xd_wXZgRmeN21QU4KGdxqqMZMn1leqwv_VcY4Vgs3EsVS-qSlTBgCqjguBfz23Xd6wYPoE0QmTQ58dJ3wgpjLlYdF65p9KChP4E5tUm1fsq3A1vFyoxHcEzgADfgs1_TXELYkGdUYjZxSDCmLHptBnpDTk2YllOYHXXvZVgNXAKq2Zp8oLJEj1-LhvCjxSfXvjMpm-6bujCJM-AEL6xV52yM4jnNMRCmNv50tV9Z98rR65ZwRLLawL8EBeHzgemmmKCxrKABkRRkkD25Ttgejj4QfDTvDYNLyGAKrNnFwOOAeQljqLkW1COKgqR6sVAHZMSSko6SM9_rx3Onvzd4w9DYj7UNzSaeKEC0cAKUvJutvyK4FRi1X_nI0=w1910-h957' ,@mensaje OUTPUT;
EXEC sp_crear_libro 'Breve historia del tiempo', '1988-04-01', 4, 7, 3, 'Disponible', 'https://lh3.googleusercontent.com/fife/ALs6j_Gxat5VnCMDV513J2iJuYyOQ0_gLhqmFd--6VXBUkW8-AOM6X6DaHpdNClLQCvrSOVhbxibejNb4Vr0HxtctAbLdJ2Kx-Zy6dxQC_0Je1Rhp6dm45naJ6eEStCGhOHXF5ttl1nJYVYGjw8PZUbmewdZjoqmFgxTJvHr2X2HgINWJ0ihOr7Dm_C5kOEiQ_jMHScUHLbciaS5t1iZE4gc12Jz_3mD8Uw-VypI1o4vyt7ciIw8mP70yfKkNjVwi0PhFEuH_wqEA_B_x0jC920KUYjNpNzClSrDdShm1BCrMAxhqAlhipQK8qr76VITe6lNPklamp-P7m9qo9BOjC006JZB7VwYBr1PDXONkTOCkcB8MF4-gYDBCyhFQebBrUQwX3zCQRdKPJnJIY6n1I8L_NSELJrP-c5fHYICpIyaIFyO6HyWaMS4eljN1wJBLyOdJQ3IhbY8ZfCE6ma8exexXeucyjHGVdxXkI-w0qMC95XrJSHBqF5b9vofwawJcINeMBr51BFu8nKulotou1-KByC9K07fd6fAgHf5TTPtI6uVGgb99ekYRNuvXpVmkA378Izvp03kIGJ93yGGQlcEVsgJZIsMakdk0rgxO_LTyp-L6WfTYA1ooIea_q8byxsveHcjaNoEJ4wVsOs48wgYa-1IqOTC99F1P58uStqJchVxJt-y1llUBru9NxPlXh4UQdYBzM0HHez5lBDbSSV0sY3c8aLwEW47zyJVrc-TULw716dgrDW9pe5VNuh9SZRPrPBdiLHsyMuKKPSPxwqLGR8BH0bN2zFpnX1WJjwugs7wUmHEzYJyJKaP2r58EzcY-jVETTUcrXjG6ykSm0ZvcWQ9TvkoQehhgCWS5GY1OV9XND_UcCNMfb-zGMAofZBH9vvVH7uzS71CYaCaObRYHulpRkR3qg90u7Djj16fudiXzI0bdSaGJEyu0WwnDqYMCYaWrrvhA0fp-65m61MnFxpJNQfx4B0N8qQwbbB8GREDOwxznk7_vjohVlkdPaJ1-V0zHIosHlRUi1rl2sSh3LbIR--aln9IB5TSb1Wi30PrKiY2UOoZSFUY3L6RKcKxZi8fWcWHVLnDSEHYt5l0JHjIEQO5uVYo2Q7NDQ0ICZMeV4VqCEs6l-DEiUyIZa17vVNNcFDsMlIQ84SCzvQtivH5jL0sEHPfsdmF2TlBawbc4aXCx-eULkzJnwjD_2atvBAJ0qIlmhKktcVe0dq78uUcdpgWT9bokjUR1W6WccRKwPfYltF4rFOC6LRjOmUtvdzPq2yVXkr4lt5p0PR3KArd1zFd9W4-_NS5MsX4v6m5yefoyskk7K6BW05a_FSjNL3nOfmqbcVrTjoXRXNYaubDaJXpJSgPI_Hmq4iOlspPCPHJkn-fevvcLtA0XRAtarpFLOT6FGQJoyh8_ODwfJ1hEQM1NIAgkbgv9G92_Ag8-prXFXzFjMRe7K5Edy6Ehbg6ZZj6wmDcef4_mJRoHoOUpaMtAitvBuy95sD6h4td-dD6qPWEA-3qrJV6AOwSMc0feUImKboCYMu_FqbrGz0WXyJqFUVBWg739VMgiUDHQ5idR1AxmlUN0cxf7ZOxWhA1sZby4SodQeD-rP3R0L_TYHkhg-M0GpedJmVYuYI-FuXGEpkX63J__Tjsxt5oEuVHVsehiNF8pyW9Fpn0WaYf0b7O=w1910-h957',@mensaje OUTPUT;
EXEC sp_crear_libro 'Los heraldos negros', '1919-07-19', 6, 8, 2, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_Hs6jDWkh77L-mEPuaDrS0BT16j9poOLa3NWG9g7LkOiJ7kjLFUf54qsPcfOeFt7emAJVysqgh3n-erFn0uhqPFBCO4MUX5AowsnAdAPvEwCys9r0NMBWNSh3doxtST2Gv63Dw6j2wmH4UFgUbE2jp3uqNB_lMIAIq7zYR82OLK4MZFjKnfESx23VYerHDVxR-WFMjb4UssnGv_cIx3JWpWjxOKhLWeqirae1aYzIuWmXY1XtYTKITBY1d0oDUUoZMIhhtd9OiTX33sXxUMJqSWXCxCKPnjmV4lHVCEG-fE8kQfg8IjbPTxJVgU-PlBv69jUQY0Vt2bgvpFtGaYORtz5QZXX_L4kdBAMB17dpMtOXS7fewjhaZ9o6F7OhcwAEyRUnUMbAb3NqYXkPsjFbh0fRYYiasJPdClQtwWxBrfZcEF-ayXC6RO-aPz19Vt-H45MB8Xtw6Q3nZDWhiDaJFQZNoJjDwMIqXUVebU51LYxyaSby7PmU_5sMwfL2UDpBXsWi8Kake9ZRoQKVpYymYRjbtBfcrIAjXdA1FhMKyUXfN7Yb-hdag6eHHdBX33NB6gLsBvkajjd7MwIWTcx-Tghuo1k-nm332W1ccO9TvLtJ0FonQch7dQItjFTuKQ_ol-WmWXoCk-jTKwBoCSEqWdo36wC22hiSCBamwD0uHY36nfIzIp61gJB3tDpO1T7QO_3SKhjDbDv74RCL56SpwwLiJAtC4Uh5ZVXlCBP_dq3p5Epyst8blM8Fg2fTmxXWcYlRzxfHJitMPXOCZO9dkOAHbjwqX-ydvLd3E4ziCO5Cr7BkwrP4WtbkqSjfyptpocNYZEiWbYRgmuh29ltZ-B-a2ZiYedrRMP3ygoXKqdoqWhbHkfiwOwgopC1MswBYWmzUBLQX42g0uzhRkfDzfJjCS9vJJH2Dci_MqsadXMcTe1oM7bw85nWx5SFKZVrSUNWqRkgIj3F3wUNFHas9_YYRYa_HkHrv5cIsoxmZWA8rcjZEB1pKPrN8zGB_ByGEKrK3ahgVXKmZo2TRo-T4OAAUR-eGHai3sJ_t90Y1px1-Si7akl5ZAYzRnVaIKWXduB3t4sziOhnGQSYft22JO5V9xWHWxFQhMVK73PRb-rXCmOG145Vf3AYDF5R23M-yvHg7VJJFInaHKp1duumWzI4YSwegtBNfUwXhOQMacTY2ffVyKFUlLNX909W95APgLVAeDJogiWmlb2VHWyMn32SqgBRMfbIOZfvduM3nUyfxTED4QvcgX7zZ1MNiUlcoCiPr5O9PrHwdcgVHlbokRMevwxtzAISHPEeXqoviX10bihp88NVe9LgD-QVCJcDzahf_5dEUP8hiw4KF2aiboRsznedgi88JFDbpnAKQUQkYlFkhK74s8UrlhHwjmisqkJdnR6jT-Eny26RPxIeqvYOVFD8X1PRahH6lDwdBmJH9KtpAetpATMrgDGFKPFFpZ1Y9JYbpsFU6vtLwa_qDIMacPVGT07mvUvbaa6ZKdjqBcuiZtmasYXCSjKTqcBLmSrws4drJEB0QOrSZVTcO_HSmlWuil5GbR7B_ow5cDIxRc3gO5HTgY5xfsACFPzi79od9nR-Xci-Q-P0vxza3FlbLh-OCejFSsesCtsNny1A4D7tb7ZwFAwRCoTgl9WKODHopLcjPsF060-b_mrgYaEBZHM=w1910-h957',@mensaje OUTPUT;
EXEC sp_crear_libro 'La República', '', 9, 9, 3, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_GulhyOh8wKjOaHZC60qW0YIY5i-aHi-uhUAZ7DSa0XRH3AtYGKLjWP5A9lRbOl0FXZWFmn9m3lWeDfmLNvOrzXpsGH9B2x95IXltNil9P2dD5C13ElxlFh54NsQU_PW9h6T_UrsYeWSCdrfwMCXGpuOMCAnCcfGVYqnBiX1eQYdMVrH32q74WKq263q4OOxzIaZIv6D2arFNZ_bzzUn5TLz9gIAYGzYaIoxm2qBoyXKjxFwa3sJe-2vHq6KwcLQcQbIjWgwW9Tb-R5UE9BPNiIxURNwRtbE2tE2jspmih0i9SNWQSuOnxkVG_3LjITR2iyaWqSwLluoK7aA9ROrKgPYYbwK8NVgwH5fE1Xb4UMS1sbHQgdFD7kP5JxSR8hS6GBCFsfEUrWvsTyJFdVc8OJcnQLwbfe-DccQ_eEn9Y7F4jFbcpN19JEuqQixOeWEFOlN8Rb9O0HiTdd39LQfDxwccvecgLoBXePfeqWyfG7CLSUW09mjMrzKsIMAHz2nzdOFRcgR0gYFbR97LcEFpB-iRPY2OL-1iYzkXd0Y6QVMxRGjeO0WB_CIEeMY_1eYMckx6zQvJYYD3qrc3kcmEJQVXCpaq56R8fn26sHec7K_z_T2w9ZB-fNc0eREKHXoNZxR3XmcYHC4tId7-vW9ArKoW-dY_H5MP-BunduiBL6WZwv20FGcSy0EbtE2hcF0Iu0GtkRXCLYho1N0wXl1mYx3EjD6H870wSjRj5e6Eb_U1id3vI5fDP1ESL5Hfe8z5s65xNqdUxKGaaUyOWINVbhOyHNeTqHEIp-W-CDgOJHmIvMnPtSC5VUDLprFlKjmgFEYS8V5eQT8oGeh23GtGIGgz_nYJBgbyTnxMqxkAYigpXkzkTfuuQQ8Fyuu0d3uESbAhL9y2BsFPbNg8pwTiINAqpAaP447vFaF4v_7VUA2NFfiC_7hR6oYG8DUoqIVrWeeQa143837YKFXwdlMolgulby2JMkeGftpTIA6K1qaqFgOUxv_cDM78PWZxN5QYM6cn5BFJpVZQLfoOP35x9JoW-cYQz590If7tQkGgEgaLehh19yCIqUnXilUWecMaG0JTAQ-QAmiQXAbQzcDzHLHo_RIbIiLJsZaCkFR8OEvkcezcddDa5jXdX0R5NqsXyFauU_vCKOkBPJ5C40_VqOYmauUC2lA-YsAWru1if_tVI3x_GMEPiXAXgQs1lDH-I9MIwg9vzymTublCWgwf3845gydv4sEK1iADeSfbKGoTuTaMaO2FVvSFkI3VXu6BTF6c4uvWGW2t-brkaVixjBBS3IZCAVbBb2E99kOigft0yzLMkMTz_bFizFvPPeT3h6jf9Egup4Nt7i0TG4YorU3b8j7zskmA0ukBWzjYKlrk1QiCFYUyMqQEOcUcV99K06n7D5rQRLlvbJzI2c361HOUhKT5ikVL3QmZFTNQ8cMjdG3tNP71L1sUeJyYOKe8I2tBITvdyU8u68IRTrlk0e0uhswaBI7FC70AEQRGef6-G9UFYE6FrbVafwuT-jlP0wnLEC8sEEBx6Vsrz65sLGs-re3YwDfO65eJXGV1UexKcyvT_gcg7NZvKzuwD0K1eovQHugbJ7XWOatkUa4U5VFyI7JcX4voSldShWg24hojg5NBDGX0A6FxwTVoI0ruTPiaLrkZoeb2i4x4hnWHZtblY=w1910-h957' ,@mensaje OUTPUT;
EXEC sp_crear_libro 'El malestar en la cultura', '1930-01-01', 10, 10, 2, 'Disponible','https://lh3.googleusercontent.com/fife/ALs6j_Gm1vTo-GAMvfxCB2SBe_ksj9P-0Db9sxldPpHlWOfjCRAAcHa8llSjK7v69vSRNDP24F_kxYkhw1VgI4ukENTqaTFnom_tpaSpmxLrYmijmTfx4hz3yfk_6F3KgkFSUAnBt8f2NUUHBhCfcX4fMduGx87C6jb2VKjfTR1y43dZ-Ogu2p02gsL6jpPBvKaZljnKzz5zY85NZ2wcBWO5H-x-eMjMxQBCP0n39Fww-WYhMl-rYgyjQJO5qiydHTANHLplVukw3idy1_jHwM1W8Gq6B5Vu6OIGnmIBiaS433OJxMvG8Qrc6h_TYEOCSjV7fJtCBgONm8me8JUzPClpwTOf1HT0qUpvK4zfy2_5xaBAazmXER0vi4YaQdBDoXVycjJffTV-L-jLfqoHwb8Mc2F8PhWmM0Ed-9EVAVFA3YdVRni6K6gEvkla2fNuKd8G4cqFhgLRBQTrQCMasUag9oJ15w0KoAFWHYptAON954RWFTrrSdkCi80g6ZRsV8tG8PXjbL9DRs_2ICl9LEclqo_CakvvBGm63cJV6fTwI8dqy9y9rSAzPaT4SrvPsYpHfOtaWROQD6k0ED_CkKJkJzyRbcNdtFXIBg4n1Y3KtGNDiF6iuc_5hKAX8mMGCKcQ426Dt0t6OBLo-mQdHB56H9JyZusEEd1kPHk8jwAhSTHD_m7rvwy5NqOx32q8w_745-duLli9TTlcrXA1FUl9BI_YcySo8XN93C6AxmQ5Tlm-SYYUXS0M5GOAWmzpePbuBrmuOfeZ2kPB_XIAvE9VBsi6F9-Y9GPmku1-1NA0CXVFh2HWxD-Wi3tZeANGQmtfItqprnAVnyMtrqNdSxYgRdph2-QkhPNW0HWKC5NCD_F8aaKEOZ59pVJx6mllTHA5BEfmJk41IT19ZtO4Zp6ekrrphtB341OqOHb2NroKREIoJCW60LBbsyLsEmyAeRt35Dhd52U7JQjgbpIvi04a1sLDK8XNJOMajELa6ICSZkkTVVVw_GFKytwgpVghgZPna_Gf1wxFIxn4zJ3sWqRjJuZAVewlFATUCCIetX1W22QH2GhuQNQJY3JrL7W6tVcS1fkdFHl0B9DF1XYuKEXsz8ioi7-e1q443JnVTAm4nMy_djwPAras7htY1QcERsPhHRvOso9Cgssy5zjG-BH1zJp9Ntq3OrKA-NpRt3PWJXwLOICcx_ugsjla5RI-86YAUTKV3BsqW_woQcpUkcB5ZL__mnr22yCb-JutzRUHljRelKMolCOhWrFiago4CZIuhWK3ihFrsooU1KK3qI-lUP528LkkEaouw4_Fp0wm4QdwfJfmPEBO3Y857jXGk63wxvaxPmmh0ASfWzwhqse8UZohmOl55NiqY9a4nw3bcJ4s0U29qRxphfYxKaX_l1BIe53VPQ3ZtrWRLo0-okRQUrCTU3jTL2WMN6WIGKkiw6ay3lN2dk3S8gmLuOqbWSBZUyu65y3OoxaEUBf6_t_ag6SfwA5TivmYFGtnaVmiPx-hUryF0tntIcXFvpgVwLjbCrwVBi1zwJMdKbdsrjO2im_gmG9L57vXUv9kWbm2qRBE5hZ_qzTN-X6nQDsdR9rYKiLTG9J78hnh-cekde32GHB_xqDI-eUyG1AUFm50zg8czs5JhdNBF2ZoqufhymHJ_t9mDRfQ8Xygox6y7g3CuLY1ppIq=w1910-h957' ,@mensaje OUTPUT;

-- Insertar Préstamos
DECLARE @fecha_devolucion DATETIME = DATEADD(day, 14, GETDATE());

EXEC sp_prestar_libro 1001, 10000, @fecha_devolucion, @mensaje OUTPUT;
EXEC sp_prestar_libro 1002, 10001, @fecha_devolucion, @mensaje OUTPUT;
EXEC sp_prestar_libro 1003, 10002, @fecha_devolucion, @mensaje OUTPUT;

-- Préstamos históricos (ya devueltos)
INSERT INTO tbl_prestamo (id_usuario_fk, id_libro_fk, fecha_prestamo, fecha_devolucion, fecha_devolucion_real, estado)
VALUES 
(1001, 10003, DATEADD(month, -2, GETDATE()), DATEADD(month, -1, GETDATE()), DATEADD(month, -1, GETDATE()), 'Pendiente'),
(1002, 10004, DATEADD(month, -3, GETDATE()), DATEADD(month, -2, GETDATE()), DATEADD(month, -2, GETDATE()), 'Pendiente'),
(1003, 10005, DATEADD(month, -4, GETDATE()), DATEADD(month, -3, GETDATE()), DATEADD(month, -3, GETDATE()), 'Pendiente');

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
use DB_Peru_Lee
-- Consultar reservas activas
EXEC sp_listar_solicitudes;

DECLARE @mensaje VARCHAR(200)
EXEC sp_solicitar 1001, 10000, @mensaje OUTPUT
PRINT @mensaje


-- Consultar reservas actibva Por Usuarios
EXEC sp_consultar_solicitudes_usuario 1001;
exec sp_procesar_solicitud 1

-- Devolver libro
--EXEC sp_devolver_libro 2;
EXEC sp_devolver_libro 2, 'nuevo mensaje';
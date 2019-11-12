

--------------EJ 2--------------------
DROP TRIGGER IF EXISTS cambiopassword ON usuario;
DROP TABLE IF EXISTS historialpassword;
DROP TABLE IF EXISTS usuario CASCADE;
DROP TABLE IF EXISTS rol CASCADE;
DROP TABLE IF EXISTS roles;

CREATE TABLE usuario
(
        Nombre TEXT NOT NULL,
        Password TEXT,
        
        PRIMARY KEY(Nombre)
);

CREATE TABLE rol
(
        Nombre TEXT NOT NULL,
        Nivel INTEGER CHECK(Nivel >= 0),
        
        PRIMARY KEY(Nombre)
 );
 
CREATE TABLE roles
(
        Usuario TEXT NOT NULL,
        Rol TEXT NOT NULL,
        
        PRIMARY KEY(Usuario, Rol),
        FOREIGN KEY(Usuario) REFERENCES usuario ON DELETE CASCADE,
        FOREIGN KEY(Rol) REFERENCES rol ON DELETE CASCADE
);

CREATE TABLE historialpassword
(
        Usuario TEXT NOT NULL,
        Password TEXT,
        Fecha TIMESTAMP NOT NULL,
        
        PRIMARY KEY(Usuario, Fecha)
        
        --FOREIGN KEY(Usuario) REFERENCES usuario(Nombre) ON DELETE CASCADE,
        --En realidad creo que no referencia a ese usuario?
);


CREATE OR REPLACE FUNCTION triggerCambioPassword() RETURNS TRIGGER AS $$
BEGIN
        IF (new.password = old.password)
        THEN RAISE EXCEPTION 'NEW PASSWORD SAME AS OLD PASSWORD' USING ERRCODE = 'PP001';
        END IF;
        IF  (((SELECT max(Nivel)
            FROM rol,roles,usuario
            WHERE rol.nombre = roles.rol
            AND roles.usuario = usuario.nombre) >=1) 
            AND (new.password in(
            SELECT password 
            FROM historialpassword 
            ORDER BY Fecha DESC 
            LIMIT (
            SELECT sum(Nivel)
            FROM rol, usuario, roles
            WHERE rol.nombre = roles.rol
            AND roles.usuario = usuario.nombre))))
        THEN RAISE EXCEPTION 'PASSWORD HAS BEEN USED BEFORE' USING ERRCODE = 'PP002';
        ELSE
        INSERT INTO historialpassword(Usuario, Password, Fecha) VALUES(usuario, password, CURRENT_TIMESTAMP);
        END IF;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER cambiopassword 
BEFORE UPDATE ON usuario
FOR EACH ROW 
EXECUTE PROCEDURE triggerCambioPassword();

INSERT INTO usuario VALUES ('jperez', 'pass1');
INSERT INTO usuario VALUES ('mgomez', 'pass1');
INSERT INTO usuario VALUES ('tbalbin', 'pass1');
INSERT INTO usuario VALUES ('ucampos', 'pass1');

INSERT INTO rol VALUES ('secretaria', 0);
INSERT INTO rol VALUES ('gerente', 1);
INSERT INTO rol VALUES ('revisor', 2);

INSERT INTO roles VALUES ('jperez', 'secretaria');
INSERT INTO roles VALUES ('mgomez', 'secretaria');
INSERT INTO roles VALUES ('tbalbin', 'secretaria');
INSERT INTO roles VALUES ('tbalbin', 'gerente');
INSERT INTO roles VALUES ('ucampos', 'revisor');

INSERT INTO historialpassword VALUES ('mgomez', 'pass2', '01/01/2019 00:00:00');
INSERT INTO historialpassword VALUES ('tbalbin', 'pass15', '01/01/2019 00:00:00');
INSERT INTO historialpassword VALUES ('tbalbin', 'pass44', '01/02/2019 00:00:00');
INSERT INTO historialpassword VALUES ('ucampos', 'pass2', '01/01/2019 00:00:00');
INSERT INTO historialpassword VALUES ('ucampos', 'pass3', '01/02/2019 00:00:00');
INSERT INTO historialpassword VALUES ('ucampos', 'pass4', '01/03/2019 00:00:00');

-------------- PRUEBA ---------------

SELECT * FROM usuario;
SELECT * FROM rol;
SELECT * FROM roles;
SELECT * FROM historialpassword;

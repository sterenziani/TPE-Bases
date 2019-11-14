--------EJ 1---------
DROP TRIGGER IF EXISTS rangofechatrigger ON contrato;
DROP TRIGGER IF EXISTS nuevoresumentrigger ON contrato;
DROP TABLE IF EXISTS contrato;
DROP TABLE IF EXISTS resumencontrato;

CREATE TABLE contrato
(
        FechaDesde int CHECK(FechaDesde > 99999 AND FechaDesde < 1000000 AND FechaDesde%100 <= 12) NOT NULL,
        FechaHasta int CHECK(FechaHasta > 99999 AND FechaHasta < 1000000 AND FechaHasta%100 <= 12) NOT NULL,
        DeptoId int CHECK(DeptoId > 0) NOT NULL,
        PersonaId int CHECK(PersonaId > 0),
        
        PRIMARY KEY(FechaDesde, FechaHasta, DeptoId)
);

CREATE TABLE ResumenContrato
(
        FechaDesde int CHECK(FechaDesde > 99999 AND FechaDesde < 1000000 AND FechaDesde%100 <= 12) NOT NULL,
        FechaHasta int CHECK(FechaHasta > 99999 AND FechaHasta < 1000000 AND FechaHasta%100 <= 12) NOT NULL,
        DeptoId int CHECK(DeptoId > 0) NOT NULL,
        PRIMARY KEY(FechaDesde, FechaHasta, DeptoId)
);

--Al agregar un contrato, revisa que no contradiga las fechas ya establecidas
CREATE OR REPLACE FUNCTION checkFecha() RETURNS TRIGGER AS $$
BEGIN
        IF EXISTS (SELECT * FROM contrato t1 WHERE (t1.deptoId = new.deptoId AND (new.fechaDesde > t1.fechaDesde AND new.fechaHasta < t1.fechaHasta)))
                THEN RAISE EXCEPTION 'CONTRACT WITHIN ALREADY CONTRACTED RANGE' USING ERRCODE = 'PP111'; END IF;
        IF EXISTS (SELECT * FROM contrato t1 WHERE (t1.deptoId = new.deptoId AND (new.fechaDesde < t1.fechaDesde AND new.fechaHasta > t1.fechaHasta)))
                THEN RAISE EXCEPTION 'CONTRACT INCLUDES ALREADY CONTRACTED RANGE' USING ERRCODE = 'PP112'; END IF;
        IF EXISTS (SELECT * FROM contrato t1 WHERE (t1.deptoId = new.deptoId AND (new.fechaDesde > t1.fechaDesde AND new.fechaDesde < t1.fechaHasta)))
                THEN RAISE EXCEPTION 'CONTRACT OVERLAPS ENDING OF ALREADY CONTRACTED RANGE' USING ERRCODE = 'PP113'; END IF;
        IF EXISTS (SELECT * FROM contrato t1 WHERE (t1.deptoId = new.deptoId AND (new.fechaHasta > t1.fechaDesde AND new.fechaHasta < t1.fechaHasta)))
                THEN RAISE exception 'CONTRACT OVERLAPS START OF ALREADY CONTRACTED RANGE' USING ERRCODE = 'PP114'; END IF;
      RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rangoFechaTrigger BEFORE INSERT OR UPDATE ON contrato
        FOR EACH ROW EXECUTE PROCEDURE checkFecha();
        
-- Recibe un deptoId como parametro e itera sobre sus alquileres ordenados. Cuando detecta un intervalo sin alquiler, agrega una nueva tupla a ResumenContrato
CREATE OR REPLACE FUNCTION guardaDepto(PDEPTO contrato.deptoId%TYPE) RETURNS VOID AS $$
DECLARE CDEPTO CURSOR FOR SELECT fechaDesde, fechaHasta FROM contrato WHERE deptoId = PDEPTO ORDER BY fechaDesde;
RCDEPTO RECORD;
DESDEANT int;
HASTAANT int;
BEGIN
        OPEN CDEPTO;
        FETCH CDEPTO INTO RCDEPTO;
        DESDEANT := RCDEPTO.fechaDesde;
        HASTAANT := RCDEPTO.fechaHasta;
        LOOP
                FETCH CDEPTO INTO RCDEPTO;
                EXIT WHEN NOT FOUND;
                IF RCDEPTO.fechaDesde = HASTAANT THEN
                        INSERT INTO ResumenContrato VALUES(DESDEANT, HASTAANT, PDEPTO);
                        DESDEANT := RCDEPTO.fechaDesde;
                        HASTAANT := RCDEPTO.fechaHasta;
                ELSE
                        HASTAANT := RCDEPTO.fechaHasta;
                END IF;
        END LOOP;
        INSERT INTO ResumenContrato VALUES(DESDEANT, HASTAANT, PDEPTO);
        CLOSE CDEPTO;
END;
$$ LANGUAGE plpgsql;

-- Trigger que actualiza el resumen cada vez que se agregue un contrato        
CREATE OR REPLACE FUNCTION triggerearResumenContrato() RETURNS TRIGGER AS $$
DECLARE CCONTRATO CURSOR FOR SELECT DISTINCT deptoId FROM contrato;
RCDEPTO RECORD;
BEGIN
        DELETE FROM ResumenContrato;
        OPEN CCONTRATO;
        LOOP
                FETCH CCONTRATO INTO RCDEPTO;
                EXIT WHEN NOT FOUND;
                PERFORM guardaDepto(RCDEPTO.deptoId);
        END LOOP;
        CLOSE CCONTRATO;
RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER nuevoResumenTrigger AFTER INSERT OR UPDATE OR DELETE ON contrato
        FOR EACH ROW EXECUTE PROCEDURE triggerearResumenContrato();

-- Llama a guardaDepto para cada deptoId existente.
CREATE OR REPLACE FUNCTION cargarResumenContrato() RETURNS VOID AS $$
DECLARE CCONTRATO CURSOR FOR SELECT DISTINCT deptoId FROM contrato;
RCDEPTO RECORD;
BEGIN
        DELETE FROM ResumenContrato;
        OPEN CCONTRATO;
        LOOP
                FETCH CCONTRATO INTO RCDEPTO;
                EXIT WHEN NOT FOUND;
                PERFORM guardaDepto(RCDEPTO.deptoId);
        END LOOP;
        CLOSE CCONTRATO;
END;
$$ LANGUAGE plpgsql;

-- Carga los datos de alquileres.csv desde el directorio actual en pampero
\COPY contrato from 'alquileres2.csv' csv header delimiter ','








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
);


CREATE OR REPLACE FUNCTION triggerCambioPassword() RETURNS TRIGGER AS $$
DECLARE SUMA int;
MESSAGE TEXT;
BEGIN
        IF (new.password = old.password)
        THEN RAISE EXCEPTION 'NEW PASSWORD SAME AS OLD PASSWORD' USING ERRCODE = 'PP001';
        END IF;
        SUMA := (SELECT sum(Nivel)
            FROM rol, roles
            WHERE rol.nombre = roles.rol
            AND roles.usuario = old.nombre);
        MESSAGE := CONCAT('CANNOT USE LAST ', SUMA, ' PASSWORD(S)');
        IF  (((SELECT max(Nivel)
            FROM rol,roles
            WHERE rol.nombre = roles.rol
            AND roles.usuario = old.nombre) >=1) 
            AND (new.password in(
            SELECT password 
            FROM historialpassword 
            ORDER BY Fecha DESC 
            LIMIT SUMA)))
        THEN RAISE EXCEPTION '%', MESSAGE USING ERRCODE = 'PP002';
        ELSE
        INSERT INTO historialpassword(Usuario, Password, Fecha) VALUES(old.nombre, old.password, CURRENT_TIMESTAMP);
        RAISE NOTICE 'PASSWORD CHANGED SUCCESFULLY'; 
        END IF;
        RETURN new;
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


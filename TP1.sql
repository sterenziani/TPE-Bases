--DROP TRIGGER IF EXISTS rangofechatrigger ON contrato;
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

-------------- PRUEBA ---------------

SELECT fechaDesde, fechaHasta, deptoId FROM contrato ORDER BY deptoId, fechaDesde;
SELECT * FROM ResumenContrato ORDER BY deptoId;
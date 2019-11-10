# TPE-Bases

Usen el siguiente comando para pasar sus archivos a pampero. En vez de Salerno usan su user de Pampero:
```
scp /home/...../TP1.sql salerno@pampero.itba.edu.ar:/home/salerno
```

Después conéctense a Pampero con ssh y ejecuten esto para correr el SQL que quieran:
```
psql -h bd1.it.itba.edu.ar -U salerno -f TP1.sql PROOF
```

Pueden usar DBVisualizer para armar el SQL y ver las consultas más fácil, pero la lectura de CSV sólo funciona con el comando desde terminal.

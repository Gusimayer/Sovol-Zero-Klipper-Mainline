# 02 — Backups y recuperación

Antes de cambiar firmware, bootloader, sistema operativo o configuración, conservar copias independientes. No publicar backups completos, logs privados, credenciales, IP local ni UUID innecesarios.

## Backups realizados
Se conservaron configuraciones OEM y Mainline, firmware original disponible, binarios de trabajo, logs y copias de compilación. El 15-11-2026 se creó `/home/sovol/SovZero_Backup_20261115.tar.gz`; se verificó con `gzip -t` y `tar -tzf`. Rutas y hashes privados se mantienen fuera del repositorio.

La tabla frecuencia-altura Eddy y `tap_threshold` se guardan en `SAVE_CONFIG`; no reconstruirlos manualmente. `out/` se sobrescribe en cada compilación: archivar cada binario antes del siguiente build.

## Recuperación: límites conocidos
- TOOLHEAD F103: mientras Katapult CAN-capable sobreviva, puede reprogramarse por CAN; si se pierde Katapult puede requerirse SWD.
- HOST H743: mientras Katapult sobreviva, la aplicación puede reprogramarse por USB serie; si se corrompe Katapult puede requerirse SWD en el encabezado de la placa.
- No interrumpir alimentación, USB ni programación.
- No usar binarios de recuperación de terceros sin verificar procedencia, target y compatibilidad.

## Checklist
1. Confirmar revisión física.
2. Confirmar MCU objetivo y método de conexión.
3. Verificar configuración y offset.
4. Revisar vector de reset y SHA256.
5. Tener backup adecuado y alimentación estable.
6. Conocer el método de recuperación.

Referencia Lexfrei: https://sovol.lexfrei.dev/zero/os/recovery/

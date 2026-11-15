# 05 — Configuración Mainline y Eddy-Only

Esta unidad utiliza Eddy LDC1612 del cabezal y no tiene strain gauge bajo cama. La estrategia Z documentada es Eddy-Only.

## Bloque Mainline confirmado
```ini
[probe_eddy_current eddy]
sensor_type: ldc1612
i2c_mcu: extruder_mcu
i2c_software_scl_pin: extruder_mcu:PB10
i2c_software_sda_pin: extruder_mcu:PB11
x_offset: -19.8
y_offset: -0.75
descend_z: 0.5
max_sensor_hz: 6000000
```
No trasladar `z_offset: 3.5` ni `vir_contact_speed` del bloque OEM. El I²C software PB10/PB11 se usa en el F103.

## Calibraciones realizadas
**PROBADO:** `LDC_CALIBRATE_DRIVE_CURRENT CHIP=eddy` devolvió `reg_drive_current: 15`; calibración frecuencia-altura completada y guardada con `SAVE_CONFIG`; Eddy Tap guess/refine/verify completado y umbral `10839.290` guardado. Cinco medidas TAP: media `-0.078308`, rango `0.006976 mm`. `PROBE_ACCURACY` rango `0.004123 mm`. Homing XY y Z probados con el usuario presente.

No repetir calibraciones sin causa técnica ni editar manualmente tabla de SAVE_CONFIG.

## Rex frente a Asnajder
La ruta elegida es **Rex Eddy-Only**. No mezclar macros sin analizar efectos.

El registro de continuidad indica que Asnajder dispone de `SET_Z_FROM_PROBE`, `SET_SCAN_FROM_TAP` y auxiliares. `SET_SCAN_FROM_TAP` ejecuta TAP, recalibra posición cinemática, desplaza el cabezal, hace scan y aplica `SET_GCODE_OFFSET`. La llamada aparecía comentada en el fragmento de inicio revisado. No afirmar que Asnajder exige ejecutarla en cada impresión.

Rex Eddy-Only no prescribe añadir ese ajuste de Asnajder. No ejecutar `SET_SCAN_FROM_TAP` como paso genérico de Rex.

## Valores Z que requieren contexto
Prueba independiente:
- TAP media: `-0.078308`.
- Scan independiente: `-0.022311`.
- Offset G-code base observado: `-0.102362`.

Son referencias distintas; no compararlas directamente ni restablecer offsets sin reconstruir su origen. El siguiente paso pendiente documentado era investigar `-0.102362` antes de modificar offsets o generar otra malla.

Referencias:
- Rex: https://github.com/0dysseusRex/Rex-Sovol-Zero-Mainline/wiki/Eddy-Only-Configuration
- Lexfrei calibración: https://sovol.lexfrei.dev/zero/application/calibration/
- Klipper Bed Mesh: https://www.klipper3d.org/Bed_Mesh.html

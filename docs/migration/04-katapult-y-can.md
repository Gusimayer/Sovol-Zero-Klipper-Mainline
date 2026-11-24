# 04 — Katapult y comunicación CAN

## Conceptos
- **Klipper MCU:** aplicación que controla el hardware.
- **Katapult:** bootloader para programar la aplicación.
- **Deployer:** imagen/herramienta de transición usada en ciertos bootstrap de la placa principal; no es Klipper ni el Katapult normal.
- **USB-CAN bridge:** MCU principal expone el adaptador CAN al host Linux por USB.

## Estado comprobado
`can0`, driver `gs_usb`, bitrate 1 Mbps; HOST H743 target y TOOLHEAD F103. Ambos tuvieron Katapult operativo. El puerto de Katapult HOST apareció como `/dev/ttyACM0`, pero puede variar.

En esta instalación se usó `~/klipper/lib/katapult/flashtool.py`; otras instalaciones pueden tener `~/katapult/scripts/flashtool.py`. Verificar ruta y `-h`.

## Reenumeración HOST
**PROBADO en actualización Mainline→Mainline:** HOST `1d50:606f`; solicitud `-r` por CAN; reenumeración `1d50:6177` y puerto serie; programación por serie; retorno a `1d50:606f`; `can0` vuelve a estar disponible.

Al reiniciar el puente, `can0` cae temporalmente. Esperar y comprobar la reenumeración antes de continuar.

Referencia: https://sovol.lexfrei.dev/zero/firmware/

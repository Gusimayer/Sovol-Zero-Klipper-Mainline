# Análisis del actualizador automático de Asnajder

Fuente: https://github.com/asnajder/zero-config  
Archivo revisado: `update_klipper_mcus_svzero.sh` (copia compartida, 268 líneas; revisión del 15-11-2026). Revisar de nuevo si upstream cambia.

## Flujo general
El script valida requisitos y UUID, comprueba `can0`, detiene Klipper, muestra un menú y permite actualizar HOST, TOOLHEAD y CHAMBER opcional. Al salir, un `trap` intenta arrancar Klipper.

## HOST
`flash_host()` compila con `host.mcu`. Si existe `can0`, consulta nodos y ejecuta:
```bash
python3 "$KATAPULT_FLASHTOOL" -i can0 -u "$HOSTUUID" -r
```
Después espera cinco segundos, comprueba `HOSTSERIAL` (por defecto `/dev/ttyACM0`), pide confirmación `YES` y programa por serie:
```bash
python3 "$KATAPULT_FLASHTOOL" -f "$KLIPPER_DIR/$out_bin" -d "$HOSTSERIAL"
```
El método coincide con el probado manualmente. Mejoras: detectar dinámicamente el puerto; comprobar USB Katapult `1d50:6177`; consultar estado con `-s`; sustituir la espera fija por un timeout de detección.

## TOOLHEAD / CHAMBER
`flash_canbus()` compila usando la configuración indicada, consulta CAN, solicita confirmación y programa:
```bash
python3 "$KATAPULT_FLASHTOOL" -i can0 -f "$KLIPPER_DIR/$out_bin" -u "$uuid"
```
Coincide con el método probado para F103. No habilitar CHAMBER si ese MCU no está instalado, identificado y operativo.

## Compilación y precauciones
`build_firmware()` ejecuta `make clean`, abre `menuconfig` con un archivo de configuración dedicado, compila y copia `out/klipper.bin` a un nombre específico. Guardar y calcular hash de cada binario antes de compilar el siguiente MCU. El script no valida semánticamente todas las opciones de `menuconfig`; el operador debe comprobar MCU, reloj, cristal, offset e interfaces.

El `trap cleanup EXIT` intenta arrancar Klipper al salir, incluso tras cancelar o fallar. Una versión adaptada debería recordar el estado inicial y restaurarlo, en vez de arrancarlo siempre.

## Mejoras propuestas
1. Detección dinámica del puerto serie.
2. Verificación del USB Katapult y del MCU antes de flashear.
3. Comprobación de `can0` UP y 1 Mbps.
4. SHA256 y registro de versión/configuración/binario.
5. Comprobación de ambos MCUs en Mainsail al finalizar.
6. Mantener CHAMBER desactivado hasta disponer de un MCU detectado.

Conservar el script upstream intacto y desarrollar una copia `custom`. Revisar la licencia upstream antes de redistribuir o modificar el script original.

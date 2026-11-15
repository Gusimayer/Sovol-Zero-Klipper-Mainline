# 07 — Análisis del actualizador automático de Asnajder

**Estado: análisis documental; no probado por nosotros de principio a fin.**

Fuente: https://github.com/asnajder/zero-config  
Script revisado: `update_klipper_mcus_svzero.sh`.

Este capítulo explica el flujo del script compartido/revisado. No certifica que funcione sin cambios en nuestra instalación ni es una guía para ejecutarlo.

## HOST
La función `flash_host()` compila usando configuración HOST, consulta CAN, solicita Katapult con `flashtool.py -i can0 -u "$HOSTUUID" -r`, espera un intervalo fijo, comprueba el puerto serie configurado (por defecto `/dev/ttyACM0`), pide confirmación y programa por serie. El flujo es coherente con nuestra actualización manual, pero el script completo no se ha ejecutado.

## TOOLHEAD / CHAMBER
La función `flash_canbus()` compila, consulta CAN, pide confirmación y programa por CAN usando el UUID. El script contempla CHAMBER opcional. No seleccionar CHAMBER en nuestra máquina mientras ese MCU no esté detectado y validado.

## Compilación y servicio
`build_firmware()` ejecuta `make clean`, abre `menuconfig` con una configuración dedicada, compila y copia el binario a un nombre específico. Guardar cada salida antes del siguiente build. El operador debe revisar MCU, reloj, cristal, offset y buses.

El script detiene Klipper y usa un `trap` que intenta arrancarlo al salir. Una futura versión propia debería recordar el estado inicial y restaurarlo.

## Mejoras a evaluar, no probadas
- Detectar dinámicamente el puerto Katapult.
- Espera con timeout y comprobación USB, en vez de espera fija.
- Consultar estado Katapult antes de escribir.
- Validar target y offset.
- Comprobar `can0` UP y bitrate.
- Registrar versión, configuración, SHA256 y resultado.
- Validar ambos MCUs en Mainsail.

## Copyright y redistribución
Este repositorio enlaza y analiza el proyecto original, pero no incluye una copia del script. Un repositorio público no concede automáticamente permiso para reutilizar código. Antes de copiar, modificar o redistribuir, comprobar la licencia upstream o pedir permiso al autor. La atribución no sustituye una licencia.

No aplicar automáticamente MIT a código de terceros. Los documentos propios pueden licenciarse por separado cuando se decida la licencia global. Revisar el estado de licencia del upstream en el momento de reutilizar código.

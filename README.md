# Sovol Zero — Klipper Mainline

Documentación de una Sovol Zero migrada desde el entorno OEM de Sovol a Klipper Mainline. Se distingue entre **probado en esta máquina**, **fuente externa** y **pendiente/no probado**.

## Estado de referencia

- Host: Allwinner H616 con Armbian Trixie.
- MCU principal físico: STM32H750; firmware Mainline compilado como `stm32h743xx` a 400 MHz.
- MCU cabezal: STM32F103.
- MCU principal también actúa como puente USB-CAN (`gs_usb`).
- CAN `can0`, 1 Mbps.
- HOST y TOOLHEAD actualizados y verificados en `v0.14.0-0-gc9559fa0` el 24-11-2026.
- Eddy LDC1612 en el cabezal. Esta unidad no tiene célula de carga bajo la cama.

## Documentación

1. Hardware y arquitectura.
2. Backups y recuperación.
3. Migración OEM → Mainline.
4. Katapult y CAN.
5. Configuración Eddy-Only.
6. Actualización Klipper Mainline → Mainline (procedimiento automático recomendado).
7. Actualización manual de MCU Mainline → Mainline (referencia técnica).
8. Análisis del actualizador Asnajder.
9. Registro de decisiones y estado.
10. Programación SWD del F103.

## Actualización de Klipper

Para instalaciones que ya ejecutan Klipper Mainline y tienen Katapult operativo, se recomienda utilizar el actualizador automático de MCU incluido en este repositorio.

La actualización se realiza en dos fases:

1. Actualizar los componentes de software desde Mainsail Update Manager.
2. Ejecutar el script `update_mcus.sh` para compilar y actualizar los dos MCU.

El procedimiento completo, los requisitos y las comprobaciones están documentados en el capítulo de actualización Mainline → Mainline.

La actualización automática fue probada satisfactoriamente en esta Sovol Zero el 24-11-2026.

## Créditos y referencias
- Asnajder: https://github.com/asnajder/zero-config
- Lexfrei: https://sovol.lexfrei.dev/zero/
- Rex: https://github.com/0dysseusRex/Rex-Sovol-Zero-Mainline
- Klipper: https://github.com/Klipper3d/klipper
- Katapult: https://github.com/Arksine/katapult


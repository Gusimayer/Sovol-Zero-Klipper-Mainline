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

### Hardware, instalación y configuración

1. [Hardware y arquitectura](docs/01-hardware-arquitectura.md)
2. [Backups y recuperación](docs/02-backup-recuperacion.md)
3. [Migración OEM → Mainline](docs/03-migracion-oem-a-mainline.md)
4. [Katapult y CAN](docs/04-katapult-can.md)
5. [Configuración Eddy-Only](docs/05-configuracion-eddy-only.md)

### Actualización y mantenimiento

6. [Actualización automática MCU Mainline → Mainline](docs/10-actualizacion-mcus-automatico.md) — Procedimiento recomendado.
7. [Actualización manual MCU Mainline → Mainline](docs/06-actualizacion-mcus-manual.md) — Referencia técnica.
8. [Análisis del actualizador Asnajder](docs/07-analisis-actualizador-asnajder.md)
9. [Registro y estado del proyecto](docs/08-registro-y-estado.md)
10. [Programación SWD del F103](docs/09-programacion-swd-f103.md)

### Guía general

[Manual de actualización de Klipper Mainline en Sovol Zero](Manual%20de%20actualizaci%C3%B3n%20de%20Klipper%20Mainline%20en%20Sovol%20Zero.md)

## Actualización de Klipper

Para instalaciones que ya ejecutan Klipper Mainline y tienen Katapult operativo, se recomienda utilizar el actualizador automático de MCU incluido en este repositorio.

**Script de actualización:**

[`scripts/update_mcus.sh`](scripts/update_mcus.sh)

La actualización se realiza en dos fases:

1. Actualizar los componentes de software desde Mainsail Update Manager.
2. Ejecutar el script `update_mcus.sh` para compilar y actualizar los dos MCU.

El procedimiento completo, los requisitos y las comprobaciones están documentados en el capítulo de actualización automática Mainline → Mainline.

La actualización automática fue probada satisfactoriamente en esta Sovol Zero el 24-11-2026, actualizando ambos MCU a `v0.14.0-0-gc9559fa0`.

## Créditos y referencias
- Asnajder: https://github.com/asnajder/zero-config
- Lexfrei: https://sovol.lexfrei.dev/zero/
- Rex: https://github.com/0dysseusRex/Rex-Sovol-Zero-Mainline
- Klipper: https://github.com/Klipper3d/klipper
- Katapult: https://github.com/Arksine/katapult


# Sovol Zero — Klipper Mainline

Documentación de una Sovol Zero migrada desde el entorno OEM de Sovol a Klipper Mainline. Se distingue entre **probado en esta máquina**, **fuente externa** y **pendiente/no probado**.

## Estado de referencia
- Host: Allwinner H616 con Armbian Trixie.
- MCU principal físico: STM32H750; firmware Mainline compilado como `stm32h743xx` a 400 MHz.
- MCU cabezal: STM32F103.
- MCU principal también actúa como puente USB-CAN (`gs_usb`).
- CAN `can0`, 1 Mbps.
- HOST y TOOLHEAD actualizados a `v0.13.0-827-g29d4ec2d` el 15-11-2026.
- Eddy LDC1612 en el cabezal. Esta unidad no tiene célula de carga bajo la cama.

## Documentación
1. [Hardware y arquitectura](docs/01-hardware-arquitectura.md)
2. [Backups y recuperación](docs/02-backup-recuperacion.md)
3. [Migración OEM → Mainline](docs/03-migracion-oem-a-mainline.md)
4. [Katapult y CAN](docs/04-katapult-can.md)
5. [Configuración Eddy-Only](docs/05-configuracion-eddy-only.md)
6. [Actualización manual Mainline → Mainline](docs/06-actualizacion-mcus-manual.md)
7. [Análisis del actualizador Asnajder](docs/07-analisis-actualizador-asnajder.md)
8. [Registro de decisiones y estado](docs/08-registro-y-estado.md)\n9. [Programación SWD del F103](docs/09-programacion-swd-f103.md)

## Evidencia
- **PROBADO:** realizado y observado en esta impresora.
- **FUENTE EXTERNA:** extraído de guías/repositorios; no implica ejecución.
- **PENDIENTE:** requiere validación antes de recomendarlo como procedimiento.

Flashear puede dejar un MCU inaccesible. Identifica la revisión, conserva backups, comprueba target, offset, vector de reset y SHA256, y mantén alimentación estable. No reutilices UUID de esta máquina.

## Créditos y referencias
- Asnajder: https://github.com/asnajder/zero-config
- Lexfrei: https://sovol.lexfrei.dev/zero/
- Rex: https://github.com/0dysseusRex/Rex-Sovol-Zero-Mainline
- Klipper: https://github.com/Klipper3d/klipper
- Katapult: https://github.com/Arksine/katapult

No se redistribuye aquí el script de Asnajder. No implica afiliación con Sovol ni con los autores citados.

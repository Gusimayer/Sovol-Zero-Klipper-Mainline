# Sovol Zero — Klipper Mainline

Documentación de una instalación real de Klipper Mainline en Sovol Zero.

## Documentos
- [Actualización manual de los MCUs](docs/02-actualizacion-mcus-manual.md)
- [Análisis del actualizador de Asnajder](docs/03-actualizador-asnajder.md)
- [Estado de referencia](docs/04-estado-referencia.md)

## Arquitectura comprobada
- Host Linux: Allwinner H616 con Armbian Trixie.
- MCU principal: STM32H743, que también actúa como puente USB-CAN.
- MCU del cabezal: STM32F103xe, conectado por CAN.

**Alcance:** actualización Mainline → Mainline, con Katapult ya instalado. No es una guía de migración OEM ni de instalación inicial de Katapult.

Antes de flashear, identifica la revisión de hardware, conserva backups, verifica MCU/configuración/hash y no reutilices UUID de otra impresora. Flashear incorrectamente puede dejar la máquina inoperativa.

## Referencias
- https://github.com/asnajder/zero-config
- https://sovol.lexfrei.dev/zero/
- https://github.com/Klipper3d/klipper
- https://github.com/Arksine/katapult

No implica afiliación con Sovol ni con los autores de las referencias.

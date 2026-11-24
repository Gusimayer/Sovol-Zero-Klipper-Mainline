# Sovol Zero — Klipper Mainline

Documentación y herramientas para migrar una Sovol Zero desde el entorno OEM de Sovol a Klipper Mainline y mantener posteriormente sus microcontroladores.

## Estado de la unidad documentada

- Host: Allwinner H616 con Armbian Trixie.
- MCU principal físico: STM32H750; firmware Mainline compilado como `stm32h743xx` a 400 MHz.
- MCU del cabezal: STM32F103.
- MCU principal también actúa como puente USB-CAN (`gs_usb`).
- CAN `can0`, 1 Mbps.
- Eddy LDC1612 en el cabezal; esta unidad no tiene célula de carga bajo la cama.
- HOST y TOOLHEAD verificados en `v0.14.0-0-gc9559fa0` el 24-11-2026.

## Empieza aquí

1. Lee el [manual general](docs/00-manual-general-mainline.md).
2. Usa el [índice de documentación](docs/README.md) para localizar cada procedimiento.
3. Identifica el hardware y prepara respaldos antes de migrar o recuperar.

## Estructura

- `docs/hardware/`: arquitectura, pantalla táctil BTT HDMI5 y audio HDMI.
- `docs/migration/`: migración OEM → Mainline y Katapult/CAN.
- `docs/configuration/`: configuración y Eddy-Only.
- `docs/maintenance/`: actualizaciones manuales y automáticas.
- `docs/recovery/`: backups, recuperación y SWD.
- `docs/references/`: análisis externo y registro.
- `scripts/`: herramientas ejecutables.

## Actualización Mainline → Mainline

El procedimiento recomendado es actualizar primero el software desde Mainsail Update Manager y después ejecutar [`scripts/update_mcus.sh`](scripts/update_mcus.sh). El ciclo automático completo fue probado satisfactoriamente en esta unidad el 24-11-2026, actualizando ambos MCU a `v0.14.0-0-gc9559fa0`. Consulta la [guía de actualización automática](docs/maintenance/10-actualizacion-automatica.md).

**Importante:** el script requiere dos perfiles de compilación locales que no se distribuyen en el repositorio. Si no dispones de los perfiles exactos y sus hashes verificados, no lo ejecutes ni desactives las comprobaciones.

## Documento original

Se conserva el [manual ODT original](Manual%20de%20actualizaci%C3%B3n%20de%20Klipper%20Mainline%20en%20Sovol%20Zero.odt) como referencia histórica.

## Referencias

- [Asnajder — zero-config](https://github.com/asnajder/zero-config)
- [Lexfrei — Sovol Zero Mainline](https://sovol.lexfrei.dev/zero/)
- [Rex — Sovol Zero Mainline](https://github.com/0dysseusRex/Rex-Sovol-Zero-Mainline)
- [Klipper](https://github.com/Klipper3d/klipper)
- [Katapult](https://github.com/Arksine/katapult)

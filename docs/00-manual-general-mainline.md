# Manual general de Klipper Mainline en Sovol Zero

## Propósito y alcance

Este manual reúne el recorrido general del proyecto: identificar la arquitectura, proteger la instalación original, migrar de Klipper OEM a Klipper Mainline, validar Katapult/CAN, configurar Eddy-Only y mantener posteriormente los microcontroladores.

No sustituye los procedimientos técnicos detallados de cada capítulo. Antes de ejecutar comandos de flasheo, consulta siempre el documento específico enlazado en cada fase.

La documentación describe una unidad concreta. No debe copiarse directamente a otra Sovol Zero sin verificar revisión de placa, MCU, bootloader, UUID, offsets, cableado y configuración.

## Estado de referencia de la máquina documentada

- Host Linux: Allwinner H616, Armbian Trixie, ARM64.
- MCU principal físico: STM32H750; firmware Klipper Mainline compilado con target `stm32h743xx` a 400 MHz.
- El MCU principal también proporciona el puente USB-CAN `gs_usb`.
- MCU del cabezal: STM32F103.
- Bus CAN: interfaz `can0`, 1 Mbps.
- Sensor de proximidad: Eddy LDC1612 en el cabezal.
- La unidad documentada no dispone de célula de carga bajo la cama; la configuración Z sigue la ruta Eddy-Only.
- El 24-11-2026 HOST y TOOLHEAD quedaron actualizados y verificados en Klipper `v0.14.0-0-gc9559fa0`.

## Fase 1. Identificación y respaldos

Antes de modificar nada:

1. Identifica la revisión física de la placa y los microcontroladores.
2. Registra la topología USB/CAN y los UUID actuales.
3. Conserva una copia de la configuración OEM y de la configuración Mainline de trabajo.
4. Guarda los volcados de firmware originales disponibles, binarios, perfiles de compilación y registros relevantes.
5. Comprueba la integridad de los respaldos y conserva una copia externa.

Los UUID OEM no deben reutilizarse en Mainline. Los UUID reales de la unidad documentada y otros datos de diagnóstico aparecen en los capítulos técnicos; no son valores universales.

**Documento:** [Backups y recuperación](recovery/02-backups-y-recuperacion.md).

## Fase 2. Migración OEM a Klipper Mainline

La migración inicial es distinta de una actualización normal. Incluye preparar el sistema Linux, identificar los MCU, instalar Katapult cuando corresponda, compilar y programar las aplicaciones Klipper, recuperar CAN y adaptar la configuración de la impresora.

No ejecutes una guía de bootstrap o SWD sobre una máquina que ya tiene Katapult Mainline operativo, salvo que estés realizando una recuperación documentada y hayas confirmado el estado del MCU.

**Documento principal:** [Migración OEM → Mainline](migration/03-migracion-oem-a-mainline.md).

## Fase 3. Katapult y comunicación CAN

En la arquitectura documentada, el MCU principal es simultáneamente el controlador principal y el puente USB-CAN. Cuando se solicita Katapult al MCU principal, el dispositivo USB cambia temporalmente de identidad y la interfaz CAN puede desaparecer. Tras volver a programar y arrancar Klipper, debe recuperarse el dispositivo USB-CAN y reaparecer `can0`.

Comprueba el estado de CAN y el modo de arranque antes de cualquier programación. No presupongas que un puerto serie, UUID o VID:PID será idéntico en otra revisión.

**Documento:** [Katapult y CAN](migration/04-katapult-y-can.md).

## Fase 4. Configuración Eddy-Only

La máquina documentada no tiene célula de carga bajo la cama. La configuración de Z se basa en Eddy LDC1612 y en el procedimiento Eddy-Only elegido para esta unidad.

No mezcles macros ni procedimientos que presupongan una strain gauge. Conserva los datos de calibración guardados por Klipper y sigue el procedimiento específico del proyecto.

**Documento:** [Configuración Eddy-Only](configuration/05-eddy-only.md).

## Fase 5. Actualizaciones posteriores Mainline → Mainline

Una vez que Klipper Mainline y Katapult funcionan correctamente, las actualizaciones rutinarias siguen otro procedimiento:

1. Actualizar Klipper y los componentes del host desde Mainsail Update Manager.
2. Actualizar el firmware del MCU o de los MCU con el script mantenido en este repositorio.
3. Verificar la recuperación de USB-CAN/CAN, el arranque de Klipper y el estado `READY` en Mainsail.

**El procedimiento automático completo está probado y funcionó correctamente en esta unidad el 24-11-2026**: actualización de software desde Mainsail y programación de ambos MCU con la opción `3` del script. Se verificó que HOST y TOOLHEAD cargaron `v0.14.0-0-gc9559fa0`, y se recuperaron USB-CAN, `can0` y el servicio Klipper. Las opciones individuales HOST y TOOLHEAD existen, pero no forman parte de esa prueba completa.

**Importante:** el script necesita dos perfiles de compilación locales en `~/klipper` (`klipper-f103-update.config` y `klipper-h743-update.config`) con hashes exactos. Esos perfiles no están incluidos en el repositorio. Si no están disponibles en una copia fiable, no ejecutes el script ni desactives las comprobaciones de integridad.

- [Actualización automática MCU Mainline → Mainline](maintenance/10-actualizacion-automatica.md)
- [Actualización manual MCU Mainline → Mainline](maintenance/06-actualizacion-manual.md)
- [Script de actualización](../scripts/update_mcus.sh)

## Fase 6. Procedimientos de recuperación y diagnóstico

Si un MCU deja de responder, evita repetir el flasheo a ciegas. Determina primero si el MCU está ejecutando Klipper, Katapult por CAN o Katapult USB. Comprueba la disponibilidad del binario correcto, su dirección de aplicación y su SHA256 antes de programar.

El procedimiento SWD del F103 contiene la evidencia y los límites de la sesión documentada. No debe confundirse un backup SWD acreditado con una secuencia de escritura cuya salida de consola no se haya conservado.

- [Backups y recuperación](02-backup-recuperacion.md)
- [Programación SWD del F103](recovery/09-programacion-swd-f103.md)

## Criterios para considerar la máquina operativa

Después de una migración, actualización o recuperación:

- Klipper arranca sin errores y Mainsail muestra `READY`.
- Los dos MCU aparecen conectados.
- La versión de cada MCU es la esperada; después de una actualización completa, HOST y TOOLHEAD deben coincidir.
- `can0` está operativo a 1 Mbps.
- Eddy y las funciones de movimiento se validan con las comprobaciones apropiadas antes de imprimir.

## Cómo interpretar esta documentación

- **Probado:** hay evidencia de ejecución o estado final en la unidad documentada.
- **Referencia externa:** procedimiento o información procedente de una guía externa; no implica que se haya ejecutado íntegramente en esta máquina.
- **Pendiente/no probado:** no debe presentarse como una operación validada.
- Los UUID, hashes, offsets y perfiles específicos de esta unidad no son universales.

## Índice de documentación técnica

- [Hardware y arquitectura](hardware/README.md)
- [Migración OEM → Mainline y Katapult/CAN](migration/README.md)
- [Configuración Eddy-Only](configuration/README.md)
- [Mantenimiento y actualizaciones](maintenance/README.md)
- [Backups, recuperación y programación SWD](recovery/README.md)
- [Referencias y registro del proyecto](references/README.md)

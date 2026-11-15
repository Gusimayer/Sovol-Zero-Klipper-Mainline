# 03 — Migración OEM → Klipper Mainline

**Este capítulo trata la migración inicial. No es la actualización posterior Mainline→Mainline.** Los procedimientos varían según el bootloader presente en cada MCU y la revisión de placa.

## Punto de partida
La máquina ejecutaba Klipper OEM de Sovol sobre H616, MCU principal STM32H750 (puente USB-CAN), MCU de cabezal STM32F103 y un módulo de cámara no detectado. Eddy LDC1612 está en el cabezal. Los UUID OEM no deben reutilizarse en Mainline.

## Backups
**PROBADO:** se conservaron configuraciones OEM, archivos auxiliares, logs y firmwares originales disponibles, además de copias de trabajo separadas. Lexfrei recomienda también dump SWD del F103 e imagen eMMC completa; no afirmamos que todos esos elementos se completaran en esta unidad sin evidencia del registro.

## HOST: Katapult
**PROBADO:** el MCU principal se programó con ST-Link V2 usando `Katapult_Zero_Host_H743_128kb.bin` de Asnajder. CubeProgrammer verificó escritura en `0x08000000`; apareció como Katapult USB `1d50:6177`.

El MCU físico se identificó como H750, pero Mainline se compiló con target `stm32h743xx`, 400 MHz y aplicación en `0x8020000`. No repetir este paso en una máquina que ya tenga Katapult Mainline operativo.

## TOOLHEAD F103
La sesión SWD está documentada con la conexión del ST-Link V2, identificación del STM32F103, lectura completa de la flash original y verificación del backup, binarios preparados y parámetros de compilación. Véase [Programación SWD del F103](09-programacion-swd-f103.md).

El F103 terminó respondiendo por CAN con un UUID Mainline real, distinto del UUID OEM. El registro recuperado acredita el volcado SWD y el estado final Mainline; no conserva la salida final completa de OpenOCD que demuestre cada operación de borrado/escritura/verificación. Por rigor, esa salida no se reconstruye ni se presenta como transcripción ejecutada.

## Klipper y configuración
Se construyeron aplicaciones con offset F103 `0x08002000` y HOST `0x08020000`. HOST target `stm32h743xx`, 400 MHz, cristal 25 MHz, USB-CAN PA11/PA12 y CAN PB8/PB9. F103 `stm32f103xe`, 72 MHz, cristal 8 MHz y CAN PB8/PB9.

La configuración OEM se tradujo progresivamente en una copia de trabajo: UUID nuevos, Eddy por I²C software PB10/PB11 del F103, retirada de parámetros/macros Sovol no disponibles en Mainline y revisión de homing, malla, ventiladores, sensores y macros. No copiar una configuración completa sin comprobar pines y revisión.

## Estado alcanzado
HOST y TOOLHEAD comunicaban con Klipper Mainline por CAN. Eddy LDC1612 quedó operativo y se realizaron calibraciones. Para Z se eligió Rex Eddy-Only porque esta unidad no tiene célula de carga bajo cama.

## Referencias
- Lexfrei migración: https://sovol.lexfrei.dev/zero/firmware/mcu-migration/
- Lexfrei build: https://sovol.lexfrei.dev/zero/firmware/build/
- Lexfrei flashing: https://sovol.lexfrei.dev/zero/firmware/flashing/
- Asnajder: https://github.com/asnajder/zero-config
- Runbook Lexfrei: https://sovol.lexfrei.dev/zero/runbooks/over-stock/

La ruta Deployer de Lexfrei pertenece al bootstrap OEM→Mainline. No se usa para actualizar MCUs que ya tienen Katapult Mainline.

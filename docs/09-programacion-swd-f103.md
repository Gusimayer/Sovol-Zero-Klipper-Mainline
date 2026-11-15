# 09 — Programación SWD del STM32F103 del cabezal

## Alcance

Este capítulo documenta la preparación, conexión, identificación y copia de seguridad SWD realizadas durante la migración inicial OEM → Klipper Mainline de esta Sovol Zero.

**No confundir con las actualizaciones posteriores Mainline → Mainline.** Una vez instalado Katapult Mainline CAN en el F103, las actualizaciones normales del firmware del cabezal se realizan por CAN; no es necesario volver a abrir el cabezal ni usar ST-Link.

## Hardware y conexión

MCU del cabezal: STM32F103 de densidad media, identificado por OpenOCD como dispositivo `0x20036410`, con 128 KiB de flash física.

Conexión del ST-Link V2 al conector del cabezal:

| ST-Link V2 | Serigrafía del conector | Señal |
|---|---|---|
| 3.3 V | `5V3` | Alimentación 3,3 V |
| SWDIO | `IO` | SWDIO / PA13 |
| SWCLK | `CK` | SWCLK / PA14 |
| GND | `G` | Masa |

**No conectar la salida de 5 V del ST-Link.** En esta sesión se utilizó la salida de 3,3 V para alimentar el MCU.

Antes de conectar el programador, aislar el cabezal de la alimentación de 24 V y desconectar CAN, según el procedimiento seguido en la sesión. El host Armbian puede permanecer encendido.

## Herramientas detectadas

- OpenOCD `0.12.0`.
- Adaptador ST-Link V2, USB VID:PID `0483:3748`.
- Interfaz SWD.
- Archivo de configuración de target OpenOCD: `target/stm32f1x.cfg`.

OpenOCD detectó el adaptador y el chip. En una de las lecturas se observó:

- Tensión de destino: aproximadamente 3,20 V.
- DPIDR: `0x1BA01477`.
- Núcleo Cortex-M3.
- Dispositivo: `0x20036410`.
- Flash: 128 KiB.
- Base de flash: `0x08000000`.

## Copia de seguridad SWD — realizada y verificada

Se creó el directorio:

```bash
mkdir -p ~/firmware_OEM/backup
```

El comando que realizó la lectura completa de los 128 KiB fue:

```bash
sudo openocd \
  -c "adapter driver st-link" \
  -c "st-link vid_pid 0x0483 0x3748" \
  -c "transport select dapdirect_swd" \
  -c "adapter speed 100" \
  -f target/stm32f1x.cfg \
  -c "init" \
  -c "reset halt" \
  -c "dump_image /home/sovol/firmware_OEM/backup/toolhead-original-128k.bin 0x08000000 0x20000" \
  -c "shutdown"
```

Resultado observado: `dumped 131072 bytes`.

Verificación del archivo:

```bash
ls -lh ~/firmware_OEM/backup/toolhead-original-128k.bin
stat -c 'Tamaño exacto: %s bytes' ~/firmware_OEM/backup/toolhead-original-128k.bin
sha256sum ~/firmware_OEM/backup/toolhead-original-128k.bin
```

Datos registrados:

- Archivo: `toolhead-original-128k.bin`
- Tamaño: `131072` bytes.
- SHA256: `26e14185ab2a0fdc0018551c8cebc69ea0b33fca7b49040a03c1a92d001a6666`.

Conservar este archivo sin modificar. Es el volcado de la flash original del F103 antes de la migración.

## Binarios Mainline preparados para el F103

La carpeta de trabajo registrada fue:

`/home/sovol/firmware_OEM/binaries/`

| Imagen | Nombre | SHA256 |
|---|---|---|
| Katapult | `katapult-f103.bin` | `b1b55b12dd50ff3ac0f63064bd69b90acbd4dc5c3b40fbf361c3151e786c375e` |
| Klipper | `klipper-f103.bin` | `964a91dd753f972ef1664b2b674297c356ed902b5e431d6581a9fc18a8c4052e` |

Configuración de referencia de Klipper F103 conservada en:

`~/firmware_OEM/configs/klipper-f103-original.config`

SHA256 del archivo de configuración:

`a66226e7ecd9a6277ca81d4bf822b84f3c8308c3105d6954327f95b1f565e650`

Parámetros relevantes documentados para el F103:

- MCU: `stm32f103xe`.
- Reloj: 72 MHz.
- Cristal: 8 MHz.
- CAN: PB8/PB9.
- Frecuencia CAN: 1 Mbps.
- Offset de aplicación Klipper: `0x08002000`.
- Katapult ocupa el comienzo de la flash, en `0x08000000`.

Los hashes identifican los binarios concretos de aquella sesión. No reutilizarlos para otros builds: volver a calcular SHA256 después de compilar.

## Sobre la secuencia de escritura

La guía Lexfrei describe el bootstrap del cabezal mediante SWD: escribir Katapult CAN en `0x08000000` y la aplicación Klipper en `0x08002000`. La guía de referencia se encuentra en:

- https://sovol.lexfrei.dev/zero/firmware/mcu-migration/
- https://sovol.lexfrei.dev/zero/firmware/flashing/
- https://sovol.lexfrei.dev/zero/firmware/build/

**Nota de evidencia:** el registro de consola recuperado de la sesión del 6 de noviembre acredita la identificación del MCU, la lectura SWD y la verificación del backup. También conserva los binarios y sus hashes. No conserva en el fragmento recuperado la salida final completa de OpenOCD que demuestre el borrado, escritura y verificación de ambas imágenes. Por tanto, este documento no presenta una secuencia de escritura reconstruida como si fuera la transcripción exacta ejecutada. La instalación posterior de Katapult Mainline y la comunicación CAN del F103 sí están confirmadas por el estado de la impresora y por su UUID Mainline.

## Diagnóstico de OpenOCD durante la sesión

Se probaron transportes que no funcionaron con el driver ST-Link usado:

- `transport select swd` → `Debug adapter doesn't support 'swd' transport`.
- `transport select hla_swd` → `Debug adapter doesn't support 'hla_swd' transport`.

El transporte que permitió la lectura SWD fue:

`transport select dapdirect_swd`

En un momento OpenOCD devolvió `Error: open failed`; después de resolver el acceso USB al dispositivo, se pudo ejecutar el volcado con `sudo openocd` y `dapdirect_swd`.

No tomar los intentos fallidos como comandos válidos de programación.

## Después del bootstrap

Una vez instalado Katapult Mainline CAN, el F103 aparece en el bus CAN con un UUID nuevo, distinto del identificador OEM. En esta unidad el UUID actual del cabezal es `e592fd710122`; no copiarlo a otras impresoras.

Para las actualizaciones posteriores de esta máquina se utiliza Katapult por CAN. La actualización del 15-11-2026 está documentada en `06-actualizacion-mcus-manual.md` y no requiere repetir este procedimiento SWD.

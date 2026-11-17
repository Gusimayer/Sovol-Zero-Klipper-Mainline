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


## 3.1. Objetivo de la migración

El objetivo de este proyecto es sustituir el entorno Klipper personalizado que suministra Sovol en la Sovol Zero por una instalación basada en **Klipper Mainline**, utilizando el código fuente oficial de Klipper y Katapult y eliminando las modificaciones específicas del firmware OEM.

La migración no consiste únicamente en instalar una versión diferente de Klipper en el sistema Linux. La Sovol Zero utiliza una arquitectura distribuida en la que intervienen:

- Un sistema Linux que ejecuta Klippy.
- Un microcontrolador STM32H750 en la placa principal.
- Un microcontrolador STM32F103 en el cabezal.
- Un enlace CAN entre la placa principal y el cabezal.
- El STM32H750 funcionando simultáneamente como MCU de la impresora y puente USB-CAN.

Por este motivo, la migración requiere actualizar de forma coordinada el software del host y el firmware de los microcontroladores.

También es necesario adaptar la configuración de la impresora. El firmware OEM incorpora extensiones, comandos y módulos que no existen en Klipper Mainline. Las funciones que ya están disponibles en upstream deben utilizarse mediante sus implementaciones nativas, mientras que las funciones exclusivamente OEM deben eliminarse, sustituirse o mantenerse desactivadas.

El resultado buscado es una instalación que pueda mantenerse y actualizarse utilizando los repositorios oficiales, sin depender de los mecanismos de actualización propios de Sovol.

### Alcance

La migración comprende:

1. Preparación y respaldo del sistema OEM.
2. Identificación del hardware y de los microcontroladores.
3. Preparación del entorno de compilación.
4. Instalación de Katapult en los microcontroladores.
5. Compilación y programación de Klipper Mainline.
6. Recuperación de la comunicación CAN.
7. Instalación y configuración del entorno Mainline en Linux.
8. Adaptación de `printer.cfg` y los archivos auxiliares.
9. Sustitución de las funciones específicas de Sovol.
10. Comprobación del funcionamiento de los componentes.
11. Calibración y validación mecánica.

La MCU opcional del calentador de cámara queda fuera de la primera fase de migración. No se debe incluir hasta identificarla y comprobar su comunicación.

---

## 3.2. Arquitectura de hardware de la Sovol Zero

La placa de control lleva la referencia serigrafiada:

`H616_JC_3Z_5160_V1.2`


### Host Linux

- SoC: Allwinner H616.
- Arquitectura: ARM64.
- Sistema operativo utilizado: Armbian Trixie / Debian 13. (https://armbian.com/es/boards/sovol-zero)
- Usuario del sistema: `sovol`.
- Directorio principal: `/home/sovol`.
- Klipper: `~/klipper`.
- Entorno Python: `~/klippy-env`.

El H616 ejecuta Klippy, Moonraker y los servicios de interfaz y administración.

### MCU principal

- Microcontrolador físico: STM32H750.
- Target utilizado para compilar Mainline: STM32H743.
- Frecuencia configurada: 400 MHz.
- Cristal externo: 25 MHz.
- Función: control de la placa principal y puente USB-CAN.

Aunque el microcontrolador físico es un H750, se utiliza el target H743 para compilar el firmware Mainline.

Esta elección permite utilizar la configuración de reloj de 400 MHz que hemos validado para esta placa. No debe confundirse el nombre del target de compilación con la identificación física del microcontrolador.

### MCU del cabezal

- Microcontrolador: STM32F103.
- Variante: densidad media.
- Identificador de dispositivo observado: `0x20036410`.
- Flash física: 128 KiB.
- RAM: 20 KiB.
- Comunicación con la placa principal: CAN.

Este microcontrolador controla los componentes del cabezal, entre ellos el extrusor, el calentador, el ventilador y el sensor Eddy LDC1612.

### Comunicación entre los componentes

La topología utilizada es:

```text
                 SOVOL ZERO
             ┌─────────────────┐
             │   Allwinner     │
             │      H616       │
             │                 │
             │ Linux / Klippy  │
             │ Moonraker       │
             │ Mainsail        │
             └────────┬────────┘
                      │ USB interno
                      │
             ┌────────▼────────┐
             │    STM32H750    │
             │  Target H743    │
             │                 │
             │ MCU principal   │
             │ USB-CAN Bridge  │
             └────────┬────────┘
                      │
                  CAN BUS
                      │
             ┌────────▼────────┐
             │    STM32F103    │
             │                 │
             │ MCU cabezal     │
             │ Extrusor        │
             │ Eddy LDC1612    │
             └─────────────────┘
```

No existe un cable USB interno independiente entre el H616 y el H750. La comunicación se realiza mediante las pistas USB de la propia placa.

El H750 actúa como puente USB-CAN, por lo que su funcionamiento es imprescindible para que Linux pueda comunicarse con los dos microcontroladores.

### UUID Mainline confirmados

Después de actualizar los microcontroladores, los UUID detectados son:

| MCU | UUID | Identificación |
|---|---|---|
| HOST | `4179ccb3303d` | STM32H750 |
| TOOLHEAD | `e592fd710122` | STM32F103 |

Los UUID originales del firmware OEM eran:

| MCU | UUID OEM |
|---|---|
| HOST | `0d1445047cdd` |
| TOOLHEAD | `61755fe321ac` |

Los identificadores OEM no deben reutilizarse en la configuración Mainline.

El firmware OEM sintetizaba los UUID mediante una modificación de `chipid.c`. Mainline utiliza la identificación real del hardware, por lo que al sustituir el firmware aparecen nuevos identificadores.

La identificación física de los nodos se comprobó desconectando temporalmente el cable CAN del cabezal y observando qué UUID permanecía disponible.

---

## 3.3. Preparación y respaldos previos

Antes de modificar firmware o configuraciones se realizó una copia de seguridad del entorno original.

El propósito es conservar tanto los archivos de configuración como los binarios necesarios para investigar o recuperar el estado anterior.

### Respaldo de configuración

Se conservó una copia independiente de los archivos OEM en:

`~/migration-backup/config-original-trabajo/`

Entre los archivos guardados se encuentran:

- `printer.cfg`
- `printer-backup.cfg`
- `Macro.cfg`
- `rgb.cfg`
- `plr.cfg`
- `chamber_hot.cfg`
- `macros_audio.cfg`
- `shell_command.cfg`
- `get_ip.cfg`
- `saved_variables.cfg`
- `mainsail.cfg`
- `moonraker.conf`
- `crowsnest.conf`
- `timelapse.cfg`
- `KlipperScreen.conf`
- Directorio `sounds/`

También se conservaron los archivos auxiliares y las copias anteriores de Moonraker.
* Se utiliza una pantalla BTT HDMI5 que reproduce audio, por eso de la macro_audio y directorio sound.
* Se utiliza tiras led por eso del rgb.cg

### Respaldo del firmware original

Se realizaron respaldos de los microcontroladores.

**STM32F103 del cabezal**

Archivo:

`~/firmware_lexfrei/backup/toolhead-original-128k.bin`

- Tamaño: 131072 bytes.
- Contenido: lectura de los 128 KiB de flash.
- SHA256:

`26e14185ab2a0fdc0018551c8cebc69ea0b33fca7b49040a03c1a92d001a6666`

**STM32H750 de la placa principal**

Se conservó una lectura de 128 KiB desde la dirección `0x08000000`.

Es importante señalar que este archivo no representa una copia completa de toda la memoria flash del H750.

SHA256:

`fb2c2630d2f25889235e7a3a0aafbad02e0b0971171e52105c3563dd677b1d5f`

### Respaldo del sistema

También se conservaron copias de la configuración, los registros de Klipper, Moonraker y Crowsnest.

Los archivos se copiaron al PC y se verificaron mediante SHA256.

Los respaldos originales no deben sobrescribirse durante las operaciones posteriores.

---

## 3.4. Preparación del almacenamiento y del entorno Mainline

Antes de comenzar la instalación de Klipper Mainline se realizó una modificación importante en el almacenamiento interno de la Sovol Zero: la sustitución del módulo eMMC original de 8 GB por uno de 32 GB.

Esta modificación permitió disponer de mayor capacidad para el sistema operativo, los repositorios de desarrollo, los entornos Python, los registros y los archivos auxiliares necesarios durante la migración.

### Sustitución del eMMC original

La Sovol Zero incorpora originalmente un módulo eMMC Samsung de 8 GB.

Se decidió sustituirlo por un módulo de mayor capacidad, conservando el original como respaldo físico.

| Característica | eMMC original | eMMC instalado |
|---|---|---|
| Fabricante / modelo | Samsung KLM8G1GET | YXSC YXSBG6PX-AE |
| Capacidad nominal | 8 GB | 32 GB |
| Función | Almacenamiento original | Almacenamiento del sistema |
| Estado posterior | Conservado intacto | Instalado y operativo |

El módulo de 32 GB se preparó previamente con Armbian y posteriormente se instaló en la placa de la Sovol Zero.

Una vez instalado, la impresora arrancó correctamente desde el nuevo almacenamiento.

El módulo original Samsung de 8 GB se retiró y se conservó intacto, sin utilizarlo para las operaciones posteriores de migración.

### Sistema operativo

El nuevo almacenamiento permitió trabajar con una instalación de Armbian basada en Debian Trixie.

Entorno utilizado:

- Sistema: Armbian Trixie.
- Distribución base: Debian 13.
- Arquitectura: ARM64.
- SoC: Allwinner H616.
- Usuario: `sovol`.

La instalación de Armbian constituye la base Linux sobre la que se ejecutan Klipper Mainline y los servicios asociados.

Es importante distinguir el cambio de almacenamiento de la migración de firmware: sustituir el eMMC no actualiza por sí mismo los microcontroladores STM32. Son operaciones independientes que forman parte de la preparación global de la impresora.

### Motivos de la ampliación

El almacenamiento original de 8 GB resulta limitado cuando se trabaja con repositorios de código fuente, herramientas de compilación, entornos virtuales de Python, registros y copias de seguridad.

La ampliación a 32 GB proporciona más espacio para:

- Código fuente de Klipper.
- Código fuente de Katapult.
- Entornos virtuales Python.
- Herramientas de compilación ARM.
- Firmware compilado.
- Configuraciones y macros.
- Registros de Klipper y Moonraker.
- Copias de seguridad.
- Archivos de mantenimiento y actualización.

### Resultado

El cambio de eMMC se completó satisfactoriamente.

La Sovol Zero arrancó desde el módulo YXSC de 32 GB con Armbian instalado, mientras que el módulo Samsung original de 8 GB quedó conservado como respaldo físico.

A partir de este punto, los trabajos de preparación y migración a Klipper Mainline se realizaron sobre el nuevo almacenamiento.

Se preparó el entorno de Klipper Mainline y Katapult.

### Directorios utilizados

```text
/home/sovol/
├── klipper/
├── katapult/
├── klippy-env/
├── printer_data/
│   ├── config/
│   ├── gcodes/
│   ├── logs/
│   └── systemd/
└── migration-backup/
    ├── config-original-trabajo/
    └── config-mainline-actual/
```

### Repositorios

Klipper se encuentra en:

`~/klipper`

Katapult se encuentra en:

`~/katapult`

El entorno Python de Klipper:

`~/klippy-env`

La instalación utiliza Klipper Mainline, rama `master`.

Durante la migración se trabajó con el commit:

`0cee841e31d701595b3e509a0b502f6e320f52a8`

Versión:

`v0.13.0-820-g0cee841e`

La versión del código fue evolucionando durante las pruebas y actualizaciones posteriores. La versión actual debe consultarse directamente en el repositorio instalado, no deducirse de los datos históricos de la migración.

### Servicios

Se conservaron los servicios existentes:

- Klipper.
- Moonraker.
- Mainsail.
- Crowsnest.
- KlipperScreen.

No se reinstalaron innecesariamente los componentes que ya estaban funcionando.

La ruta de configuración activa de Klipper es:

`/home/sovol/printer_data/config/printer.cfg`

El archivo de registros:

`/home/sovol/printer_data/logs/klippy.log`

La configuración de servicio utiliza el entorno Python de `~/klippy-env`.

---

## 3.5. Migración del microcontrolador principal H750

El primer elemento crítico fue el microcontrolador de la placa principal.

El H750 tiene una función especial en esta impresora: además de controlar los componentes conectados a la placa, actúa como puente USB-CAN.

Por tanto, su firmware debe configurarse correctamente para mantener la comunicación entre el host Linux y los nodos CAN.

### Bootstrap de Katapult

El acceso SWD del microcontrolador principal está físicamente poco accesible.

Para esta unidad se utilizó un programador ST-Link V2 y un binario Katapult preparado para la Sovol Zero.

Archivo utilizado:

`Katapult_Zero_Host_H743_128kb.bin`

Tamaño:

6764 bytes.

SHA256:

`464C8BB78D32AF26E4551AE1F324BB44569CBCD41435888D7028ED3173DF2021`

La programación se realizó mediante STM32CubeProgrammer.

La escritura se verificó correctamente en:

`0x08000000`

Este paso instala el bootloader Katapult utilizado para las operaciones posteriores.

### Comprobación USB

Después de programar Katapult, el dispositivo se presentó mediante USB con:

- VID: `1d50`
- PID: `6177`

Este identificador corresponde al dispositivo en modo Katapult.

Cuando el firmware Klipper está ejecutándose como puente USB-CAN, el identificador pasa a:

- VID: `1d50`
- PID: `606f`

La reenumeración USB permite distinguir ambos estados.

### Configuración de compilación H750/H743

El firmware Mainline del microcontrolador principal se compiló con estos parámetros:

| Parámetro | Valor |
|---|---|
| Arquitectura | STM32 |
| Target | STM32H743 |
| Frecuencia | 400 MHz |
| Cristal | 25 MHz |
| Dirección de aplicación | `0x08020000` |
| USB-CAN | PA11 / PA12 |
| CAN | PB8 / PB9 |
| Startup pins | `!PE11,!PB0` |

La dirección de aplicación debe mantenerse en `0x08020000`, ya que los primeros 128 KiB están reservados para el bootloader.

La configuración del puente USB-CAN permite que el host Linux acceda al bus CAN a través del H750.

### Verificación del puente

Una vez instalado el firmware Mainline, el dispositivo volvió a enumerarse como USB-CAN.

Se comprobó:

- Dispositivo USB `1d50:606f`.
- Interfaz `can0`.
- Driver `gs_usb`.
- Estado `UP`.
- Bitrate de 1 Mbps.
- Estado CAN `ERROR-ACTIVE`.

El estado `ERROR-ACTIVE` indica que el controlador CAN está funcionando normalmente; no significa por sí mismo que exista un error.

---

## 3.6. Migración del microcontrolador del cabezal STM32F103

El segundo microcontrolador que debe funcionar con Mainline es el STM32F103 del cabezal.

Su firmware original contiene modificaciones específicas de Sovol, especialmente relacionadas con el sensor Eddy y la comunicación con el sistema de control.

No es suficiente con sustituir únicamente el firmware del host: ambos microcontroladores deben utilizar un protocolo compatible.

### Características de compilación

| Parámetro | Valor |
|---|---|
| Arquitectura | STM32 |
| MCU | STM32F103 |
| Variante | `stm32f103xe` |
| Frecuencia | 72 MHz |
| Dirección de aplicación | `0x08002000` |
| Interfaz de comunicación | CAN |
| Pines CAN | PB8 / PB9 |
| Referencia de reloj | 8 MHz |
| Bootloader | Katapult |

La dirección `0x08002000` reserva los primeros 8 KiB para Katapult.

### Acceso SWD

Durante los trabajos de identificación y respaldo del cabezal se utilizó acceso SWD.

La conexión de referencia del programador ST-Link V2 es:

| ST-Link | Placa |
|---|---|
| 3.3 V | Alimentación de referencia |
| SWDIO | SWDIO |
| SWCLK | SWCLK |
| GND | GND |

La identificación del dispositivo se realizó mediante OpenOCD.

Se observó el identificador:

`0x1BA01477`

El dispositivo corresponde a la familia STM32F1.

El respaldo de flash del F103 se conserva antes de realizar modificaciones.

**Nota de trazabilidad:** no se debe presentar una secuencia de escritura SWD completa como procedimiento probado si no se dispone del registro de la operación original. La instalación final de Katapult y Klipper Mainline en el F103 sí quedó completada y el microcontrolador respondió correctamente por CAN.

### Comunicación CAN

Después de instalar el firmware Mainline, el F103 apareció en el bus con un UUID nuevo:

`e592fd710122`

Este UUID fue identificado físicamente desconectando y reconectando el cable CAN del cabezal.

La comunicación con el F103 quedó operativa a través del puente USB-CAN del H750.

---

## 3.7. Configuración de comunicación CAN

La interfaz CAN es una parte fundamental de la arquitectura.

La comunicación debe funcionar a 1 Mbps.

La interfaz utilizada es:

`can0`

El driver es:

`gs_usb`

La configuración final debe presentar:

```text
can0: UP
can state: ERROR-ACTIVE
bitrate 1000000
```

Los dos microcontroladores deben aparecer con sus UUID correspondientes.

La consulta de nodos se realiza con las herramientas de Katapult o con las herramientas de diagnóstico de CAN disponibles en la instalación.

Hay que distinguir dos situaciones:

- MCU ejecutando Klipper: está conectado y operativo, pero no aparece necesariamente como nodo Katapult.
- MCU en Katapult: responde a las consultas del bootloader y puede recibir una nueva imagen de firmware.

Por tanto, que una consulta Katapult no encuentre nodos mientras ambos MCU están ejecutando Klipper no implica que la comunicación CAN esté averiada.

---

## 3.8. Adaptación de la configuración OEM a Mainline

Una vez actualizados los microcontroladores, fue necesario adaptar la configuración de la impresora.

No se debe copiar directamente el `printer.cfg` OEM y esperar que funcione sin modificaciones.

El firmware de Sovol incorpora parámetros y extensiones que no están presentes en Mainline.

La estrategia utilizada consiste en conservar el archivo original y construir una configuración independiente para Mainline.

### Identificación de los MCU

Configuración Mainline:

```ini
[mcu]
canbus_uuid: 4179ccb3303d

[mcu extruder_mcu]
canbus_uuid: e592fd710122
```

Los UUID antiguos deben sustituirse por los nuevos identificadores reales.

### Sensor Eddy LDC1612

La configuración OEM utilizaba:

```ini
[probe_eddy_current eddy]
sensor_type: ldc1612
z_offset: 3.5
i2c_mcu: extruder_mcu
i2c_bus: i2c2
x_offset: -19.8
y_offset: -0.75
vir_contact_speed: 3.0
```

En Mainline se utiliza I²C por software:

```ini
[probe_eddy_current eddy]
sensor_type: ldc1612
i2c_mcu: extruder_mcu
i2c_software_scl_pin: extruder_mcu:PB10
i2c_software_sda_pin: extruder_mcu:PB11
x_offset: -19.8
y_offset: -0.75
descend_z: 0.5
max_sensor_hz: 6000000
```

La razón principal es que la implementación OEM del bus I²C hardware incorpora adaptaciones para el STM32F1 que no están presentes en Mainline.

En las pruebas de migración, el uso del bus hardware `i2c2` produjo errores `START_NACK`.

La implementación de I²C por software en PB10/PB11 permitió recuperar la comunicación con el sensor.

El parámetro `vir_contact_speed` es específico de Sovol y se elimina.

El antiguo `z_offset: 3.5` no debe trasladarse directamente a `descend_z`. Este último define la altura de aproximación del sensor y no representa el mismo ajuste.

La corriente de excitación y la tabla de calibración frecuencia-altura se generan mediante los procedimientos de calibración de Klipper.

### Homing Z

La configuración OEM utiliza funciones específicas de Sovol para el contacto y la calibración Z.

En Mainline se adapta el procedimiento de homing para utilizar el sensor Eddy y las funciones nativas de Klipper.

Se elimina la dependencia de:

- `[z_offset_calibration]`.
- `RUN_PROBE_VIR_CONTACT`.
- `Z_OFFSET_CALIBRATION`.

La configuración definitiva se realiza mediante las funciones de homing y sondeo disponibles en Mainline.

### Otras funciones OEM

También se revisan las macros y los archivos auxiliares.

Se conservan como referencia, pero no se activan automáticamente las funciones que dependen de módulos OEM ausentes.

Entre ellas:

- OTA de Sovol.
- Scripts de actualización de MCU OEM.
- Macros de recuperación eléctrica.
- Macros de calibración de contacto propietarias.
- Funciones específicas del módulo de cámara.
- Dependencias externas de audio no instaladas.

La existencia de una macro en un archivo no implica que se ejecute. Solo se ejecuta cuando es invocada desde G-code, otra macro o un evento.

Por tanto, no es necesario eliminar indiscriminadamente todas las macros que contienen movimientos.

---

## 3.9. Instalación y verificación de Klipper Mainline

Una vez preparados el host y los microcontroladores, se comprobó la compatibilidad entre las versiones.

Los dos MCU deben cargar firmware construido a partir de una versión compatible del mismo árbol de Klipper.

Una instalación con versiones incompatibles puede producir errores de protocolo, comandos desconocidos o fallos durante el inicio.

En el registro de Klipper se pueden observar las líneas:

```text
Loaded MCU 'mcu'
Loaded MCU 'extruder_mcu'
```

La comprobación debe incluir:

1. Que el MCU principal se conecta.
2. Que el MCU del cabezal se conecta.
3. Que ambos cargan una versión compatible.
4. Que no aparecen errores de protocolo.
5. Que Klipper termina en estado `Ready`.

La versión debe comprobarse en el registro de arranque actual, no únicamente en registros antiguos.

---

## 3.10. Validación funcional posterior

La migración de firmware no se considera terminada simplemente porque los dos MCU aparezcan conectados.

También es necesario validar los componentes de la impresora.

### Validación de comunicación

- Host Linux operativo.
- Klipper activo.
- Moonraker accesible.
- Mainsail conectado.
- CAN operativo.
- MCU principal conectado.
- MCU del cabezal conectado.

### Validación del sensor Eddy

Se realizaron las calibraciones nativas de Mainline.

Primero se ajustó la corriente del sensor mediante:

`LDC_CALIBRATE_DRIVE_CURRENT CHIP=eddy`

Resultado:

`reg_drive_current: 15`

Posteriormente se realizó la calibración frecuencia-altura y se guardó mediante `SAVE_CONFIG`.

También se completó el procedimiento de Eddy Tap:

- Consulta inicial.
- `TAP=guess`.
- `TAP=refine`.
- `TAP=verify`.
- Guardado mediante `SAVE_CONFIG`.

Umbral obtenido:

`tap_threshold = 10839.290`

La calibración quedó almacenada en la configuración.

### Homing y mediciones

Se completaron pruebas de homing y sondeo bajo supervisión del usuario.

También se realizó una prueba independiente mediante:

```gcode
PROBE METHOD=scan
```

El resultado obtenido fue:

```text
Result: at 96.000,76.200 estimate contact at z=-0.022311
```

La media obtenida en la prueba TAP fue:

`-0.078308`

Estos valores corresponden a métodos de medición distintos y no deben compararse directamente para deducir un error de calibración.

### Validación de impresión

La última fase debe comprobar el ciclo completo de impresión:

- Inicio.
- Calentamiento.
- Homing.
- Preparación de la malla.
- Impresión.
- Finalización.
- Cancelación.

Las pruebas físicas deben realizarse con el usuario presente y verificando previamente las coordenadas y los movimientos.

---

## 3.11. Componentes que no se migran inicialmente

### MCU del calentador de cámara

El archivo OEM `chamber_hot.cfg` describe un MCU auxiliar denominado `hot_mcu`.

Su UUID histórico es:

`58a72bb93aa4`

Sin embargo, este MCU no apareció en las consultas CAN realizadas durante la migración.

Por tanto:

- No se incluye en el `printer.cfg` Mainline.
- No se actualiza sin identificar primero el hardware.
- No se activan sus macros.
- No se da por hecho que el calentador de cámara funciona.

### Sensor de carga bajo la cama

La configuración OEM contiene referencias a un sistema de calibración de contacto.

Sin embargo, no se debe asumir que esta unidad tiene una célula de carga bajo la cama.

En esta instalación se ha confirmado que no existe ese sensor.

El sistema de medición Z utilizado es el Eddy LDC1612 del cabezal, con los métodos TAP y SCAN disponibles en Mainline.

La configuración y los procedimientos de calibración se adaptan a esa arquitectura.

---

## 3.12. Resultado de la migración

La migración OEM → Klipper Mainline ha permitido sustituir los componentes principales del entorno de Sovol.

| Componente | Resultado |
|---|---|
| Host Linux H616 | Operativo |
| Klipper Mainline | Operativo |
| Katapult H750/H743 | Instalado |
| Klipper H750/H743 | Operativo |
| Katapult F103 | Instalado |
| Klipper F103 | Operativo |
| Puente USB-CAN | Operativo |
| CAN 1 Mbps | Operativo |
| Mainsail | Operativo |
| Moonraker | Operativo |
| Crowsnest | Operativo |
| KlipperScreen | Operativo |
| Eddy LDC1612 | Operativo |
| Eddy TAP | Calibrado |
| Eddy SCAN | Probado |
| MCU cámara | Pendiente de diagnóstico |

La impresora funciona con Klipper Mainline y los dos microcontroladores principales están actualizados.

La arquitectura resultante permite mantener el sistema utilizando el código fuente Mainline y las herramientas de actualización de Katapult, sin depender del procedimiento OTA de Sovol.

---

## 3.13. Diferencia entre migración inicial y actualizaciones posteriores

Es importante distinguir dos procedimientos que no deben mezclarse.

### Migración inicial OEM → Mainline

Es la operación descrita en este capítulo.

Incluye:

- Respaldar el firmware OEM.
- Sustituir los bootloaders cuando corresponde.
- Instalar Katapult Mainline.
- Instalar Klipper Mainline.
- Obtener los nuevos UUID.
- Adaptar la configuración OEM.
- Validar los componentes.

Es una operación de cambio de plataforma.

### Actualización Mainline → Mainline

Una vez que la impresora ya funciona con Mainline, las actualizaciones posteriores son mucho más sencillas.

No es necesario repetir el bootstrap inicial ni volver a instalar Katapult.

En nuestra instalación:

**TOOLHEAD F103**
- Se compila Klipper para STM32F103.
- Se programa mediante Katapult por CAN.
- Se utiliza el UUID actual del cabezal.

**HOST H743**
- Se compila Klipper para STM32H743.
- Se solicita la entrada en Katapult mediante CAN.
- El puente USB-CAN se reenumera como dispositivo Katapult USB.
- Se consulta el estado del bootloader.
- Se programa el firmware mediante USB serie.
- El puente vuelve a enumerarse como USB-CAN.

Este procedimiento se encuentra documentado y se ha ejecutado manualmente con resultado satisfactorio en esta máquina.

Las actualizaciones Mainline posteriores deben utilizar exclusivamente este flujo y no repetir los pasos de la migración OEM.

---

## 3.14. Consideraciones para futuras recuperaciones

La recuperación depende del componente que haya fallado.

### Si Klipper no arranca, pero Katapult responde

Se puede volver a programar la aplicación Klipper utilizando Katapult, siempre que el bootloader esté operativo y la dirección de aplicación sea correcta.

### Si el HOST permanece en Katapult

El H750 debe aparecer como dispositivo USB Katapult.

Se puede consultar su estado y comprobar la dirección de aplicación antes de programar un nuevo binario.

No se debe arrancar Klipper mientras el puente USB-CAN no haya regresado correctamente.

### Si Katapult del HOST queda dañado

La recuperación puede requerir acceso SWD al microcontrolador principal.

El acceso físico es complicado debido a la integración de la placa. Por este motivo, no se debe interrumpir la alimentación ni la conexión USB durante la programación.

### Si el TOOLHEAD deja de responder

Primero se debe comprobar la comunicación CAN y el estado del bootloader.

Si Katapult responde, se puede volver a programar por CAN.

Si el bootloader no responde, puede ser necesario recuperar el F103 mediante SWD.

Los respaldos originales y los binarios Mainline deben conservarse fuera de la impresora.

---

## 3.15. Conclusión

La migración de la Sovol Zero a Klipper Mainline no consiste en sustituir una versión de Klipper por otra.

Es una migración completa de la arquitectura de firmware, desde el sistema OEM hasta el host Linux y los microcontroladores que controlan la impresora.

El trabajo más importante ha sido identificar correctamente el hardware, conservar los respaldos, sustituir los firmware OEM por versiones Mainline compatibles y adaptar las funciones propietarias a las implementaciones disponibles en upstream.

La configuración resultante utiliza:

- Klipper Mainline.
- Katapult.
- STM32H750 físico compilado como STM32H743.
- STM32F103 en el cabezal.
- Puente USB-CAN.
- Comunicación CAN a 1 Mbps.
- Eddy LDC1612 mediante I²C por software.
- Eddy TAP y SCAN nativos de Mainline.

La experiencia obtenida permite disponer de un procedimiento reproducible para esta unidad y de una base documentada para futuras actualizaciones y tareas de mantenimiento.

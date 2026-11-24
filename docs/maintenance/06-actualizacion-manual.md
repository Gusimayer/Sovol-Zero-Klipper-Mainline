# 06 — Actualización manual de MCU: Klipper Mainline → Klipper Mainline

## 06.1. Objetivo y alcance

Este procedimiento describe la actualización manual del firmware Klipper de los dos microcontroladores de una Sovol Zero que **ya está migrada a Klipper Mainline y tiene Katapult instalado y operativo**.

La actualización documentada se realizó el **15-11-2026**. Ambos microcontroladores terminaron ejecutando Klipper `v0.13.0-827-g29d4ec2d`, y Mainsail mostró HOST y TOOLHEAD conectados.

> **Importante: esto no es la migración inicial desde el firmware OEM de Sovol.**
>
> En una actualización Mainline → Mainline:
> - No se reinstala Katapult.
> - No se utiliza Deployer.
> - No se repite el procedimiento de bootstrap mediante ST-Link.
> - No se modifican los UUID.
> - Se actualiza la aplicación Klipper que se ejecuta en cada MCU.
>
> El F103 del cabezal se actualiza directamente por CAN. El H750 de la placa principal se pone primero en Katapult mediante CAN y, al reenumerarse como dispositivo USB serie, se programa por ese puerto.

Este capítulo separa los datos confirmados de la sesión del 15-11-2026 de los comandos de comprobación que se proponen para que otra persona pueda repetir el procedimiento con seguridad. Los nombres de dispositivos, UUID y puertos pueden ser distintos en otras impresoras.

---

## 06.2. Arquitectura y orden de actualización

La Sovol Zero de esta instalación utiliza dos MCU:

| Identificación | Microcontrolador físico | Target de compilación | Método de actualización |
|---|---|---|---|
| TOOLHEAD | STM32F103 | `stm32f103xe` | Katapult por CAN |
| HOST | STM32H750 | `stm32h743xx` | Solicitud Katapult por CAN y programación por USB serie |

El H750 cumple dos funciones: ejecuta el firmware del MCU principal y actúa como puente USB-CAN entre Linux y el bus CAN. Por ese motivo, al ponerlo en modo Katapult, el dispositivo USB cambia temporalmente de identidad y la interfaz CAN deja de estar disponible hasta que vuelve a arrancar Klipper.

### Datos de esta instalación

- Repositorio Klipper: `~/klipper`
- Entorno Python de Klipper: `~/klippy-env`
- Interfaz CAN: `can0`
- Velocidad CAN: 1 Mbps
- Herramienta Katapult utilizada: `~/klipper/lib/katapult/flashtool.py`
- UUID TOOLHEAD y HOST: consultar los valores configurados en `printer.cfg`; no copiar UUID de otra máquina.
- Versión final comprobada: `v0.13.0-827-g29d4ec2d`

Los UUID completos de la máquina de referencia se omiten en esta documentación pública. Cada usuario debe utilizar los UUID reales de su propia impresora.

---

## 06.3. Precauciones antes de empezar

Una actualización de firmware implica detener temporalmente el control de la impresora. No iniciar el proceso mientras haya una impresión en curso o los calentadores estén activos.

1. Dejar la impresora en reposo y comprobar que no hay ninguna impresión.
2. Dejar enfriar la cama y el hotend.
3. Mantener la alimentación eléctrica estable durante todo el proceso.
4. No desconectar el USB ni la alimentación mientras se está escribiendo el firmware.
5. No cerrar el terminal durante una operación de programación.
6. No ejecutar comandos de migración OEM ni volver a instalar Katapult.
7. Confirmar que se dispone de acceso al host Linux y a Mainsail.
8. Tener a mano una copia de `printer.cfg` y de los archivos de configuración de compilación.

### Advertencia sobre `make clean`

Klipper utiliza el directorio `out/` para los archivos generados durante la compilación. El comando `make clean` elimina ese contenido.

Por tanto, **no se debe compilar el segundo MCU sin haber guardado antes el binario del primero**. Si se compila HOST después de F103, el archivo `out/klipper.bin` del F103 puede ser sustituido. Se guardan los binarios con nombres diferentes antes de continuar.

---

## 06.4. Acceso al host y comprobaciones iniciales

Abrir una sesión SSH o un terminal local en la Sovol Zero e iniciar sesión con el usuario que administra Klipper.

### Paso 1. Comprobar el usuario y el directorio

```bash
whoami
```

El resultado esperado en esta instalación es:

```text
sovol
```

Comprobar el directorio principal:

```bash
printf '%s\n' "$HOME"
```

En esta instalación debe mostrar:

```text
/home/sovol
```

### Paso 2. Comprobar que existe el repositorio de Klipper

```bash
ls -ld ~/klipper
```

Debe aparecer el directorio del repositorio. Si no existe, detener el procedimiento: esta guía presupone una instalación Mainline ya operativa.

### Paso 3. Comprobar la versión del código fuente

```bash
cd ~/klipper && git describe --always --tags
```

Este comando muestra la versión identificada por Git. La versión final de la sesión documentada fue:

```text
v0.13.0-827-g29d4ec2d
```

No es obligatorio que otra instalación tenga exactamente esa versión. Lo importante es que los dos MCU se compilen desde el mismo árbol de Klipper y que la versión elegida sea la que se pretende instalar.

### Paso 4. Comprobar la herramienta de programación

```bash
ls -l ~/klipper/lib/katapult/flashtool.py
```

La ruta debe existir. Esta es la herramienta utilizada en la actualización documentada. No se debe sustituir automáticamente por una ruta de otra guía o instalación.

### Paso 5. Consultar la ayuda de la herramienta

```bash
python3 ~/klipper/lib/katapult/flashtool.py -h
```

La ayuda permite comprobar las opciones disponibles en la versión instalada. Si las opciones no coinciden con las mostradas en este documento, detenerse y revisar la versión de la herramienta antes de continuar.

---

## 06.5. Comprobar el estado de Klipper y de CAN

### Paso 1. Consultar el servicio Klipper

```bash
sudo systemctl status klipper --no-pager
```

Antes de la actualización, Klipper debe estar funcionando correctamente. Si ya existe un error de conexión con alguno de los MCU, hay que resolverlo antes de actualizar.

### Paso 2. Consultar la interfaz CAN

```bash
ip -details link show can0
```

La interfaz debe existir y mostrar una configuración de 1 Mbps. En la sesión de referencia, una vez que el puente H750 estaba funcionando, `can0` aparecía `UP` y el estado CAN era `ERROR-ACTIVE`.

También puede consultarse de forma resumida:

```bash
ip -brief link show can0
```

Si `can0` no existe, está caída o no tiene la velocidad esperada, no continuar con la programación del F103.

### Paso 3. Identificar los UUID de la instalación

Consultar el archivo de configuración:

```bash
grep -n -A2 -E '^\[mcu\]|^\[mcu extruder_mcu\]' ~/printer_data/config/printer.cfg
```

En esta configuración, `[mcu]` corresponde al HOST y `[mcu extruder_mcu]` al TOOLHEAD.

Anotar por separado los valores de `canbus_uuid`. No intercambiarlos. Los comandos de esta guía utilizan los marcadores `<UUID_TOOLHEAD>` y `<UUID_HOST>` para evitar publicar identificadores privados.

---

## 06.6. Preparar directorio de copias de firmware

Crear un directorio para conservar los binarios generados:

```bash
mkdir -p ~/firmware-updates/2026-11-15
```

Comprobar que se ha creado:

```bash
ls -ld ~/firmware-updates/2026-11-15
```

Los nombres de los archivos guardados deben identificar claramente el MCU al que corresponden. No utilizar un único nombre genérico para los dos binarios.

---

## 06.7. Compilar Klipper para el TOOLHEAD STM32F103

El primer MCU que se actualiza es el del cabezal.

### Paso 1. Crear o revisar la configuración de compilación

En la sesión documentada se utilizó:

```text
~/klipper/klipper-f103-update.config
```

La configuración debe corresponder a estos parámetros:

```text
CONFIG_MCU="stm32f103xe"
CONFIG_CLOCK_FREQ=72000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8002000
CONFIG_STM32_FLASH_START_2000=y
CONFIG_STM32_CLOCK_REF_8M=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```

Explicación:

| Parámetro | Significado |
|---|---|
| `stm32f103xe` | Familia/variante de MCU seleccionada para compilar |
| `72000000` | Reloj de 72 MHz |
| `0x8002000` | Dirección donde comienza la aplicación Klipper |
| `FLASH_START_2000` | Reserva los primeros 8 KiB para Katapult |
| `CLOCK_REF_8M` | Cristal de referencia de 8 MHz |
| `CANBUS_PB8_PB9` | Utiliza PB8 y PB9 para CAN |

La dirección `0x08002000` es esencial: no debe cambiarse por `0x08000000`, porque los primeros 8 KiB están reservados para Katapult.

### Paso 2. Entrar en el repositorio

```bash
cd ~/klipper
```

### Paso 3. Limpiar compilaciones anteriores

```bash
make clean
```

Este comando elimina los archivos de compilación anteriores del directorio `out/`. No elimina el repositorio ni los archivos `.config` independientes, pero sí puede eliminar un `klipper.bin` generado previamente. Por eso se debe guardar cualquier binario anterior antes de ejecutarlo.

### Paso 4. Abrir la configuración de compilación del F103

```bash
make menuconfig KCONFIG_CONFIG=klipper-f103-update.config
```

En el menú de configuración, comprobar que las opciones coinciden con los parámetros indicados en el apartado anterior. No seleccionar opciones de otra placa ni cambiar la interfaz CAN.

Guardar la configuración y salir del menú.

> La configuración exacta utilizada en la sesión se conserva en `klipper-f103-update.config`. Su SHA256 registrado fue `439597e622736e5162191b484ad256b42214faef4d6042d1e13c957848c99dd6`.

### Paso 5. Compilar el firmware

```bash
make KCONFIG_CONFIG=klipper-f103-update.config
```

Esperar a que termine. Si aparecen errores, no continuar con el flasheo. Revisar el mensaje completo y corregir la compilación primero.

El binario generado debe estar en:

```text
~/klipper/out/klipper.bin
```

### Paso 6. Comprobar que existe el binario

```bash
ls -lh ~/klipper/out/klipper.bin
```

Calcular su hash:

```bash
sha256sum ~/klipper/out/klipper.bin
```

En la sesión del 15-11-2026, el binario F103 tuvo este SHA256:

```text
df966915ba70b65edd760e2fe3ac32102075dd24ea9e233121d5c37e29697cb0
```

Si el código fuente o la configuración son diferentes, el hash también puede ser diferente. El hash es una huella de identificación, no un valor que deba forzarse.

### Paso 7. Guardar el binario con un nombre inequívoco

```bash
cp ~/klipper/out/klipper.bin ~/firmware-updates/2026-11-15/klipper-f103.bin
```

Comprobar la copia:

```bash
sha256sum ~/firmware-updates/2026-11-15/klipper-f103.bin
```

El hash debe coincidir con el del archivo recién compilado.

---

## 06.8. Detener Klipper antes de programar

Antes de enviar firmware a los MCU, detener el servicio Klipper para evitar que intente comunicarse con ellos durante el proceso.

```bash
sudo systemctl stop klipper
```

Comprobar que se ha detenido:

```bash
sudo systemctl is-active klipper
```

El resultado esperado es:

```text
inactive
```

Si el servicio sigue activo, no continuar hasta averiguar por qué no se ha detenido.

---

## 06.9. Programar el TOOLHEAD F103 mediante CAN

El F103 se actualiza directamente por el bus CAN a través del puente USB-CAN del H750.

### Paso 1. Confirmar que CAN sigue disponible

```bash
ip -details link show can0
```

Debe seguir apareciendo `can0` en estado `UP`, a 1 Mbps.

### Paso 2. Enviar el firmware al F103

Sustituir `<UUID_TOOLHEAD>` por el UUID real del cabezal, obtenido de `printer.cfg`:

```bash
python3 ~/klipper/lib/katapult/flashtool.py -i can0 -u <UUID_TOOLHEAD> -f ~/firmware-updates/2026-11-15/klipper-f103.bin
```

Qué significa cada argumento:

- `python3`: ejecuta la herramienta con Python 3.
- `flashtool.py`: herramienta de Katapult para comunicarse con el bootloader.
- `-i can0`: utiliza la interfaz CAN.
- `-u <UUID_TOOLHEAD>`: selecciona el MCU del cabezal.
- `-f ...klipper-f103.bin`: indica el archivo que se va a programar.

No utilizar el UUID del HOST en este comando.

### Paso 3. Esperar a que finalice la escritura

No interrumpir el proceso. En la sesión documentada se observaron los mensajes:

```text
Write complete
Verification Complete
Programming Complete
```

Estos mensajes indican que la escritura y la verificación finalizaron correctamente.

Si aparece un error, no dar por actualizada la MCU. Conservar la salida completa para diagnosticarlo.

### Paso 4. No arrancar Klipper todavía si se va a actualizar el HOST

En el procedimiento documentado se actualizó a continuación el HOST. Por tanto, Klipper permaneció detenido mientras se realizaba también esa operación.

---

## 06.10. Compilar Klipper para el HOST H750 usando target H743

El MCU físico es un STM32H750, pero esta instalación utiliza el target de compilación `stm32h743xx`, con la configuración de reloj validada para la placa.

### Paso 1. Revisar la configuración de compilación

Archivo utilizado:

```text
~/klipper/klipper-h743-update.config
```

Parámetros:

```text
CONFIG_MCU="stm32h743xx"
CONFIG_CLOCK_FREQ=400000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8020000
CONFIG_STM32_FLASH_START_20000=y
CONFIG_STM32_CLOCK_REF_25M=y
CONFIG_STM32_USBCANBUS_PA11_PA12=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```

Explicación:

| Parámetro | Significado |
|---|---|
| `stm32h743xx` | Target utilizado para compilar el MCU físico H750 |
| `400000000` | Reloj configurado a 400 MHz |
| `0x8020000` | Dirección de inicio de la aplicación |
| `FLASH_START_20000` | Reserva 128 KiB para Katapult |
| `CLOCK_REF_25M` | Cristal externo de 25 MHz |
| `USBCANBUS_PA11_PA12` | Activa el puente USB-CAN |
| `CANBUS_PB8_PB9` | Configura los pines CAN |

La dirección `0x08020000` reserva los primeros 128 KiB para Katapult. No cambiarla por `0x08000000`.

### Paso 2. Volver al repositorio

```bash
cd ~/klipper
```

### Paso 3. Limpiar la compilación anterior

```bash
make clean
```

El comando elimina `out/`. El binario F103 ya debe estar guardado en `~/firmware-updates/2026-11-15/klipper-f103.bin` antes de ejecutar este paso.

### Paso 4. Abrir la configuración H743

```bash
make menuconfig KCONFIG_CONFIG=klipper-h743-update.config
```

Comprobar las opciones anteriores, especialmente:

- Target `STM32H743`.
- Reloj de 400 MHz.
- Cristal de 25 MHz.
- USB-CAN por PA11/PA12.
- CAN por PB8/PB9.
- Inicio de aplicación en `0x08020000`.

Guardar y salir.

> El SHA256 de la configuración utilizada en la sesión fue `ad6dd374a8e086311b1927923fc7fdfd452cda49f160ef386e9b6a345cc4a10a`.

### Paso 5. Compilar el HOST

```bash
make KCONFIG_CONFIG=klipper-h743-update.config
```

Esperar a que finalice sin errores.

### Paso 6. Comprobar el binario

```bash
ls -lh ~/klipper/out/klipper.bin
```

Calcular su hash:

```bash
sha256sum ~/klipper/out/klipper.bin
```

El SHA256 del binario H743 generado en la sesión documentada fue:

```text
5a6f9d4d4354b247edc3ba0d0bdb33bc00600eafee3abb9dce923a52e879b273
```

### Paso 7. Guardar el binario HOST por separado

```bash
cp ~/klipper/out/klipper.bin ~/firmware-updates/2026-11-15/klipper-h743.bin
```

Verificar la copia:

```bash
sha256sum ~/firmware-updates/2026-11-15/klipper-h743.bin
```

El hash debe coincidir con el del binario generado.

---

## 06.11. Poner el HOST H750 en modo Katapult

Esta operación es distinta de la actualización del F103.

El H750 está funcionando como puente USB-CAN. Primero se le envía por CAN una solicitud para que reinicie y entre en Katapult. Después, el dispositivo se presenta como un puerto USB serie.

### Paso 1. Comprobar la identidad USB-CAN actual

```bash
lsusb
```

Con Klipper funcionando en el H750, el dispositivo se identifica en esta instalación como:

```text
1d50:606f
```

Este identificador corresponde al modo USB-CAN de Klipper.

### Paso 2. Solicitar Katapult al HOST por CAN

Sustituir `<UUID_HOST>` por el UUID del HOST obtenido de `printer.cfg`:

```bash
python3 ~/klipper/lib/katapult/flashtool.py -i can0 -u <UUID_HOST> -r
```

La opción `-r` solicita al MCU que reinicie en el bootloader Katapult.

Al ejecutarse esta operación, el puente USB-CAN deja de funcionar temporalmente como interfaz CAN. Es normal que `can0` desaparezca o deje de estar disponible durante este cambio.

### Paso 3. Esperar la reenumeración USB

En la sesión del 15-11-2026 el dispositivo reapareció con:

```text
1d50:6177
```

Este VID:PID identifica Katapult USB, no el modo normal USB-CAN.

Comprobar los dispositivos USB:

```bash
lsusb
```

Identificar el puerto serie disponible:

```bash
ls -l /dev/ttyACM*
```

En aquella sesión apareció:

```text
/dev/ttyACM0
```

**No asumir que siempre será `/dev/ttyACM0`.** El nombre puede cambiar según el orden de conexión y los dispositivos presentes. Utilizar el puerto que acaba de aparecer asociado al dispositivo Katapult. Si hay varios puertos, identificarlo antes de continuar; no probar puertos al azar.

---

## 06.12. Consultar Katapult y verificar la dirección de aplicación

Antes de escribir el HOST, consultar el estado del bootloader.

Sustituir `/dev/ttyACM0` si el sistema ha asignado otro puerto:

```bash
python3 ~/klipper/lib/katapult/flashtool.py -d /dev/ttyACM0 -s
```

La opción `-d` selecciona el dispositivo serie y `-s` consulta su estado.

En la sesión documentada se verificó:

- Katapult conectado.
- Protocolo `1.1.0`.
- Tamaño de bloque: 64 bytes.
- `Application Start: 0x8020000`.

La dirección `0x8020000` debe coincidir con la dirección configurada al compilar Klipper para el HOST.

**No programar el firmware si la dirección de aplicación que informa Katapult no coincide con la prevista.** Detenerse y revisar la configuración del bootloader y la compilación.

---

## 06.13. Programar el HOST H750 por USB serie

Una vez comprobado Katapult y su dirección de aplicación, enviar el binario H743.

Sustituir el puerto serie por el que se haya identificado en el paso anterior:

```bash
python3 ~/klipper/lib/katapult/flashtool.py -d /dev/ttyACM0 -f ~/firmware-updates/2026-11-15/klipper-h743.bin
```

Qué significa cada argumento:

- `-d /dev/ttyACM0`: selecciona el puerto serie del H750 en modo Katapult.
- `-f`: indica el archivo de firmware que se va a escribir.
- `klipper-h743.bin`: binario Mainline compilado para el target H743.

Esperar a que finalicen la escritura y la verificación. En la sesión documentada se completó la programación correctamente y el dispositivo se reenumeró de nuevo como USB-CAN.

No desconectar la alimentación ni el cable durante la escritura.

---

## 06.14. Comprobar el regreso del HOST al modo USB-CAN

Después de programar el HOST, el H750 debe reiniciar y volver a ejecutar Klipper como puente USB-CAN.

### Paso 1. Comprobar la identidad USB

```bash
lsusb
```

El dispositivo debe volver a identificarse como:

```text
1d50:606f
```

Si continúa como `1d50:6177`, sigue en modo Katapult. No considerar finalizada la actualización ni intentar operar la impresora.

### Paso 2. Comprobar que vuelve a existir CAN

```bash
ip -details link show can0
```

En la sesión de referencia, `can0` volvió a estar disponible con:

- Estado `UP`.
- Driver `gs_usb`.
- Bitrate de 1 Mbps.
- Estado CAN `ERROR-ACTIVE`.

Si `can0` no reaparece, revisar primero el estado USB del H750 y los registros del sistema. No dar por correcta la actualización únicamente porque el comando de flasheo haya terminado.

---

## 06.15. Arrancar Klipper y validar los dos MCU

Cuando el HOST haya vuelto a enumerarse como USB-CAN y `can0` esté disponible, arrancar Klipper:

```bash
sudo systemctl start klipper
```

Comprobar el servicio:

```bash
sudo systemctl status klipper --no-pager
```

Debe aparecer activo. Después, desde Mainsail, ejecutar:

```gcode
FIRMWARE_RESTART
```

Esperar a que Klipper vuelva a inicializarse. No ejecutar movimientos ni activar calentadores durante esta primera comprobación.

### Validación en Mainsail

Comprobar que:

1. Klipper alcanza el estado `Ready`.
2. El MCU principal HOST está conectado.
3. El MCU del cabezal TOOLHEAD está conectado.
4. No aparecen errores de protocolo.
5. No hay errores de comunicación CAN.
6. La telemetría vuelve a actualizarse.

### Comprobación de versión en el registro

Consultar las líneas recientes del registro:

```bash
tail -n 100 ~/printer_data/logs/klippy.log
```

La sesión documentada terminó con ambos MCU ejecutando:

```text
v0.13.0-827-g29d4ec2d
```

No utilizar una línea antigua del registro como prueba de la versión actual. Revisar el último arranque y confirmar que los dos MCU se han conectado en esa inicialización.

---

## 06.16. Resultado de la actualización del 15-11-2026

La actualización manual se completó correctamente.

| Elemento | Resultado |
|---|---|
| TOOLHEAD STM32F103 | Programado por CAN |
| HOST STM32H750 / target H743 | Programado por USB serie tras solicitar Katapult por CAN |
| Katapult | Conservado; no reinstalado |
| USB-CAN | Recuperado |
| `can0` | `UP`, 1 Mbps, `ERROR-ACTIVE` |
| Versión de Klipper en ambos MCU | `v0.13.0-827-g29d4ec2d` |
| Mainsail | HOST y TOOLHEAD conectados |
| Telemetría | Operativa |

### Huellas de los archivos de la sesión de referencia

Estos valores sirven para identificar los archivos exactos generados durante aquella actualización. No son valores universales ni deben coincidir si se utiliza otro commit o configuración.

| Archivo | SHA256 |
|---|---|
| `klipper-f103-update.config` | `439597e622736e5162191b484ad256b42214faef4d6042d1e13c957848c99dd6` |
| `klipper-f103.bin` | `df966915ba70b65edd760e2fe3ac32102075dd24ea9e233121d5c37e29697cb0` |
| `klipper-f103.elf` | `16833ccb7bf5a1d3745b97d0be211082c497ddcee9876ff035a8cd979167891c` |
| `klipper-h743-update.config` | `ad6dd374a8e086311b1927923fc7fdfd452cda49f160ef386e9b6a345cc4a10a` |
| `klipper-h743.bin` | `5a6f9d4d4354b247edc3ba0d0bdb33bc00600eafee3abb9dce923a52e879b273` |
| `klipper-h743.elf` | `648fd98da2fbbe1e9c0f7bc643c714b519b3aa24e9fc2abe1357b20ca89867ad` |
| Defconfig H743 | `44981331d1b477571a5a7ac028ca020e59f52e8739d2f95c31aaab437ac7467b` |

---

## 06.17. Problemas habituales y cómo actuar

### El F103 no responde por CAN

Comprobar:

- Que `can0` existe y está `UP`.
- Que el bitrate es 1 Mbps.
- Que el UUID corresponde al cabezal.
- Que Klipper está detenido.
- Que el F103 está alimentado y conectado al bus.

No cambiar UUID ni parámetros de pines para intentar resolverlo sin identificar primero la causa.

### El H750 no reaparece como Katapult USB

Comprobar si el dispositivo USB ha cambiado de VID:PID y si el kernel ha creado un puerto serie. No asumir que el puerto es siempre `/dev/ttyACM0`.

Si el H750 no aparece como Katapult, no intentar flashearlo por un puerto que no se haya identificado. La recuperación puede requerir diagnóstico adicional.

### Katapult informa una dirección de aplicación distinta

No escribir el binario. Comparar la dirección que informa Katapult con `CONFIG_FLASH_APPLICATION_ADDRESS` de la compilación. En esta máquina debe ser `0x8020000` para el HOST y `0x08002000` para el F103.

### El HOST se programa, pero no vuelve `can0`

Comprobar primero que el USB ha vuelto a `1d50:606f`. Si sigue en `1d50:6177`, el H750 continúa en Katapult y todavía no está funcionando como puente USB-CAN.

### Klipper no alcanza `Ready`

Revisar el último arranque de `klippy.log`, la conexión de ambos MCU y los mensajes de protocolo. No repetir el flasheo sin haber identificado el error.

---

## 06.18. Diferencia respecto a la migración OEM → Mainline

Este procedimiento solo es válido cuando los dos microcontroladores ya ejecutan Klipper Mainline y Katapult está instalado.

| Operación | Migración OEM → Mainline | Actualización Mainline → Mainline |
|---|---|---|
| Instalar Katapult | Sí, cuando corresponde | No |
| Usar ST-Link para bootstrap | Puede ser necesario | No forma parte del procedimiento normal |
| Cambiar UUID | Sí, al sustituir la identificación OEM | No |
| Compilar Klipper | Sí | Sí |
| Actualizar F103 por CAN | Según estado inicial | Sí |
| Solicitar Katapult al HOST por CAN | Según estado inicial | Sí |
| Programar HOST por USB serie | Según bootloader y estado inicial | Sí, en este procedimiento |
| Adaptar la configuración OEM | Sí | No, salvo cambios funcionales independientes |

No utilizar este capítulo para recuperar una impresora que todavía ejecuta firmware OEM o que no tiene Katapult operativo. En ese caso debe seguirse el procedimiento de migración inicial y recuperación correspondiente.

---

## 06.19. Referencias y trazabilidad

La actualización descrita se realizó manualmente el 15-11-2026. Se verificaron la escritura y programación de ambos MCU, la reenumeración USB del HOST, la recuperación de CAN y el estado final `Ready` en Mainsail.

El actualizador automatizado de Asnajder no se ejecutó de principio a fin durante esta sesión. Por tanto, este capítulo documenta el procedimiento manual, no una ejecución del script automatizado.

Los comandos de consulta incluidos para identificar el entorno y los dispositivos forman parte de una secuencia reproducible de comprobación. Cuando el registro histórico no conserva una transcripción literal de una consulta, no se presenta su salida como si se hubiera capturado durante la sesión original.

---

**Navegación:** [← Índice de mantenimiento](README.md) | [Siguiente: actualización automática](10-actualizacion-automatica.md)

# Actualización manual de los MCUs

**Prueba de referencia: 15-11-2026.** Este procedimiento actualiza la aplicación Klipper en HOST STM32H743 y TOOLHEAD STM32F103 cuando Klipper Mainline y Katapult ya están instalados y funcionando.

## 1. Diferencia entre los MCUs
- HOST H743: funciona también como puente USB-CAN. Se solicita Katapult por CAN y se programa por USB serie.
- TOOLHEAD F103: se programa directamente por CAN.

No reinstalar Katapult ni Deployer. No seguir aquí el procedimiento de migración OEM → Mainline.

## 2. Comprobaciones previas
```bash
systemctl is-active klipper
ip -details -statistics link show can0
lsusb
python3 ~/katapult/scripts/flashtool.py -i can0 -q
```
Confirmar que `can0` está UP, `ERROR-ACTIVE`, 1 Mbps, y que se han identificado correctamente los UUID de HOST y TOOLHEAD. Los UUID son propios de cada máquina; no copiar los de otra instalación.

Conservar backups de configuración, firmware y sistema. Mantener alimentación estable.

## 3. Compilar firmwares por separado

Configuración F103 comprobada:
```text
CONFIG_MCU="stm32f103xe"
CONFIG_CLOCK_FREQ=72000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8002000
CONFIG_STM32_FLASH_START_2000=y
CONFIG_STM32_CLOCK_REF_8M=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```

```bash
cd ~/klipper
make clean
make KCONFIG_CONFIG=klipper-f103-update.config -j2
```
Guardar inmediatamente `out/klipper.bin` como `klipper-f103.bin`.

Configuración H743 comprobada:
```text
CONFIG_MCU="stm32h743xx"
CONFIG_CLOCK_FREQ=400000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8020000
CONFIG_STM32_FLASH_START_20000=y
CONFIG_STM32_CLOCK_REF_25M=y
CONFIG_STM32_USBCANBUS_PA11_PA12=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```

```bash
make clean
make KCONFIG_CONFIG=klipper-h743-update.config -j2
```
Guardar `out/klipper.bin` como `klipper-h743.bin`.

`make clean` elimina la salida anterior. No compilar el segundo MCU hasta haber guardado el binario del primero. Calcular hashes:
```bash
sha256sum ~/klipper/klipper-f103.bin
sha256sum ~/klipper/klipper-h743.bin
```

## 4. Actualizar TOOLHEAD F103 por CAN

Detener Klipper:
```bash
sudo systemctl stop klipper
```

Programar (sustituir `<UUID_TOOLHEAD>` por el UUID comprobado de esta impresora):
```bash
python3 ~/klipper/lib/katapult/flashtool.py -i can0 -u <UUID_TOOLHEAD> -f ~/klipper/klipper-f103.bin
```
Esperar `Programming Complete`. No cortar alimentación. En la prueba, tras el flasheo fue necesario `FIRMWARE_RESTART` desde Mainsail para recuperar READY; verificar el estado real antes de continuar.

## 5. Actualizar HOST H743: CAN → USB serie

Con Klipper detenido y el puente USB-CAN presente (`1d50:606f`), solicitar Katapult:
```bash
python3 ~/katapult/scripts/flashtool.py -i can0 -u <UUID_HOST> -r
```
El H743 desaparece temporalmente como USB-CAN y se reenumera como Katapult. Es normal que `can0` desaparezca durante esta fase.

Comprobar:
```bash
lsusb
```
Debe aparecer Katapult (`1d50:6177`). El puerto de serie puede variar; en la prueba fue `/dev/ttyACM0`.

Consultar estado (ajustar puerto):
```bash
python3 ~/katapult/scripts/flashtool.py -d /dev/ttyACM0 -s
```
Verificar `Katapult Connected`, MCU `stm32h743xx` y `Application Start: 0x8020000`.

Programar:
```bash
python3 ~/katapult/scripts/flashtool.py -d /dev/ttyACM0 -f ~/klipper/klipper-h743.bin
```
Esperar `Programming Complete`.

Comprobar retorno del puente:
```bash
lsusb
ip -details link show can0
```
Debe reaparecer `1d50:606f`; `can0` debe estar UP, `ERROR-ACTIVE`, 1 Mbps.

## 6. Arranque y validación final
```bash
sudo systemctl start klipper
systemctl is-active klipper
```
En Mainsail comprobar READY, ambos MCUs conectados, temperaturas y telemetría actualizándose y ausencia de errores de comunicación. Si queda SHUTDOWN, leer el error antes de actuar; puede ser necesario `FIRMWARE_RESTART`.

## 7. Resultado probado
Ambos MCUs quedaron en `v0.13.0-827-g29d4ec2d`; HOST H743 a 400 MHz y TOOLHEAD F103 a 72 MHz. Katapult se conservó; no se reinstaló.

## 8. Recuperación
Si Katapult no aparece, no continuar a ciegas. Si el USB-CAN no vuelve, comprobar enumeración USB, alimentación y logs. Un bootloader dañado puede requerir SWD. No improvisar binarios ni direcciones.

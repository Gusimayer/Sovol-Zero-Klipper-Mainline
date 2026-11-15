# 06 — Actualización manual Mainline → Mainline

Procedimiento realizado el 15-11-2026, cuando ambos MCUs ya tenían Klipper Mainline y Katapult. No es migración OEM.

## Configuración de compilación F103
```text
CONFIG_MCU="stm32f103xe"
CONFIG_CLOCK_FREQ=72000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8002000
CONFIG_STM32_FLASH_START_2000=y
CONFIG_STM32_CLOCK_REF_8M=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```

## Configuración de compilación HOST H743 target
```text
CONFIG_MCU="stm32h743xx"
CONFIG_CLOCK_FREQ=400000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8020000
CONFIG_STM32_FLASH_START_20000=y
CONFIG_STM32_CLOCK_REF_25M=y
CONFIG_STM32_USBCANBUS_PA11_PA12=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```

Se utilizaron archivos independientes de configuración. `make clean` elimina `out/`: guardar cada binario antes de compilar el siguiente.

## TOOLHEAD F103 por CAN
Con Klipper detenido se programó:
```bash
python3 ~/klipper/lib/katapult/flashtool.py -i can0 -u <UUID_TOOLHEAD> -f <klipper-f103.bin>
```
Salida: `Write complete`, `Verification Complete`, `Programming Complete`. Después se recuperó READY mediante `FIRMWARE_RESTART` desde Mainsail.

## HOST H743 por CAN → USB serie
Con Klipper detenido, HOST presente como USB-CAN `1d50:606f`, se solicitó Katapult:
```bash
python3 ~/klipper/lib/katapult/flashtool.py -i can0 -u <UUID_HOST> -r
```
El puente se reenumeró como Katapult `1d50:6177`, MCU `stm32h743xx`, puerto `/dev/ttyACM0` en esa sesión.

Consulta de estado:
```bash
python3 ~/klipper/lib/katapult/flashtool.py -d /dev/ttyACM0 -s
```
Verificación observada: Katapult conectado, protocolo 1.1.0, bloque 64 bytes, `Application Start: 0x8020000`.

Programación:
```bash
python3 ~/klipper/lib/katapult/flashtool.py -d /dev/ttyACM0 -f <klipper-h743.bin>
```
Salida: verificación completa y `Programming Complete`. El HOST volvió a `1d50:606f`; `can0` UP, `ERROR-ACTIVE`, 1 Mbps.

## Resultado
Ambos MCUs quedaron en `v0.13.0-827-g29d4ec2d`; Mainsail mostró HOST y TOOLHEAD conectados y telemetría operativa.

UUID, ruta flashtool y puerto serie dependen de cada instalación. Verificar con `-h`; no asumir `/dev/ttyACM0`.

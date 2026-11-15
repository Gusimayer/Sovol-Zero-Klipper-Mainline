# Estado de referencia — 15-11-2026

| Componente | Resultado |
|---|---|
| Host | Armbian Trixie ARM64 sobre H616 |
| HOST MCU | STM32H743, target de compilación `stm32h743xx` |
| TOOLHEAD MCU | STM32F103xe |
| Klipper HOST | `v0.13.0-827-g29d4ec2d` |
| Klipper TOOLHEAD | `v0.13.0-827-g29d4ec2d` |
| Klipper host | `v0.13.0-827-g29d4ec2d-dirty` |
| CAN | `can0`, `gs_usb`, 1 Mbps |

El sufijo `-dirty` es del repositorio Klipper host con cambios locales/no versionados; no indica que los firmwares MCU estén mal.

## Configuración HOST
```text
CONFIG_MCU="stm32h743xx"
CONFIG_CLOCK_FREQ=400000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8020000
CONFIG_STM32_FLASH_START_20000=y
CONFIG_STM32_CLOCK_REF_25M=y
CONFIG_STM32_USBCANBUS_PA11_PA12=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```
SHA256 del binario de esa sesión: `5a6f9d4d4354b247edc3ba0d0bdb33bc00600eafee3abb9dce923a52e879b273`

## Configuración TOOLHEAD
```text
CONFIG_MCU="stm32f103xe"
CONFIG_CLOCK_FREQ=72000000
CONFIG_FLASH_APPLICATION_ADDRESS=0x8002000
CONFIG_STM32_FLASH_START_2000=y
CONFIG_STM32_CLOCK_REF_8M=y
CONFIG_STM32_CANBUS_PB8_PB9=y
```
SHA256 del binario de esa sesión: `df966915ba70b65edd760e2fe3ac32102075dd24ea9e233121d5c37e29697cb0`

## Katapult
- HOST: `v0.0.1-113-gec59b9b`, protocolo 1.1.0.
- TOOLHEAD: `v0.0.1-115-g3b973a4`, protocolo 1.1.0.

Los UUID reales se omiten de esta documentación pública. Consultar los de cada instalación; no reutilizar los de otra impresora.

## Validación
Mainsail mostró ambos MCUs conectados, HOST a 400 MHz, TOOLHEAD a 72 MHz, temperaturas y telemetría. El puente USB-CAN y `can0` se recuperaron después de actualizar HOST.

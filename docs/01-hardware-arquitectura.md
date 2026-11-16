# 01 — Hardware y arquitectura

## Topología de la unidad documentada

| Capa | Componente | Función |
|---|---|---|
| Host Linux | Allwinner H616, Armbian Trixie | Klipper host, Moonraker y servicios |
| Placa | `H616_JC_3Z_5160_V1.2` | Integra H616 y MCU principal |
| MCU principal | STM32H750 físico; firmware Mainline `stm32h743xx` | Control principal y puente USB-CAN |
| MCU cabezal | STM32F103 | Extrusor, hotend, Eddy LDC1612 y acelerómetro |
| MCU cámara | Auxiliar no detectado durante el trabajo | No incluir hasta diagnosticar |


## USB-CAN
Con Klipper activo, el MCU principal aparece como USB `1d50:606f`; Linux expone `can0` con `gs_usb`. Al solicitar Katapult se reenumera como `1d50:6177`, aparece un puerto serie (en la sesión, `/dev/ttyACM0`) y `can0` desaparece temporalmente. Tras programar y arrancar Klipper, vuelve el USB-CAN.

**PROBADO:** `can0` a 1 Mbps, `ERROR-ACTIVE`, sin errores RX/TX ni bus-off en la comprobación compartida.

## Eddy y sensor bajo cama
Esta unidad no tiene célula de carga/strain gauge bajo la cama. El sensor utilizado es Eddy LDC1612 del cabezal. No aplicar procedimientos que requieran una strain gauge.

Referencia: https://sovol.lexfrei.dev/zero/hardware/architecture/

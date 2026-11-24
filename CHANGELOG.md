# Changelog

## 2026-11-15
- Documentación ampliada de arquitectura, backups, migración OEM→Mainline, Katapult/CAN y Eddy-Only.
- Separación explícita entre migración inicial y actualización Mainline→Mainline.
- Análisis del actualizador Asnajder marcado como no probado.
- Registro de pendientes y evidencia.

## 2026-11-15 — v3
- Añadido capítulo específico de SWD para el STM32F103 del cabezal.
- Incorporados cableado ST-Link V2, identificación OpenOCD, comando de backup ejecutado, tamaño y SHA256 del volcado.
- Añadidos nombres, hashes y parámetros conocidos de los binarios F103.
- Se distingue el volcado SWD acreditado de la secuencia final de escritura, cuya salida completa no aparece en el fragmento de consola recuperado.

## 2026-11-24 — Actualización automática de MCU Mainline
### Añadido
- Script `scripts/update_mcus.sh` para actualizar automáticamente los MCU HOST H743 y TOOLHEAD F103.
- Procedimiento de instalación y ejecución del actualizador.
- Opción de recuperación del HOST H743 desde Katapult USB.
- Comprobaciones de integridad de perfiles y binarios mediante SHA256.

### Validado
- Actualización completa de Klipper HOST y ambos MCU a `v0.14.0-0-gc9559fa0`.
- Programación del TOOLHEAD F103 mediante CAN.
- Programación del HOST H743 mediante Katapult USB.
- Recuperación de USB-CAN y de la interfaz `can0`.
- Verificación de versiones y conexión de ambos MCU desde Mainsail.

### Documentación
- Se incorpora el procedimiento automático Mainline → Mainline.
- Se conserva el procedimiento manual como referencia técnica.

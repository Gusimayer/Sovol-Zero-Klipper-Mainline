# 08 — Registro de decisiones y estado

## Línea temporal
| Fase | Resultado |
|---|---|
| Inspección OEM | H616 + H750 principal + F103 cabezal identificados |
| Backups | Configuración OEM, logs y firmware disponible preservados |
| HOST Katapult | ST-Link V2; USB `1d50:6177` |
| TOOLHEAD | Katapult Mainline CAN y UUID real |
| Mainline | HOST y TOOLHEAD comunicando por CAN |
| Configuración | Traducción progresiva; original preservado |
| Eddy | LDC1612 por I²C software PB10/PB11; calibraciones completadas |
| Z | Homing y repetibilidad probados |
| Eddy-Only | Ruta Rex elegida por ausencia de célula de carga bajo cama |
| 15-11-2026 | HOST y TOOLHEAD actualizados a `v0.13.0-827-g29d4ec2d` |

## Decisiones
- No asumir strain gauge bajo cama.
- No incluir MCU cámara hasta diagnosticarlo.
- No mezclar Rex Eddy-Only y macros Asnajder sin análisis.
- No ejecutar `SET_SCAN_FROM_TAP` ni restablecer offsets por intuición.
- No publicar UUID, IP, logs privados, backups ni secretos.
- Separar migración OEM→Mainline de actualización Mainline→Mainline.

## Pendientes
1. Investigar origen del offset G-code Z `-0.102362` antes de tocar offsets o generar malla.
2. Recuperar el chat/log de la primera programación SWD del F103 para completar los comandos exactos.
3. Revisar el script Asnajder en el commit exacto si se desea actualizar el análisis.
4. Diagnosticar MCU cámara.

Cada nueva prueba debería registrar fecha, revisión de placa, commits, configuración, comando, salida, hash SHA256 y resultado.

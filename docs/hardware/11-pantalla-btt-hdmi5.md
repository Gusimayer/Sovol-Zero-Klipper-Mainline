# 11 — Pantalla táctil BTT HDMI5

## Alcance

Este capítulo recoge la puesta en marcha de la pantalla táctil **BTT HDMI5** utilizada con la Sovol Zero y KlipperScreen sobre Armbian. Separa la configuración de la salida de vídeo de la orientación de las coordenadas táctiles: son dos ajustes distintos y ambos deben quedar correctos.

## Detección de la pantalla

En la instalación trabajada se identificó:

- Salida de vídeo Xorg: `HDMI-1`.
- Resolución: `800×480`.
- Frecuencia observada: aproximadamente `51,31 Hz`.
- La salida aparecía como pantalla principal.
- Dispositivo táctil: `/dev/input/event1`.
- Identificador de dispositivo XInput: `6`.

Los identificadores de XInput y los nombres de `eventN` pueden cambiar después de reiniciar o conectar dispositivos. No se deben asumir como universales.

## Orientación de la imagen

La orientación de la salida HDMI se debe configurar en Xorg, de forma independiente a la matriz del táctil. Durante el trabajo se identificó como ajuste candidato la opción `Rotate` con valor `inverted` para el monitor `HDMI-1`, mediante un archivo de configuración de Xorg.

**Estado de validación:** la necesidad de corregir la orientación de la imagen quedó identificada, pero no conservamos aquí una comprobación final de persistencia tras reinicio. Antes de considerar este ajuste cerrado, comprobar que KlipperScreen arranca con la imagen en posición correcta y que sigue así después de reiniciar Armbian.

## Orientación del táctil

La imagen puede estar bien orientada y, sin embargo, el panel táctil enviar coordenadas invertidas. En la sesión documentada, la matriz de calibración aplicada al dispositivo XInput fue:

```bash
xinput set-prop 6 128 -1 0 1 0 -1 1 0 0 1
```

La matriz aplica una inversión de 180° a las coordenadas. El usuario confirmó que, tras aplicarla, el tacto coincidía correctamente con la imagen.

**Importante:** el identificador `6` y la propiedad `128` corresponden a la sesión concreta. Antes de reutilizar el comando, consulta los dispositivos y propiedades disponibles:

```bash
xinput list
xinput list-props 6
```

La corrección interactiva quedó confirmada; la persistencia mediante un script `fix-touch.sh` o un override de systemd para KlipperScreen se propuso, pero no quedó validada en la sesión recuperada. No se presenta como configuración permanente ya probada.

## Comprobaciones finales

1. Confirmar que Xorg detecta `HDMI-1` a `800×480`.
2. Confirmar que la imagen se muestra derecha.
3. Verificar que los toques coinciden con los controles en las cuatro esquinas y en el centro.
4. Reiniciar KlipperScreen y, después, Armbian para comprobar persistencia.
5. Si cambia el identificador del táctil, volver a localizarlo con `xinput list` antes de aplicar la matriz.

## Referencias

- [KlipperScreen](https://github.com/KlipperScreen/KlipperScreen)
- [X.Org — xinput](https://www.x.org/releases/current/doc/man/man1/xinput.1.xhtml)

---

**Navegación:** [← Índice de hardware](README.md) | [Siguiente: sistema de audio HDMI](12-audio-hdmi.md)

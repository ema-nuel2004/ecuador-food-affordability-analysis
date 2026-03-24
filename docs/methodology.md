# Metodología detallada

## 1. Filosofía del dataset

Este proyecto usa una jerarquía de fuentes:

1. **dato exacto oficial** cuando existe un valor puntual claramente publicado;
2. **serie mensual oficial** cuando el archivo local es completo y legible;
3. **reconstrucción analítica transparente** cuando el bundle local no contiene una serie mensual completa.

## 2. Anclas exactas utilizadas

La CFB de diciembre se fija exactamente con los valores oficiales del INEC para 2015–2025. La serie del SBU se fija exactamente con los valores normativos oficiales para 2015–2025.

## 3. Reconstrucción mensual de la CFB

La trayectoria mensual entre diciembres se interpola mediante una función estacional determinística normalizada a cero en diciembre. Esto garantiza:

- coincidencia exacta con los niveles oficiales de diciembre;
- continuidad temporal;
- una trayectoria mensual razonable para modelado de series de tiempo.

## 4. Deflactor

El script intenta leer el archivo del BCE incluido en `documents/official_sources/bce/`. Si la extracción local es incompleta, el script aplica un fallback reproducible y deja trazabilidad del modo usado.

## 5. Robustez

Se calcula una bandera de outliers sobre la variación mensual de la CFB usando mediana móvil y MAD móvil:

\[
|x_t - \tilde{x}_t| > 5 \cdot MAD_t
\]

La idea no es manipular la serie sino auditarla.

## 6. Forecasting

Se estiman tres modelos:

- `ARIMA()`
- `ETS()`
- `RW(drift)`

La exportación final incluye intervalos al 80% y 95%.

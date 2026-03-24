# Paquete de documentos oficiales para el proyecto Ecuador Food Affordability

Este paquete reúne los documentos oficiales más importantes para rehacer el proyecto con mejor trazabilidad.

## Qué sí quedó incluido físicamente
- **BCE**: series históricas oficiales en Excel para IPC y salarios.
- **Ministerio del Trabajo**: acuerdos ministeriales descargables para SBU 2023, 2024 y 2025, más documentos relacionados que referencian SBU 2021 y 2022 y el ajuste 2020.

## Qué quedó referenciado pero no embebido
Los archivos del **INEC** tienen URL oficial exacta dentro de `MANIFEST_official_documents.csv`, pero el host del INEC bloqueó la descarga automatizada binaria desde este entorno.

Eso significa que el paquete **sí contiene todas las rutas oficiales necesarias**, pero algunos archivos del INEC tendrás que descargarlos manualmente desde esas URLs para tener una carpeta 100% cerrada.

## Archivos del BCE especialmente útiles
- `BCE_IEM_421a_IPC_base_2014.xlsx` → serie IPC base 2014
- `BCE_IEM_422_Salario_Unificado_Componentes.xls` → salario unificado y componentes
- `BCE_IEM_423_SBU_nominal_real_promedio.xls` → salario nominal y real promedio
- `BCE_Cap4_85anios_series_historicas.xls` → series históricas largas, útil para validación cruzada

## Próximo paso recomendado
1. Descargar manualmente los archivos del INEC listados en el manifiesto.
2. Colocarlos en `docs/inec/`.
3. Reapuntar el script del repo para leer primero los archivos INEC y usar BCE/Ministerio como verificación cruzada.

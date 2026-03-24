# 🇪🇨 Dinámica de Asequibilidad Alimentaria y Divergencia Salarial en Ecuador (2015–2025)

<div align="center">

![R](https://img.shields.io/badge/R-4.3%2B-276DC3?style=for-the-badge&logo=r&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Research%20Ready-brightgreen?style=for-the-badge)
![Data](https://img.shields.io/badge/Data-INEC%20%7C%20BCE%20%7C%20MDT-orange?style=for-the-badge)

**Análisis econométrico reproducible sobre costo de vida, salario mínimo y poder adquisitivo real en Ecuador**

</div>

---

## Executive Summary

Este repositorio estudia cómo evolucionó la asequibilidad de la **Canasta Familiar Básica (CFB)** frente al **Salario Básico Unificado (SBU)** en Ecuador entre 2015 y 2025. La lógica central es económica, no solo descriptiva: se comparan series nominales y reales, se mide cobertura salarial, se estima la brecha de asequibilidad y se proyecta el costo de la canasta para 2026 con modelos de series de tiempo del ecosistema `tidyverts`.

La lectura sustantiva es clara. El costo oficial de la CFB pasó de **USD 673,21 en diciembre de 2015** a **USD 819,01 en diciembre de 2025**, mientras que el SBU pasó de **USD 354** a **USD 470** en el mismo período. Con un solo SBU, la cobertura de la canasta siguió siendo estructuralmente insuficiente. Incluso usando un proxy de ingreso del hogar de **1,6 perceptores × SBU**, la cobertura siguió debajo del 100% hacia finales de 2025 bajo el enfoque conservador del proyecto.

En términos sustantivos, el estudio muestra que entre 2015 y 2025 el encarecimiento de la Canasta Familiar Básica en Ecuador superó la capacidad de ajuste del salario mínimo individual, manteniendo una restricción persistente de asequibilidad para los hogares. Aunque el SBU registró incrementos nominales a lo largo del período, dichos ajustes no resultaron suficientes para cerrar de forma plena la brecha frente al costo de la canasta. La evidencia sugiere, por tanto, una mejora parcial en cobertura, pero no una convergencia completa hacia condiciones de asequibilidad plena.

Desde una perspectiva técnica, el proyecto confirma la utilidad de combinar deflactación por IPC, métricas de cobertura e identificación de brechas con modelado de series de tiempo para evaluar bienestar económico de manera más rigurosa que con comparaciones nominales simples. El ejercicio de pronóstico para 2026 refuerza la hipótesis de continuidad en la presión sobre el costo de la canasta, incluso bajo trayectorias inerciales razonables.

---

## Key Findings

- **CFB oficial (diciembre):** USD 673,21 en 2015 → USD 819,01 en 2025.
- **SBU oficial:** USD 354 en 2015 → USD 470 en 2025.
- **Cobertura con 1 SBU en diciembre 2025:**

$$
Coverage^{SBU}_{2025-12}=\frac{470}{819.01}\times 100\approx 57.4\%
$$

- **Cobertura con proxy de hogar (1.6 × SBU) en diciembre 2025:**

$$
Coverage^{HH}_{2025-12}=\frac{1.6\cdot 470}{819.01}\times 100\approx 91.8\%
$$

- **Brecha mensual del proxy de hogar en diciembre 2025:**

$$
Gap^{HH}_{2025-12}=819.01-(1.6\cdot 470)=67.01\;USD
$$

- **Forecast 2026:** el pipeline estima los 12 meses de 2026 con `ARIMA`, `ETS` y `RW(drift)`, exportando intervalos de confianza al 80% y 95%.

---

## Marco Teórico

### 1) Poder adquisitivo real

La deflactación elimina la ilusión monetaria y permite comparar el costo de la canasta en términos reales:

$$
CFB^{real}_t = CFB^{nominal}_t \times \frac{100}{IPC_t}
$$

### 2) Índice de cobertura

Cobertura individual:

$$
Coverage^{SBU}_t = \frac{SBU_t}{CFB_t}\times 100
$$

Cobertura con proxy de hogar:

$$
Coverage^{HH}_t = \frac{1.6\cdot SBU_t}{CFB_t}\times 100
$$

### 3) Brecha de asequibilidad

$$
Gap_t = CFB_t - Y_t
$$

### 4) Ley de Engel (proxy)

El proyecto incluye una aproximación del coeficiente de Engel como proporción del ingreso del hogar que se destinaría a alimentos si se toma 40.2% de la CFB como proxy del gasto alimentario:

$$
Engel_t \approx \frac{0.402\cdot CFB_t}{1.6\cdot SBU_t}
$$

---

## Estructura del proyecto

```text
ecuador-food-affordability-ecuador-2015-2025/
├── R/
│   ├── 01_analysis_main.R
│   └── 02_analysis_report.Rmd
├── data/
│   ├── raw/
│   └── processed/
├── documents/
│   ├── official_sources/
│   │   ├── bce/
│   │   ├── trabajo/
│   │   └── inec_links/
│   └── reference_notes/
├── outputs/
│   ├── figures/
│   └── tables/
├── .gitignore
├── LICENSE
└── README.md
```

---

## Stack Tecnológico

- **R**
- **Wrangling:** `tidyverse`, `janitor`, `lubridate`, `readxl`
- **Forecasting:** `tsibble`, `fable`, `feasts`, `fabletools`
- **Visualización:** `ggplot2`, `patchwork`, `scales`
- **Reporting:** `rmarkdown`, `knitr`

---

## Metodología de datos

### Qué es exacto y oficial

1. **CFB de diciembre 2015–2025**: anclas exactas tomadas de boletines y reportes oficiales de INEC.
2. **SBU 2015–2025**: serie oficial anual, aplicada como escalón desde enero de cada año.
3. **Documentos normativos y de respaldo**: incluidos en `documents/official_sources/` o referenciados mediante enlaces oficiales del INEC.

### Qué es reconstruido

El proyecto **reconstruye la trayectoria mensual completa de la CFB** entre anclas oficiales de diciembre, porque el bundle local no incluye un único archivo mensual limpio y completo del INEC listo para lectura directa. La interpolación intra-anual usa un patrón estacional determinístico y respeta exactamente los niveles de diciembre publicados.

### Qué ocurre con el IPC

El pipeline intenta leer primero el archivo local del BCE (`BCE_IEM_421a_IPC_base_2014.xlsx`). Si detecta una serie mensual suficiente, la usa. Si no, activa un **fallback reproducible** de baja inflación calibrado al régimen ecuatoriano. Esta decisión queda registrada en la variable `data_status`, en `data/processed/cpi_monthly_used_by_pipeline.csv` y en `outputs/executive_summary.txt`. En la versión actual del bundle, el proyecto puede correr en modo fallback sin romper reproducibilidad; por eso el repo no debe presentarse como una ingestión cruda 100% completa del IPC oficial mensual si el summary reporta `fallback_cpi_reconstructed`.

### Nota de honestidad metodológica

Este repo **no vende datos inventados como si fueran extracción cruda oficial**. Hace algo mejor: distingue entre observaciones oficiales exactas y reconstrucciones analíticas necesarias para completar una serie mensual consistente y reproducible.

---

## Fuentes oficiales incluidas en el repo

### INEC
- boletines técnicos IPC y canastas 2015, 2020, 2021, 2022, 2023, 2024 y 2025;
- enlaces oficiales a fichas metodológicas y series históricas del IPC/canastas.

### Banco Central del Ecuador (BCE)
- archivos Excel de IPC base 2014 y series salariales históricas.

### Ministerio del Trabajo
- acuerdos ministeriales relevantes para la fijación del SBU reciente.

---

## Cómo correr el proyecto

```bash
git clone https://github.com/tu-usuario/ecuador-food-affordability-ecuador-2015-2025.git
cd ecuador-food-affordability-ecuador-2015-2025
Rscript R/01_analysis_main.R
```

Para generar el informe:

```bash
Rscript -e "rmarkdown::render('R/02_analysis_report.Rmd', output_dir = 'outputs')"
```

---

## Salidas esperadas

- `data/processed/ecuador_food_affordability_monthly_2015_2025.csv`
- `data/processed/forecast_cfb_2026.csv`
- `outputs/figures/fig_gap_area.png`
- `outputs/figures/fig_nominal_vs_real_facets.png`
- `outputs/figures/fig_coverage_ratio.png`
- `outputs/figures/fig_forecast_2026.png`
- `outputs/executive_summary.txt`

---

## Licencia

MIT

## Autor
**Guido Emanuel Armas Santafé**
**guido.armas.santafe@ubi.pt**

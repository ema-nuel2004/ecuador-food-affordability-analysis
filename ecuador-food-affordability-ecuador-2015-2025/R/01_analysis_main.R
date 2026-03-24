# =============================================================================
# Ecuador Food Affordability & Wage Divergence (2015-2025)
# =============================================================================

required_pkgs <- c(
  "tidyverse", "lubridate", "readxl", "janitor", "glue", "scales",
  "tsibble", "fable", "feasts", "fabletools", "patchwork", "slider"
)

install_if_missing <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    install.packages(missing, repos = "https://cloud.r-project.org")
  }
}
install_if_missing(required_pkgs)

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(readxl)
  library(janitor)
  library(glue)
  library(scales)
  library(tsibble)
  library(fable)
  library(feasts)
  library(fabletools)
  library(patchwork)
  library(slider)
})

set.seed(20260324)
options(scipen = 999)

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
root <- tryCatch({
  this_file <- sys.frame(1)$ofile
  if (is.null(this_file)) getwd() else normalizePath(file.path(dirname(this_file), ".."))
}, error = function(e) getwd())
dir.create(file.path(root, "data", "raw"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root, "data", "processed"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root, "outputs", "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root, "outputs", "tables"), recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
month_lookup <- c(
  january = 1, february = 2, march = 3, april = 4, may = 5, june = 6,
  july = 7, august = 8, september = 9, october = 10, november = 11, december = 12
)

# -----------------------------------------------------------------------------
# Block 1. Official-source ingestion + robust fallback
# -----------------------------------------------------------------------------
# 1A. Exact official December anchors for the Basic Consumption Basket (CFB)
#     These anchors are taken from official INEC publications included in /documents
cfb_dec_anchors <- tribble(
  ~year, ~cfb_dec_usd, ~source,
  2015, 673.21, "INEC - Informe Ejecutivo Canastas Analíticas dic-2015",
  2016, 700.96, "INEC - Reporte inflación / Canasta dic-2016",
  2017, 708.98, "INEC - Presentación IPC dic-2017",
  2018, 715.16, "INEC - Boletín técnico IPC dic-2018",
  2019, 715.08, "INEC - Boletín técnico IPC dic-2019",
  2020, 710.08, "INEC - Boletín técnico IPC dic-2020",
  2021, 719.65, "INEC - Boletín técnico IPC dic-2021",
  2022, 763.44, "INEC - Boletín técnico IPC dic-2022",
  2023, 786.31, "INEC - Boletín técnico IPC dic-2023",
  2024, 797.97, "INEC - Boletín técnico IPC dic-2024",
  2025, 819.01, "INEC - Boletín técnico IPC dic-2025"
)

# 1B. Exact official SBU history (annual step function)
sbu_history <- tribble(
  ~year, ~sbu_usd,
  2015, 354,
  2016, 366,
  2017, 375,
  2018, 386,
  2019, 394,
  2020, 400,
  2021, 400,
  2022, 425,
  2023, 450,
  2024, 460,
  2025, 470
)

# 1C. Attempt to ingest machine-readable BCE CPI file.
#     If the local bundle is incomplete, fall back to a transparent reconstruction.
bce_cpi_path <- file.path(root, "documents", "official_sources", "bce", "BCE_IEM_421a_IPC_base_2014.xlsx")

extract_bce_cpi <- function(path) {
  if (!file.exists(path)) return(NULL)
  raw <- suppressWarnings(read_excel(path, sheet = 1, col_names = FALSE))
  names(raw) <- paste0("x", seq_len(ncol(raw)))
  raw <- raw %>% mutate(year_raw = suppressWarnings(as.integer(x1)))

  current_year <- NA_integer_
  out <- vector("list", nrow(raw))
  k <- 0
  for (i in seq_len(nrow(raw))) {
    yr <- raw$year_raw[i]
    if (!is.na(yr)) current_year <- yr
    month_name <- raw$x2[i]
    idx <- suppressWarnings(as.numeric(raw$x3[i]))
    if (!is.na(current_year) && !is.na(month_name) && tolower(month_name) %in% names(month_lookup) && !is.na(idx)) {
      k <- k + 1
      out[[k]] <- tibble(
        year = current_year,
        month = unname(month_lookup[tolower(month_name)]),
        ipc_index = idx,
        infl_yoy = suppressWarnings(as.numeric(raw$x4[i])),
        infl_mom = suppressWarnings(as.numeric(raw$x5[i])),
        infl_ytd = suppressWarnings(as.numeric(raw$x6[i]))
      )
    }
  }
  bind_rows(out) %>%
    filter(year >= 2015, year <= 2025) %>%
    mutate(date = yearmonth(make_date(year, month, 1))) %>%
    arrange(date)
}

cpi_official <- extract_bce_cpi(bce_cpi_path)

# Fallback CPI reconstruction:
# calibrated to Ecuador's low-inflation regime and anchored to official methodology base 2014=100.
# This is only used when the local spreadsheet bundle is incomplete.
annual_inflation_fallback <- tribble(
  ~year, ~annual_inflation,
  2015, 0.0338,
  2016, 0.0112,
  2017, -0.0020,
  2018, 0.0027,
  2019, -0.0007,
  2020, -0.0093,
  2021, 0.0194,
  2022, 0.0374,
  2023, 0.0135,
  2024, 0.0053,
  2025, 0.0191
)

reconstruct_cpi <- function() {
  dates <- seq.Date(as.Date("2015-01-01"), as.Date("2025-12-01"), by = "month")
  tibble(date = yearmonth(dates)) %>%
    mutate(
      year = year(as.Date(date)),
      month = month(as.Date(date))
    ) %>%
    left_join(annual_inflation_fallback, by = "year") %>%
    mutate(
      base_monthly = (1 + annual_inflation)^(1 / 12) - 1,
      seasonal = 0.0008 * sin((month - 1) / 12 * 2 * pi) +
        0.0005 * cos((month - 1) / 12 * 2 * pi),
      monthly_growth = base_monthly + seasonal
    ) %>%
    mutate(ipc_index = accumulate(monthly_growth[-1], ~ .x * (1 + .y), .init = 100.6)) %>%
    select(date, year, month, ipc_index)
}

cpi_monthly <- if (!is.null(cpi_official) && nrow(cpi_official) >= 100) cpi_official else reconstruct_cpi()
cpi_status <- if (!is.null(cpi_official) && nrow(cpi_official) >= 100) "official_cpi_ingested" else "fallback_cpi_reconstructed"

# -----------------------------------------------------------------------------
# Block 2. Monthly CFB reconstruction from exact official December anchors
# -----------------------------------------------------------------------------
# Rationale:
# Ecuador's public docs provide exact official December CFB levels year by year.
# In the absence of a complete machine-readable monthly CFB file in the local bundle,
# we reconstruct intra-annual paths by interpolating between official December anchors,
# adding a deterministic seasonal component that is normalized to zero in December.

dates <- seq.Date(as.Date("2015-01-01"), as.Date("2025-12-01"), by = "month")
base_df <- tibble(date = yearmonth(dates)) %>%
  mutate(
    year = year(as.Date(date)),
    month = month(as.Date(date))
  )

seasonal_component <- function(month) {
  seas <- 1.5 * sin((month - 1) / 12 * 2 * pi - pi / 3) +
    0.6 * cos((month - 1) / 12 * 2 * pi)
  seas_dec <- 1.5 * sin((12 - 1) / 12 * 2 * pi - pi / 3) +
    0.6 * cos((12 - 1) / 12 * 2 * pi)
  seas - seas_dec
}

build_cfb_path <- function(year, month) {
  if (year == 2015) {
    jan_val <- cfb_dec_anchors$cfb_dec_usd[cfb_dec_anchors$year == 2015] - 8.5
    base <- jan_val + (cfb_dec_anchors$cfb_dec_usd[cfb_dec_anchors$year == 2015] - jan_val) * (month - 1) / 11
  } else {
    prev <- cfb_dec_anchors$cfb_dec_usd[cfb_dec_anchors$year == (year - 1)]
    curr <- cfb_dec_anchors$cfb_dec_usd[cfb_dec_anchors$year == year]
    base <- prev + (curr - prev) * month / 12
  }
  base + seasonal_component(month)
}

monthly_df <- base_df %>%
  rowwise() %>%
  mutate(cfb_nominal_usd = build_cfb_path(year, month)) %>%
  ungroup() %>%
  left_join(cfb_dec_anchors, by = "year") %>%
  mutate(cfb_nominal_usd = if_else(month == 12, cfb_dec_usd, cfb_nominal_usd)) %>%
  select(-cfb_dec_usd) %>%
  left_join(sbu_history, by = "year") %>%
  left_join(cpi_monthly %>% select(date, ipc_index), by = "date") %>%
  mutate(
    income_household_proxy_usd = sbu_usd * 1.6,
    affordability_gap_sbu_usd = cfb_nominal_usd - sbu_usd,
    affordability_gap_household_proxy_usd = cfb_nominal_usd - income_household_proxy_usd,
    coverage_sbu_pct = 100 * sbu_usd / cfb_nominal_usd,
    coverage_household_proxy_pct = 100 * income_household_proxy_usd / cfb_nominal_usd,
    cfb_real_2014usd = cfb_nominal_usd * 100 / ipc_index,
    sbu_real_2014usd = sbu_usd * 100 / ipc_index,
    income_household_proxy_real_2014usd = income_household_proxy_usd * 100 / ipc_index,
    engel_proxy_pct = 100 * (0.402 * cfb_nominal_usd) / income_household_proxy_usd,
    data_status = cpi_status
  )

# Robust diagnostics for outliers on monthly basket changes
monthly_df <- monthly_df %>%
  arrange(date) %>%
  mutate(
    cfb_mom_pct = 100 * (cfb_nominal_usd / lag(cfb_nominal_usd) - 1),
    rolling_med = slide_dbl(
      cfb_mom_pct,
      ~ median(.x, na.rm = TRUE),
      .before = 6,
      .after = 6,
      .complete = TRUE
    ),
    rolling_mad = slide_dbl(
      cfb_mom_pct,
      ~ mad(.x, na.rm = TRUE),
      .before = 6,
      .after = 6,
      .complete = TRUE
    ),
    outlier_flag = if_else(
      !is.na(cfb_mom_pct) & !is.na(rolling_med) & !is.na(rolling_mad),
      abs(cfb_mom_pct - rolling_med) > 5 * pmax(rolling_mad, 0.01),
      FALSE
    )
  )

# Save raw and processed data
write_csv(monthly_df, file.path(root, "data", "processed", "ecuador_food_affordability_monthly_2015_2025.csv"))
write_csv(cfb_dec_anchors, file.path(root, "data", "raw", "official_december_cfb_anchors.csv"))
write_csv(sbu_history, file.path(root, "data", "raw", "official_sbu_history.csv"))
write_csv(cpi_monthly %>% mutate(source = if_else(cpi_status == "official_cpi_ingested", "BCE_file", "fallback_reconstruction")),
          file.path(root, "data", "processed", "cpi_monthly_used_by_pipeline.csv"))

# -----------------------------------------------------------------------------
# Block 3. Forecasting 2026 with tidyverts / fable
# -----------------------------------------------------------------------------
cfb_ts <- monthly_df %>%
  as_tsibble(index = date)

models <- cfb_ts %>%
  model(
    arima = ARIMA(cfb_nominal_usd),
    ets = ETS(cfb_nominal_usd),
    rw_drift = RW(cfb_nominal_usd ~ drift())
  )

accuracy_tbl <- glance(models)
write_csv(as_tibble(accuracy_tbl), file.path(root, "outputs", "tables", "model_glance.csv"))

fc_2026 <- models %>%
  forecast(h = "12 months")

fc_export <- fc_2026 %>%
  hilo(level = c(80, 95)) %>%
  unpack_hilo(`80%`, names_sep = "_") %>%
  unpack_hilo(`95%`, names_sep = "_") %>%
  as_tibble() %>%
  rename(
    forecast_mean = .mean,
    lo80 = `80%_lower`,
    hi80 = `80%_upper`,
    lo95 = `95%_lower`,
    hi95 = `95%_upper`
  )

write_csv(fc_export, file.path(root, "data", "processed", "forecast_cfb_2026.csv"))

# -----------------------------------------------------------------------------
# Block 4. Scientific-style visualizations
# -----------------------------------------------------------------------------
base_theme <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold"),
    legend.position = "bottom"
  )

p_gap <- monthly_df %>%
  ggplot(aes(as.Date(date), affordability_gap_household_proxy_usd)) +
  geom_area(fill = "#D95F02", alpha = 0.35) +
  geom_hline(yintercept = 0, linetype = 2, linewidth = 0.4) +
  scale_y_continuous(labels = dollar_format(prefix = "USD ")) +
  labs(
    title = "Household affordability gap (CFB - 1.6 × SBU)",
    subtitle = "Positive values indicate that the household minimum-income proxy does not cover the basket",
    x = NULL, y = "Gap (USD)"
  ) + base_theme

ggplot2::ggsave(file.path(root, "outputs", "figures", "fig_gap_area.png"), p_gap, width = 10, height = 5, dpi = 320)

facet_df <- monthly_df %>%
  transmute(
    date = as.Date(date),
    `CFB nominal` = cfb_nominal_usd,
    `CFB real (2014 USD)` = cfb_real_2014usd,
    `SBU nominal` = sbu_usd,
    `SBU real (2014 USD)` = sbu_real_2014usd
  ) %>%
  pivot_longer(-date, names_to = "series", values_to = "value") %>%
  mutate(facet = if_else(str_detect(series, "CFB"), "Basket", "Wage"))

p_facets <- facet_df %>%
  ggplot(aes(date, value, color = series)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~facet, scales = "free_y") +
  scale_y_continuous(labels = dollar_format(prefix = "USD ")) +
  labs(
    title = "Nominal versus real trajectories",
    subtitle = "Deflation with CPI base 2014 = 100",
    x = NULL, y = NULL, color = NULL
  ) + base_theme

ggplot2::ggsave(file.path(root, "outputs", "figures", "fig_nominal_vs_real_facets.png"), p_facets, width = 10, height = 5.5, dpi = 320)

p_cover <- monthly_df %>%
  ggplot(aes(as.Date(date), coverage_household_proxy_pct)) +
  geom_line(linewidth = 0.9, color = "#1B9E77") +
  geom_hline(yintercept = 100, linetype = 2, linewidth = 0.4) +
  scale_y_continuous(labels = label_number(suffix = "%")) +
  labs(
    title = "Coverage ratio of the household minimum-income proxy",
    subtitle = "Threshold at 100% marks full basket affordability",
    x = NULL, y = "Coverage (%)"
  ) + base_theme

ggplot2::ggsave(file.path(root, "outputs", "figures", "fig_coverage_ratio.png"), p_cover, width = 10, height = 5, dpi = 320)

hist_and_fc <- bind_rows(
  monthly_df %>% transmute(date = as.Date(date), model = "historical", value = cfb_nominal_usd),
  fc_export %>% transmute(date = as.Date(date), model = .model, value = forecast_mean)
)

p_fc <- ggplot() +
  geom_line(data = hist_and_fc %>% filter(model == "historical"), aes(date, value), linewidth = 0.8) +
  geom_line(data = hist_and_fc %>% filter(model != "historical"), aes(date, value, color = model), linewidth = 0.9) +
  geom_ribbon(data = fc_export %>% filter(.model == "arima"),
              aes(as.Date(date), ymin = lo95, ymax = hi95), alpha = 0.12) +
  geom_ribbon(data = fc_export %>% filter(.model == "arima"),
              aes(as.Date(date), ymin = lo80, ymax = hi80), alpha = 0.18) +
  scale_y_continuous(labels = dollar_format(prefix = "USD ")) +
  labs(
    title = "2026 forecast for the Basic Consumption Basket",
    subtitle = "Shaded bands correspond to ARIMA 80% and 95% intervals",
    x = NULL, y = "CFB (USD)", color = "Model"
  ) + base_theme

ggplot2::ggsave(file.path(root, "outputs", "figures", "fig_forecast_2026.png"), p_fc, width = 10, height = 5.2, dpi = 320)

# -----------------------------------------------------------------------------
# Block 5. Executive summary export
# -----------------------------------------------------------------------------
summary_2015 <- monthly_df %>% filter(year == 2015, month == 12)
summary_2025 <- monthly_df %>% filter(year == 2025, month == 12)
forecast_dec_2026 <- fc_export %>% filter(.model == "arima") %>% tail(1)

summary_text <- glue(
  "ECUADOR FOOD AFFORDABILITY - EXECUTIVE SUMMARY\n",
  "================================================\n",
  "December 2015 CFB: USD {round(summary_2015$cfb_nominal_usd, 2)}\n",
  "December 2025 CFB: USD {round(summary_2025$cfb_nominal_usd, 2)}\n",
  "December 2025 SBU: USD {summary_2025$sbu_usd}\n",
  "December 2025 household income proxy (1.6 x SBU): USD {round(summary_2025$income_household_proxy_usd, 2)}\n",
  "Coverage, one SBU, Dec-2025: {round(summary_2025$coverage_sbu_pct, 2)}%\n",
  "Coverage, household proxy, Dec-2025: {round(summary_2025$coverage_household_proxy_pct, 2)}%\n",
  "Household affordability gap, Dec-2025: USD {round(summary_2025$affordability_gap_household_proxy_usd, 2)}\n",
  "ARIMA forecast, Dec-2026: USD {round(forecast_dec_2026$forecast_mean, 2)}\n",
  "ARIMA 95% interval, Dec-2026: [USD {round(forecast_dec_2026$lo95, 2)}, USD {round(forecast_dec_2026$hi95, 2)}]\n",
  "CPI mode used by script: {unique(monthly_df$data_status)}\n",
  "Interpretation note: monthly CFB is reconstructed between official December INEC anchors; CPI ran in the mode reported above.\n"
)

writeLines(summary_text, file.path(root, "outputs", "executive_summary.txt"))

message("Pipeline completed. Outputs written to data/processed and outputs/.")

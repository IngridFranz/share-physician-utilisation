# Horizontal inequity in specialist and GP utilisation: replication code

This repository contains the Stata code used to reproduce the analyses,
tables, and figures for the manuscript on income-related horizontal inequity
in specialist and general-practitioner (GP) utilisation among adults aged 50
years and older in 27 European countries and Israel using SHARE Wave 9.

## Scope

The public workflow reproduces:

1. validation and standardisation of the restricted analysis input;
2. weighted country-specific probit models and average marginal effects;
3. observed and need-expected Erreygers-corrected concentration indices;
4. horizontal inequity indices;
5. variable-level and grouped decomposition contributions;
6. the 500-replication bootstrap for the specialist-use HI;
7. Benjamini-Hochberg false-discovery-rate adjustment;
8. no-rural sensitivity analyses;
9. the sampling-design availability audit; and
10. publication tables and figures, including the secondary GP decomposition.

The focused manuscript does not include planned hospitalisation or conditional
specialist-contact frequency. Development scripts for those analyses are
therefore not part of this release.

## Data access

SHARE microdata are not distributed with this repository. Researchers must
register with SHARE, accept the conditions of use, and obtain the relevant
Wave 9 files directly from SHARE. See <https://share-eric.eu/data/>.

The workflow starts from a restricted, person-level analysis input containing
five records per respondent, one for each SHARE income implicate. The expected
schema and source-variable mapping are documented in `data/README.md` and
`metadata/variable_dictionary.csv`. No row-level data should be committed to
this repository.

## Software

- Stata 19
- User-written Stata command `conindex`

Install `conindex` once from within Stata:

```stata
ssc install conindex
```

The scripts stop with an informative error if the command is unavailable.

## Configuration

1. Clone or download the repository.
2. Open `code/00_config.do`.
3. Set `SOURCE_ANALYSIS_DATA` to the restricted analysis input.
4. Set `DESIGN_DATA` to the SHARE Wave 9 `gv_weights` file.
5. Set `RUN_BOOTSTRAP` to `0` for a quick technical test or retain `1` for the
   full 500-replication analysis.
6. Optionally set `TEST_COUNTRY` to one SHARE country code for a short test;
   leave it empty for the complete analysis.

Do not replace the repository paths in the analysis scripts. All local paths
are defined in `00_config.do`.

## Running the workflow

Start Stata, change the working directory to the repository root, and run:

```stata
cd "PATH/TO/share-physician-equity-replication"
do "code/00_master.do"
```

The scripts run in this order:

| Script | Purpose |
|---|---|
| `01_prepare_analysis_data.do` | Creates and validates `spec_use` and `gp_use`; validates the restricted input schema |
| `02_main_analysis.do` | Main models, AMEs, ECI/HI point estimates, and decompositions across five implicates |
| `03_bootstrap_specialist_hi.do` | Specialist-use HI bootstrap and MI pooling |
| `04_fdr_adjustment.do` | Benjamini-Hochberg adjustment across 28 countries |
| `05_sensitivity_no_rural.do` | Fixed- and expanded-sample sensitivity analyses |
| `06_sampling_design_audit.do` | Availability of strata and PSU information |
| `07_gp_decomposition_outputs.do` | Secondary GP decomposition table and figure |
| `08_publication_figures.do` | Final manuscript figures |
| `09_verify_outputs.do` | Automated checks of country coverage, outcome names, implicates, and required outputs |

## Main variable names

- `spec_use`: at least one specialist consultation in the previous 12 months
- `gp_use`: at least one GP consultation in the previous 12 months
- `inc_ind_PPP`: PPP-adjusted equivalised annual household income
- `cciw_w9`: calibrated Wave 9 individual cross-sectional weight

The published code does not use the earlier development names ending in
`_entry`.

## Outputs

Machine-readable results are written to `results/`; graphics are written to
run-specific folders under `figures/`; execution logs are written to `logs/`.
The principal workbooks are:

- `results/equity_results.xlsx`
- `results/hi_bootstrap.xlsx`
- `results/hi_fdr.xlsx`
- `results/no_rural_sensitivity.xlsx`
- `results/sampling_design_audit.xlsx`
- `results/gp_decomposition.xlsx`

Intermediate `.dta` and `.csv` outputs are retained to permit independent
checks and alternative presentation of the results.

## Reproducibility boundaries

The repository reproduces the statistical analysis from the restricted merged
analysis input. Because SHARE data access is governed by a user agreement, the
input data cannot be included. The repository does not claim to reproduce the
administrative download process or redistribute merged SHARE modules. The
source-variable mapping is provided so that registered users can construct a
compatible input under their own SHARE licence.

## Citation

Please cite both the accompanying manuscript and this code release. Complete
the placeholder fields in `CITATION.cff` before creating the archived release.
Suggested manuscript wording is provided in `CODE_AND_DATA_AVAILABILITY.md`.
The scope of the completed technical test is documented in `VALIDATION.md`.

## Licence

The code is released under the MIT License. This licence applies to the code
only and does not alter the SHARE conditions of use.


**************************************************************************
* USER CONFIGURATION
* Run Stata from the repository root before executing 00_master.do.
**************************************************************************

version 19

global REPO_ROOT "`c(pwd)'"
global CODE       "$REPO_ROOT/code"
global DATA       "$REPO_ROOT/data"
global RESULTS    "$REPO_ROOT/results"
global FIGURES    "$REPO_ROOT/figures"
global LOGS       "$REPO_ROOT/logs"

foreach d in "$DATA" "$RESULTS" "$FIGURES" "$LOGS" {
    capture mkdir "`d'"
}

* EDIT THESE TWO PATHS. SHARE microdata are not distributed with this
* repository. 
global SOURCE_ANALYSIS_DATA "EDIT/PATH/TO/restricted_share_analysis_input.dta"
global DESIGN_DATA          "EDIT/PATH/TO/sharew9_rel9-0-0_gv_weights.dta"

* Local restricted analysis dataset created by 01_prepare_analysis_data.do.
* This file is excluded from version control by .gitignore and must not be shared.
global ANALYSIS_DATA "$DATA/analysis_data_restricted.dta"

* Computationally bootstrap settings.
global BOOTSTRAP_REPS 500
global BOOTSTRAP_SEED 24082026

* Set to 0 to skip the 500-replication bootstrap during a test run.
global RUN_BOOTSTRAP 1

* Optional technical test: enter one SHARE country code (for example 12 for
* Germany). Leave empty for the complete 28-country analysis.
global TEST_COUNTRY ""


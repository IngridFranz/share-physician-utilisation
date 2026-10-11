**************************************************************************
* MASTER REPLICATION SCRIPT
**************************************************************************

version 19
clear all
set more off

* Start Stata in the repository root:
*   cd "PATH/TO/share-physician-equity-replication"
*   do "code/00_master.do"

capture confirm file "code/00_config.do"
if _rc {
    display as error "Current directory is not the repository root."
    display as error "Change directory to the repository root and run again."
    exit 601
}

do "code/00_config.do"

capture log close _all
log using "$LOGS/replication_run.log", text replace name(replication)

do "$CODE/01_prepare_analysis_data.do"
do "$CODE/02_main_analysis.do"

if $RUN_BOOTSTRAP == 1 {
    do "$CODE/03_bootstrap_specialist_hi.do"
    do "$CODE/04_fdr_adjustment.do"
}
else {
    display as text "Bootstrap and FDR steps skipped by configuration."
}

do "$CODE/05_sensitivity_no_rural.do"
do "$CODE/06_sampling_design_audit.do"
do "$CODE/07_gp_decomposition_outputs.do"

if $RUN_BOOTSTRAP == 1 {
    do "$CODE/08_publication_figures.do"
}
else {
    display as text "Publication figures require bootstrap output and were skipped."
}

do "$CODE/09_verify_outputs.do"

log close replication
display as result "Replication workflow completed."


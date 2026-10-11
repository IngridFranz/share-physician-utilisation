**************************************************************************
* VALIDATE REPLICATION OUTPUTS
*
* Check the completeness and internal consistency of generated results.
**************************************************************************

version 19
clear all
set more off

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}

local expected_countries = cond("$TEST_COUNTRY" == "", 28, 1)

capture confirm file "$RESULTS/summary_MI_pooled.dta"
if _rc {
    display as error "Missing main pooled result file."
    exit 601
}

use "$RESULTS/summary_MI_pooled.dta", clear
assert inlist(outcome,"spec_use","gp_use")
assert status == "OK"
isid country outcome
quietly levelsof country, local(countries)
local n_countries : word count `countries'
assert `n_countries' == `expected_countries'
quietly count
assert r(N) == 2 * `expected_countries'
assert !missing(eci_obs_MI,eci_need_MI,hi_MI)

use "$RESULTS/decomposition_MI_pooled.dta", clear
assert inlist(outcome,"spec_use","gp_use")
assert inlist(determinant_group,"Need","Non-Need")
assert !missing(contribution_MI) if M > 0
quietly levelsof country, local(countries_dec)
local n_countries_dec : word count `countries_dec'
assert `n_countries_dec' == `expected_countries'

use "$RESULTS/sample_by_implicate.dta", clear
assert inrange(implicat,1,5)
assert inlist(outcome,"spec_use","gp_use")
assert inrange(completion_rate,0,1) if !missing(completion_rate)
sort country outcome implicat
by country outcome: assert _N == 5

capture confirm file "$RESULTS/no_rural_sensitivity.xlsx"
assert !_rc
capture confirm file "$RESULTS/sampling_design_audit.xlsx"
assert !_rc
capture confirm file "$RESULTS/gp_decomposition.xlsx"
assert !_rc

if $RUN_BOOTSTRAP == 1 {
    capture confirm file "$RESULTS/HI_bootstrap_MI_pooled.dta"
    assert !_rc
    use "$RESULTS/HI_bootstrap_MI_pooled.dta", clear
    isid country
    quietly count
    assert r(N) == `expected_countries'
    assert !missing(hi_MI,hi_se_MI,hi_l95_MI,hi_u95_MI)

    capture confirm file "$RESULTS/HI_bootstrap_MI_pooled_FDR.dta"
    assert !_rc
}

display as result "Output verification completed successfully."

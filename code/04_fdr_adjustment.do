**************************************************************************
* BENJAMINI-HOCHBERG FDR CORRECTION FOR BOOTSTRAPPED HI RESULTS
*
* Applies BH-FDR separately within each outcome across the 28 country tests.
* Does not alter the original bootstrap results.
**************************************************************************

version 19
clear all
set more off

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}
global OUT "$RESULTS"

local INPUT "$OUT/HI_bootstrap_MI_pooled.dta"
local XLSX  "$OUT/hi_fdr.xlsx"

capture confirm file "`INPUT'"
if _rc {
    display as error "Bootstrap pooled file not found: `INPUT'"
    exit 601
}

use "`INPUT'", clear

foreach v in country outcome hi_MI hi_p_MI hi_l95_MI hi_u95_MI {
    capture confirm variable `v'
    if _rc {
        display as error "Required variable missing: `v'"
        exit 111
    }
}

drop if missing(hi_p_MI)

**************************************************************************
* 1. BENJAMINI-HOCHBERG STEP-UP PROCEDURE WITHIN EACH OUTCOME
**************************************************************************

sort outcome hi_p_MI country
by outcome: generate int n_tests = _N
by outcome: generate int p_rank = _n

generate double bh_critical_value = 0.05*p_rank/n_tests
generate byte bh_pass_raw = hi_p_MI <= bh_critical_value

* Largest rank satisfying p(i) <= i*q/m defines the rejection threshold.
bysort outcome: egen int bh_max_reject_rank = ///
    max(cond(bh_pass_raw==1,p_rank,0))

generate byte reject_fdr_05 = p_rank <= bh_max_reject_rank ///
    & bh_max_reject_rank > 0

* Monotone BH-adjusted p-values: min_{j>=i}(m/j)*p(j), capped at 1.
generate double p_fdr_bh = min(1,hi_p_MI*n_tests/p_rank)
gsort outcome -p_rank
by outcome: replace p_fdr_bh = min(p_fdr_bh,p_fdr_bh[_n-1]) ///
    if _n > 1
sort outcome country

* Bonferroni is retained as a stricter descriptive sensitivity check.
generate double p_bonferroni = min(1,hi_p_MI*n_tests)
generate byte reject_bonferroni_05 = p_bonferroni < 0.05

generate str12 hi_direction = "inconclusive"
replace hi_direction = "pro-rich" if hi_l95_MI > 0 & !missing(hi_l95_MI)
replace hi_direction = "pro-poor" if hi_u95_MI < 0 & !missing(hi_u95_MI)

label variable n_tests "Number of country tests within outcome"
label variable p_rank "Rank of unadjusted HI p-value"
label variable p_fdr_bh "Benjamini-Hochberg adjusted p-value"
label variable reject_fdr_05 "Reject after BH-FDR correction, q=0.05"
label variable p_bonferroni "Bonferroni-adjusted p-value"
label variable reject_bonferroni_05 "Reject after Bonferroni correction"

order country outcome hi_MI hi_l95_MI hi_u95_MI hi_p_MI ///
    p_fdr_bh reject_fdr_05 p_bonferroni reject_bonferroni_05 ///
    hi_direction n_tests p_rank bh_critical_value

sort outcome p_rank

save "$OUT/HI_bootstrap_MI_pooled_FDR.dta", replace
export delimited using "$OUT/HI_bootstrap_MI_pooled_FDR.csv", replace
export excel using "`XLSX'", sheet("HI_FDR") ///
    firstrow(variables) replace

**************************************************************************
* 2. COMPACT OUTCOME-LEVEL SUMMARY
**************************************************************************

preserve
    generate byte reject_unadjusted_05 = hi_p_MI < 0.05

    collapse (count) n_country=country ///
        (sum) n_unadjusted=reject_unadjusted_05 ///
              n_fdr=reject_fdr_05 ///
              n_bonferroni=reject_bonferroni_05, by(outcome)

    list, clean noobs

    save "$OUT/HI_FDR_outcome_summary_v1.dta", replace
    export delimited using "$OUT/HI_FDR_outcome_summary_v1.csv", replace
    export excel using "`XLSX'", sheet("Outcome_summary") ///
        firstrow(variables) sheetreplace
restore

display as result "FDR sensitivity analysis completed."
display as result "Results: `XLSX'"
display as text "Primary reporting should still emphasize estimates and bootstrap CIs."

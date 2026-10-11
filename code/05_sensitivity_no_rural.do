**************************************************************************
* NO-RURAL SENSITIVITY: FIXED VERSUS EXPANDED SAMPLE
* Primary outcome only: specialist consultation.
* Source data and main results are never overwritten.
**************************************************************************

version 19
clear all
set more off

capture which conindex
if _rc {
    display as error "conindex is required. Install once: ssc install conindex"
    exit 111
}

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}
local DATA "$ANALYSIS_DATA"
global OUT "$RESULTS"
local XLSX "$OUT/no_rural_sensitivity.xlsx"

use "`DATA'", clear
isid mergeid implicat

generate byte age_65_74 = agecat == 2 if !missing(agecat)
generate byte age_75_84 = agecat == 3 if !missing(agecat)
generate byte age_85plus = agecat == 4 if !missing(agecat)
generate byte edu_medium = isced3 == 2 if !missing(isced3)
generate byte edu_high = isced3 == 3 if !missing(isced3)
generate byte mar_sepdiv = marital4 == 2 if !missing(marital4)
generate byte mar_widowed = marital4 == 3 if !missing(marital4)
generate byte mar_never = marital4 == 4 if !missing(marital4)
generate byte net_small = network_size3 == 1 if !missing(network_size3)
generate byte net_large = network_size3 == 2 if !missing(network_size3)

local NEED age_65_74 age_75_84 age_85plus female poor_srh pain chronic_any ///
    adl_any iadl_any
local NONNEED_NR edu_medium edu_high limited_healthlit mar_sepdiv ///
    mar_widowed mar_never net_small net_large suppl_ins
local MODEL_NR `NEED' `NONNEED_NR'
local MODEL_FULL `MODEL_NR' rural

quietly levelsof country, local(COUNTRIES)
if "$TEST_COUNTRY" != "" local COUNTRIES $TEST_COUNTRY

tempname P
tempfile RAW
postfile `P' str16 sample_rule int implicat country long N ///
    double eci_obs eci_need hi status_code using `RAW', replace

foreach RULE in fixed expanded {
    forvalues m = 1/5 {
        foreach c of local COUNTRIES {
            preserve
            keep if implicat == `m' & country == `c' & eligible_w9 == 1
            if "`RULE'" == "fixed" {
                egen int __miss = rowmiss(spec_use inc_ind_PPP cciw_w9 `MODEL_FULL')
            }
            else {
                egen int __miss = rowmiss(spec_use inc_ind_PPP cciw_w9 `MODEL_NR')
            }
            keep if __miss == 0 & inc_ind_PPP >= 0 & inc_ind_PPP < . ///
                & cciw_w9 > 0 & cciw_w9 < .
            quietly count
            local NN = r(N)
            local EO = .
            local EN = .
            local HI = .
            local RC = 0

            if `NN' < 100 local RC = 100
            else {
                quietly summarize spec_use, meanonly
                if r(min) == r(max) local RC = 200
                else {
                    capture quietly probit spec_use `MODEL_NR' [pw=cciw_w9], vce(robust)
                    if _rc local RC = _rc
                    else {
                        estimates store FULL_NR
                        generate byte __esample = e(sample)
                        capture quietly conindex spec_use if __esample [pw=cciw_w9], ///
                            rank(inc_ind_PPP) truezero bounded limits(0 1) erreygers
                        if !_rc local EO = r(CI)

                        foreach x of local NONNEED_NR {
                            clonevar __o_`x' = `x'
                            quietly summarize `x' if __esample [aw=cciw_w9], meanonly
                            replace `x' = r(mean) if __esample
                        }
                        estimates restore FULL_NR
                        capture quietly predict double __pneed if __esample, pr
                        if !_rc {
                            capture quietly conindex __pneed if __esample [pw=cciw_w9], ///
                                rank(inc_ind_PPP) truezero bounded limits(0 1) erreygers
                            if !_rc {
                                local EN = r(CI)
                                if !missing(`EO') local HI = `EO'-`EN'
                            }
                        }
                    }
                }
            }
            post `P' ("`RULE'") (`m') (`c') (`NN') (`EO') (`EN') (`HI') (`RC')
            restore
        }
    }
}
postclose `P'

use `RAW', clear
sort sample_rule country implicat
save "$OUT/no_rural_fixed_and_expanded_by_implicate_v1.dta", replace
export delimited using "$OUT/no_rural_fixed_and_expanded_by_implicate_v1.csv", replace

bysort sample_rule country: egen M = count(hi)
bysort sample_rule country: egen N_min = min(N)
bysort sample_rule country: egen N_max = max(N)
bysort sample_rule country: egen eci_obs_MI = mean(eci_obs)
bysort sample_rule country: egen eci_need_MI = mean(eci_need)
bysort sample_rule country: egen hi_MI = mean(hi)
bysort sample_rule country: keep if _n == 1
keep sample_rule country M N_min N_max eci_obs_MI eci_need_MI hi_MI status_code
sort country sample_rule
save "$OUT/no_rural_fixed_and_expanded_MI_pooled_v1.dta", replace
export delimited using "$OUT/no_rural_fixed_and_expanded_MI_pooled_v1.csv", replace
export excel using "`XLSX'", sheet("Pooled_comparison") firstrow(variables) replace

display as result "Fixed- and expanded-sample no-rural sensitivity completed."
display as text "These are point-estimate sensitivities; do not infer significance from them."


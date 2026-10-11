**************************************************************************
* BOOTSTRAP HORIZONTAL INEQUITY (HI) WITH FIVE IMPUTATIONS
* Produces sampling + imputation uncertainty for HI.
**************************************************************************

version 19
clear all
set more off

capture which conindex
if _rc {
    display as error "conindex is required. Install once with: ssc install conindex"
    exit 111
}

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}

* Must match the final ADL/IADL specification used in 02_main_analysis.do.

global OUT "$RESULTS"
local DATA "$ANALYSIS_DATA"
local XLSX "$RESULTS/hi_bootstrap.xlsx"

local REPS $BOOTSTRAP_REPS
local SEED $BOOTSTRAP_SEED

* Primary dependent variable only.
local OUTCOMES spec_use 



**************************************************************************
* 1. PROGRAM RETURNING ONE HI ESTIMATE
**************************************************************************

capture program drop equity_calc_hi
program define equity_calc_hi, rclass
    version 19
    syntax varname(numeric), RANK(varname numeric) WGT(varname numeric) ///
        NEED(varlist numeric) NONNEED(varlist numeric)

    tempvar complete esample pneed
    quietly egen int `complete' = rowmiss(`varlist' `rank' `wgt' `need' `nonneed')
    quietly replace `complete' = `complete' + 1 if `wgt'<=0 | `wgt'>=. ///
        | `rank'<0 | `rank'>=.

    quietly count if `complete'==0
    if r(N)<100 {
        return scalar eci_obs=.
        return scalar eci_need=.
        return scalar hi=.
        return scalar N=r(N)
        exit
    }

    quietly summarize `varlist' if `complete'==0, meanonly
    if r(min)==r(max) {
        return scalar eci_obs=.
        return scalar eci_need=.
        return scalar hi=.
        return scalar N=r(N)
        exit
    }

    capture quietly probit `varlist' `need' `nonneed' ///
        if `complete'==0 [pw=`wgt']
    if _rc {
        return scalar eci_obs=.
        return scalar eci_need=.
        return scalar hi=.
        return scalar N=.
        exit
    }
    estimates store __EQUITY_HI_MODEL

    quietly generate byte `esample'=e(sample)
    quietly count if `esample'
    local NN=r(N)

    capture quietly conindex `varlist' if `esample' [pw=`wgt'], ///
        rank(`rank') truezero bounded limits(0 1) erreygers
    if _rc {
        return scalar eci_obs=.
        return scalar eci_need=.
        return scalar hi=.
        return scalar N=`NN'
        exit
    }
    local OBS=r(CI)

    local j=0
    foreach x of local nonneed {
        local ++j
        tempvar original`j'
        quietly generate double `original`j''=`x'
        quietly summarize `x' if `esample' [aw=`wgt'], meanonly
        quietly replace `x'=r(mean) if `esample'
    }

    * Restore probit because conindex may replace active estimation results.
    estimates restore __EQUITY_HI_MODEL
    capture quietly predict double `pneed' if `esample', pr
    if _rc {
        local k=0
        foreach x of local nonneed {
            local ++k
            quietly replace `x'=`original`k''
        }
        return scalar eci_obs=`OBS'
        return scalar eci_need=.
        return scalar hi=.
        return scalar N=`NN'
        exit
    }

    capture quietly conindex `pneed' if `esample' [pw=`wgt'], ///
        rank(`rank') truezero bounded limits(0 1) erreygers
    if _rc {
        local k=0
        foreach x of local nonneed {
            local ++k
            quietly replace `x'=`original`k''
        }
        return scalar eci_obs=`OBS'
        return scalar eci_need=.
        return scalar hi=.
        return scalar N=`NN'
        exit
    }
    local NEEDCI=r(CI)

    * Restore observed covariates before returning; bootstrap calls must not
    * alter the data passed to the following replication.
    local k=0
    foreach x of local nonneed {
        local ++k
        quietly replace `x'=`original`k''
    }

    return scalar eci_obs=`OBS'
    return scalar eci_need=`NEEDCI'
    return scalar hi=`OBS'-`NEEDCI'
    return scalar N=`NN'
end

**************************************************************************
* 2. LOAD DATA AND CREATE THE IDENTICAL MAIN MODEL
**************************************************************************

use "`DATA'", clear
isid mergeid implicat

generate byte age_65_74 = agecat==2 if !missing(agecat)
generate byte age_75_84 = agecat==3 if !missing(agecat)
generate byte age_85plus = agecat==4 if !missing(agecat)
generate byte edu_medium = isced3==2 if !missing(isced3)
generate byte edu_high = isced3==3 if !missing(isced3)
generate byte mar_sepdiv = marital4==2 if !missing(marital4)
generate byte mar_widowed = marital4==3 if !missing(marital4)
generate byte mar_never = marital4==4 if !missing(marital4)
generate byte net_small = network_size3==1 if !missing(network_size3)
generate byte net_large = network_size3==2 if !missing(network_size3)

local NEED age_65_74 age_75_84 age_85plus female poor_srh pain chronic_any ///
    adl_any iadl_any
local NONNEED edu_medium edu_high limited_healthlit mar_sepdiv mar_widowed ///
    mar_never net_small net_large rural suppl_ins
if `INCLUDE_MIGRATION'==1 local NONNEED `NONNEED' migrant_firstgen
local MODEL `NEED' `NONNEED'

quietly levelsof country, local(COUNTRIES)
if "$TEST_COUNTRY" != "" local COUNTRIES $TEST_COUNTRY

tempname P
tempfile RAW
postfile `P' int implicat int country str20 outcome long N ///
    double hi_point hi_boot_se eci_obs eci_need int reps_requested ///
    str60 status using `RAW', replace

**************************************************************************
* 3. COUNTRY × OUTCOME × IMPLICATE BOOTSTRAP
**************************************************************************

foreach c of local COUNTRIES {
    foreach y of local OUTCOMES {
        forvalues m=1/5 {
            display as result "Bootstrap: country `c', `y', implicate `m'"
            preserve
            keep if country==`c' & implicat==`m' & eligible_w9==1

            egen int __miss=rowmiss(`y' inc_ind_PPP cciw_w9 `MODEL')
            keep if __miss==0 & cciw_w9>0 & cciw_w9<. ///
                & inc_ind_PPP>=0 & inc_ind_PPP<.
            drop __miss

            quietly count
            local NN=r(N)
            local STATUS "OK"
            local Q=.
            local SE=.
            local EO=.
            local EN=.

            if `NN'>=100 {
                quietly equity_calc_hi `y', rank(inc_ind_PPP) wgt(cciw_w9) ///
                    need(`NEED') nonneed(`NONNEED')
                local Q=r(hi)
                local EO=r(eci_obs)
                local EN=r(eci_need)

                capture noisily bootstrap r(hi), reps(`REPS') seed(`=`SEED'+`c'*100+`m'') ///
                    nodots reject(missing(r(hi))): ///
                    equity_calc_hi `y', rank(inc_ind_PPP) wgt(cciw_w9) ///
                        need(`NEED') nonneed(`NONNEED')

                if _rc {
                    local STATUS "Bootstrap failed, rc=`=_rc'"
                }
                else {
                    matrix __V=e(V)
                    local SE=sqrt(__V[1,1])
                }
            }
            else local STATUS "Too few complete observations"

            post `P' (`m') (`c') ("`y'") (`NN') (`Q') (`SE') (`EO') (`EN') ///
                (`REPS') ("`STATUS'")
            restore
        }
    }
}
postclose `P'

**************************************************************************
* 4. SAVE AND RUBIN-POOL HI
**************************************************************************

use `RAW', clear
sort outcome country implicat
save "$OUT/HI_bootstrap_by_implicate.dta", replace
export delimited using "$OUT/HI_bootstrap_by_implicate.csv", replace
export excel using "`XLSX'", sheet("By_implicate") firstrow(variables) replace

generate double within_v=hi_boot_se^2
bysort country outcome: egen M=count(hi_point)
bysort country outcome: egen hi_MI=mean(hi_point)
bysort country outcome: egen W=mean(within_v)
bysort country outcome: egen B=sd(hi_point)
replace B=B^2
generate double total_v=W+(1+1/M)*B
generate double hi_se_MI=sqrt(total_v)
generate double hi_z_MI=hi_MI/hi_se_MI
generate double hi_p_MI=2*normal(-abs(hi_z_MI))
generate double hi_l95_MI=hi_MI-invnormal(.975)*hi_se_MI
generate double hi_u95_MI=hi_MI+invnormal(.975)*hi_se_MI
bysort country outcome: keep if _n==1
keep country outcome M N reps_requested hi_MI hi_se_MI hi_z_MI hi_p_MI ///
    hi_l95_MI hi_u95_MI W B status
sort outcome country
save "$OUT/HI_bootstrap_MI_pooled.dta", replace
export delimited using "$OUT/HI_bootstrap_MI_pooled.csv", replace
export excel using "`XLSX'", sheet("HI_MI_pooled") firstrow(variables) sheetreplace

display as result "Completed bootstrap MI pooling."
display as result "Results: `XLSX'"

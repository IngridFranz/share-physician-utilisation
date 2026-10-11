**************************************************************************
* EQUITY ANALYSIS – SHARE W9 – FIVE INCOME IMPLICATES
* Stata 19
*
* Specialist use 
* GP use         
*
* Main Need: age, sex, SRH, pain, diagnosed chronic condition, ADL, IADL
* Main Non-Need: education, health literacy, marital status,
*                network size, rural residence, supplementary insurance
**************************************************************************

version 19
clear all
set more off

capture which conindex
if _rc {
    display as error "conindex is required. Install once with: ssc install conindex"
    exit 111
}

**************************************************************************
* 0. USER SETTINGS
**************************************************************************

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}


global OUT "$RESULTS"
local DATA "$ANALYSIS_DATA"
local XLSX "$RESULTS/equity_results.xlsx"
local Z95 = invnormal(.975)

* Outcome order reflects the paper hierarchy.
local OUTCOMES spec_use gp_use

**************************************************************************
* 1. LOAD, CHECK, AND CREATE MODEL DUMMIES
**************************************************************************

use "`DATA'", clear
isid mergeid implicat
assert inrange(implicat,1,5)

capture confirm variable mergeid
if _rc {
    display as error "Required identifier missing: mergeid"
    exit 111
}

local REQUIRED implicat country cciw_w9 inc_ind_PPP eligible_w9 ///
    spec_use gp_use agecat female poor_srh pain chronic_any ///
    adl_any iadl_any ///
    isced3 limited_healthlit marital4 network_size3 rural suppl_ins

foreach v of local REQUIRED {
    capture confirm numeric variable `v'
    if _rc {
        display as error "Required numeric variable missing: `v'"
        exit 111
    }
}


* Need indicators; reference age 50-64.
generate byte age_65_74 = agecat == 2 if !missing(agecat)
generate byte age_75_84 = agecat == 3 if !missing(agecat)
generate byte age_85plus = agecat == 4 if !missing(agecat)

* Non-need indicators.
* Education reference: low ISCED 0-2.
generate byte edu_medium = isced3 == 2 if !missing(isced3)
generate byte edu_high   = isced3 == 3 if !missing(isced3)

* Marital reference: married / registered partnership.
generate byte mar_sepdiv  = marital4 == 2 if !missing(marital4)
generate byte mar_widowed = marital4 == 3 if !missing(marital4)
generate byte mar_never   = marital4 == 4 if !missing(marital4)

* Network reference: no named network member.
generate byte net_small = network_size3 == 1 if !missing(network_size3)
generate byte net_large = network_size3 == 2 if !missing(network_size3)

local NEED age_65_74 age_75_84 age_85plus female poor_srh pain chronic_any ///
    adl_any iadl_any
local NONNEED edu_medium edu_high limited_healthlit mar_sepdiv mar_widowed ///
    mar_never net_small net_large rural suppl_ins
local MODEL `NEED' `NONNEED'

* Group labels used in long-format publication files.
foreach x of local NEED {
    char `x'[equity_group] "Need"
}
foreach x of local NONNEED {
    char `x'[equity_group] "Non-Need"
}

**************************************************************************
* 2. RESULT POSTFILES – Implicate-specific
**************************************************************************

tempname P_SUM P_REG P_DEC P_GRP P_SAMP
tempfile F_SUM F_REG F_DEC F_GRP F_SAMP

postfile `P_SUM' int implicat int country str20 outcome long N ///
    double sum_w mean_y eci_obs se_obs eci_need se_need hi ///
    str80 status using `F_SUM', replace

postfile `P_REG' int implicat int country str20 outcome str32 term ///
    str12 determinant_group str12 statistic double estimate se z p l95 u95 ///
    str60 status using `F_REG', replace

postfile `P_DEC' int implicat int country str20 outcome str32 term ///
    str12 determinant_group double mean_x ame ame_se ci_x ci_x_se ///
    gci_x gci_x_se contribution contribution_se percent_eci ///
    str60 status using `F_DEC', replace

postfile `P_GRP' int implicat int country str20 outcome ///
    str20 determinant_group double contribution percent_eci ///
    using `F_GRP', replace

postfile `P_SAMP' int implicat int country str20 outcome ///
    long N_country N_eligible N_complete double completion_rate event_rate ///
    using `F_SAMP', replace

quietly levelsof country, local(COUNTRIES)
if "$TEST_COUNTRY" != "" local COUNTRIES $TEST_COUNTRY

**************************************************************************
* 3. FIVE-IMPLICATE × COUNTRY × OUTCOME LOOP
**************************************************************************

forvalues m = 1/5 {
    display as result "IMPLICATE `m' OF 5"

    foreach c of local COUNTRIES {
        foreach y of local OUTCOMES {

            quietly count if implicat == `m' & country == `c'
            local NCOUNTRY = r(N)

            quietly count if implicat == `m' & country == `c' & eligible_w9 == 1
            local NELIG = r(N)

            tempvar nmiss touse
            quietly egen int `nmiss' = rowmiss(`y' inc_ind_PPP cciw_w9 `MODEL')
            quietly generate byte `touse' = implicat == `m' & country == `c' ///
                & eligible_w9 == 1 & `nmiss' == 0 ///
                & inc_ind_PPP >= 0 & inc_ind_PPP < . ///
                & cciw_w9 > 0 & cciw_w9 < .

            quietly count if `touse'
            local NCOMP = r(N)
            local CRATE = cond(`NELIG'>0,`NCOMP'/`NELIG',.)
            quietly summarize `y' if `touse' [aw=cciw_w9], meanonly
            local ERATE = r(mean)

            post `P_SAMP' (`m') (`c') ("`y'") (`NCOUNTRY') (`NELIG') ///
                (`NCOMP') (`CRATE') (`ERATE')

            local STATUS "OK"
            local SUMW=.
            local MEANY=.
            local EOBS=.
            local SEOBS=.
            local ENEED=.
            local SENEED=.
            local HI=.

            if `NCOMP' < 100 {
                local STATUS "Too few complete observations"
                post `P_SUM' (`m') (`c') ("`y'") (`NCOMP') (`SUMW') ///
                    (`MEANY') (`EOBS') (`SEOBS') (`ENEED') (`SENEED') ///
                    (`HI') ("`STATUS'")
                drop `nmiss' `touse'
                continue
            }

            quietly summarize `y' if `touse', meanonly
            if r(min) == r(max) {
                local STATUS "Outcome has no variation"
                post `P_SUM' (`m') (`c') ("`y'") (`NCOMP') (`SUMW') ///
                    (`MEANY') (`EOBS') (`SEOBS') (`ENEED') (`SENEED') ///
                    (`HI') ("`STATUS'")
                drop `nmiss' `touse'
                continue
            }

            preserve
            quietly keep if `touse'

            quietly summarize cciw_w9, meanonly
            local SUMW = r(sum)
            quietly summarize `y' [aw=cciw_w9], meanonly
            local MEANY = r(mean)

            capture quietly probit `y' `MODEL' [pw=cciw_w9], vce(robust)
            local RCMODEL = _rc

            if `RCMODEL' {
                local STATUS "Weighted probit failed, rc=`RCMODEL'"
            }
            else {
                estimates store FULLMODEL
                generate byte __esample = e(sample)
                quietly count if __esample
                local NMODEL = r(N)

                * Observed Erreygers concentration index.
                capture quietly conindex `y' if __esample [pw=cciw_w9], ///
                    rank(inc_ind_PPP) truezero bounded limits(0 1) erreygers
                if !_rc {
                    local EOBS = r(CI)
                    local SEOBS = r(CIse)
                }
                else local STATUS "Observed ECI failed"

                * Save actual non-need values and fix them at weighted means.
                foreach x of local NONNEED {
                    clonevar __o_`x' = `x'
                    quietly summarize `x' if __esample [aw=cciw_w9], meanonly
                    replace `x' = r(mean) if __esample
                }

                * conindex may replace the active estimation results.
                estimates restore FULLMODEL
                capture quietly predict double __pneed if __esample, pr
                if !_rc {
                    capture quietly conindex __pneed if __esample [pw=cciw_w9], ///
                        rank(inc_ind_PPP) truezero bounded limits(0 1) erreygers
                    if !_rc {
                        local ENEED = r(CI)
                        local SENEED = r(CIse)
                        if !missing(`EOBS') local HI = `EOBS' - `ENEED'
                    }
                    else local STATUS "Need ECI failed"
                }
                else local STATUS "Need prediction failed"

                * Restore observed non-need values.
                foreach x of local NONNEED {
                    replace `x' = __o_`x'
                    drop __o_`x'
                }

                * Coefficients, AMEs, and decomposition contributions.
                local SUM_NEED = 0
                local SUM_NONNEED = 0
                local SUM_ALL = 0

                foreach x of local MODEL {
                    estimates restore FULLMODEL
                    local GROUP : char `x'[equity_group]

                    local B=.
                    local BSE=.
                    capture local B = _b[`x']
                    capture local BSE = _se[`x']
                    local BZ=cond(!missing(`BSE') & `BSE'>0,`B'/`BSE',.)
                    local BP=cond(!missing(`BZ'),2*normal(-abs(`BZ')),.)
                    local BL=cond(!missing(`BSE'),`B'-`Z95'*`BSE',.)
                    local BU=cond(!missing(`BSE'),`B'+`Z95'*`BSE',.)
                    post `P_REG' (`m') (`c') ("`y'") ("`x'") ("`GROUP'") ///
                        ("Probit_b") (`B') (`BSE') (`BZ') (`BP') (`BL') (`BU') ("OK")

                    capture quietly margins, dydx(`x') predict(pr) post
                    local RCAME = _rc
                    local AME=.
                    local AMESE=.
                    local AZ=.
                    local AP=.
                    local AL=.
                    local AU=.
                    local DSTATUS "OK"
                    if `RCAME' {
                        local DSTATUS "AME failed, rc=`RCAME'"
                    }
                    else {
                        capture local AME = _b[`x']
                        capture local AMESE = _se[`x']
                        local AZ=cond(!missing(`AMESE') & `AMESE'>0,`AME'/`AMESE',.)
                        local AP=cond(!missing(`AZ'),2*normal(-abs(`AZ')),.)
                        local AL=cond(!missing(`AMESE'),`AME'-`Z95'*`AMESE',.)
                        local AU=cond(!missing(`AMESE'),`AME'+`Z95'*`AMESE',.)
                    }
                    post `P_REG' (`m') (`c') ("`y'") ("`x'") ("`GROUP'") ///
                        ("AME") (`AME') (`AMESE') (`AZ') (`AP') (`AL') (`AU') ///
                        ("`DSTATUS'")

                    quietly summarize `x' if __esample [aw=cciw_w9], meanonly
                    local MX = r(mean)
                    local CIX=.
                    local CIXSE=.
                    local GCIX=.
                    local GCIXSE=.
                    local CONTR=.
                    local CONTRSE=.
                    local PCT=.

                    if r(min) < r(max) & !missing(`AME') {
                        capture quietly conindex `x' if __esample [pw=cciw_w9], ///
                            rank(inc_ind_PPP) truezero
                        if !_rc {
                            local CIX=r(CI)
                            local CIXSE=r(CIse)
                        }
                        capture quietly conindex `x' if __esample [pw=cciw_w9], ///
                            rank(inc_ind_PPP) truezero generalized
                        if !_rc {
                            local GCIX=r(CI)
                            local GCIXSE=r(CIse)
                            local CONTR=4*`AME'*`GCIX'
                            local CONTRSE=4*sqrt((`GCIX'*`AMESE')^2 + ///
                                (`AME'*`GCIXSE')^2)
                            local SUM_ALL=`SUM_ALL'+`CONTR'
                            if "`GROUP'"=="Need" local SUM_NEED=`SUM_NEED'+`CONTR'
                            if "`GROUP'"=="Non-Need" local SUM_NONNEED=`SUM_NONNEED'+`CONTR'
                            if !missing(`EOBS') & `EOBS'!=0 local PCT=100*`CONTR'/`EOBS'
                        }
                    }

                    post `P_DEC' (`m') (`c') ("`y'") ("`x'") ("`GROUP'") ///
                        (`MX') (`AME') (`AMESE') (`CIX') (`CIXSE') (`GCIX') ///
                        (`GCIXSE') (`CONTR') (`CONTRSE') (`PCT') ("`DSTATUS'")
                }

                local RESID=cond(!missing(`EOBS'),`EOBS'-`SUM_ALL',.)
                local PNEED=cond(!missing(`EOBS') & `EOBS'!=0,100*`SUM_NEED'/`EOBS',.)
                local PNON=cond(!missing(`EOBS') & `EOBS'!=0,100*`SUM_NONNEED'/`EOBS',.)
                local PRES=cond(!missing(`EOBS') & `EOBS'!=0,100*`RESID'/`EOBS',.)
                post `P_GRP' (`m') (`c') ("`y'") ("Need") (`SUM_NEED') (`PNEED')
                post `P_GRP' (`m') (`c') ("`y'") ("Non-Need") (`SUM_NONNEED') (`PNON')
                post `P_GRP' (`m') (`c') ("`y'") ("Residual") (`RESID') (`PRES')
            }

            post `P_SUM' (`m') (`c') ("`y'") (`NCOMP') (`SUMW') (`MEANY') ///
                (`EOBS') (`SEOBS') (`ENEED') (`SENEED') (`HI') ("`STATUS'")

            restore
            drop `nmiss' `touse'
        }
    }
}

postclose `P_SUM'
postclose `P_REG'
postclose `P_DEC'
postclose `P_GRP'
postclose `P_SAMP'

**************************************************************************
* 4. SAVE IMPLICATE-SPECIFIC RESULTS
**************************************************************************

use `F_SUM', clear
sort outcome country implicat
save "$OUT/summary_by_implicate.dta", replace
export delimited using "$OUT/summary_by_implicate.csv", replace

use `F_REG', clear
sort outcome country statistic term implicat
save "$OUT/regression_by_implicate.dta", replace
export delimited using "$OUT/regression_by_implicate.csv", replace

use `F_DEC', clear
sort outcome country determinant_group term implicat
save "$OUT/decomposition_by_implicate.dta", replace
export delimited using "$OUT/decomposition_by_implicate.csv", replace

use `F_GRP', clear
sort outcome country determinant_group implicat
save "$OUT/decomposition_groups_by_implicate.dta", replace
export delimited using "$OUT/decomposition_groups_by_implicate.csv", replace

use `F_SAMP', clear
sort outcome country implicat
save "$OUT/sample_by_implicate.dta", replace
export delimited using "$OUT/sample_by_implicate.csv", replace

**************************************************************************
* 5. RUBIN POOLING: SUMMARY INDICES
**************************************************************************

use "$OUT/summary_by_implicate.dta", clear
generate double vobs = se_obs^2
generate double vneed = se_need^2

bysort country outcome: egen M = count(hi)
bysort country outcome: egen eci_obs_MI = mean(eci_obs)
bysort country outcome: egen eci_need_MI = mean(eci_need)
bysort country outcome: egen hi_MI = mean(hi)
bysort country outcome: egen W_obs = mean(vobs)
bysort country outcome: egen W_need = mean(vneed)
bysort country outcome: egen B_obs = sd(eci_obs)
bysort country outcome: egen B_need = sd(eci_need)
replace B_obs = B_obs^2
replace B_need = B_need^2
generate double se_eci_obs_MI = sqrt(W_obs + (1+1/M)*B_obs)
generate double se_eci_need_MI = sqrt(W_need + (1+1/M)*B_need)
generate double l95_eci_obs_MI = eci_obs_MI - `Z95'*se_eci_obs_MI
generate double u95_eci_obs_MI = eci_obs_MI + `Z95'*se_eci_obs_MI
generate double l95_eci_need_MI = eci_need_MI - `Z95'*se_eci_need_MI
generate double u95_eci_need_MI = eci_need_MI + `Z95'*se_eci_need_MI

* HI confidence intervals require the separate bootstrap script because
* Cov(ECI_observed, ECI_need) is needed; no independence assumption is made.
bysort country outcome: keep if _n==1
keep country outcome M N mean_y eci_obs_MI se_eci_obs_MI l95_eci_obs_MI ///
    u95_eci_obs_MI eci_need_MI se_eci_need_MI l95_eci_need_MI ///
    u95_eci_need_MI hi_MI status
sort outcome country
save "$OUT/summary_MI_pooled.dta", replace
export delimited using "$OUT/summary_MI_pooled.csv", replace
export excel using "`XLSX'", sheet("Summary_MI") firstrow(variables) replace

**************************************************************************
* 6. RUBIN POOLING: REGRESSION / AMEs
**************************************************************************

use "$OUT/regression_by_implicate.dta", clear
generate double within_v = se^2
bysort country outcome statistic term: egen M = count(estimate)
bysort country outcome statistic term: egen estimate_MI = mean(estimate)
bysort country outcome statistic term: egen W = mean(within_v)
bysort country outcome statistic term: egen B = sd(estimate)
replace B = B^2
generate double se_MI = sqrt(W + (1+1/M)*B)
generate double z_MI = estimate_MI/se_MI
generate double p_MI = 2*normal(-abs(z_MI))
generate double l95_MI = estimate_MI-`Z95'*se_MI
generate double u95_MI = estimate_MI+`Z95'*se_MI
bysort country outcome statistic term: keep if _n==1
keep country outcome statistic term determinant_group M estimate_MI se_MI ///
    z_MI p_MI l95_MI u95_MI status
sort outcome country statistic term
save "$OUT/regression_MI_pooled.dta", replace
export delimited using "$OUT/regression_MI_pooled.csv", replace
export excel using "`XLSX'", sheet("Regression_MI") firstrow(variables) sheetreplace

**************************************************************************
* 7. RUBIN POOLING: DETERMINANT CONTRIBUTIONS
**************************************************************************

use "$OUT/decomposition_by_implicate.dta", clear
generate double within_v = contribution_se^2
bysort country outcome term: egen M = count(contribution)
bysort country outcome term: egen contribution_MI = mean(contribution)
bysort country outcome term: egen W = mean(within_v)
bysort country outcome term: egen B = sd(contribution)
replace B = B^2
generate double contribution_se_MI = sqrt(W + (1+1/M)*B)
generate double contribution_l95_MI = contribution_MI-`Z95'*contribution_se_MI
generate double contribution_u95_MI = contribution_MI+`Z95'*contribution_se_MI
bysort country outcome term: egen mean_x_MI = mean(mean_x)
bysort country outcome term: egen ame_MI = mean(ame)
bysort country outcome term: egen ci_x_MI = mean(ci_x)
bysort country outcome term: egen gci_x_MI = mean(gci_x)
bysort country outcome term: keep if _n==1

merge m:1 country outcome using "$OUT/summary_MI_pooled.dta", ///
    keep(master match) nogen keepusing(eci_obs_MI)
generate double percent_eci_MI = 100*contribution_MI/eci_obs_MI ///
    if eci_obs_MI!=0 & !missing(eci_obs_MI)
keep country outcome term determinant_group M mean_x_MI ame_MI ci_x_MI ///
    gci_x_MI contribution_MI contribution_se_MI contribution_l95_MI ///
    contribution_u95_MI percent_eci_MI status
sort outcome country determinant_group term
save "$OUT/decomposition_MI_pooled.dta", replace
export delimited using "$OUT/decomposition_MI_pooled.csv", replace
export excel using "`XLSX'", sheet("Contributions_MI") firstrow(variables) sheetreplace

use "$OUT/decomposition_groups_by_implicate.dta", clear
bysort country outcome determinant_group: egen contribution_MI = mean(contribution)
bysort country outcome determinant_group: keep if _n==1
merge m:1 country outcome using "$OUT/summary_MI_pooled.dta", ///
    keep(master match) nogen keepusing(eci_obs_MI)
generate double percent_eci_MI = 100*contribution_MI/eci_obs_MI ///
    if eci_obs_MI!=0 & !missing(eci_obs_MI)
keep country outcome determinant_group contribution_MI percent_eci_MI
sort outcome country determinant_group
save "$OUT/decomposition_groups_MI_pooled.dta", replace
export delimited using "$OUT/decomposition_groups_MI_pooled.csv", replace
export excel using "`XLSX'", sheet("Contribution_groups") firstrow(variables) sheetreplace

**************************************************************************
* 8. SAMPLE OUTPUT
**************************************************************************

use "$OUT/sample_by_implicate.dta", clear
bysort country outcome: keep if _n==1
sort outcome country
save "$OUT/sample_overview.dta", replace
export delimited using "$OUT/sample_overview.csv", replace
export excel using "`XLSX'", sheet("Samples") firstrow(variables) sheetreplace

display as result "Completed main MI analysis."
display as result "Excel workbook: `XLSX'"
display as result "Machine-readable DTA and CSV files: $OUT"
display as text "Run 03_bootstrap_specialist_hi.do for specialist-use HI confidence intervals."

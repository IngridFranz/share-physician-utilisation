**************************************************************************
* PSU / STRATA AVAILABILITY AUDIT, ALL COUNTRIES
*
* Read-only audit. Source datasets are never overwritten.
* Person counts use implicate 1 because design data do not vary by implicate.
**************************************************************************

version 19
clear all
set more off

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}
local DATA "$ANALYSIS_DATA"
local WEIGHTS "$DESIGN_DATA"
global OUT "$RESULTS"
local XLSX "$OUT/sampling_design_audit.xlsx"

foreach f in DATA WEIGHTS {
    capture confirm file "``f''"
    if _rc {
        display as error "Required file not found: ``f''"
        exit 601
    }
}

**************************************************************************
* 1. Prepare official design variables
**************************************************************************

use "`WEIGHTS'", clear
foreach v in mergeid country subsample stratum1 psu cciw_w9 {
    capture confirm variable `v'
    if _rc {
        display as error "Required gv_weights variable missing: `v'"
        exit 111
    }
}
isid mergeid
keep mergeid country subsample stratum1 stratum2 psu ssu dw_w9 cciw_w9
rename country country_design
rename cciw_w9 cciw_w9_design
tempfile DESIGN
save `DESIGN', replace

**************************************************************************
* 2. Merge without altering the analysis dataset
**************************************************************************

use "`DATA'", clear
isid mergeid implicat
keep if implicat == 1
merge 1:1 mergeid using `DESIGN', generate(merge_design) keep(master match)

assert country == country_design if merge_design == 3
generate double weight_abs_diff = abs(cciw_w9-cciw_w9_design) ///
    if merge_design == 3 & !missing(cciw_w9,cciw_w9_design)

generate byte design_complete = merge_design == 3 ///
    & !missing(subsample) & !missing(stratum1) & !missing(psu)

* Recreate final model indicators.
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

local MODEL age_65_74 age_75_84 age_85plus female poor_srh pain ///
    chronic_any adl_any iadl_any edu_medium edu_high limited_healthlit ///
    mar_sepdiv mar_widowed mar_never net_small net_large rural suppl_ins

egen int miss_spec = rowmiss(spec_use inc_ind_PPP cciw_w9 `MODEL')
generate byte eligible = eligible_w9 == 1
generate byte sample_spec = eligible & miss_spec == 0 ///
    & inc_ind_PPP >= 0 & inc_ind_PPP < . & cciw_w9 > 0 & cciw_w9 < .
generate byte sample_spec_design = sample_spec & design_complete

* IDs are unique across countries, subsamples, strata and PSUs.
egen long stratum_uid = group(country subsample stratum1) if design_complete
egen long psu_uid = group(country subsample stratum1 psu) if design_complete
egen byte tag_psu = tag(country stratum_uid psu_uid) if sample_spec_design
bysort country stratum_uid: egen int n_psu_in_stratum = ///
    total(tag_psu) if sample_spec_design
egen byte tag_stratum = tag(country stratum_uid) if sample_spec_design
generate byte singleton_stratum = tag_stratum == 1 ///
    & n_psu_in_stratum == 1 if sample_spec_design

**************************************************************************
* 3. Country-level audit table
**************************************************************************

tempname P
tempfile AUDIT
postfile `P' int country long N_country N_eligible N_spec_complete ///
    N_design_complete N_spec_design N_strata N_psu N_singleton_strata ///
    double design_retention max_weight_abs_diff using `AUDIT', replace

quietly levelsof country, local(COUNTRIES)
foreach c of local COUNTRIES {
    quietly count if country == `c'
    local NC = r(N)
    quietly count if country == `c' & eligible
    local NE = r(N)
    quietly count if country == `c' & sample_spec
    local NS = r(N)
    quietly count if country == `c' & design_complete
    local ND = r(N)
    quietly count if country == `c' & sample_spec_design
    local NSD = r(N)
    quietly count if country == `c' & tag_stratum == 1
    local NST = r(N)
    quietly count if country == `c' & tag_psu == 1
    local NPSU = r(N)
    quietly count if country == `c' & singleton_stratum == 1
    local NSING = r(N)
    quietly summarize weight_abs_diff if country == `c', meanonly
    local WD = r(max)
    local RET = cond(`NS'>0,`NSD'/`NS',.)
    post `P' (`c') (`NC') (`NE') (`NS') (`ND') (`NSD') ///
        (`NST') (`NPSU') (`NSING') (`RET') (`WD')
}
postclose `P'

use `AUDIT', clear
format design_retention %9.3f
format max_weight_abs_diff %12.6f
sort country
save "$OUT/sampling_design_audit.dta", replace
export delimited using "$OUT/sampling_design_audit.csv", replace
export excel using "`XLSX'", sheet("Country_audit") firstrow(variables) replace

list country N_eligible N_spec_complete N_spec_design design_retention ///
    N_strata N_psu N_singleton_strata, noobs abbreviate(22)

display as result "All-country PSU/strata audit completed."
display as result "Review design_retention and N_singleton_strata before choosing the final VCE."

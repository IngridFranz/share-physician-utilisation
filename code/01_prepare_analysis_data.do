**************************************************************************
* PREPARE THE ANALYSIS INPUT
*
* Standardise dependent-variable names and validate the data structure
* required for the analyses.
**************************************************************************

version 19
clear all
set more off

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}

capture confirm file "$SOURCE_ANALYSIS_DATA"
if _rc {
    display as error "Analysis input not found."
    display as error "Edit SOURCE_ANALYSIS_DATA in code/00_config.do."
    exit 601
}

use "$SOURCE_ANALYSIS_DATA", clear
isid mergeid implicat
assert inrange(implicat,1,5)

* Construct the two dependent variables using the public names.
capture confirm variable spec_use
if _rc {
    foreach v in hc602_ hc877_ {
        capture confirm variable `v'
        if _rc {
            display as error "Cannot construct spec_use; source variable missing: `v'"
            exit 111
        }
    }
    generate byte spec_use = .
    replace spec_use = 0 if hc602_ == 0
    replace spec_use = 0 if hc602_ > 0 & hc602_ < . & hc877_ == 0
    replace spec_use = 1 if hc602_ > 0 & hc602_ < . ///
        & hc877_ >= 1 & hc877_ < .
}

capture confirm variable gp_use
if _rc {
    foreach v in hc602_ hc876_ {
        capture confirm variable `v'
        if _rc {
            display as error "Cannot construct gp_use; source variable missing: `v'"
            exit 111
        }
    }
    generate byte gp_use = .
    replace gp_use = 0 if hc602_ == 0
    replace gp_use = 0 if hc602_ > 0 & hc602_ < . & hc876_ == 0
    replace gp_use = 1 if hc602_ > 0 & hc602_ < . ///
        & hc876_ >= 1 & hc876_ < .
}

label define yesno_public 0 "No" 1 "Yes", replace
label values spec_use gp_use yesno_public
label variable spec_use "At least one specialist consultation in previous 12 months"
label variable gp_use   "At least one GP consultation in previous 12 months"

**************************************************************************
* Construct analysis variables when only their documented source variables
* are present in the merged restricted input.
**************************************************************************

capture confirm variable inc_ind_PPP
if _rc {
    tempvar household_income_eur
    capture confirm variable thinc2
    if !_rc generate double `household_income_eur' = thinc2
    else {
        capture confirm variable hh_income_B
        if _rc {
            display as error "Income source missing: provide thinc2 or hh_income_B."
            exit 111
        }
        generate double `household_income_eur' = hh_income_B
    }
    foreach v in exrate pppc2022 hhsize {
        capture confirm variable `v'
        if _rc {
            display as error "Income conversion variable missing: `v'"
            exit 111
        }
    }
    generate double inc_ind_PPP = ///
        (`household_income_eur' * exrate / pppc2022) / sqrt(hhsize) ///
        if `household_income_eur' >= 0 & `household_income_eur' < . ///
        & exrate > 0 & exrate < . & pppc2022 > 0 & pppc2022 < . ///
        & hhsize > 0 & hhsize < .
    label variable inc_ind_PPP ///
        "PPP-adjusted equivalised annual household income"
}

capture confirm variable agecat
if _rc {
    confirm variable age2022
    generate byte agecat = .
    replace agecat = 1 if inrange(age2022,50,64)
    replace agecat = 2 if inrange(age2022,65,74)
    replace agecat = 3 if inrange(age2022,75,84)
    replace agecat = 4 if age2022 >= 85 & age2022 < .
}

capture confirm variable female
if _rc {
    confirm variable dn042_
    generate byte female = .
    replace female = 0 if dn042_ == 1
    replace female = 1 if dn042_ == 2
}

capture confirm variable poor_srh
if _rc {
    confirm variable ph003_
    generate byte poor_srh = .
    replace poor_srh = 0 if inlist(ph003_,1,2,3)
    replace poor_srh = 1 if inlist(ph003_,4,5)
}

capture confirm variable pain
if _rc {
    confirm variable ph084_
    generate byte pain = .
    replace pain = 1 if ph084_ == 1
    replace pain = 0 if ph084_ == 5
}

capture confirm variable chronic_any
if _rc {
    confirm variable ph006dno
    generate byte chronic_any = .
    replace chronic_any = 1 if ph006dno == 0
    replace chronic_any = 0 if ph006dno == 1
}

capture confirm variable adl_any
if _rc {
    confirm variable adl2
    generate byte adl_any = adl2 if inlist(adl2,0,1)
}

capture confirm variable iadl_any
if _rc {
    confirm variable iadl2
    generate byte iadl_any = iadl2 if inlist(iadl2,0,1)
}

capture confirm variable isced3
if _rc {
    confirm variable isced1997_r
    generate byte isced3 = .
    replace isced3 = 1 if inrange(isced1997_r,0,2)
    replace isced3 = 2 if inrange(isced1997_r,3,4)
    replace isced3 = 3 if inrange(isced1997_r,5,6)
}

capture confirm variable limited_healthlit
if _rc {
    confirm variable hc889_
    generate byte limited_healthlit = .
    replace limited_healthlit = 1 if inlist(hc889_,1,2,3)
    replace limited_healthlit = 0 if inlist(hc889_,4,5)
}

capture confirm variable marital4
if _rc {
    confirm variable marital_status_raw
    generate byte marital4 = .
    replace marital4 = 1 if inlist(marital_status_raw,1,2)
    replace marital4 = 2 if inlist(marital_status_raw,3,5)
    replace marital4 = 3 if marital_status_raw == 6
    replace marital4 = 4 if marital_status_raw == 4
}

capture confirm variable network_size3
if _rc {
    confirm variable network_size_raw
    generate byte network_size3 = .
    replace network_size3 = 0 if network_size_raw == 0
    replace network_size3 = 1 if inrange(network_size_raw,1,2)
    replace network_size3 = 2 if inrange(network_size_raw,3,7)
}

capture confirm variable rural
if _rc {
    capture confirm variable area_residence_raw
    if _rc {
        confirm variable areabldgi
        generate byte area_residence_raw = areabldgi
    }
    generate byte rural = .
    replace rural = 0 if inlist(area_residence_raw,1,2,3)
    replace rural = 1 if inlist(area_residence_raw,4,5)
}

capture confirm variable suppl_ins
if _rc {
    confirm variable hc113_
    generate byte suppl_ins = .
    replace suppl_ins = 1 if hc113_ == 1
    replace suppl_ins = 0 if hc113_ == 5
}

capture confirm variable eligible_w9
if _rc {
    capture confirm variable age2022
    local HAS_AGE = !_rc
    confirm variable cciw_w9
    if `HAS_AGE' generate byte eligible_w9 = age2022 >= 50 & age2022 < . ///
            & cciw_w9 > 0 & cciw_w9 < .
    else generate byte eligible_w9 = !missing(agecat) ///
            & cciw_w9 > 0 & cciw_w9 < .
}

local REQUIRED mergeid implicat country eligible_w9 cciw_w9 inc_ind_PPP ///
    spec_use gp_use agecat female poor_srh pain chronic_any adl_any iadl_any ///
    isced3 limited_healthlit marital4 network_size3 rural suppl_ins

foreach v of local REQUIRED {
    capture confirm variable `v'
    if _rc {
        display as error "Required analysis variable missing: `v'"
        exit 111
    }
}

assert inlist(spec_use,0,1) | missing(spec_use)
assert inlist(gp_use,0,1) | missing(gp_use)
assert cciw_w9 > 0 if eligible_w9 == 1
assert inc_ind_PPP >= 0 if !missing(inc_ind_PPP)

* Non-income person characteristics must not vary across income implicates.
foreach v in country eligible_w9 cciw_w9 spec_use gp_use agecat female ///
    poor_srh pain chronic_any adl_any iadl_any isced3 limited_healthlit ///
    marital4 network_size3 rural suppl_ins {
    bysort mergeid (`v'): assert `v'[1] == `v'[_N] ///
        if !missing(`v'[1],`v'[_N])
}

compress
save "$ANALYSIS_DATA", replace
display as result "Derived analysis data created: $ANALYSIS_DATA"


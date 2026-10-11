**************************************************************************
* GP decomposition: table and figure
*
* Purpose
*   Extract the already estimated MI-pooled decomposition of any GP use,
*   create a variable-level results table, aggregate contributions for a
*   Figure-3-style display, and export figure.
*
* This script does not re-estimate the probit models or decomposition.
* Source: Contributions_MI and Summary_MI in the final analysis workbook.
*
* Stata 19
**************************************************************************

version 19
clear all
set more off

if "$REPO_ROOT" == "" {
    display as error "Run code/00_master.do from the repository root."
    exit 198
}
global MAINOUT "$RESULTS"
global OUTDIR  "$RESULTS"
global FIGOUT  "$FIGURES"

global MAINXLSX "$MAINOUT/equity_results.xlsx"
global OUTXLSX  "$OUTDIR/gp_decomposition.xlsx"

capture confirm file "$MAINXLSX"
if _rc {
    display as error "Required result file not found: $MAINXLSX"
    exit 601
}

**************************************************************************
* Helper: country names
**************************************************************************

capture program drop equity_country_names
program define equity_country_names
    capture drop country_name
    generate str20 country_name = ""
    replace country_name = "Austria"        if country == 11
    replace country_name = "Germany"        if country == 12
    replace country_name = "Sweden"         if country == 13
    replace country_name = "Netherlands"    if country == 14
    replace country_name = "Spain"          if country == 15
    replace country_name = "Italy"          if country == 16
    replace country_name = "France"         if country == 17
    replace country_name = "Denmark"        if country == 18
    replace country_name = "Greece"         if country == 19
    replace country_name = "Switzerland"    if country == 20
    replace country_name = "Belgium"        if country == 23
    replace country_name = "Israel"         if country == 25
    replace country_name = "Czech Republic" if country == 28
    replace country_name = "Poland"         if country == 29
    replace country_name = "Luxembourg"     if country == 31
    replace country_name = "Hungary"        if country == 32
    replace country_name = "Portugal"       if country == 33
    replace country_name = "Slovenia"       if country == 34
    replace country_name = "Estonia"        if country == 35
    replace country_name = "Croatia"        if country == 47
    replace country_name = "Lithuania"      if country == 48
    replace country_name = "Bulgaria"       if country == 51
    replace country_name = "Cyprus"         if country == 53
    replace country_name = "Finland"        if country == 55
    replace country_name = "Latvia"         if country == 57
    replace country_name = "Malta"          if country == 59
    replace country_name = "Romania"        if country == 61
    replace country_name = "Slovakia"       if country == 63
    assert country_name != ""
end

**************************************************************************
* 1. Extract the existing GP variable-level decomposition results
**************************************************************************

import excel using "$MAINXLSX", ///
    sheet("Contributions_MI") firstrow clear

keep if outcome == "gp_use"
quietly levelsof country, local(GP_COUNTRIES)
local N_GP_COUNTRIES : word count `GP_COUNTRIES'
assert _N == `N_GP_COUNTRIES' * 19
equity_country_names

* A pooled contribution is unavailable when the corresponding indicator
* has no variation in the model estimation sample in any implicate.
generate byte constant_in_esample = ///
    missing(contribution_MI) & M == 0 & mean_x_MI == 0 & ame_MI == 0

count if missing(contribution_MI) & constant_in_esample != 1
assert r(N) == 0

generate str80 result_note = ""
replace result_note = ///
    "No variation in estimation sample; contribution not estimable" ///
    if constant_in_esample == 1

* Keep the original missing value in the detailed results table. A separate
* display variable is set to zero only for aggregation and plotting.
generate double contribution_for_figure = contribution_MI
replace contribution_for_figure = 0 if constant_in_esample == 1

generate str36 term_label = term
replace term_label = "Age 65-74 years"           if term == "age_65_74"
replace term_label = "Age 75-84 years"           if term == "age_75_84"
replace term_label = "Age 85 years or older"     if term == "age_85plus"
replace term_label = "Female"                    if term == "female"
replace term_label = "Poor self-assessed health" if term == "poor_srh"
replace term_label = "Pain"                      if term == "pain"
replace term_label = "Chronic condition"         if term == "chronic_any"
replace term_label = "ADL limitation"            if term == "adl_any"
replace term_label = "IADL limitation"           if term == "iadl_any"
replace term_label = "Medium education"          if term == "edu_medium"
replace term_label = "High education"            if term == "edu_high"
replace term_label = "Health literacy"   		if term == "limited_healthlit"
replace term_label = "Separated or divorced"     if term == "mar_sepdiv"
replace term_label = "Widowed"                   if term == "mar_widowed"
replace term_label = "Never married"             if term == "mar_never"
replace term_label = "Small social network"       if term == "net_small"
replace term_label = "Large social network"       if term == "net_large"
replace term_label = "Rural residence"            if term == "rural"
replace term_label = "Supplementary insurance"    if term == "suppl_ins"

generate byte term_order = .
replace term_order = 1  if term == "age_65_74"
replace term_order = 2  if term == "age_75_84"
replace term_order = 3  if term == "age_85plus"
replace term_order = 4  if term == "female"
replace term_order = 5  if term == "poor_srh"
replace term_order = 6  if term == "pain"
replace term_order = 7  if term == "chronic_any"
replace term_order = 8  if term == "adl_any"
replace term_order = 9  if term == "iadl_any"
replace term_order = 10 if term == "edu_medium"
replace term_order = 11 if term == "edu_high"
replace term_order = 12 if term == "limited_healthlit"
replace term_order = 13 if term == "mar_sepdiv"
replace term_order = 14 if term == "mar_widowed"
replace term_order = 15 if term == "mar_never"
replace term_order = 16 if term == "net_small"
replace term_order = 17 if term == "net_large"
replace term_order = 18 if term == "rural"
replace term_order = 19 if term == "suppl_ins"
assert !missing(term_order)

order country country_name outcome determinant_group term term_label ///
    M contribution_MI contribution_se_MI contribution_l95_MI ///
    contribution_u95_MI mean_x_MI ame_MI ci_x_MI gci_x_MI ///
    percent_eci_MI constant_in_esample result_note
sort country term_order

tempfile GP_DETAIL
save `GP_DETAIL'

preserve
keep country country_name outcome determinant_group term term_label ///
    M contribution_MI contribution_se_MI contribution_l95_MI ///
    contribution_u95_MI mean_x_MI ame_MI ci_x_MI gci_x_MI ///
    percent_eci_MI constant_in_esample result_note

export excel using "$OUTXLSX", ///
    sheet("GP_variable_contributions") ///
    firstrow(variables) replace
restore

**************************************************************************
* 2. Create factor-level contributions for the figure
**************************************************************************

generate str12 component = ""
replace component = "need"      if determinant_group == "Need"
replace component = "education" if inlist(term, "edu_medium", "edu_high")
replace component = "healthlit" if term == "limited_healthlit"
replace component = "marital"   if inlist(term, ///
    "mar_sepdiv", "mar_widowed", "mar_never")
replace component = "network"   if inlist(term, "net_small", "net_large")
replace component = "rural"     if term == "rural"
replace component = "insurance" if term == "suppl_ins"
assert component != ""

collapse (sum) contribution_for_figure ///
    (max) constant_in_esample, by(country country_name component)

reshape wide contribution_for_figure constant_in_esample, ///
    i(country country_name) j(component) string

rename contribution_for_figureneed      contribution_need
rename contribution_for_figureeducation contribution_education
rename contribution_for_figurehealthlit contribution_healthlit
rename contribution_for_figuremarital   contribution_marital
rename contribution_for_figurenetwork   contribution_network
rename contribution_for_figurerural     contribution_rural
rename contribution_for_figureinsurance contribution_insurance

egen byte contains_constant_term = rowmax( ///
    constant_in_esampleneed constant_in_esampleeducation ///
    constant_in_esamplehealthlit constant_in_esamplemarital ///
    constant_in_esamplenetwork constant_in_esamplerural ///
    constant_in_esampleinsurance)

drop constant_in_esample*
tempfile GP_FACTORS
save `GP_FACTORS'

**************************************************************************
* 3. Merge observed ECI, need-expected ECI, HI, N, and mean GP use
**************************************************************************

import excel using "$MAINXLSX", sheet("Summary_MI") firstrow clear
keep if outcome == "gp_use"
keep country N mean_y eci_obs_MI eci_need_MI hi_MI
merge 1:1 country using `GP_FACTORS', assert(match) nogen

egen double sum_modelled = rowtotal( ///
    contribution_need contribution_education contribution_healthlit ///
    contribution_marital contribution_network contribution_rural ///
    contribution_insurance)

generate double contribution_residual = eci_obs_MI - sum_modelled
generate double decomposition_check = ///
    sum_modelled + contribution_residual - eci_obs_MI

assert abs(decomposition_check) < 1e-10
drop sum_modelled

order country country_name N mean_y eci_obs_MI eci_need_MI hi_MI ///
    contribution_need contribution_education contribution_healthlit ///
    contribution_marital contribution_network contribution_rural ///
    contribution_insurance contribution_residual ///
    contains_constant_term decomposition_check
sort hi_MI country_name

export excel using "$OUTXLSX", ///
    sheet("GP_factor_contributions") ///
    firstrow(variables) sheetreplace

save "$OUTDIR/gp_factor_contributions.dta", replace
export delimited using ///
    "$OUTDIR/gp_factor_contributions.csv", replace

**************************************************************************
* 4. Figure: Decomposition Contribution for any GP use
**************************************************************************

graph set window fontface "Arial"
graph set print  fontface "Arial"
set scheme s1color

* Colour-blind-safe palette; matches the specialist-use decomposition.
local NAVY       "0 73 110"
local SKYBLUE    "86 180 233"
local GREEN      "0 158 115"
local ORANGE     "230 159 0"
local VERMILLION "213 94 0"
local PURPLE     "204 121 167"

graph hbar (asis) ///
    contribution_need ///
    contribution_education ///
    contribution_healthlit ///
    contribution_marital ///
    contribution_network ///
    contribution_rural ///
    contribution_insurance ///
    contribution_residual, ///
    over(country_name, sort(eci_obs_MI) descending ///
        label(labsize(small))) ///
    stack ///
    bar(1, color("`NAVY'")       lcolor(none)) ///
    bar(2, color("`ORANGE'")     lcolor(none)) ///
    bar(3, color("`GREEN'")      lcolor(none)) ///
    bar(4, color("`PURPLE'")     lcolor(none)) ///
    bar(5, color("`SKYBLUE'")    lcolor(none)) ///
    bar(6, color("`VERMILLION'") lcolor(none)) ///
    bar(7, color(black)           lcolor(none)) ///
    bar(8, color(gs11)            lcolor(none)) ///
    yline(0, lcolor(gs8) lwidth(thin)) ///
    ytitle("Contribution to observed ECI", size(small)) ///
    ylabel(, labsize(small) grid glcolor(gs14) glwidth(thin)) ///
    legend(order(1 "Need" 2 "Education" 3 "Health literacy" ///
        4 "Marital status" 5 "Social network" 6 "Rural residence" ///
        7 "Supplementary insurance" 8 "Residual") ///
        title("GP care use", size(small) color(black)) ///
        cols(2) position(6) ring(1) size(small) ///
        symxsize(5) colgap(3) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(margin(zero) lcolor(none) fcolor(white)) ///
    graphregion(margin(vsmall) lcolor(none) fcolor(white)) ///
    xsize(6.69) ysize(8.7) ///
    name(Figure_GP_decomposition, replace)

graph save Figure_GP_decomposition ///
    "$FIGOUT/Figure_GP_decomposition_v1.gph", replace

graph export "$FIGOUT/Figure_GP_decomposition_v1.pdf", ///
    name(Figure_GP_decomposition) replace

graph export "$FIGOUT/Figure_GP_decomposition_v1.tif", ///
    name(Figure_GP_decomposition) width(2400) replace

graph export "$FIGOUT/Figure_GP_decomposition_v1.png", ///
    name(Figure_GP_decomposition) width(2400) replace

display as result "GP tables saved in: $OUTXLSX"
display as result "GP figure saved in: $FIGOUT"
display as text ///
    "Review rows flagged constant_in_esample in the variable-level table."

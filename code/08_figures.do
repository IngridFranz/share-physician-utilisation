**************************************************************************
* Figures 
* Uses final MI-pooled result files; does not re-estimate models.
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
global FIGOUT  "$FIGURES"


local RUNSTAMP "`c(current_date)'_`c(current_time)'"
local RUNSTAMP : subinstr local RUNSTAMP ":" "", all
local RUNSTAMP : subinstr local RUNSTAMP " " "_", all
global FIGRUN "$FIGOUT/run_`RUNSTAMP'"
capture mkdir "$FIGRUN"

global MAINXLSX "$MAINOUT/equity_results.xlsx"
global BOOTXLSX "$MAINOUT/hi_bootstrap.xlsx"

foreach f in "$MAINXLSX" "$BOOTXLSX" {
    capture confirm file "`f'"
    if _rc {
        display as error "Required result file not found: `f'"
        exit 601
    }
}

**************************************************************************
* Helper: assign country names from numeric SHARE country codes.
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

capture program drop equity_order_labels
program define equity_order_labels
    args ordervar
    if "`ordervar'" == "" {
        display as error "equity_order_labels requires an order variable"
        exit 198
    }
    confirm numeric variable `ordervar'
    capture label drop equity_country_order
    quietly count
    local n = r(N)
    forvalues i = 1/`n' {
        local lbl = country_name[`i']
        label define equity_country_order `i' `"`lbl'"', add
    }
    label values `ordervar' equity_country_order
end

graph set window fontface "Arial"
graph set print  fontface "Arial"
set scheme s1color

* Colour-blind-safe palette derived from Okabe-Ito.
local NAVY       "0 73 110"
local BLUE       "0 114 178"
local SKYBLUE    "86 180 233"
local GREEN      "0 158 115"
local ORANGE     "230 159 0"
local VERMILLION "213 94 0"
local PURPLE     "204 121 167"
local GREY       "80 80 80"
local LIGHTGREY  "170 170 170"

**************************************************************************
* Figure 1. Weighted proportion with any GP or specialist consultation
* One graph only; no panel label and no embedded title.
**************************************************************************

import excel using "$MAINXLSX", sheet("Summary_MI") firstrow clear
keep if inlist(outcome, "gp_use", "spec_use")
keep country outcome mean_y
reshape wide mean_y, i(country) j(outcome) string
rename mean_ygp_use   gp_proportion
rename mean_yspec_use specialist_proportion

equity_country_names
gsort -specialist_proportion country_name
generate int country_order = _n
equity_order_labels country_order

generate double y_gp   = country_order + 0.12
generate double y_spec = country_order - 0.12
label values y_gp   equity_country_order
label values y_spec equity_country_order

twoway ///
    (scatter y_gp gp_proportion, ///
        msymbol(O) msize(small) ///
        mcolor("`NAVY'") mlcolor("`NAVY'")) ///
    (scatter y_spec specialist_proportion, ///
        msymbol(D) msize(small) ///
        mcolor("`VERMILLION'") mlcolor("`VERMILLION'")), ///
    xscale(range(0 1.1)) ///
    xlabel(0(0.2)1, format(%3.1f) labsize(small) ///
        grid glcolor(gs14) glwidth(thin)) ///
    ylabel(1(1)28, valuelabel angle(horizontal) ///
        labsize(small) noticks nogrid) ///
    yscale(reverse range(0.5 28.5)) ///
    xtitle("Weighted proportion with at least one consultation", ///
        size(small)) ///
    ytitle("") ///
    legend(order(1 "GP consultation" 2 "Specialist consultation") rows(1) ///
        position(6) ring(1) size(small) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(margin(zero) lcolor(none) fcolor(white)) ///
    graphregion(margin(vsmall) lcolor(none) fcolor(white)) ///
    xsize(6.69) ysize(8.4) ///
    name(Figure1, replace)

graph save Figure1 "$FIGRUN/Figure1_physician_utilisation.gph", replace
graph export "$FIGRUN/Figure1_physician_utilisation.pdf", ///
    name(Figure1) replace
graph export "$FIGRUN/Figure1_physician_utilisation.tif", ///
    name(Figure1) width(2400) replace
graph export "$FIGRUN/Figure1_physician_utilisation.png", ///
    name(Figure1) width(2400) replace

**************************************************************************
* Figure 2. Specialist-use inequality and horizontal inequity
* Panel A: observed and need-expected ECI.
* Panel B: horizontal inequity index.
* Both panels use the same country order and numerical scale. Germany is
* indicated by black marker borders. The panels are also exported separately.
**************************************************************************

import excel using "$MAINXLSX", sheet("Summary_MI") firstrow clear
keep if outcome == "spec_use"
keep country eci_obs_MI l95_eci_obs_MI u95_eci_obs_MI ///
    eci_need_MI l95_eci_need_MI u95_eci_need_MI hi_MI
tempfile SPECMAIN
save `SPECMAIN'

import excel using "$BOOTXLSX", sheet("HI_MI_pooled") firstrow clear
drop if missing(country)
keep country hi_l95_MI hi_u95_MI
merge 1:1 country using `SPECMAIN', assert(match) nogen

equity_country_names
gsort -hi_MI country_name
generate int country_order = _n
equity_order_labels country_order

* Estimates shown together within a panel lie on the same country line.
generate double y_observed = country_order
generate double y_need     = country_order
generate double y_hi       = country_order
label values y_observed equity_country_order
label values y_need     equity_country_order
label values y_hi       equity_country_order

egen double index_min = rowmin( ///
    l95_eci_obs_MI l95_eci_need_MI hi_l95_MI)
egen double index_max = rowmax( ///
    u95_eci_obs_MI u95_eci_need_MI hi_u95_MI)
quietly summarize index_min, meanonly
local XMIN = floor(r(min) * 10) / 10
quietly summarize index_max, meanonly
local XMAX = ceil(r(max) * 10) / 10
local XMIN = min(`XMIN', -0.1)
local XMAX = max(`XMAX',  0.1)
drop index_min index_max

twoway ///
    (rcap l95_eci_obs_MI u95_eci_obs_MI y_observed, horizontal ///
        lcolor("`GREY'") lwidth(thin)) ///
    (scatter y_observed eci_obs_MI if country != 12, ///
        msymbol(O) msize(small) mcolor("`GREY'") mlcolor("`GREY'")) ///
    (scatter y_observed eci_obs_MI if country == 12, ///
        msymbol(O) msize(medium) mcolor("`GREY'") ///
        mlcolor(black) mlwidth(medthin)) ///
    (rcap l95_eci_need_MI u95_eci_need_MI y_need, horizontal ///
        lcolor("`ORANGE'") lwidth(thin)) ///
    (scatter y_need eci_need_MI if country != 12, ///
        msymbol(T) msize(small) ///
        mcolor("`ORANGE'") mlcolor("`ORANGE'")) ///
    (scatter y_need eci_need_MI if country == 12, ///
        msymbol(T) msize(medium) mcolor("`ORANGE'") ///
        mlcolor(black) mlwidth(medthin)), ///
    xline(0, lcolor(gs8) lpattern(shortdash) lwidth(thin)) ///
    xscale(range(`XMIN' `XMAX')) ///
    xlabel(`XMIN'(0.2)`XMAX', format(%4.1f) labsize(vsmall) ///
        grid glcolor(gs14) glwidth(thin)) ///
    ylabel(1(1)28, valuelabel angle(horizontal) ///
        labsize(vsmall) noticks nogrid) ///
    yscale(reverse range(0.5 28.5)) ///
    xtitle("Erreygers-corrected concentration index", size(vsmall)) ///
    ytitle("") ///
    legend(order(2 "Observed" 5 "Need-expected") ///
        cols(2) position(6) ring(1) size(vsmall) ///
        region(margin(t=4) lcolor(none) fcolor(none))) ///
    plotregion(margin(l=1 r=3 t=0 b=1) ///
        lcolor(none) fcolor(white)) ///
    graphregion(margin(l=3 r=10 t=3 b=10) ///
        lcolor(none) fcolor(white)) ///
    xsize(6.69) ysize(8.6) ///
    name(Figure2A, replace)

twoway ///
    (rcap hi_l95_MI hi_u95_MI y_hi, horizontal ///
        lcolor("`BLUE'") lwidth(thin)) ///
    (scatter y_hi hi_MI if country != 12, ///
        msymbol(D) msize(small) mcolor("`BLUE'") mlcolor("`BLUE'")) ///
    (scatter y_hi hi_MI if country == 12, ///
        msymbol(D) msize(medium) mcolor("`BLUE'") ///
        mlcolor(black) mlwidth(medthin)), ///
    xline(0, lcolor(gs8) lpattern(shortdash) lwidth(thin)) ///
    xscale(range(-0.3 0.62)) ///
    xlabel(-0.2(0.2)0.6, format(%4.1f) labsize(vsmall) ///
        grid glcolor(gs14) glwidth(thin)) ///
    ylabel(none) ///
    yscale(reverse range(0.5 28.5) noline) ///
    xtitle("Horizontal inequity index", size(vsmall)) ///
    ytitle("") ///
    legend(order(2 "Horizontal inequity") ///
        cols(1) position(6) ring(1) size(vsmall) ///
        region(margin(t=4) lcolor(none) fcolor(none))) ///
    plotregion(margin(l=1 r=3 t=0 b=1) ///
        lcolor(none) fcolor(white)) ///
    graphregion(margin(l=3 r=10 t=3 b=10) ///
        lcolor(none) fcolor(white)) ///
    xsize(6.69) ysize(8.6) ///
    name(Figure2B, replace)

* Composite without panel letters or a descriptive title.
* Identical y-axis ranges.
graph combine Figure2A Figure2B, cols(2) imargin(tiny) ///
    graphregion(margin(l=2 r=7 t=2 b=6) ///
        lcolor(none) fcolor(white)) ///
    xsize(6.69) ysize(8.6) name(Figure2, replace)

graph save Figure2A "$FIGRUN/Figure2A_specialist_ECI.gph", replace
graph export "$FIGRUN/Figure2A_specialist_ECI.pdf", ///
    name(Figure2A) replace
graph export "$FIGRUN/Figure2A_specialist_ECI.tif", ///
    name(Figure2A) width(2400) replace
graph export "$FIGRUN/Figure2A_specialist_ECI.png", ///
    name(Figure2A) width(2400) replace

graph save Figure2B "$FIGRUN/Figure2B_specialist_HI.gph", replace
graph export "$FIGRUN/Figure2B_specialist_HI.pdf", ///
    name(Figure2B) replace
graph export "$FIGRUN/Figure2B_specialist_HI.tif", ///
    name(Figure2B) width(2400) replace
graph export "$FIGRUN/Figure2B_specialist_HI.png", ///
    name(Figure2B) width(2400) replace

graph save Figure2 "$FIGRUN/Figure2_specialist_equity.gph", replace
graph export "$FIGRUN/Figure2_specialist_equity.pdf", ///
    name(Figure2) replace
graph export "$FIGRUN/Figure2_specialist_equity.tif", ///
    name(Figure2) width(2400) replace
graph export "$FIGRUN/Figure2_specialist_equity.png", ///
    name(Figure2) width(2400) replace

**************************************************************************
* Figure 3. Decomposition of the observed specialist-use ECI
*
* Need contributions are summed into one component. Non-need contributions
* are shown separately for each conceptual factor. Contributions from the
* categories of education, marital status, and social network are summed
* within their respective factors. The residual closes the decomposition.
**************************************************************************

import excel using "$MAINXLSX", sheet("Contributions_MI") firstrow clear
keep if outcome == "spec_use"
keep country term determinant_group contribution_MI

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
collapse (sum) contribution_MI, by(country component)
reshape wide contribution_MI, i(country) j(component) string

rename contribution_MIneed      contribution_need
rename contribution_MIeducation contribution_education
rename contribution_MIhealthlit contribution_healthlit
rename contribution_MImarital   contribution_marital
rename contribution_MInetwork   contribution_network
rename contribution_MIrural     contribution_rural
rename contribution_MIinsurance contribution_insurance

tempfile DECOMPOSITION
save `DECOMPOSITION'

import excel using "$MAINXLSX", sheet("Summary_MI") firstrow clear
keep if outcome == "spec_use"
keep country eci_obs_MI hi_MI
merge 1:1 country using `DECOMPOSITION', assert(match) nogen

egen double sum_modelled = rowtotal( ///
    contribution_need contribution_education contribution_healthlit ///
    contribution_marital contribution_network contribution_rural ///
    contribution_insurance)
generate double contribution_residual = eci_obs_MI - sum_modelled
drop sum_modelled

assert !missing(contribution_need, contribution_education, ///
    contribution_healthlit, contribution_marital, contribution_network, ///
    contribution_rural, contribution_insurance, contribution_residual)

equity_country_names
gsort -eci_obs_MI country_name

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
    bar(1, color("`SKYBLUE'")    lcolor(none)) ///
    bar(2, color("`ORANGE'")     lcolor(none)) ///
    bar(3, color("`GREEN'")      lcolor(none)) ///
    bar(4, color("`PURPLE'")     lcolor(none)) ///
    bar(5, color("`NAVY'")       lcolor(none)) ///
    bar(6, color("`VERMILLION'") lcolor(none)) ///
    bar(7, color(black)           lcolor(none)) ///
    bar(8, color(gs11)            lcolor(none)) ///
    yline(0, lcolor(gs8) lwidth(thin)) ///
    ytitle("Contribution to observed ECI", size(small)) ///
    ylabel(, labsize(small) grid glcolor(gs14) glwidth(thin)) ///
    legend(order(1 "Need" 2 "Education" 3 "Health literacy" ///
        4 "Marital status" 5 "Social network" 6 "Rural residence" ///
        7 "Supplementary insurance" 8 "Residual") ///
        cols(2) position(6) ring(1) size(vsmall) ///
        symxsize(5) colgap(3) ///
        region(lcolor(none) fcolor(none))) ///
    plotregion(margin(l=1 r=3 t=0 b=0) ///
        lcolor(none) fcolor(white)) ///
    graphregion(margin(l=3 r=12 t=3 b=3) ///
        lcolor(none) fcolor(white)) ///
    xsize(6.69) ysize(8.7) ///
    name(Figure3, replace)

graph save Figure3 "$FIGRUN/Figure3_decomposition_specialist.gph", replace
graph export "$FIGRUN/Figure3_decomposition_specialist.pdf", ///
    name(Figure3) replace
graph export "$FIGRUN/Figure3_decomposition_specialist.tif", ///
    name(Figure3) width(2400) replac
graph export "$FIGRUN/Figure3_decomposition_specialist.png", ///
    name(Figure3) width(2400) replace


display as result "Figures saved in: $FIGRUN"
display as text "Figures contain no embedded titles."

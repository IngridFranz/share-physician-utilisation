# Restricted data input

No SHARE microdata are included in this repository.

`SOURCE_ANALYSIS_DATA` in `code/00_config.do` must point to a Stata dataset
with one observation per `mergeid` and income `implicat`. Each respondent must
therefore appear up to five times. The combination `mergeid implicat` must be
unique and `implicat` must take values 1–5.

The input must contain either the two public dependent variables (`spec_use`
and `gp_use`) or the SHARE source variables `hc602_`, `hc876_`, and `hc877_`
from which they are constructed. It must also contain the model variables
listed in `metadata/variable_dictionary.csv`.

The final analysis input generated locally is named
`data/analysis_data_restricted.dta`. As it contains restricted SHARE microdata,
it is excluded from version control and is not included in the public repository or archived release.

The sampling-design audit additionally requires the official SHARE Wave 9
`gv_weights` dataset, specified as `DESIGN_DATA` in `code/00_config.do`.


/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Append all Nigeria code						          *
 * Date: January 2024                                                            *
 * -------------------------------------------------------------------------------*
*/
clear 

global paths "NGA\GHS10 NGA\GHS12 NGA\GHS15 NGA\GHS18 NGA\GHS23"

**********************************************************
**** A) Harmonize IDs
**********************************************************
 
use "${Temp}\\NGA\GHS10\\hh_frame.dta", clear
gen wave = 1
forvalues wave=2/5{
global temppath: word `wave' of $paths
append using "${Temp}\\${temppath}\\hh_frame.dta", gen(append)
replace wave = `wave' if append==1
drop append
}

gen hh_id_merge = hhid
egen hh_id_obs = group(hhid)
replace hh_id_obs = hh_id_obs + 5000000 

keep hh_id_obs hh_id_merge wave
duplicates drop
save "${Temp}\\NGA\\Frame_hhIDs.dta", replace

use "${Temp}\\NGA\\GHS10\\plot_crop_frame.dta", clear
gen wave = 1
forvalues wave=2/5{
global temppath: word `wave' of $paths
append using "${Temp}\\${temppath}\\plot_crop_frame.dta", gen(append)
replace wave = `wave' if append==1
drop append
}

// cannot track plots
egen plot_id_temp = concat(wave plot_id ), punct("-")
egen plot_id_obs = group(plot_id_temp)
replace plot_id_obs = plot_id_obs + 5000000 
gen plot_id_merge=  plot_id 

drop if cropcode==. | plot_id=="."
sort wave plot_id cropcode, stable
bys plot_id plot_id_obs plot_id_merge  cropcode  wave: replace crop_name = crop_name[1]
duplicates drop
save "${Temp}\\NGA\\Frame_plotcrop.dta", replace

use "${Temp}\\NGA\\GHS10\\indiv_frame.dta", clear
gen wave = 1
forvalues wave=2/5{
global temppath: word `wave' of $paths
append using "${Temp}\\${temppath}\\indiv_frame.dta", gen(append)
replace wave = `wave' if append==1
drop append
}

gen indiv_id_merge = ID
egen indiv_id_obs = group(indiv_id_merge)

gen hh_id_merge = hhid

keep ID indiv_id_obs indiv_id_merge  wave hh_id_merge
duplicates drop
save "${Temp}\\NGA\\Frame_indiv.dta", replace
rename indiv_id_merge respondent_id 
forvalues wave = 1/5 {
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  respondent_id using "${Temp}\\${temppath}\\Respondent_characteristics1.dta", keep(match)
rename respondent_id respondent_id_merge
gen respondent_id_obs = indiv_id_obs
keep hhid  respondent_id_obs respondent_id_merge 
save "${Temp}\\${temppath}\\Respondent_characteristics1_ID.dta", replace
restore
}
rename respondent_id manager_id
forvalues wave = 1/5 {
preserve
global temppath: word `wave' of $paths
keep if wave==`wave'
merge 1:m  manager_id using "${Temp}\\${temppath}\\Manager_characteristics1.dta", keep(match)
rename manager_id manager_id_merge
gen manager_id_obs = indiv_id_obs
keep plot_id  manager_id_obs manager_id_merge 
save "${Temp}\\${temppath}\\Manager_characteristics1_ID.dta", replace
restore
}

use "${Temp}\\NGA\GHS10\\Coords.dta", clear
append using "${Temp}\\NGA\GHS12\\Coords.dta"
append using "${Temp}\\NGA\GHS15\\Coords.dta"
append using "${Temp}\\NGA\GHS18\\Coords.dta"

keep lat_modified lon_modified 
duplicates drop
egen geocoords_id = group(lat_modified lon_modified)
replace geocoords_id = geocoords_id + 5000000
keep lat_modified lon_modified geocoords_id
duplicates drop
save "${Temp}\\NGA\\geocoords_id.dta", replace


use "${Temp}\\NGA\GHS10\\ea_id.dta", clear
gen hh_id_merge = hhid
gen wave =1
append using "${Temp}\\NGA\GHS12\\ea_id.dta", 
replace hh_id_merge = hhid if hh_id_merge==.
replace  wave =2 if wave==.
append using "${Temp}\\NGA\GHS15\\ea_id.dta", 
replace hh_id_merge = hhid if hh_id_merge==.
replace  wave =3 if wave==.
append using "${Temp}\\NGA\GHS18\\ea_id.dta", 
replace hh_id_merge = hhid if hh_id_merge==.
replace  wave =4 if wave==.
append using "${Temp}\\NGA\GHS23\\ea_id.dta", 
replace hh_id_merge = hhid if hh_id_merge==.
replace  wave =5 if wave==.
merge m:1 hh_id_merge wave using "${Temp}\\NGA\\Frame_hhIDs.dta", keep( match) nogen

egen ea_id_obs = group(ea_id)
replace ea_id_obs = ea_id_obs + 5000000
bys hh_id_obs: assert ea_id_obs == ea_id_obs[1] //  error
rename ea_id ea_id_merge

keep hh_id_merge ea_id_obs  ea_id_merge wave
duplicates drop
isid hh_id_merge wave
save "${Temp}\\NGA\\ea_id_obs.dta", replace



**********************************************************
**** B) Create plot-crop datasets
**********************************************************

forvalues wave = 1/5 {
global temppath: word `wave' of $paths

use "${Temp}\\${temppath}\\plot_crop_frame.dta", clear
duplicates drop
merge m:1 hhid using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
if `wave'< 5 {
merge m:1 hhid  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NGA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\harvest_kg.dta", keep(master match) nogen
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\harvest_value.dta", keep(master match) nogen
drop main_crop // added later
if `wave' > 2 {
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\harvest_end_month.dta", keep(master match) nogen
}
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\planting_month.dta", keep(master match) nogen
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\seed_kg_merge.dta", keep(master match) nogen
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\seed_value.dta" , keep(master match) nogen
if `wave' >2 {
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\improved.dta" , keep(master match) nogen
}
merge m:1 plot_id  using "${Temp}\\${temppath}\\used_pesticides.dta", keep(master match) nogen
merge 1:1 plot_id cropcode using "${Temp}\\${temppath}\\crop_shock.dta", keep(master match) nogen

gen wave = `wave'


define_labels


// harmonise IDS
gen hh_id_merge = hhid
merge m:1 hh_id_merge wave using "${Temp}\\NGA\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\NGA\\ea_id_obs.dta", keep(master match) nogen
merge 1:1 plot_id cropcode wave using "${Temp}\\NGA\\Frame_plotcrop.dta", keep(master match) nogen

rename cropcode crop_code

preserve
foreach var in  harvest_sold_kg hhid  {
capture drop `var'
}  
tostring hh_id_merge, replace
save "${Final}\\NGA_FINAL_plotcrop`wave'.dta", replace
restore


**********************************************************
**** C) Create plot datasets
**********************************************************


if `wave'>2  {
	local improved improved
}

collapse (sum) harvest_kg harvest_value  seed_kg  seed_value (count) n_harvest_kg = harvest_kg n_harvest_value=harvest_value n_seed_kg = seed_kg  n_seed_value =seed_value (max) `improved' used_pesticides *_shock , by(plot_id ea_id_obs ea_id_merge  pw strataid admin_1 admin_1_name admin_2  admin_3   wave plot_id_obs plot_id_merge hh_id_obs hh_id_merge )

foreach var in  harvest_kg harvest_value seed_kg  seed_value {
	replace `var' = . if n_`var'==0
}



merge 1:1 plot_id  using "${Temp}\\${temppath}\\intercropped.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\nb_seasonal_crop.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\main_crop.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\plot_area.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\labor_days.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\inorganic_fertilizer.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\organic_fertilizer.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics1.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics1_ID.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\Manager_characteristics2.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\Respondent_characteristics1.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\Respondent_characteristics1_ID.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\Resp_characteristics2.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\irrigated.dta", keep(master match) nogen
if `wave'>2 {
merge 1:1 plot_id  using "${Temp}\\${temppath}\\erosion_protection.dta", keep(master match) nogen
}
merge m:1 hhid  using "${Temp}\\${temppath}\\tractor.dta", keep(master match) nogen
merge m:1 plot_id   using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\livestock.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\harvest_interview_month.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\planting_interview_month.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
if `wave'< 5 {
merge m:1 hhid  using "${Temp}\\${temppath}\\ag_asset_index.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\aez.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\dist_popcenter.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\dist_market.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\elevation.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\twi.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\soil.dta", keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NGA\\geocoords_id.dta", keep(master match) nogen
merge m:1 plot_id  using "${Temp}\\${temppath}\\plot_slope.dta", keep(master match) nogen
if `wave' >3 {
merge m:1 hhid  using "${Temp}\\${temppath}\\popdensity.dta", keep(master match) nogen	
}
}
// calculate yields
gen yield_kg = harvest_kg/plot_area_GPS
gen yield_value = harvest_value/plot_area_GPS

// harmonise IDS
tostring hh_id_merge, replace
foreach var in  UREA_kg NPK_kg other_kg n_nitrogen_kg n_NPK_kg n_UREA_kg n_other_kg dist_popcenter2 dist_market2  harvest_sold_kg  n_harvest_kg n_harvest_value n_seed_value n_seed_kg manager_id respondent_id ID_worker* hhid {
capture drop `var'
}  
order hh_id_merge hh_id_obs plot_id_obs plot_id_merge


define_labels

save "${Final}\\NGA_FINAL_plotw`wave'.dta", replace
}

**********************************************************
**** D) Create household datasets
**********************************************************


forvalues wave = 1/5 {
global temppath: word `wave' of $paths

use "${Temp}\\${temppath}\\hh_frame.dta", clear
gen wave = `wave'

merge 1:1 hhid using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
if `wave'< 5 {
merge 1:1 hhid using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NGA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_primary_education.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_electricity_access.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_dependency_ratio.dta", keep(master match) nogen
if `wave'< 5 {
merge 1:1 hhid using "${Temp}\\${temppath}\\cons_quint.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\totcons.dta", keep(master match) nogen
}
merge 1:1 hhid using "${Temp}\\${temppath}\\shock.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 hhid using "${Temp}\\${temppath}\\size.dta", keep(master match) nogen
merge 1:1 hhid  using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 hhid  using "${Temp}\\${temppath}\\nfe.dta", keep(master match) nogen
merge 1:1 hhid  using "${Temp}\\${temppath}\\HDDS.dta", keep(master match) nogen
merge 1:1 hhid  using "${Temp}\\${temppath}\\nb_fallow_plots.dta", keep(master match) nogen
merge 1:1 hhid   using "${Temp}\\${temppath}\\nb_plots.dta", keep(master match) nogen
merge 1:1 hhid  using "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", keep(master match) nogen

// harmonise IDS
gen hh_id_merge = hhid

merge m:1 hh_id_merge wave using "${Temp}\\NGA\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\NGA\\ea_id_obs.dta", keep(master match) nogen
foreach var in hhid {
capture drop `var'
} 
define_labels
tostring hh_id_merge, replace
order hh_id_merge hh_id_obs 
save "${Final}\\NGA_FINAL_hhw`wave'.dta", replace
}

**********************************************************
**** E) Create individual level datasets
**********************************************************


forvalues wave = 1/5 {
global temppath: word `wave' of $paths

use "${Temp}\\${temppath}\\indiv_frame.dta", clear
merge m:1 hhid using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 hhid using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
if `wave'< 5 {
merge m:1 hhid  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\NGA\\geocoords_id.dta", keep(master match) nogen
}
merge 1:1 hhid ID using "${Temp}\\${temppath}\\indiv_chars.dta", keep(master match) nogen
merge 1:1 hhid ID using "${Temp}\\${temppath}\\wasting.dta", keep(master match) nogen
merge 1:1 hhid ID using "${Temp}\\${temppath}\\labor.dta", keep(master match) nogen
merge 1:1 hhid ID using "${Temp}\\${temppath}\\educ_indiv.dta", keep(master match) nogen

gen wave = `wave'
define_labels

gen hh_id_merge = hhid

gen indiv_id_merge = ID
merge m:1 hh_id_merge wave using "${Temp}\\NGA\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 indiv_id_merge wave using "${Temp}\\NGA\\Frame_indiv.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\NGA\\ea_id_obs.dta", keep(master match) nogen
foreach var in birth_month hhid {
capture drop `var'
} 
tostring hh_id_merge, replace
order hh_id_merge hh_id_obs indiv_id_merge indiv_id_obs 
save "${Final}\\NGA_FINAL_indivw`wave'.dta", replace
}


**********************************************************
**** F) Append all
**********************************************************


use "${Final}\\NGA_FINAL_plotcrop1.dta",  clear
append using "${Final}\\NGA_FINAL_plotcrop2.dta",
append using "${Final}\\NGA_FINAL_plotcrop3.dta",
append using "${Final}\\NGA_FINAL_plotcrop4.dta",
append using "${Final}\\NGA_FINAL_plotcrop5.dta",
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
 
save "${Final}\\NGA_FINAL_plotcrop.dta", replace


use "${Final}\\NGA_FINAL_plotw1.dta",  clear
append using "${Final}\\NGA_FINAL_plotw2.dta",
append using "${Final}\\NGA_FINAL_plotw3.dta",
append using "${Final}\\NGA_FINAL_plotw4.dta", 
append using "${Final}\\NGA_FINAL_plotw5.dta", 
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
 
save "${Final}\\NGA_FINAL_plot.dta", replace


use "${Final}\\NGA_FINAL_hhw1.dta",  clear
append using "${Final}\\NGA_FINAL_hhw2.dta",
append using "${Final}\\NGA_FINAL_hhw3.dta",
append using "${Final}\\NGA_FINAL_hhw4.dta",
append using "${Final}\\NGA_FINAL_hhw5.dta",
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
 
save "${Final}\\NGA_FINAL_hh.dta", replace

use "${Final}\\NGA_FINAL_indivw1.dta",  clear
append using "${Final}\\NGA_FINAL_indivw2.dta",
append using "${Final}\\NGA_FINAL_indivw3.dta",
append using "${Final}\\NGA_FINAL_indivw4.dta",
append using "${Final}\\NGA_FINAL_indivw5.dta",
tostring ea_id_merge, replace
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]
 
save "${Final}\\NGA_FINAL_indiv.dta", replace



**********************************************************
**** G) Create variables for USD values
**********************************************************

wbopendata, language(en - English) country(USA) topics() indicator(FP.CPI.TOTL) clear long
keep year fp_cpi_totl
gen fp_cpi_totl_2020_line = fp_cpi_totl if year==2020
egen fp_cpi_totl_2020 = max(fp_cpi_totl_2020_line)
gen deflator = fp_cpi_totl/fp_cpi_totl_2020
keep deflator year
tempfile deflator
save `deflator', replace

wbopendata, language(en - English) country(NGA) topics() indicator(PA.NUS.ATLS) clear long
keep pa_nus_atls year
merge 1:1 year using `deflator', nogen
gen wave = 1 if year == 2010
replace wave = 2 if year == 2012
replace wave = 3 if year == 2015
replace wave = 4 if year == 2018
replace wave = 5 if year == 2023
drop if wave==. 

merge 1:m wave using "${Final}\\NGA_FINAL_plot.dta", nogen

foreach var in harvest_value  seed_value hired_labor_value inorganic_fertilizer_value yield_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\NGA_FINAL_plot.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 


merge 1:m wave using "${Final}\\NGA_FINAL_plotcrop.dta", nogen

foreach var in harvest_value  seed_value {
	rename `var' `var'_LCU
	gen `var'_USD = `var'_LCU/pa_nus_atls
	replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\NGA_FINAL_plotcrop.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\NGA_FINAL_hh.dta", nogen

rename totcons totcons_LCU
gen totcons_USD = totcons_LCU/pa_nus_atls
replace totcons_USD = totcons_USD/deflator
define_labels
save "${Final}\\NGA_FINAL_hh.dta", replace


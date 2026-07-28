/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Append all Malawi code									          *
* Date: January 2024                                                            *
* -------------------------------------------------------------------------------*
*/
clear 

global paths "MWI\IHPS10 MWI\IHPS13 MWI\IHPS16 MWI\IHPS19"

global hh "case_id y2_hhid y3_hhid y4_hhid"

**********************************************************
**** A) Harmonize IDs
**********************************************************

use "${Input}\\Malawi\\IHPS 10\\hh_mod_a_filt_10.dta", clear 

gen hh_id_obs = case_id
keep case_id  hh_id_obs 
merge 1:m case_id using "${Input}\\Malawi\\IHPS 13\\\hh_mod_a_filt_13.dta", keepusing(y2_hhid dist_to_IHS3location) keep(match) nogen

define_MWI_track y2_hhid case_id 2 1 13 10 dist_to_IHS3location	
replace hh_id_obs = y2_hhid if 	parent_w2==0
gen wave = 2

keep case_id y2_hhid hh_id_obs parent_w2 wave
tempfile HH_frame_w2
save `HH_frame_w2', replace
merge 1:m y2_hhid using  "${Input}\\Malawi\\IHPS 16\\\hh_mod_a_filt_16.dta", keepusing(y3_hhid dist_to_IHPSlocation)  keep(match) nogen

define_MWI_track y3_hhid y2_hhid 3 2 16 13 dist_to_IHPSlocation	
replace hh_id_obs = y3_hhid + "-w3" if 	parent_w3==0
replace wave = 3

keep case_id y2_hhid y3_hhid  hh_id_obs parent_w2 parent_w3 wave
tempfile HH_frame_w3
save `HH_frame_w3', replace
merge 1:m y3_hhid using  "${Input}\\Malawi\\IHPS 19\\\hh_mod_a_filt_19.dta", keepusing(y4_hhid dist_to_IHPS2016location)  keep(match) nogen

define_MWI_track y4_hhid y3_hhid 4 3 19 16 dist_to_IHPS2016location	
replace hh_id_obs = y4_hhid + "-w4" if 	parent_w4==0
replace wave = 4

keep case_id y2_hhid y3_hhid y4_hhid  hh_id_obs parent_w2 parent_w3 parent_w4 wave
tempfile HH_frame_w4
save `HH_frame_w4', replace

use "${Temp}\\MWI\IHPS10\\hh_frame.dta", clear
gen wave = 1 
gen hh_id_merge = case_id
gen hh_id_obs = case_id
append using "${Temp}\\MWI\IHPS13\\hh_frame.dta"
replace wave = 2 if wave==.
replace hh_id_merge = y2_hhid if wave==2
append using "${Temp}\\MWI\IHPS16\\hh_frame.dta"
replace wave = 3 if wave==.
replace hh_id_merge = y3_hhid if wave==3
append using "${Temp}\\MWI\IHPS19\\hh_frame.dta"
replace wave = 4 if wave==.
replace hh_id_merge = y4_hhid if wave==4

merge m:1 y2_hhid wave using `HH_frame_w2', nogen update
merge m:1 y3_hhid wave using `HH_frame_w3', nogen update
merge m:1 y4_hhid wave using `HH_frame_w4', nogen update

rename hh_id_obs hh_id_obs_temp
egen hh_id_obs = group(hh_id_obs_temp)
replace hh_id_obs = hh_id_obs + 2000000 


keep hh_id_obs hh_id_merge wave
save "${Temp}\\MWI\\Frame_hhIDs.dta", replace

use "${Temp}\\MWI\\IHPS10\\plot_crop_frame.dta", clear
gen wave = 1
gen hh_id_merge = case_id
forvalues wave=2/4{
global temppath: word `wave' of $paths
local hhd: word `wave' of $hh
append using "${Temp}\\${temppath}\\plot_crop_frame.dta", gen(append)
replace wave = `wave' if append==1
replace hh_id_merge = `hhd' if append==1
drop append
}

// cannot track plots
egen plot_id_temp = concat(wave plot_id ), punct("-")
egen plot_id_obs = group(plot_id_temp)
replace plot_id_obs = plot_id_obs + 2000000 
gen plot_id_merge=  plot_id 

// can track parcels
merge m:1 wave hh_id_merge using "${Temp}\\MWI\\Frame_hhIDs.dta", keep(master match)
tostring hh_id_obs, gen(hh_id_obs_str)
replace parcel_id = reverse(subinstr(reverse(parcel_id),substr(reverse(parcel_id), strpos(reverse(parcel_id), "-" ) + 1, .), reverse(hh_id_obs_str),1)) if parcel_id!=""
gen parcel_id_temp = parcel_id
egen parcel_id_obs = group(parcel_id_temp) if parcel_id_temp!=""
replace parcel_id_obs = parcel_id_obs + 2000000 
gen parcel_id_merge=  parcel_id 

keep plot_id plot_id_obs plot_id_merge  crop_code crop_name wave parcel_id_obs parcel_id_merge
duplicates drop
save "${Temp}\\MWI\\Frame_plotcrop.dta", replace


use "${Temp}\\MWI\\IHPS10\\indiv_frame.dta", clear
gen wave = 1
forvalues wave=2/4{
global temppath: word `wave' of $paths
append using "${Temp}\\${temppath}\\indiv_frame.dta", gen(append)
replace wave = `wave' if append==1
drop append
}
gen indiv_id_obs = PID
rename indiv_id_obs indiv_id_obs_temp
egen indiv_id_obs = group(indiv_id_obs_temp)
replace indiv_id_obs = indiv_id_obs + 2000000 

gen indiv_id_merge = PID

gen hh_id_merge = case_id
replace hh_id_merge = y2_hhid if wave ==2
replace hh_id_merge = y3_hhid if wave ==3
replace hh_id_merge = y4_hhid if wave ==4

keep PID indiv_id_obs indiv_id_merge  wave hh_id_merge
duplicates drop
save "${Temp}\\MWI\\Frame_indiv.dta", replace
rename indiv_id_merge respondent_id 
forvalues wave = 1/4 {
preserve
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh
keep if wave==`wave'
merge 1:m  respondent_id using "${Temp}\\${temppath}\\Resp_characteristics1.dta", keep(match)
rename respondent_id respondent_id_merge
gen respondent_id_obs = indiv_id_obs
keep $hhd  respondent_id_obs respondent_id_merge 
save "${Temp}\\${temppath}\\Resp_characteristics1_ID.dta", replace
restore
}
rename respondent_id manager_id
forvalues wave = 1/4 {
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

use "${Temp}\\MWI\IHPS10\\Coords.dta", clear
append using "${Temp}\\MWI\IHPS13\\Coords.dta"
append using "${Temp}\\MWI\IHPS16\\Coords.dta"
append using "${Temp}\\MWI\IHPS19\\Coords.dta"

keep lat_modified lon_modified 
duplicates drop
egen geocoords_id = group(lat_modified lon_modified)
replace geocoords_id = geocoords_id + 2000000
keep lat_modified lon_modified geocoords_id
duplicates drop
save "${Temp}\\MWI\\geocoords_id.dta", replace


use "${Temp}\\MWI\IHPS10\\ea_id.dta", clear
gen hh_id_merge = case_id
gen wave =1
append using "${Temp}\\MWI\IHPS13\\ea_id.dta", 
replace hh_id_merge = y2_hhid if hh_id_merge==""
replace  wave =2 if wave==.
append using "${Temp}\\MWI\IHPS16\\ea_id.dta", 
replace hh_id_merge = y3_hhid if hh_id_merge==""
replace  wave =3 if wave==.
append using "${Temp}\\MWI\IHPS19\\ea_id.dta", 
replace hh_id_merge = y4_hhid if hh_id_merge==""
replace  wave =4 if wave==.
merge m:1 hh_id_merge wave using "${Temp}\\MWI\\Frame_hhIDs.dta", keep( match) nogen

egen ea_id_obs = group(ea_id)
replace ea_id_obs = ea_id_obs + 2000000
bys hh_id_obs (ea_id_obs): replace ea_id_obs = ea_id_obs[1] // 1 error
rename ea_id ea_id_merge

keep hh_id_merge ea_id_obs  ea_id_merge wave
duplicates drop
isid hh_id_merge wave
save "${Temp}\\MWI\\ea_id_obs.dta", replace




**********************************************************
**** B) Create plot-crop datasets
**********************************************************

forvalues wave = 1/4 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh

use "${Temp}\\${temppath}\\plot_crop_frame.dta", clear
duplicates drop
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MWI\\geocoords_id.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_kg.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_value.dta", keep(master match) nogen
drop main_crop // added later
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\pct_area_planted.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_end_month.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\planting_month.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_kg_merge.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\seed_value.dta" , keep(master match) nogen
if `wave'>2 {
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\improved.dta" , keep(master match) nogen
}
merge m:1 plot_id  using "${Temp}\\${temppath}\\used_pesticides.dta", keep(master match) nogen
merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\crop_shock.dta", keep(master match) nogen

gen wave = `wave'



// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge wave using "${Temp}\\MWI\\Frame_hhIDs.dta", keep(master match) nogen
merge 1:1 plot_id crop_code wave using "${Temp}\\MWI\\Frame_plotcrop.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\MWI\\ea_id_obs.dta", keep(master match) nogen
preserve
foreach var in parcel_id  case_id y2_hhid y3_hhid y4_hhid  occ baseline_rural panelweight region district dist_to_IHS3location hhsize interview_status hh_a05 hh_a06 hh_a07a hh_a10a hh_a10b hh_a16 hh_a21 hh_a23a_3 hh_a23a_4 hh_a23a_5 hh_a23a_6 hh_a23a_7 hh_a23a_8 hh_a23b_3 hh_a23b_4 hh_a23b_5 hh_a23b_6 hh_a23b_7 hh_a23b_8 hh_a23c_3 hh_a23c_4 hh_a23c_5 hh_a23c_6 hh_a23c_7 hh_a23c_8 hh_a24 hh_a26a hh_a26b hh_a26c hh_a27 hh_a29a hh_a29b hh_a29c hh_a30 hh_a33 hh_a35 hh_a37a_1 hh_a37a_2 hh_a37a_3 hh_a37a_4 hh_a37a_5 hh_a37a_6 hh_a37a_7 hh_a37a_8 hh_a37b_1 hh_a37b_2 hh_a37b_3 hh_a37b_4 hh_a37b_5 hh_a37b_6 hh_a37b_7 hh_a37b_8 hh_a38 hh_a40a hh_a40b hh_a40c hh_a41 hh_a43 hh_a43a hh_a43b hh_a43c hh_a44 hh_a46a hh_a46b hh_a46c hh_g00_1 hh_g00_2 panelweight_2016 panelweight_2013 ta_code dist_to_IHPSlocation mover consent hh_a22 hh_a23 hh_a31 hh_a37 hh_a40 interviewdate_v1 interviewdate_v2 hh_o0a consumption_date panelweight_2019 dist_to_IHPS2016location  harvest_sold_kg  n_harvest_kg n_harvest_value n_seed_value n_seed_kg  {
capture drop `var'
}  
define_labels
save "${Final}\\MWI_FINAL_plotcrop`wave'.dta", replace
restore


**********************************************************
**** C) Create plot datasets
**********************************************************

if `wave'>1  {
local parcel_id parcel_id parcel_id_merge parcel_id_obs
}
if `wave'>2 {
local improved improved
}

collapse (sum) harvest_kg harvest_value  seed_kg  seed_value (count) n_harvest_kg = harvest_kg n_harvest_value=harvest_value n_seed_kg = seed_kg  n_seed_value =seed_value (max)  used_pesticides *_shock `improved' , by(plot_id ea_id_obs ea_id_merge  pw strataid admin_1 admin_1_name admin_2 admin_2_name admin_3   wave plot_id_obs plot_id_merge hh_id_obs hh_id_merge `parcel_id' )

foreach var in  harvest_kg harvest_value seed_kg  seed_value {
replace `var' = . if n_`var'==0
}


global hhd: word `wave' of $hh

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
merge m:1 $hhd  using "${Temp}\\${temppath}\\Resp_characteristics1.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Resp_characteristics1_ID.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Resp_characteristics2.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\irrigated.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\erosion_protection.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\tractor.dta", keep(master match) nogen
if `wave'>2 {
merge m:1 parcel_id   using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen
}
else {
merge m:1 plot_id   using "${Temp}\\${temppath}\\plot_owned.dta", keep(master match) nogen	
}
merge m:1 $hhd  using "${Temp}\\${temppath}\\livestock.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\harvest_interview_month.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\planting_interview_month.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\ag_asset_index.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\aez.dta", keep(master match) nogen

merge m:1 $hhd  using "${Temp}\\${temppath}\\dist_popcenter.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\elevation.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\twi.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\soil.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MWI\\geocoords_id.dta", keep(master match) nogen
merge 1:1 plot_id  using "${Temp}\\${temppath}\\plot_dist_household.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\plot_slope.dta", keep(master match) nogen


// calculate yields
gen yield_kg = harvest_kg/plot_area_GPS
gen yield_value = harvest_value/plot_area_GPS

// harmonise IDS
foreach var in   case_id y2_hhid y3_hhid y4_hhid parcel_id n_total_labor_days n_total_family_labor_days n_total_hired_labor_days n_hired_labor_value NPK_kg DAP_kg UREA_kg CAN_kg D_kg other_kg n_nitrogen_kg n_NPK_kg n_DAP_kg n_UREA_kg n_CAN_kg n_D_kg n_other_kg qx_type hh_a01 hh_a02 hh_a02b hh_a11 hh_a13 hh_a22_1 hh_a22_2 hh_a23_1 hh_a23a_1 hh_a23b_1 hh_a23c_1 hh_a23_2 hh_a23a_2 hh_a23b_2 hh_a23c_2 hh_a25_1 hh_a25_2 hh_a26_1 hh_a26a_1 hh_a26b_1 hh_a26c_1 hh_a26_2 hh_a26a_2 hh_a26b_2 hh_a26c_2 hh_a31_1 hh_a31_2 hh_a32_1 hh_a32a_1 hh_a32b_1 hh_a32c_1 hh_a32_2 hh_a32a_2 hh_a32b_2 hh_a32c_2 hh_a34_1 hh_a34_2 hh_a35_1 hh_a35a_1 hh_a35b_1 hh_a35c_1 hh_a35_2 hh_a35a_2 hh_a35b_2 hh_a35c_2 hh_g09 hh_m00 hh_o00 hh_s01 hh_w01 int_outcome_1 int_outcome_2 _merge occ baseline_rural panelweight region district dist_to_IHS3location hhsize interview_status hh_a05 hh_a06 hh_a07a hh_a10a hh_a10b hh_a16 hh_a21 hh_a23a_3 hh_a23a_4 hh_a23a_5 hh_a23a_6 hh_a23a_7 hh_a23a_8 hh_a23b_3 hh_a23b_4 hh_a23b_5 hh_a23b_6 hh_a23b_7 hh_a23b_8 hh_a23c_3 hh_a23c_4 hh_a23c_5 hh_a23c_6 hh_a23c_7 hh_a23c_8 hh_a24 hh_a26a hh_a26b hh_a26c hh_a27 hh_a29a hh_a29b hh_a29c hh_a30 hh_a33 hh_a35 hh_a37a_1 hh_a37a_2 hh_a37a_3 hh_a37a_4 hh_a37a_5 hh_a37a_6 hh_a37a_7 hh_a37a_8 hh_a37b_1 hh_a37b_2 hh_a37b_3 hh_a37b_4 hh_a37b_5 hh_a37b_6 hh_a37b_7 hh_a37b_8 hh_a38 hh_a40a hh_a40b hh_a40c hh_a41 hh_a43 hh_a43a hh_a43b hh_a43c hh_a44 hh_a46a hh_a46b hh_a46c hh_g00_1 hh_g00_2 panelweight_2016 panelweight_2013 ta_code dist_to_IHPSlocation mover consent hh_a22 hh_a23 hh_a31 hh_a37 hh_a40 interviewdate_v1 interviewdate_v2 hh_o0a consumption_date panelweight_2019 dist_to_IHPS2016location  harvest_sold_kg manager_id respondent_id  {
capture drop `var'
}  
order hh_id_merge hh_id_obs plot_id_obs plot_id_merge

define_labels

save "${Final}\\MWI_FINAL_plotw`wave'.dta", replace
}

**********************************************************
**** D) Create household datasets
**********************************************************


forvalues wave = 1/4 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh


use "${Temp}\\${temppath}\\hh_frame.dta", clear
gen wave = `wave'

merge 1:1 $hhd using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MWI\\geocoords_id.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_primary_education.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_electricity_access.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_dependency_ratio.dta", keep(master match) nogen
if `wave'==2 { 
merge 1:1 $hhd using "${Temp}\\${temppath}\\cons_quint.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\totcons.dta", keep(master match) nogen	
}

merge 1:1 $hhd using "${Temp}\\${temppath}\\shock.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\hh_asset_index.dta", keep(master match) nogen
merge 1:1 $hhd using "${Temp}\\${temppath}\\size.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\nfe.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\HDDS.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\nb_fallow_plots.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\nb_plots.dta", keep(master match) nogen
merge m:1 $hhd  using "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", keep(master match) nogen
if `wave' > 1 { 
merge m:1 $hhd  using "${Temp}\\${temppath}\\popdensity.dta", keep(master match) nogen
}

// harmonise IDS
gen hh_id_merge = $hhd
merge m:1 hh_id_merge wave using "${Temp}\\MWI\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\MWI\\ea_id_obs.dta", keep(master match) nogen
foreach var in household_id household_id2 y2_hhid dist_to_IHS3location hh_a05 y3_hhid dist_to_IHPSlocation y4_hhid dist_to_IHPS2016location {
capture drop `var'
} 
order hh_id_merge hh_id_obs 
define_labels

save "${Final}\\MWI_FINAL_hhw`wave'.dta", replace
}

**********************************************************
**** E) Create individual level datasets
**********************************************************


forvalues wave = 1/4 {
global temppath: word `wave' of $paths
global hhd: word `wave' of $hh

use "${Temp}\\${temppath}\\indiv_frame.dta", clear
merge m:1 $hhd using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\strataid.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\urban.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\weights.dta", keep(master match) nogen
merge m:1 $hhd using "${Temp}\\${temppath}\\Coords.dta", keep(master match) nogen
merge m:1 lat_modified lon_modified  using "${Temp}\\MWI\\geocoords_id.dta", keep(master match) nogen
merge 1:1 $hhd PID using "${Temp}\\${temppath}\\indiv_chars.dta", keep(master match) nogen
merge 1:1 $hhd PID using "${Temp}\\${temppath}\\wasting.dta", keep(master match) nogen
merge 1:1 $hhd PID using "${Temp}\\${temppath}\\labor.dta", keep(master match) nogen
merge 1:1 $hhd PID using "${Temp}\\${temppath}\\educ_indiv.dta", keep(master match) nogen

gen wave = `wave'
define_labels

gen hh_id_merge = $hhd
gen indiv_id_merge = PID
merge m:1 hh_id_merge wave using "${Temp}\\MWI\\Frame_hhIDs.dta", keep(master match) nogen
merge m:1 indiv_id_merge wave using "${Temp}\\MWI\\Frame_indiv.dta", keep(master match) nogen
merge m:1 hh_id_merge wave using "${Temp}\\MWI\\ea_id_obs.dta", keep(master match) nogen
foreach var in id_code {
capture drop `var'
} 
order hh_id_merge hh_id_obs indiv_id_merge indiv_id_obs 
save "${Final}\\MWI_FINAL_indivw`wave'.dta", replace
}


**********************************************************
**** F) Append all
**********************************************************


use "${Final}\\MWI_FINAL_plotcrop1.dta",  clear
forvalues wave=2/4{
append using "${Final}\\MWI_FINAL_plotcrop`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

save "${Final}\\MWI_FINAL_plotcrop.dta", replace


use "${Final}\\MWI_FINAL_plotw1.dta",  clear
forvalues wave=2/4{
append using "${Final}\\MWI_FINAL_plotw`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

save "${Final}\\MWI_FINAL_plot.dta", replace


use "${Final}\\MWI_FINAL_hhw1.dta",  clear
forvalues wave=2/4{
append using "${Final}\\MWI_FINAL_hhw`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

save "${Final}\\MWI_FINAL_hh.dta", replace

use "${Final}\\MWI_FINAL_indivw1.dta",  clear
forvalues wave=2/4{
append using "${Final}\\MWI_FINAL_indivw`wave'.dta",
}
bys hh_id_obs(ea_id_merge): assert ea_id_merge == ea_id_merge[_n]
bys hh_id_obs(ea_id_merge): assert strataid == strataid[_n]

save "${Final}\\MWI_FINAL_indiv.dta", replace



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

wbopendata, language(en - English) country(MWI) topics() indicator(PA.NUS.ATLS) clear long
keep pa_nus_atls year
merge 1:1 year using `deflator', nogen
gen wave = 1 if year == 2010
replace wave = 2 if year == 2013
replace wave = 3 if year == 2016
replace wave = 4 if year == 2018
drop if wave==. 

merge 1:m wave using "${Final}\\MWI_FINAL_plot.dta", nogen

foreach var in harvest_value  seed_value hired_labor_value inorganic_fertilizer_value yield_value {
rename `var' `var'_LCU
gen `var'_USD = `var'_LCU/pa_nus_atls
replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\MWI_FINAL_plot.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 


merge 1:m wave using "${Final}\\MWI_FINAL_plotcrop.dta", nogen

foreach var in harvest_value  seed_value {
rename `var' `var'_LCU
gen `var'_USD = `var'_LCU/pa_nus_atls
replace `var'_USD = `var'_USD /deflator
}
define_labels
save "${Final}\\MWI_FINAL_plotcrop.dta", replace

keep pa_nus_atls deflator wave 
duplicates drop 

merge 1:m wave using "${Final}\\MWI_FINAL_hh.dta", nogen

rename totcons totcons_LCU
gen totcons_USD = totcons_LCU/pa_nus_atls
replace totcons_USD = totcons_USD/deflator
define_labels
save "${Final}\\MWI_FINAL_hh.dta", replace


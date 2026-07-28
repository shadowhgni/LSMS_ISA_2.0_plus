/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for ES3          *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Tanzania
global wave  NPS 14 - refresh
global cover  HH_SEC_A.dta
global indiv_roster  HH_SEC_B.dta
global educ HH_SEC_C.dta
global plot_inputs AG_SEC_3A.dta
global shocks HH_SEC_R.dta
global housing  HH_SEC_I.dta
global lab_roster HH_SEC_E.dta
global plot_roster  AG_SEC_2A.dta
global perennial_fruit AG_SEC_6A.dta
global perennial AG_SEC_6B.dta
global perennial_fruit_sell AG_SEC_7A.dta
global perennial_sell AG_SEC_7B.dta
global HDDS hh_sec_j1.dta
global csption consumptionnps4.dta
global items AG_SEC_11.dta
global items_hh HH_SEC_M.dta
global harvest_rwdta  AG_SEC_4A.dta
global harvest_sold_rwdta  AG_SEC_5A.dta
global geovars_hh npsy4.ea.offset.dta
global livestock LF_SEC_02.dta
global nfe HH_SEC_N.dta
global anthropo  HH_SEC_V.dta
global meta AG_SEC_A.dta
global temppath TZA\NPS14


**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame

use "${Input}\\${country}\\${wave}\\${perennial_fruit}", clear
decode zaocode, gen(name_fruit)
keep y4_hhid plotnum zaocode name_fruit
tempfile perennial_fruit
save `perennial_fruit', replace
use "${Input}\\${country}\\${wave}\\${perennial}", clear
decode zaocode, gen(name_per)
keep y4_hhid plotnum zaocode name_per
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using `perennial_fruit', nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using `perennial', nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id= concat(y4_hhid plotnum) , punct("-")
decode zaocode, gen(crop_name)
replace crop_name = substr(crop_name, strpos(crop_name, " ")+1, .)
keep y4_hhid plot_id crop_name zaocode 

duplicates drop

duplicates tag plot_id crop_name, gen(tag)
decode zaocode, gen(cropname2)
replace crop_name = cropname2 if tag>0
replace crop_name = "OTHER" if crop_name=="(SPECIFY)"

duplicates report plot_id crop_name

save "${Temp}\\${temppath}\\plot_crop_frame_refresh.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
keep y4_hhid 
duplicates report y4_hhid 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame_refresh.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (y4_hhid indidy4), punct("-")
keep y4_hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame_refresh.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear

egen ea_id = concat(hh_a01_1 hh_a02_1 hh_a03_1 hh_a04_1), punct("-")
keep y4_hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace
save "${Temp}\\${temppath}\\ea_id_refresh.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear 
keep y4_hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid_refresh.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename hh_a01_1 admin_1
rename hh_a01_2 admin_1_name
keep y4_hhid admin_1 admin_1_name
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace
save "${Temp}\\${temppath}\\admin1_refresh.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_2 = concat(hh_a01_1 hh_a02_1), punct("-")
replace admin_2 = "" if  hh_a02_1==. | hh_a01_1==.
rename  hh_a02_2  admin_2_name
keep y4_hhid admin_2 admin_2_name
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace
save "${Temp}\\${temppath}\\admin2_refresh.dta", replace


// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_3 = concat(hh_a01_1 hh_a02_1 hh_a03_1), punct("-")
replace admin_3 = "" if hh_a03_1==. | hh_a02_1==. | hh_a01_1==.
keep y4_hhid admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace
save "${Temp}\\${temppath}\\admin3_refresh.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${csption}", clear
rename urban urban2
recode urban2 (2 = 1 "Yes") (1 = 0 "No"), gen(urban) label(urban)
keep y4_hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban_refresh.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename y4_weights pw
keep pw y4_hhid
duplicates drop
save "${Temp}\\${temppath}\\weights_refresh.dta", replace

// planting month (absent)

// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
rename _merge _mergefruit
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", 
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
rename _merge _mergeper
egen plot_id= concat(y4_hhid plotnum) , punct("-")

gen month = ag4a_24_2
format month %tm
replace month=. if ag4a_24_2==0

gen year = 2015
replace year= 2014 if inlist(ag4a_24_2, 11, 12)
format year %ty
replace year = ag6a_07_3 if _mergefruit==2 & ag6a_07_3>1900
replace year = ag6b_07_3 if _mergeper==2 & ag6b_07_3>1900
replace month = ag6a_07_4 if month==.
replace month = ag6b_07_4 if month==.


gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(y4_hhid plot_id zaocode)
save "${Temp}\\${temppath}\\harvest_end_month_refresh.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen month = hh_a18_2
format month %tm 
gen year = hh_a18_3
format year %ty 

gen harvest_interview_month = ym( year, month)
format harvest_interview_month %tmCCYYMon
keep y4_hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month_refresh.dta", replace

// planting_interview_month (absent)

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta.dta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge m:1 y4_hhid using "${Temp}\\${temppath}\\ea_id_refresh.dta", keep(master match) nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin1_refresh.dta", keep(master match) nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin2_refresh.dta", keep(master match) nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin3_refresh.dta", keep(master match) nogen 
egen plot_id= concat(y4_hhid plotnum) , punct("-")

gen harvest_kg_seas= ag4a_28 
replace harvest_kg_seas = 0 if ag4a_19==2
gen harvest_kg_per = ag6a_09 
gen harvest_kg_fruit = ag6b_09 
egen harvest_kg = rowtotal(harvest_kg_seas  harvest_kg_per harvest_kg_fruit), missing

recode ag4a_22 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_seas) label(crop_shock)
replace crop_shock_seas=1 if ag4a_17==1 // pre harvest losses
replace crop_shock_seas=1 if ag4a_20==3
recode ag6a_10 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_fruit) label(crop_shock)
recode ag6b_10 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_per) label(crop_shock)
egen crop_shock = rowmax(crop_shock_seas  crop_shock_fruit crop_shock_per)

replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 
collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id zaocode admin_1 admin_2 admin_3 ea_id y4_hhid)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg_refresh.dta", replace
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id= concat(y4_hhid plotnum) , punct("-")

recode ag4a_22 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_seas) label(crop_shock)
replace crop_shock_seas=1 if ag4a_17==1 // pre harvest losses
replace crop_shock_seas=1 if ag4a_20==3
recode ag6a_10 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_fruit) label(crop_shock)
recode ag6b_10 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_per) label(crop_shock)
egen crop_shock = rowmax(crop_shock_seas  crop_shock_fruit crop_shock_per)

recode ag4a_23 (1 = 1 "Yes") (2/9 = 0 "No"), gen(drought_shock1) label(drought_shock) 
recode ag4a_03 (2 = 1 "Yes") (1 3/9 = 0 "No"), gen(drought_shock2) label(drought_shock) 
replace drought_shock1=0 if ag4a_22==2
replace drought_shock2=0 if ag4a_01==1
gen drought_shock= 1 if drought_shock1==1 | drought_shock2==1
replace drought_shock=0 if (drought_shock1==0 & drought_shock2==0 )	

recode ag4a_23 (4 = 1 "Yes") (1/3 5/9 = 0 "No"), gen(pests_shock1) label(pests_shock) 
recode ag4a_18 (3 = 1 "Yes") (1 2 4/9 = 0 "No"), gen(pests_shock2) label(pests_shock) 
replace pests_shock1=0 if ag4a_22==2
replace pests_shock2=0 if ag4a_17==2
gen pests_shock= 1 if pests_shock1==1 | pests_shock2==1
replace pests_shock=0 if (pests_shock1==0 & pests_shock2==0 )
recode ag6a_11 (1 2 3 = 1 "Yes") (4/9 = 0 "No"), gen(pests_shock_fruit) label(crop_shock)
replace pests_shock_fruit = 0 if ag6a_10==2
recode ag6b_11 (1 2 3 = 1 "Yes") (4/9 = 0 "No"), gen(pests_shock_per) label(crop_shock)
replace pests_shock_per = 0 if ag6b_10==2
egen pests_shock_combin = rowmax(pests_shock  pests_shock_fruit pests_shock_per)
replace pests_shock = pests_shock_combin


collapse (max) crop_shock pests_shock  drought_shock, by(y4_hhid plot_id zaocode )
save "${Temp}\\${temppath}\\crop_shock_refresh.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y4_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y4_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge m:1 y4_hhid using "${Temp}\\${temppath}\\ea_id_refresh.dta", nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin1_refresh.dta",  nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin2_refresh.dta", nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin3_refresh.dta",  nogen 

gen harvest_sold_kg_seas = ag5a_02
replace harvest_sold_kg_seas= 0 if ag5a_01==2

gen harvest_sold_kg_per = ag7a_03
replace harvest_sold_kg_per= 0 if ag7a_02==2

gen harvest_sold_kg_fruit = ag7b_03
replace harvest_sold_kg_fruit= 0 if ag7b_02==2

egen harvest_sold_kg = rowtotal(harvest_sold_kg_seas harvest_sold_kg_per harvest_sold_kg_fruit), missing

collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( zaocode y4_hhid admin_1 admin_2 admin_3)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\harvest_sold_kg_refresh.dta", replace
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(y4_hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m y4_hhid using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(y4_hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep y4_hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh_refresh.dta", replace

// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y4_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y4_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge m:1 y4_hhid using "${Temp}\\${temppath}\\ea_id_refresh.dta", nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin1_refresh.dta", nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin2_refresh.dta", nogen 
merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin3_refresh.dta",  nogen 

gen harvest_sold_value_seas = ag5a_03
gen harvest_sold_value_per  = ag7a_04
gen harvest_sold_value_fruit  = ag7b_04

egen harvest_sold_value = rowtotal(harvest_sold_value_seas harvest_sold_value_per harvest_sold_value_fruit), missing

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( zaocode y4_hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value_refresh.dta", replace
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace


// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta.dta}", clear
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y4_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y4_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y4_hhid zaocode, gen(tag)
drop if tag>0
drop tag
keep y4_hhid  zaocode 
duplicates drop

valuation_median_crops_noea_sort y4_hhid   zaocode

main_crop_def zaocode


keep plot_id harvest_value zaocode main_crop 
save "${Temp}\\${temppath}\\harvest_value_refresh.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t

egen plot_id= concat(y4_hhid plotnum) , punct("-")

recode ag4a_04 (1 =1 "Yes") (2=0 "No"), gen(intercropped_seas) label(intercropped)
recode ag6a_05 (1 =1 "Yes") (2=0 "No"), gen(intercropped_fruit) label(intercropped)
recode ag6b_05 (1 =1 "Yes") (2=0 "No"), gen(intercropped_per) label(intercropped)
egen intercropped = rowmax(intercropped_seas intercropped_fruit intercropped_per)
keep zaocode plot_id intercropped
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped_refresh.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
rename _merge _mergefruit
merge 1:m y4_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", 
drop if plotnum==""
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id = concat( y4_hhid plotnum), punct("-")
replace zaocode = . if _mergefruit==2 | _merge==2
bys  plot_id : egen nb_seasonal_crop = count(zaocode)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop_refresh.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
tempfile perennial_nodups
save `perennial_nodups', replace
use "${Input}\\${country}\\${wave}\\${perennial_fruit}", clear
duplicates tag y4_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
tempfile perennial_fruit_nodups
save `perennial_fruit_nodups', replace


use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
merge m:1 y4_hhid plotnum zaocode using `perennial_fruit_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codeszaocode1)
drop _merge
merge m:1 y4_hhid plotnum zaocode using `perennial_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codeszaocode2)
drop _merge
egen plot_id = concat( y4_hhid plotnum), punct("-")

merge m:1 zaocode plot_id  using "${Temp}\\${temppath}\\harvest_value_refresh.dta", keep(match using) nogen

rename  zaocode  tempname
rename main_crop zaocode 
merge m:1 y4_hhid plotnum zaocode using `perennial_fruit_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codesmain_crop1)
drop _merge
merge m:1 y4_hhid plotnum zaocode using `perennial_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codesmain_crop2)
drop _merge
rename  zaocode  main_crop
rename  tempname zaocode

bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if zaocode==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

foreach c in main_crop zaocode {
lab val `c' AG4A_0B
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2
replace `c' = substr(`c', 1, length(`c') - 1) if substr(`c', -1, 1) ==  "S"	
replace `c' = substr(`c', 1, length(`c')- 1) if substr(`c', -2, 2) == "OE" 
replace `c' = strupper(`c')	

replace `c'="EGGPLANT" if `c'=="EGG PLANT"
replace `c' = "SUGARCANE" if `c'=="SUGAR CANE"
replace `c' = "WATERMELON" if `c'=="WATER MELLON"
replace `c' = "CHICKPEA" if `c'=="CHICK PEA"
replace `c' = "YAMS" if `c'=="YAM"
replace `c' = "PUMPKINS" if `c' =="PUMPKIN"
replace `c' = "CHILIES" if `c' =="CHILIE"
replace `c' = "BANANAS" if `c' =="BANANA"	
replace `c' = "GROUNDNUTS" if `c' =="GROUNDNUT"	

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c', "GROUNDNUTS", "SOY", "SOYABEAN", "SOYABEANS",  "BEANS", "BEAN", "VOANDZOU")  | strpos(`c',"BAMBARA NUT") | strpos(`c',"PEA")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c', "CASSAVA", "YAMS", "CARROT", "BEETS") | strpos(`c',"POTATO") | strpos(`c',"COCOYAM")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"TARO", "SOUCHET", "RIZGA")
replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE" | `c'=="PADDY"
replace `c'2 = "WHEAT" if `c'=="WHEAT"
replace `c'2 = "MAIZE" if `c'=="MAIZE"
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
replace `c'2 = "MILLET" if `c'=="MILLET" | `c'=="ACHA" |  `c'=="FONIO" | `c'=="BULRUSH MILLET" | `c'=="FINGER MILLET"
replace `c'2 = "NUTS" if `c'=="NUTS" | `c'=="CASHEW NUT"
replace `c'2 = "" if `c'=="."
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if codes`c'1==1 | codes`c'2==1
drop `c'
rename `c'2 `c'
}
tab zaocode, gen(contains_crop_)

foreach n in 9 8 7 6 5 4 {
	local i = `n' + 2
	rename contains_crop_`n' contains_crop_`i'
} 
	
foreach n in 3 2 1 {
	local i = `n' + 1
	rename contains_crop_`n' contains_crop_`i'
} 

gen contains_crop_1=0
gen contains_crop_5=0

//share of each crop category

forvalues n = 1/11 {
gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
replace share_crop`n' = 0 if contains_crop_`n'==0
}

collapse (sum) share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop_refresh.dta", replace

// share of plot area planted by crop 

// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat(y4_hhid plotnum) , punct("-")

gen area_self_reported = ag2a_04 * 0.404686

gen plot_area_GPS= ag2a_09 * 0.404686 // acres to ha 

merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin3_refresh.dta", keep(master match) nogen

isid y4_hhid plot_id
sort y4_hhid plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi tsset, clear 
encode admin_3, gen(admin_3_cd)
mi impute pmm plot_area_GPS area_self_reported i.admin_3_cd, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys y4_hhid: egen farm_size = total(plot_area_GPS), missing

keep y4_hhid plot_id  plot_area_GPS farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area_refresh.dta", replace

// improved 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id= concat(y4_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
collapse (max) improved  ,by(plot_id zaocode)
save "${Temp}\\${temppath}\\improved_refresh.dta", replace

// seed kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 y4_hhid using "${Temp}\\${temppath}\\ea_id_refresh.dta", nogen 
egen plot_id= concat(y4_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
gen seed_kg = ag4a_10_1 if ag4a_10_2==1 // cannot convert many units
collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by(plot_id zaocode ea_id improved)
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg_refresh.dta", replace
save "${Temp}\\${temppath}\\seed_kg.dta", replace
collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by(plot_id zaocode ea_id )
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg_merge_refresh.dta", replace



// seed_kg_sold 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id= concat(y4_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
gen seeds_amount_purchased_kg = ag4a_10c_1 if ag4a_10c_2==1  
collapse  (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg=seeds_amount_purchased_kg  ,by(plot_id zaocode improved)
replace seeds_amount_purchased_kg=. if n_seeds_amount_purchased_kg==0
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg_refresh.dta", replace


// seed_value_sold 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id= concat(y4_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
gen seed_value_temp = ag4a_12
collapse (sum) seed_value_temp (count) n_seed_value_temp=seed_value_temp  ,by(plot_id zaocode improved)
replace seed_value_temp=. if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp_refresh.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear


egen plot_id= concat(y4_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)

keep y4_hhid plot_id zaocode improved 
duplicates drop


	// value median seeds (different nomenclature from program)
	merge m:1 y4_hhid  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen


	merge 1:1 plot_id zaocode improved using "${Temp}\\${temppath}\\seed_value_temp_refresh.dta", keep(master match)	nogen
	merge 1:1 plot_id zaocode improved using "${Temp}\\${temppath}\\seeds_amount_purchased_kg_refresh.dta", keep(master match)	nogen
		
	gen seed_price_temp = seed_value_temp / seeds_amount_purchased_kg
	replace seed_price_temp = . if seed_price_temp==0



	forvalues n =1/4 {
	capture merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
	if !_rc {
	 merge m:1 y4_hhid using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
	}
	}

	gen n=1 if !mi(seed_price_temp) & seed_price_temp!=0
	bys ea_id zaocode improved: egen n2= total(n)
	gen ten_obs_EA=1 if n2>=10 & !mi(n2)
	replace ten_obs_EA=0 if n2<10 | mi(n2)
	tab ten_obs_EA
	bys ea_id zaocode improved: egen seed_price_EA = median(seed_price_temp) if seed_price_temp!=0
	gen seed_price = seed_price_EA if ten_obs_EA==1
	drop n2 

	capture confirm variable admin_4
	if !_rc {
			bys admin_4 zaocode improved: egen n2= total(n)
			gen ten_obs_admin4=1 if n2>=10 & !mi(n2)
			replace ten_obs_admin4=0 if n2<10 | mi(n2)
			tab ten_obs_admin4
			bys admin_4 zaocode improved: egen seed_price_admin4 = median(seed_price_temp) if seed_price_temp!=0
			replace seed_price = seed_price_admin4 if ten_obs_admin4==1 & ten_obs_EA==0 // no change
			drop n2 

			bys admin_3 zaocode improved: egen n2=total(n)
			gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
			replace ten_obs_admin3=0 if n2<10 | mi(n2)
			tab ten_obs_admin3
			bys admin_3 zaocode improved: egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
			replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_admin4==0 
			drop n2 
			}
		else {
			bys admin_3 zaocode improved: egen n2=total(n)
			gen ten_obs_admin3=1 if n2>=10 & !mi(n2)
			replace ten_obs_admin3=0 if n2<10 | mi(n2)
			tab ten_obs_admin3
			bys admin_3 zaocode improved: egen seed_price_admin3 = median(seed_price_temp) if seed_price_temp!=0
			replace seed_price = seed_price_admin3 if ten_obs_admin3==1 & ten_obs_EA==0 
			drop n2 
			} 

			

	* 
	bys admin_2 zaocode improved: egen n2=total(n)
	gen ten_obs_admin2=1 if n2>=10 & !mi(n2)
	replace ten_obs_admin2=0 if n2<10 | mi(n2)
	tab ten_obs_admin2
	bys admin_2 zaocode improved: egen seed_price_admin2 = median(seed_price_temp) if seed_price_temp!=0
	replace seed_price = seed_price_admin2 if ten_obs_admin2==1 & ten_obs_admin3==0 
	drop n2

	* admin_1 level 
	bys admin_1 zaocode improved: egen n2=total(n)
	gen ten_obs_admin1=1 if n2>=10 & !mi(n2)
	replace ten_obs_admin1=0 if n2<10 | mi(n2)
	tab ten_obs_admin1
	bys admin_1 zaocode improved: egen seed_price_admin_1 = median(seed_price_temp) if seed_price_temp!=0
	replace seed_price = seed_price_admin_1 if ten_obs_admin1==1 & ten_obs_admin2==0 
	drop n2

	* 
	bys zaocode improved: egen n2=total(n)
	gen ten_obs_n=1 if n2>=10 & !mi(n2)
	replace ten_obs_n=0 if n2<10 | mi(n2)
	tab ten_obs_n
	bys zaocode improved: egen seed_price_national = median(seed_price_temp) if seed_price_temp!=0
	replace seed_price = seed_price_national if ten_obs_n==1 & ten_obs_admin1==0 
	drop n2 n

	replace seed_price=seed_price_national if ten_obs_n==0


	** Collapse to the EA - crop level
	keep ea_id zaocode seed_price improve
	duplicates drop

	** Generating harvest value, using crop price variable
	merge 1:m ea_id zaocode improve using "${Temp}\\${temppath}\\seed_kg_refresh.dta", keep(match using) nogen
	gen seed_value = seed_price * seed_kg

collapse (sum) seed_value (count) n = seed_value, by(plot_id zaocode ) 
replace seed_value = . if n ==0
duplicates drop
save "${Temp}\\${temppath}\\seed_value_refresh.dta", replace

// labor days
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-")

egen hired_labor_days1 = rowtotal(ag3a_74_1 ag3a_74_2 ag3a_74_3), missing 
replace hired_labor_days1= 0 if ag3a_73==2

egen hired_labor_days2 = rowtotal(ag3a_74_5 ag3a_74_6 ag3a_74_7), missing  
replace hired_labor_days2= 0 if ag3a_73==2

egen hired_labor_days3 = rowtotal(ag3a_74_13 ag3a_74_14 ag3a_74_15), missing 
replace hired_labor_days3= 0 if ag3a_73==2

egen total_hired_labor_days = rowtotal(hired_labor_days*), missing

egen wage_total = rowtotal(ag3a_74_4 ag3a_74_8 ag3a_74_16), missing
gen wage = wage_total/total_hired_labor_days

valuation_median_wages y4_hhid wage wage wage

gen hired_labor_value = child_wage * total_hired_labor_days // all wages are equal

foreach n of numlist 1/12  {
egen ID`n' = concat(y4_hhid ag3a_72_id`n'), punct("-")
gen ID_worker`n'_PP = ID`n' if  ag3a_72_id`n' !=.
}


forvalues n = 13/18 {
egen ID`n' = concat(y4_hhid ag3a_72_id`n'), punct("-")
local h = `n' - 12
gen ID_worker`h'_PH = ID`h' if  ag3a_72_id`n' !=.
}

egen total_family_labor_days = rowtotal(ag3a_72_1 ag3a_72_2 ag3a_72_3 ag3a_72_4 ag3a_72_5 ag3a_72_6 ag3a_72_7 ag3a_72_8 ag3a_72_9 ag3a_72_10 ag3a_72_11 ag3a_72_12 ag3a_72_13 ag3a_72_14 ag3a_72_15 ag3a_72_16 ag3a_72_17 ag3a_72_18), missing
egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days), missing

keep total_labor_days plot_id total_family_labor_days total_hired_labor_days hired_labor_value ID_worker*
duplicates drop
save "${Temp}\\${temppath}\\labor_days_refresh.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y4_hhid plotnum), punct("-")
recode ag3a_47 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_refresh.dta", replace

// nitrogen equivalent
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
merge m:1 y4_hhid using "${Temp}\\${temppath}\\ea_id_refresh.dta", nogen 
egen plot_id = concat( y4_hhid plotnum), punct("-") 

gen UREA_kg1 = ag3a_49 if ag3a_48==2 
	gen UREA_kg2 = ag3a_56 if ag3a_55==2
	egen UREA_kg = rowtotal(UREA_kg*), missing
	gen nitrogen_kg1 = UREA_kg * 0.46
	
	* DAP 
	gen DAP_kg1 = ag3a_49 if ag3a_48==1
	gen DAP_kg2 = ag3a_56 if ag3a_55==1
	egen DAP_kg = rowtotal(DAP_kg*), missing
	gen nitrogen_kg2 = DAP_kg * 0.18
	
	* SA 
	gen SA_kg1 = ag3a_49 if ag3a_48==5
	gen SA_kg2 = ag3a_56 if ag3a_55==5
	egen SA_kg = rowtotal(SA_kg*), missing
	gen nitrogen_kg3 = SA_kg * 0.21
	
	*CAN 
	gen CAN_kg1 = ag3a_49 if ag3a_48==4
	gen CAN_kg2 = ag3a_56 if ag3a_55==4
	egen CAN_kg = rowtotal(CAN_kg*), missing
	gen nitrogen_kg4 = CAN_kg * 0.26
	
	* NPK 
	gen NPK_kg1 = ag3a_49 if ag3a_48==6
	gen NPK_kg2 = ag3a_56 if ag3a_55==6
	egen NPK_kg = rowtotal(NPK_kg*), missing
	gen nitrogen_kg5 = NPK_kg * 0.2
	
	egen nitrogen_kg = rowtotal(nitrogen_kg*), missing
	replace nitrogen_kg=0 if ag3a_47==2
	
	egen fert_kg = rowtotal(ag3a_49 ag3a_56), missing // I will not differentiate between fertilizers in to calculation of prices because there are too little observations

collapse (sum) nitrogen_kg  fert_kg   (count) n_nitrogen_kg = nitrogen_kg n_fert_kg = fert_kg   , by(plot_id y4_hhid ea_id)
foreach var in nitrogen_kg fert_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg_refresh.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

egen plot_id = concat(y4_hhid plotnum), punct("-") 
isid plot_id

egen fert_purchased_value = rowtotal(ag3a_51 ag3a_58), missing
egen fert_purchased_kg = rowtotal(ag3a_49 ag3a_56), missing

valuation_median_fert_price y4_hhid fert

keep ea_id fert_value
duplicates drop

drop if fert_value==.
merge 1:m ea_id using "${Temp}\\${temppath}\\nitrogen_kg_refresh.dta", keep(match) nogen

foreach n in fert  {
gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing
replace inorganic_fertilizer_value = 0 if nitrogen_kg==0

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value_refresh.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-") 
recode ag3a_41 (1= 1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer_refresh.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-")
recode ag3a_65a (1= 1 "Yes") (2 = 0 "No") , gen(used_pesticides) label(used_pesticides)
replace used_pesticides= 1 if ag3a_60==1
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides_refresh.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-")
recode ag3a_25 ( 1 2 5 9  = 1 "Yes") (11= .) (.=.)  (else = 0 "No") , gen(plot_owned) label(plot_owned) 
recode ag3a_28a (1 2 = 1 "Yes") (3 = 0 "No") , gen(plot_certificate) label(plot_certificate)
replace plot_certificate=1 if inrange(ag3a_28d, 1, 5)
replace plot_certificate=0 if plot_owned==0
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned_refresh.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-")
recode  ag3a_18 (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated_refresh.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-")
recode ag3a_15 (1 = 1 "Yes") (2=0 "No"), gen(erosion_protection)  label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection_refresh.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
gen tractor= 1 if ag11_04==1 & inlist(itemid,6, 7, 8) 
replace tractor= 1 if ag11_06==1 & inlist(itemid,6, 7, 8) 
replace tractor= 0 if !inlist(itemid,6, 7, 8) 
collapse (max) tractor , by(y4_hhid)
save "${Temp}\\${temppath}\\tractor_refresh.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-")
recode ag3a_03 (4 = 1) (. = .)  (* = 0) , gen(fallow_plot)
bys y4_hhid: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 y4_hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_fallow_plots= 0 if _merge ==2
keep y4_hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots_refresh.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y4_hhid plotnum), punct("-")
recode ag3a_03 (4 = 1) (. = .)  (* = 0) , gen(fallow_plot)
bys y4_hhid: egen nb_plots = count(fallow_plot)
merge m:1 y4_hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_plots= 0 if _merge ==2
keep y4_hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots_refresh.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${educ}", clear

recode hh_c03 (1 =1 "Yes") (2= 0 "No"), gen(formal_education) label(formal_education)
recode hh_c07 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education) label(primary_education)
replace primary_education= 0 if formal_education==0
replace primary_education= 1 if inrange(hh_c09, 18, 45) // this questions is for kids currently attending school
replace primary_education=0 if inrange(hh_c09, 1, 17)
replace primary_education = 1 if inrange(hh_c10, 17, 45)  // for kids who attended school last year
replace primary_education = 0 if inrange(hh_c10, 1, 16) | inlist(hh_c10,90, 91) 
replace primary_education = 0 if hh_c01==2

bys y4_hhid: egen hh_primary_education= max(primary_education) 
bys y4_hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(y4_hhid)
keep y4_hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education_refresh.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode hh_i17 (1 2 8 = 1 "Yes") (.=.)  (else = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
keep y4_hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access_refresh.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

rename hh_b04 age 
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort y4_hhid: egen dep=total(dep_temp)
bysort y4_hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep)
replace hh_dependency_ratio = dep if nondep==0

collapse (max)  hh_dependency_ratio, by(y4_hhid)
save "${Temp}\\${temppath}\\hh_dependency_ratio_refresh.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
drop if inlist(lvstckid, 15, 16) 
recode lf02_01 (1 = 1 "Yes") (2 . = 0 "No") , gen(livestock) label(livestock) 
collapse (max)  livestock, by(y4_hhid) 
merge 1:m y4_hhid using "${Input}\\${country}\\${wave}\\${harvest_rwdta}", keep(using match)
replace livestock= 0 if _merge==2
collapse (max) livestock, by(y4_hhid) 
save "${Temp}\\${temppath}\\livestock_refresh.dta", replace

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = expm/hhsize
xtile cons_quint= totcons, n(5)
keep y4_hhid cons_quint 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint_refresh.dta", replace

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = expm/hhsize
keep y4_hhid totcons
duplicates drop
save "${Temp}\\${temppath}\\totcons_refresh.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y4_hhid plotnum ), punct("-")
rename ag3a_09_1 manager_id
sort  y4_hhid (manager_id)
collapse (first) manager_id  , by(y4_hhid plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id = indidy4  // this is the HH member id 
merge 1:m  y4_hhid manager_id using `ID_list', keep(match ) nogen
rename manager_id id
egen manager_id = concat (y4_hhid id ), punct("-")
recode  hh_b02 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename hh_b04 age_manager
recode hh_b19 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1_refresh.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
gen manager_id =  indidy4  // this is the HH member id 
merge 1:m  y4_hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (y4_hhid id ), punct("-")

recode hh_c03 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode hh_c07 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager= 0 if formal_education_manager==0
replace primary_education_manager= 1 if inrange(hh_c09, 18, 45) 
replace primary_education_manager=0 if inrange(hh_c09, 1, 17)
replace primary_education_manager = 1 if inrange(hh_c10, 17, 45)
replace primary_education_manager = 0 if inrange(hh_c10, 1, 16) | inlist(hh_c10,90, 91)
replace primary_education_manager = 0 if hh_c01==2

keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2_refresh.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${meta}", clear 
rename ag_a09_2 respondent_id 
sort  y4_hhid (respondent_id)
collapse (first) respondent_id, by(y4_hhid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename indidy4 respondent_id // this is the HH member id 
merge 1:m  y4_hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (y4_hhid id ), punct("-")
recode  hh_b02 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename hh_b04 age_respondent
recode hh_b19 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married_respondent) 
keep y4_hhid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1_refresh.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
gen respondent_id = indidy4  // this is the HH member id 
merge 1:m  y4_hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (y4_hhid id ), punct("-")

recode hh_c03 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode hh_c07 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent= 0 if formal_education_respondent==0
replace primary_education_respondent= 1 if inrange(hh_c09, 18, 45) 
replace primary_education_respondent=0 if inrange(hh_c09, 1, 17)
replace primary_education_respondent = 1 if inrange(hh_c10, 17, 45)
replace primary_education_respondent = 0 if inrange(hh_c10, 1, 16) | inlist(hh_c10,90, 91)

keep y4_hhid primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2_refresh.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode hh_r01 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_shock) label(hh_shock)
collapse (max) hh_shock, by(y4_hhid) 
save "${Temp}\\${temppath}\\shock_refresh.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${csption}", clear
rename hhsize hh_size
keep y4_hhid hh_size
duplicates drop
save "${Temp}\\${temppath}\\size_refresh.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear

recode ag11_03 (1 = 1) (2 = 0) , gen(hh_owns_) 

/// observations are missing if the household does not own the asset
expand 15 if itemid==.
bys y4_hhid (itemid): gen n= _n
forval x=1/15{
	replace itemid = `x' if itemid==. & n==`x'
}
drop if inlist(itemid, 12, 15)
foreach var of varlist hh_owns_* { 
	replace `var'=0 if `var'==.
}

keep y4_hhid itemid hh_owns_ 
reshape wide hh_owns_ , i(y4_hhid) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep y4_hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index_refresh.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear

drop if itemcode>431 & itemcode<437 // drop agricultural assets
	drop if itemcode>439 
recode hh_m01 (0 = 0) (.= . ) (else=1), gen(hh_owns) label(hh_owns) 
	keep hh_owns y4_hhid itemcode
	reshape wide hh_owns , i(y4_hhid) j(itemcode)
	factor hh_owns*, pcf 
	predict hh_asset_index
keep y4_hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index_refresh.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
merge m:1 y4_hhid using "${Input}\\${country}\\${wave}\\${cover}",
recode entid ( . = 0 "No") (* = 1 "Yes"), gen(nonfarm_enterprise) label(nonfarm_enterprise)
collapse (max) nonfarm_enterprise , by(y4_hhid)
save "${Temp}\\${temppath}\\nfe_refresh.dta", replace

// latitude 
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
merge 1:m clusterid using "${Input}\\${country}\\${wave}\\${cover}",
keep y4_hhid lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords_refresh.dta", replace

// agro ecological zone (absent)

// distance to nearest road (absent)

// distance to nearest population center (absent)

// distance to nearest market  (absent)

// plot slope (absent)

// plot elevation (absent)

// plot distance to hh (absent)

// total wetness index (absent)

// soil variables (absent)

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (y4_hhid indidy4), punct("-")

recode  hh_b02 (2=1 "Yes") (1=0 "No"), gen(female) 
rename hh_b04 age
recode hh_b19 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married)
replace married = 0 if hh_b18==2
rename hh_b05 relationship_head_temp 
decode relationship_head_temp, gen(relationship_head)
replace relationship_head = proper(relationship_head)
replace relationship_head = "Son/Daughter" if relationship_head== "Step Son / Daughter"
replace relationship_head = "Servant" if relationship_head== "Live-In Servant"
replace relationship_head = "Non Relative" if relationship_head== "Other Non-Relatives (Specify)"
replace relationship_head = "Other Relative" if relationship_head== "Other Relative(Specify)"

keep y4_hhid ID married female age relationship_head  
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars_refresh.dta", replace


// wasting (confidential birth dates)


// labor 
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen ID = concat (y4_hhid indidy4), punct("-")

recode hh_e66 (0 = 0) (. = .) (else = 1), gen( farm_work)
replace farm_work = 0 if hh_e65==2
recode hh_e63 (1 = 1) (2 = 0) (.=.), gen( SOB_work)
recode hh_e08ab (1 = 1) (2 = 0) (.=.), gen( wage_work)
replace wage_work=0 if hh_e25==1

// industry:
gen 	ind_ag = hh_e21_2 == 1 | hh_e21_2==2 // Agriculture 
gen 	ind_fish = hh_e21_2==3 
gen 	ind_mining = hh_e21_2 == 8 | hh_e21_2==9 // mining
gen 	ind_manuf = hh_e21_2 >= 11 & hh_e21_2<=36 // manuf
gen 	ind_const = hh_e21_2 >= 41 & hh_e21_2<=43	// construc
gen 	ind_serv = hh_e21_2 >= 45 & hh_e21_2<= 4000	// services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
	replace `var' = 0 if hh_e04ab==2 // no wage employment
	replace `var' = 0 if hh_e05!=1 // remove apprenticeships
	}

gen wage_hrs1 = hh_e32 
replace wage_hrs1 = 0 if hh_e08ab==2
replace wage_hrs1 = 0 if hh_e25 == 1
gen wage_hrs2 = hh_e50 
replace wage_hrs2 = 0 if hh_e36==2
replace wage_hrs2 = 0 if hh_e43==1
egen wage_hrs = rowtotal(wage_hrs1 wage_hrs2), missing
rename (hh_e66 hh_e64  ) (farm_hrs SB_hrs  )
replace farm_hrs = 0 if hh_e65==2
replace SB_hrs = 0 if hh_e63==2


gen working_age = hh_e01==1 

foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}


keep ID y4_hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor_refresh.dta", replace

// education
use "${Input}\\${country}\\${wave}\\${educ}", clear

egen ID = concat (y4_hhid indidy4), punct("-")

recode hh_c03 (1 =1 "Yes") (2= 0 "No"), gen(formal_education) label(formal_education)
recode hh_c07 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education) label(primary_education)
replace primary_education= 0 if formal_education==0
replace primary_education= 1 if inrange(hh_c09, 18, 45) 
replace primary_education=0 if inrange(hh_c09, 1, 17)
replace primary_education = 1 if inrange(hh_c10, 17, 45)
replace primary_education = 0 if inrange(hh_c10, 1, 16) | inlist(hh_c10,90, 91)
replace primary_education = 0 if hh_c01==2
replace formal_education = 0 if hh_c01==2

keep ID y4_hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv_refresh.dta", replace


// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if hh_j01 ==1 // keep if consumed
rename itemcode food_id

gen A = food_id>=101 & food_id<=112
gen B = food_id>=201 & food_id<=207
gen C = food_id>=601 & food_id<=603
gen D = food_id>=701 & food_id<=704
gen E = food_id>=801 & food_id<=806 
gen F = food_id==807 
gen G = food_id>=808 & food_id<=810
gen H = food_id>=401 & food_id<=504
gen I = food_id>=901 & food_id<=903
gen J = food_id>=1001 & food_id<=1002
gen K = food_id>=301 & food_id<=303
gen L = food_id>=1003 & food_id<=1105 

collapse (max) A B C D E H I J K L, by(y4_hhid)
egen HDDS = rowtotal(A B C D E H I J K L), missing 

merge 1:m y4_hhid  using "${Input}\\${country}\\${wave}\\${HDDS}", 
collapse (max) HDDS, by(y4_hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS_refresh.dta", replace
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
global wave  NPS 12
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
global HDDS HH_SEC_J1.dta
global csption ConsumptionNPS3.dta
global items AG_SEC_11.dta
global items_hh HH_SEC_M.dta
global harvest_rwdta  AG_SEC_4A.dta
global harvest_sold_rwdta  AG_SEC_5A.dta
global geovars_hh HouseholdGeovars_Y3.dta
global geovars PlotGeovars_Y3.dta
global livestock LF_SEC_02.dta
global nfe HH_SEC_N.dta
global anthropo  HH_SEC_V.dta
global meta AG_SEC_01.dta
global temppath TZA\NPS12



**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${perennial_fruit}", clear
decode zaocode, gen(name_fruit)
keep y3_hhid plotnum zaocode name_fruit
tempfile perennial_fruit
save `perennial_fruit', replace
use "${Input}\\${country}\\${wave}\\${perennial}", clear
decode zaocode, gen(name_per)
keep y3_hhid plotnum zaocode name_per
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using `perennial_fruit', nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using `perennial', nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id= concat(y3_hhid plotnum) , punct("-")
decode zaocode, gen(crop_name)
replace crop_name = substr(crop_name, strpos(crop_name, " ")+1, .)
replace crop_name = name_fruit if crop_name==""
replace crop_name = name_per if crop_name==""
keep y3_hhid plot_id crop_name zaocode 
duplicates drop

duplicates tag plot_id crop_name, gen(tag)
decode zaocode, gen(cropname2)
replace crop_name = cropname2 if tag>0
duplicates report plot_id zaocode crop_name
replace crop_name = "OTHER" if crop_name=="(SPECIFY)"

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
keep y3_hhid 
duplicates report y3_hhid 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (y3_hhid indidy3), punct("-")
keep y3_hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
bys y3_hhid (y2_hhid): replace y2_hhid = y2_hhid[_N] 
keep y2_hhid y3_hhid
duplicates drop
merge 1:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", nogen
merge m:1 y2_hhid using "${Temp}\\TZA\NPS10\\ea_id.dta", nogen keep(master match)
keep y3_hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear 
keep y3_hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename hh_a01_1 admin_1
rename hh_a01_2 admin_1_name
keep y3_hhid admin_1  admin_1_name
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_2 = concat(hh_a01_1 hh_a02_1), punct("-")
replace admin_2 = "" if hh_a02_1==. | hh_a01_1==.
rename hh_a02_2 admin_2_name
keep y3_hhid admin_2 admin_2_name
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_3 = concat(hh_a01_1 hh_a02_1 hh_a03_1), punct("-")
replace admin_3 = "" if hh_a03_1==. | hh_a02_1==. | hh_a01_1==.
keep y3_hhid admin_3 
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
recode y3_rural (0 = 1 "Yes") (1 = 0 "No"), gen(urban) label(urban)
keep y3_hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename y3_weight pw
keep pw y3_hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month (absent)

// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
rename _merge _mergefruit
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", 
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
rename _merge _mergeper

egen plot_id= concat(y3_hhid plotnum) , punct("-")

gen month = ag4a_24_2
format month %tm
replace month=. if ag4a_24_2==0

gen year = 2013
replace year= 2012 if inlist(ag4a_24_2, 11, 12)
format year %ty
replace year = ag6a_07_3 if _mergefruit==2 & ag6a_07_3>1900
replace year = ag6b_07_3 if _mergeper==2 & ag6b_07_3>1900
replace month = 12 if ag6a_07_3!=.
replace month = 12 if ag6b_07_3!=.

gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(y3_hhid plot_id zaocode)
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen month = hh_a18_2
format month %tm 
gen year = hh_a18_3
format year %ty 

gen harvest_interview_month = ym( year, month)
format harvest_interview_month %tmCCYYMon
keep y3_hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace


// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge m:1 y3_hhid using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 
egen plot_id= concat(y3_hhid plotnum) , punct("-")


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
collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id zaocode admin_1 admin_2 admin_3 ea_id y3_hhid)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id= concat(y3_hhid plotnum) , punct("-")

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

collapse (max) crop_shock pests_shock  drought_shock, by( y3_hhid plot_id     zaocode )
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y3_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y3_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge m:1 y3_hhid using "${Temp}\\${temppath}\\ea_id.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta",  nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_kg_seas = ag5a_02
replace harvest_sold_kg_seas= 0 if ag5a_01==2

gen harvest_sold_kg_per = ag7a_03
replace harvest_sold_kg_per= 0 if ag7a_02==2

gen harvest_sold_kg_fruit = ag7b_03
replace harvest_sold_kg_fruit= 0 if ag7b_02==2

egen harvest_sold_kg = rowtotal(harvest_sold_kg_seas harvest_sold_kg_per harvest_sold_kg_fruit), missing


collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( zaocode y3_hhid admin_1 admin_2 admin_3)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(y3_hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m y3_hhid using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(y3_hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep y3_hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace

// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y3_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y3_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge m:1 y3_hhid using "${Temp}\\${temppath}\\ea_id.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_value_seas = ag5a_03
gen harvest_sold_value_per  = ag7a_04
gen harvest_sold_value_fruit  = ag7b_04

egen harvest_sold_value = rowtotal(harvest_sold_value_seas harvest_sold_value_per harvest_sold_value_fruit), missing

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( zaocode y3_hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y3_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
merge 1:m y3_hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
drop occ zaoname
duplicates drop
duplicates tag y3_hhid zaocode, gen(tag)
drop if tag>0
drop tag
keep y3_hhid  zaocode 
duplicates drop

valuation_median_crops_noea_sort y3_hhid    zaocode

main_crop_def zaocode


keep plot_id harvest_value zaocode main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
drop if plotnum==""
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id= concat(y3_hhid plotnum) , punct("-")

recode ag4a_04 (1 =1 "Yes") (2=0 "No"), gen(intercropped_seas) label(intercropped)
recode ag6a_05 (1 =1 "Yes") (2=0 "No"), gen(intercropped_fruit) label(intercropped)
recode ag6b_05 (1 =1 "Yes") (2=0 "No"), gen(intercropped_per) label(intercropped)
egen intercropped = rowmax(intercropped_seas intercropped_fruit intercropped_per)

keep zaocode plot_id intercropped
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
rename _merge _mergefruit
merge 1:m y3_hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", 
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id = concat( y3_hhid plotnum), punct("-")
replace zaocode = . if _mergefruit==2 | _merge==2
bys  plot_id : egen nb_seasonal_crop = count(zaocode)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
tempfile perennial_nodups
save `perennial_nodups', replace
use "${Input}\\${country}\\${wave}\\${perennial_fruit}", clear
duplicates tag y3_hhid plotnum zaocode,gen(t)
drop if t>0
drop t
tempfile perennial_fruit_nodups
save `perennial_fruit_nodups', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
drop occ plotname zaoname
drop if plotnum==""
merge m:1 y3_hhid plotnum zaocode using `perennial_fruit_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codeszaocode1)
drop _merge
merge m:1 y3_hhid plotnum zaocode using `perennial_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codeszaocode2)
drop _merge
egen plot_id = concat( y3_hhid plotnum), punct("-")

merge m:1 zaocode plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen


rename  zaocode  tempname
rename main_crop zaocode 
merge m:1 y3_hhid plotnum zaocode using `perennial_fruit_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codesmain_crop1)
drop _merge
merge m:1 y3_hhid plotnum zaocode using `perennial_nodups', 
drop if plotnum==""
recode _merge (2 = 1) (3 1 = 0), gen(codesmain_crop2)
drop _merge
rename  zaocode  main_crop
rename  tempname zaocode

bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if zaocode==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

foreach c in main_crop zaocode {
lab val `c' zaocode
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

collapse (sum) share_crop* (max) contains_crop_* , by(plot_id main_crop maincrop_valueshare) 
save "${Temp}\\${temppath}\\main_crop.dta", replace

// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat(y3_hhid plotnum) , punct("-")

gen area_self_reported = ag2a_04 * 0.404686

gen plot_area_GPS= ag2a_09 * 0.404686 // acres to ha 

merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

isid y3_hhid plot_id
sort y3_hhid plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi tsset, clear 
encode admin_3, gen(admin_3_cd)
mi impute pmm plot_area_GPS area_self_reported i.admin_3_cd, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys y3_hhid: egen farm_size = total(plot_area_GPS), missing

keep y3_hhid plot_id   plot_area_GPS farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// improved 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id= concat(y3_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
collapse (max) improved  ,by(plot_id zaocode)
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 y3_hhid using "${Temp}\\${temppath}\\ea_id.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 
egen plot_id= concat(y3_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
gen seed_kg = ag4a_10_1 if ag4a_10_2==1 // cannot convert many units
collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by( admin_1 admin_2 admin_3 plot_id zaocode ea_id improved)
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg.dta", replace
collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by(plot_id zaocode ea_id )
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace

// seed_kg_sold 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id= concat(y3_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
gen seeds_amount_purchased_kg = ag4a_10_1 if ag4a_10_2==1 & ag4a_14==2 
collapse (max) improved (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg=seeds_amount_purchased_kg  ,by(plot_id y3_hhid zaocode)
replace seeds_amount_purchased_kg=. if n_seeds_amount_purchased_kg==0
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

egen plot_id= concat(y3_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)
gen seed_value_temp = ag4a_12
collapse (sum) seed_value_temp (count) n_seed_value_temp=seed_value_temp  ,by(plot_id y3_hhid zaocode improved)
replace seed_value_temp=. if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 
egen plot_id= concat(y3_hhid plotnum) , punct("-")
recode ag4a_08 (1 3 = 1 "Yes") (2 = 0 "No") (4=.), gen(improved) label(improved)

keep y3_hhid plot_id zaocode improved
duplicates drop

valuation_median_seeds_noea y3_hhid plot_id zaocode 

keep  plot_id zaocode seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")

egen hired_labor_days1 = rowtotal(ag3a_74_1 ag3a_74_2 ag3a_74_3), missing 
replace hired_labor_days1= 0 if ag3a_73==2

egen hired_labor_days2 = rowtotal(ag3a_74_5 ag3a_74_6 ag3a_74_7), missing  
replace hired_labor_days2= 0 if ag3a_73==2

egen hired_labor_days3 = rowtotal(ag3a_74_9 ag3a_74_10 ag3a_74_11), missing 
replace hired_labor_days3= 0 if ag3a_73==2

egen hired_labor_days4 = rowtotal(ag3a_74_13 ag3a_74_14 ag3a_74_15), missing 
replace hired_labor_days4= 0 if ag3a_73==2

egen total_hired_labor_days = rowtotal(hired_labor_days*), missing

egen wage_total = rowtotal(ag3a_74_4 ag3a_74_8 ag3a_74_12 ag3a_74_16), missing
gen wage = wage_total/total_hired_labor_days

valuation_median_wages y3_hhid wage wage wage

gen hired_labor_value = child_wage * total_hired_labor_days // all wages are equal

foreach n of numlist 1/18  {
egen ID`n' = concat(y3_hhid ag3a_72_id`n'), punct("-")
gen ID_worker`n'_PP = ID`n' if  ag3a_72_id`n' !=.
}


forvalues n = 19/24 {
egen ID`n' = concat(y3_hhid ag3a_72_id`n'), punct("-")
local h = `n' - 18
gen ID_worker`h'_PH = ID`h' if  ag3a_72_id`n' !=.
}

drop ag3a_72_id* ag3a_72_25 ag3a_72_26 ag3a_72_27 ag3a_72_28
egen total_family_labor_days = rowtotal(ag3a_72_*), missing

egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days), missing

keep total_labor_days plot_id total_family_labor_days total_hired_labor_days hired_labor_value ID_worker*
duplicates drop
save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid plotnum), punct("-")
recode ag3a_47 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 
egen plot_id = concat( y3_hhid plotnum), punct("-") 

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

collapse (sum) nitrogen_kg  fert_kg   (count) n_nitrogen_kg = nitrogen_kg n_fert_kg = fert_kg   , by(plot_id y3_hhid admin_1 admin_2 admin_3)
foreach var in nitrogen_kg fert_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 y3_hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 
egen plot_id = concat(y3_hhid plotnum), punct("-") 
isid plot_id

egen fert_purchased_value = rowtotal(ag3a_51 ag3a_58), missing
egen fert_purchased_kg = rowtotal(ag3a_49 ag3a_56), missing

valuation_median_fert_price_noea y3_hhid fert

keep admin_1 admin_2 admin_3 fert_value
duplicates drop

drop if fert_value==.
merge 1:m admin_1 admin_2 admin_3 using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

foreach n in fert  {
gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing
replace inorganic_fertilizer_value = 0 if nitrogen_kg==0

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-") 
recode ag3a_41 (1= 1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")
recode ag3a_61 (1= 1 "Yes") (.=.)  (else = 0 "No") , gen(used_pesticides) label(used_pesticides)
replace used_pesticides= 1 if ag3a_60==1
replace used_pesticides= 0 if ag3a_60==2
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")
recode ag3a_25 ( 1 5  = 1 "Yes") (.=.) (else = 0 "No") , gen(plot_owned) label(plot_owned) 
recode ag3a_28 (9 10 11 = 0 "No") (.=.)  (else = 1 "Yes"), gen(plot_certificate) label(plot_certificate)
replace plot_certificate=0 if plot_owned==0
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")
recode  ag3a_18 (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")
recode ag3a_15 (1 = 1 "Yes") (2=0 "No"), gen(erosion_protection)  label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
gen tractor= 1 if ag11_04==1 & inlist(itemid,6, 7, 8) 
replace tractor= 1 if ag11_06==1 & inlist(itemid,6, 7, 8) 
replace tractor= 0 if !inlist(itemid,6, 7, 8) 
collapse (max) tractor , by(y3_hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")
recode ag3a_03 (4 = 1) (. = .)  (* = 0) , gen(fallow_plot)
bys y3_hhid: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_fallow_plots= 0 if _merge ==2
keep y3_hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")
recode ag3a_03 (4 = 1) (. = .)  (* = 0) , gen(fallow_plot)
bys y3_hhid: egen nb_plots = count(fallow_plot)
merge m:1 y3_hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_plots= 0 if _merge ==2	
keep y3_hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

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

bys y3_hhid: egen hh_primary_education= max(primary_education) 
bys y3_hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(y3_hhid)
keep y3_hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode hh_i17 (1 2 8 = 1 "Yes") (.=.)  (else = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
keep y3_hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

rename hh_b04 age 
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort y3_hhid: egen dep=total(dep_temp)
bysort y3_hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep  if nondep==0

collapse (max)  hh_dependency_ratio, by(y3_hhid)
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
drop if inlist(lvstckid, 15, 16) 
drop if lf02_01==. 
recode lf02_01 (1 = 1 "Yes") (2 = 0 "No") , gen(livestock) label(livestock) 
collapse (max)  livestock, by(y3_hhid) 
merge 1:m y3_hhid using "${Input}\\${country}\\${wave}\\${harvest_rwdta}", keep(using match)
replace livestock= 0 if _merge==2
collapse (max) livestock, by(y3_hhid) 
save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = expm/hhsize
xtile cons_quint= totcons, n(5)
keep y3_hhid cons_quint 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = expm/hhsize
keep y3_hhid totcons
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(y3_hhid plotnum ), punct("-")
rename ag3a_09_1 manager_id
replace manager_id=. if manager_id==99
sort  y3_hhid (manager_id)
collapse (first) manager_id  , by(y3_hhid plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id = indidy3  // this is the HH member id 
merge 1:m  y3_hhid manager_id using `ID_list', keep(match ) nogen
rename manager_id id
egen manager_id = concat (y3_hhid id ), punct("-")
recode  hh_b02 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename hh_b04 age_manager
recode hh_b19 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
gen manager_id =  indidy3  // this is the HH member id 
merge 1:m  y3_hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (y3_hhid id ), punct("-")

recode hh_c03 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode hh_c07 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager= 0 if formal_education_manager==0
replace primary_education_manager= 1 if inrange(hh_c09, 18, 45) 
replace primary_education_manager=0 if inrange(hh_c09, 1, 17)
replace primary_education_manager = 1 if inrange(hh_c10, 17, 45)
replace primary_education_manager = 0 if inrange(hh_c10, 1, 16) | inlist(hh_c10,90, 91)

keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${meta}", clear 
gen respondent_id= indidy3 if ag01_04=="X"
sort  y3_hhid (respondent_id)
collapse (first) respondent_id, by(y3_hhid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename indidy3 respondent_id // this is the HH member id 
merge 1:m  y3_hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (y3_hhid id ), punct("-")
recode  hh_b02 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename hh_b04 age_respondent
recode hh_b19 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married_respondent) 
keep y3_hhid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
gen respondent_id = indidy3  // this is the HH member id 
merge 1:m  y3_hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (y3_hhid id ), punct("-")

recode hh_c03 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode hh_c07 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent= 0 if formal_education_respondent==0
replace primary_education_respondent= 1 if inrange(hh_c09, 18, 45) 
replace primary_education_respondent=0 if inrange(hh_c09, 1, 17)
replace primary_education_respondent = 1 if inrange(hh_c10, 17, 45)
replace primary_education_respondent = 0 if inrange(hh_c10, 1, 16) | inlist(hh_c10,90, 91)

keep y3_hhid primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear

recode hh_r01 (1= 1 "Yes") (2=0 "No"), gen(hh_shock) label(hh_shock)
replace hh_shock=0 if !inlist(hh_r05_1, 2012, 2013)
replace hh_shock=1 if hh_r05_1==2011 & inlist(hh_r05_2, 10, 11, 12)
collapse (max) hh_shock, by(y3_hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${csption}", clear
rename hhsize hh_size
keep y3_hhid hh_size
duplicates drop
save "${Temp}\\${temppath}\\size.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear

recode ag11_03 (1 = 1) (2 = 0) , gen(hh_owns_) 

/// observations are missing if the household does not own the asset
expand 15 if itemid==.
bys y3_hhid (itemid): gen n= _n
forval x=1/15{
	replace itemid = `x' if itemid==. & n==`x'
}
drop if inlist(itemid, 12, 15)
foreach var of varlist hh_owns_* { 
	replace `var'=0 if `var'==.
}

keep y3_hhid itemid hh_owns_ 
reshape wide hh_owns_ , i(y3_hhid) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep y3_hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear

drop if itemcode>431 & itemcode<437 // drop agricultural assets
	drop if itemcode>439 
recode hh_m01 (0 = 0) (.= . ) (else=1), gen(hh_owns) label(hh_owns) 
	keep hh_owns y3_hhid itemcode
	reshape wide hh_owns , i(y3_hhid) j(itemcode)
	factor hh_owns*, pcf 
	predict hh_asset_index
keep y3_hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
recode entid ( . = 0 "No") (* = 1 "Yes"), gen(nonfarm_enterprise) label(nonfarm_enterprise)
collapse (max) nonfarm_enterprise , by(y3_hhid)
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude 
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename (lat_dd_mod lon_dd_mod) (lat_modified lon_modified)
keep y3_hhid lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear

rename land03 agro_ecological_zone
keep y3_hhid agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist01  dist_road
keep y3_hhid dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist02 dist_popcenter
keep y3_hhid dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace

// distance to nearest market (none)
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist03 dist_market
keep y3_hhid dist_market
duplicates drop
save "${Temp}\\${temppath}\\dist_market.dta", replace

// plot slope
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename soil02 plot_slope
keep y3_hhid plot_slope
duplicates drop
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot elevation
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename soil01 elevation
keep y3_hhid elevation
duplicates drop
save "${Temp}\\${temppath}\\elevation.dta", replace

// plot distance to hh
use "${Input}\\${country}\\${wave}\\${geovars}", clear
egen plot_id = concat( y3_hhid plotnum), punct("-")
rename plot01 plot_dist_household
keep plot_id plot_dist_household
duplicates drop
save "${Temp}\\${temppath}\\plot_distance.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
rename soil03 twi
keep y3_hhid twi
duplicates drop
save "${Temp}\\${temppath}\\twi.dta", replace

// soil variables
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
local run = 5 
foreach i in 05 06 07 08 09 10 11 {
local num  = `run' - 4
recode soil`i' (1=1) (0 2/7=0), gen(sq`num'_d)
local ++run
}
factor sq1_d-sq7_d, pcf 
predict soil_fertility_index

local names "nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability"
forvalues n =1/7 {
local lab: word `n' of `names'
rename sq`n'_d `lab'
}

keep y3_hhid  nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index
duplicates drop
save "${Temp}\\${temppath}\\soil.dta", replace

// popdensity
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
rename land04 popdensity
keep y3_hhid popdensity
duplicates drop
save "${Temp}\\${temppath}\\popdensity.dta", replace

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (y3_hhid indidy3), punct("-")

recode  hh_b02 (2=1 "Yes") (1=0 "No"), gen(female) 
rename hh_b04 age
recode hh_b19 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married)
replace married = 0 if  hh_b18==2
rename hh_b05 relationship_head_temp 
decode relationship_head_temp, gen(relationship_head)
replace relationship_head = proper(relationship_head)
replace relationship_head = "Son/Daughter" if relationship_head== "Step Son / Daughter"
replace relationship_head = "Servant" if relationship_head== "Live-In Servant"
replace relationship_head = "Non Relative" if relationship_head== "Other Non-Relatives (Specify)"
replace relationship_head = "Other Relative" if relationship_head== "Other Relative(Specify)"

// month of birth
gen birth_month= ym(hh_b03_1 ,hh_b03_2)
format birth_month %tm 

keep y3_hhid ID married female age relationship_head  birth_month
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${anthropo}", clear
egen ID = concat (y3_hhid indidy3 ), punct("-")
merge 1:1 y3_hhid ID using "${Temp}\\${temppath}\\indiv_chars.dta",  keep(master match) nogen
merge m:1 y3_hhid  using "${Temp}\\${temppath}\\harvest_interview_month.dta",  keep(master match) nogen

// age in months
gen age_months = harvest_interview_month - birth_month

*Main anthropometric variables
gen weight= hh_v03
gen height= hh_v04

gen cage=age*12
replace cage = age_months if age==0| age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  y3_hhid ID weight height
duplicates drop
save "${Temp}\\${temppath}\\wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear
egen ID = concat (y3_hhid indidy3), punct("-")

recode hh_e69 (0 = 0) (. = .) (else = 1), gen( farm_work)
replace farm_work = 0 if hh_e65==2
recode hh_e63 (1 = 1) (2 = 0) (.=.), gen( SOB_work)
recode hh_e08b (1 = 1) (2 = 0) (.=.), gen( wage_work)

// industry:
gen 	ind_ag = hh_e21_2 == 1 | hh_e21_2==2 // Agriculture 
gen 	ind_fish = hh_e21_2==3 
gen 	ind_mining = hh_e21_2 == 8 | hh_e21_2==9 // mining
gen 	ind_manuf = hh_e21_2 >= 11 & hh_e21_2<=36 // manuf
gen 	ind_const = hh_e21_2 >= 41 & hh_e21_2<=43	// construc
gen 	ind_serv = hh_e21_2 >= 45 & hh_e21_2<= 4923	// services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
	replace `var' = 0 if hh_e04b==2 // no wage employment
	}

gen wage_hrs1 = hh_e32 
replace wage_hrs1 = 0 if hh_e17==3
replace wage_hrs1 = 0 if hh_e08b == 2
gen wage_hrs2 = hh_e50 
replace wage_hrs2 = 0 if hh_e36==2
replace wage_hrs2 = 0 if hh_e08b == 2
egen wage_hrs = rowtotal(wage_hrs1 wage_hrs2), missing
rename (hh_e69 hh_e64  ) (farm_hrs SB_hrs  )
replace farm_hrs = 0 if hh_e65==2
replace SB_hrs = 0 if hh_e63==2

gen working_age = hh_e01 ==1

foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}

keep ID y3_hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education
use "${Input}\\${country}\\${wave}\\${educ}", clear

egen ID = concat (y3_hhid indidy3), punct("-")

recode hh_c03 (1 =1 "Yes") (2= 0 "No"), gen(formal_education) label(formal_education)
recode hh_c07 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education) label(primary_education)
replace primary_education= 0 if formal_education==0
replace primary_education= 1 if inrange(hh_c09, 18, 45) 
replace primary_education=0 if inrange(hh_c09, 1, 17)
replace primary_education = 1 if inrange(hh_c10, 17, 45)
replace primary_education = 0 if inrange(hh_c10, 1, 16) | inlist(hh_c10,90, 91)
replace primary_education = 0 if hh_c01==2
replace formal_education = 0 if hh_c01==2

keep ID y3_hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace


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

collapse (max) A B C D E H I J K L, by(y3_hhid)
egen HDDS = rowtotal(A B C D E H I J K L), missing 

merge 1:m y3_hhid  using "${Input}\\${country}\\${wave}\\${HDDS}", 
collapse (max) HDDS, by(y3_hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace
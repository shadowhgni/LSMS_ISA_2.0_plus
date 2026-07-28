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
global wave  NPS 08
global cover  SEC_A_T.dta
global indiv_roster  SEC_B_C_D_E1_F_G1_U.dta
global plot_inputs SEC_3A.dta
global shocks SEC_R.dta
global housing  SEC_H1_J_K2_O2_P1_Q1_S1.dta
global plot_roster  SEC_2A.dta
global perennial_fruit SEC_6A.dta
global perennial SEC_6B.dta
global perennial_fruit_sell SEC_7A.dta
global perennial_sell SEC_7B.dta
global csption TZY1.HH.Consumption.dta
global items SEC_11_ALL.dta
global items_hh SEC_N.dta
global harvest_rwdta  SEC_4A.dta
global harvest_sold_rwdta  SEC_5A.dta
global geovars_hh HH.Geovariables_Y1.dta
global geovars Plot.Geovariables_Y1_revised2.dta
global livestock SEC_10A.dta
global meta SEC_1_ALL.dta
global temppath TZA\NPS08
global HDDS SEC_K1.dta


**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************
 
// plot-crop frame
use "${Input}\\${country}\\${wave}\\${perennial_fruit}", clear
decode zaocode, gen(name_fruit)
keep hhid plotnum zaocode name_fruit
tempfile perennial_fruit
save `perennial_fruit', replace
use "${Input}\\${country}\\${wave}\\${perennial}", clear
decode zaocode, gen(name_per)
keep hhid plotnum zaocode name_per
tempfile perennial
save `perennial', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:1 hhid plotnum zaocode using `perennial_fruit', nogen
merge 1:m hhid plotnum zaocode using `perennial', nogen
egen plot_id= concat(hhid plotnum) , punct("-")
decode zaocode, gen(crop_name)
replace crop_name = name_fruit if crop_name==""
replace crop_name = name_per if crop_name==""
keep hhid plot_id crop_name zaocode 

duplicates drop

duplicates tag plot_id crop_name, gen(tag)
decode zaocode, gen(cropname2)
replace crop_name = cropname2 if tag>0


replace crop_name = "OTHER" if crop_name=="(SPECIFY)"

replace crop_name = strupper(crop_name)
replace crop_name = strtrim(crop_name)
replace crop_name = stritrim(crop_name)
duplicates report plot_id  crop_name


save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
keep hhid 
duplicates report hhid 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hhid sbmemno), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen ea_id = concat(region district ward ea), punct("-")
replace ea_id="" if ea==. | ward==. | district==. |region==. 
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear 
keep hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename region admin_1
keep hhid admin_1  
decode admin_1, gen(admin_1_name)
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_2 = concat(region district), punct("-")
replace admin_2="" if district==. |region==.
keep hhid admin_2
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_3 = concat(region district ward), punct("-")
replace admin_3="" if ward==. | district==. | region==.
keep hhid admin_3
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen urban= 1 if rural=="Urban"
replace urban=0 if rural=="Rural"
lab def urban 1 "Yes" 0 "No"
keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename hh_weight pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month (absent)

// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:1 hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
rename _merge _mergefruit
merge 1:m hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", 
rename _merge _mergeper

egen plot_id= concat(hhid plotnum) , punct("-")
gen month = s4aq11_2
format month %tm
replace month=. if s4aq11_2==0

gen year = 2009
replace year= 2008 if inlist(s4aq11_2, 11, 12)
format year %ty
replace year = s6aq3 if _mergefruit==2 & s6aq3>1900
replace year = s6bq3 if _mergeper==2 & s6bq3>1900
replace month = 12 if s6aq3!=.
replace month = 12 if s6bq3!=.

gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(hhid zaocode plot_id) 
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen month = sa2q18m
format month %tm 
gen year = sa2q18y
format year %ty 

gen harvest_interview_month = ym( year, month)
format harvest_interview_month %tmCCYYMon
keep hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month (absent)

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:1 hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
merge 1:m hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
merge m:1 hhid using "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 
egen plot_id= concat(hhid plotnum) , punct("-")

gen harvest_kg_seas= s4aq15 
replace harvest_kg_seas = 0 if s4aq1==2
gen harvest_kg_per = s6aq8 
gen harvest_kg_fruit = s6bq8 
egen harvest_kg = rowtotal(harvest_kg_seas  harvest_kg_per harvest_kg_fruit), missing

recode s4aq17 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_seas) label(crop_shock)
replace crop_shock_seas=1 if !mi(s4aq10) & s4aq10!=9 // pre harvest losses
replace crop_shock_seas = 1 if s4aq2==3
recode s6aq9 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_fruit) label(crop_shock)
recode s6bq9 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_per) label(crop_shock)
egen crop_shock = rowmax(crop_shock_seas  crop_shock_fruit crop_shock_per)

replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 
collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id zaocode admin_1 admin_2 admin_3 ea_id hhid)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:1 hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
merge 1:m hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
egen plot_id= concat(hhid plotnum) , punct("-")

recode s4aq17 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_seas) label(crop_shock)
replace crop_shock_seas=1 if !mi(s4aq10) & s4aq10!=9 // pre harvest losses
replace crop_shock_seas = 1 if s4aq2==3
recode s6aq9 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_fruit) label(crop_shock)
recode s6bq9 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock_per) label(crop_shock)
egen crop_shock = rowmax(crop_shock_seas  crop_shock_fruit crop_shock_per)

recode s4aq10 (1 = 1 "Yes") (2/9 = 0 "No"), gen(drought_shock1) label(drought_shock) 
recode s4aq5 (2 = 1 "Yes") (1 3/9 = 0 "No"), gen(drought_shock2) label(drought_shock) 
replace drought_shock1=0 if s4aq9==2
replace drought_shock2=0 if s4aq3==1
gen drought_shock= 1 if drought_shock1==1 | drought_shock2==1
replace drought_shock=0 if (drought_shock1==0 & drought_shock2==0 )

recode s4aq10 (4 = 1 "Yes") (1/3 5/9 = 0 "No"), gen(pests_shock1) label(pests_shock) 
recode s4aq18 (3 = 1 "Yes") (1 2 4/9 = 0 "No"), gen(pests_shock2) label(pests_shock) 
replace pests_shock1=0 if s4aq9==2
replace pests_shock2=0 if s4aq17==2
gen pests_shock= 1 if pests_shock1==1 | pests_shock2==1
replace pests_shock=0 if (pests_shock1==0 & pests_shock2==0 )
recode s6aq10 (1 2 3 = 1 "Yes") (4/9 = 0 "No"), gen(pests_shock_fruit) label(crop_shock)
replace pests_shock_fruit = 0 if s6aq9==2
recode s6bq10 (1 2 3 = 1 "Yes") (4/9 = 0 "No"), gen(pests_shock_per) label(crop_shock)
replace pests_shock_per = 0 if s6bq9==2
egen pests_shock_combin = rowmax(pests_shock  pests_shock_fruit pests_shock_per)
replace pests_shock = pests_shock_combin


keep hhid plot_id crop_shock pests_shock  drought_shock   zaocode  
duplicates drop
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
merge m:1 hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
merge 1:m hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen

merge m:1 hhid using "${Temp}\\${temppath}\\ea_id.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta",  nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_kg_seas = s5aq2
replace harvest_sold_kg_seas= 0 if s5aq1==2

gen harvest_sold_kg_per = s7aq3
replace harvest_sold_kg_per= 0 if s7aq2==2

gen harvest_sold_kg_fruit = s7bq3
replace harvest_sold_kg_fruit= 0 if s7bq2==2

egen harvest_sold_kg = rowtotal(harvest_sold_kg_seas harvest_sold_kg_per harvest_sold_kg_fruit), missing

collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( zaocode hhid admin_1 admin_2 admin_3)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m hhid using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace


// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
merge m:1 hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
merge 1:m hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
merge m:1 hhid using "${Temp}\\${temppath}\\ea_id.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_value_seas = s5aq3
gen harvest_sold_value_per  = s7aq4
gen harvest_sold_value_fruit  = s7bq4

egen harvest_sold_value = rowtotal(harvest_sold_value_seas harvest_sold_value_per harvest_sold_value_fruit), missing


collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( zaocode hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
merge m:1 hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit_sell}", nogen
merge 1:m hhid  zaocode using "${Input}\\${country}\\${wave}\\${perennial_sell}", nogen
keep hhid  zaocode 
duplicates drop

valuation_median_crops hhid  hhid  zaocode

main_crop_def zaocode

keep plot_id harvest_value zaocode main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:1 hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", nogen
merge 1:m hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", nogen
egen plot_id= concat(hhid plotnum) , punct("-")
recode s4aq6 (1 =1 "Yes") (2=0 "No"), gen(intercropped_seas) label(intercropped)
recode s6aq5 (1 =1 "Yes") (2=0 "No"), gen(intercropped_fruit) label(intercropped)
recode s6bq5 (1 =1 "Yes") (2=0 "No"), gen(intercropped_per) label(intercropped)
egen intercropped = rowmax(intercropped_seas intercropped_fruit intercropped_per)

keep zaocode plot_id intercropped
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:1 hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
rename _merge _mergefruit
merge 1:m hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial}", 
egen plot_id = concat( hhid plotnum), punct("-")
replace zaocode = . if _mergefruit==2 | _merge==2
bys  plot_id : egen nb_seasonal_crop = count(zaocode)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${perennial}", clear
duplicates tag hhid plotnum zaocode,gen(t)
drop if t>0
drop t
tempfile perennial_nodups
save `perennial_nodups', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
recode _merge (2 = 1) (3 1 = 0), gen(codeszaocode1)
drop _merge
merge m:1 hhid plotnum zaocode using `perennial_nodups', 
recode _merge (2 = 1) (3 1 = 0), gen(codeszaocode2)
drop _merge
duplicates tag hhid plotnum zaocode,gen(t)
drop if t>0
drop t
egen plot_id = concat( hhid plotnum), punct("-")

merge m:1 zaocode plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen

rename  zaocode  tempname
rename main_crop zaocode 
merge m:1 hhid plotnum zaocode using "${Input}\\${country}\\${wave}\\${perennial_fruit}", 
recode _merge (2 = 1) (3 1 = 0), gen(codesmain_crop1)
drop _merge
merge m:1 hhid plotnum zaocode using `perennial_nodups', 
recode _merge (2 = 1) (3 1 = 0), gen(codesmain_crop2)
drop _merge
rename  zaocode  main_crop
rename  tempname zaocode

bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if zaocode==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

foreach c in main_crop zaocode {
lab val `c' S4AZAOCODE
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



foreach n in 9  8 7 6 5 4 {
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

collapse (sum) share_crop* (max) contains_crop_*  , by(plot_id main_crop maincrop_valueshare) 
save "${Temp}\\${temppath}\\main_crop.dta", replace

// share of plot area planted by crop 

// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id= concat(hhid plotnum) , punct("-")
gen area_self_reported = s2aq4 * 0.404686

gen plot_area_GPS= area * 0.404686 

merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

isid hhid plot_id
sort hhid plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi tsset, clear 
encode admin_3, gen(admin_3_cd)
mi impute pmm plot_area_GPS area_self_reported i.admin_3_cd, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys hhid: egen farm_size = total(plot_area_GPS), missing

keep hhid plot_id   plot_area_GPS farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// improved (absent)

// seed kg (only purchased seeds)

// seed_kg_sold (only purchased seeds)


// seed_value_sold (only purchased seeds)

// seed value 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 
egen plot_id= concat(hhid plotnum) , punct("-")

gen seed_value = s4aq20

keep  plot_id zaocode seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")

egen total_hired_labor_days = rowtotal(s3aq63_1 s3aq63_2 s3aq63_4 s3aq63_5 s3aq63_7 s3aq63_8), missing
replace total_hired_labor_days= 0 if s3aq62==2

egen total_family_labor_days = rowtotal(s3aq61_1 s3aq61_2 s3aq61_3 s3aq61_4 s3aq61_5 s3aq61_6 s3aq61_7 s3aq61_8 s3aq61_9 s3aq61_10 s3aq61_11 s3aq61_12 s3aq61_13 s3aq61_14 s3aq61_15 s3aq61_16 s3aq61_17 s3aq61_18 s3aq61_19 s3aq61_20 s3aq61_21 s3aq61_22 s3aq61_23 s3aq61_24 s3aq61_25 s3aq61_26 s3aq61_27 s3aq61_28 s3aq61_29 s3aq61_30 s3aq61_31 s3aq61_32 s3aq61_33 s3aq61_34 s3aq61_35 s3aq61_36), missing

egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days), missing

egen wage_total = rowtotal(s3aq63_3 s3aq63_6 s3aq63_9), missing
gen wage = wage_total/total_hired_labor_days

valuation_median_wages hhid wage wage wage

gen hired_labor_value = child_wage * total_hired_labor_days


forvalues n = 1/24 {
egen ID`n' = concat(hhid s3aq61_id`n'), punct("-")
gen ID_worker`n'_PP = ID`n' if  s3aq61_id`n' !=.
}


forvalues n = 25/36 {
egen ID`n' = concat(hhid s3aq61_id`n'), punct("-")
local h = `n' - 24
gen ID_worker`h'_PH = ID`h' if  s3aq61_id`n' !=.
}

keep total_labor_days plot_id total_family_labor_days total_hired_labor_days hired_labor_value ID_worker*
duplicates drop
save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")
recode s3aq43 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
merge m:1 hhid using "${Temp}\\${temppath}\\ea_id.dta", nogen 
egen plot_id = concat( hhid plotnum), punct("-") 


recode s3aq43 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

*UREA
gen UREA_kg = s3aq45 if s3aq44==2  
gen nitrogen_kg1 = UREA_kg * 0.46

* DAP 
gen DAP_kg = s3aq45 if s3aq44==1
gen nitrogen_kg2 = DAP_kg * 0.18

* SA 
gen SA_kg = s3aq45 if s3aq44==5
gen nitrogen_kg3 = SA_kg * 0.21

*CAN 
gen CAN_kg = s3aq45 if s3aq44==4
gen nitrogen_kg4 = CAN_kg * 0.26

* NPK 
gen NPK_kg = s3aq45 if s3aq44==6
gen nitrogen_kg5 = NPK_kg * 0.2

egen nitrogen_kg = rowtotal(nitrogen_kg*), missing
replace nitrogen_kg = 0 if s3aq43==2

gen fert_kg  = s3aq45

collapse (sum) nitrogen_kg  fert_kg   (count) n_nitrogen_kg = nitrogen_kg n_fert_kg = fert_kg   , by(plot_id hhid ea_id)
foreach var in nitrogen_kg fert_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear

egen plot_id = concat(hhid plotnum), punct("-") 
isid plot_id

gen fert_purchased_value = s3aq46
gen fert_purchased_kg  = s3aq45

valuation_median_fert_price hhid fert

keep ea_id fert_value
duplicates drop

merge 1:m ea_id using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

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
egen plot_id = concat( hhid plotnum), punct("-") 
recode s3aq37 (1= 1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")
recode s3aq50 (1= 1 "Yes") (.=.) (else = 0 "No") , gen(used_pesticides) label(used_pesticides)
replace used_pesticides = 0 if s3aq49==2
replace used_pesticides= 1 if s3aq49==1
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")
recode s3aq22 ( 1 5  = 1 "Yes") (.=.) (else = 0 "No") , gen(plot_owned) label(plot_owned) 
recode s3aq25 (2 = 0 "No") (1 = 1 "Yes") (5=.), gen(plot_certificate) label(plot_certificate)
replace plot_certificate=0 if plot_owned==0
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")
recode  s3aq15 (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")
recode s3aq12 (1 = 1 "Yes") (2=0 "No") (3=.), gen(erosion_protection)  label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
gen tractor= 1 if s11q4==1 & inlist(impcode, 7, 8, 9) 
replace tractor= 1 if s11q6==1 & inlist(impcode, 7, 8, 9) 
replace tractor= 0 if !inlist(impcode, 7, 8, 9) 
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")
recode s3aq3 (4 = 1) (. = .)  (* = 0) , gen(fallow_plot)
bys hhid: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_fallow_plots= 0 if _merge ==2
keep hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat( hhid plotnum), punct("-")
recode s3aq3 (4 = 1) (. = .)  (* = 0) , gen(fallow_plot)
bys hhid: egen nb_plots = count(fallow_plot)
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_plots= 0 if _merge ==2	
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

recode scq2 (1 =1 "Yes") (2= 0 "No"), gen(formal_education) label(formal_education)
recode scq6 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education) label(primary_education)
replace primary_education= 0 if formal_education==0
replace primary_education= 1 if inrange(scq7, 18, 45) // this questions is for kids currently attending school
replace primary_education=0 if inrange(scq7, 1, 17)
replace primary_education = 1 if inrange(scq8, 17, 45)  // for kids who attended school last year
replace primary_education = 0 if inrange(scq8, 1, 16) | scq8==90 
replace primary_education = 0 if sbq10==17

bys hhid: egen hh_primary_education= max(primary_education) 
bys hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(hhid)
keep hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode sjq18 (1 2 8 = 1 "Yes") (.=.) (else = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
keep hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

rename sbq4 age 
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort hhid: egen dep=total(dep_temp)
bysort hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep  if nondep==0

collapse (max)  hh_dependency_ratio, by(hhid)
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
drop if inlist(animal, 15, 16) // drop dogs and "other"
recode s10aq2 (1 = 1 "Yes") (2 = 0 "No") , gen(livestock) label(livestock) 
collapse (max)  livestock, by(hhid) 
merge 1:m hhid using "${Input}\\${country}\\${wave}\\${harvest_rwdta}", keep(using match)
replace livestock= 0 if _merge==2
collapse (max) livestock, by(hhid) 
save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = expm/hhsize
xtile cons_quint= totcons, n(5)
keep hhid cons_quint 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = expm/hhsize
keep hhid totcons
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid plotnum ), punct("-")
rename s3aq6_1 manager_id
sort  hhid (manager_id)
collapse (first) manager_id  , by(hhid plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id = sbmemno  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match ) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode  sbq2 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename sbq4 age_manager
recode sbq18 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married_manager)
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id =  sbmemno  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")

recode scq2 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode scq6 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager= 0 if formal_education_manager==0
replace primary_education_manager= 1 if inrange(scq7, 18, 45) // this questions is for kids currently attending school
replace primary_education_manager=0 if inrange(scq7, 1, 17)
replace primary_education_manager = 1 if inrange(scq8, 17, 45)  // for kids who attended school last year
replace primary_education_manager = 0 if inrange(scq8, 1, 16) | scq8==90 

keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${meta}", clear 
gen respondent_id= rosterid if s1q4=="X"
sort  hhid (respondent_id)
collapse (first) respondent_id, by(hhid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename sbmemno respondent_id // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode  sbq2 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename sbq4 age_respondent
recode sbq18 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married_respondent) 
keep hhid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen respondent_id = sbmemno  // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")

recode scq2 (1 =1 "Yes") (2= 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode scq6 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent= 0 if formal_education_respondent==0
replace primary_education_respondent= 1 if inrange(scq7, 18, 45) // this questions is for kids currently attending school
replace primary_education_respondent=0 if inrange(scq7, 1, 17)
replace primary_education_respondent = 1 if inrange(scq8, 17, 45)  // for kids who attended school last year
replace primary_education_respondent = 0 if inrange(scq8, 1, 16) | scq8==90 

keep hhid primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode srq1 (1= 1 "Yes") (2=0 "No"), gen(hh_shock) label(hh_shock)
replace hh_shock=0 if !inlist(srq5year, 2009, 2008)
replace hh_shock=1 if srq5year==2007 & inlist(srq5month, 10, 11, 12)
collapse (max) hh_shock, by(hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${csption}", clear
rename hhsize hh_size
keep hhid hh_size
duplicates drop
save "${Temp}\\${temppath}\\size.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear

recode s11q3 (1 = 1) (2 = 0) , gen(owns_) 
drop if inlist(impcode, 12)
keep hhid impcode owns_ 
reshape wide owns_ , i(hhid) j(impcode)
factor owns_*, pcf 
predict ag_asset_index
drop owns*
keep hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear
drop if sncode>431 & sncode<437 // drop agricultural assets
drop if sncode>439 
recode snq1 (0 = 0) (.= . ) (else=1), gen(hh_owns) label(hh_owns)
keep hh_owns hhid sncode
reshape wide hh_owns , i(hhid) j(sncode)
foreach var of varlist hh_owns* {
replace `var'=0 if `var'==.
}
factor hh_owns*, pcf 
predict hh_asset_index
keep hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recode seq22 ( 2 = 0 "No") (3 = 1 "Yes"), gen(nonfarm_enterprise) label(nonfarm_enterprise)
replace nonfarm_enterprise=1 if seq23==1
collapse (max) nonfarm_enterprise , by(hhid)
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude 
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep hhid lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename land03 agro_ecological_zone
keep hhid agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist01  dist_road
keep hhid dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist02 dist_popcenter
keep hhid dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace
 
// distance to nearest market 
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist03 dist_market
keep hhid dist_market
duplicates drop
save "${Temp}\\${temppath}\\dist_market.dta", replace
 
// plot slope
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename soil02 plot_slope
keep hhid plot_slope
duplicates drop
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot elevation
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename soil01 elevation
keep hhid elevation
duplicates drop
save "${Temp}\\${temppath}\\elevation.dta", replace

// plot distance to hh
use "${Input}\\${country}\\${wave}\\${geovars}", clear
egen plot_id = concat( hhid plotnum), punct("-")
rename dist01 plot_dist_household
keep plot_id plot_dist_household
duplicates drop
save "${Temp}\\${temppath}\\plot_distance.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
rename soil03 twi
keep hhid twi
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

keep hhid  nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index
duplicates drop
save "${Temp}\\${temppath}\\soil.dta", replace

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hhid sbmemno), punct("-")

recode  sbq2 (2=1 "Yes") (1=0 "No"), gen(female) 
rename sbq4 age
recode sbq18 ( 1 2 = 1 "Yes") (.=.) (else  = 0 "No"), gen(married) 
replace married = 0 if scq1==2
rename sbq5 relationship_head_temp
decode relationship_head_temp, gen(relationship_head)
replace relationship_head = proper(relationship_head)
replace relationship_head = "Son/Daughter" if relationship_head== "Step Children"
replace relationship_head = "Father/Mother" if relationship_head== "Father-Mother"
replace relationship_head = "Servant" if relationship_head== "Live-Inservant"
replace relationship_head = "Non Relative" if relationship_head== "Other Non Relatives"

// month of birth
gen birth_month= ym(sbq3yr, sbq3mnth)
format birth_month %tm 

keep hhid ID married female age relationship_head  birth_month
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hhid sbmemno ), punct("-")
merge 1:1 hhid ID using "${Temp}\\${temppath}\\indiv_chars.dta",  keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\harvest_interview_month.dta",  keep(master match) nogen

// age in months
gen age_months = harvest_interview_month - birth_month

*Main anthropometric variables
gen weight= suq4
gen height= suq5

gen cage=age*12
replace cage = age_months if age==0| age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  hhid ID weight height
duplicates drop
save "${Temp}\\${temppath}\\wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hhid sbmemno), punct("-")

recode seq46_hr (0 = 0) (.=.) (else = 1), gen( farm_work)
recode seq45 (0 = 0) (.=.) (else = 1), gen( SOB_work)
recode seq19 (0 = 0) (.=.) (else = 1), gen( wage_work)
replace wage_work = 0 if seq9==2 
replace wage_work = 0 if seq3==2 & seq4==2 & seq5==2 
replace wage_work = 0 if seq3==2 & seq4==2 & seq5==1

	// industry:
	gen 	ind_ag = seq13 == 1 | seq13==2 // Agriculture 
	gen 	ind_fish = seq13==3 // fishing
	gen 	ind_mining = seq13 >= 5 & seq13<=9 // mining
	gen 	ind_manuf = seq13 >= 10 & seq13<=36 // manuf
	gen 	ind_const = seq13 >= 41 & seq13<=43	// construc
	gen 	ind_serv = seq13 >= 45 & seq13<= 4923	// services
	foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
		replace `var' = 0 if seq9==2 & seq10 == 2 // no wage employment
		replace `var' = 0 if seq5==2 | seq5 == 1 // these individuals were skipped
		}
		
rename (seq46_hr seq45 seq19 ) (farm_hrs SB_hrs wage_hrs )
replace wage_hrs = 0 if wage_work==0

gen working_age = seq1==1


foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}

keep ID hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

egen ID = concat (hhid sbmemno), punct("-")

recode scq2 (1 =1 "Yes") (2= 0 "No"), gen(formal_education) label(formal_education)
recode scq6 (18/45 = 1 "Yes") (.=.) (else=0 "No"), gen(primary_education) label(primary_education)
replace primary_education= 0 if formal_education==0
replace primary_education= 1 if inrange(scq7, 18, 45) // this questions is for kids currently attending school
replace primary_education=0 if inrange(scq7, 1, 17)
replace primary_education = 1 if inrange(scq8, 17, 45)  // for kids who attended school last year
replace primary_education = 0 if inrange(scq8, 1, 16) | scq8==90 
replace primary_education = 0 if scq1==2
replace formal_education = 0 if scq1==2

keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace

// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if skq1 ==1 // keep if consumed
rename skcode food_id

gen A = food_id>=101 & food_id<=112
gen B = food_id>=201 & food_id<=207
gen C = food_id>=601 & food_id<=603
gen D = food_id>=701 & food_id<=704
gen E = food_id>=801 & food_id<=806 | food_id>=90 & food_id<=96
gen F = food_id==807 
gen G = food_id>=808 & food_id<=810
gen H = food_id>=401 & food_id<=504
gen I = food_id>=901 & food_id<=903
gen J = food_id>=1001 & food_id<=1002
gen K = food_id>=301 & food_id<=303
gen L = food_id>=1003 & food_id<=1105 

collapse (max) A B C D E F G H I J K L, by(hhid)
egen HDDS = rowtotal(A B C D E F G H I J K L), missing 

merge 1:m hhid  using "${Input}\\${country}\\${wave}\\${HDDS}", 
collapse (max) HDDS, by(hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace

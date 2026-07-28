/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for GHS4          *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Nigeria
global wave  GHS 23
global cover  secta_plantingw5.dta
global cover2  sectaa_harvestw5.dta
global indiv_roster  sect1_plantingw5.dta
global indiv_roster0  sect1_harvestw5.dta
global indiv_roster1  sect2_harvestw5.dta
global lab_roster11 sect11c1a_plantingw5.dta
global lab_roster12 sect11c1b_plantingw5.dta
global lab_roster21 secta2a_harvestw5.dta
global lab_roster22 secta2b_harvestw5.dta
global shocks sect12_harvestw5.dta
global housing  sect9_harvestw5.dta
global plot_roster  sect11a1_plantingw5.dta
global ferts secta11c2_harvestw5.dta
global ferts_sold secta11c3_harvestw5.dta
global items secta4_harvestw5.dta
global items_hh sect10_plantingw5.dta
global harvest_rwdta  secta3i_harvestw5.dta
global harvest_sold_rwdta  secta3ii_harvestw5.dta
global perennial  secta3iii_harvestw5.dta
global seeds  sect11f_plantingw5.dta
global seeds_sold1 sect11e1_plantingw5.dta
global seeds_sold2 sect11e2_plantingw5.dta
global geovars_hh nga_householdgeovars_y4.dta
global geovars nga_plotgeovariables_y4.dta
global livestock sect11i_plantingw5.dta
global conversions ag_conv_w4.dta
global tenure sect11b1_plantingw5.dta // many missing here because not cultivated
global labor_hh sect4a_harvestw5.dta
global nfe sect8a_harvestw5.dta
global anthropo  sect4b_harvestw5.dta
global meta sectc_harvestw5.dta
global temppath NGA\GHS23
global HDDS sect5b_harvestw5.dta



**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:m hhid plotid cropcode using "${Input}\\${country}\\${wave}\\${perennial}"
egen plot_id = concat(hhid plotid), punct("-")
decode cropcode, gen(crop_name)
replace crop_name = substr(crop_name, strpos(crop_name,  ".")+2, .)
keep hhid plot_id crop_name cropcode 

duplicates drop


duplicates tag plot_id crop_name, gen(tag)
decode cropcode, gen(cropname2)
replace crop_name = cropname2 if tag>0


duplicates report plot_id cropcode crop_name

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
keep hhid 
duplicates report hhid 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame.dta", replace
merge 1:1 hhid using  "${Input}\\${country}\\${wave}\\${cover2}"

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster0}", clear
merge 1:1 hhid indiv using "${Input}\\${country}\\${wave}\\${indiv_roster}"
drop if s1q4==2
rename indiv id
egen ID = concat (hhid id ), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear 
egen ea_id_temp = concat(lga ea), punct("-")
drop lga ea
merge 1:1 hhid using "${Temp}\\NGA\GHS18\\ea_id.dta", keep(master match)
replace ea_id = ea_id_temp if _merge==1
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename zone zone_w5
merge 1:1 hhid using "${Temp}\\NGA\GHS18\\strataid.dta", keep(master match)
replace strataid = zone_w5 if _merge==1 // refreshed households
keep hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear 
rename zone admin_1
keep hhid admin_1  
decode admin_1, gen(admin_1_name)
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename state admin_2 
keep hhid admin_2
decode admin_2, gen(admin_2_name)
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename lga admin_3
keep hhid admin_3
decode admin_3, gen(admin_3_name)
replace admin_3_name = substr(admin_3_name, strpos(admin_3_name,  ".")+2, .)
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
recode sector (1 = 1 "Yes") (2 =0 "No"), gen(urban) label(urban)
keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename wt_cross_wave5 pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${seeds}", clear

egen plot_id = concat( hhid plotid), punct("-")

gen month = s11fq11_month
gen year= s11fq11_year


gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
drop month year

collapse (min) planting_month , by(hhid cropcode plot_id)
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:m hhid plotid cropcode using "${Input}\\${country}\\${wave}\\${perennial}"

egen plot_id = concat( hhid plotid), punct("-")
gen month = sa3iq14a
gen year = sa3iq14b
replace month = sa3iiiq22a if _merge==2
replace year = sa3iiiq22b if _merge==2

gen harvest_end_month = ym( year, month)
format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(plot_id cropcode ) 
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover2}", clear
destring InterviewStart, replace
gen str = substr(InterviewStart, 1 ,10)
gen day = date( str, "YMD")
gen harvest_interview_month = mofd( day)
format harvest_interview_month %tmCCYYMon
keep hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
destring InterviewStart, replace
gen str = substr(InterviewStart, 1 ,10)
gen day = date( str, "YMD")
gen planting_interview_month = mofd( day)
format planting_interview_month %tmCCYYMon
keep hhid planting_interview_month
duplicates drop
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:m hhid plotid cropcode using "${Input}\\${country}\\${wave}\\${perennial}"

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 
egen plot_id = concat(hhid plotid), punct("-")

recode sa3iq3 (1 = 1 "Yes") (2 =0 "No"), gen(any_harvest) label(any_harvest) 


gen harvest_kg_temp= sa3iq9a * sa3iq9_conv 
replace harvest_kg_temp=0 if any_harvest==0 
gen harvest_kg_expected = sa3iq15a * sa3iq15_conv
gen harvest_kg_per = sa3iiiq23a * sa3iiiq23_conv

egen harvest_kg = rowtotal(harvest_kg_temp harvest_kg_expected harvest_kg_per), missing

recode sa3iq3 (2 = 1 "Yes") (1 = 0 "No"), gen(crop_shock) label(crop_shock)
replace crop_shock = 0 if sa3iq4_1>21 & sa3iq4_2>21
replace crop_shock = 1 if sa3iq6==1 
replace crop_shock = 0 if sa3iq7_1>21  & sa3iq7_1>21 

replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 
collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id cropcode admin_1 admin_2 admin_3 hhid)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// crop shock

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:m hhid plotid cropcode using "${Input}\\${country}\\${wave}\\${perennial}"
egen plot_id = concat(hhid plotid), punct("-")

recode sa3iq3 (2 = 1 "Yes") (1 = 0 "No"), gen(crop_shock) label(crop_shock)
replace crop_shock = 0 if sa3iq4_1>21 & sa3iq4_2>21
replace crop_shock = 1 if sa3iq6==1 
replace crop_shock = 0 if sa3iq7_1>21  & sa3iq7_1>21 

collapse (max)  crop_shock     , by(hhid plot_id cropcode)

save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
gen total_kg = sa3iiq3a * sa3iiq1_conv
gen share_sold = sa3iiq6/sa3iiq3a
gen harvest_sold_kg_temp = share_sold * total_kg
replace harvest_sold_kg_temp = 0 if sa3iiq4==2
merge 1:m hhid  cropcode using "${Input}\\${country}\\${wave}\\${perennial}"  
gen harvest_sold_per = sa3iiiq23a * sa3iiiq23_conv
replace harvest_sold_per = 0 if _merge==1 
collapse (sum) harvest_sold_per (count) n = harvest_sold_per (max) harvest_sold_kg_temp , by(cropcode hhid)
replace harvest_sold_per = . if n==0
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta",  nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

egen harvest_sold_kg = rowtotal(harvest_sold_kg_temp harvest_sold_per), missing

collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( cropcode hhid admin_1 admin_2 admin_3)
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
gen harvest_sold_value_temp = sa3iiq7
merge 1:m hhid  cropcode using "${Input}\\${country}\\${wave}\\${perennial}"
gen harvest_sold_value_per = sa3iiiq24
collapse (sum) harvest_sold_value_per (count) n = harvest_sold_value_per (max) harvest_sold_value_temp , by(cropcode hhid)
replace harvest_sold_value_per = . if n==0
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

egen harvest_sold_value = rowtotal(harvest_sold_value_temp harvest_sold_value_per), missing

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( cropcode hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
merge 1:m hhid  cropcode using "${Input}\\${country}\\${wave}\\${perennial}"
keep hhid  cropcode 
duplicates drop

valuation_median_crops_noea_sort hhid   cropcode

main_crop_def cropcode


keep plot_id harvest_value cropcode main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace

// intercropped
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11fq4 (1= 0 "No") (2 = 1 "Yes"), gen(intercropped) label(intercropped)
keep cropcode plot_id intercropped
collapse (max) intercropped, by(plot_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat( hhid plotid), punct("-")
bys  plot_id : egen nb_seasonal_crop = count(cropcode)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${seeds}", clear
drop if s11fq2==2 
gen count_temporary=1
collapse (sum) count_temporary, by(cropcode)
tempfile Perennial_crops_temp
save `Perennial_crops_temp', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
drop if s11fq2==1 
gen count_permanent=1
collapse (sum) count_permanent, by(cropcode)
merge 1:1 cropcode using `Perennial_crops_temp' // There is no overlap 
gen permanent_crop=0 
replace permanent_crop=1 if _merge==1 
drop if permanent_crop==0 
drop permanent_crop count_permanent count_temporary _merge
tempfile Perennial_crops_list 
save `Perennial_crops_list', replace
rename cropcode main_crop
tempfile Perennial_crops_list_MC 
save `Perennial_crops_list_MC', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge 1:m hhid plotid cropcode using "${Input}\\${country}\\${wave}\\${perennial}"
rename _merge _mergeper
egen plot_id = concat( hhid plotid), punct("-")
merge m:1 cropcode using  `Perennial_crops_list', keep(master match) 
rename _merge _mergecropcode

merge m:1 cropcode plot_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen
merge m:1 main_crop using  `Perennial_crops_list_MC', keep(master match) 
rename _merge _mergemain_crop

bys plot_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if cropcode==main_crop
bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

foreach c in main_crop cropcode {
lab val `c' sa3i_crops__id
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2
replace `c' = strupper(`c')

local dot strpos(`c', ".")
replace `c' = trim(cond(`dot', substr(`c',`dot' + 1, .), `c'))
replace `c' = "SUGARCANE" if `c' =="SUGAR CANE"
replace `c' = "PUMPKINS" if `c' =="PUMPKIN"
replace `c' = "OKRA" if `c' =="OKRO"
replace `c' = "BANANAS" if `c' =="BANANA"	
replace `c' = "TOMATOES" if `c' =="TOMATO"	

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"COWPEA", "GROUNDNUTS", "SOY", "SOYA BEANS",  "BEANS") | strpos(`c', "COWPEA") | strpos(`c', "PEANUT") | strpos(`c' , "GROUND NUTS")
replace `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"PEA", "PEANUTS", "VOANDZOU", "BAMBARA NUT", "PIGEON PEA")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"POTATO", "SWEET POTATO", "CASSAVA", "YAMS", "CARROT") | strpos(`c', "CASSAVA") | strpos(`c', "POTATO")
replace `c'2 = "TUBERS / ROOT CROPS" if strpos(`c', "YAM")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"BEETS", "TARO", "SOUCHET", "COCOYAM", "RIZGA")
replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE" | strpos(`c', "RICE")
replace `c'2 = "WHEAT" if `c'=="WHEAT"
replace `c'2 = "MAIZE" if `c'=="MAIZE"| strpos(`c', "MAIZE")
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
replace `c'2 = "SORGHUM" if strpos(`c', "SORGHUM")
replace `c'2 = "MILLET" if `c'=="MILLET" | `c'=="ACHA" |  `c'=="FONIO" | strpos(`c', "MILLET")
replace `c'2 = "NUTS" if `c'=="NUTS" | `c'=="SHEA NUTS" | `c'=="CASHEW NUT"
replace `c'2 = "" if `c'=="."
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if  _merge`c' == 3
drop `c'
rename `c'2 `c'
}
tab cropcode, gen(contains_crop_)


foreach n in 8 7 6 5 4 {
	local i = `n' + 2
	rename contains_crop_`n' contains_crop_`i'
} 

foreach n in 3 2 1 {
	local i = `n' + 1
	rename contains_crop_`n' contains_crop_`i'
} 

gen contains_crop_1=0
gen contains_crop_5=0
gen contains_crop_11=0

//share of each crop category

forvalues n = 1/11 {
gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
replace share_crop`n' = 0 if contains_crop_`n'==0
}

collapse (sum)   share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop.dta", replace



// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
rename (zone state lga) (admin_1 admin_2 admin_3)
egen plot_id = concat( hhid plotid), punct("-") 

gen area_self_reported= s11aq3_number
replace area_self_reported = area_self_reported * 0.4 if s11aq3_unit==5
replace area_self_reported = area_self_reported * 0.0001 if s11aq3_unit==7
replace area_self_reported = area_self_reported * 0.0929 if s11aq3_unit==8
replace area_self_reported = area_self_reported * 0.04645 if s11aq3_unit==9
replace area_self_reported = area_self_reported * 0.405 if s11aq3_unit==10

// heaps
replace area_self_reported = area_self_reported * 0.00012 if s11aq3_unit==1 & admin_1==1
replace area_self_reported = area_self_reported * 0.00016 if s11aq3_unit==1 & admin_1==2
replace area_self_reported = area_self_reported * 0.00011 if s11aq3_unit==1 & admin_1==3
replace area_self_reported = area_self_reported * 0.00019 if s11aq3_unit==1 & admin_1==4
replace area_self_reported = area_self_reported * 0.00021 if s11aq3_unit==1 & admin_1==5
replace area_self_reported = area_self_reported * 0.00012 if s11aq3_unit==1 & admin_1==6

// ridges 
replace area_self_reported = area_self_reported * 0.0027 if s11aq3_unit==2 & admin_1==1
replace area_self_reported = area_self_reported * 0.004 if s11aq3_unit==2 & admin_1==2
replace area_self_reported = area_self_reported * 0.00494 if s11aq3_unit==2 & admin_1==3
replace area_self_reported = area_self_reported * 0.0023 if s11aq3_unit==2 & admin_1==4
replace area_self_reported = area_self_reported * 0.0023 if s11aq3_unit==2 & admin_1==5
replace area_self_reported = area_self_reported * 0.00001 if s11aq3_unit==2 & admin_1==6

// stands
replace area_self_reported = area_self_reported * 0.00006 if s11aq3_unit==3 & admin_1==1
replace area_self_reported = area_self_reported * 0.00016 if s11aq3_unit==3 & admin_1==2
replace area_self_reported = area_self_reported * 0.00004 if s11aq3_unit==3 & admin_1==3
replace area_self_reported = area_self_reported * 0.00004 if s11aq3_unit==3 & admin_1==4
replace area_self_reported = area_self_reported * 0.00013 if s11aq3_unit==3 & admin_1==5
replace area_self_reported = area_self_reported * 0.00041 if s11aq3_unit==3 & admin_1==6


gen plot_area_GPS= s11mq3
replace plot_area_GPS = plot_area * 0.0001 // converting to hectare

merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

isid hhid plot_id
sort hhid plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi tsset, clear 
mi impute pmm plot_area_GPS area_self_reported i.admin_3, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys hhid: egen farm_size = total(plot_area_GPS), missing

keep hhid plot_id   plot_area_GPS farm_size
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// improved
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11fq7 (2=0 "No") (1 =1 "Yes"), gen(improved)
collapse (max) improved, by(hhid plot_id cropcode)
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv, by(zone cropcode unit size)
drop if inlist(., sa3iq9_conv, size, unit, zone)
tempfile Conversions
save `Conversions', replace
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv, by( cropcode unit size)
drop if inlist(., sa3iq9_conv, unit)
tempfile Conversions_nozone
save `Conversions_nozone', replace
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv , by( unit size)
drop if inlist(., sa3iq9_conv, size, unit)
tempfile Conversions_nozonecrop
save `Conversions_nozonecrop', replace
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv , by( unit)
drop if inlist(., sa3iq9_conv, unit)
tempfile Conversions_nozonenocropnosize
save `Conversions_nozonenocropnosize', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( hhid plotid), punct("-") // This creates a unique plot id.

recode s11fq7 (2=0 "No") (1 =1 "Yes"), gen(improved)

gen seed_kg_preconv = s11fq5a 
rename s11fq5b unit
rename s11fq5c size
merge m:1 zone cropcode unit size using  `Conversions', keep(master match)  
gen seed_kg= seed_kg_preconv * sa3iq9_conv
drop sa3iq9_conv 
merge m:1 cropcode unit size using `Conversions_nozone', keep(master match) nogen
replace seed_kg= seed_kg_preconv * sa3iq9_conv if seed_kg==.
drop sa3iq9_conv
merge m:1  unit size using `Conversions_nozonecrop', keep(master match) nogen
replace seed_kg= seed_kg_preconv * sa3iq9_conv if seed_kg==.
drop sa3iq9_conv

merge m:1 unit using `Conversions_nozonenocropnosize', keep(master match) nogen
replace seed_kg= seed_kg_preconv * sa3iq9_conv if seed_kg==.

replace seed_kg = seed_kg_preconv if unit==1
replace seed_kg = seed_kg_preconv * 0.001 if unit==2

rename (zone state lga) (admin_1 admin_2 admin_3)
collapse (sum)  seed_kg (count) n_seed_kg = seed_kg , by( cropcode hhid plot_id admin_1 admin_2 admin_3 improved)
replace seed_kg = . if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg.dta", replace
collapse (sum)  seed_kg (count) n_seed_kg = seed_kg , by( cropcode hhid plot_id admin_1 admin_2 admin_3)
replace seed_kg = . if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace


// seed_kg_sold 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv, by(zone cropcode unit size)
drop if inlist(., sa3iq9_conv, size, unit, zone)
tempfile Conversions
save `Conversions', replace
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv, by( cropcode unit size)
drop if inlist(., sa3iq9_conv, unit)
tempfile Conversions_nozone
save `Conversions_nozone', replace
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv , by( unit size)
drop if inlist(., sa3iq9_conv, size, unit)
tempfile Conversions_nozonecrop
save `Conversions_nozonecrop', replace
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
keep cropcode sa3iq9b sa3iq9c sa3iq9d sa3iq9_conv zone 
drop if sa3iq9d==1 // we drop unshelled observations: assuming all expected harvest are shelled estimates
rename sa3iq9b unit 
rename sa3iq9c size
collapse (median) sa3iq9_conv , by( unit)
drop if inlist(., sa3iq9_conv, unit)
tempfile Conversions_nozonenocropnosize
save `Conversions_nozonenocropnosize', replace

use "${Input}\\${country}\\${wave}\\${seeds_sold1}", clear
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${seeds_sold2}", nogen

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

decode seedid, gen(seed_id)
egen improved_string= ends(seed_id), head
gen improved= 1 if improved_string=="IMPROVED" 
replace improved=0 if improved_string=="TRADITIONAL"

** Price of seeds per observation
rename s11eq9b unit
rename s11eq9c size
merge m:1 zone cropcode unit size using  `Conversions', keep(master match) nogen 
gen seeds_amount_purchased_kg= sa3iq9_conv * s11eq9a
drop sa3iq9_conv 
merge m:1 cropcode unit size using  `Conversions_nozone', keep(master match) nogen 
replace seeds_amount_purchased_kg= sa3iq9_conv * s11eq9a if mi(seeds_amount_purchased_kg)
drop sa3iq9_conv 
merge m:1  unit size using  `Conversions_nozonecrop', keep(master match) nogen 
replace seeds_amount_purchased_kg= sa3iq9_conv * s11eq9a if mi(seeds_amount_purchased_kg)
drop sa3iq9_conv 
merge m:1  unit  using  `Conversions_nozonenocropnosize', keep(master match) nogen 
replace seeds_amount_purchased_kg= sa3iq9_conv * s11eq9a if mi(seeds_amount_purchased_kg)

collapse (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg = seeds_amount_purchased_kg, by(cropcode hhid  admin_1 admin_2 admin_3 improved)
replace seeds_amount_purchased_kg = . if n_seeds_amount_purchased_kg==0
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds_sold1}", clear
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${seeds_sold2}", nogen
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 


decode seedid, gen(seed_id)
egen improved_string= ends(seed_id), head
gen improved= 1 if improved_string=="IMPROVED" 
replace improved=0 if improved_string=="TRADITIONAL"


gen seed_value_temp = s11eq11 

collapse  (sum) seed_value_temp (count) n_seed_value_temp = seed_value_temp , by(cropcode hhid  admin_1 admin_2 admin_3 improved )
replace seed_value_temp = . if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds_sold1}", clear
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${seeds_sold2}", nogen
rename (zone state lga) (admin_1 admin_2 admin_3)
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

decode seedid, gen(seed_id)
egen improved_string= ends(seed_id), head
gen improved= 1 if improved_string=="IMPROVED" 
replace improved=0 if improved_string=="TRADITIONAL"


keep cropcode  hhid  improved
duplicates drop

valuation_median_seeds_noea hhid improved cropcode 

keep  plot_id cropcode seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days
use "${Input}\\${country}\\${wave}\\${lab_roster11}", clear
merge m:1 hhid plotid using "${Input}\\${country}\\${wave}\\${lab_roster12}", 
egen plot_id = concat( hhid plotid), punct("-")
drop if indiv==.

* 1) Family labor

replace s11c1q1b = 0 if s11c1q1a==2
bys plot_id: egen PPtotal_family_labor_days = total(s11c1q1b), missing 
replace PPtotal_family_labor_days = 0 if _merge==2


* 2) Hired labor
gen PPhired_man_days = s11c1q3_1 *s11c1q4_1
replace PPhired_man_days = 0 if s11c1q2_1==2 // these plots did not hire men

gen PPhired_woman_days = s11c1q3_2 *s11c1q4_2
replace PPhired_woman_days = 0 if s11c1q2_2==2 // these plots did not hire women

gen PPhired_child_days = s11c1q3_3 *s11c1q4_3
replace PPhired_child_days = 0 if s11c1q2_3==2 // these plots did not hire children

egen PPtotal_hired_labor_days= rowtotal(PPhired_man_days PPhired_woman_days PPhired_child_days), missing

replace PPtotal_hired_labor_days = 0 if _merge==1

gen PPhired_man_wage= s11c1q6_1

gen PPhired_woman_wage= s11c1q6_2

gen PPhired_child_wage = s11c1q6_3

* 3) other labor

gen PPother_man_days = s11c1q9_1 *s11c1q10_1
replace PPother_man_days = 0 if s11c1q8_1==2 // these plots did not hire men

gen PPother_woman_days = s11c1q9_2 *s11c1q10_2
replace PPother_woman_days = 0 if s11c1q8_2==2 // these plots did not hire women

gen PPother_child_days = s11c1q9_3 *s11c1q10_3
replace PPother_child_days = 0 if s11c1q8_3==2 // these plots did not hire children


egen PPtotal_other_labor_days= rowtotal(PPother_man_days PPother_woman_days PPother_child_days), missing
replace PPtotal_other_labor_days = 0 if _merge==1
* ID code of workers

keep PPtotal_other_labor_days PPhired_man_wage PPhired_woman_wage PPhired_child_wage PPtotal_hired_labor_days PPtotal_family_labor_days plot_id hhid indiv

gen ID_worker = indiv
reshape wide PPtotal_other_labor_days PPhired_man_wage PPhired_woman_wage PPhired_child_wage PPtotal_hired_labor_days PPtotal_family_labor_days ID_worker, i(plot_id hhid) j(indiv)

foreach var in  PPtotal_family_labor_days {
egen `var' =  rowtotal(`var'*), missing
}

foreach var in PPhired_man_wage PPhired_woman_wage PPhired_child_wage PPtotal_other_labor_days  PPtotal_hired_labor_days {
egen `var' =  rowmean(`var'*)
}

keep hhid plot_id PPtotal_family_labor_days PPhired_man_wage PPhired_woman_wage PPhired_child_wage PPtotal_other_labor_days  PPtotal_hired_labor_days ID_worker*

foreach var in ID_worker* {
rename `var' `var'_PP
}

valuation_median_wages hhid PPhired_man_wage PPhired_woman_wage PPhired_child_wage

gen man_labor_value = man_wage * PPhired_man_wage
gen woman_labor_value = woman_wage * PPhired_woman_wage
gen child_labor_value = child_wage * PPhired_child_wage
egen PPhired_labor_value = rowtotal (*_labor_value), missing


tempfile PPtotal_labor_days 
save `PPtotal_labor_days', replace 

use "${Input}\\${country}\\${wave}\\${lab_roster21}", clear
merge m:1 hhid plotid using "${Input}\\${country}\\${wave}\\${lab_roster22}"
egen plot_id = concat( hhid plotid), punct("-") 
drop if indiv==.

merge m:1 hhid  using "${Temp}\\${temppath}\\harvest_interview_month.dta",  keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\planting_interview_month.dta",  keep(master match) nogen
gen nb_months_since_pp = harvest_interview_month - planting_interview_month
gen nb_weeks_since_pp = round(nb_months_since_pp  * 4.33) // numebr of weeks/ month on average


* 1) Family labor 
gen ld = nb_weeks_since_pp *  sa2aq2
replace ld = 0 if sa2aq1==2
bys plot_id: egen PHtotal_family_labor_days = total(ld), missing 
replace PHtotal_family_labor_days = 0 if _merge==2

* 2) Hired labor days

gen PHhired_man_days = sa2bq2_1 *sa2bq3_1
replace PHhired_man_days = 0 if sa2bq1_1==0 

gen PHhired_woman_days = sa2bq2_2 *sa2bq3_2
replace PHhired_woman_days = 0 if sa2bq1_2==0 

gen PHhired_child_days = sa2bq2_3 *sa2bq3_3
replace PHhired_child_days = 0 if sa2bq1_3==0 

egen PHtotal_hired_labor_days= rowtotal(PHhired_man_days PHhired_woman_days PHhired_child_days), missing
replace PHtotal_hired_labor_days = 0 if _merge==1

gen PHhired_man_wage= sa2bq5_1
	
gen PHhired_woman_wage= sa2bq5_2
	
gen PHhired_child_wage = sa2bq5_3	

valuation_median_wages hhid PHhired_man_wage PHhired_woman_wage PHhired_child_wage

gen man_labor_value = man_wage * PHhired_man_days
gen woman_labor_value = woman_wage * PHhired_woman_days
gen child_labor_value = child_wage * PHhired_child_days
egen PHhired_labor_value = rowtotal (*_labor_value), missing


* 3) Other (free) labor

gen PHother_man_days = sa2bq8_1 *sa2bq9_1
replace PHother_man_days = 0 if sa2bq7_1==0 // these plots did not hire men

gen PHother_woman_days = sa2bq8_2 *sa2bq9_2
replace PHother_woman_days = 0 if sa2bq7_2==0 // these plots did not hire women

gen PHother_child_days = sa2bq8_3 *sa2bq9_3
replace PHother_child_days = 0 if sa2bq7_3==0 // these plots did not hire children

egen PHtotal_other_labor_days= rowtotal(PHother_man_days PHother_woman_days PHother_child_days), missing
replace PHtotal_other_labor_days = 0 if _merge==1

* 4) Total labor days

egen PHtotal_labor_days = rowtotal(PHtotal_hired_labor_days PHtotal_family_labor_days PHtotal_other_labor_days), missing

* ID code of workers

keep PHtotal_other_labor_days PHhired_man_wage PHhired_woman_wage PHhired_child_wage PHtotal_hired_labor_days PHtotal_family_labor_days plot_id hhid indiv

gen ID_worker = indiv
reshape wide PHtotal_other_labor_days PHhired_man_wage PHhired_woman_wage PHhired_child_wage PHtotal_hired_labor_days PHtotal_family_labor_days ID_worker, i(plot_id hhid) j(indiv)

foreach var in  PHtotal_family_labor_days {
egen `var' =  rowtotal(`var'*), missing
}

foreach var in PHhired_man_wage PHhired_woman_wage PHhired_child_wage PHtotal_other_labor_days  PHtotal_hired_labor_days {
egen `var' =  rowmean(`var'*)
}

keep hhid plot_id PHtotal_family_labor_days PHhired_man_wage PHhired_woman_wage PHhired_child_wage PHtotal_other_labor_days  PHtotal_hired_labor_days ID_worker*


foreach var in ID_worker* {
rename `var' `var'_PH
}
valuation_median_wages hhid PHhired_man_wage PHhired_woman_wage PHhired_child_wage

gen man_labor_value = man_wage * PHhired_man_wage
gen woman_labor_value = woman_wage * PHhired_woman_wage
gen child_labor_value = child_wage * PHhired_child_wage
egen PHhired_labor_value = rowtotal (*_labor_value), missing

tempfile PHtotal_labor_days 
save `PHtotal_labor_days', replace 

// PH labor

// put all together
use `PHtotal_labor_days', clear
merge 1:1 plot_id  using `PPtotal_labor_days', nogen

egen total_labor_days = rowtotal(PHtotal_hired_labor_days PHtotal_family_labor_days PHtotal_other_labor_days PPtotal_hired_labor_days PPtotal_family_labor_days PPtotal_other_labor_days ), missing

egen total_hired_labor_days = rowtotal(PHtotal_hired_labor_days PPtotal_hired_labor_days ), missing

egen total_family_labor_days = rowtotal(PHtotal_family_labor_days PPtotal_family_labor_days)

egen hired_labor_value = rowtotal(PHhired_labor_value PPhired_labor_value), missing
replace hired_labor_value = 0 if total_hired_labor_days==0

keep total_labor_days plot_id total_family_labor_days total_hired_labor_days hired_labor_value ID_worker*
duplicates drop
save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11c2q5 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${ferts}", clear

merge m:1 hhid  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen

forvalues n =1/4 {
capture merge m:1 hhid using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
if !_rc {
 merge m:1 hhid using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}
}

egen plot_id = concat( hhid plotid), punct("-") 
recode s11c2q5 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

*UREA
gen UREA_kg = s11c2q11a * s11c2q11a_conv
replace UREA_kg= 0 if s11c2q6__2==0
replace UREA_kg= 0 if inorganic_fertilizer==0

* NPK
gen NPK_kg=  s11c2q7a * s11c2q7a_conv
replace NPK_kg=0 if s11c2q6__1==0
replace NPK_kg= 0 if inorganic_fertilizer==0

* other
gen other_kg=  s11c2q9a * s11c2q9a_conv
replace other_kg=0 if s11c2q6__96==0
replace other_kg= 0 if inorganic_fertilizer==0

* Nitrogen equalivent 

gen UREA_N_kg = UREA_kg*0.46
gen NPK_N_kg = NPK_kg*0.2
egen nitrogen_kg = rowtotal(UREA_N_kg NPK_N_kg), missing

collapse (sum) nitrogen_kg  UREA_kg  NPK_kg other_kg  (count) n_nitrogen_kg = nitrogen_kg n_NPK_kg = NPK_kg  n_UREA_kg = UREA_kg n_other_kg = other_kg , by(plot_id hhid ea_id admin_1 admin_2 admin_3)
foreach var in nitrogen_kg NPK_kg  UREA_kg  other_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 
use "${Input}\\${country}\\${wave}\\${ferts_sold}", clear
rename (zone state lga) (admin_1 admin_2 admin_3)
drop if ea==. | ea==0
gen input_purchase_kg = s11c3q4a * s11c3q4_conv if !inlist(s11c3q4b, 3, 4) // if not converted to liters 
gen input_purchase_l = s11c3q4a * s11c3q4_conv if inlist(s11c3q4b, 3, 4)
keep s11c3q5 input_purchase_kg input_purchase_l hhid inputid admin_1 admin_2 admin_3 ea // I keep quantity sold and value to reshape
reshape wide admin_1 admin_2 admin_3 ea s11c3q5 input_purchase_kg input_purchase_l , i(hhid) j(inputid) // inputs types are not variables
foreach var in  admin_1 admin_2 admin_3 ea {
drop `var'2 `var'3 `var'4 `var'5 `var'6 `var'7 `var'8
rename `var'1 `var'
}
gen UREA_purchased_kg = input_purchase_kg3
gen UREA_purchased_value = s11c3q53

gen NPK_purchased_kg = input_purchase_kg2
gen NPK_purchased_value = s11c3q52

gen other_purchased_kg = input_purchase_kg4
gen other_purchased_value = s11c3q54


collapse (max) UREA_purchased_kg  NPK_purchased_kg other_purchased_kg  UREA_purchased_value NPK_purchased_value  other_purchased_value  , by(hhid)

valuation_median_fert_price hhid UREA

valuation_median_fert_price hhid NPK

valuation_median_fert_price hhid other

bys ea_id admin_1 admin_2 admin_3: assert UREA_value==UREA_value[1]

collapse (mean) UREA_value  NPK_value  other_value , by(ea_id admin_1 admin_2 admin_3) 
merge 1:m ea_id admin_1 admin_2 admin_3 using "${Temp}\\${temppath}\\nitrogen_kg.dta", nogen // some unmatched regions

foreach n in NPK UREA other  {
gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep plot_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id = concat( hhid plotid), punct("-") 
recode s11c2q11 (1 = 1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11c2q3 (1 = 1 "Yes") (2 = 0 "No") , gen(used_pesticides) label(used_pesticides)
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q4 ( 1 4 5  = 1 "Yes") (2 3 6 7 8 9= 0 "No") , gen(plot_owned) 
recode s11b1q8 (1 = 1 "Yes") (2= 0 "No") (3=.), gen(plot_certificate) label(plot_certificate)
replace plot_certificate=0 if plot_owned==0 
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q56 (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace

// erosion protection
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q66 ( 2 = 0 "No" ) (1 = 1 "Yes"), gen(erosion_protection) label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-") 
recode s11b1q69 (1 = 1 "Yes") (2 = 0 "No"), gen(tractor) label(tractor)
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q44 (1 = 1) (. = . ) (* = 0), gen(fallow_plot)
bys hhid: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_fallow_plots= 0 if _merge ==2		
keep hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( hhid plotid), punct("-")
bys hhid: egen nb_plots = count(plot_id) 
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover}", 
replace nb_plots= 0 if _merge ==2	
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear

recode s2q6 ( 1 = 1 "Yes") ( 2 = 0 "No"), gen(formal_education_hh1) label(formal_education_hh1)
recode s2q9 (0/15 51/64 98 99 = 0 "No" ) (16/43 321/424 = 1 "Yes"), gen(primary_education_hh1) label(primary_education_hh1)
replace primary_education_hh1 = 0 if formal_education_hh1==0

egen formal_education_hh = rowmax(formal_education_hh1 )
egen primary_education_hh = rowmax( primary_education_hh1)
bys hhid: egen hh_primary_education= max(primary_education_hh) 
bys hhid: egen hh_formal_education = max(formal_education_hh)

collapse (max) hh_formal_education hh_primary_education, by(hhid)
keep hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode s9q20 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
replace  hh_electricity_access= 1 if s9q19_1==1 | s9q19_2 ==1
keep hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

rename s1q6 age 
replace age=. if age==999
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort hhid: egen dep=total(dep_temp)
bysort hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep if nondep==0
collapse (max) hh_dependency_ratio, by(hhid)
keep hhid hh_dependency_ratio
duplicates drop
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover}"
recode s11iq1  (1 = 1 "Yes") (2 . = 0 "No"), gen(livestock) label(livestock)
collapse (max) livestock, by(hhid) 
save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint (absent)

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( hhid plotid), punct("-")
rename s11aq5a manager_id
sort  hhid (manager_id)
collapse (first) manager_id  , by(hhid plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster0}", clear
gen manager_id = indiv  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match ) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode  s1q2 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename s1q6 age_manager
replace age_manager=. if age_manager==999
recode s1q16 ( 1 2 = 1 "Yes") (3/7 = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear
gen manager_id =  indiv  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode s2q6 ( 1 = 1 "Yes") ( 2 = 0 "No"), gen(formal_education_manager1) label(formal_education_manager1)
recode s2q9 (0/15 51/64 98 99 = 0 "No" ) (16/43 321/424 = 1 "Yes"), gen(primary_education_manager1) label(primary_education_manager1)
replace primary_education_manager1 = 0 if formal_education_manager1==0

egen formal_education_manager = rowmax(formal_education_manager1)
egen primary_education_manager = rowmax( primary_education_manager1)
keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${tenure}", clear 
merge 1:1 hhid plotid using "${Input}\\${country}\\${wave}\\${plot_roster}", nogen 
duplicates report hhid // one duplicate
gen respondent_id = s11b1q2 

sort  hhid (respondent_id)
collapse (first) respondent_id, by(hhid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster0}", clear
rename indiv respondent_id // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode  s1q2 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename s1q6 age_respondent
replace age_respondent=. if age_respondent==999
recode s1q16 ( 1 2 = 1 "Yes") (3/7 = 0 "No"), gen(married_respondent) 
keep hhid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear
gen respondent_id = indiv  // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")

recode s2q6 ( 1 = 1 "Yes") ( 2 = 0 "No"), gen(formal_education_respondent1) label(formal_education_respondent1)
recode s2q9 (0/15 51/64 98 99 = 0 "No" ) (16/43 321/424 = 1 "Yes"), gen(primary_education_respondent1) label(primary_education_respondent1)
replace primary_education_respondent1 = 0 if formal_education_respondent1==0


egen formal_education_respondent = rowmax(formal_education_respondent1 )
egen primary_education_respondent = rowmax( primary_education_respondent1)
keep hhid primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode s12q1 (1 = 1 "Yes") (2 0 = 0 "No"), gen(hh_shock) label(hh_shock)
collapse (max) hh_shock, by(hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${labor_hh}", clear
bys hhid: egen hh_size = count(indiv)
keep hhid hh_size
duplicates drop
isid hhid
save "${Temp}\\${temppath}\\size.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear

drop if inlist(item_cd, 313, 314, 315, 316 )
duplicates report hhid item_cd // a few duplicates 
duplicates drop hhid item_cd, force

gen hh_owns_= 0
foreach var of varlist sa4q4_1 sa4q4_2 sa4q4_3 sa4q4_4 sa4q4_5 { 
replace hh_owns_=1 if !mi(`var') & `var'!=0
replace hh_owns_=1 if sa4q3==1 | sa4q3==2
}


keep hhid item_cd hh_owns_
reshape wide hh_owns_ , i(hhid) j(item_cd)
foreach var of varlist hh_owns_* {
replace `var'=0 if `var'==.
}
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear

recode s10q1a (1 = 1) (2=0), gen(hh_owns) label(hh_owns) 
keep hh_owns hhid item_cd
reshape wide hh_owns , i(hhid) j(item_cd)
foreach var of varlist hh_owns* {
replace `var'=0 if `var'==.
}
factor hh_owns*, pcf 
predict hh_asset_index
keep hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover}",
recode s8q1__1 ( 0 = 0 "No") (1 = 1 "Yes"), gen(nonfarm_enterprise) label(nonfarm_enterprise)
keep hhid nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude (unavailable)

// agro ecological zone (unavailable)

// ALL GEOCOORDINATES UNAVAILABLE?

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster0}", clear
egen ID = concat (hhid indiv), punct("-")
drop if s1q4==2
recode  s1q2 (2=1 "Yes") (1=0 "No"), gen(female)
rename s1q6 age
recode s1q16 ( 1 2 = 1 "Yes") (3/7 = 0 "No"), gen(married) 
rename s1q3 relationship_head_temp
decode relationship_head_temp, gen(relationship_head)
replace relationship_head = proper(relationship_head)
replace relationship_head = substr(relationship_head,strpos(relationship_head, " " ) + 1, .)
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head== "Parent-In-Law"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head== "Son-In-Law/Daughter-In-Law"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head== "Brother/Sister-In-Law"
replace relationship_head = "Sister/Brother" if relationship_head== "Brother/Sister"
replace relationship_head = "Non Relative" if relationship_head== "Other Non-Relation (Specify)"
replace relationship_head = "Non Relative" if relationship_head== "Other (Specify)"
replace relationship_head = "Other Relative" if relationship_head== "Other Relation (Specify)"
replace relationship_head = "Servant" if relationship_head== "Domestic Help (Resident)"
replace relationship_head = "Grandparent" if relationship_head== "Grandfather/Mother"
replace relationship_head = "Son/Daughter" if relationship_head== "Adopted Child"
replace relationship_head = "Son/Daughter" if relationship_head== "Own Child"
replace relationship_head = "Son/Daughter" if relationship_head== "Step Child"
replace relationship_head = "Other Relative" if relationship_head== "Other Relation (Specify)"


// month of birth
gen birth_month= ym(s1q11, s1q10)
format birth_month %tm 

keep hhid ID married female age relationship_head  birth_month
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${anthropo}", clear
egen ID = concat (hhid indiv ), punct("-")
merge 1:1 hhid ID using "${Temp}\\${temppath}\\indiv_chars.dta",  keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\harvest_interview_month.dta",  keep(master match) nogen

// age in months
gen age_months = harvest_interview_month - birth_month

*Main anthropometric variables
egen weight=rowmedian(s4bq8a s4bq8b s4bq8c)
egen height=rowmedian(s4bq12a s4bq12b s4bq12c)

gen cage=age*12
replace cage = age_months if age==0| age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  hhid ID weight height
duplicates drop
save "${Temp}\\${temppath}\\wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${labor_hh}", clear
egen ID = concat (hhid indiv), punct("-")

recode s4aq10 (1 = 1) (2 = 0), gen( farm_work1)
recode s4aq11 (1 = 1) (2 = 0), gen( farm_work2)
gen farm_work = 1 if farm_work1==1 | farm_work2==1
replace  farm_work = 0 if farm_work1==0 

recode s4aq6 (1 = 1) (2 = 0), gen( SOB_work)

recode s4aq40_code (0 = 0) (.=.) (else = 1), gen( wage_work)
replace wage_work= 0 if s4aq32==2

gen working_age = s4aq1 == 1

// industry:
gen ind_ag = s4aq41_code >100 & s4aq41_code<300  // Agriculture 
gen ind_fish = s4aq41_code >300 & s4aq41_code<400
gen ind_mining = s4aq41_code > 500 & s4aq41_code<1000 // mining
gen ind_manuf = s4aq41_code >= 1010 & s4aq41_code<=4000 // manuf
gen ind_const = s4aq41_code >= 4100 & s4aq41_code<=4500 // construc
gen ind_serv = s4aq41_code >= 4501 & s4aq41_code<= 10000 // services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if s4aq42==1 | s4aq42==2   // remove self employment
replace `var' = 0 if s4aq21==1 // did not work
}
rename (s4aq12 s4aq7 s4aq5 ) (farm_hrs SB_hrs wage_hrs )
replace farm_hrs= 0 if s4aq11==2
replace SB_hrs= 0 if s4aq6==2
replace wage_hrs= 0 if s4aq4==2



foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}


keep ID hhid  farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education

use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear

egen ID = concat (hhid indiv), punct("-")

recode s2q6 ( 1 = 1 "Yes") ( 2 = 0 "No"), gen(formal_education1) label(formal_education1)
recode s2q9 (0/15 51/64 98 99 = 0 "No" ) (16/43 321/424 = 1 "Yes"), gen(primary_education1) label(primary_education1)
replace primary_education1 = 0 if formal_education1==0

egen formal_education = rowmax(formal_education1 )
egen primary_education = rowmax( primary_education1)
keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace



// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if s5bq1 ==1 // keep if consumed
rename item_cd food_id

gen A = food_id>=10 & food_id<=29
gen B = food_id>=30 & food_id<=38
gen C = food_id>=70 & food_id<=79
gen D = food_id>=60 & food_id<=69
gen E = food_id>=80 & food_id<=82 | food_id>=90 & food_id<=96
gen F = food_id>=83 & food_id<=85
gen G = food_id>=100 & food_id<=107
gen H = food_id>=40 & food_id<=48
gen I = food_id>=110 & food_id<=115
gen J = food_id>=50 & food_id<=56
gen K = food_id>=130 & food_id<=133
gen L = food_id>=120 & food_id<=122 | food_id>=141 & food_id<=148

collapse (max) A B C D E F G H I J K L, by(hhid)
egen HDDS = rowtotal(A B C D E F G H I J K L), missing 

merge 1:m hhid  using "${Input}\\${country}\\${wave}\\${HDDS}", 
collapse (max) HDDS, by(hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace
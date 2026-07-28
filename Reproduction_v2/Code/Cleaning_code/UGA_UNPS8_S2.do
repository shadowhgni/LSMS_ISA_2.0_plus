/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for UGA1       									  *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Uganda
global wave  UNPS 19
global cover  GSEC1.dta
global plot_area AGSEC2A.dta
global plot_area2 AGSEC2B.dta
global plot_inputs AGSEC3B.dta
global plot_labor AGSEC3B_1.dta
global shocks GSEC16.dta
global housing  GSEC10_1.dta
global plot_roster  AGSEC4B.dta
global perennial SEC_6B.dta
global csption pov2019_20.dta
global items AGSEC10.dta
global items_hh gsec14.dta
global harvest_rwdta  AGSEC5B.dta
global harvest_sold_rwdta  SEC_5A.dta
global indiv_roster GSEC2.dta
global educ GSEC4.dta
global anthropo GSEC6_5.dta
global labor_hh GSEC8.dta
global nfe GSEC12_1.dta
global nfe2 GSEC12_2.dta
global livestock AGSEC1.dta
global meta SEC_1_ALL.dta
global HDDS GSEC15B.dta 
global temppath UGA\UNPS19



**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID ), punct("-")

recast str32 hhid
decode cropID, gen(crop_name)
replace crop_name = substr(crop_name, strpos(crop_name, " ")+1, .)
keep hhid plot_id crop_name cropID  parcel_id

duplicates drop

replace crop_name = strproper(crop_name)
duplicates tag plot_id crop_name, gen(tag)
decode cropID, gen(cropname2)
replace crop_name = cropname2 if tag>0


duplicates report plot_id cropID crop_name
 
save "${Temp}\\${temppath}\\_S2plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid
keep hhid 
duplicates report hhid 
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recast str32 hhid
egen ID = concat (hhid pid), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\_S2indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************


// ea ID
use  "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhidold  
tempfile cover
save `cover', replace

use "${Input}\Uganda\UNPS 13\GSEC1.dta", clear
rename hhid hhid_new
tostring HHID_old, replace format("%30.0f")
rename HHID_old HHID
merge m:1 HHID using "${Input}\\Uganda\\UNPS 09\\2009_GSEC1.dta", keep(master match) keepusing(comm) nogen
drop HHID
rename hhid_new t0_hhid
replace t0_hhid = subinstr(t0_hhid, "-04-", "", 1)
keep comm t0_hhid
merge 1:m t0_hhid using  "${Input}\\Uganda\\UNPS 18\\GSEC1.dta", keep(using match)  nogen keepusing(hhid)
rename hhid hhidold
recast str32 hhidold
merge 1:m hhidold using  `cover', keep(using match)  nogen
rename comm ea_id
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\_S2ea_id.dta", replace

// stratum id 
use  "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhidold  
tempfile cover
save `cover', replace

use "${Input}\Uganda\UNPS 13\GSEC1.dta", clear
rename hhid hhid_new
tostring HHID_old, replace format("%30.0f")
rename HHID_old HHID
merge m:1 HHID using "${Input}\\Uganda\\UNPS 09\\2009_GSEC1.dta", keep(master match) keepusing(stratum) nogen
drop HHID
rename hhid_new t0_hhid
replace t0_hhid = subinstr(t0_hhid, "-04-", "", 1)
keep stratum t0_hhid
merge 1:m t0_hhid using  "${Input}\\Uganda\\UNPS 18\\GSEC1.dta", keep(using match)  nogen keepusing(hhid)
rename hhid hhidold
recast str32 hhidold
merge 1:m hhidold using `cover', keep(using match)  nogen
rename stratum strataid
recast str32 hhid
keep hhid strataid
duplicates drop
save "${Temp}\\${temppath}\\_S2strataid.dta", replace


// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear 
recast str32 hhid
rename region admin_1
keep hhid admin_1  
decode admin_1, gen(admin_1_name)
duplicates drop
save "${Temp}\\${temppath}\\_S2admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid
rename district admin_2_name
encode admin_2_name, gen(admin_2)
keep hhid admin_2 admin_2_name
duplicates drop
save "${Temp}\\${temppath}\\_S2admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid
egen admin_3_name = concat(district s1aq02a), punct("-")
encode admin_3_name, gen(admin_3)
keep hhid admin_3 admin_3_name
duplicates drop
save "${Temp}\\${temppath}\\_S2admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid
keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\_S2urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid
rename wgt pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\_S2weights.dta", replace

// planting month 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")
gen month = s4bq09_1
format month %tm 

gen year = s4bq09_2
replace year=. if s4bq09_2==9998
format year %ty
gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
keep hhid plot_id planting_month cropID
duplicates drop
save "${Temp}\\${temppath}\\_S2planting_month.dta", replace

// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")

// first condition
gen month1 = s5bq06f_1
format month1 %tm 

gen year1 = s5bq06f_1_1 
format year1 %ty 
gen harvest_end_month1 = ym(year1, month1)
replace harvest_end_month1 = . if harvest_end_month1< 677 | harvest_end_month1>726

format harvest_end_month1 %tmCCYYMon
drop month1 year1

// second condition
gen month2 = s5bq06f_2
format month2 %tm 

gen year2 = s5bq06f_1_2 
format year2 %ty 
gen harvest_end_month2 = ym(year2, month2)
format harvest_end_month2 %tmCCYYMon
drop month2 year2

egen harvest_end_month = rowmax(harvest_end_month1 harvest_end_month2)
format harvest_end_month %tmCCYYMon
keep plot_id cropID harvest_end_month
duplicates drop
save "${Temp}\\${temppath}\\_S2harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid

destring year, gen(year_num)
destring month, gen(month_num)
gen harvest_interview_month = ym( year_num, month_num)
format harvest_interview_month %tmCCYYMon
keep hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\_S2harvest_interview_month.dta", replace

// planting_interview_month (absent)

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 

egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id  = concat(hhid parcelID), punct("-")

// condition 1
gen harvest_kg1 = s5bq06a_1 * s5bq06d_1 // amount multiplied by CF
replace harvest_kg=0 if harvest_b==3

// condition 2
gen harvest_kg2 = s5bq06a_2 * s5bq06d_2 // amount multiplied by CF
replace harvest_kg2=0 if harvest_b==3

egen harvest_kg = rowtotal(harvest_kg*), missing

recode s5bq22_1 (.= 0 "No") (else = 1 "Yes"), gen(crop_shock) label(crop_shock) 
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(hhid plot_id cropID admin_1 admin_2 admin_3 parcelID pltid parcel_id)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\_S2harvest_kg.dta", replace

// percent area harvested

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")

recode s5bq22_1 (.= 0 "No") (else = 1 "Yes"), gen(crop_shock) label(crop_shock) 

recode s5bq22_1 (4 = 1 "Yes") (. = .) (else = 0 "No"), gen(drought_shock) label(drought_shock) 

recode s5bq22_1 (3 = 1 "Yes") (. = .) (else = 0 "No"), gen(flood_shock) label(flood_shock) 

recode s5bq22_1 (1 = 1 "Yes") (. = .) (else = 0 "No"), gen(pests_shock) label(pests_shock) 


keep hhid plot_id crop_shock pests_shock  drought_shock  flood_shock cropID  
duplicates drop
save "${Temp}\\${temppath}\\_S2crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
rename (s5bq06b_1 s5bq06c_1 s5bq06d_1 ) (unit condition conversion )
collapse (median) conversion, by(cropID unit condition)
tempfile Conversion_factors 
save `Conversion_factors', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta",  nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta",  nogen 

rename (s5bq07b_1 s5bq07c_1) (condition unit)
merge m:1 unit condition cropID using `Conversion_factors',  keep(master match) nogen 
gen harvest_sold_kg1 = s5bq07a_1 * conversion 
replace harvest_sold_kg1= 0 if s5bq07a_1==0

drop unit condition
rename (s5bq07b_2 s5bq07c_2) (condition unit)
merge m:1 unit condition cropID using `Conversion_factors',  keep(match) nogen
gen harvest_sold_kg2 = s5bq07a_2 * conversion 
replace harvest_sold_kg2= 0 if s5bq07a_2==0

drop unit condition	
egen harvest_sold_kg = rowtotal(harvest_sold_kg*), missing


collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( cropID hhid admin_1 admin_2 admin_3)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
save "${Temp}\\${temppath}\\_S2harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m hhid using "${Temp}\\${temppath}\\_S2harvest_kg.dta", keep(match)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(hhid)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
keep hhid share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\_S2harvest_sold_kg_hh.dta", replace


// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta",  nogen 

egen harvest_sold_value = rowtotal( s5bq08_1 s5bq08_2), missing

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( cropID hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\_S2harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
keep hhid  cropID 
duplicates drop

valuation_mdn_cr_noeaS2_sort hhid    cropID

main_crop_def_parcel cropID

collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(plot_id parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\_S2harvest_value_plot.dta", replace
collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\_S2harvest_value.dta", replace

// intercropped
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recode s4bq08 (. = .) (1= 0 "No") (2=1 "Yes"), gen(intercropped) label(intercropped)
keep cropID parcel_id intercropped
collapse (max) intercropped, by(parcel_id)
save "${Temp}\\${temppath}\\_S2intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
egen tag = tag(parcel_id cropID)
egen nb_seasonal_crop = total(tag), by(parcel_id)
keep parcel_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\_S2nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recast str32 hhid

merge m:1 cropID parcel_id  using "${Temp}\\${temppath}\\_S2harvest_value.dta", keep(match using) nogen

bys parcel_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if cropID==main_crop
bys parcel_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)



gen codesmain_crop = main_crop
gen codescropID = cropID
foreach c in main_crop cropID {
lab val `c' crop_code_4b__id
rename `c' `c'2
decode `c'2, gen(`c')
drop `c'2
replace `c' = upper(`c')

replace `c' = "YAMS" if `c'=="YAM"
replace `c' = "COCOYAM" if `c'=="COCO YAM"
replace `c' = "CARROT" if `c'=="CARROTS"
replace `c' = "SOYABEANS" if `c'=="SOYA BEANS"

gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c', "GROUNDNUTS", "SOY", "SOYABEAN", "SOYABEANS",  "BEANS", "BEAN", "VOANDZOU")  | strpos(`c',"BAMBARA NUT") | strpos(`c',"PEA")
replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c', "CASSAVA", "YAMS", "CARROT", "BEETS") | strpos(`c',"POTATO") | strpos(`c',"COCOYAM")
replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE" | `c'=="PADDY"
replace `c'2 = "MAIZE" if `c'=="MAIZE"
replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "MILLET" if `c'=="MILLET" | `c'=="ACHA" |  `c'=="FONIO" | `c'=="BULRUSH MILLET" | `c'=="FINGER MILLET"
replace `c'2 = "" if `c'=="."
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if codes`c' >=700 & !mi(codes`c' )
drop `c'
rename `c'2 `c'
}
tab cropID, gen(contains_crop_)

foreach n in  8 7 6 5 4 {
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

collapse (sum) share_crop* (max) contains_crop_*, by(parcel_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\_S2main_crop.dta", replace

// share of plot area planted by crop 

// land area
use "${Input}\\${country}\\${wave}\\${plot_area2}", clear
recast str32 hhid
tempfile plot_area2
save `plot_area2', replace

use "${Input}\\${country}\\${wave}\\${plot_area}", clear
recast str32 hhid

merge 1:1  hhid parcelID using `plot_area2'

egen parcel_id = concat(hhid parcelID), punct("-")

gen area_GPS = s2aq4 * 0.404686
replace area_GPS = s2aq04 * 0.404686 if area_GPS==.

gen area_self_reported = s2aq5 * 0.404686
replace area_self_reported = s2aq05 * 0.404686 if area_self_reported==.

gen plot_area_GPS=.
replace plot_area_GPS = area_GPS if area_GPS>0
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen
//encode admin_3, gen(admin_3_num)

isid hhid parcel_id
sort hhid parcel_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi impute pmm plot_area_GPS area_self_reported i.admin_3, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys hhid: egen farm_size = total(plot_area_GPS), missing

keep hhid parcel_id  plot_area_GPS farm_size 
duplicates drop
save "${Temp}\\${temppath}\\_S2plot_area.dta", replace


// improved 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")
recode s4bq13 (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)
collapse (max) improved  ,by(hhid plot_id cropID)
save "${Temp}\\${temppath}\\_S2improved.dta", replace

// seed kg 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta",  nogen 
egen plot_id = concat(hhid parcelID pltid), punct("-")
recode s4bq13 (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)
gen seed_kg = s4bq11a if s4bq11b==1 //kg
replace seed_kg = s4bq11a * 0.001 if s4bq11b==2 //gram
replace seed_kg = s4bq11a * 120 if s4bq11b==9
replace seed_kg = s4bq11a * 100 if s4bq11b==10
replace seed_kg = s4bq11a * 80 if s4bq11b==11
replace seed_kg = s4bq11a * 50 if s4bq11b==12
replace seed_kg = s4bq11a * 20 if s4bq11b==20
replace seed_kg = s4bq11a * 5 if s4bq11b==21
replace seed_kg = s4bq11a * 15 if s4bq11b==22
replace seed_kg = s4bq11a * 2 if s4bq11b==29
replace seed_kg = s4bq11a * 1 if s4bq11b==30 
replace seed_kg = s4bq11a * 0.5 if s4bq11b==31
replace seed_kg = s4bq11a * 20 if s4bq11b==37
replace seed_kg = s4bq11a * 10 if s4bq11b==38
replace seed_kg = s4bq11a * 5 if s4bq11b==39
replace seed_kg = s4bq11a * 2 if s4bq11b==40
replace seed_kg = 0 if s4bq16==2

collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by(admin_1 admin_2 admin_3 hhid plot_id cropID  improved)
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\_S2seed_kg.dta", replace
rename seed_kg   seeds_amount_purchased_kg 
save "${Temp}\\${temppath}\\_S2seeds_amount_purchased_kg.dta", replace
rename seeds_amount_purchased_kg  seed_kg
collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by(admin_1 admin_2 admin_3 hhid plot_id cropID )
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\_S2seed_kg_merge.dta", replace

// seed_kg_sold (absent)

// seed_value_sold 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")
recode s4bq13 (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)
gen seed_value_temp = s4bq15
collapse (sum) seed_value_temp (count) n_seed_value_temp=seed_value_temp  ,by(hhid plot_id cropID improved)
replace seed_value_temp=. if n_seed_value_temp==0
save "${Temp}\\${temppath}\\_S2seed_value_temp.dta", replace


// seed value 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta",  nogen 
egen plot_id = concat(hhid parcelID pltid), punct("-")

valuation_median_seeds_noea_S2 hhid plot_id cropID 

keep  plot_id cropID seed_value
duplicates drop
save "${Temp}\\${temppath}\\_S2seed_value.dta", replace

// labor days
use "${Input}\\${country}\\${wave}\\${plot_labor}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen ID = concat(hhid fam_labour_3b__id), punct("-")
isid plot_id ID

bys plot_id (s3bq33): gen n = _n if s3bq33==1
forvalues n = 1/14 {
gen ID_worker`n' = ID if  n==`n'
}

gen total_family_labor_days = s3bq33_1
replace total_family_labor_days = 0 if s3bq33==2

collapse (firstnm) ID_worker1 ID_worker2 ID_worker3 ID_worker4 ID_worker5 ID_worker6 ID_worker7 ID_worker8 ID_worker9 ID_worker10 ID_worker11 ID_worker12 ID_worker13 ID_worker14 (sum) total_family_labor_days (count) n_total_family_labor_days = total_family_labor_days, by(plot_id hhid)
replace total_family_labor_days=. if n_total_family_labor_days==0
tempfile total_family_labor_days
save `total_family_labor_days', replace

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 
merge 1:m plot_id using `total_family_labor_days'


gen hired_man_days = s3bq35a
replace hired_man_days = 0 if s3bq34==2

gen hired_woman_days = s3bq35b
replace hired_woman_days = 0 if s3bq34==2

gen hired_child_days = s3bq35c
replace hired_child_days = 0 if s3bq34==2

gen wage = s3bq36 

egen  total_hired_labor_days= rowtotal(hired_*), missing

egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days), missing


valuation_median_wages_noea_S2 hhid wage wage wage

gen hired_labor_value = child_wage * total_hired_labor_days
replace hired_labor_value = 0 if total_hired_labor_days==0

keep total_labor_days parcel_id total_family_labor_days total_hired_labor_days hired_labor_value ID_worker*
collapse (sum) total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value (firstnm) ID_worker* (count) Ntotal_labor_days = total_labor_days Ntotal_family_labor_days = total_family_labor_days Ntotal_hired_labor_days = total_hired_labor_days Nhired_labor_value = hired_labor_value , by(parcel_id)
foreach var in total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value {
	replace `var' = . if N`var'==0
}
save "${Temp}\\${temppath}\\_S2labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID ), punct("-")
recode s3bq13 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
collapse (max)  inorganic_fertilizer, by(parcel_id)

save "${Temp}\\${temppath}\\_S2inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-") 
egen parcel_id = concat(hhid parcelID), punct("-") 
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 

recode s3bq13 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

generate nitrogen_kg =s3bq15 *0.46 if s3bq14 ==1
replace nitrogen_kg =s3bq15 *0.18 if s3bq14 ==2
replace nitrogen_kg =s3bq15 *0 if s3bq14 ==3 
replace nitrogen_kg =s3bq15 *((0.46+0.18)/2) if s3bq14 ==4 
replace nitrogen_kg =0 if s3bq13 ==2

gen fert_kg = s3bq15
replace fert_kg = 0 if s3bq13==2

collapse (sum) nitrogen_kg  fert_kg   (count) n_nitrogen_kg = nitrogen_kg n_fert_kg = fert_kg   , by(parcel_id hhid admin_1 admin_2 admin_3)
foreach var in nitrogen_kg fert_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\_S2nitrogen_kg.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-") 
isid plot_id
recast str32 hhid
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\_S2admin3.dta", keep(master match) nogen 
gen fert_purchased_value = s3bq18
gen fert_purchased_kg  = s3bq17

valuation_median_fert_price_noea hhid fert

keep admin_1 admin_2 admin_3 fert_value
duplicates drop

merge 1:m admin_1 admin_2 admin_3 using "${Temp}\\${temppath}\\_S2nitrogen_kg.dta", keep(match) nogen

foreach n in fert  {
gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep parcel_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\_S2inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")  
recode s3bq04 (1 =1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(parcel_id)
save "${Temp}\\${temppath}\\_S2organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
recode s3bq22 (2 = 0 "No") (1 = 1 "Yes") (. = .), gen(used_pesticides) label(used_pesticides)
replace used_pesticides=0 if s3bq23==3
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\_S2used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${plot_area2}", clear
recast str32 hhid
tempfile plot_area2
save `plot_area2', replace

use "${Input}\\${country}\\${wave}\\${plot_area}", clear
recast str32 hhid

merge 1:1 hhid parcelID using `plot_area2'
merge 1:m hhid parcelID using  "${Temp}\\${temppath}\\_S2harvest_kg.dta", nogen
drop plot_id parcel_id
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID ), punct("-")
recode s2aq8 (1 2 6 7 = 1 "Yes") (3 4 8 9 96 = 0 "No") (5=.) , gen(plot_owned) label(plot_owned)
replace plot_owned= 0 if _merge==2

recode s2aq23 (1/3 = 1 "Yes") (4 = 0 "No"), gen(plot_certificate) label(plot_certificate)
replace plot_certificate= 0 if _merge==2
collapse  (max) plot_owned plot_certificate, by(parcel_id)

save "${Temp}\\${temppath}\\_S2plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_area2}", clear
recast str32 hhid
tempfile plot_area2
save `plot_area2', replace

use "${Input}\\${country}\\${wave}\\${plot_area}", clear
recast str32 hhid
merge 1:1 hhid parcelID using  `plot_area2'
merge 1:m hhid parcelID using  "${Temp}\\${temppath}\\_S2harvest_kg.dta", nogen
drop plot_id parcel_id
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recode  a2aq18 (1 = 1 "Yes") (. =.) (else = 0 "No"), gen(irrigated) label(irrigated)
collapse (max)  irrigated, by(parcel_id)

save "${Temp}\\${temppath}\\_S2irrigated.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${plot_area2}", clear
recast str32 hhid
tempfile plot_area2
save `plot_area2', replace

use "${Input}\\${country}\\${wave}\\${plot_area}", clear
recast str32 hhid

merge 1:1 hhid parcelID using  `plot_area2'
merge 1:m hhid parcelID using  "${Temp}\\${temppath}\\_S2harvest_kg.dta", nogen
drop plot_id parcel_id
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recode s2aq22a (.=.) (0 = 0 "No") (* = 1 "Yes") , gen(erosion_protection) label(erosion_protection)
replace erosion_protection=1 if s2aq22b!=. & !mi(s2aq22b)
collapse (max)  erosion_protection, by(parcel_id)

save "${Temp}\\${temppath}\\_S2erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
recast str32 hhid
recode A10itemcod_ID (6 = 1 "Yes") (.=.) (else= 0 "No"), gen(tractor) label(tractor)
replace tractor = 0 if s10q04a==2  & A10itemcod==6 // not used
replace tractor = 1 if s10q06a==1 & A10itemcod==6
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\_S2tractor.dta", replace

// nb fallow (absent)

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")
recast str32 hhid
gen n = 1
bys hhid: egen nb_plots = count(n)
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\_S2nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${educ}", clear
recast str32 hhid
recode s4q05 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode s4q07 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education = 0 if inrange(s4q09,0, 16)
replace primary_education = 1 if inrange(s4q09,17, 60)
replace primary_education = 0 if formal_education==0

bys hhid: egen hh_primary_education= max(primary_education) 
bys hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(hhid)
keep hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_primary_education.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recast str32 hhid
recode s10q01 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
keep hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recast str32 hhid
gen age = h2q8  
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents

bysort hhid: egen dep=total(dep_temp)
bysort hhid: egen nondep=total(nondep_temp)

gen hh_dependency_ratio = (dep/nondep)
replace hh_dependency_ratio = dep if nondep==0

collapse (max)  hh_dependency_ratio, by(hhid)
save "${Temp}\\${temppath}\\_S2hh_dependency_ratio.dta", replace

// livestock
use "${Input}\\${country}\\${wave}\\${livestock}", clear
recast str32 hhid
duplicates report hhid
recode lvstck ( 2 = 0 "No") (1 = 1 "Yes"), gen(livestock) label(livestock)	
replace livestock= 1 if hh_anm==1
replace livestock= 1 if hh_plty==1
replace livestock=0 if lvstck==. & hh_plty==. & hh_anm==.
lab val livestock livestock 
keep hhid livestock
duplicates drop

save "${Temp}\\${temppath}\\_S2livestock.dta", replace


// consumption quint 
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = (nrrexp30 * 12)/hsize
xtile cons_quint= totcons, n(5)
keep cons_quint hhid 
duplicates drop
save "${Temp}\\${temppath}\\_S2cons_quint.dta", replace

// consumption aggregate 
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = (nrrexp30 * 12)/hsize
keep totcons hhid 
duplicates drop
save "${Temp}\\${temppath}\\_S2totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID pltid), punct("-")	
egen parcel_id = concat(hhid parcelID), punct("-")	
recast str32 hhid
gen  manager_id = s3bq03_3
replace manager_id = s3bq03_4a if s3bq03_2==2
sort  parcel_id (manager_id)
collapse (first) manager_id  , by(hhid parcel_id)
duplicates drop
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
gen manager_id = pid  // this is the HH member id 
recast str32 hhid
merge 1:m  hhid manager_id using `ID_list', keep(match ) nogen
recode h2q3 (2=1 "Yes") (1=0 "No"), gen(female_manager) label(female_manager)
gen age_manager = h2q8
recode h2q10 ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married_manager) label(married_manager) 
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
keep parcel_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\_S2Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
gen manager_id =  pid  // this is the HH member id 
recast str32 hhid
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen

recode s4q05 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode s4q07 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager = 0 if inrange(s4q09,0, 16)
replace primary_education_manager = 1 if inrange(s4q09,17, 60)
replace primary_education_manager = 0 if formal_education_manager==0
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")

keep parcel_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\_S2Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear 
recast str32 hhid
egen plot_id = concat(hhid parcelID pltid), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
gen respondent_id= s5bq05_1 
sort  parcel_id (respondent_id)
collapse (first) respondent_id, by(parcel_id hhid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename pid respondent_id // this is the HH member id 
recast str32 hhid
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode  h2q3 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename h2q8 age_respondent
recode h2q10 ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married_respondent) 
keep parcel_id female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\_S2respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear
gen respondent_id = pid  // this is the HH member id 
recast str32 hhid
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")

recode s4q05 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode s4q07 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent = 0 if inrange(s4q09,0, 16)
replace primary_education_respondent = 1 if inrange(s4q09,17, 60)
replace primary_education_respondent = 0 if formal_education_respondent==0

keep parcel_id primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\_S2Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid
tempfile cover
save `cover', replace

use "${Input}\\${country}\\${wave}\\${shocks}", clear
recast str32 hhid
recode s16q01 (2 . =0 "No") (1 = 1 "Yes") , gen(hh_shock) label(hh_shock)
collapse (max) hh_shock, by(hhid) 
merge 1:1 hhid using `cover',
replace hh_shock = 0 if _merge==2
keep hh_shock hhid
duplicates drop
save "${Temp}\\${temppath}\\_S2shock.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recast str32 hhid
bys hhid: egen hh_size = count(pid)
collapse (max) hh_size , by(hhid)
save "${Temp}\\${temppath}\\_S2hh_size.dta", replace

// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
recast str32 hhid
tempfile items
save `items', replace

bys hhid: gen n = _n 
bys hhid: egen max = max(n)
expand 23-n if max==n
bys hhid: replace n = _n 
replace A10itemcod_ID=n


// Merging back with the original dataset to determine household ownership
merge 1:1 hhid A10itemcod_ID using `items', 
drop if A10itemcod_ID==22 	// we exclude "other"
recode _merge (3=1) (1=0), gen(hh_owns_)
rename A10itemcod_ID itemid 

keep hhid itemid hh_owns_
reshape wide hh_owns_ , i(hhid) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\_S2ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear
recast str32 hhid
drop if h14q02>20 // drop other
	recode h14q03 (1 4 5 = 1) (.= . ) (3=0), gen(hh_owns) label(hh_owns) 
	keep hh_owns hhid h14q02
	reshape wide hh_owns , i(hhid) j(h14q02)
	foreach var of varlist hh_owns* {
		replace `var' = 0 if `var'==.
	}
	
	factor hh_owns*, pcf 
	predict hh_asset_index
keep hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\_S2hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${cover}", clear
recast str32 hhid
tempfile cover
save `cover', replace


use "${Input}\\${country}\\${wave}\\${nfe}", clear
recast str32 hhid
merge m:1 hhid using `cover'
egen total = rowtotal(NA1a NA1b NA1c NA1d NA1e NA1f NA1g NA1h), missing
gen nonfarm_enterprise =1 if total<16
replace nonfarm_enterprise = 0 if total==16
replace nonfarm_enterprise = 0 if _merge==2
keep nonfarm_enterprise hhid
tempfile nonfarm_enterprise
save `nonfarm_enterprise', replace

use "${Input}\\${country}\\${wave}\\${nfe2}", clear
recast str32 hhid
merge m:1 hhid using `nonfarm_enterprise' 
replace nonfarm_enterprise  = 1 if _merge==1 
replace nonfarm_enterprise = 0 if h12q20==2
collapse (max)  nonfarm_enterprise, by(hhid)
duplicates drop
save "${Temp}\\${temppath}\\_S2nfe.dta", replace

// latitude (absent)

// agro ecological zone (absent)

// distance to nearest road (absent)

// distance to nearest population center (absent)

// distance to nearest market (absent)

// plot slope (absent)

// plot elevation (absent)

// plot distance to hh (absent)

// total wetness index (absent)

// soil variables 

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
egen ID = concat (hhid pid), punct("-")
recast str32 hhid

recode  h2q3 (2=1 "Yes") (1=0 "No"), gen(female) 
rename h2q8 age
recode h2q10  ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married) 
replace married = 0 if age<10
rename h2q4 relationship_head_temp 
decode relationship_head_temp, gen(relationship_head) 
replace relationship_head = proper(relationship_head)
replace relationship_head = "Niece/Nephew" if relationship_head== "Nephew / Niece"
replace relationship_head = "Non Relative" if relationship_head== "Non-Relative"
replace relationship_head = "Other Relative" if relationship_head== "Other Relatives"
replace relationship_head = "Son/Daughter Of Head Or Spouse" if relationship_head== "Son / Daughter Of Head Or Spouse"
replace relationship_head = "Sister/Brother Of Head Or Spouse" if relationship_head== "Sister / Brother Of Head Or Spouse"

// month of birth
gen birth_month= ym(h2q9c, h2q9b)
format birth_month %tm 

keep hhid ID married female age relationship_head  birth_month
duplicates drop
save "${Temp}\\${temppath}\\_S2indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${anthropo}", clear
recast str32 hhid
egen ID = concat (hhid pid ), punct("-")
merge 1:1 hhid ID using "${Temp}\\${temppath}\\_S2indiv_chars.dta",  keep(master match) nogen
merge m:1 hhid  using "${Temp}\\${temppath}\\_S2harvest_interview_month.dta",  keep(master match) nogen

// age in months
gen age_months = harvest_interview_month - birth_month

*Main anthropometric variables
gen weight= s6q27a if age<5
gen height= s6q28a2  if age<5
replace height = s6q28b2 if height==. & age<5

gen cage=age*12
replace cage = age_months if age==0| age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  hhid ID weight height
duplicates drop
save "${Temp}\\${temppath}\\_S2wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recast str32 hhid
tempfile indiv_roster
save `indiv_roster', replace

use "${Input}\\${country}\\${wave}\\${labor_hh}", clear
egen ID = concat (hhid pid), punct("-")
compress hhid
merge 1:1 hhid pid using `indiv_roster',

gen working_age = _merge==3 & h2q8>=10

recode s8q12 (1 = 1) (2 = 0), gen(farm_work)
recode s8q06 (1 = 1) (2 = 0), gen( SOB_work)
replace SOB_work = 1 if s8q08==1
recode s8q04 (1 = 1) (2 = 0), gen( wage_work)

// industry:
gen 	ind_ag = h8q19b_twoDigit == 61 | h8q19b_twoDigit==62 | h8q19b_twoDigit==63 | h8q19b_fourDigit> 9129  & h8q19b_fourDigit< 9216 // Agriculture 
gen 	ind_fish = h8q19b_fourDigit==6222 | h8q19b_fourDigit==9216 // fishing
gen 	ind_mining = h8q19b_threeDigit == 9311  // mining
gen 	ind_manuf = h8q19b_twoDigit >= 72 & h8q19b_twoDigit<=83 | h8q19b_fourDigit ==9329 // manuf
gen 	ind_const = h8q19b_twoDigit == 9313  | h8q19b_twoDigit == 9312	// construc
gen 	ind_serv = h8q19b_twoDigit >= 11 & h8q19b_twoDigit<= 54 | h8q19b_twoDigit==91 | h8q19b_twoDigit>93 &!mi(h8q19b_twoDigit) 	// services


egen hrs= rowtotal(s8q36a s8q36b s8q36c s8q36d s8q36e s8q36f s8q36g), missing
gen farm_hrs = hrs if farm_work==1 & ind_ag ==1 & wage_work==0
replace farm_hrs = 0 if farm_work == 0
gen SB_hrs = hrs if SOB_work==1 & ind_ag ==1 & wage_work==0
replace SB_hrs = 0 if SOB_work == 0
gen wage_hrs = hrs if wage_work==1
replace wage_hrs = 0 if wage_work == 0

foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}

keep ID hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
merge 1:1 ID hhid  using "${Temp}\\${temppath}\\_S2indiv_frame.dta", keep(using match)
foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if _merge==2
}
save "${Temp}\\${temppath}\\_S2labor.dta", replace

// education

use "${Input}\\${country}\\${wave}\\${educ}", clear
compress hhid

egen ID = concat (hhid pid), punct("-")

recode s4q05 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode s4q07 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
replace primary_education = 0 if inrange(s4q09,0, 16)
replace primary_education = 1 if inrange(s4q09,17, 60)
replace primary_education = 0 if formal_education==0
keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\_S2educ_indiv.dta", replace

// HDDS

use "${Input}\\${country}\\${wave}\\${HDDS}", clear
compress hhid
tempfile temp
save `temp', replace

keep if CEB03 ==1 // keep if consumed
rename CEB01 item_cd

gen A = item_cd>=101 & item_cd<=104 | item_cd>=110 & item_cd<=116 | item_cd>=172 & item_cd<=173 | item_cd>=1043 & item_cd<=1151
gen B = item_cd>=105 & item_cd<=109
gen C = item_cd>=135 & item_cd<=139 | item_cd>=164 & item_cd<=168 | item_cd>=1351 & item_cd<=1353 | item_cd>=1652 & item_cd<=1654
gen D = item_cd>=130 & item_cd<=134 | item_cd>=169 & item_cd<=171 | item_cd==174 | item_cd>=1311 & item_cd<=1313
gen E = item_cd>=117 & item_cd<=121 | item_cd>=1211 & item_cd<=1214
gen F = item_cd==124
gen G = item_cd>=1221 & item_cd<=1237
gen H = item_cd>=140 & item_cd<=145 | item_cd>=162 & item_cd<=163
gen I = item_cd>=125 & item_cd<=126 | item_cd>=1251 & item_cd<=1254 | item_cd==1281 
gen J = item_cd>=127 & item_cd<=129 | item_cd>=1271 & item_cd<=1272
gen K = item_cd==147 | item_cd>=1471 & item_cd<=1472
gen L = item_cd>=148 & item_cd<=150

collapse (max) A B C D E F G H I J K L, by(hhid)
egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m hhid  using `temp', 

collapse (max) HDDS, by(hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\_S2HDDS.dta", replace


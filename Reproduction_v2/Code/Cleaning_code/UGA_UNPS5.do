/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Extract data for UGA1         *
 * Date: December 2023                                                            *
 * -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Uganda
global wave  UNPS 15
global cover  GSEC1.dta
global parcel1 AGSEC2A.dta
global parcel2 AGSEC2B.dta
global plot_inputs AGSEC3A.dta
global shocks GSEC16.dta
global housing  GSEC10_1.dta
global plot_roster  AGSEC4A.dta
global perennial SEC_6B.dta
global csption pov2015_16.dta
global items AGSEC10.dta
global items_hh gsec14.dta
global harvest_rwdta  AGSEC5A.dta
global harvest_sold_rwdta  SEC_5A.dta
global indiv_roster GSEC2.dta
global educ GSEC4.dta
global anthropo gsec6_1.dta
global labor_hh GSEC8.dta
global nfe GSEC12_1.dta
global nfe2 GSEC12_2.dta
global livestock AGSEC1.dta
global meta SEC_1_ALL.dta
global HDDS GSEC15B.dta 
global temppath UGA\UNPS15



**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID ), punct("-")

decode cropID, gen(crop_name)
keep hhid plot_id crop_name cropID  parcel_id


duplicates drop

duplicates report plot_id cropID crop_name parcel_id
 
save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear

keep hhid 
duplicates report hhid 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

egen ID = concat (hhid pid), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// ea ID
use "${Input}\Uganda\UNPS 13\GSEC1.dta", clear
rename hhid hhid_new
tostring HHID_old, replace format("%30.0f")
rename HHID_old HHID
merge m:1 HHID using "${Input}\\Uganda\\UNPS 09\\2009_GSEC1.dta", keep(master match) keepusing(comm) nogen
drop HHID
rename hhid_new hhid
replace hhid = subinstr(hhid, "-04-", "", 1)
keep comm hhid
merge 1:1 hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(using match)  nogen
rename comm ea_id
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata id
use "${Input}\Uganda\UNPS 13\GSEC1.dta", clear
rename hhid hhid_new
tostring HHID_old, replace format("%30.0f")
rename HHID_old HHID
merge m:1 HHID using "${Input}\\Uganda\\UNPS 09\\2009_GSEC1.dta", keep(master match) keepusing(stratum) nogen
drop HHID
rename hhid_new hhid
replace hhid = subinstr(hhid, "-04-", "", 1)
keep stratum hhid
merge 1:1 hhid using "${Input}\\${country}\\${wave}\\${cover}", keep(using match)  nogen
rename stratum strataid
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
rename district admin_2
rename district_name admin_2_name
keep hhid admin_2 admin_2_name
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename scounty_code admin_3
rename subcounty_name admin_3_name
keep hhid admin_3 admin_3_name
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear

keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename h_xwgt_W5 pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear

egen plot_id = concat(hhid parcelID plotID), punct("-")
gen month = a4aq9_1
	replace month=. if a4aq9_1==99

	gen year = 2000 +  a4aq9_2
format year %ty
gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
keep hhid plot_id planting_month cropID
duplicates drop
save "${Temp}\\${temppath}\\planting_month.dta", replace


// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

egen plot_id = concat(hhid parcelID plotID), punct("-")

// first condition
gen month1 = a5aq6f
	format month1 %tm 

	gen year1 = a5aq6f_1 
format year %ty 
gen harvest_end_month = ym(year, month)

format harvest_end_month %tmCCYYMon
drop month year

format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(plot_id cropID )

save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${livestock}", clear
gen harvest_interview_month = ym( year, month)
	format harvest_interview_month %tmCCYYMon 
keep harvest_interview_month hhid
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month (absent)

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 

egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")

gen harvest_kg = a5aq6a * a5aq6d // amount multiplied by CF
	replace harvest_kg=0 if a5aq5_2==1 
	replace harvest_kg = a5aq6a if a5aq6c==1
	
** recode a5aq22 (.= 0 "No") (else = 1 "Yes"), gen(crop_shock) label(crop_shock) 
**replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 // no valid crop shock var

collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(hhid plot_id cropID admin_1 admin_2 admin_3 parcelID plotID parcel_id)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// percent area harvested

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

egen plot_id = concat(hhid parcelID plotID), punct("-")

gen crop_shock=.
gen drought_shock =.
gen flood_shock =.	
gen pests_shock=. 
collapse (max)  crop_shock pests_shock  drought_shock  flood_shock   , by(cropID hhid plot_id)  
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

rename (a5aq6b a5aq6c a5aq6d) (unit condition conversion )
collapse (median) conversion, by(cropID unit condition)
tempfile Conversion_factors 
save `Conversion_factors', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta",  nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_kg = a5aq7a * A5AQ7D
replace harvest_sold_kg= a5aq7a if a5aq7c==1
replace harvest_sold_kg= 0 if a5aq7a==0

collapse (sum) harvest_sold_kg (count) n_harvest_sold_kg = harvest_sold_kg, by( cropID hhid admin_1 admin_2 admin_3)
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
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_value = a5aq8 * 100

collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( cropID hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

keep hhid  cropID 
duplicates drop

valuation_median_crops_noea_sort hhid    cropID

main_crop_def_parcel cropID

collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(plot_id parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\harvest_value_plot.dta", replace
collapse (sum) harvest_value (max) main_crop (count) Nharvest_value = harvest_value, by(parcel_id  cropID )
replace harvest_value =. if Nharvest_value==0
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recode a4aq8 (. = .) (1= 0 "No") (2=1 "Yes"), gen(intercropped) label(intercropped)
keep cropID plot_id intercropped parcel_id
collapse (max) intercropped, by(parcel_id)
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
egen tag = tag(parcel_id cropID)
egen nb_seasonal_crop = total(tag), by(parcel_id)
keep parcel_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace

// main crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")

merge m:1 cropID parcel_id  using "${Temp}\\${temppath}\\harvest_value.dta", keep(match using) nogen

bys parcel_id: egen total_value_plot= total(harvest_value), missing
gen maincrop_valueshare_temp = harvest_value/ total_value_plot if cropID==main_crop
bys parcel_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)

lab def lbcrp 1 "BARLEY" , add
lab val cropID lbcrp

gen codesmain_crop = main_crop
gen codescropID = cropID
foreach c in main_crop cropID {
lab val `c' lbcrp
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
replace `c'2 = "MILLET" if `c'=="MILLET" | `c'=="ACHA" |  `c'=="FONIO" | `c'=="BULRUSH MILLET" | `c'=="FINGER MILLET"
replace `c'2 = "WHEAT" if `c'=="WHEAT"
replace `c'2 = "BARLEY" if `c'=="BARLEY"
replace `c'2 = "" if `c'=="."
tab `c' if `c'2==""
replace `c'2 = "OTHER" if `c'2==""
replace `c'2 = "PERENNIAL/FRUIT" if codes`c' >=700 & !mi(codes`c' )
drop `c'
rename `c'2 `c'
}
tab cropID, gen(contains_crop_)

foreach n in 9 8 7 6 5 4  {
local i = `n' + 2
rename contains_crop_`n' contains_crop_`i'
} 

foreach n in 3 2 1  {
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

collapse (sum) share_crop* (max) contains_crop_* , by(parcel_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop.dta", replace

// share of plot area planted by crop 

// land area

use "${Input}\\${country}\\${wave}\\${plot_area}", clear
merge 1:1  hhid parcelID using "${Input}\\${country}\\${wave}\\${plot_area2}"

egen parcel_id = concat(hhid parcelID), punct("-")

gen area_GPS = a2aq4 * 0.404686
replace area_GPS = a2bq4 * 0.404686 if area_GPS==.

gen area_self_reported = a2aq5 * 0.404686
replace area_self_reported = a2bq5 * 0.404686 if area_self_reported==.

gen plot_area_GPS=.
replace plot_area_GPS = area_GPS if area_GPS>0
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
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
save "${Temp}\\${temppath}\\plot_area.dta", replace


// improved 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear

egen plot_id = concat(hhid parcelID plotID), punct("-")
recode a4aq13  (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)
collapse (max) improved  ,by(hhid plot_id cropID)
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 
egen plot_id = concat(hhid parcelID plotID), punct("-")
recode a4aq13  (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)
gen seed_kg = a4aq11a if a4aq11b==1 //kg
	replace seed_kg = a4aq11a * 0.001 if a4aq11b==2 //gram
	replace seed_kg = a4aq11a * 120 if a4aq11b==9
	replace seed_kg = a4aq11a * 100 if a4aq11b==10
	replace seed_kg = a4aq11a * 80 if a4aq11b==11
	replace seed_kg = a4aq11a * 50 if a4aq11b==12
	replace seed_kg = a4aq11a * 20 if a4aq11b==20
	replace seed_kg = a4aq11a * 5 if a4aq11b==21
	replace seed_kg = a4aq11a * 15 if a4aq11b==22
	replace seed_kg = a4aq11a * 2 if a4aq11b==29
	replace seed_kg = a4aq11a * 1 if a4aq11b==30 
	replace seed_kg = a4aq11a * 0.5 if a4aq11b==31
	replace seed_kg = a4aq11a * 20 if a4aq11b==37
	replace seed_kg = a4aq11a * 10 if a4aq11b==38
	replace seed_kg = a4aq11a * 5 if a4aq11b==39
	replace seed_kg = a4aq11a * 2 if a4aq11b==40
	replace seed_kg= 0 if a4aq16==2

collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by(admin_1 admin_2 admin_3 hhid plot_id cropID  improved)
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg.dta", replace
rename seed_kg   seeds_amount_purchased_kg 
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace
rename seeds_amount_purchased_kg  seed_kg
collapse (sum) seed_kg (count) n_seed_kg=seed_kg  ,by(admin_1 admin_2 admin_3 hhid plot_id cropID )
replace seed_kg=. if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace

// seed_kg_sold (absent)

// seed_value_sold 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear

egen plot_id = concat(hhid parcelID plotID), punct("-")
recode a4aq13  (. = .) (1 = 0 "No") (2 = 1 "Yes"), gen(improved) label(improved)

gen seed_value_temp = a4aq15
collapse (sum) seed_value_temp (count) n_seed_value_temp=seed_value_temp  ,by(hhid plot_id cropID improved)
replace seed_value_temp=. if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace


// seed value 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 
egen plot_id = concat(hhid parcelID plotID), punct("-")

keep hhid plot_id cropID  
duplicates drop
valuation_median_seeds_noea hhid plot_id cropID 

keep  plot_id cropID seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 

local n = 0
foreach mem in a b c d e {
gen ID_worker`n' = a3aq33`mem' 
local ++n
}

drop a3aq33a a3aq33b a3aq33c a3aq33d a3aq33e
	egen total_family_labor_days= rowtotal(a3aq33*), missing 

	gen hired_man_days = a3aq35a
	replace hired_man_days = 0 if a3aq34==2
	
	gen hired_woman_days = a3aq35b
	replace hired_woman_days = 0 if a3aq34==2

	gen hired_child_days = a3aq35c
	replace hired_child_days = 0 if a3aq34==2
	
	gen wage = a3aq36 
	
egen  total_hired_labor_days= rowtotal(hired_*), missing

egen total_labor_days = rowtotal(total_hired_labor_days total_family_labor_days), missing


valuation_median_wages_noea hhid wage wage wage

gen hired_labor_value = child_wage * total_hired_labor_days
replace hired_labor_value = 0 if total_hired_labor_days==0


keep total_labor_days parcel_id total_family_labor_days total_hired_labor_days hired_labor_value
collapse (sum) total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value (count) Ntotal_labor_days = total_labor_days Ntotal_family_labor_days = total_family_labor_days Ntotal_hired_labor_days = total_hired_labor_days Nhired_labor_value = hired_labor_value , by(parcel_id)
foreach var in total_labor_days total_family_labor_days total_hired_labor_days hired_labor_value {
	replace `var' = . if N`var'==0
}
save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID ), punct("-")
recode a3aq13 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
collapse (max)  inorganic_fertilizer, by(parcel_id)

save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-") 
egen parcel_id = concat(hhid parcelID), punct("-") 

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 

recode a3aq13 (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

generate nitrogen_kg =a3aq15 *0.46 if a3aq14 ==1
replace nitrogen_kg =a3aq15 *0.18 if a3aq14 ==2
replace nitrogen_kg =a3aq15 *0 if a3aq14 ==3 
replace nitrogen_kg =a3aq15 *((0.46+0.18)/2) if a3aq14 ==4 
replace nitrogen_kg =0 if a3aq13 ==2

gen fert_kg = a3aq15
replace fert_kg = 0 if a3aq13==2

collapse (sum) nitrogen_kg  fert_kg   (count) n_nitrogen_kg = nitrogen_kg n_fert_kg = fert_kg   , by(parcel_id hhid admin_1 admin_2 admin_3)
foreach var in nitrogen_kg fert_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-") 
isid plot_id

merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 
gen fert_purchased_value = a3aq18
gen fert_purchased_kg  = a3aq17

valuation_median_fert_price_noea hhid fert

keep admin_1 admin_2 admin_3 fert_value
duplicates drop

merge 1:m admin_1 admin_2 admin_3 using "${Temp}\\${temppath}\\nitrogen_kg.dta", keep(match) nogen

foreach n in fert  {
    gen value_`n' = `n'_value * `n'_kg
}

egen inorganic_fertilizer_value = rowtotal(value_*), missing

keep parcel_id  inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace

// organic fert
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-") 
egen parcel_id = concat(hhid parcelID), punct("-") 
recode a3aq4 (1 =1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
collapse (max)  organic_fertilizer, by(parcel_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
recode a3aq22 (2 = 0 "No") (1 = 1 "Yes") (. = .), gen(used_pesticides) label(used_pesticides)
replace used_pesticides=0 if a3aq23==3
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${parcel1}", clear
merge 1:1 hhid parcelID using "${Input}\\${country}\\${wave}\\${parcel2}"
merge 1:m hhid parcelID using "${Temp}\\${temppath}\\harvest_kg.dta", nogen keep(master match)
drop parcel_id
egen parcel_id = concat(hhid parcelID), punct("-")
recode a2aq8 (1 2 = 1 "Yes") (3 4 = 0 "No") (5 6=.) , gen(plot_owned) label(plot_owned)
replace plot_owned= 0 if _merge==2

recode a2aq23 (1/3 = 1 "Yes") (4 = 0 "No"), gen(plot_certificate) label(plot_certificate)
replace plot_certificate= 0 if _merge==2
replace plot_owned = 1 if plot_certificate==1
collapse  (max) plot_owned plot_certificate, by(parcel_id)

save "${Temp}\\${temppath}\\plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${parcel1}", clear
merge 1:1 hhid parcelID using  "${Input}\\${country}\\${wave}\\${parcel2}"

merge 1:m hhid parcelID using  "${Temp}\\${temppath}\\harvest_kg.dta", nogen
drop plot_id parcel_id
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recode  a2aq18 (1 = 1 "Yes") (. =.) (else = 0 "No"), gen(irrigated) label(irrigated)
replace irrigated=1 if a2bq16==1
replace irrigated=0 if inlist(a2bq16, 2, 3)
collapse (max)  irrigated, by(parcel_id)

save "${Temp}\\${temppath}\\irrigated.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${parcel1}", clear
merge 1:1 hhid parcelID using  "${Input}\\${country}\\${wave}\\${parcel2}"

merge 1:m hhid parcelID using  "${Temp}\\${temppath}\\harvest_kg.dta", nogen
drop plot_id parcel_id
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
recode a2aq22a (.=.) (8 = 0 "No") (* = 1 "Yes") , gen(erosion_protection) label(erosion_protection)
replace erosion_protection=1 if a2aq22b!=8 & !mi(a2aq22b)
	replace erosion_protection=1 if !mi(a2bq20a) | !mi(a2bq20b)
	replace erosion_protection=0 if a2bq20a==8 | mi(a2bq20a) & a2bq20b==8
collapse (max)  erosion_protection, by(parcel_id)

save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${items}", clear
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover}",
gen tractor = 1 if Farm_Implement==1 & A10itemcod==6
	replace tractor = 0 if Farm_Implement==0 | A10itemcod!=6
replace tractor = 0 if _merge==2
	replace tractor = 0 if a10q4==2 & A10itemcod==6 // not used
	replace tractor = 1 if a10q6==1 & A10itemcod==6
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow (absent)

// nb plots
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")

gen n = 1
bys hhid: egen nb_plots = count(n)
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${educ}", clear


recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode h4q7 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
	replace primary_education = 0 if inrange(h4q9,0, 16)
	replace primary_education = 1 if inrange(h4q9,17, 60)
	replace primary_education = 0 if formal_education==0
bys hhid: egen hh_primary_education= max(primary_education) 
bys hhid: egen hh_formal_education = max(formal_education)

collapse (max) hh_formal_education hh_primary_education, by(hhid)
keep hhid hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace

// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode h10q1 (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
replace hh_electricity_access=1 if h10q6==1
keep hhid hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace

// dependency ratio
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear


gen age = h2q8  
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

duplicates report hhid
recode lvstck ( 2 = 0 "No") (1 = 1 "Yes"), gen(livestock) label(livestock)
replace livestock= 1 if hh_anm==1
replace livestock= 1 if hh_plty==1
replace livestock=0 if lvstck==. & hh_plty==. & hh_anm==.
lab val livestock livestock 
keep hhid livestock
duplicates drop

save "${Temp}\\${temppath}\\livestock.dta", replace


// consumption quint 
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen hhid = subinstr(hh, "-05-", "", 1)
gen totcons = (nrrexp30 * 12)/hsize
xtile cons_quint= totcons, n(5)
keep cons_quint hhid 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace

// consumption aggregate 
use "${Input}\\${country}\\${wave}\\${csption}", clear
gen totcons = (nrrexp30 * 12)/hsize
gen hhid = subinstr(hh, "-05-", "", 1)
keep totcons hhid 
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace

// hh size
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear


bys hhid: egen hh_size = count(pid)
collapse (max) hh_size , by(hhid)
save "${Temp}\\${temppath}\\hh_size.dta", replace



// manager chars
use "${Input}\\${country}\\${wave}\\${plot_inputs}", clear
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
gen long manager_id_temp = a3aq3_3 
	replace manager_id_temp = a3aq3_4a if manager_id==.
	
		tostring manager_id_temp, gen(manager_id_temp2)
		gen ID_person = substr(manager_id_temp2, -3, 3)
		gen ID_temp = substr(hhid, 2, 5)
		gen P = "P"
		egen ID_temp2 = concat(P ID_temp)
		egen manager_id = concat(ID_temp2 ID_person ), punct("-")
sort  parcel_id (manager_id)
collapse (first) manager_id  , by(hhid parcel_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear

gen manager_id = pid  // this is the HH member id 

merge 1:m  hhid manager_id using `ID_list', keep(match ) nogen
recode h2q3 (2=1 "Yes") (1=0 "No"), gen(female_manager) label(female_manager)
gen age_manager = h2q8
recode h2q10 ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married_manager) label(married_manager) 
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
keep parcel_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear


gen manager_id =  pid  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen

recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode h4q7 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
	replace primary_education_manager = 0 if inrange(h4q9,0, 16)
	replace primary_education_manager = 1 if inrange(h4q9,17, 60)
	replace primary_education_manager = 0 if formal_education_manager==0

rename manager_id id
egen manager_id = concat (hhid id ), punct("-")

keep parcel_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace

// respondent chars
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear 
egen plot_id = concat(hhid parcelID plotID), punct("-")
egen parcel_id = concat(hhid parcelID), punct("-")
gen long respondent_id_temp = a5aq5_1
		tostring respondent_id_temp, gen(respondent_id_temp2)
		gen ID_person = substr(respondent_id_temp2, -3, 3)
		gen ID_temp = substr(hhid, 2, 5)
		gen P = "P"
		egen ID_temp2 = concat(P ID_temp)
		egen respondent_id = concat(ID_temp2 ID_person ), punct("-")
sort  parcel_id (respondent_id)
collapse (first) respondent_id, by(parcel_id hhid)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear


rename pid respondent_id // this is the HH member id 

merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")
recode  h2q3 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename h2q8 age_respondent
recode h2q10 ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married_respondent) 
keep parcel_id female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${educ}", clear


gen respondent_id = pid  // this is the HH member id 

merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")

recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode h4q7 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education_respondent) label(primary_education_respondent)
	replace primary_education_respondent = 0 if inrange(h4q9,0, 16)
	replace primary_education_respondent = 1 if inrange(h4q9,17, 60)
	replace primary_education_respondent = 0 if formal_education_respondent==0

keep parcel_id primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
replace hhid = subinstr(hhid, "-05-", "", 1)
format h16q2y %ty
	format h16q02a %tm
	gen month_shock = ym( h16q2y, h16q02a)
	gen shock = month_shock + h16q02b // = the month when the shock ended
	format shock %tmCCYYMon
	
	gen hh_shock=1 if shock>= tm(2013Jan)  & !mi(shock)
	replace hh_shock=0 if shock< tm(2013Jan) | shock==. 
	collapse (max) hh_shock, by(hhid) 
save "${Temp}\\${temppath}\\shock.dta", replace


// ag assets
use "${Input}\\${country}\\${wave}\\${items}", clear
recode Farm_Implement (1=1) (2=0) (.=0), gen(hh_owns_)
	rename A10itemcod itemid 
	drop if itemid==22

keep hhid itemid hh_owns_
reshape wide hh_owns_ , i(hhid) j(itemid)
factor hh_owns_*, pcf 
predict ag_asset_index
drop hh_owns*
keep hhid ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace

// hh assets
use "${Input}\\${country}\\${wave}\\${items_hh}", clear
drop if h14q2>20 // drop other
		recode h14q3 (1 = 1) (.= . ) (2=0), gen(hh_owns) label(hh_owns) 
		keep hh_owns hhid h14q2
		reshape wide hh_owns , i(hhid) j(h14q2)
		foreach var of varlist hh_owns* {
			replace `var' = 0 if `var'==.
		}

factor hh_owns*, pcf 
predict hh_asset_index
keep hhid hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
recode h12q1 ( 1 = 1) (2 = 0), gen(nonfarm_enterprise)
collapse (max)  nonfarm_enterprise, by(hhid)
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude 


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


recode  h2q3 (2=1 "Yes") (1=0 "No"), gen(female) 
rename h2q8 age
recode h2q10  ( 1 2 = 1 "Yes") (3 4 5 = 0 "No"), gen(married) 
replace married = 0 if age<10
rename h2q4 relationship_head_temp 
decode relationship_head_temp, gen(relationship_head) 
replace relationship_head = proper(relationship_head)
replace relationship_head = "Niece/Nephew" if relationship_head== "Nephew/Niece"
replace relationship_head = "Non Relative" if relationship_head== "Other (Specify)"
replace relationship_head = "Other Relative" if relationship_head== "Other Relatives"
replace relationship_head = "Grandchild" if relationship_head== "Grand Child"
replace relationship_head = "Son/Daughter" if relationship_head== "Son/Daughter Of Head"

// month of birth
gen birth_month= ym(h2q9c, h2q9b)
format birth_month %tm 

keep hhid ID married female age relationship_head  birth_month
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${anthropo}", clear

egen ID = concat (hhid pid ), punct("-")
merge 1:1 hhid ID using "${Temp}\\${temppath}\\indiv_chars.dta",  nogen

// assume interview month is 
// age in months
gen age_months=h6q4

*Main anthropometric variables
gen weight= h6q27a
gen height= h6q28a 
replace height = h6q28b if height==.

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


egen ID = concat (hhid pid), punct("-")

recode h8q12 (1 = 1) (2 = 0), gen(farm_work)
recode h8q6 (1 = 1) (2 = 0), gen( SOB_work)
replace SOB_work = 1 if h8q8==1
recode h8q4 (1 = 1) (2 = 0), gen( wage_work)

egen hrs= rowtotal(h8q36a h8q36b h8q36c h8q36d h8q36e h8q36f h8q36g), missing
gen farm_hrs = hrs if farm_work==1  & wage_work==0
replace farm_hrs = 0 if farm_work == 0
gen SB_hrs = hrs if SOB_work==1 & wage_work==0
replace SB_hrs = 0 if SOB_work == 0
gen wage_hrs = hrs if wage_work==1
replace wage_hrs = 0 if wage_work == 0


keep ID hhid farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs 
duplicates drop
merge 1:1 ID hhid  using "${Temp}\\${temppath}\\indiv_frame.dta", keep(using match)
foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs  {
replace `var' = 0 if _merge==2
}
save "${Temp}\\${temppath}\\labor.dta", replace

// education

use "${Input}\\${country}\\${wave}\\${educ}", clear

egen ID = concat (hhid pid), punct("-")

recode h4q5 (2 3 =1 "Yes") (1 = 0 "No"), gen(formal_education) label(formal_education)
recode h4q7 (10/16 = 0 "No") (. 98 =.) (else =1 "Yes"), gen(primary_education) label(primary_education)
	replace primary_education = 0 if inrange(h4q9,0, 16)
	replace primary_education = 1 if inrange(h4q9,17, 60)
		replace primary_education = 0 if formal_education==0

keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace


// HDDS

use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if h15bq3a ==1 // keep if consumed
rename itmcd item_cd

gen A = item_cd>=101 & item_cd<=104 | item_cd>=110 & item_cd<=116 | item_cd>=172 & item_cd<=173  | item_cd==180 | item_cd>=190 & item_cd<=191
gen B = item_cd>=105 & item_cd<=109
gen C = item_cd>=135 & item_cd<=139 | item_cd>=164 & item_cd<=168 | item_cd>=181 & item_cd<=182
gen D = item_cd>=130 & item_cd<=134 | item_cd>=169 & item_cd<=171 | item_cd==174 
gen E = item_cd>=117 & item_cd<=121
gen F = item_cd==124
gen G = item_cd>=122 & item_cd<=123
gen H = item_cd>=140 & item_cd<=145 | item_cd>=162 & item_cd<=163
gen I = item_cd>=125 & item_cd<=126
gen J = item_cd>=127 & item_cd<=129
gen K = item_cd==147 
gen L = item_cd>=148 & item_cd<=150

collapse (max) A B C D E F G H I J K L, by(hhid)
 egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m hhid  using "${Input}\\${country}\\${wave}\\${cover}", 
collapse (max) HDDS, by(hhid)
save "${Temp}\\${temppath}\\HDDS.dta", replace

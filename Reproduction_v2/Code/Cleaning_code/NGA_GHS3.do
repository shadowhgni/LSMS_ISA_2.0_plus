/*********************************************************************************
 * LSMS-ISA Harmonised Panel Analysis Code                                        *
 * Description: Extract data for GHS3          *
 * Date: December 2023                                                            *
 * -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Nigeria
global wave  GHS 15
global cover1  secta_plantingw3.dta
global cover2  secta_harvestw3.dta
global indiv_roster  sect1_plantingw3.dta
global indiv_roster0  sect1_harvestw3.dta
global indiv_roster1  sect2_harvestw3.dta
global lab_roster1 sect11c1_plantingw3.dta
global lab_roster2 secta2_harvestw3.dta
global shocks sect15a_harvestw3.dta
global housing  sect11_plantingw3.dta
global plot_roster  sect11a1_plantingw3.dta
global ferts secta11d_harvestw3.dta
global csption1 cons_agg_wave3_visit1.dta
global csption2 cons_agg_wave3_visit2.dta
global items secta4_harvestw3.dta
global items_hh sect5_plantingw3.dta
global harvest_rwdta  secta3i_harvestw3.dta
global harvest_sold_rwdta  secta3ii_harvestw3.dta
global perennial  sect11f_plantingw3.dta
global HDDS sect10b_harvestw3.dta
global livestock sect11i_plantingw3.dta
global conversions ag_conv_w3.dta
global seeds sect11e_plantingw3.dta
global pesticides secta11c2_harvestw3.dta
global tenure sect11b1_plantingw3.dta
global labor_hh sect3_plantingw3.dta
global nfe sect9_harvestw3.dta
global geovars_hh NGA_HouseholdGeovars_Y3.dta
global geovars NGA_PlotGeovariables_Y3.dta
global anthropo  sect4a_harvestw3.dta
global temppath NGA\GHS15



**********************************************************
**** A) Master frame of crops, plots and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
rename cropname crop_name
egen plot_id = concat(hhid plotid), punct("-")
keep hhid plot_id crop_name cropcode 

sort plot_id cropcode, stable
bys plot_id cropcode  : replace crop_name = crop_name[1]

duplicates drop

duplicates tag plot_id crop_name, gen(tag)
decode cropcode, gen(cropname2)
replace crop_name = cropname2 if tag>0
replace crop_name = substr(crop_name, strpos(crop_name, ".")+2, .)
duplicates report plot_id cropcode crop_name
 
save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover1}", clear
keep hhid 
duplicates report hhid 
duplicates drop
save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame
use "${Input}\\${country}\\${wave}\\${indiv_roster0}", clear
merge 1:1 hhid indiv using "${Input}\\${country}\\${wave}\\${indiv_roster}"
drop if s1q4a==2 // drop those that don't live in hh
rename indiv id
egen ID = concat (hhid id ), punct("-")
keep hhid ID
duplicates drop
save "${Temp}\\${temppath}\\indiv_frame.dta", replace


**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover1}", clear 
drop ea lga
merge 1:1 hhid using "${Input}\\${country}\\GHS 10\\secta_plantingw1.dta", keep(master match) nogen
egen ea_id = concat(lga ea), punct("-")
keep hhid ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace


// strata
use "${Input}\\${country}\\${wave}\\${cover1}", clear 
rename zone zone_w3
merge 1:1 hhid using "${Input}\\${country}\\GHS 10\\secta_plantingw1.dta", keep(master match)
rename zone strataid
keep hhid strataid  
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover1}", clear 
rename zone admin_1
keep hhid admin_1  
decode admin_1, gen(admin_1_name)
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 2
use "${Input}\\${country}\\${wave}\\${cover1}", clear
rename state admin_2 
keep hhid admin_2
decode admin_2, gen(admin_2_name)
duplicates drop
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover1}", clear
rename lga admin_3
keep hhid admin_3
decode admin_3, gen(admin_3_name)
replace admin_3_name = strupper(admin_3_name)
duplicates drop
save "${Temp}\\${temppath}\\admin3.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover1}", clear
recode sector (1 = 1 "Yes") (2 =0 "No"), gen(urban) label(urban)
keep hhid urban
duplicates drop
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${csption1}", clear
merge 1:1 hhid using "${Input}\\${country}\\${wave}\\${csption2}", nogen
rename hhweight pw
keep pw hhid
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${perennial}", clear

egen plot_id = concat( hhid plotid), punct("-")

gen month = s11fq3a
gen year= s11fq3b

gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
drop month year

collapse (min) planting_month , by(hhid cropcode plot_id)
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hhid plotid), punct("-")

gen month = sa3iq6c1
gen year = sa3iq6c2
gen harvest_end_month = ym( year, month)
format harvest_end_month %tmCCYYMon
collapse (max) harvest_end_month, by(plot_id cropcode ) 
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover2}", clear
gen month = saq13m
format month %tm 
gen year = saq13y
format year %ty
gen harvest_interview_month = ym( year, month)
format harvest_interview_month %tmCCYYMon
keep hhid harvest_interview_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover1}", clear
gen month = saq13m
format month %tm 
gen year = saq13y
format year %ty
gen planting_interview_month = ym( year, month)
format planting_interview_month %tmCCYYMon
keep hhid planting_interview_month

duplicates drop
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
tempfile Conversions
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen 
egen plot_id = concat(hhid plotid), punct("-")
recode sa3iq3 (1 = 1 "Yes") (2 =0 "No"), gen(any_harvest) label(any_harvest) 
rename cropcode crop_cd 
rename sa3iq6ii unit_cd 
count if inlist(., crop_cd, unit_cd, admin_1)
merge m:1 crop_cd unit_cd admin_1 using `Conversions', keep(master match) 
gen harvest_kg_temp= sa3iq6i * conv_ 
drop conv_ unit_cd
replace harvest_kg_temp=0 if any_harvest==0 // Respondents who did not harvest anything from the plot were coded as missing

rename sa3iq6d2 unit_cd 
merge m:1 crop_cd unit_cd admin_1 using `Conversions', keep(master match) nogen
gen harvest_kg_expected = sa3iq6d1 * conv_ 
drop conv_ unit_cd 

egen harvest_kg = rowtotal( harvest_kg_temp harvest_kg_expected), missing

recode sa3iq3 (2 = 1 "Yes") (1 = 0 "No"), gen(crop_shock) label(crop_shock)
replace crop_shock = 0 if sa3iq4==9 | sa3iq4==10 
replace harvest_kg = . if harvest_kg==0 & crop_shock!=1 
rename crop_cd cropcode
collapse (sum) harvest_kg (count) n_harvest_kg = harvest_kg , by(plot_id cropcode admin_1 admin_2 admin_3 hhid)
replace harvest_kg = . if n_harvest_kg==0
save "${Temp}\\${temppath}\\harvest_kg.dta", replace

// // percent area harvested
// use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
//
// egen plot_id = concat( hhid plotid), punct("-")
// gen pct_area_harvested = sa3iq5c
// replace pct_area_harvested=100 if sa3iq3==2 & !inlist(sa3iq4, 9, 10)
// keep hhid plot_id cropcode pct_area_harvested
// duplicates drop
// save "${Temp}\\${temppath}\\pct_area_harvested.dta", replace

// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(hhid plotid), punct("-")
recode sa3iq3 (2 = 1 "Yes") (1 = 0 "No"), gen(crop_shock) label(crop_shock)
replace crop_shock = 0 if sa3iq4==9 | sa3iq4==10 

recode sa3iq4 (1 = 1 "Yes") (2/8 11 = 0 "No") ( 9 10 =.), gen(drought_shock) label(drought_shock) 
replace drought_shock=0 if sa3iq3==1

recode sa3iq4 (2 = 1 "Yes") (1 3/8 11 = 0 "No") ( 9 10 =.), gen(flood_shock) label(flood_shock) 
replace flood_shock=0 if sa3iq3==1

recode sa3iq4 (3 = 1 "Yes") (1 2 4/8 11 = 0 "No") ( 9 10 =.), gen(pests_shock) label(pests_shock) 
replace pests_shock=0 if sa3iq3==1

gen pct_lost = 100 - sa3iq5c 
replace pct_lost = pct_lost/100

collapse (max)  crop_shock pests_shock  drought_shock flood_shock    , by(hhid plot_id cropcode)

save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
tempfile Conversions_kg
save `Conversions_kg', replace
bys crop_cd unit_cd: egen mad = mad(conv_)
collapse (median) conv_ (first) mad , by(crop_cd unit_cd)
tempfile Conversions_kg_onlyunit
save `Conversions_kg_onlyunit', replace

use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
rename (zone state lga) (admin_1 admin_2 admin_3)
rename cropcode crop_cd 
rename sa3iiq5b unit_cd
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta",  nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

merge m:1 admin_1 crop_cd unit_cd using `Conversions_kg', keep(master match) nogen
gen harvest_sold_kg = sa3iiq5a * conv_
replace harvest_sold_kg  = 0 if sa3iiq3==2

rename crop_cd cropcode
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
rename (zone state lga) (admin_1 admin_2 admin_3)
rename cropcode crop_cd 
rename sa3iiq5b unit_cd
merge m:1 hhid using "${Temp}\\${temppath}\\admin1.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin2.dta", nogen 
merge m:1 hhid using "${Temp}\\${temppath}\\admin3.dta",  nogen 

gen harvest_sold_value = sa3iiq6

rename crop_cd cropcode
collapse (sum) harvest_sold_value (count) n_harvest_sold_value = harvest_sold_value, by( cropcode hhid admin_1 admin_2 admin_3)
replace harvest_sold_value = . if n_harvest_sold_value==0
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_sold_rwdta}", clear
keep hhid  cropcode 
duplicates drop

valuation_median_crops_noea_sort hhid    cropcode

main_crop_def cropcode


keep plot_id harvest_value cropcode main_crop 
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${perennial}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11fq2 (1= 0 "No") (2/6 = 1 "Yes"), gen(intercropped) label(intercropped)
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


use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s11fc5==2 // drop permanent crops
gen count_temporary=1
collapse (sum) count_temporary, by(cropcode)
tempfile Perennial_crops_temp 
save `Perennial_crops_temp', replace

use "${Input}\\${country}\\${wave}\\${perennial}", clear
drop if s11fc5==1 // drop seasonal crops
gen count_permanent=1
collapse (sum) count_permanent, by(cropcode)
merge 1:1 cropcode using `Perennial_crops_temp' // There is overlap
gen permanent_crop=0 
replace permanent_crop=1 if _merge==1 
replace permanent_crop=1 if _merge==3 & count_permanent>count_temporary // if crops appear in the "permanent" list more * frequently, they are counted as permanent crops. 
replace permanent_crop = 1 if cropcode==3030
drop if permanent_crop==0 // this results in a list of crop codes which are permanent
drop permanent_crop count_permanent count_temporary _merge
tempfile Perennial_crops_list 
save `Perennial_crops_list', replace
rename cropcode main_crop
tempfile Perennial_crops_list_MC 
save `Perennial_crops_list_MC', replace

use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
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
lab val `c' cropcode
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

collapse (sum)   share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
save "${Temp}\\${temppath}\\main_crop.dta", replace

// share of plot area planted by crop 


// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
rename (zone state lga) (admin_1 admin_2 admin_3)
egen plot_id = concat( hhid plotid), punct("-") 

gen area_self_reported= s11aq4a
replace area_self_reported = area_self_reported * 0.0667 if s11aq4b==4 
replace area_self_reported = area_self_reported * 0.4 if s11aq4b==5
replace area_self_reported = area_self_reported * 0.0001 if s11aq4b==7

// heaps
replace area_self_reported = area_self_reported * 0.00012 if s11aq4b==1 & admin_1==1
replace area_self_reported = area_self_reported * 0.00016 if s11aq4b==1 & admin_1==2
replace area_self_reported = area_self_reported * 0.00011 if s11aq4b==1 & admin_1==3
replace area_self_reported = area_self_reported * 0.00019 if s11aq4b==1 & admin_1==4
replace area_self_reported = area_self_reported * 0.00021 if s11aq4b==1 & admin_1==5
replace area_self_reported = area_self_reported * 0.00012 if s11aq4b==1 & admin_1==6

// ridges 
replace area_self_reported = area_self_reported * 0.0027 if s11aq4b==2 & admin_1==1
replace area_self_reported = area_self_reported * 0.004 if s11aq4b==2 & admin_1==2
replace area_self_reported = area_self_reported * 0.00494 if s11aq4b==2 & admin_1==3
replace area_self_reported = area_self_reported * 0.0023 if s11aq4b==2 & admin_1==4
replace area_self_reported = area_self_reported * 0.0023 if s11aq4b==2 & admin_1==5
replace area_self_reported = area_self_reported * 0.00001 if s11aq4b==2 & admin_1==6

// stands
replace area_self_reported = area_self_reported * 0.00006 if s11aq4b==3 & admin_1==1
replace area_self_reported = area_self_reported * 0.00016 if s11aq4b==3 & admin_1==2
replace area_self_reported = area_self_reported * 0.00004 if s11aq4b==3 & admin_1==3
replace area_self_reported = area_self_reported * 0.00004 if s11aq4b==3 & admin_1==4
replace area_self_reported = area_self_reported * 0.00013 if s11aq4b==3 & admin_1==5
replace area_self_reported = area_self_reported * 0.00041 if s11aq4b==3 & admin_1==6


gen plot_area_GPS= s11aq4c
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
recode s11eq3b (3 4 =0 "No") (1 2 =1 "Yes"), gen(improved)
collapse (max) improved, by(hhid plot_id cropcode)
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg

use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
tempfile Conversions
save `Conversions', replace
use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
collapse (median) conv_, by(crop_cd unit_cd)
tempfile Conversions_nozone
save `Conversions_nozone', replace
use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
collapse (median) conv_  , by( unit_cd)
tempfile Conversions_nozonenocrop
save `Conversions_nozonenocrop', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( hhid plotid), punct("-") // This creates a unique plot id.
rename (zone state lga) (admin_1 admin_2 admin_3)

// left over seeds
gen seed_kg_preconv = s11eq6a 
rename s11eq6b unit_cd
rename cropcode crop_cd
count if unit_cd==. | admin_1==. | seed_kg_preconv==. | crop_cd==.  // many missing
merge m:1   crop_cd unit_cd admin_1 using  `Conversions', keep(master match) nogen // this is a terrible match rate, mainly because the database is missing many crops
gen seed_kg1= seed_kg_preconv * conv_
drop conv_  
merge m:1  crop_cd unit_cd using `Conversions_nozone', keep(master match) nogen
replace seed_kg1= seed_kg_preconv * conv_ if mi(seed_kg1)
drop conv_  
merge m:1  unit_cd using `Conversions_nozonenocrop', keep(master match) nogen
replace seed_kg1= seed_kg_preconv * conv_ if mi(seed_kg1)
drop conv_ seed_kg_preconv unit_cd
replace seed_kg1 = 0 if s11eq4==2

// free seeds  
gen seed_kg_preconv = s11eq10a 
rename s11eq10b unit_cd
count if unit_cd==. | admin_1==. | seed_kg_preconv==. | crop_cd==.  // many missing
merge m:1  crop_cd unit_cd admin_1 using  `Conversions', keep(master match) nogen 
gen seed_kg2= seed_kg_preconv * conv_
drop conv_  
merge m:1  crop_cd unit_cd using `Conversions_nozone', keep(master match) nogen
replace seed_kg2= seed_kg_preconv * conv_ if mi(seed_kg2)
drop conv_  
merge m:1  unit_cd using `Conversions_nozonenocrop', keep(master match) nogen
replace seed_kg2= seed_kg_preconv * conv_ if mi(seed_kg2)
drop conv_ seed_kg_preconv unit_cd

replace seed_kg2 = 0 if s11eq8==2


// 1st source commercial 
gen seed_kg_preconv = s11eq18a 
rename s11eq18b unit_cd
count if unit_cd==. | admin_1==. | seed_kg_preconv==. | crop_cd==.  // many missing
merge m:1  crop_cd unit_cd admin_1 using  `Conversions', keep(master match) nogen 
gen seed_kg3= seed_kg_preconv * conv_
drop conv_  
merge m:1  crop_cd unit_cd using `Conversions_nozone', keep(master match) nogen
replace seed_kg3= seed_kg_preconv * conv_ if mi(seed_kg3)
drop conv_  
merge m:1  unit_cd using `Conversions_nozonenocrop', keep(master match) nogen
replace seed_kg3= seed_kg_preconv * conv_ if mi(seed_kg3)
drop conv_ seed_kg_preconv unit_cd

replace seed_kg3 = 0 if s11eq14==2


// 2nd source commercial 
gen seed_kg_preconv = s11eq30a 
rename s11eq30b unit_cd
count if unit_cd==. | admin_1==. | seed_kg_preconv==. | crop_cd==.  // many missing
merge m:1  crop_cd unit_cd admin_1 using  `Conversions', keep(master match) nogen 
gen seed_kg4= seed_kg_preconv * conv_
drop conv_  
merge m:1  crop_cd unit_cd using `Conversions_nozone', keep(master match) nogen
replace seed_kg4= seed_kg_preconv * conv_ if mi(seed_kg4)
drop conv_  
merge m:1  unit_cd using `Conversions_nozonenocrop', keep(master match) nogen
replace seed_kg4= seed_kg_preconv * conv_ if mi(seed_kg4)
drop conv_ seed_kg_preconv unit_cd

replace seed_kg4 = 0 if s11eq26==2


egen seed_kg = rowtotal(seed_kg*), missing
replace seed_kg=0 if s11eq3==2

rename crop_cd cropcode
collapse (sum)  seed_kg (count) n_seed_kg = seed_kg , by( cropcode hhid plot_id admin_1 admin_2 admin_3)
replace seed_kg = . if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg.dta", replace
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace


// seed_kg_sold 
use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
tempfile Conversions
save `Conversions', replace

use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( hhid plotid), punct("-") // This creates a unique plot id.
rename (zone state lga) (admin_1 admin_2 admin_3)

// 1st source commercial 
gen seed_kg_preconv = s11eq18a 
rename s11eq18b unit_cd // to merge
rename cropcode crop_cd // to merge
count if crop_cd==. | unit_cd==. | admin_1==. 
merge m:1  crop_cd unit_cd admin_1 using  `Conversions', keep(master match) nogen 
gen seed_kg_purch1= seed_kg_preconv * conv_
drop conv_ seed_kg_preconv unit_cd

// 2nd source commercial 
gen seed_kg_preconv = s11eq30a 
rename s11eq30b unit_cd
count if crop_cd==. | unit_cd==. | admin_1==. 
merge m:1  crop_cd unit_cd admin_1 using  `Conversions', keep(master match) nogen 
gen seed_kg_purch2= seed_kg_preconv * conv_
drop conv_ seed_kg_preconv unit_cd
rename crop_cd cropcode

egen seeds_amount_purchased_kg= rowtotal(seed_kg_purch1 seed_kg_purch2), missing
collapse (sum) seeds_amount_purchased_kg (count) n_seeds_amount_purchased_kg = seeds_amount_purchased_kg, by(cropcode hhid plot_id)
replace seeds_amount_purchased_kg = . if n_seeds_amount_purchased_kg==0
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( hhid plotid), punct("-") // This creates a unique plot id.
rename (zone state lga) (admin_1 admin_2 admin_3)

egen seed_value_temp = rowtotal(s11eq21 s11eq33), missing 

collapse  (sum) seed_value_temp (count) n_seed_value_temp = seed_value_temp , by(cropcode hhid plot_id )
replace seed_value_temp = . if n_seed_value_temp==0
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( hhid plotid), punct("-") // This creates a unique plot id.
rename (zone state lga) (admin_1 admin_2 admin_3)

keep cropcode plot_id hhid plot_id
duplicates drop

val_median_seeds_noimp_noea hhid plot_id cropcode 

keep  plot_id cropcode seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days
use "${Input}\\${country}\\${wave}\\${lab_roster1}", clear
egen plot_id = concat( hhid plotid), punct("-")
egen PPmean_fam_hr_per_day = rowmean(s11c1q1*4)

* 1) Family labor

gen hh_labordays1 = s11c1q1a2 * s11c1q1a3
gen hh_labordays2 = s11c1q1b2 * s11c1q1b3
gen hh_labordays3 = s11c1q1c2 * s11c1q1c3
gen hh_labordays4 = s11c1q1d2 * s11c1q1d3
    egen PPtotal_family_labor_days = rowtotal(hh_labordays*), missing 


* 2) Hired labor

gen PPhired_man_days = s11c1q2 * s11c1q3
replace PPhired_man_days = 0 if s11c1q2 == 0

gen PPhired_woman_days = s11c1q5 *s11c1q6
replace PPhired_woman_days = 0 if s11c1q5 == 0

gen PPhired_child_days = s11c1q8 *s11c1q9
replace PPhired_child_days = 0 if s11c1q8 == 0

egen PPtotal_hired_labor_days= rowtotal(PPhired_man_days PPhired_woman_days PPhired_child_days), missing

gen PPhired_man_wage= s11c1q4

gen PPhired_woman_wage= s11c1q7

gen PPhired_child_wage = s11c1q10

valuation_median_wages hhid PPhired_man_wage PPhired_woman_wage PPhired_child_wage

gen man_labor_value = man_wage * PPhired_man_wage
gen woman_labor_value = woman_wage * PPhired_woman_wage
gen child_labor_value = child_wage * PPhired_child_wage
egen PPhired_labor_value = rowtotal (*_labor_value), missing


* ID code of workers

local let "a b c d"
forvalues n = 1/4 {
local a: word `n' of `let'
egen ID`a' = concat(hhid s11c1q1`a'1 ), punct("-")
gen ID_worker`n'_PP = ID`a' if  s11c1q1`a'1 !=.
}


tempfile PPtotal_labor_days 
save `PPtotal_labor_days', replace 

use "${Input}\\${country}\\${wave}\\${lab_roster2}", clear
egen plot_id = concat( hhid plotid), punct("-") 
egen PHmean_fam_hr_per_day = rowmean(sa2q1b_*4)

* 1) Family labor 

local a "a b c d e f g h"
	
	forvalues x =1/8 {
	    local let: word `x' of `a'
	   gen hh_labordays`x'1 = sa2q1b_`let'2 * sa2q1b_`let'3
	   gen hh_labordays`x'2 = sa2q1`let'2 * sa2q1`let'3	   
	}
egen PHtotal_family_labor_days = rowtotal(hh_labordays*), missing 

* 2) Hired labor days
 
	gen PHhired_man_days = sa2q1c * sa2q1d
	replace PHhired_man_days = 0 if sa2q1c==0
	
	gen PHhired_woman_days = sa2q1f * sa2q1g
	replace PHhired_woman_days = 0 if sa2q1f==0
	
	gen PHhired_child_days = sa2q1i * sa2q1j
	replace PHhired_child_days = 0 if sa2q1i==0
	
	egen PHtotal_hired_labor_days= rowtotal(PHhired_man_days PHhired_woman_days PHhired_child_days), missing

gen PHhired_man_wage= sa2q1e
		
	gen PHhired_woman_wage= sa2q1h
		
	gen PHhired_child_wage = sa2q1k	

valuation_median_wages hhid PHhired_man_wage PHhired_woman_wage PHhired_child_wage

gen man_labor_value = man_wage * PHhired_man_days
gen woman_labor_value = woman_wage * PHhired_woman_days
gen child_labor_value = child_wage * PHhired_child_days
egen PHhired_labor_value = rowtotal (*_labor_value), missing


* 3) Other (free) labor

	gen PHother_man_days = sa2q1n_a
	
	gen PHother_woman_days = sa2q1n_b
	
	gen PHother_child_days = sa2q1n_c
	
	egen PHtotal_other_labor_days= rowtotal(PHother_man_days PHother_woman_days PHother_child_days), missing

* 4) Total labor days

egen PHtotal_labor_days = rowtotal(PHtotal_hired_labor_days PHtotal_family_labor_days PHtotal_other_labor_days), missing

* ID code of workers

local let "a b c d"
forvalues n = 1/4 {
local a: word `n' of `let'
egen ID`a' = concat(hhid sa2q1`a'1), punct("-")
gen ID_worker`n'_PH = ID`a' if  sa2q1`a'1 !=.
}


tempfile PHtotal_labor_days 
save `PHtotal_labor_days', replace 

// PH labor

// put all together
use `PHtotal_labor_days', clear
merge 1:1 plot_id  using `PPtotal_labor_days', nogen

egen total_labor_days = rowtotal(PHtotal_hired_labor_days PHtotal_family_labor_days PHtotal_other_labor_days PPtotal_hired_labor_days PPtotal_family_labor_days ), missing

egen total_hired_labor_days = rowtotal(PHtotal_hired_labor_days PPtotal_hired_labor_days ), missing

egen total_family_labor_days = rowtotal(PHtotal_family_labor_days PPtotal_family_labor_days)

egen hired_labor_value = rowtotal(PHhired_labor_value PPhired_labor_value), missing
replace hired_labor_value = 0 if total_hired_labor_days==0

keep total_labor_days plot_id total_family_labor_days total_hired_labor_days hired_labor_value ID_worker1_PH ID_worker2_PH ID_worker3_PH ID_worker4_PH ID_worker1_PP ID_worker2_PP ID_worker3_PP ID_worker4_PP
duplicates drop
save "${Temp}\\${temppath}\\labor_days.dta", replace

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11dq1a (1 =1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
replace inorganic_fertilizer=0 if s11dq1==2
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent

use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
collapse (median) conv_  , by(admin_1 unit_cd)
tempfile Conversions_fert 
save `Conversions_fert', replace

use "${Input}\\${country}\\${wave}\\${ferts}", clear

egen plot_id = concat( hhid plotid), punct("-") 
rename (zone state lga) (admin_1 admin_2 admin_3)
*UREA

//left over 
gen UREA_preconv = s11dq4a if s11dq3==2
gen  unit_cd = s11dq4b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen UREA_kg1= UREA_preconv * conv_
replace UREA_kg1 = 0 if s11dq2==2
drop conv_ UREA_preconv unit_cd

// free
gen UREA_preconv = sect11dq8a if sect11dq7==2
gen  unit_cd = sect11dq8b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen UREA_kg2= UREA_preconv * conv_
replace UREA_kg2 = 0 if sect11dq6==2
drop conv_ UREA_preconv unit_cd
 
// e wallet subsidy
gen UREA_preconv = s11dq5c1 if s11dq5b==2
gen unit_cd = s11dq5c2 
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen UREA_kg3= UREA_preconv * conv_
replace UREA_kg3 = 0 if s11dq5a==2
drop conv_ UREA_preconv unit_cd 

// commercial 1  
gen UREA_preconv = s11dq16a if s11dq15==2
gen  unit_cd = s11dq16b
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen UREA_kg4= UREA_preconv * conv_
replace UREA_kg4 = 0 if s11dq12==2
drop conv_ UREA_preconv unit_cd

// commercial 2
gen UREA_preconv = s11dq28a if s11dq27==2
gen  unit_cd = s11dq28b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen UREA_kg5= UREA_preconv * conv_
replace UREA_kg5 = 0 if s11dq24==2
drop conv_ UREA_preconv unit_cd

egen UREA_kg = rowtotal (UREA_kg*), missing
replace UREA_kg = 0 if s11dq1==2 | s11dq1a==2


** NPK

//left over 
gen NPK_preconv = s11dq4a if s11dq3==1
gen  unit_cd = s11dq4b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen NPK_kg1= NPK_preconv * conv_
replace NPK_kg1 = 0 if s11dq2==2
drop conv_ NPK_preconv unit_cd

// free
gen NPK_preconv = sect11dq8a if sect11dq7==1
gen  unit_cd = sect11dq8b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen NPK_kg2= NPK_preconv * conv_
replace NPK_kg2 = 0 if sect11dq6==2
drop conv_ NPK_preconv unit_cd
 
// e wallet subsidy
gen NPK_preconv = s11dq5c1 if s11dq5b==1
gen  unit_cd = s11dq5c2
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen NPK_kg3= NPK_preconv * conv_
replace NPK_kg3 = 0 if s11dq5a==2
drop conv_ NPK_preconv unit_cd
 
// commercial 1  
gen NPK_preconv = s11dq16a if s11dq15==1
gen  unit_cd = s11dq16b
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen NPK_kg4= NPK_preconv * conv_
replace NPK_kg4 = 0 if s11dq12==2
drop conv_ NPK_preconv unit_cd

// commercial 2
gen NPK_preconv = s11dq28a if s11dq27==1
gen  unit_cd = s11dq28b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen NPK_kg5= NPK_preconv * conv_
replace NPK_kg5 = 0 if s11dq24==2
drop conv_ NPK_preconv unit_cd

egen NPK_kg = rowtotal (NPK_kg*), missing
replace NPK_kg = 0 if s11dq1==2 | s11dq1a==2

* Other 

//left over 
gen other_preconv = s11dq4a if s11dq3==4
gen  unit_cd = s11dq4b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen other_kg1= other_preconv * conv_
replace other_kg1 = 0 if s11dq2==2
drop conv_ other_preconv unit_cd

// free
gen other_preconv = sect11dq8a if sect11dq7==4
gen  unit_cd = sect11dq8b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen other_kg2= other_preconv * conv_
replace other_kg2 = 0 if sect11dq6==2
drop conv_ other_preconv unit_cd
 
// e wallet subsidy
gen other_preconv = s11dq5c1 if s11dq5b==4
gen  unit_cd = s11dq5c2
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen other_kg3= other_preconv * conv_
replace other_kg3 = 0 if s11dq5a==2
drop conv_ other_preconv unit_cd
 
// commercial 1  
gen other_preconv = s11dq16a if s11dq15==4
gen  unit_cd = s11dq16b
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen other_kg4= other_preconv * conv_
replace other_kg4 = 0 if s11dq12==2
drop conv_ other_preconv unit_cd

// commercial 2
gen other_preconv = s11dq28a if s11dq27==4
gen  unit_cd = s11dq28b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_fert', keep(master match) nogen 
gen other_kg5= other_preconv * conv_
replace other_kg5 = 0 if s11dq24==2
drop conv_ other_preconv unit_cd

egen other_kg = rowtotal(other_kg*), missing
replace other_kg = 0 if s11dq1==2 | s11dq1a==2

* C/ Nitrogen equalivents

gen UREA_N_kg = UREA_kg*0.46
gen NPK_N_kg = NPK_kg*0.2
egen nitrogen_kg = rowtotal(UREA_N_kg NPK_N_kg), missing


collapse (sum) nitrogen_kg  UREA_kg  NPK_kg other_kg  (count) n_nitrogen_kg = nitrogen_kg n_NPK_kg = NPK_kg  n_UREA_kg = UREA_kg n_other_kg = other_kg , by(plot_id hhid)
foreach var in nitrogen_kg NPK_kg  UREA_kg  other_kg  {
replace `var' = . if n_`var'==0
}
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value 

use "${Input}\\${country}\\${wave}\\${conversions}", clear
rename (conv_NC_1 conv_NE_2 conv_NW_3 conv_SE_4 conv_SS_5 conv_SW_6) (conv_1 conv_2 conv_3 conv_4 conv_5 conv_6)
drop if inlist(unit_cd, 190, 191, 192, 3) // This drops values that are converted into liters
keep unit_cd crop_cd conv_1 conv_2 conv_3 conv_4 conv_5 conv_6
reshape long conv_, i( crop_cd unit_cd) j(admin_1) 
tempfile Conversions
save `Conversions', replace
collapse (median) conv_ , by(unit_cd admin_1)
tempfile Conversions_nocrop
save `Conversions_nocrop', replace

use "${Input}\\${country}\\${wave}\\${ferts}", clear
egen plot_id = concat( hhid plotid), punct("-") 
rename (zone state lga) (admin_1 admin_2 admin_3)

gen UREA_purchased_p1 = s11dq19 if s11dq15==2 
gen UREA_purchased_p2 = s11dq29 if s11dq27==2 
egen UREA_purchased_value = rowtotal(UREA_purchased_p* ), missing 

gen NPK_purchased_p1 = s11dq19 if s11dq15==1
gen NPK_purchased_p2 = s11dq29 if s11dq27==1 
egen NPK_purchased_value = rowtotal(NPK_purchased_p* ), missing 

gen other_purchased_p1 = s11dq19 if s11dq15==4
gen other_purchased_p2 = s11dq29 if s11dq27==4
egen other_purchased_value = rowtotal(other_purchased_p* ), missing 

** quantity 

* UREA
gen UREA_preconv = s11dq16a if s11dq15==2
gen  unit_cd = s11dq16b
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_nocrop', keep(master match) nogen 
gen UREA_purchased_kg1= UREA_preconv * conv_
drop conv_ UREA_preconv unit_cd

// commercial 2
gen UREA_preconv = s11dq28a if s11dq27==2
gen  unit_cd = s11dq28b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_nocrop', keep(master match) nogen 
gen UREA_purchased_kg2= UREA_preconv * conv_
drop conv_ UREA_preconv unit_cd

egen UREA_purchased_kg = rowtotal(UREA_purchased_kg*), missing

* NPK 
gen NPK_preconv = s11dq16a if s11dq15==1
gen  unit_cd = s11dq16b
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using  `Conversions_nocrop', keep(master match) nogen 
gen NPK_purchased_kg1= NPK_preconv * conv_
drop conv_ NPK_preconv unit_cd

// commercial 2
gen NPK_preconv = s11dq28a if s11dq27==1
gen  unit_cd = s11dq28b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_nocrop', keep(master match) nogen 
gen NPK_purchased_kg2= NPK_preconv * conv_
drop conv_ NPK_preconv unit_cd

egen NPK_purchased_kg = rowtotal(NPK_purchased_kg*), missing

* Other 
gen other_preconv = s11dq16a if s11dq15==4
gen  unit_cd = s11dq16b
count if unit_cd==. | admin_1==.  
merge m:1  unit_cd admin_1 using `Conversions_nocrop', keep(master match) nogen 
gen other_purchased_kg1= other_preconv * conv_
drop conv_ other_preconv unit_cd

// commercial 2
gen other_preconv = s11dq28a if s11dq27==4
gen  unit_cd = s11dq28b
count if unit_cd==. | admin_1==. 
merge m:1  unit_cd admin_1 using  `Conversions_nocrop', keep(master match) nogen 
gen other_purchased_kg2= other_preconv * conv_
drop conv_ other_preconv unit_cd

egen other_purchased_kg = rowtotal(other_purchased_kg*), missing

collapse (max) UREA_purchased_kg  NPK_purchased_kg other_purchased_kg  UREA_purchased_value NPK_purchased_value  other_purchased_value  , by(hhid)

valuation_median_fert_price hhid UREA

valuation_median_fert_price hhid NPK

valuation_median_fert_price hhid other


collapse (sum) UREA_value  NPK_value  other_value , by(hhid) 
merge 1:m hhid using "${Temp}\\${temppath}\\nitrogen_kg.dta", nogen

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
recode s11dq36 (1 = 1 "Yes") (2 = 0 "No"), gen(organic_fertilizer) label(organic_fertilizer)
replace organic_fertilizer= 0 if s11dq1==2
collapse (max)  organic_fertilizer, by(plot_id)
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${pesticides}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11c2q1 (1 = 1 "Yes") (2 = 0 "No") , gen(used_pesticides) label(used_pesticides)
collapse (max) used_pesticides, by(plot_id)
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q4 ( 1 4 5  = 1 "Yes") (2 3 = 0 "No") (6=.) , gen(plot_owned) 
recode s11b1q7 (1 = 1 "Yes") (2= 0 "No") (3=.), gen(plot_certificate) label(plot_certificate)
replace plot_certificate=0 if plot_owned==0 | s11b1q4==4
keep plot_id plot_owned plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// irrigated
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q39 (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace

// erosion protection 
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q49 ( 2 = 0 "No" ) (1 = 1 "Yes"), gen(erosion_protection) label(erosion_protection) 
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace

// tractor
use "${Input}\\${country}\\${wave}\\${lab_roster1}", clear
egen plot_id = concat( hhid plotid), punct("-") 
recode s11c1q11 (1=1 "Yes") (2=0 "No"), gen(tractor) label(tractor)
collapse (max) tractor , by(hhid)
save "${Temp}\\${temppath}\\tractor.dta", replace

// nb fallow
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q28 (1 = 1) (. = . ) (* = 0), gen(fallow_plot)
replace fallow_plot= 0 if s11b1q27==1
bys hhid: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover1}", 
replace nb_fallow_plots= 0 if _merge ==2		
keep hhid nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace

// nb plots
use "${Input}\\${country}\\${wave}\\${tenure}", clear
egen plot_id = concat( hhid plotid), punct("-")
recode s11b1q28 (1 = 1) (. = . ) (* = 0), gen(fallow_plot)
replace fallow_plot= 0 if s11b1q27==1
bys hhid: egen nb_plots = count(fallow_plot)
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover1}", 
replace nb_plots= 0 if _merge ==2	
keep hhid nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear

recode s2aq6 ( 1 = 1 "Yes") ( 2 = 0 "No"), gen(formal_education_hh1) label(formal_education_hh1)
recode s2aq9 (  0/15 51/61 = 0 "No" ) (16/43  = 1 "Yes"), gen(primary_education_hh1) label(primary_education_hh1)
replace primary_education_hh1 = 0 if s2aq6==2

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
recode s11q17b (1 = 1 "Yes") (2 = 0 "No"), gen(hh_electricity_access) label(hh_electricity_access)
replace hh_electricity_access=1 if s11q28b==1 & hh_electricity_access==0 
replace hh_electricity_access=1 if s11q28f==1 & hh_electricity_access==0 
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
recode s11iq1  (1 = 1 "Yes") (2 = 0 "No"), gen(livestock) label(livestock)
collapse (max) livestock, by(hhid) 
save "${Temp}\\${temppath}\\livestock.dta", replace

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption1}", clear
merge 1:1 hhid using "${Input}\\${country}\\${wave}\\${csption2}", nogen

xtile cons_quint= totcons, n(5)  
keep hhid cons_quint 
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption1}", clear
merge 1:1 hhid using "${Input}\\${country}\\${wave}\\${csption2}", nogen
keep hhid totcons 
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( hhid plotid), punct("-")
gen  manager_id = s11aq6a
replace manager_id =  s11aq6b if s11aq6a==.
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
rename s1q4 age_manager
replace age_manager=. if age_manager==999
recode s1q7 ( 1 2 = 1 "Yes") (3/7 = 0 "No"), gen(married_manager) 
keep plot_id female_manager age_manager married_manager manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear
gen manager_id =  indiv  // this is the HH member id 
merge 1:m  hhid manager_id using `ID_list', keep(match) nogen
rename manager_id id
egen manager_id = concat (hhid id ), punct("-")
recode s2aq6 ( 1 = 1 "Yes") ( 2 = 0 "No" ), gen(formal_education_manager1) label(formal_education_manager1)
recode s2aq9 (  0/15 51/61 = 0 "No" ) (16/43  = 1 "Yes"), gen(primary_education_manager1) label(primary_education_manager1)
replace primary_education_manager1 = 0 if s2aq6==2

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
replace respondent_id  = s11aq6a if s11b1q1==1
replace respondent_id =  s11aq6b if s11aq6a==.
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
rename s1q4 age_respondent
replace age_respondent=. if age_respondent==999
recode s1q7 ( 1 2 = 1 "Yes") (3/7 = 0 "No"), gen(married_respondent) 
keep hhid female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\respondent_characteristics1.dta", replace

use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear
gen respondent_id = indiv  // this is the HH member id 
merge 1:m  hhid respondent_id using `ID_list', keep(match) nogen
rename respondent_id id
egen respondent_id = concat (hhid id ), punct("-")

recode s2aq6 ( 1 = 1 "Yes") ( 2 = 0 "No"), gen(formal_education_respondent1) label(formal_education_respondent1)
recode s2aq9 (  0/15 51/61 = 0 "No" ) (16/43  = 1 "Yes"), gen(primary_education_respondent1) label(primary_education_respondent1)
replace primary_education_respondent1 = 0 if s2aq6==2

egen formal_education_respondent = rowmax(formal_education_respondent1 )
egen primary_education_respondent = rowmax( primary_education_respondent1)
keep hhid primary_education_respondent formal_education_respondent
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
replace s15aq1=0 if s15aq3a=="X" 
recode s15aq1 (1 = 1 "Yes") (2 0 = 0 "No"), gen(hh_shock) label(hh_shock)
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

drop if inlist(item_cd, 313, 314, 315, 316, 317,  3221, 3222, 3223, 3224 )
duplicates report hhid item_cd // a few duplicates 
duplicates drop hhid item_cd, force

gen hh_owns_= 0
foreach var of varlist sa4q2a sa4q2b sa4q2c sa4q2d { 
replace hh_owns_=1 if !mi(`var') & `var'!=0
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

drop if item_cd>331
recode s5q1 (0 = 0) (.=.) (else = 1), gen(hh_owns) label(hh_owns) 
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
merge m:1 hhid using "${Input}\\${country}\\${wave}\\${cover1}",
recode _merge ( 2 = 0 "No") (3 = 1 "Yes"), gen(nonfarm_enterprise) label(nonfarm_enterprise)
keep hhid nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nfe.dta", replace

// latitude 
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ( LAT_DD_MOD LON_DD_MOD) ( lat_modified lon_modified)
keep hhid lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ssa_aez09 agro_ecological_zone
keep hhid agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist_road2 dist_road
keep hhid dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename dist_popcenter2 dist_popcenter
keep hhid dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace
 
// distance to nearest market
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ea ea_id
keep hhid dist_market
duplicates drop
save "${Temp}\\${temppath}\\dist_market.dta", replace
 

// plot slope
use "${Input}\\${country}\\${wave}\\${geovars}", clear
egen plot_id = concat( hhid plotid), punct("-")
rename srtmslp_nga plot_slope
keep plot_id plot_slope
duplicates drop
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot elevation
use "${Input}\\${country}\\${wave}\\${geovars}", clear
egen plot_id = concat( hhid plotid), punct("-")
rename srtm_nga elevation 
keep plot_id elevation
duplicates drop
save "${Temp}\\${temppath}\\elevation.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars}", clear 
egen plot_id = concat( hhid plotid), punct("-")
rename twi_nga twi 
keep plot_id twi
duplicates drop
save "${Temp}\\${temppath}\\twi.dta", replace

// soil variables
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ea ea_id
forvalues i=1/7{
recode sq`i' (1=1) (2/7=0), gen(sq`i'_d)
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


// popdensity
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
keep hhid popdensity
tostring popdensity, replace 
duplicates drop
save "${Temp}\\${temppath}\\popdensity.dta", replace

// popdensity
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear 
keep hhid popdensity
tostring popdensity, replace 
duplicates drop
save "${Temp}\\${temppath}\\popdensity.dta", replace

// indiv chars 
use "${Input}\\${country}\\${wave}\\${indiv_roster0}", clear
egen ID = concat (hhid indiv), punct("-")
drop if s1q4a==2 // drop those that don't live in hh
recode  s1q2 (2=1 "Yes") (1=0 "No"), gen(female)
rename s1q4 age
recode s1q7 ( 1 2 = 1 "Yes") (3/7 = 0 "No"), gen(married) 
rename s1q3 relationship_head_temp 
decode relationship_head_temp, gen(relationship_head)
replace relationship_head = proper(relationship_head)
replace relationship_head = substr(relationship_head,strpos(relationship_head, " " ) + 1, .)
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head== "Parent In Law"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head== "Son/Daughter-In-Law"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head== "Brother/Sister Inlaw"
replace relationship_head = "Sister/Brother" if relationship_head== "Brother/Sister"
replace relationship_head = "Non Relative" if relationship_head== "Other Non-Relative"
replace relationship_head = "Non Relative" if relationship_head== "Other (Specify)"
replace relationship_head = "Other Relative" if relationship_head== "Other Relative"
replace relationship_head = "Servant" if relationship_head== "Domestic Help (Resident)"
replace relationship_head = "Servant" if relationship_head== "Domestic Help (Non Resident)"
replace relationship_head = "Grandparent" if relationship_head== "Grandfather/Mother"
replace relationship_head = "Son/Daughter" if relationship_head== "Adopted Child"
replace relationship_head = "Son/Daughter" if relationship_head== "Own Child"
replace relationship_head = "Son/Daughter" if relationship_head== "Step Child"
replace relationship_head = "Other Relative" if relationship_head== "Other Relation (Specify)"
replace relationship_head = "Non Relative" if relationship_head== "Other Non Relation (Specify)"

// month of birth
gen birth_month= ym(s1q6_year, s1q6_month)
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
gen weight=s4aq52
gen height=s4aq53 // height missing 

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

recode s3q5b (0 = 0) (.=.) (else = 1), gen( farm_work)
replace farm_work= 0 if s3q5==2
recode s3q6b (0 = 0) (.=.) (else = 1), gen( SOB_work)
replace SOB_work= 0 if s3q6==2
recode s3q4b (0 = 0) (.=.) (else = 1), gen( wage_work)
replace wage_work= 0 if s3q4==2

gen working_age = s3q1 == 1

// industry:
gen ind_ag = s3q14 == 1  // Agriculture 
gen ind_fish = . // none?
gen ind_mining = s3q14 == 2 // mining
gen ind_manuf = s3q14 >= 3 & s3q14<=5 // manuf
gen ind_const = s3q14 == 6 // construc
gen ind_serv = s3q14 >= 7 & s3q14<= 14 // services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if s3q4==2   // remove self employment, did not need to use s3q15
replace `var' = 0 if s3q7==2 // did not work
}
rename (s3q5b s3q6b s3q4b ) (farm_hrs SB_hrs wage_hrs )
replace farm_hrs= 0 if s3q5==2
replace SB_hrs= 0 if s3q6==2
replace wage_hrs= 0 if s3q4==2


foreach var in farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
replace `var' = 0 if working_age==0
}

keep ID hhid  farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education

use "${Input}\\${country}\\${wave}\\${indiv_roster1}", clear

egen ID = concat (hhid indiv), punct("-")

recode s2aq6 ( 1 = 1 "Yes") ( 2 = 0 "No"), gen(formal_education1) label(formal_education1)
recode s2aq9 (  0/15 51/61 = 0 "No" ) (16/43  = 1 "Yes"), gen(primary_education1) label(primary_education1)
replace primary_education1 = 0 if s2aq6==2

egen formal_education = rowmax(formal_education1 )
egen primary_education = rowmax( primary_education1)
keep ID hhid formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace

// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if s10bq1 ==1 // keep if consumed
rename item_cd food_id

gen A = food_id>=10 & food_id<=29
gen B = food_id>=30 & food_id<=38
gen C = food_id>=70 & food_id<=79
gen D = food_id>=60 & food_id<=66
gen E = food_id>=80 & food_id<=82 | food_id>=90 & food_id<=96
gen F = food_id>=83 & food_id<=85
gen G = food_id>=100 & food_id<=107
gen H = food_id>=40 & food_id<=48
gen I = food_id>=110 & food_id<=114
gen J = food_id>=50 & food_id<=53
gen K = food_id>=130 & food_id<=133
gen L = food_id>=120 & food_id<=122

collapse (max) A B C D E F G H I J K L, by(hhid)
egen HDDS = rowtotal(A B C D E F G H I J K L), missing 

merge 1:m hhid  using "${Input}\\${country}\\${wave}\\${HDDS}", 
collapse (max) HDDS, by(hhid)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace

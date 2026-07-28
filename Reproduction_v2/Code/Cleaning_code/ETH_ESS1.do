/*********************************************************************************
* LSMS-ISA Harmonised Panel Analysis Code                                        *
* Description: Extract data for ESS1									          *
* Date: December 2023                                                            *
* -------------------------------------------------------------------------------*
*/

**********************************************************
*** Set globals for files
**********************************************************

global country  Ethiopia
global wave  ESS 11
global cover  sect_cover_hh_w1.dta
global household_roster sect1_hh_w1.dta
global indiv_roster  sect2_hh_w1.dta
global health  sect3_hh_w1.dta
global lab_roster  sect4_hh_w1.dta
global shocks sect8_hh_w1.dta
global housing  sect9_hh_w1.dta
global assets sect10_hh_w1.dta
global nfe sect11a_hh_w1.dta
global cover_pc_pp  sect_cover_pp_w1.dta
global parcel_roster  sect2_pp_w1.dta
global plot_roster  sect3_pp_w1.dta
global planting_rwdta  sect4_pp_w1.dta
global perennial_sale sect12_ph_w1.dta
global seeds  sect5_pp_w1.dta
global misc  sect7_pp_w1.dta
global cover_pc_ph  sect_cover_ph_w1.dta
global harvest_rwdta  sect9_ph_w1.dta
global labor_ph  sect10_ph_w1.dta
global harvest_sale_rwdta  sect11_ph_w1.dta
global geovars_hh Pub_ETH_HouseholdGeovariables_Y1.dta
global geovars_plot Pub_ETH_PlotGeovariables_Y1.dta
global HDDS sect5a_hh_w1.dta

global conversions_land ET_local_area_unit_conversion.dta
global csption  cons_agg_w1.dta

global temppath ETH\ESS11

 

**********************************************************
**** A) Master frame of crops, plots, individuals and households
**********************************************************

// plot-crop frame
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear

// create strata id
gen region2 = saq01
replace region2 = 5 if inlist(region2, 2, 6, 12, 13, 15)
egen strataid = group(rural region2)

decode crop_code, generate(crop_name2) 
replace crop_name =crop_name2 if crop_name==""


keep household_id holder_id parcel_id field_id crop_name crop_code  pw 
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
rename parcel_id parcel_id2
egen parcel_id = concat(holder_id parcel_id2), punct("-") 

decode crop_code, gen(cropname2)
replace crop_name = cropname2 if crop_name==""
drop if crop_code==.

duplicates report plot_id crop_code crop_name parcel_id

save "${Temp}\\${temppath}\\plot_crop_frame.dta", replace

// household frame
use "${Input}\\${country}\\${wave}\\${cover}", clear

// create strata id
gen region2 = saq01
replace region2 = 5 if inlist(region2, 2, 6, 12, 13, 15)
egen strataid = group(rural region2)

keep household_id  pw 
duplicates report household_id 

save "${Temp}\\${temppath}\\hh_frame.dta", replace

// individual frame 
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
keep individual_id household_id 
duplicates drop 

save "${Temp}\\${temppath}\\indiv_frame.dta", replace

**********************************************************
**** B) Variable extraction
**********************************************************

// EA
use "${Input}\\${country}\\${wave}\\${cover}", clear
merge 1:m household_id using "${Input}\\Ethiopia\\ESS 13\\sect_cover_hh_w2.dta", keepusing(ea_id2) keep(match master)

bys ea_id (ea_id2): assert ea_id2 == ea_id2[_N] | ea_id2==""
bys ea_id (ea_id2): replace ea_id2 = ea_id2[_N] if ea_id2==""
drop ea_id 
rename ea_id2 ea_id

keep household_id ea_id
duplicates drop
save "${Temp}\\${temppath}\\ea_id.dta", replace

// strata
use "${Input}\\${country}\\${wave}\\${cover}", clear

gen region2 = saq01
replace region2 = 99 if inlist(region2, 2, 6, 12, 13, 15)
egen strataid = group(rural region2)
keep household_id strataid
duplicates drop
save "${Temp}\\${temppath}\\strataid.dta", replace

// admin 1
use "${Input}\\${country}\\${wave}\\${cover}", clear
rename saq01 admin_1

keep household_id admin_1
duplicates drop
save "${Temp}\\${temppath}\\admin1.dta", replace

// admin 1 name 
use "${Input}\\${country}\\${wave}\\${cover}", clear
decode saq01, gen(admin_1_name)

keep household_id admin_1_name
duplicates drop
save "${Temp}\\${temppath}\\admin_1_name.dta", replace


// admin 2
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_2 = concat(saq01 saq02), punct("-") // This creates a unique zone i

keep household_id admin_2
duplicates drop
tempfile admin2
save "${Temp}\\${temppath}\\admin2.dta", replace

// admin 3
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_3 = concat(saq01 saq02 saq03), punct("-") // This creates a unique woreda id

keep household_id admin_3
duplicates drop
tempfile admin3
save "${Temp}\\${temppath}\\admin3.dta", replace

// admin 4
use "${Input}\\${country}\\${wave}\\${cover}", clear
egen admin_4 = concat(saq01 saq02 saq03 saq04), punct("-") // This creates a unique kebele id

keep household_id admin_4
duplicates drop
tempfile admin4
save "${Temp}\\${temppath}\\admin4.dta", replace

// urban
use "${Input}\\${country}\\${wave}\\${cover}", clear
recode rural (1 =0 "No") (0=1 "Yes"), gen(urban)

keep household_id urban
duplicates drop
tempfile urban
save "${Temp}\\${temppath}\\urban.dta", replace

// weights
use "${Input}\\${country}\\${wave}\\${cover}", clear
keep pw household_id 
duplicates drop
save "${Temp}\\${temppath}\\weights.dta", replace

// planting month
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
gen year= pp_s4q12_b
recode pp_s4q12_a (1 13 = 9) (2 = 10) (3= 11) (4 = 12 ) (5 = 1) (6 = 2) (7= 3 ) (8=4) (9=5) (10 = 6) (11= 7 ) (12 = 8) (else=.), gen(month)
replace year= 2012  if pp_s4q12_b==2004 & month< 9
replace year = 2011 if pp_s4q12_b==2004 & month>= 9 & !mi(month)
replace year= 2011 if pp_s4q12_b==2003 & month< 9 
replace  year= 2010 if pp_s4q12_b==2003 & month>= 9 & !mi(month)
replace year=2010 if  pp_s4q12_b==2002 & month< 9 
replace year=. if year<2010
gen planting_month = ym(year, month)
format planting_month %tmCCYYMon
keep household_id plot_id crop_code planting_month
duplicates drop
save "${Temp}\\${temppath}\\planting_month.dta", replace

// harvest end month
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
recode ph_s9q13_b (1 13 = 9) (2 = 10) (3= 11) (4 = 12 ) (5 = 1) (6 = 2) (7= 3 ) (8=4) (9=5) (10 = 6) (11= 7 ) (12 = 8) (else=.), gen(month)
gen year = 2011 if month>=9 & !mi(month)
replace year= 2012 if month<9 
gen harvest_end_month = ym(year, month)
format harvest_end_month %tmCCYYMon
keep household_id plot_id crop_code harvest_end_month
duplicates drop
save "${Temp}\\${temppath}\\harvest_end_month.dta", replace

// harvest_interview_month 
use "${Input}\\${country}\\${wave}\\${cover_pc_ph}", clear

gen year = ph_saq14_c
recode ph_saq14_b (1 13 = 9) (2 = 10) (3= 11) (4 = 12 ) (5 = 1) (6 = 2) (7= 3 ) (8=4) (9=5) (10 = 6) (11= 7 ) (12 = 8) (else=.), gen(month)
replace year= 2012  if ph_saq14_c==2004 & month< 9
replace year = 2011 if ph_saq14_c==2004 & month>= 9 & !mi(month)
replace year= 2011 if ph_saq14_c==2003 & month< 9 
replace  year= 2010 if ph_saq14_c==2003 & month>= 9 & !mi(month)
gen harvest_interview_month = ym(year, month)
format harvest_interview_month %tmCCYYMon
drop month year



keep holder_id harvest_interview_month
duplicates drop 
save "${Temp}\\${temppath}\\harvest_interview_month.dta", replace

// planting_interview_month 
use "${Input}\\${country}\\${wave}\\${cover_pc_pp}", clear

gen year = pp_saq14_c
recode pp_saq14_b (1 13 = 9) (2 = 10) (3= 11) (4 = 12 ) (5 = 1) (6 = 2) (7= 3 ) (8=4) (9=5) (10 = 6) (11= 7 ) (12 = 8) (else=.), gen(month)
replace year= 2012  if pp_saq14_c==2004 & month< 9
replace year = 2011 if pp_saq14_c==2004 & month>= 9 & !mi(month)
replace year= 2011 if pp_saq14_c==2003 & month< 9 
replace  year= 2010 if pp_saq14_c==2003 & month>= 9 & !mi(month)
gen planting_interview_month = ym(year, month)
format planting_interview_month %tmCCYYMon	replace planting_interview_month=. if planting_interview_month< ym(2011,9)
keep holder_id planting_interview_month
duplicates drop 
save "${Temp}\\${temppath}\\planting_interview_month.dta", replace

// harvest_kg 
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
drop ea_id
merge m:1 household_id using "${Temp}\\${temppath}\\admin1.dta", keep(master match) nogen
merge m:1 household_id using "${Temp}\\${temppath}\\admin2.dta", keep(master match) nogen
merge m:1 household_id using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen

merge m:1 household_id using  "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
recode ph_s9q07 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock) label(crop_shock)
replace crop_shock = 1 if ph_s9q09==1

gen harvest_gram = ph_s9q12_b * 0.001
egen harvest_kg= rowtotal (ph_s9q12_a harvest_gram), missing

replace harvest_kg = . if harvest_kg==0 & crop_shock!=1
keep household_id plot_id crop_code harvest_kg holder_id ea_id admin_1 admin_2 admin_3 
save "${Temp}\\${temppath}\\harvest_kg.dta", replace


// crop shock
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode ph_s9q07 (1 = 1 "Yes") (2 = 0 "No"), gen(crop_shock) label(crop_shock)
replace crop_shock = 1 if ph_s9q09==1

recode ph_s9q08_a (1 = 1 "Yes") (2/6 8/999 = 0 "No"), gen(drought_shock1) label(drought_shock) 
recode ph_s9q08_b (1 = 1 "Yes") (2/6 8/999 = 0 "No"), gen(drought_shock2) 
recode ph_s9q10 (2 = 1 "Yes") (1 3/100 = 0 "No"), gen(drought_shock3) 
replace drought_shock1 = 0 if ph_s9q07==2
replace drought_shock2 = 0 if ph_s9q07==2
replace drought_shock3 = 0 if ph_s9q09==2
gen drought_shock= 1 if drought_shock1==1 | drought_shock2==1 | drought_shock3==1 
replace drought_shock=0 if (drought_shock1==0 & drought_shock2==0 & drought_shock3==0)
replace drought_shock=0 if (drought_shock1==0  & drought_shock2==. & drought_shock3==0) // second option not always used

recode ph_s9q08_a (2 = 1 "Yes") (1 3/6 8/999 = 0 "No"), gen(rain_shock1) label(rain_shock) 
recode ph_s9q08_b (2 = 1 "Yes") (1  3/6 8/999  = 0 "No"), gen(rain_shock2) 
recode ph_s9q10 (1 = 1 "Yes") (2/100 = 0 "No"), gen(rain_shock3) 
replace rain_shock1 = 0 if ph_s9q07==2
replace rain_shock2 = 0 if ph_s9q07==2
replace rain_shock3 = 0 if ph_s9q09==2
gen rain_shock= 1 if rain_shock1==1 | rain_shock2==1 | rain_shock3==1 
replace rain_shock=0 if (rain_shock1==0 & rain_shock2==0 & rain_shock3==0)
replace rain_shock=0 if (rain_shock1==0 & rain_shock2==. & rain_shock3==0)  // second option not always used

recode ph_s9q08_a (4 = 1 "Yes") (1/3 5/6 8/999 = 0 "No"), gen(pests_shock1) label(pests_shock) 
recode ph_s9q08_b (4 = 1 "Yes") (1/3 5/6 8/999 = 0 "No"), gen(pests_shock2) 
recode ph_s9q10 (3 10 = 1 "Yes") (1 2 4/9 11/100 = 0 "No"), gen(pests_shock3) 
replace pests_shock1 = 0 if ph_s9q07==2
replace pests_shock2 = 0 if ph_s9q07==2
replace pests_shock3 = 0 if ph_s9q09==2
gen pests_shock= 1 if pests_shock1==1 | pests_shock2==1 | pests_shock3==1
replace pests_shock=0 if (pests_shock1==0 & pests_shock2==0 & pests_shock3==0)
replace pests_shock=0 if (pests_shock1==0 & pests_shock2==. & pests_shock3==0)  // second option not always used

recode ph_s9q10 (7 = 1 "Yes") (1/6 8/999 = 0 "No"), gen(flood_shock) label(flood_shock) 	
replace flood_shock = 0 if ph_s9q09==2

keep household_id plot_id crop_shock pests_shock rain_shock drought_shock flood_shock crop_code 
duplicates drop
save "${Temp}\\${temppath}\\crop_shock.dta", replace

// harvest sold amount
use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
merge 1:m household_id ph_saq07 crop_code using "${Input}\\${country}\\${wave}\\${perennial_sale}", 
drop if crop_code==.

gen harvest_sold_kg_gram= ph_s11q03_b *0.001
replace harvest_sold_kg_gram=0 if ph_s11q01==2 
replace ph_s11q03_a=0 if ph_s11q01==2 
gen harvest_sold_kg_per = ph_s12q07 
replace harvest_sold_kg_per=0 if ph_s12q06==2
egen harvest_sold_kg = rowtotal (harvest_sold_kg_gram ph_s11q03_a harvest_sold_kg_per), missing
keep household_id   harvest_sold_kg crop_code holder_id
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg.dta", replace
collapse (sum) harvest_sold_kg  (count) n_harvest_sold_kg=harvest_sold_kg , by(household_id)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
merge 1:m household_id using "${Temp}\\${temppath}\\harvest_kg.dta", keep(match using)
collapse (sum) harvest_sold_kg harvest_kg (count) n_harvest_sold_kg=harvest_sold_kg n_harvest_kg = harvest_kg, by(household_id _merge)
replace harvest_sold_kg = . if n_harvest_sold_kg==0
replace harvest_kg = . if n_harvest_kg==0
gen share_kg_sold = harvest_sold_kg/harvest_kg
replace share_kg_sold = . if share_kg_sold>1
replace share_kg_sold = 0 if harvest_kg==0
replace share_kg_sold = 0 if _merge==2
keep household_id share_kg_sold
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_kg_hh.dta", replace



// harvest sold value
use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
merge 1:m household_id ph_saq07 crop_code using "${Input}\\${country}\\${wave}\\${perennial_sale}", 
gen harvest_sold_value_dec = ph_s11q04_b * 0.01
egen harvest_sold_value = rowtotal(ph_s11q04_a harvest_sold_value_dec ph_s12q08), missing	
replace harvest_sold_value=0 if ph_s11q01==2 & _merge==1
replace harvest_sold_value=0 if ph_s12q06==2 & _merge==2
keep household_id harvest_sold_value crop_code holder_id
duplicates drop
save "${Temp}\\${temppath}\\harvest_sold_value.dta", replace

// harvest_value & main crop
use "${Input}\\${country}\\${wave}\\${harvest_sale_rwdta}", clear
merge 1:m household_id ph_saq07 crop_code using "${Input}\\${country}\\${wave}\\${perennial_sale}", nogen
drop ea_id


merge 1:m household_id holder_id crop_code using "${Temp}\\${temppath}\\harvest_kg.dta", 
keep admin_1 admin_2 admin_3 household_id holder_id crop_code 
duplicates drop

valuation_median_crops_noea household_id holder_id crop_code

main_crop_def crop_code


keep household_id plot_id  harvest_value crop_code main_crop
save "${Temp}\\${temppath}\\harvest_value.dta", replace


// intercropped
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode pp_s3q03 (1 = 0 "No") (2 = 1 "Yes") (else = .) , gen(intercropped) label(intercropped)
keep household_id plot_id intercropped
duplicates drop
save "${Temp}\\${temppath}\\intercropped.dta", replace

// nb_seasonal_crop
use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
bys  plot_id : egen nb_seasonal_crop = count(crop_code)
keep plot_id nb_seasonal_crop
duplicates drop
save "${Temp}\\${temppath}\\nb_seasonal_crop.dta", replace


	// main crop
	use "${Input}\\${country}\\${wave}\\${harvest_rwdta}", clear
	egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
	merge 1:1 plot_id crop_code using "${Temp}\\${temppath}\\harvest_value.dta",  nogen


	bys plot_id: egen total_value_plot= total(harvest_value), missing
	gen maincrop_valueshare_temp = harvest_value/ total_value_plot if crop_code==main_crop
	bys plot_id: egen maincrop_valueshare = max(maincrop_valueshare_temp)


gen codesmain_crop = main_crop
gen codescrop_code = crop_code
	foreach c in main_crop crop_code {
	lab val `c' crop_code
	rename `c' `c'2
	decode `c'2, gen(`c')
	drop `c'2
	replace `c' = strupper(`c')
	gen `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"FIELD PEAS", "HARICOT BEANS", "RED KIDENY BEANS", "CHICK PEAS", "GROUND NUTS", "LENTILS", "VETCH", "SOYA BEANS", "MUNG BEAN/ MASHO")
	replace `c'2 = "BEANS AND OTHER LEGUMES" if inlist(`c',"HORSE BEANS")
	replace `c'2 = "TUBERS / ROOT CROPS" if inlist(`c',"GODERE", "SWEET POTATO", "POTATOES", "OTHER ROOT C", "CASSAVA", "CARROT", "BEER ROOT")
	replace `c'2 = "RICE" if `c'=="PADDY RICE" | `c'=="RICE"
	replace `c'2 = "WHEAT" if `c'=="WHEAT"
	replace `c'2 = "MAIZE" if `c'=="MAIZE"
	replace `c'2 = "BARLEY" if `c'=="BARLEY"
	replace `c'2 = "SORGHUM" if `c'=="SORGHUM"
	replace `c'2 = "MILLET" if `c'=="MILLET"
	tab `c' if `c'2==""
	replace `c'2 = "OTHER" if `c'2==""
	replace `c'2 = "PERENNIAL/FRUIT" if inlist(codes`c', 19, 20, 22, 34, 35, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 55, 65, 66, 71, 72, 74, 75, 76, 81, 82, 84, 85, 86, 98, 99, 108, 111, 112, 113, 114, 115, 116, 117, 122)
	drop `c'
	rename `c'2 `c'
	}
	tab crop_code , gen(contains_crop_)


	foreach n in 10 9 8 7 6 5 {
	local i = `n' + 1
	rename contains_crop_`n' contains_crop_`i'
	}

	gen contains_crop_5 =0


	//share of each crop category
	forvalues n = 1/11 {
	gen share_crop`n' = harvest_value/ total_value_plot if contains_crop_`n'==1
	replace share_crop`n' = 0 if contains_crop_`n'==0
	}

	collapse (sum)   share_crop* (max) contains_crop_*, by(plot_id main_crop maincrop_valueshare ) 
	save "${Temp}\\${temppath}\\main_crop.dta", replace

// share of plot area planted by crop 
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

gen pct_area_planted = pp_s4q03 
replace pct_area_planted = 100 if pp_s4q02==1 

keep pct_area_planted plot_id crop_code
duplicates drop
save "${Temp}\\${temppath}\\pct_area_planted.dta", replace


// land area
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

rename saq01 region
rename saq02 zone 
rename saq03 woreda 
rename pp_s3q02_c local_unit
merge m:1 region zone woreda local_unit using "${Input}\\${country}\\${wave}\\${conversions_land}", keep(master match) nogen

gen  area_GPS = pp_s3q05_a *0.0001
gen  area_rope_compass = pp_s3q08_b * 0.0001

gen area_self_reported = pp_s3q02_a 
replace area_self_reported= area_self_reported * conversion
replace area_self_reported = pp_s3q02_a if local_unit==2 // This corresponds to values that are in m²
replace area_self_reported= area_self_reported * 0.0001 // This converts everything in hectares
replace area_self_reported = pp_s3q02_a if local_unit==1 // These values are already in hectares

isid household_id plot_id
sort household_id plot_id

gen plot_area_GPS=.
replace plot_area_GPS = area_GPS if area_GPS>0
merge m:1 household_id using "${Temp}\\${temppath}\\admin3.dta", keep(master match) nogen
encode admin_3, gen(admin_3_num)

isid household_id plot_id
sort household_id plot_id

mi set wide 					//	declare the data to be wide. 
mi register imputed plot_area_GPS	//	identify plotsize as the variable being imputed 
mi impute pmm plot_area_GPS area_self_reported i.admin_3_num, add(1) rseed(12345) noisily dots /*
*/	force knn(5) bootstrap 
mi unset
replace plot_area_GPS = plot_area_GPS_1_ if mi(plot_area_GPS)

bys household_id: egen farm_size = total(plot_area_GPS), missing

keep household_id plot_id  plot_area_GPS farm_size plot_area_GPS_1_
duplicates drop
save "${Temp}\\${temppath}\\plot_area.dta", replace

// improved
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
recode pp_s4q11 (1 3 =0 "No") (2=1 "Yes"), gen(improved)
keep household_id plot_id  crop_code improved
duplicates drop
save "${Temp}\\${temppath}\\improved.dta", replace

// seed kg
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
gen seed_gram = pp_s5q19_b *0.001
egen seed_kg = rowtotal (pp_s5q19_a seed_gram), missing
merge 1:m plot_id crop_code using "${Temp}\\${temppath}\\improved.dta", keepusing(improved) keep(master match) nogen
drop ea_id
merge m:1 household_id using  "${Temp}\\${temppath}\\ea_id.dta", keep(master match) nogen
keep household_id plot_id crop_code  seed_kg improved  ea_id
duplicates drop
save "${Temp}\\${temppath}\\seed_kg.dta", replace
collapse (sum) seed_kg (count) n_seed_kg = seed_kg , by(plot_id crop_code)
replace seed_kg = . if n_seed_kg==0
save "${Temp}\\${temppath}\\seed_kg_merge.dta", replace

// seed_kg_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
gen seeds_amount_purchased_gram = pp_s5q05_b *0.001 
egen seeds_amount_purchased_kg = rowtotal ( pp_s5q05_a seeds_amount_purchased_gram), missing
replace seeds_amount_purchased_kg=0 if pp_s5q03==2 // this variable asks whether any was purchased.
merge 1:m plot_id crop_code using "${Temp}\\${temppath}\\improved.dta", keepusing(improved) keep(master match) nogen
keep household_id plot_id crop_code  seeds_amount_purchased_kg improved
duplicates drop
save "${Temp}\\${temppath}\\seeds_amount_purchased_kg.dta", replace

// seed_value_sold
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
merge 1:m plot_id crop_code using "${Temp}\\${temppath}\\improved.dta", keepusing(improved) keep(master match) nogen
gen seed_value_temp = pp_s5q08
keep household_id plot_id crop_code  seed_value_temp improved
duplicates drop
save "${Temp}\\${temppath}\\seed_value_temp.dta", replace

// seed value 
use "${Input}\\${country}\\${wave}\\${seeds}", clear
egen plot_id = concat(holder_id  parcel_id field_id), punct("-")
merge 1:m plot_id crop_code using "${Temp}\\${temppath}\\improved.dta", keepusing(improved) keep(master match) nogen
drop ea_id
merge m:1 household_id  using "${Temp}\\${temppath}\\ea_id.dta", keep(master match)	nogen

forvalues n =1/4 {
merge m:1 household_id using "${Temp}\\${temppath}\\admin`n'.dta", keep(master match)	nogen
}

valuation_median_seeds household_id plot_id crop_code

keep household_id plot_id crop_code seed_value
duplicates drop
save "${Temp}\\${temppath}\\seed_value.dta", replace

// labor days 

// HIRED PP
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
drop if !inlist(pp_s3q03, 1, 2) 

gen hired_number_man = pp_s3q28_a 
gen hired_man_days_av=pp_s3q28_b // Total number of days per man 
replace hired_man_days_av=0 if hired_number_man==0
gen PPhired_man_days= hired_man_days_av * hired_number_man // = Variable of interest
	
gen hired_number_woman= pp_s3q28_d
gen hired_woman_days_av=pp_s3q28_e
replace hired_woman_days_av=0 if hired_number_woman==0
gen PPhired_woman_days= hired_woman_days_av * hired_number_woman  // = Variable of interest
	
gen hired_number_children = pp_s3q28_g
gen hired_child_days_av=pp_s3q28_h
replace hired_child_days_av=0 if hired_number_children==0
gen PPhired_child_days= hired_child_days_av * hired_number_child // = Variable of interest
	
egen PPtotal_hired_labor_days = rowtotal(PPhired_child_days PPhired_woman_days PPhired_man_days), missing

	// calculate value
		gen PPhired_man_wage= pp_s3q28_c
		replace PPhired_man_wage =. if hired_number_man==0  // This is to ensure that these observations are not counted when computing median wages
			
		gen PPhired_woman_wage= pp_s3q28_f
		replace PPhired_woman_wage =. if hired_number_woman==0
			
		gen PPhired_child_wage = pp_s3q28_i
		replace PPhired_child_wage =. if hired_number_child==0
		
		valuation_median_wages household_id PPhired_man_wage PPhired_woman_wage PPhired_child_wage
		
		gen PPman_labor_value_hired = man_wage * PPhired_man_days
		gen PPwoman_labor_value_hired = woman_wage * PPhired_woman_days
		gen PPchild_labor_value_hired = child_wage * PPhired_child_days
		egen PPtotal_hired_labor_value = rowtotal( PPman_labor_value_hired PPwoman_labor_value_hired PPchild_labor_value_hired), missing
		
		rename (man_wage woman_wage child_wage ) (PPman_wage PPwoman_wage PPchild_wage )
		
		
 
keep plot_id PPtotal_hired_labor_days PPman_wage PPwoman_wage PPchild_wage PPtotal_hired_labor_value
duplicates drop
tempfile PPtotal_hired_labor_days
save `PPtotal_hired_labor_days', replace

// FAMILY PP 
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
drop if !inlist(pp_s3q03, 1, 2) 

local alet "b f j n r v"
local blet "c g k o s w"
local clet "a e i m q u"
local dlet "d h l p t x"
forvalues n = 1/6 { 
	local a: word `n' of `alet'
	local b: word `n' of `blet'
	local c: word `n' of `clet'
	local d: word `n' of `dlet'
	gen number_weeks`n'= pp_s3q27_`a'
	gen days_per_week`n'=pp_s3q27_`b'
	replace number_weeks`n'=0 if pp_s3q27_`c'==0
	replace days_per_week`n'=0 if pp_s3q27_`c'==0					
	gen family_labor_days`n' = number_weeks`n' * days_per_week`n'	
	gen hr_`n' = pp_s3q27_`d'
	}

egen PPtotal_family_labor_days = rowtotal(family_labor_days*), missing // we aggregate total family days
egen PPmean_family_hour_day = rowmean(hr_*) // we aggregate total family days

keep plot_id PPtotal_family_labor_days PPmean_family_hour_day 
duplicates drop

tempfile PPtotal_family_labor_days
save `PPtotal_family_labor_days', replace

// OTHER PP
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
drop if !inlist(pp_s3q03, 1, 2) 

rename pp_s3q29_a other_number_men
gen other_man_days_av=pp_s3q29_b
replace other_man_days_av=0 if other_number_men==0 
gen PPother_man_days= other_man_days_av * other_number_men
	
rename pp_s3q29_c other_number_women
gen other_woman_days_av=pp_s3q29_d
replace other_woman_days_av=0 if other_number_women==0 
gen PPother_woman_days= other_woman_days_av * other_number_women
	
rename pp_s3q29_e other_number_children
gen other_child_days_av=pp_s3q29_f
replace other_child_days_av=0 if other_number_children==0 
gen PPother_child_days= other_child_days_av * other_number_children
	
egen PPtotal_other_labor_days= rowtotal(PPother_man_days PPother_woman_days PPother_child_days), missing

keep plot_id PPtotal_other_labor_days
duplicates drop

tempfile PPtotal_other_labor_days
save `PPtotal_other_labor_days', replace

// HIRED PH
use "${Input}\\${country}\\${wave}\\${labor_ph}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

gen hired_number_man = ph_s10q01_a
gen hired_man_days_av=ph_s10q01_b // Total number of days per man 
replace hired_man_days_av=0 if hired_number_man==0
gen PHhired_man_days1= hired_man_days_av * hired_number_man // = Variable of interest
	
gen hired_number_woman= ph_s10q01_d
gen hired_woman_days_av=ph_s10q01_e 
replace hired_woman_days_av=0 if hired_number_woman==0
gen PHhired_woman_days1= hired_woman_days_av * hired_number_woman  // = Variable of interest
	
gen hired_number_children = ph_s10q01_g
gen hired_child_days_av =ph_s10q01_h
replace hired_child_days_av=0 if hired_number_children==0
gen PHhired_child_days1= hired_child_days_av * hired_number_child // = Variable of interest
	
egen PHtotal_hired_labor_days_crop = rowtotal(PHhired_child_days1 PHhired_woman_days1 PHhired_man_days1), missing

		// calculate value
		gen PHhired_man_wage1= ph_s10q01_c
		replace PHhired_man_wage1 =. if hired_number_man==0 // This is to ensure that these observations are not counted when computing median wages
		
		gen PHhired_woman_wage1= ph_s10q01_f
		replace PHhired_woman_wage1 =. if hired_number_woman==0
		
		gen PHhired_child_wage1 = ph_s10q01_i
		replace PHhired_child_wage1 =. if hired_number_child==0
		
		valuation_median_wages household_id PHhired_man_wage1 PHhired_woman_wage1 PHhired_child_wage1
		
		gen PHman_labor_value_hired = man_wage * PHhired_man_days
		gen PHwoman_labor_value_hired = woman_wage * PHhired_woman_days
		gen PHchild_labor_value_hired = child_wage * PHhired_child_days
		egen PHtotal_hired_labor_value_crop = rowtotal( PHman_labor_value_hired PHwoman_labor_value_hired PHchild_labor_value_hired), missing
		
		rename (man_wage woman_wage child_wage ) (PHman_wage PHwoman_wage PHchild_wage )
		
		

keep plot_id PHtotal_hired_labor_days_crop PHtotal_hired_labor_value_crop crop_code PHman_wage PHwoman_wage PHchild_wage
duplicates drop

tempfile PHtotal_hired_labor_days_crop
save `PHtotal_hired_labor_days_crop', replace


// FAMILY PH
use "${Input}\\${country}\\${wave}\\${labor_ph}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

local alet "b f j n r v z na"
local blet "c g k o s w ka oa"
local clet "a e i m q u y ma"
local dlet "d h l p t x la pa"
forvalues n = 1/8 { 
		local a: word `n' of `alet'
		local b: word `n' of `blet'
		local c: word `n' of `clet'
		local d: word `n' of `dlet'
		gen number_weeks`n'= ph_s10q02_`a'
		gen days_per_week`n'=ph_s10q02_`b'
		replace number_weeks`n'=0 if ph_s10q02_`c'==0
		replace days_per_week`n'=0 if ph_s10q02_`c'==0
		
		gen family_labor_days`n'_crop = number_weeks`n' * days_per_week`n'
		
		gen hr_`n'_crop = ph_s10q02_`d'
		

	}

egen PHtotal_family_labor_days_crop = rowtotal(family_labor_days*_crop), missing
egen PHmean_family_hour_day_crop = rowmean(hr_*_crop)

keep plot_id PHtotal_family_labor_days_crop crop_code PHmean_family_hour_day_crop
duplicates drop

tempfile PHtotal_family_labor_days_crop
save `PHtotal_family_labor_days_crop', replace


// OTHER PH
use "${Input}\\${country}\\${wave}\\${labor_ph}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

rename ph_s10q03_a other_number_men
gen other_man_days_av=ph_s10q03_b
replace other_man_days_av=0 if other_number_men==0 
gen PHother_man_days1= other_man_days_av * other_number_men
	
rename ph_s10q03_c other_number_women
gen other_woman_days_av=ph_s10q03_d
replace other_woman_days_av=0 if other_number_women==0 
gen PHother_woman_days1= other_woman_days_av * other_number_women
	
rename ph_s10q03_e other_number_children
gen other_child_days_av=ph_s10q03_f
replace other_child_days_av=0 if other_number_children==0 
gen PHother_child_days1= other_child_days_av * other_number_children
	
egen PHtotal_other_labor_days_crop= rowtotal(PHother_man_days1 PHother_woman_days1 PHother_child_days1), missing

keep plot_id PHtotal_other_labor_days_crop crop_code
duplicates drop

tempfile PHtotal_other_labor_days_crop
save `PHtotal_other_labor_days_crop', replace

// put all together
use `PHtotal_hired_labor_days_crop', clear
merge 1:1 plot_id crop_code using `PHtotal_family_labor_days_crop', nogen
merge 1:1 plot_id crop_code using `PHtotal_other_labor_days_crop', nogen

foreach var of varlist PHtotal_hired_labor_days_crop PHtotal_family_labor_days_crop PHtotal_other_labor_days_crop PHtotal_hired_labor_value_crop PHmean_family_hour_day_crop { 
bys plot_id: egen `var'_p = total(`var'), missing
} 
	
merge m:1 plot_id using  `PPtotal_hired_labor_days', nogen
merge m:1 plot_id  using `PPtotal_family_labor_days', nogen
merge m:1 plot_id using `PPtotal_other_labor_days', nogen

egen total_labor_days = rowtotal(PHtotal_hired_labor_days_crop_p PHtotal_family_labor_days_crop_p PHtotal_other_labor_days_crop_p  PPtotal_other_labor_days PPtotal_family_labor_days PPtotal_hired_labor_days), missing

egen total_hired_labor_days = rowtotal(PHtotal_hired_labor_days_crop_p PPtotal_hired_labor_days), missing

egen total_family_labor_days = rowtotal(PHtotal_family_labor_days_crop_p PPtotal_family_labor_days)

egen hired_labor_value = rowtotal(PHtotal_hired_labor_value_crop_p PPtotal_hired_labor_value), missing
replace hired_labor_value = 0 if total_hired_labor_days==0

keep total_labor_days plot_id total_family_labor_days total_hired_labor_days hired_labor_value 
duplicates drop

save "${Temp}\\${temppath}\\labor_days.dta", replace

// ID of worker on plot
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
use "${Input}\\${country}\\${wave}\\${labor_ph}", clear

// inorganic fertilizer
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode pp_s3q14 ( 1 = 1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)
keep plot_id inorganic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer.dta", replace

// nitrogen equivalent
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.


recode pp_s3q14 ( 1 = 1 "Yes") (2 = 0 "No"), gen(inorganic_fertilizer) label(inorganic_fertilizer)

recode pp_s3q15 (1 = 1 "Yes") (2 = 0 "No"), gen(used_UREA) label(used_UREA)
gen UREA_kg = pp_s3q16_c
replace UREA_kg=0 if used_UREA==0
replace UREA_kg=0 if inorganic_fertilizer==0
	
recode pp_s3q18 (1 = 1 "Yes") (2 = 0 "No"), gen(used_DAP) label(used_DAP)
gen DAP_kg = pp_s3q19_c
replace DAP_kg=0 if inorganic_fertilizer==0
replace DAP_kg=0 if used_DAP==0

gen UREA_N_kg = UREA_kg*0.46
gen DAP_N_kg = DAP_kg*0.18 
egen nitrogen_kg = rowtotal(UREA_N_kg DAP_N_kg ), missing
keep plot_id nitrogen_kg
duplicates drop
save "${Temp}\\${temppath}\\nitrogen_kg.dta", replace

// inorganic fertilizer value (= actual bought fertilizer)
use "${Input}\\${country}\\${wave}\\${misc}", clear
merge 1:m holder_id using "${Input}\\${country}\\${wave}\\${plot_roster}", keep(match using) nogen 
egen plot_id = concat( holder_id parcel_id field_id), punct("-")

bys holder_id: egen plot_count= count(plot_id)
gen UREA_purchased = pp_s7q15/plot_count
gen DAP_purchased = pp_s7q14/plot_count
egen inorganic_fertilizer_value= rowtotal(UREA_purchased DAP_purchased), missing
keep plot_id inorganic_fertilizer_value
duplicates drop
save "${Temp}\\${temppath}\\inorganic_fertilizer_value.dta", replace


// organic fert
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode pp_s3q21 (1 = 1 "Yes") ( 2 = 0 "No"), gen(manure) label(manure)
recode pp_s3q23 ( 1 = 1 "Yes") (2 = 0 "No"), gen(compost) label(compost)	
recode pp_s3q25 (1 = 1 "Yes") (2 = 0 "No"), gen(other_organic) label(other_organic)
	
gen organic_fertilizer= 1 if (manure==1 | compost==1 | other_organic==1)
replace organic_fertilizer=0 if manure==0 & compost==0 & other_organic==0   // This dummy is equal to 0 for plots for which we are certain that there are no used fertilizer. 
replace organic_fertilizer = 0 if pp_s3q14==2
keep plot_id organic_fertilizer
duplicates drop
save "${Temp}\\${temppath}\\organic_fertilizer.dta", replace

// pesticides
use "${Input}\\${country}\\${wave}\\${planting_rwdta}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
recode pp_s4q05 (1 = 1 "Yes") (2 = 0 "No"), gen(used_pesticides) label(used_pesticides)
replace used_pesticides=0 if pp_s4q04==2  
keep plot_id crop_code used_pesticides
duplicates drop
save "${Temp}\\${temppath}\\used_pesticides.dta", replace

// plot owned
use "${Input}\\${country}\\${wave}\\${parcel_roster}", clear
recode pp_s2q03 ( 1 2 = 1 "Yes") (3/12 = 0 "No") , gen(plot_owned) label(plot_owned) 
keep plot_owned holder_id parcel_id 
duplicates drop
save "${Temp}\\${temppath}\\plot_owned.dta", replace

// plot ceertificate
use "${Input}\\${country}\\${wave}\\${parcel_roster}", clear
recode pp_s2q04 (1 = 1 "Yes") (2= 0 "No"), gen(plot_certificate) label(plot_certificate)
replace plot_certificate = 0 if inlist(pp_s2q03, 3,4,6)
keep holder_id parcel_id plot_certificate
duplicates drop
save "${Temp}\\${temppath}\\plot_certificate.dta", replace	

// irrigated
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode pp_s3q12 (1 = 1 "Yes") (2 = 0 "No"), gen(irrigated) label(irrigated)
keep plot_id irrigated
duplicates drop
save "${Temp}\\${temppath}\\irrigated.dta", replace	


// erosion protection
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

recode pp_s3q32 ( 2 = 1 "Yes") (1  = 0 "No"), gen(erosion_protection) label(erosion_protection)
keep plot_id erosion_protection
duplicates drop
save "${Temp}\\${temppath}\\erosion_protection.dta", replace	

// nb fallow
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
recode pp_s3q03 (3 = 1) (. = . ) (* = 0), gen(fallow_plot)
bys household_id: egen nb_fallow_plots = total(fallow_plot), missing
merge m:1 household_id using "${Input}\\${country}\\${wave}\\${cover}", keepusing(household_id)
replace nb_fallow_plots= 0 if _merge ==2
keep household_id nb_fallow_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_fallow_plots.dta", replace	


// nb plots
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat( holder_id parcel_id field_id), punct("-") // This creates a unique plot id.
bys household_id: egen nb_plots = count(pp_s3q03)
merge m:1 household_id using "${Input}\\${country}\\${wave}\\${cover}", keepusing(household_id)
replace nb_plots= 0 if _merge ==2
keep household_id nb_plots
duplicates drop
save "${Temp}\\${temppath}\\nb_plots.dta", replace	

// education hh
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recode hh_s2q03 ( 1 = 1 "Yes") (2 = 0 "No"), gen(hh_formal_education_temp) label(hh_formal_education)
recode hh_s2q05 (0 98 1/3 93/96 4/7 = 0 "No" ) (8/35 = 1 "Yes"), gen(hh_primary_education_temp) label(hh_primary_education)
replace hh_primary_education_temp = 0 if hh_s2q03==2 // These individuals have never attended school
bys household_id: egen hh_formal_education= max(hh_formal_education_temp) 
bys household_id: egen hh_primary_education= max(hh_primary_education_temp) 
collapse (max) hh_formal_education hh_primary_education, by(household_id)	
keep household_id hh_formal_education hh_primary_education
duplicates drop
save "${Temp}\\${temppath}\\hh_primary_education.dta", replace	


// electricity access
use "${Input}\\${country}\\${wave}\\${housing}", clear
recode hh_s9q19 (1/4 = 1 "Yes") (5/13 = 0 "No"), gen(hh_electricity_access)
keep household_id hh_electricity_access
duplicates drop
save "${Temp}\\${temppath}\\hh_electricity_access.dta", replace	

// dependency ratio
use "${Input}\\${country}\\${wave}\\${household_roster}", clear
rename hh_s1q04_a age
gen dep_temp= !inrange(age,15,65) & !mi(age) // dummy for dependents
gen nondep_temp= inrange(age,15,65) & !mi(age) // dummy for non-dependents
bysort household_id: egen dep=total(dep_temp)
bysort household_id: egen nondep=total(nondep_temp)
gen hh_dependency_ratio = (dep/nondep) 
replace hh_dependency_ratio = dep  if nondep==0
collapse (max) hh_dependency_ratio, by(household_id)
keep household_id hh_dependency_ratio
duplicates drop
save "${Temp}\\${temppath}\\hh_dependency_ratio.dta", replace	

// livestock
use "${Input}\\${country}\\${wave}\\${cover_pc_pp}", clear
recode pp_saq13 (2 3 =1 "Yes") (1 = 0 "No") , gen(livestock) label(livestock)
keep holder_id livestock
duplicates drop
save "${Temp}\\${temppath}\\livestock.dta", replace	

// consumption quint
use "${Input}\\${country}\\${wave}\\${csption}", clear
keep household_id cons_quint
duplicates drop
save "${Temp}\\${temppath}\\cons_quint.dta", replace	

// consumption aggregate (unprcoessed)
use "${Input}\\${country}\\${wave}\\${csption}", clear
rename nom_totcons_aeq totcons
keep household_id totcons
duplicates drop
save "${Temp}\\${temppath}\\totcons.dta", replace	

// manager chars
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-")
rename pp_saq07 manager_id // The plot manager here is the holder
sort  household_id (manager_id)
collapse (first) manager_id household_id , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${household_roster}", clear
gen manager_id = hh_s1q00 // this is the HH member id 
merge 1:m  household_id manager_id using `ID_list', keep(match) nogen
gen hh_s2q00 = manager_id
merge m:1  household_id hh_s2q00 using "${Input}\\${country}\\${wave}\\${indiv_roster}", keep(match) keepusing(individual_id) nogen
rename manager_id manager_id_temp
gen manager_id = individual_id
recode  hh_s1q03 (2=1 "Yes") (1=0 "No"), gen(female_manager) 
rename hh_s1q04_a age_manager
recode hh_s1q08 (2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married_manager) 
keep household_id female_manager age_manager married_manager plot_id manager_id
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename hh_s2q00 manager_id
merge 1:m  household_id manager_id using `ID_list', keep(match) nogen
recode hh_s2q03 ( 1 = 1 "Yes") (2 = 0 "No"), gen(formal_education_manager) label(formal_education_manager)
recode hh_s2q05 (0 98 1/3 93/96 4/7 = 0 "No" ) (8/35 = 1 "Yes"), gen(primary_education_manager) label(primary_education_manager)
replace primary_education_manager = 0 if hh_s2q03==2 // These individuals have never attended school

keep plot_id primary_education_manager formal_education_manager
duplicates drop
save "${Temp}\\${temppath}\\Manager_characteristics2.dta", replace	

// respondent chars
use "${Input}\\${country}\\${wave}\\${parcel_roster}", clear
gen respondent_id = pp_saq07 
keep  respondent holder_id parcel_id
tempfile ID_list_temp
save `ID_list_temp', replace
use "${Input}\\${country}\\${wave}\\${plot_roster}", clear
merge m:1  holder_id parcel_id using `ID_list_temp', keep(match) nogen
egen plot_id = concat(holder_id parcel_id field_id), punct("-") 

sort  household_id (respondent_id)
collapse (first) respondent_id household_id , by(plot_id)
tempfile ID_list
save `ID_list', replace

use "${Input}\\${country}\\${wave}\\${household_roster}", clear
rename hh_s1q00 respondent_id // this is the HH member id 
merge 1:m  household_id respondent_id using `ID_list', keep(match) nogen
gen hh_s2q00 = respondent_id
merge m:1  household_id hh_s2q00 using "${Input}\\${country}\\${wave}\\${indiv_roster}", keep(match) keepusing(individual_id) nogen
rename respondent_id respondent_id_temp
gen respondent_id = individual_id
recode  hh_s1q03 (2=1 "Yes") (1=0 "No"), gen(female_respondent) 
rename hh_s1q04_a age_respondent
recode hh_s1q08 (2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married_respondent) 	
keep plot_id female_respondent age_respondent married_respondent respondent_id
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics1.dta", replace	

use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
rename hh_s2q00 respondent_id // this is the HH member id 
duplicates report household_id respondent_id // no duplicates
merge 1:m  household_id respondent_id using `ID_list', keep(match) nogen
recode hh_s2q03 ( 1 = 1 "Yes") (2 = 0 "No"), gen(formal_education_respondent) label(formal_education_respondent)
recode hh_s2q05 (0 98 1/3 93/96 4/7 = 0 "No" ) ///
(8/35 = 1 "Yes"), gen(primary_education_respondent) label(primary_education_respondent)
replace primary_education_respondent = 0 if hh_s2q03==2 // These individuals have never attended school
keep plot_id primary_education_respondent formal_education_respondent 
duplicates drop
save "${Temp}\\${temppath}\\Resp_characteristics2.dta", replace	

// hh size
use "${Input}\\${country}\\${wave}\\${cover}", clear
gen hh_size = hh_saq09
keep household_id hh_size
duplicates drop
save "${Temp}\\${temppath}\\hh_size.dta", replace	

// hh shock
use "${Input}\\${country}\\${wave}\\${shocks}", clear
recode hh_s8q01 (1 =1 "Yes") ( 2 = 0 "No"), gen(hh_shock) label(hh_shock) // I only code negative shocks as 1 
keep household_id hh_shock
collapse (max) hh_shock, by(household_id) 
save "${Temp}\\${temppath}\\hh_shock.dta", replace


// ag assets
use "${Input}\\${country}\\${wave}\\${assets}", clear
rename hh_s10q00 item_code
keep if inlist(item_code, 16,17,30,31,32,33,34,35)
rename hh_s10q01 d_
replace d_=1 if d_>1 & !mi(d_)
keep household_id item_code d_
reshape wide d_ , i(household_id) j(item_code)
factor d_*, pcf 
predict ag_asset_index
drop d_*
keep household_id ag_asset_index
duplicates drop
save "${Temp}\\${temppath}\\ag_asset_index.dta", replace


// hh assets
use "${Input}\\${country}\\${wave}\\${assets}", clear
drop if inlist(hh_s10q00, 16,17,30,31,32,33,34,35)
recode hh_s10q01 ( 0 = 0 ) (* = 1), gen (hh_owns) 
keep hh_owns household_id hh_s10q00
reshape wide hh_owns , i(household_id) j(hh_s10q00)
factor hh_owns*, pcf 
predict hh_asset_index
keep household_id hh_asset_index
duplicates drop
save "${Temp}\\${temppath}\\hh_asset_index.dta", replace

// non farm enterprise
use "${Input}\\${country}\\${wave}\\${nfe}", clear
egen total = rowtotal(hh_s11aq01 hh_s11aq02 hh_s11aq03 hh_s11aq04 hh_s11aq05 hh_s11aq06 hh_s11aq07 hh_s11aq08)
gen nonfarm_enterprise = 0 if total==16
replace nonfarm_enterprise = 1 if total<16
keep household_id nonfarm_enterprise
duplicates drop
save "${Temp}\\${temppath}\\nonfarm_enterprise.dta", replace

// latitude
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ( LAT_DD_MOD LON_DD_MOD) ( lat_modified lon_modified)
keep household_id lat_modified lon_modified
duplicates drop
save "${Temp}\\${temppath}\\Coords.dta", replace

// agro ecological zone
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename ssa_aez09 agro_ecological_zone
keep household_id agro_ecological_zone
duplicates drop
save "${Temp}\\${temppath}\\aez.dta", replace

// distance to nearest road
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep household_id dist_road
duplicates drop
save "${Temp}\\${temppath}\\dist_road.dta", replace

// distance to nearest population center
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep household_id dist_popcenter
duplicates drop
save "${Temp}\\${temppath}\\dist_popcenter.dta", replace

// distance to nearest market
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep household_id dist_market
duplicates drop
save "${Temp}\\${temppath}\\dist_market.dta", replace


// plot slope
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

rename plot_srtmslp plot_slope 
keep plot_id plot_slope
duplicates drop
save "${Temp}\\${temppath}\\plot_slope.dta", replace

// plot distance to hh
use "${Input}\\${country}\\${wave}\\${geovars_plot}", clear
egen plot_id = concat(holder_id parcel_id field_id), punct("-") // This creates a unique plot id.

rename dist_household plot_dist_household
keep plot_id plot_dist_household
duplicates drop
save "${Temp}\\${temppath}\\plot_dist_household.dta", replace

// plot elevation
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
rename srtm elevation 
keep household_id elevation
duplicates drop
save "${Temp}\\${temppath}\\elevation.dta", replace

// total wetness index
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
keep household_id twi
duplicates drop
save "${Temp}\\${temppath}\\twi.dta", replace

// soil variables
use "${Input}\\${country}\\${wave}\\${geovars_hh}", clear
forvalues i=1/7{
	recode sq`i' (1=1) (2/7=0), gen(sq`i'_d)
}
factor sq1_d-sq7_d, pcf 
predict soil_fertility_index

local names "nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability"
forvalues n =1/7 {
local lab: word `n' of `names'
rename	sq`n'_d `lab'
}
keep household_id  nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index
duplicates drop
save "${Temp}\\${temppath}\\soil.dta", replace

// popdensity (absent)

// indiv chars
use "${Input}\\${country}\\${wave}\\${household_roster}", clear

recode  hh_s1q03 (2=1 "Yes") (1=0 "No"), gen(female) 
rename hh_s1q04_a age
gen age_2 = floor(hh_s1q04_b/12)
replace age = age_2 if age==.
recode hh_s1q08 (2 3 = 1 "Yes") (1 4 5 6 = 0 "No"), gen(married)
replace married = 0 if married==.
decode hh_s1q02, generate(relationship_head) 
replace relationship_head = substr(relationship_head,strpos(relationship_head, " " ) + 1, .)
replace relationship_head = "Father-in-law/Mother-in-law" if relationship_head== "Father/month-in-Law"
replace relationship_head = "Son-in-law/Daughter-in-law" if relationship_head== "Son/Daughter-in-Law"
replace relationship_head = "Brother-in-law/Sister-in-law" if relationship_head== "Brother/Sister-in-Law"

keep household_id individual_id married female age relationship_head 
duplicates drop
save "${Temp}\\${temppath}\\indiv_chars.dta", replace


// wasting
use "${Input}\\${country}\\${wave}\\${health}", clear
merge 1:1 household_id individual_id using "${Input}\\${country}\\${wave}\\${household_roster}", keep(master match) nogen
merge 1:1 household_id individual_id using "${Temp}\\${temppath}\\indiv_chars.dta",  keep(master match) nogen

*Main anthropometric variables
gen weight=hh_s3q22
gen height=hh_s3q23
replace height=. if height>200

gen cage=age*12
replace cage = hh_s1q04_b if age==.
format %5.0g cage
zscore06, a(cage) s(female) h(height) w(weight) male(0) female(1)

gen wasting=whz06<-2 if whz06<.

keep haz06 waz06 whz06 bmiz06 wasting  household_id individual_id weight height
duplicates drop
save "${Temp}\\${temppath}\\wasting.dta", replace


// labor 
use "${Input}\\${country}\\${wave}\\${lab_roster}", clear

	// industry:
gen 	ind_ag = hh_s4q11_b == 1  // Agriculture 
gen 	ind_fish = hh_s4q11_b == 2	// fishing
gen 	ind_mining = hh_s4q11_b == 3	// mining
gen 	ind_manuf = hh_s4q11_b == 4 | hh_s4q11_b == 5	// manuf
gen 	ind_const = hh_s4q11_b == 6	// construc
gen 	ind_serv = hh_s4q11_b >= 7 & hh_s4q11_b<= 18	// services
foreach var in ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv {
	replace `var' = 0 if hh_s4q09==2 | hh_s4q09==. // not emplyed
}
recode hh_s4q04 (0 = 0) (.=.) (else = 1), gen( farm_work)
recode hh_s4q05 (0 = 0) (.=.) (else = 1), gen( SOB_work)
recode hh_s4q07 (0 = 0) (.=.) (else = 1), gen( wage_work)
rename (hh_s4q04 hh_s4q05 hh_s4q07 ) (farm_hrs SB_hrs wage_hrs )

	// nb of working age members
gen working_age =  hh_s4q01=="X"
bys household_id: egen nb_members_working_age = total(working_age)

foreach var in farm_hrs SB_hrs wage_hrs farm_work SOB_work wage_work  ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv  {
	replace `var' = 0 if working_age==0
}
keep individual_id household_id farm_work SOB_work wage_work farm_hrs SB_hrs wage_hrs ind_ag ind_const ind_fish ind_manuf ind_mining ind_serv  working_age
duplicates drop
save "${Temp}\\${temppath}\\labor.dta", replace

// education
use "${Input}\\${country}\\${wave}\\${indiv_roster}", clear
recode hh_s2q03 ( 1 = 1 "Yes") (2 = 0 "No"), gen(formal_education) label(formal_education)
recode hh_s2q05 (0 98 1/3 93/96 4/7 = 0 "No" ) (8/35 = 1 "Yes"), gen(primary_education) label(education)
foreach var in formal_education primary_education {
	replace `var' = 0  if hh_s2q01==""
	replace `var' = 0 if hh_s2q03==2
}
keep household_id individual_id formal_education primary_education
duplicates drop
save "${Temp}\\${temppath}\\educ_indiv.dta", replace

// HDDS 
use "${Input}\\${country}\\${wave}\\${HDDS}", clear

keep if hh_s5aq01 ==1 // keep if consumed

gen A = hh_s5aq00==1 | hh_s5aq00==2 | hh_s5aq00==3 | hh_s5aq00==4 | hh_s5aq00==5 | hh_s5aq00==6
gen B = hh_s5aq00==16
gen C = hh_s5aq00==14 | hh_s5aq00==17
gen D = hh_s5aq00==15
gen E = hh_s5aq00==18
gen F = hh_s5aq00==21
gen G = . 
gen H = hh_s5aq00>=7 & hh_s5aq00<=13
gen I = hh_s5aq00 == 19 | hh_s5aq00==20
gen J = .
gen K = hh_s5aq00==22
gen L = hh_s5aq00==23| hh_s5aq00==24 | hh_s5aq00==25

collapse (max) A B C D E F G H I J K L, by(household_id)
 egen HDDS = rowtotal(A B C D E F G H I J K L), missing 


merge 1:m household_id  using "${Input}\\${country}\\${wave}\\${HDDS}", 

collapse (max) HDDS, by(household_id)
replace HDDS = 0 if HDDS==.
save "${Temp}\\${temppath}\\HDDS.dta", replace

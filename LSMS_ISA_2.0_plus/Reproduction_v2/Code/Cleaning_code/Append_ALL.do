


// PLot crop

use "${Final}\\ETH_FINAL_plotcrop.dta", clear
gen country ="Ethiopia"
foreach cty in MWI MLI NER NGA TZA UGA {
append using "${Final}\\`cty'_FINAL_plotcrop.dta", 
replace country = "Malawi" if "`cty'"== "MWI" & country==""
replace country = "Mali" if "`cty'"== "MLI"  & country==""
replace country = "Niger" if "`cty'"== "NER" & country==""
replace country = "Nigeria" if "`cty'"== "NGA" & country==""
replace country = "Tanzania" if "`cty'"== "TZA" & country==""
replace country = "Uganda" if "`cty'"== "UGA" & country==""
}

foreach var in zaocode crop_code cropID cropid crop_id holder_id field_id plot_id plot_id_temp pltid plotID saq08 saq14 s12cq02a s12cq02b s12cq02b_os s12cq03 s12cq04_1 s12cq04_2 s12cq04_os s12cq05 s12cq05_os s12cq06 s12cq07a s11q11b s12cq08a s12cq08b s12cq08c s12cq08d s12cq08e n_seed_kg n_ph_s11q04 n_harvest_sold_kg n_harvest_kg n_harvest_sold_value garden_id ph_s11q04 ph_s11q01 pw_w3 pw_w4 pw_w5 saq01 saq02 saq03 saq04 saq05 saq06 saq07 mean_cf_nat mean_cf y2_hhid y3_hhid y4_hhid sdd_hhid Hhid  HHID prcid parcelID hhid household_id2 hid pw2 deflator pa_nus_atls n pct_lost pct_area_planted parcel_id year Nharvest_value parcel_id2 cropname2 tag hh_id_obs_temp t y5_hhid seed_value_cp n_seed_value_cp admin_2_str admin_3_str ea_id {
	capture drop `var' // last removals 
}
replace season = 1 if season==. // outside of UGA, season is set to 1 by default
define_labels

replace crop_name = strupper(crop_name)
replace crop_name = strtrim(crop_name)
replace crop_name = stritrim(crop_name)

sort country wave hh_id_obs plot_id_obs
duplicates report wave season hh_id_obs plot_id_obs crop_name
order country wave crop_name season pw ea_id_merge ea_id_obs strataid urban admin_1 admin_2 admin_3 admin_1_name admin_2_name admin_3_name lat_modified lon_modified geocoords_id parcel_id_obs parcel_id_merge	plot_id_obs plot_id_merge	hh_id_obs hh_id_merge		harvest_end_month	planting_month	harvest_kg	harvest_value_LCU harvest_value_USD		seed_kg	seed_value_LCU seed_value_USD 	improved	used_pesticides 	crop_shock	pests_shock 	rain_shock 	drought_shock 	flood_shock
save "${Final}\Plotcrop_dataset.dta", replace


// plot 
use "${Final}\\ETH_FINAL_plot.dta", clear
gen country ="Ethiopia"
foreach cty in MWI MLI NER NGA TZA UGA {
append using "${Final}\\`cty'_FINAL_plot.dta"
replace country = "Malawi" if "`cty'"== "MWI" & country==""
replace country = "Mali" if "`cty'"== "MLI" & country==""
replace country = "Niger" if "`cty'"== "NER" & country==""
replace country = "Nigeria" if "`cty'"== "NGA" & country==""
replace country = "Tanzania" if "`cty'"== "TZA" & country==""
replace country = "Uganda" if "`cty'"== "UGA" & country==""
}


foreach var in deflator  hhid month_planting year_planting  y3_hhid y4_hhid sdd_hhid  Hhid y2_hhid y3_hhid y4_hhid dist_popcenter2 self_reported_area pa_nus_atls area_self_reported n_harvest_kg n_harvest_value n_seed_kg n_seed_value Ntotal_labor_days Ntotal_family_labor_days Ntotal_hired_labor_days Nhired_labor_value year plot_id HHID   parcel_id y5_hhid  ID_worker1 ID_worker2 ID_worker3 ID_worker4 ID_worker5 ID_worker6 ID_worker7 ID_worker8 ID_worker9 ID_worker10 ID_worker11 ID_worker12 ID_worker13 ID_worker14 ID_worker1_PP ID_worker2_PP ID_worker3_PP ID_worker4_PP ID_worker5_PP ID_worker6_PP ID_worker7_PP ID_worker8_PP ID_worker9_PP ID_worker10_PP ID_worker11_PP ID_worker12_PP ID_worker13_PP ID_worker14_PP ID_worker15_PP ID_worker16_PP ID_worker17_PP ID_worker18_PP ID_worker19_PP ID_worker20_PP ID_worker21_PP ID_worker22_PP ID_worker23_PP ID_worker24_PP ID_worker1_PH ID_worker2_PH ID_worker3_PH ID_worker4_PH ID_worker5_PH ID_worker6_PH ID_worker7_PH ID_worker8_PH ID_worker9_PH ID_worker10_PH ID_worker11_PH ID_worker12_PH respondent_id ID_worker37_PP ID_worker38_PP ID_worker39_PP ID_worker40_PP ID_worker41_PP ID_worker42_PP ID_worker25_PP ID_worker26_PP ID_worker27_PP ID_worker28_PP ID_worker29_PP ID_worker30_PP	popdensity  admin_2_str admin_3_str ea_id popdensity manager_id {
	capture drop `var' // last removals 
}
	//cap age at 100 
	replace age_manager = 100 if age_manager>100 & !mi(age_manager)
	replace age_respondent = 100 if age_respondent>100 & !mi(age_respondent)
replace season = 1 if season==. // outside of UGA, season is set to 1 by default
define_labels
sort country wave hh_id_obs plot_id_obs
order country wave hh_id_obs hh_id_merge  plot_id_obs plot_id_merge parcel_id_obs parcel_id_merge  season pw ea_id_merge ea_id_obs strataid admin_1 admin_2 admin_3  admin_1_name admin_2_name  lat_modified lon_modified geocoords_id harvest_interview_month planting_interview_month  plot_area_GPS farm_size harvest_kg harvest_value_* yield_* total_labor_days total_hired_labor_days total_family_labor_days hired_labor_value_LCU hired_labor_value_USD seed_kg seed_value_* improved nitrogen_kg inorganic_fertilizer* organic_fertilizer used_pesticides *_shock intercropped nb_seasonal_crop maincrop_valueshare share_value_BARLEY share_value_LEGUMES share_value_MAIZE share_value_MILLET share_value_NUTS share_value_OTHER share_value_PERENNIAL share_value_RICE share_value_SORGHUM share_value_TUBERS share_value_WHEAT contains_BARLEY contains_LEGUMES contains_MAIZE contains_MILLET contains_OTHER contains_PERENNIALS contains_RICE contains_SORGHUM contains_TUBERS contains_WHEAT contains_NUTS manager_id_merge manager_id_obs age_manager female_manager married_manager formal_education_manager primary_education_manager respondent_id_merge respondent_id_obs age_respondent female_respondent married_respondent formal_education_respondent primary_education_respondent irrigated tractor erosion_protection plot_owned plot_certificate livestock  urban ag_asset_index agro_ecological_zone dist_popcenter dist_market elevation twi nutrient_availability nutrient_retention rooting_conditions oxygen_availability excess_salts toxicity workability soil_fertility_index plot_dist_household plot_slope
 

duplicates report wave season hh_id_obs plot_id_obs
save "${Final}\Plot_dataset.dta", replace


// household

use "${Final}\\ETH_FINAL_hh.dta", clear
gen country ="Ethiopia"
foreach cty in MWI MLI NER NGA TZA UGA {
append using "${Final}\\`cty'_FINAL_hh.dta", 
replace country = "Malawi" if "`cty'"== "MWI" & country==""
replace country = "Mali" if "`cty'"== "MLI" & country==""
replace country = "Niger" if "`cty'"== "NER" & country==""
replace country = "Nigeria" if "`cty'"== "NGA" & country==""
replace country = "Tanzania" if "`cty'"== "TZA" & country==""
replace country = "Uganda" if "`cty'"== "UGA" & country==""
}

define_labels
foreach var in  deflator  pa_nus_atls hhid ag_hh_obs case_id hh_wgt y2_hhid y3_hhid y4_hhid sdd_hhid Hhid HHID year admin_3_name hh_wgt hh_id_obs_temp y5_hhid admin_2_str admin_3_str  ea_id popdensity {
	capture drop `var' // last removals 
}
replace season = 1 if season==. // outside of UGA, season is set to 1 by default
define_labels

sort country wave hh_id_obs 
duplicates report wave season hh_id_obs 
order country wave hh_id_merge hh_id_obs  season pw ea_id_merge ea_id_obs strataid urban admin_1 admin_2 admin_3 admin_1_name admin_2_name  lat_modified lon_modified geocoords_id 	hh_size	hh_shock 	hh_primary_education		hh_electricity_access	hh_dependency_ratio	hh_formal_education	nonfarm_enterprise		nb_fallow_plots	nb_plots 	share_kg_sold		totcons_LCU totcons_USD	cons_quint	hh_asset_index	HDDS	

save "${Final}\Household_dataset.dta", replace


// individual

use "${Final}\\ETH_FINAL_indiv.dta", clear
gen country ="Ethiopia"
foreach cty in MWI MLI NER NGA TZA UGA {
append using "${Final}\\`cty'_FINAL_indiv.dta", 
replace country = "Malawi" if "`cty'"== "MWI" & country==""
replace country = "Mali" if "`cty'"== "MLI" & country==""
replace country = "Niger" if "`cty'"== "NER" & country==""
replace country = "Nigeria" if "`cty'"== "NGA" & country==""
replace country = "Tanzania" if "`cty'"== "TZA" & country==""
replace country = "Uganda" if "`cty'"== "UGA" & country==""
}
define_labels
foreach var in   nb_members_working_age hhid ID ms01q06b birth_month sdd_hhid Hhid HHID hh_b05b y2_hhid y3_hhid y4_hhid PID  year case_id PID hh_b05b y2_hhid y3_hhid y4_hhid hhid ID ms01q06b sdd_hhid Hhid birth_month HHID admin_3_name case_id PID hh_b05b y2_hhid y3_hhid y4_hhid hhid ID ms01q06b sdd_hhid Hhid birth_month HHID household_id household_id2 individual_id2 individual_id individual_id_w1 hh_id_obs_temp indiv_id_obs_temp y5_hhid indiv_id_obs_temp7 indiv_id_obs_temp8 ea_id admin_2_str admin_3_str _merge {
	capture drop `var' // last removals 
}
replace season = 1 if season==. // outside of UGA, season is set to 1 by default	
	//cap age at 100 
	replace age = 100 if age>100 & !mi(age)
order country wave  hh_id_obs hh_id_merge indiv_id_obs	indiv_id_merge season pw ea_id_merge ea_id_obs strataid urban admin_1 admin_2 admin_3 admin_1_name admin_2_name  lat_modified lon_modified geocoords_id 	relationship_head	age	married	female	formal_education 	primary_education	height	weight	wasting	haz06	waz06	whz06	bmiz06	farm_work	SOB_work	wage_work	farm_hrs	SB_hrs	wage_hrs	ind_ag	ind_fish	ind_mining	ind_manuf	ind_const	ind_serv	working_age

sort country wave hh_id_obs indiv_id_obs
duplicates report wave season hh_id_obs indiv_id_obs
order country wave season hh_id_obs hh_id_merge indiv_id_obs indiv_id_merge   pw ea_id_merge ea_id_obs strataid urban admin_1 admin_2 admin_3 admin_1_name admin_2_name  lat_modified lon_modified geocoords_id 	

save "${Final}\Individual_dataset.dta", replace




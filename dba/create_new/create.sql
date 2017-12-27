CREATE TABLE public.region_lk
(
  region_code smallint PRIMARY KEY,
  region_name character varying(50),
  region_desc character varying(100)
);

CREATE TABLE state_lk (
state_id int PRIMARY KEY,
STATE_ABBR character(2),
STATE_NAME varchar(50),
STATE_FIPS_CODE int,
region_code smallint REFERENCES region_lk(region_code)
);

__ With a PE Admin Import Exclude the agency_name_edit column when loading the csv
CREATE TABLE public.summarized_data
(
	DATA_YEAR	smallint,
	AGENCY_ID	int,
	MONTH_NUM	smallint,
  ORI	varchar(25),
	AGENCY_TYPE_NAME	varchar(100),
	pub_agency_name varchar(100),
  pub_agency_unit varchar(100),
  ucr_agency_name varchar(100),
  ncic_agency_name varchar(100),
	POPULATION		int,
	POPULATION_GROUP_ID	smallint,
	POPULATION_GROUP_CODE	character(3),
	POPULATION_GROUP_DESC	varchar(100),
  PARENT_POP_GROUP_CODE smallint,
  PARENT_POP_GROUP_DESC varchar(100),
  POP_SORT_ORDER smallint,
	MIP_FLAG		boolean,
	SUMMARY_RAPE_DEF	character(1),
	PE_REPORTED_FLAG	character(1),
  male_officer int,
  male_civilian int,
  male_total int,
  female_officer int,
  female_civilian int,
  female_total int,
  officer_rate int,
  employee_rate int,
	STATE_NAME	varchar(100),
	STATE_ID	smallint,
  STATE_ABBR	character(2),
  COUNTY_NAME varchar(100),
  MSA_NAME varchar(100),
	DIVISION_CODE	smallint,
	DIVISION_NAME	varchar(100),
	REGION_CODE	smallint,
	REGION_NAME	varchar(100),
  JUDICIAL_DIST_CODE varchar(25),
  FIELD_OFFICE_ID int,
	SUM_UNKNOWN	int,
	SUM_HOM		int,
	SUM_MAN		int,
	SUM_RPE_NS_LEG	int,
	SUM_RPE_FRC_LEG	int,
	SUM_RPE_ATT_LEG	int,
	SUM_RPE_NS	int,
	SUM_RPE_FRC	int,
	SUM_RPE_ATT	int,
	SUM_ROB_NS	int,
	SUM_ROB_GUN	int,
	SUM_ROB_CUT	int,
	SUM_ROB_OTH	int,
	SUM_ROB_HFF	int,
	SUM_ASS_NS	int,
	SUM_ASS_GUN	int,
	SUM_ASS_CUT	int,
	SUM_ASS_OTH	int,
	SUM_ASS_HFF	int,
	SUM_ASS_SM	int,
	SUM_BRG_NS	int,
	SUM_BRG_FEO	int,
	SUM_BRG_UEO	int,
	SUM_BRG_AFE	int,
	SUM_LAR_TFT	int,
	SUM_MTR_NS	int,
	SUM_MTR_ATO	int,
	SUM_MTR_TRK	int,
	SUM_MTR_OTH	int,
	SUM_HT_NS	int,
	SUM_HT_SEX	int,
	SUM_HT_SRV	int,
	SUM_ARS		int,
  agency_name_edit varchar(100)
);


UPDATE public.summarized_data sd
   SET agency_name_edit= edited_name
 FROM public.agency_name_edits ane
 WHERE ane.ori = sd.ori

 CREATE MATERIALIZED VIEW agencies AS
 select distinct on(agency_id) agency_id, ori as ori, agency_type_name as agency_type_name, state_id as state_id, state_abbr as state_abbr, agency_name_edit as agency_name_edit, county_name as county_name
     from public.summarized_data

    CREATE MATERIALIZED VIEW summarized_data_national AS
     select data_year as data_year,
     SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
     SUM(sum_unknown) as sum_unknown,
   SUM(sum_hom) as homicide,
   (((SUM(sum_hom)*1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as homicide_rate,
   SUM(sum_man) as sum_man,
   SUM(sum_rpe_ns_leg) as sum_rpe_ns_leg,
   SUM(sum_rpe_frc_leg) as sum_rpe_frc_leg,
   SUM(sum_rpe_att_leg) as sum_rpe_att_leg,
   (SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)) as rape_legacy,
   ((((SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as rape_legacy_rate,
   SUM(sum_rpe_ns) as sum_rpe_ns,
   SUM(sum_rpe_frc) as sum_rpe_frc,
   SUM(sum_rpe_att) as sum_rpe_att,
   (SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)) as rape,
   ((((((SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att))) *1.0))/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as rape_rate,
   SUM(sum_rob_ns) as sum_rob_ns,
   SUM(sum_rob_gun) as sum_rob_gun,
   SUM(sum_rob_cut) as sum_rob_cut,
   SUM(sum_rob_oth) as sum_rob_oth,
   SUM(sum_rob_hff) as sum_rob_hff,
   (SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as robbery,
   (((((SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as robbery_rate,
   (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)+SUM(sum_hom)+SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)+SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)+SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as violent_crime,
   (((((SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)+SUM(sum_hom)+SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)+SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)+SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as violent_crime_rate,
   SUM(sum_ass_ns) as sum_ass_ns,
   SUM(sum_ass_gun) as  sum_ass_gun,
   SUM(sum_ass_cut) as sum_ass_cut ,
   SUM(sum_ass_oth) as sum_ass_oth ,
   SUM(sum_ass_hff) as sum_ass_hff ,
   SUM(sum_ass_sm) as sum_ass_sm ,
   (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)) as aggravated_assault,
   (((((SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as aggravated_assault_rate,
   SUM(sum_brg_ns) as sum_brg_ns,
   SUM(sum_brg_feo) as sum_brg_feo ,
   SUM(sum_brg_ueo) as sum_brg_ueo,
   SUM(sum_brg_afe) as sum_brg_afe,
   (SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)) as burglary,
   (((((SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as burglary_rate,
   SUM(sum_lar_tft) as larceny,
  (((((SUM(sum_lar_tft))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as larceny_rate,
   SUM(sum_mtr_ns) as sum_mtr_ns,
   SUM(sum_mtr_ato) as sum_mtr_ato,
   SUM(sum_mtr_trk) as sum_mtr_trk,
   SUM(sum_mtr_oth) as sum_mtr_oth,
   (SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as motor_vehicle_theft,
   (((((SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as motor_vehicle_theft_rate,
   (SUM(sum_lar_tft)+SUM(sum_ars)+SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)+SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as property_crime,
   (((((SUM(sum_lar_tft)+SUM(sum_ars)+SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)+SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as property_crime_rate,
   SUM(sum_ht_ns) as sum_ht_ns,
   SUM(sum_ht_sex) as sum_ht_sex ,
   SUM(sum_ht_srv) as sum_ht_srv,
   (SUM(sum_ht_ns)+SUM(sum_ht_sex)+SUM(sum_ht_srv)) as human_trafficing,
   (((((SUM(sum_ht_ns)+SUM(sum_ht_sex)+SUM(sum_ht_srv))) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0)as human_trafficing_rate,
   SUM(sum_ars) as arson,
   ((((SUM(sum_ars)) *1.0)/ (SUM(CASE WHEN month_num = 12 THEN population ELSE null END) )*1.0) * 100000.0) as arson_rate
         from public.summarized_data GROUP BY data_year;


         CREATE MATERIALIZED VIEW summarized_data_region AS
         select region_code, region_name, data_year as data_year,
         SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
         SUM(sum_unknown) as sum_unknown,
           SUM(sum_hom) as homicide,
           (((SUM(sum_hom)*1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as homicide_rate,
           SUM(sum_man) as sum_man,
           SUM(sum_rpe_ns_leg) as sum_rpe_ns_leg,
           SUM(sum_rpe_frc_leg) as sum_rpe_frc_leg,
           SUM(sum_rpe_att_leg) as sum_rpe_att_leg,
           (SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)) as rape_legacy,
           ((((SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as rape_legacy_rate,
           SUM(sum_rpe_ns) as sum_rpe_ns,
           SUM(sum_rpe_frc) as sum_rpe_frc,
           SUM(sum_rpe_att) as sum_rpe_att,
           (SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)) as rape,
           ((((((SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att))) *1.0))/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as rape_rate,
           SUM(sum_rob_ns) as sum_rob_ns,
           SUM(sum_rob_gun) as sum_rob_gun,
           SUM(sum_rob_cut) as sum_rob_cut,
           SUM(sum_rob_oth) as sum_rob_oth,
           SUM(sum_rob_hff) as sum_rob_hff,
           (SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as robbery,
           (((((SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as robbery_rate,
           (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)+SUM(sum_hom)+SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)+SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)+SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as violent_crime,
           (((((SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)+SUM(sum_hom)+SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)+SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)+SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as violent_crime_rate,
           SUM(sum_ass_ns) as sum_ass_ns,
           SUM(sum_ass_gun) as  sum_ass_gun,
           SUM(sum_ass_cut) as sum_ass_cut ,
           SUM(sum_ass_oth) as sum_ass_oth ,
           SUM(sum_ass_hff) as sum_ass_hff ,
           SUM(sum_ass_sm) as sum_ass_sm ,
           (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)) as aggravated_assault,
           (((((SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as aggravated_assault_rate,
           SUM(sum_brg_ns) as sum_brg_ns,
           SUM(sum_brg_feo) as sum_brg_feo ,
           SUM(sum_brg_ueo) as sum_brg_ueo,
           SUM(sum_brg_afe) as sum_brg_afe,
           (SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)) as burglary,
           (((((SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as burglary_rate,
           SUM(sum_lar_tft) as larceny,
           (((((SUM(sum_lar_tft))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as larceny_rate,
           SUM(sum_mtr_ns) as sum_mtr_ns,
           SUM(sum_mtr_ato) as sum_mtr_ato,
           SUM(sum_mtr_trk) as sum_mtr_trk,
           SUM(sum_mtr_oth) as sum_mtr_oth,
           (SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as motor_vehicle_theft,
           (((((SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as motor_vehicle_theft_rate,
           (SUM(sum_lar_tft)+SUM(sum_ars)+SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)+SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as property_crime,
           (((((SUM(sum_lar_tft)+SUM(sum_ars)+SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)+SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as property_crime_rate,
           SUM(sum_ht_ns) as sum_ht_ns,
           SUM(sum_ht_sex) as sum_ht_sex ,
           SUM(sum_ht_srv) as sum_ht_srv,
           (SUM(sum_ht_ns)+SUM(sum_ht_sex)+SUM(sum_ht_srv)) as human_trafficing,
           (((((SUM(sum_ht_ns)+SUM(sum_ht_sex)+SUM(sum_ht_srv))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0)as human_trafficing_rate,
           SUM(sum_ars) as arson,
           ((((SUM(sum_ars)) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as arson_rate
             from public.summarized_data GROUP BY region_code,region_name, data_year;

    CREATE MATERIALIZED VIEW summarized_data_state AS
  select state_id, state_name as state_name, state_abbr as state_abbr, data_year as data_year,
  SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
  SUM(sum_unknown) as sum_unknown,
    SUM(sum_hom) as homicide,
    (((SUM(sum_hom)*1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as homicide_rate,
    SUM(sum_man) as sum_man,
    SUM(sum_rpe_ns_leg) as sum_rpe_ns_leg,
    SUM(sum_rpe_frc_leg) as sum_rpe_frc_leg,
    SUM(sum_rpe_att_leg) as sum_rpe_att_leg,
    (SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)) as rape_legacy,
    ((((SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as rape_legacy_rate,
    SUM(sum_rpe_ns) as sum_rpe_ns,
    SUM(sum_rpe_frc) as sum_rpe_frc,
    SUM(sum_rpe_att) as sum_rpe_att,
    (SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)) as rape,
    ((((((SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att))) *1.0))/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as rape_rate,
    SUM(sum_rob_ns) as sum_rob_ns,
    SUM(sum_rob_gun) as sum_rob_gun,
    SUM(sum_rob_cut) as sum_rob_cut,
    SUM(sum_rob_oth) as sum_rob_oth,
    SUM(sum_rob_hff) as sum_rob_hff,
    (SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as robbery,
    (((((SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as robbery_rate,
    (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)+SUM(sum_hom)+SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)+SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)+SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as violent_crime,
    (((((SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)+SUM(sum_hom)+SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)+SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)+SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as violent_crime_rate,
    SUM(sum_ass_ns) as sum_ass_ns,
    SUM(sum_ass_gun) as  sum_ass_gun,
    SUM(sum_ass_cut) as sum_ass_cut ,
    SUM(sum_ass_oth) as sum_ass_oth ,
    SUM(sum_ass_hff) as sum_ass_hff ,
    SUM(sum_ass_sm) as sum_ass_sm ,
    (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)) as aggravated_assault,
    (((((SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as aggravated_assault_rate,
    SUM(sum_brg_ns) as sum_brg_ns,
    SUM(sum_brg_feo) as sum_brg_feo ,
    SUM(sum_brg_ueo) as sum_brg_ueo,
    SUM(sum_brg_afe) as sum_brg_afe,
    (SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)) as burglary,
    (((((SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as burglary_rate,
    SUM(sum_lar_tft) as larceny,
    (((((SUM(sum_lar_tft))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as larceny_rate,
    SUM(sum_mtr_ns) as sum_mtr_ns,
    SUM(sum_mtr_ato) as sum_mtr_ato,
    SUM(sum_mtr_trk) as sum_mtr_trk,
    SUM(sum_mtr_oth) as sum_mtr_oth,
    (SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as motor_vehicle_theft,
    (((((SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as motor_vehicle_theft_rate,
    (SUM(sum_lar_tft)+SUM(sum_ars)+SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)+SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as property_crime,
    (((((SUM(sum_lar_tft)+SUM(sum_ars)+SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)+SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as property_crime_rate,
    SUM(sum_ht_ns) as sum_ht_ns,
    SUM(sum_ht_sex) as sum_ht_sex ,
    SUM(sum_ht_srv) as sum_ht_srv,
    (SUM(sum_ht_ns)+SUM(sum_ht_sex)+SUM(sum_ht_srv)) as human_trafficing,
    (((((SUM(sum_ht_ns)+SUM(sum_ht_sex)+SUM(sum_ht_srv))) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0)as human_trafficing_rate,
    SUM(sum_ars) as arson,
    ((((SUM(sum_ars)) *1.0)/ NULLIF((SUM(CASE WHEN month_num = 12 THEN population ELSE null END) ),0)*1.0) * 100000.0) as arson_rate
      from public.summarized_data GROUP BY state_id,state_name,state_abbr, data_year;

      CREATE MATERIALIZED VIEW summarized_data_agency AS
            select ori, ncic_agency_name as ncic_agency_name, agency_name_edit as agency_name_edit,agency_type_name as agency_type_name,state_abbr as state_abbr , data_year as data_year,
            SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
            SUM(sum_unknown) as sum_unknown,
  SUM(sum_hom) as homicide,
  SUM(sum_man) as sum_man,
  SUM(sum_rpe_ns_leg) as sum_rpe_ns_leg,
  SUM(sum_rpe_frc_leg) as sum_rpe_frc_leg,
  SUM(sum_rpe_att_leg) as sum_rpe_att_leg,
  (SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)) as rape_legacy,
  SUM(sum_rpe_ns) as sum_rpe_ns,
  SUM(sum_rpe_frc) as sum_rpe_frc,
  SUM(sum_rpe_att) as sum_rpe_att,
  (SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)) as rape,
  SUM(sum_rob_ns) as sum_rob_ns,
  SUM(sum_rob_gun) as sum_rob_gun,
  SUM(sum_rob_cut) as sum_rob_cut,
  SUM(sum_rob_oth) as sum_rob_oth,
  SUM(sum_rob_hff) as sum_rob_hff,
  (SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as robbery,
  (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)+SUM(sum_hom)+SUM(sum_rpe_ns_leg)+SUM(sum_rpe_frc_leg)+SUM(sum_rpe_ns)+SUM(sum_rpe_frc)+SUM(sum_rpe_att)+SUM(sum_rob_ns)+SUM(sum_rob_gun)+SUM(sum_rob_cut)+SUM(sum_rob_oth)+SUM(sum_rob_hff)) as violent_crime,
  SUM(sum_ass_ns) as sum_ass_ns,
  SUM(sum_ass_gun) as  sum_ass_gun,
  SUM(sum_ass_cut) as sum_ass_cut ,
  SUM(sum_ass_oth) as sum_ass_oth ,
  SUM(sum_ass_hff) as sum_ass_hff ,
  SUM(sum_ass_sm) as sum_ass_sm ,
  (SUM(sum_ass_ns)+SUM(sum_ass_gun)+SUM(sum_ass_cut)+SUM(sum_ass_hff)) as aggravated_assault,
  SUM(sum_brg_ns) as sum_brg_ns,
  SUM(sum_brg_feo) as sum_brg_feo ,
  SUM(sum_brg_ueo) as sum_brg_ueo,
  SUM(sum_brg_afe) as sum_brg_afe,
  (SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)) as burglary,
  SUM(sum_lar_tft) as larceny,
  SUM(sum_mtr_ns) as sum_mtr_ns,
  SUM(sum_mtr_ato) as sum_mtr_ato,
  SUM(sum_mtr_trk) as sum_mtr_trk,
  SUM(sum_mtr_oth) as sum_mtr_oth,
  (SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as motor_vehicle_theft,
  (SUM(sum_lar_tft)+SUM(sum_ars)+SUM(sum_brg_ns)+SUM(sum_brg_feo)+SUM(sum_brg_ueo)+SUM(sum_brg_afe)+SUM(sum_mtr_ns)+SUM(sum_mtr_ato)+SUM(sum_mtr_trk)+SUM(sum_mtr_oth)) as property_crime,
  SUM(sum_ht_ns) as sum_ht_ns,
  SUM(sum_ht_sex) as sum_ht_sex ,
  SUM(sum_ht_srv) as sum_ht_srv,
  (SUM(sum_ht_ns)+SUM(sum_ht_sex)+SUM(sum_ht_srv)) as human_trafficing,
  SUM(sum_ars) as arson
                from public.summarized_data GROUP BY ori,ncic_agency_name,agency_name_edit, agency_type_name, state_abbr,data_year;

CREATE MATERIALIZED VIEW police_employment_nation AS
  SELECT
    data_year as data_year,
    SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
    SUM(male_officer) as male_officer_ct,
    SUM(male_civilian) as male_civilian_ct,
    SUM(male_total) as male_total_ct,
    SUM(female_officer) as female_officer_ct,
    SUM(female_civilian) as female_civilian_ct,
    SUM(female_total) as female_total_ct,
    SUM(male_officer)+SUM(female_officer) as officer_ct,
    SUM(male_civilian)+SUM(female_civilian) as civilian_ct,
    SUM(male_total)+SUM(female_total) as total_pe_ct,
    ROUND(((SUM(male_total)+SUM(female_total))*1.0 / SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END))*1000,2) as pe_ct_per_1000
  FROM public.summarized_data
  GROUP BY data_year;

CREATE MATERIALIZED VIEW police_employment_region AS
  SELECT
    region_code as region_code,
    region_name as region_name,
    data_year as data_year,
    SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
    SUM(male_officer) as male_officer_ct,
    SUM(male_civilian) as male_civilian_ct,
    SUM(male_total) as male_total_ct,
    SUM(female_officer) as female_officer_ct,
    SUM(female_civilian) as female_civilian_ct,
    SUM(female_total) as female_total_ct,
    SUM(male_officer)+SUM(female_officer) as officer_ct,
    SUM(male_civilian)+SUM(female_civilian) as civilian_ct,
    SUM(male_total)+SUM(female_total) as total_pe_ct,
    ROUND(((SUM(male_total)+SUM(female_total))*1.0 / NULLIF(SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END),0))*1000,2) as pe_ct_per_1000
  FROM public.summarized_data
  GROUP BY region_code, region_name, data_year;

CREATE MATERIALIZED VIEW police_employment_state AS
  SELECT
    state_id as state_id,
    state_name as state_name,
    state_abbr as state_abbr,
    data_year as data_year,
    SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
    SUM(male_officer) as male_officer_ct,
    SUM(male_civilian) as male_civilian_ct,
    SUM(male_total) as male_total_ct,
    SUM(female_officer) as female_officer_ct,
    SUM(female_civilian) as female_civilian_ct,
    SUM(female_total) as female_total_ct,
    SUM(male_officer)+SUM(female_officer) as officer_ct,
    SUM(male_civilian)+SUM(female_civilian) as civilian_ct,
    SUM(male_total)+SUM(female_total) as total_pe_ct,
    ROUND(((SUM(male_total)+SUM(female_total))*1.0 / NULLIF(SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END),0))*1000,2) as pe_ct_per_1000
  FROM public.summarized_data
  GROUP BY state_id, state_name, state_abbr, data_year;

CREATE MATERIALIZED VIEW police_employment_agency AS
  SELECT
    ori as ori,
    ncic_agency_name as ncic_agency_name,
    agency_name_edit as agency_name_edit,
    agency_type_name as agency_type_name,
    state_abbr as state_abbr,
    data_year as data_year,
    SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END) as population,
    SUM(male_officer) as male_officer_ct,
    SUM(male_civilian) as male_civilian_ct,
    SUM(male_total) as male_total_ct,
    SUM(female_officer) as female_officer_ct,
    SUM(female_civilian) as female_civilian_ct,
    SUM(female_total) as female_total_ct,
    SUM(male_officer)+SUM(female_officer) as officer_ct,
    SUM(male_civilian)+SUM(female_civilian) as civilian_ct,
    SUM(male_total)+SUM(female_total) as total_pe_ct,
    ROUND(((SUM(male_total)+SUM(female_total))*1.0 / NULLIF(SUM(CASE WHEN month_num = 12 THEN population ELSE 0 END),0))*1000,2) as pe_ct_per_1000
  FROM public.summarized_data
  GROUP BY ori, ncic_agency_name, agency_name_edit, agency_type_name, state_abbr, data_year;

-- Drops
drop MATERIALIZED VIEW summarized_data_state;
drop MATERIALIZED VIEW  summarized_data_region;
drop MATERIALIZED VIEW  summarized_data_national;
drop MATERIALIZED VIEW summarized_data_agency;
drop MATERIALIZED VIEW agencies;
drop MATERIALIZED VIEW police_employment_nation;
drop MATERIALIZED VIEW police_employment_region;
drop MATERIALIZED VIEW police_employment_state;
drop MATERIALIZED VIEW police_employment_agency;

--Refreshes
-- Drops
refresh MATERIALIZED VIEW summarized_data_state;
refresh MATERIALIZED VIEW  summarized_data_region;
refresh MATERIALIZED VIEW  summarized_data_national;
refresh MATERIALIZED VIEW summarized_data_agency;
refresh MATERIALIZED VIEW agencies;
refresh MATERIALIZED VIEW police_employment_nation;
refresh MATERIALIZED VIEW police_employment_region;
refresh MATERIALIZED VIEW police_employment_state;
refresh MATERIALIZED VIEW police_employment_agency;
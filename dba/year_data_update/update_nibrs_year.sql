-- This script should load + merge one year of UCR NIBRS data in the 
-- form of multiple CSV|TSV files. 


-- Most of this stuff is optimized so that the queries run in a reasonable amount of time, 
-- processing the smallest slice of data possible.

-- Additionally, we use a series of UPDATES instead of a large UPDATE/INSERT because
-- it allows us to run an update, check the results, and verify before proceeding.
-- Also, a series of smaller queries is more likely to stay in RAM than a large one.

-- !!!!!!!!!!!!!! Grep/Replace _2015 with the new _{YEAR} !!!!!!!!!!!!!!!


-- Add some basic indexes to speed up selection + joining for transformation queries.

-- nibrs_incident
ALTER TABLE ONLY nibrs_incident_new
    ADD CONSTRAINT nibrs_incident_pkey_new PRIMARY KEY (incident_id);

CREATE INDEX nibrs_incident_agency_id_new_idx ON nibrs_incident_new USING btree (agency_id);
CREATE INDEX nibrs_incident_idx1_new ON nibrs_incident_new USING btree (agency_id, incident_date);

-- nibrs_victim
ALTER TABLE ONLY nibrs_victim_new
    ADD CONSTRAINT nibrs_victim_pkey_new PRIMARY KEY (victim_id);
CREATE INDEX nibrs_victim_idx1_new ON nibrs_victim_new USING btree (victim_id, incident_id);

-- nibrs_offender
ALTER TABLE ONLY nibrs_offender_new
    ADD CONSTRAINT nibrs_offender_pkey_new PRIMARY KEY (offender_id);
CREATE INDEX nibrs_offender_idx1_new ON nibrs_offender_new USING btree (offender_id, incident_id);

-- nibrs_offense
ALTER TABLE ONLY nibrs_offense_new
    ADD CONSTRAINT nibrs_offense_pkey_new PRIMARY KEY (offense_id);
CREATE INDEX nibrs_offense_idx1_new ON nibrs_offense_new USING btree (offense_id, incident_id);

-- nibrs_arrestee
ALTER TABLE ONLY nibrs_arrestee_new
    ADD CONSTRAINT nibrs_arrestee_pkey_new PRIMARY KEY (arrestee_id);
CREATE INDEX nibrs_arrestee_idx1_new ON nibrs_arrestee_new USING btree (arrestee_id, incident_id);

-- nibrs_property
ALTER TABLE ONLY nibrs_property_new
    ADD CONSTRAINT nibrs_prop_pkey_new PRIMARY KEY (property_id);
CREATE INDEX nibrs_property_idx1_new ON nibrs_property_new USING btree (property_id, incident_id);

-- nibrs_property_desc
CREATE INDEX nibrs_property_desc_idx1_new ON nibrs_property_desc_new USING btree (property_id, prop_desc_id);

-- FUN TRICK: Trick the partition trigger into creating a new partition with 
--   appropriate CHECK() statements, and all that jazz (so you can insert directly into the 
--   partition rather than through the trigger - which can be slower). 
INSERT INTO nibrs_victim_denorm (incident_id, victim_id, year, incident_date) VALUES (9999999999,999999999, '2015',to_timestamp('01-01-2015','MM-DD-YYYY'));
DELETE from nibrs_victim_denorm_2015;
INSERT INTO nibrs_incident_denorm (incident_id, agency_id, year, incident_date) VALUES (9999999999,999999999, '2015',to_timestamp('01-01-2015','MM-DD-YYYY'));
DELETE from nibrs_incident_denorm_2015;
INSERT INTO nibrs_offender_denorm (incident_id, offender_id, year, incident_date)  VALUES (9999999999,999999999, '2015',to_timestamp('01-01-2015','MM-DD-YYYY'));
DELETE from nibrs_offender_denorm_2015;
INSERT INTO nibrs_offense_denorm (incident_id, offense_id, year, incident_date)  VALUES (9999999999,999999999, '2015',to_timestamp('01-01-2015','MM-DD-YYYY'));
DELETE from nibrs_offense_denorm_2015;
INSERT INTO nibrs_arrestee_denorm (incident_id, arrestee_id, year, incident_date)  VALUES (9999999999,999999999, '2015',to_timestamp('01-01-2015','MM-DD-YYYY'));
DELETE from nibrs_arrestee_denorm_2015;
INSERT INTO nibrs_property_denorm (incident_id, property_id, year, incident_date)  VALUES (9999999999,999999999, '2015',to_timestamp('01-01-2015','MM-DD-YYYY'));
DELETE from nibrs_property_denorm_2015;

-- Give it a little more work mem to work with. Adjust this down if you get out of memory errors.
SET work_mem='2GB';

--
-- Begin Transformation queries.
-- Transform the newly uploaded data, 
-- and load it into our partitioned denormalized (and simplified) tables.
--

INSERT INTO nibrs_incident_denorm_2015 (incident_id, agency_id, state_id, ori, year, incident_date) SELECT nibrs_incident_new.incident_id, nibrs_incident_new.agency_id, ref_agency.state_id, ref_agency.ori, EXTRACT(YEAR FROM nibrs_incident_new.incident_date) as year, nibrs_incident_new.incident_date from nibrs_incident_new JOIN ref_agency ON (ref_agency.agency_id = nibrs_incident_new.agency_id) where nibrs_incident_new.incident_date >= to_timestamp('01-01-2015', 'MM-DD-YYYY');
-- UPDATE nibrs_incident_denorm_2015 SET state_abbr = ref_state.state_postal_abbr from ref_state where nibrs_incident_denorm_2015.state_id = ref_state.state_id and nibrs_incident_denorm_2015.year = '2015';


-- Insert directly into a single partition to bypass the partition trigger (faster).
-- DONE (~5 min per update)
INSERT INTO nibrs_victim_denorm_2015 (incident_id, agency_id, year, incident_date, victim_id, age_id, age_num, sex_code, race_id, victim_type_id,resident_status_code) SELECT nibrs_victim_new.incident_id, nibrs_incident_new.agency_id, EXTRACT(YEAR FROM nibrs_incident_new.incident_date) as year, nibrs_incident_new.incident_date, nibrs_victim_new.victim_id, nibrs_victim_new.age_id, nibrs_victim_new.age_num::numeric, nibrs_victim_new.sex_code,nibrs_victim_new.race_id, nibrs_victim_new.victim_type_id, nibrs_victim_new.resident_status_code from nibrs_victim_new JOIN nibrs_incident_new on nibrs_incident_new.incident_id = nibrs_victim_new.incident_id where nibrs_incident_new.incident_date >= to_timestamp('01-01-2015', 'MM-DD-YYYY');
UPDATE nibrs_victim_denorm_2015 SET state_id = ref_agency.state_id, county_id = ref_agency_county.county_id from ref_agency JOIN ref_agency_county ON ref_agency.agency_id = ref_agency_county.agency_id where nibrs_victim_denorm_2015.agency_id = ref_agency.agency_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET state_code = ref_state.state_code from ref_state where nibrs_victim_denorm_2015.state_id = ref_state.state_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET race_code = ref_race.race_code from ref_race where nibrs_victim_denorm_2015.race_id = ref_race.race_id and nibrs_victim_denorm_2015.year = '2015'; 
UPDATE nibrs_victim_denorm_2015 SET offense_id = nibrs_offense_new.offense_id, offense_type_id = nibrs_offense_new.offense_type_id, location_id = nibrs_offense_new.location_id from nibrs_offense_new  where nibrs_offense_new.incident_id = nibrs_victim_denorm_2015.incident_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET offense_name = nibrs_offense_type.offense_name from nibrs_offense_type where nibrs_offense_type.offense_type_id = nibrs_victim_denorm_2015.offense_type_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET circumstance_name = nibrs_circumstances.circumstances_name, ethnicity = nibrs_ethnicity.ethnicity_name, victim_type = nibrs_victim_type.victim_type_name from nibrs_victim_circumstances ON nibrs_victim_circumstances.victim_id = nibrs_victim_denorm_2015.victim_id JOIN nibrs_circumstances ON nibrs_circumstances.circumstances_id = nibrs_victim_circumstances.circumstances_id JOIN nibrs_ethnicity ON nibrs_ethnicity.ethnicity_id = nibrs_victim_new.ethnicity_id JOIN nibrs_victim_type ON nibrs_victim_new.victim_type_id = nibrs_victim_type.victim_type_id where nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET location_name = nibrs_location_type.location_name, location_code=nibrs_location_type.location_code from nibrs_location_type where nibrs_location_type.location_id = nibrs_victim_denorm_2015.location_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET property_id = nibrs_property_new.property_id, property_loss_id=nibrs_property_new.prop_loss_id from nibrs_property_new  where nibrs_property_new.incident_id = nibrs_victim_denorm_2015.incident_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET property_desc_id = nibrs_property_desc_new.prop_desc_id from nibrs_property_desc_new where nibrs_property_desc_new.property_id = nibrs_victim_denorm_2015.property_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET prop_desc_name = nibrs_prop_desc_type.prop_desc_name from nibrs_prop_desc_type where nibrs_prop_desc_type.prop_desc_id = nibrs_victim_denorm_2015.property_desc_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET bias_id = nibrs_bias_motivation.bias_id from nibrs_bias_motivation where nibrs_bias_motivation.offense_id = nibrs_victim_denorm_2015.offense_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET bias_name = nibrs_bias_list.bias_name from nibrs_bias_list where nibrs_victim_denorm_2015.bias_id = nibrs_bias_list.bias_id and nibrs_victim_denorm_2015.year = '2015';
UPDATE nibrs_victim_denorm_2015 SET offender_relationship = nibrs_relationship.relationship_name from nibrs_victim_offender_rel JOIN nibrs_relationship ON nibrs_relationship.relationship_id = nibrs_victim_offender_rel.relationship_id where nibrs_victim_denorm_2015.victim_id = nibrs_victim_offender_rel.victim_id and nibrs_victim_denorm_2015.year = '2015';


-- denorm offender
INSERT INTO nibrs_offender_denorm_2015 (incident_id, agency_id, year, incident_date, offender_id, age_id, age_num, sex_code, race_id, ethnicity) SELECT nibrs_offender_new.incident_id, nibrs_incident_new.agency_id, EXTRACT(YEAR FROM nibrs_incident_new.incident_date) as year, nibrs_incident_new.incident_date, nibrs_offender_new.offender_id, nibrs_offender_new.age_id, nibrs_offender_new.age_num::numeric, nibrs_offender_new.sex_code,nibrs_offender_new.race_id, nibrs_ethnicity.ethnicity_name from nibrs_offender_new  JOIN nibrs_incident_new on nibrs_incident_new.incident_id = nibrs_offender_new.incident_id  JOIN nibrs_ethnicity ON nibrs_ethnicity.ethnicity_id = nibrs_offender_new.ethnicity_id where nibrs_incident_new.incident_date >= to_timestamp('01-01-2015', 'MM-DD-YYYY');
UPDATE nibrs_offender_denorm_2015 SET state_id = ref_agency.state_id, county_id = ref_agency_county.county_id from ref_agency JOIN ref_agency_county ON ref_agency.agency_id = ref_agency_county.agency_id where nibrs_offender_denorm_2015.agency_id = ref_agency.agency_id and nibrs_offender_denorm_2015.year = '2015';
UPDATE nibrs_offender_denorm_2015 SET state_code = ref_state.state_code from ref_state where nibrs_offender_denorm_2015.state_id = ref_state.state_id and nibrs_offender_denorm_2015.year = '2015';
UPDATE nibrs_offender_denorm_2015 SET race_code = ref_race.race_code from ref_race where nibrs_offender_denorm_2015.race_id = ref_race.race_id and nibrs_offender_denorm_2015.year = '2015'; 
UPDATE nibrs_offender_denorm_2015 SET offense_type_id = nibrs_offense_new.offense_type_id, location_id = nibrs_offense_new.location_id from nibrs_offense_new where nibrs_offense_new.incident_id = nibrs_offender_denorm_2015.incident_id and nibrs_offender_denorm_2015.year = '2015';
UPDATE nibrs_offender_denorm_2015 SET offense_name = nibrs_offense_type.offense_name from nibrs_offense_type where nibrs_offense_type.offense_type_id = nibrs_offender_denorm_2015.offense_type_id and nibrs_offender_denorm_2015.year = '2015';
UPDATE nibrs_offender_denorm_2015 SET location_name = nibrs_location_type.location_name, location_code=nibrs_location_type.location_code from nibrs_location_type where nibrs_location_type.location_id = nibrs_offender_denorm_2015.location_id and nibrs_offender_denorm_2015.year = '2015';
UPDATE nibrs_offender_denorm_2015 SET property_id = nibrs_property_new.property_id, property_loss_id=nibrs_property_new.prop_loss_id from nibrs_property_new where nibrs_property_new.incident_id = nibrs_offender_denorm_2015.incident_id;
UPDATE nibrs_offender_denorm_2015 SET property_desc_id = nibrs_property_desc_new.prop_desc_id from nibrs_property_desc_new where nibrs_property_desc_new.property_id = nibrs_offender_denorm_2015.property_id;
UPDATE nibrs_offender_denorm_2015 SET offense_id = nibrs_offense_new.offense_id from nibrs_offense_new where nibrs_offender_denorm_2015.incident_id = nibrs_offense_new.incident_id and nibrs_offender_denorm_2015.year = '2015';
UPDATE nibrs_offender_denorm_2015 SET bias_id = nibrs_bias_motivation.bias_id from nibrs_bias_motivation where nibrs_bias_motivation.offense_id = nibrs_offender_denorm_2015.offense_id and nibrs_offender_denorm_2015.year = '2015';
UPDATE nibrs_offender_denorm_2015 SET bias_name = nibrs_bias_list.bias_name from nibrs_bias_list where nibrs_offender_denorm_2015.bias_id = nibrs_bias_list.bias_id and nibrs_offender_denorm_2015.year = '2015';

-- denorm offenses
INSERT INTO nibrs_offense_denorm_2015 (incident_id, agency_id, year, incident_date, offense_id, method_entry_code, num_premises_entered, location_id, offense_type_id, attempt_complete_flag) SELECT nibrs_offense_new.incident_id, nibrs_incident_new.agency_id, EXTRACT(YEAR FROM nibrs_incident_new.incident_date) as year, nibrs_incident_new.incident_date, nibrs_offense_new.offense_id, nibrs_offense_new.method_entry_code, nibrs_offense_new.num_premises_entered, nibrs_offense_new.location_id, nibrs_offense_new.offense_type_id, nibrs_offense_new.attempt_complete_flag from nibrs_offense_new  JOIN nibrs_incident_new on nibrs_incident_new.incident_id = nibrs_offense_new.incident_id where nibrs_incident_new.incident_date >= to_timestamp('01-01-2015', 'MM-DD-YYYY');
UPDATE nibrs_offense_denorm_2015 SET state_id = ref_agency.state_id, county_id = ref_agency_county.county_id from ref_agency JOIN ref_agency_county ON ref_agency.agency_id = ref_agency_county.agency_id where nibrs_offense_denorm_2015.agency_id = ref_agency.agency_id and nibrs_offense_denorm_2015.year = '2015';
UPDATE nibrs_offense_denorm_2015 SET state_code = ref_state.state_code from ref_state where nibrs_offense_denorm_2015.state_id = ref_state.state_id and nibrs_offense_denorm_2015.year = '2015';
UPDATE nibrs_offense_denorm_2015 SET location_name = nibrs_location_type.location_name, location_code=nibrs_location_type.location_code from nibrs_location_type where nibrs_location_type.location_id = nibrs_offense_denorm_2015.location_id and nibrs_offense_denorm_2015.year = '2015';
UPDATE nibrs_offense_denorm_2015 SET offense_name = nibrs_offense_type.offense_name from nibrs_offense_type where nibrs_offense_type.offense_type_id = nibrs_offense_denorm_2015.offense_type_id and nibrs_offense_denorm_2015.year = '2015';
UPDATE nibrs_offense_denorm_2015 SET weapon_id = nibrs_weapon.weapon_id from nibrs_weapon where nibrs_weapon.offense_id = nibrs_offense_denorm_2015.offense_id and nibrs_offense_denorm_2015.year = '2015';
UPDATE nibrs_offense_denorm_2015 SET weapon_name = nibrs_weapon_type.weapon_name from nibrs_weapon_type where nibrs_weapon_type.weapon_id = nibrs_offense_denorm_2015.weapon_id and nibrs_offense_denorm_2015.year = '2015';
UPDATE nibrs_offense_denorm_2015 SET bias_name = nibrs_bias_list.bias_name, suspected_using = nibrs_using_list.suspect_using_name from nibrs_bias_motivation JOIN nibrs_bias_list ON (nibrs_bias_motivation.bias_id = nibrs_bias_list.bias_id) JOIN nibrs_suspect_using ON (nibrs_suspect_using.offense_id =  nibrs_bias_motivation.offense_id) JOIN nibrs_using_list ON (nibrs_using_list.suspect_using_id = nibrs_suspect_using.suspect_using_id) where nibrs_offense_denorm_2015.offense_id = nibrs_bias_motivation.offense_id  and nibrs_offense_denorm_2015.year = '2015';


-- denorm arrestees 
INSERT INTO nibrs_arrestee_denorm_2015 (incident_id,arrest_type_id, agency_id, year, incident_date, arrestee_id, age_id, age_num, sex_code, race_id, arrest_date, resident_status, under_18_disposition_code, clearance_ind) SELECT nibrs_arrestee_new.incident_id, nibrs_arrestee_new.arrest_type_id, nibrs_incident_new.agency_id, EXTRACT(YEAR FROM nibrs_incident_new.incident_date) as year, nibrs_incident_new.incident_date, nibrs_arrestee_new.arrestee_id, nibrs_arrestee_new.age_id, nibrs_arrestee_new.age_num::numeric, nibrs_arrestee_new.sex_code,nibrs_arrestee_new.race_id, nibrs_arrestee_new.arrest_date, nibrs_arrestee_new.resident_code, nibrs_arrestee_new.under_18_disposition_code, nibrs_arrestee_new.clearance_ind from nibrs_arrestee_new JOIN nibrs_incident_new on nibrs_incident_new.incident_id = nibrs_arrestee_new.incident_id where nibrs_incident_new.incident_date >= to_timestamp('01-01-2015', 'MM-DD-YYYY');
UPDATE nibrs_arrestee_denorm_2015 SET race_code = ref_race.race_code from ref_race where nibrs_arrestee_denorm_2015.race_id = ref_race.race_id and nibrs_arrestee_denorm_2015.year = '2015'; 
UPDATE nibrs_arrestee_denorm_2015 SET arrest_type_name = nibrs_arrest_type.arrest_type_name from nibrs_arrest_type where nibrs_arrestee_denorm_2015.arrest_type_id = nibrs_arrest_type.arrest_type_id and nibrs_arrestee_denorm_2015.year = '2015';
UPDATE nibrs_arrestee_denorm_2015 SET arrest_type_code = nibrs_arrest_type.arrest_type_code, ethnicity = nibrs_ethnicity.ethnicity_name from nibrs_arrestee_new JOIN nibrs_arrest_type ON (nibrs_arrestee_new.arrest_type_id = nibrs_arrest_type.arrest_type_id) JOIN nibrs_ethnicity ON nibrs_ethnicity.ethnicity_id = nibrs_arrestee_new.ethnicity_id where nibrs_arrestee_denorm_2015.year = '2015';
UPDATE nibrs_arrestee_denorm_2015 SET arrest_type_code = nibrs_arrest_type.arrest_type_code, ethnicity = nibrs_ethnicity.ethnicity_name from nibrs_arrestee_new JOIN nibrs_arrest_type ON (nibrs_arrestee_new.arrest_type_id = nibrs_arrest_type.arrest_type_id) JOIN nibrs_ethnicity ON nibrs_ethnicity.ethnicity_id = nibrs_arrestee_new.ethnicity_id where nibrs_arrestee_denorm_2015.arrestee_id = nibrs_arrestee_new.arrestee_id and nibrs_arrestee_denorm_2015.year = '2015';

-- denorm property
INSERT INTO nibrs_property_denorm_2015 (incident_id, agency_id, year, incident_date, property_id, stolen_count) SELECT nibrs_incident_new.incident_id, nibrs_incident_new.agency_id, EXTRACT(YEAR FROM nibrs_incident_new.incident_date) as year, nibrs_incident_new.incident_date, nibrs_property_new.property_id, nibrs_property_new.stolen_count from nibrs_property_new JOIN nibrs_incident_new on nibrs_incident_new.incident_id = nibrs_property_new.incident_id and nibrs_incident_new.incident_date >= to_timestamp('01-01-2015', 'MM-DD-YYYY');
UPDATE nibrs_property_denorm_2015 SET state_id = ref_agency.state_id, ori = ref_agency.ori from ref_agency where nibrs_property_denorm_2015.agency_id = ref_agency.agency_id and nibrs_property_denorm_2015.year = '2015';
UPDATE nibrs_property_denorm_2015 SET state_code = ref_state.state_code from ref_state where nibrs_property_denorm_2015.state_id = ref_state.state_id and nibrs_property_denorm_2015.year = '2015';
UPDATE nibrs_property_denorm_2015 SET date_recovered = nibrs_property_desc_new.date_recovered, property_value = nibrs_property_desc_new.property_value, property_desc_id = nibrs_property_desc_new.prop_desc_id from nibrs_property_desc_new where nibrs_property_desc_new.property_id = nibrs_property_denorm_2015.property_id and nibrs_property_denorm_2015.year = '2015';
UPDATE nibrs_property_denorm_2015 SET prop_desc_name = nibrs_prop_desc_type.prop_desc_name from nibrs_prop_desc_type where nibrs_prop_desc_type.prop_desc_id = nibrs_property_denorm_2015.property_desc_id and nibrs_property_denorm_2015.year = '2015';
UPDATE nibrs_property_denorm_2015 SET est_drug_qty = nibrs_suspected_drug.est_drug_qty, drug_measure_code = nibrs_drug_measure_type.drug_measure_code, drug_measure_name = nibrs_drug_measure_type.drug_measure_name from nibrs_property_new JOIN nibrs_suspected_drug ON (nibrs_suspected_drug.property_id = nibrs_property_new.property_id) JOIN nibrs_drug_measure_type ON (nibrs_suspected_drug.drug_measure_type_id = nibrs_drug_measure_type.drug_measure_type_id) where nibrs_property_denorm_2015.property_id = nibrs_property_new.property_id and nibrs_property_denorm_2015.year = '2015';

-----

-- Update NIBRS aggregations.

-- 


---------
-- CARGO THEFT
---------
SET work_mem='2GB'; -- Go Super Saiyan.

-- Generates CT stats.
drop materialized view IF EXISTS ct_counts_states;
create materialized view ct_counts_states as select  count(incident_id), sum(stolen_value) as stolen_value, sum(recovered_value) as recovered_value,  year, state_id,  location_name,  offense_name, victim_type_name, prop_desc_name
from ( 
    SELECT DISTINCT(ct_incident.incident_id), 
    state_id, 
    location_name,
    offense_name,
    victim_type_name,
    ct_property.stolen_value::numeric as stolen_value,
    ct_property.recovered_value::numeric as recovered_value,
    prop_desc_name,
    EXTRACT(YEAR FROM ct_incident.incident_date) as year 
    from ct_incident 
    LEFT OUTER JOIN ct_offense ON ct_incident.incident_id = ct_offense.incident_id 
    LEFT OUTER JOIN nibrs_offense_type ON ct_offense.offense_type_id = nibrs_offense_type.offense_type_id 
    LEFT OUTER JOIN nibrs_location_type ON ct_offense.location_id = nibrs_location_type.location_id
    LEFT OUTER JOIN ct_victim ON ct_victim.incident_id = ct_incident.incident_id 
    LEFT OUTER JOIN nibrs_victim_type ON ct_victim.victim_type_id = nibrs_victim_type.victim_type_id

    LEFT OUTER JOIN ct_property ON ct_incident.incident_id = ct_property.incident_id
    LEFT OUTER JOIN nibrs_prop_desc_type ON nibrs_prop_desc_type.prop_desc_id = ct_property.prop_desc_id

    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = ct_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, prop_desc_name),
    (year, location_name),
    (year, victim_type_name),
    (year, offense_name),
    
    (year, state_id, prop_desc_name),
    (year, state_id, location_name),
    (year, state_id, victim_type_name),
    (year, state_id, offense_name)
);

drop materialized view IF EXISTS  ct_counts_ori;
create materialized view ct_counts_ori as select  count(incident_id), sum(stolen_value) as stolen_value, sum(recovered_value) as recovered_value,  year, ori,  location_name,  offense_name, victim_type_name, prop_desc_name
from ( 
    SELECT DISTINCT(ct_incident.incident_id), 
    ref_agency.ori, 
    location_name,
    offense_name,
    victim_type_name,
    ct_property.stolen_value::numeric as stolen_value,
    ct_property.recovered_value::numeric as recovered_value,
    prop_desc_name,
    EXTRACT(YEAR FROM ct_incident.incident_date) as year 
    from ct_incident 
    LEFT OUTER JOIN ct_offense ON ct_incident.incident_id = ct_offense.incident_id 
    LEFT OUTER JOIN nibrs_offense_type ON ct_offense.offense_type_id = nibrs_offense_type.offense_type_id 
    LEFT OUTER JOIN nibrs_location_type ON ct_offense.location_id = nibrs_location_type.location_id
    LEFT OUTER JOIN ct_victim ON ct_victim.incident_id = ct_incident.incident_id 
    LEFT OUTER JOIN nibrs_victim_type ON ct_victim.victim_type_id = nibrs_victim_type.victim_type_id

    LEFT OUTER JOIN ct_property ON ct_incident.incident_id = ct_property.incident_id
    LEFT OUTER JOIN nibrs_prop_desc_type ON nibrs_prop_desc_type.prop_desc_id = ct_property.prop_desc_id

    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = ct_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, ori, prop_desc_name),
    (year, ori, location_name),
    (year, ori, victim_type_name),
    (year, ori, offense_name)
);

SET work_mem='2GB'; -- Go Super Saiyan.

-- Generates CT stats.
create materialized view offense_ct_counts_states_new as select  count(incident_id), sum(stolen_value) as stolen_value, sum(recovered_value) as recovered_value,  year, state_id,  location_name,  offense_name, victim_type_name, prop_desc_name
from ( 
    SELECT DISTINCT(ct_incident.incident_id), 
    state_id, 
    location_name,
    offense_name,
    victim_type_name,
    ct_property.stolen_value::numeric as stolen_value,
    ct_property.recovered_value::numeric as recovered_value,
    prop_desc_name,
    EXTRACT(YEAR FROM ct_incident.incident_date) as year 
    from ct_incident 
    LEFT OUTER JOIN ct_offense ON ct_incident.incident_id = ct_offense.incident_id 
    LEFT OUTER JOIN nibrs_offense_type ON ct_offense.offense_type_id = nibrs_offense_type.offense_type_id 
    LEFT OUTER JOIN nibrs_location_type ON ct_offense.location_id = nibrs_location_type.location_id
    LEFT OUTER JOIN ct_victim ON ct_victim.incident_id = ct_incident.incident_id 
    LEFT OUTER JOIN nibrs_victim_type ON ct_victim.victim_type_id = nibrs_victim_type.victim_type_id

    LEFT OUTER JOIN ct_property ON ct_incident.incident_id = ct_property.incident_id
    LEFT OUTER JOIN nibrs_prop_desc_type ON nibrs_prop_desc_type.prop_desc_id = ct_property.prop_desc_id
    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = ct_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, offense_name, prop_desc_name),
    (year, offense_name, location_name),
    (year, offense_name, victim_type_name),

    (year, state_id, offense_name, prop_desc_name),
    (year, state_id, offense_name, location_name),
    (year, state_id, offense_name, victim_type_name)
);

create materialized view offense_ct_counts_ori_new as select  count(incident_id), sum(stolen_value) as stolen_value, sum(recovered_value) as recovered_value,  year, ori,  location_name,  offense_name, victim_type_name, prop_desc_name
from ( 
    SELECT DISTINCT(ct_incident.incident_id), 
    ref_agency.ori, 
    location_name,
    offense_name,
    victim_type_name,
    ct_property.stolen_value::numeric as stolen_value,
    ct_property.recovered_value::numeric as recovered_value,
    prop_desc_name,
    EXTRACT(YEAR FROM ct_incident.incident_date) as year 
    from ct_incident 
    LEFT OUTER JOIN ct_offense ON ct_incident.incident_id = ct_offense.incident_id 
    LEFT OUTER JOIN nibrs_offense_type ON ct_offense.offense_type_id = nibrs_offense_type.offense_type_id 
    LEFT OUTER JOIN nibrs_location_type ON ct_offense.location_id = nibrs_location_type.location_id
    LEFT OUTER JOIN ct_victim ON ct_victim.incident_id = ct_incident.incident_id 
    LEFT OUTER JOIN nibrs_victim_type ON ct_victim.victim_type_id = nibrs_victim_type.victim_type_id
    LEFT OUTER JOIN ct_property ON ct_incident.incident_id = ct_property.incident_id
    LEFT OUTER JOIN nibrs_prop_desc_type ON nibrs_prop_desc_type.prop_desc_id = ct_property.prop_desc_id
    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = ct_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, ori, offense_name, prop_desc_name),
    (year, ori, offense_name, location_name),
    (year, ori, offense_name, victim_type_name)
);



drop materialized view  IF EXISTS offense_ct_counts_states;
drop materialized view  IF EXISTS offense_ct_counts_ori;
DROP INDEX IF EXISTS ct_counts_state_id_idx;
DROP INDEX IF EXISTS offense_ct_counts_state_id_idx;
DROP INDEX IF EXISTS ct_counts_ori_idx;
DROP INDEX IF EXISTS offense_ct_counts_ori_idx;

ALTER view offense_ct_counts_states_new RENAME TO offense_ct_counts_states; 
ALTER view offense_ct_counts_ori_new RENAME TO offense_ct_counts_ori; 
CREATE INDEX ct_counts_state_id_idx ON ct_counts_states (state_id, year);
CREATE INDEX offense_ct_counts_state_id_idx ON offense_ct_counts_states (state_id, year);
CREATE INDEX ct_counts_ori_idx ON ct_counts_ori (ori, year);
CREATE INDEX offense_ct_counts_ori_idx ON offense_ct_counts_ori (ori, year);


--------------
-- HATE CRIME
--------------
SET work_mem='2GB'; -- Go Super Saiyan.

-- Generates Hate Crime stats.

create materialized view hc_counts_states_new as select count(incident_id), bias_name, year, state_id 
from ( SELECT DISTINCT(hc_incident.incident_id), bias_name, state_id, EXTRACT(YEAR FROM hc_incident.incident_date) as year from hc_incident 
    LEFT OUTER JOIN hc_offense ON hc_incident.incident_id = hc_offense.incident_id 
    LEFT OUTER JOIN hc_bias_motivation ON hc_offense.offense_id = hc_bias_motivation.offense_id 
    LEFT OUTER JOIN nibrs_offense_type ON nibrs_offense_type.offense_type_id = hc_offense.offense_type_id 
    LEFT OUTER JOIN nibrs_bias_list ON nibrs_bias_list.bias_id = hc_bias_motivation.bias_id 
    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = hc_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, bias_name),
    (year, state_id, bias_name)
);


create materialized view hc_counts_ori_new as select count(incident_id), ori, bias_name, year  
from ( SELECT DISTINCT(hc_incident.incident_id), ref_agency.ori, bias_name, EXTRACT(YEAR FROM hc_incident.incident_date) as year from hc_incident 
    LEFT OUTER JOIN hc_offense ON hc_incident.incident_id = hc_offense.incident_id 
    LEFT OUTER JOIN hc_bias_motivation ON hc_offense.offense_id = hc_bias_motivation.offense_id 
    LEFT OUTER JOIN nibrs_offense_type ON nibrs_offense_type.offense_type_id = hc_offense.offense_type_id 
    LEFT OUTER JOIN nibrs_bias_list ON nibrs_bias_list.bias_id = hc_bias_motivation.bias_id 
    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = hc_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, ori, bias_name)
);


create materialized view offense_hc_counts_states_new as select count(incident_id), offense_name, bias_name, year, state_id 
from ( SELECT DISTINCT(hc_incident.incident_id), bias_name, offense_name, state_id, EXTRACT(YEAR FROM hc_incident.incident_date) as year from hc_incident 
    LEFT OUTER JOIN hc_offense ON hc_incident.incident_id = hc_offense.incident_id 
    LEFT OUTER JOIN hc_bias_motivation ON hc_offense.offense_id = hc_bias_motivation.offense_id 
    LEFT OUTER JOIN nibrs_offense_type ON nibrs_offense_type.offense_type_id = hc_offense.offense_type_id 
    LEFT OUTER JOIN nibrs_bias_list ON nibrs_bias_list.bias_id = hc_bias_motivation.bias_id 
    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = hc_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, offense_name, bias_name),
    (year, state_id, offense_name, bias_name)
);


create materialized view offense_hc_counts_ori_new as select count(incident_id), ori, offense_name, bias_name, year  
from ( SELECT DISTINCT(hc_incident.incident_id), ref_agency.ori, bias_name, offense_name, EXTRACT(YEAR FROM hc_incident.incident_date) as year from hc_incident 
    LEFT OUTER JOIN hc_offense ON hc_incident.incident_id = hc_offense.incident_id 
    LEFT OUTER JOIN hc_bias_motivation ON hc_offense.offense_id = hc_bias_motivation.offense_id 
    LEFT OUTER JOIN nibrs_offense_type ON nibrs_offense_type.offense_type_id = hc_offense.offense_type_id 
    LEFT OUTER JOIN nibrs_bias_list ON nibrs_bias_list.bias_id = hc_bias_motivation.bias_id 
    LEFT OUTER JOIN ref_agency ON ref_agency.agency_id = hc_incident.agency_id
     ) as temp 
GROUP BY GROUPING SETS (
    (year, ori, offense_name, bias_name)
);


drop materialized view IF EXISTS hc_counts_states;
drop materialized view IF EXISTS offense_hc_counts_ori;
drop materialized view IF EXISTS offense_hc_counts_states;
drop materialized view IF EXISTS hc_counts_ori;

ALTER VIEW hc_counts_states_new RENAME TO hc_counts_states;
ALTER VIEW offense_hc_counts_ori_new RENAME TO offense_hc_counts_ori;
ALTER VIEW offense_hc_counts_states_new RENAME TO offense_hc_counts_states;
ALTER VIEW hc_counts_ori_new RENAME TO hc_counts_ori;

CREATE INDEX hc_counts_state_id_year_idx ON hc_counts_states (state_id, year);
CREATE INDEX offense_hc_counts_state_id_year_idx ON offense_hc_counts_states (state_id, year);
CREATE INDEX hc_counts_ori_year_idx ON hc_counts_ori (ori, year);
CREATE INDEX offense_hc_counts_ori_year_idx ON offense_hc_counts_ori (ori, year);


--------------
-- OFFENDERS
--------------

DO
$do$
DECLARE
   arr integer[] := array[2015];
   i integer;
BEGIN
   FOREACH i IN ARRAY arr
   LOOP
    SET work_mem='2GB';
    EXECUTE 'CREATE TABLE IF NOT EXISTS nibrs_offender_denorm_' || i::TEXT || ' () INHERITS (nibrs_offender_denorm)';
    RAISE NOTICE 'Dropping view for year: %', i;
    EXECUTE 'drop materialized view IF EXISTS offender_counts_' || i::TEXT || ' CASCADE';
    RAISE NOTICE 'Creating view for year: %', i;
    EXECUTE 'create materialized view offender_counts_' || i::TEXT || ' as select count(offender_id),ethnicity, prop_desc_name,offense_name, state_id, race_code,location_name, age_num, sex_code, ori  
    from ( 
        SELECT DISTINCT(offender_id), ethnicity, age_code, age_num,race_code,year,prop_desc_name,offense_name,location_name, sex_code, nibrs_offender_denorm_' || i::TEXT || '.state_id,ref_agency.ori from nibrs_offender_denorm_' || i::TEXT || ' 
        JOIN ref_agency ON ref_agency.agency_id = nibrs_offender_denorm_' || i::TEXT || '.agency_id 
        where year::integer = ' || i || ' 
        ) as temp
    GROUP BY GROUPING SETS (
        (year, race_code),
        (year, sex_code),
        (year, age_num),
        (year, location_name), 
        (year, offense_name),
        (year, prop_desc_name),
        (year, ethnicity),

        (year, state_id, race_code),
        (year, state_id, sex_code),
        (year, state_id, age_num),
        (year, state_id, location_name), 
        (year, state_id, offense_name),
        (year, state_id, prop_desc_name),
        (year, state_id, ethnicity),

        (year, ori, race_code),
        (year, ori, sex_code),
        (year, ori, age_num),
        (year, ori, location_name), 
        (year, ori, offense_name),
        (year, ori, prop_desc_name),
        (year, ori, ethnicity)
    );';
   END LOOP;
END
$do$;

drop materialized view  IF EXISTS offender_counts_states;
create materialized view offender_counts_states as 
    SELECT *, 2015 as year FROM offender_counts_2015 WHERE ori IS NULL UNION 
    SELECT *, 2014 as year FROM offender_counts_2014 WHERE ori IS NULL UNION 
    SELECT *, 2013 as year FROM offender_counts_2013 WHERE ori IS NULL  UNION
    SELECT *, 2012 as year FROM offender_counts_2012 WHERE ori IS NULL  UNION 
    SELECT *, 2011 as year FROM offender_counts_2011 WHERE ori IS NULL  UNION 
    SELECT *, 2010 as year FROM offender_counts_2010 WHERE ori IS NULL  UNION
    SELECT *, 2009 as year FROM offender_counts_2009 WHERE ori IS NULL  UNION 
    SELECT *, 2008 as year FROM offender_counts_2008 WHERE ori IS NULL  UNION 
    SELECT *, 2007 as year FROM offender_counts_2007 WHERE ori IS NULL  UNION
    SELECT *, 2006 as year FROM offender_counts_2006 WHERE ori IS NULL  UNION 
    SELECT *, 2005 as year FROM offender_counts_2005 WHERE ori IS NULL  UNION 
    SELECT *, 2004 as year FROM offender_counts_2004 WHERE ori IS NULL  UNION
    SELECT *, 2003 as year FROM offender_counts_2003 WHERE ori IS NULL  UNION 
    SELECT *, 2002 as year FROM offender_counts_2002 WHERE ori IS NULL  UNION 
    SELECT *, 2001 as year FROM offender_counts_2001 WHERE ori IS NULL  UNION
    SELECT *, 2000 as year FROM offender_counts_2000 WHERE ori IS NULL  UNION 
    SELECT *, 1999 as year FROM offender_counts_1999 WHERE ori IS NULL  UNION 
    SELECT *, 1998 as year FROM offender_counts_1998 WHERE ori IS NULL  UNION
    SELECT *, 1997 as year FROM offender_counts_1997 WHERE ori IS NULL  UNION 
    SELECT *, 1996 as year FROM offender_counts_1996 WHERE ori IS NULL  UNION 
    SELECT *, 1995 as year FROM offender_counts_1995 WHERE ori IS NULL  UNION
    SELECT *, 1994 as year FROM offender_counts_1994 WHERE ori IS NULL  UNION 
    SELECT *, 1993 as year FROM offender_counts_1993 WHERE ori IS NULL  UNION 
    SELECT *, 1992 as year FROM offender_counts_1992 WHERE ori IS NULL  UNION
    SELECT *, 1991 as year FROM offender_counts_1991 WHERE ori IS NULL ;

drop materialized view  IF EXISTS offender_counts_ori;
create materialized view offender_counts_ori as 
    SELECT *, 2015 as year FROM offender_counts_2015 WHERE ori IS NOT NULL UNION 
    SELECT *, 2014 as year FROM offender_counts_2014 WHERE ori IS NOT NULL UNION 
    SELECT *, 2013 as year FROM offender_counts_2013 WHERE ori IS NOT NULL  UNION
    SELECT *, 2012 as year FROM offender_counts_2012 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2011 as year FROM offender_counts_2011 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2010 as year FROM offender_counts_2010 WHERE ori IS NOT NULL  UNION
    SELECT *, 2009 as year FROM offender_counts_2009 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2008 as year FROM offender_counts_2008 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2007 as year FROM offender_counts_2007 WHERE ori IS NOT NULL  UNION
    SELECT *, 2006 as year FROM offender_counts_2006 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2005 as year FROM offender_counts_2005 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2004 as year FROM offender_counts_2004 WHERE ori IS NOT NULL  UNION
    SELECT *, 2003 as year FROM offender_counts_2003 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2002 as year FROM offender_counts_2002 WHERE ori IS NOT NULL  UNION 
    SELECT *, 2001 as year FROM offender_counts_2001 WHERE ori IS NOT NULL  UNION
    SELECT *, 2000 as year FROM offender_counts_2000 WHERE ori IS NOT NULL  UNION 
    SELECT *, 1999 as year FROM offender_counts_1999 WHERE ori IS NOT NULL  UNION 
    SELECT *, 1998 as year FROM offender_counts_1998 WHERE ori IS NOT NULL  UNION
    SELECT *, 1997 as year FROM offender_counts_1997 WHERE ori IS NOT NULL  UNION 
    SELECT *, 1996 as year FROM offender_counts_1996 WHERE ori IS NOT NULL  UNION 
    SELECT *, 1995 as year FROM offender_counts_1995 WHERE ori IS NOT NULL  UNION
    SELECT *, 1994 as year FROM offender_counts_1994 WHERE ori IS NOT NULL  UNION 
    SELECT *, 1993 as year FROM offender_counts_1993 WHERE ori IS NOT NULL  UNION 
    SELECT *, 1992 as year FROM offender_counts_1992 WHERE ori IS NOT NULL  UNION
    SELECT *, 1991 as year FROM offender_counts_1991 WHERE ori IS NOT NULL ;

CREATE INDEX offender_counts_state_year_id_idx ON offender_count_states (state_id, year);
CREATE INDEX offender_counts_ori_year_idx ON offender_counts_ori (ori, year);

--------------
-- OFFENDER - OFFENSES
--------------
DO
$do$
DECLARE
   arr integer[] := array[2015];
   i integer;
BEGIN
   FOREACH i IN ARRAY arr
   LOOP
    SET work_mem='2GB';
    RAISE NOTICE 'Dropping view for year: %', i;
    EXECUTE 'drop materialized view  IF EXISTS offense_offender_counts_' || i::TEXT || ' CASCADE';
    RAISE NOTICE 'Creating view for year: %', i;
    EXECUTE 'create materialized view offense_offender_counts_' || i::TEXT || ' as select count(offender_id), ori,ethnicity,offense_name, state_id, race_code, age_num, sex_code 
    from (
        SELECT DISTINCT(offender_id), ref_agency.ori, ethnicity, age_num,race_code,year,offense_name, sex_code, nibrs_offender_denorm_' || i::TEXT || '.state_id from nibrs_offender_denorm_' || i::TEXT || ' 
        JOIN ref_agency ON ref_agency.agency_id = nibrs_offender_denorm_' || i::TEXT || '.agency_id 
        where year::integer = ' || i || ' and nibrs_offender_denorm_' || i::TEXT || '.state_id is not null
    ) as temp 
    GROUP BY GROUPING SETS (
        (year, offense_name, race_code),
        (year, offense_name, sex_code),
        (year, offense_name, age_num),
        (year, offense_name, ethnicity),
        (year, state_id, offense_name, race_code),
        (year, state_id, offense_name, sex_code),
        (year, state_id, offense_name, age_num),
        (year, state_id, offense_name, ethnicity),
        (year, ori, offense_name, race_code),
        (year, ori, offense_name, sex_code),
        (year, ori, offense_name, age_num),
        (year, ori, offense_name, ethnicity)
    );';
   END LOOP;
END
$do$;

drop materialized view IF EXISTS  offense_offender_counts_states;
create materialized view offense_offender_counts_states as 
    SELECT *,2015 as year FROM offense_offender_counts_2015 WHERE ori IS NULL  UNION
    SELECT *,2014 as year FROM offense_offender_counts_2014 WHERE ori IS NULL  UNION 
    SELECT *,2013 as year FROM offense_offender_counts_2013 WHERE ori IS NULL  UNION
    SELECT *,2012 as year FROM offense_offender_counts_2012 WHERE ori IS NULL  UNION 
    SELECT *,2011 as year FROM offense_offender_counts_2011 WHERE ori IS NULL  UNION 
    SELECT *,2010 as year FROM offense_offender_counts_2010 WHERE ori IS NULL  UNION
    SELECT *,2009 as year FROM offense_offender_counts_2009 WHERE ori IS NULL  UNION 
    SELECT *,2008 as year FROM offense_offender_counts_2008 WHERE ori IS NULL  UNION 
    SELECT *,2007 as year FROM offense_offender_counts_2007 WHERE ori IS NULL  UNION
    SELECT *,2006 as year FROM offense_offender_counts_2006 WHERE ori IS NULL  UNION 
    SELECT *,2005 as year FROM offense_offender_counts_2005 WHERE ori IS NULL  UNION 
    SELECT *,2004 as year FROM offense_offender_counts_2004 WHERE ori IS NULL  UNION
    SELECT *,2003 as year FROM offense_offender_counts_2003 WHERE ori IS NULL  UNION 
    SELECT *,2002 as year FROM offense_offender_counts_2002 WHERE ori IS NULL  UNION 
    SELECT *,2001 as year FROM offense_offender_counts_2001 WHERE ori IS NULL  UNION
    SELECT *,2000 as year FROM offense_offender_counts_2000 WHERE ori IS NULL  UNION 
    SELECT *,1999 as year FROM offense_offender_counts_1999 WHERE ori IS NULL  UNION 
    SELECT *,1998 as year FROM offense_offender_counts_1998 WHERE ori IS NULL  UNION
    SELECT *,1997 as year FROM offense_offender_counts_1997 WHERE ori IS NULL  UNION 
    SELECT *,1996 as year FROM offense_offender_counts_1996 WHERE ori IS NULL  UNION 
    SELECT *,1995 as year FROM offense_offender_counts_1995 WHERE ori IS NULL  UNION
    SELECT *,1994 as year FROM offense_offender_counts_1994 WHERE ori IS NULL  UNION 
    SELECT *,1993 as year FROM offense_offender_counts_1993 WHERE ori IS NULL  UNION 
    SELECT *,1992 as year FROM offense_offender_counts_1992 WHERE ori IS NULL  UNION
    SELECT *,1991 as year FROM offense_offender_counts_1991 WHERE ori IS NULL ;


drop materialized view IF EXISTS  offense_offender_counts_ori;
create materialized view offense_offender_counts_ori as 
    SELECT *,2014 as year FROM offense_offender_counts_2015 WHERE ori IS NOT NULL  UNION 
    SELECT *,2014 as year FROM offense_offender_counts_2014 WHERE ori IS NOT NULL  UNION 
    SELECT *,2013 as year FROM offense_offender_counts_2013 WHERE ori IS NOT NULL  UNION
    SELECT *,2012 as year FROM offense_offender_counts_2012 WHERE ori IS NOT NULL  UNION 
    SELECT *,2011 as year FROM offense_offender_counts_2011 WHERE ori IS NOT NULL  UNION 
    SELECT *,2010 as year FROM offense_offender_counts_2010 WHERE ori IS NOT NULL  UNION
    SELECT *,2009 as year FROM offense_offender_counts_2009 WHERE ori IS NOT NULL  UNION 
    SELECT *,2008 as year FROM offense_offender_counts_2008 WHERE ori IS NOT NULL  UNION 
    SELECT *,2007 as year FROM offense_offender_counts_2007 WHERE ori IS NOT NULL  UNION
    SELECT *,2006 as year FROM offense_offender_counts_2006 WHERE ori IS NOT NULL  UNION 
    SELECT *,2005 as year FROM offense_offender_counts_2005 WHERE ori IS NOT NULL  UNION 
    SELECT *,2004 as year FROM offense_offender_counts_2004 WHERE ori IS NOT NULL  UNION
    SELECT *,2003 as year FROM offense_offender_counts_2003 WHERE ori IS NOT NULL  UNION 
    SELECT *,2002 as year FROM offense_offender_counts_2002 WHERE ori IS NOT NULL  UNION 
    SELECT *,2001 as year FROM offense_offender_counts_2001 WHERE ori IS NOT NULL  UNION
    SELECT *,2000 as year FROM offense_offender_counts_2000 WHERE ori IS NOT NULL  UNION 
    SELECT *,1999 as year FROM offense_offender_counts_1999 WHERE ori IS NOT NULL  UNION 
    SELECT *,1998 as year FROM offense_offender_counts_1998 WHERE ori IS NOT NULL  UNION
    SELECT *,1997 as year FROM offense_offender_counts_1997 WHERE ori IS NOT NULL  UNION 
    SELECT *,1996 as year FROM offense_offender_counts_1996 WHERE ori IS NOT NULL  UNION 
    SELECT *,1995 as year FROM offense_offender_counts_1995 WHERE ori IS NOT NULL  UNION
    SELECT *,1994 as year FROM offense_offender_counts_1994 WHERE ori IS NOT NULL  UNION 
    SELECT *,1993 as year FROM offense_offender_counts_1993 WHERE ori IS NOT NULL  UNION 
    SELECT *,1992 as year FROM offense_offender_counts_1992 WHERE ori IS NOT NULL  UNION
    SELECT *,1991 as year FROM offense_offender_counts_1991 WHERE ori IS NOT NULL ;

DROP INDEX offense_offender_counts_state_id_idx;
DROP INDEX offense_offender_counts_ori_idx;
CREATE INDEX offense_offender_counts_state_id_idx ON offense_offender_counts_states (state_id, year, offense_name);
CREATE INDEX offense_offender_counts_ori_idx ON offense_offender_counts_ori (ori, year, offense_name);

--------------
-- VICTIMS
--------------
DO
$do$
DECLARE
   arr integer[] := array[2015];
   i integer;
BEGIN
   FOREACH i IN ARRAY arr
   LOOP
    SET work_mem='2GB';
    -- necessary when run on test DB slice
    EXECUTE 'CREATE TABLE IF NOT EXISTS nibrs_victim_denorm_' || i::TEXT || ' () INHERITS (nibrs_victim_denorm)';
    RAISE NOTICE 'Dropping view for year: %', i;
    EXECUTE 'drop materialized view IF EXISTS victim_counts_' || i::TEXT || ' CASCADE';
    RAISE NOTICE 'Creating view for year: %', i;
    EXECUTE 'create materialized view victim_counts_' || i::TEXT || ' as select count(victim_id), ori,resident_status_code,offender_relationship,circumstance_name,ethnicity,offense_name, state_id, race_code, age_num, sex_code,location_name ,prop_desc_name
    from ( 
        SELECT DISTINCT(victim_id), ref_agency.ori, ethnicity, age_num,race_code,year,resident_status_code,offender_relationship,circumstance_name,offense_name, sex_code, nibrs_victim_denorm_' || i::TEXT || '.state_id,location_name,prop_desc_name 
        from nibrs_victim_denorm_' || i::TEXT || '  
        JOIN ref_agency ON ref_agency.agency_id = nibrs_victim_denorm_' || i::TEXT || '.agency_id
        where year::integer = ' || i || '  and nibrs_victim_denorm_' || i::TEXT || '.state_id is not null
        ) as temp
    GROUP BY GROUPING SETS (
        (year, race_code),
        (year, sex_code),
        (year, age_num),
        (year, location_name), 
        (year, offense_name),
        (year, prop_desc_name),
        (year, resident_status_code), 
        (year, offender_relationship),
        (year, circumstance_name),
        (year, ethnicity),

        (year, state_id, race_code),
        (year, state_id, sex_code),
        (year, state_id, age_num),
        (year, state_id, location_name), 
        (year, state_id, offense_name),
        (year, state_id, prop_desc_name),
        (year, state_id, resident_status_code), 
        (year, state_id, offender_relationship),
        (year, state_id, circumstance_name),
        (year, state_id, ethnicity),

        (year, ori, race_code),
        (year, ori, sex_code),
        (year, ori, age_num),
        (year, ori, location_name), 
        (year, ori, offense_name),
        (year, ori, prop_desc_name),
        (year, ori, resident_status_code), 
        (year, ori, offender_relationship),
        (year, ori, circumstance_name),
        (year, ori, ethnicity)
    );';
   END LOOP;
END
$do$;

drop materialized view IF EXISTS victim_counts_states CASCADE;
create materialized view victim_counts_states as 
    SELECT *, 2015 as year FROM victim_counts_2014 WHERE ori IS NULL UNION  
    SELECT *, 2014 as year FROM victim_counts_2014 WHERE ori IS NULL UNION 
    SELECT *, 2013 as year FROM victim_counts_2013 WHERE ori IS NULL UNION
    SELECT *, 2012 as year FROM victim_counts_2012 WHERE ori IS NULL UNION 
    SELECT *, 2011 as year FROM victim_counts_2011 WHERE ori IS NULL UNION 
    SELECT *, 2010 as year FROM victim_counts_2010 WHERE ori IS NULL UNION
    SELECT *, 2009 as year FROM victim_counts_2009 WHERE ori IS NULL UNION 
    SELECT *, 2008 as year FROM victim_counts_2008 WHERE ori IS NULL UNION 
    SELECT *, 2007 as year FROM victim_counts_2007 WHERE ori IS NULL UNION
    SELECT *, 2006 as year FROM victim_counts_2006 WHERE ori IS NULL UNION 
    SELECT *, 2005 as year FROM victim_counts_2005 WHERE ori IS NULL UNION 
    SELECT *, 2004 as year FROM victim_counts_2004 WHERE ori IS NULL UNION
    SELECT *, 2003 as year FROM victim_counts_2003 WHERE ori IS NULL UNION 
    SELECT *, 2002 as year FROM victim_counts_2002 WHERE ori IS NULL UNION 
    SELECT *, 2001 as year FROM victim_counts_2001 WHERE ori IS NULL UNION
    SELECT *, 2000 as year FROM victim_counts_2000 WHERE ori IS NULL UNION 
    SELECT *, 1999 as year FROM victim_counts_1999 WHERE ori IS NULL UNION 
    SELECT *, 1998 as year FROM victim_counts_1998 WHERE ori IS NULL UNION
    SELECT *, 1997 as year FROM victim_counts_1997 WHERE ori IS NULL UNION 
    SELECT *, 1996 as year FROM victim_counts_1996 WHERE ori IS NULL UNION 
    SELECT *, 1995 as year FROM victim_counts_1995 WHERE ori IS NULL UNION
    SELECT *, 1994 as year FROM victim_counts_1994 WHERE ori IS NULL UNION 
    SELECT *, 1993 as year FROM victim_counts_1993 WHERE ori IS NULL UNION 
    SELECT *, 1992 as year FROM victim_counts_1992 WHERE ori IS NULL UNION
    SELECT *, 1991 as year FROM victim_counts_1991 WHERE ori IS NULL;

drop materialized view IF EXISTS victim_counts_ori CASCADE;
create materialized view victim_counts_ori as 
    SELECT *, 2015 as year FROM victim_counts_2014 WHERE ori IS NOT NULL UNION 
    SELECT *, 2014 as year FROM victim_counts_2014 WHERE ori IS NOT NULL UNION 
    SELECT *, 2013 as year FROM victim_counts_2013 WHERE ori IS NOT NULL UNION
    SELECT *, 2012 as year FROM victim_counts_2012 WHERE ori IS NOT NULL UNION 
    SELECT *, 2011 as year FROM victim_counts_2011 WHERE ori IS NOT NULL UNION 
    SELECT *, 2010 as year FROM victim_counts_2010 WHERE ori IS NOT NULL UNION
    SELECT *, 2009 as year FROM victim_counts_2009 WHERE ori IS NOT NULL UNION 
    SELECT *, 2008 as year FROM victim_counts_2008 WHERE ori IS NOT NULL UNION 
    SELECT *, 2007 as year FROM victim_counts_2007 WHERE ori IS NOT NULL UNION
    SELECT *, 2006 as year FROM victim_counts_2006 WHERE ori IS NOT NULL UNION 
    SELECT *, 2005 as year FROM victim_counts_2005 WHERE ori IS NOT NULL UNION 
    SELECT *, 2004 as year FROM victim_counts_2004 WHERE ori IS NOT NULL UNION
    SELECT *, 2003 as year FROM victim_counts_2003 WHERE ori IS NOT NULL UNION 
    SELECT *, 2002 as year FROM victim_counts_2002 WHERE ori IS NOT NULL UNION 
    SELECT *, 2001 as year FROM victim_counts_2001 WHERE ori IS NOT NULL UNION
    SELECT *, 2000 as year FROM victim_counts_2000 WHERE ori IS NOT NULL UNION 
    SELECT *, 1999 as year FROM victim_counts_1999 WHERE ori IS NOT NULL UNION 
    SELECT *, 1998 as year FROM victim_counts_1998 WHERE ori IS NOT NULL UNION
    SELECT *, 1997 as year FROM victim_counts_1997 WHERE ori IS NOT NULL UNION 
    SELECT *, 1996 as year FROM victim_counts_1996 WHERE ori IS NOT NULL UNION 
    SELECT *, 1995 as year FROM victim_counts_1995 WHERE ori IS NOT NULL UNION
    SELECT *, 1994 as year FROM victim_counts_1994 WHERE ori IS NOT NULL UNION 
    SELECT *, 1993 as year FROM victim_counts_1993 WHERE ori IS NOT NULL UNION 
    SELECT *, 1992 as year FROM victim_counts_1992 WHERE ori IS NOT NULL UNION
    SELECT *, 1991 as year FROM victim_counts_1991 WHERE ori IS NOT NULL;

CREATE INDEX victim_counts_state_year_id_idx ON victim_counts_states (state_id, year);
CREATE INDEX victim_counts_ori_year_idx ON victim_counts_ori (ori, year);


--------------
-- VICTIMS - OFFENSES
--------------

DO
$do$
DECLARE
   arr integer[] := array[2015];
   i integer;
BEGIN
   FOREACH i IN ARRAY arr
   LOOP
    SET work_mem='2GB';
    RAISE NOTICE 'Dropping view for year: %', i;
    EXECUTE 'drop materialized view  IF EXISTS offense_victim_counts_' || i::TEXT || ' CASCADE';
    RAISE NOTICE 'Creating view for year: %', i;
    EXECUTE 'create materialized view offense_victim_counts_' || i::TEXT || ' as select count(victim_id), ori,resident_status_code,offender_relationship,circumstance_name,ethnicity,offense_name, state_id, race_code, age_num, sex_code 
    from ( 
        SELECT DISTINCT(victim_id), ref_agency.ori, ethnicity, age_num,race_code,year,resident_status_code,offender_relationship,circumstance_name,offense_name, sex_code, nibrs_victim_denorm_' || i::TEXT || '.state_id from nibrs_victim_denorm_' || i::TEXT || ' 
        JOIN ref_agency ON ref_agency.agency_id = nibrs_victim_denorm_' || i::TEXT || '.agency_id
        where year::integer = ' || i || '  and nibrs_victim_denorm_' || i::TEXT || '.state_id is not null
        ) as temp
    GROUP BY GROUPING SETS (
        (year, offense_name, race_code),
        (year, offense_name, sex_code),
        (year, offense_name, age_num),
        (year, offense_name, ethnicity),
        (year, offense_name, resident_status_code),
        (year, offense_name, offender_relationship),
        (year, offense_name, circumstance_name),
        (year, state_id, offense_name, race_code),
        (year, state_id, offense_name, sex_code),
        (year, state_id, offense_name, age_num),
        (year, state_id, offense_name, ethnicity),
        (year, state_id, offense_name, resident_status_code),
        (year, state_id, offense_name, offender_relationship),
        (year, state_id, offense_name, circumstance_name),
        (year, ori, offense_name, race_code),
        (year, ori, offense_name, sex_code),
        (year, ori, offense_name, age_num),
        (year, ori, offense_name, ethnicity),
        (year, ori, offense_name, resident_status_code),
        (year, ori, offense_name, offender_relationship),
        (year, ori, offense_name, circumstance_name)
    );';
   END LOOP;
END
$do$;

drop materialized view  IF EXISTS offense_victim_counts_states;
create materialized view offense_victim_counts_states as 
    SELECT *, 2015 as year FROM offense_victim_counts_2015 WHERE ori IS NULL UNION 
    SELECT *, 2013 as year FROM offense_victim_counts_2013 WHERE ori IS NULL UNION
    SELECT *, 2012 as year FROM offense_victim_counts_2012 WHERE ori IS NULL UNION 
    SELECT *, 2011 as year FROM offense_victim_counts_2011 WHERE ori IS NULL UNION 
    SELECT *, 2010 as year FROM offense_victim_counts_2010 WHERE ori IS NULL UNION
    SELECT *, 2009 as year FROM offense_victim_counts_2009 WHERE ori IS NULL UNION 
    SELECT *, 2008 as year FROM offense_victim_counts_2008 WHERE ori IS NULL UNION 
    SELECT *, 2007 as year FROM offense_victim_counts_2007 WHERE ori IS NULL UNION
    SELECT *, 2006 as year FROM offense_victim_counts_2006 WHERE ori IS NULL UNION 
    SELECT *, 2005 as year FROM offense_victim_counts_2005 WHERE ori IS NULL UNION 
    SELECT *, 2004 as year FROM offense_victim_counts_2004 WHERE ori IS NULL UNION
    SELECT *, 2003 as year FROM offense_victim_counts_2003 WHERE ori IS NULL UNION 
    SELECT *, 2002 as year FROM offense_victim_counts_2002 WHERE ori IS NULL UNION 
    SELECT *, 2001 as year FROM offense_victim_counts_2001 WHERE ori IS NULL UNION
    SELECT *, 2000 as year FROM offense_victim_counts_2000 WHERE ori IS NULL UNION 
    SELECT *, 1999 as year FROM offense_victim_counts_1999 WHERE ori IS NULL UNION 
    SELECT *, 1998 as year FROM offense_victim_counts_1998 WHERE ori IS NULL UNION
    SELECT *, 1997 as year FROM offense_victim_counts_1997 WHERE ori IS NULL UNION 
    SELECT *, 1996 as year FROM offense_victim_counts_1996 WHERE ori IS NULL UNION 
    SELECT *, 1995 as year FROM offense_victim_counts_1995 WHERE ori IS NULL UNION
    SELECT *, 1994 as year FROM offense_victim_counts_1994 WHERE ori IS NULL UNION 
    SELECT *, 1993 as year FROM offense_victim_counts_1993 WHERE ori IS NULL UNION 
    SELECT *, 1992 as year FROM offense_victim_counts_1992 WHERE ori IS NULL UNION
    SELECT *, 1991 as year FROM offense_victim_counts_1991 WHERE ori IS NULL;

drop materialized view  IF EXISTS offense_victim_counts_ori;
create materialized view offense_victim_counts_ori as 
    SELECT *, 2015 as year FROM offense_victim_counts_2015 WHERE ori IS NOT NULL UNION 
    SELECT *, 2014 as year FROM offense_victim_counts_2014 WHERE ori IS NOT NULL UNION 
    SELECT *, 2013 as year FROM offense_victim_counts_2013 WHERE ori IS NOT NULL UNION
    SELECT *, 2012 as year FROM offense_victim_counts_2012 WHERE ori IS NOT NULL UNION 
    SELECT *, 2011 as year FROM offense_victim_counts_2011 WHERE ori IS NOT NULL UNION 
    SELECT *, 2010 as year FROM offense_victim_counts_2010 WHERE ori IS NOT NULL UNION
    SELECT *, 2009 as year FROM offense_victim_counts_2009 WHERE ori IS NOT NULL UNION 
    SELECT *, 2008 as year FROM offense_victim_counts_2008 WHERE ori IS NOT NULL UNION 
    SELECT *, 2007 as year FROM offense_victim_counts_2007 WHERE ori IS NOT NULL UNION
    SELECT *, 2006 as year FROM offense_victim_counts_2006 WHERE ori IS NOT NULL UNION 
    SELECT *, 2005 as year FROM offense_victim_counts_2005 WHERE ori IS NOT NULL UNION 
    SELECT *, 2004 as year FROM offense_victim_counts_2004 WHERE ori IS NOT NULL UNION
    SELECT *, 2003 as year FROM offense_victim_counts_2003 WHERE ori IS NOT NULL UNION 
    SELECT *, 2002 as year FROM offense_victim_counts_2002 WHERE ori IS NOT NULL UNION 
    SELECT *, 2001 as year FROM offense_victim_counts_2001 WHERE ori IS NOT NULL UNION
    SELECT *, 2000 as year FROM offense_victim_counts_2000 WHERE ori IS NOT NULL UNION 
    SELECT *, 1999 as year FROM offense_victim_counts_1999 WHERE ori IS NOT NULL UNION 
    SELECT *, 1998 as year FROM offense_victim_counts_1998 WHERE ori IS NOT NULL UNION
    SELECT *, 1997 as year FROM offense_victim_counts_1997 WHERE ori IS NOT NULL UNION 
    SELECT *, 1996 as year FROM offense_victim_counts_1996 WHERE ori IS NOT NULL UNION 
    SELECT *, 1995 as year FROM offense_victim_counts_1995 WHERE ori IS NOT NULL UNION
    SELECT *, 1994 as year FROM offense_victim_counts_1994 WHERE ori IS NOT NULL UNION 
    SELECT *, 1993 as year FROM offense_victim_counts_1993 WHERE ori IS NOT NULL UNION 
    SELECT *, 1992 as year FROM offense_victim_counts_1992 WHERE ori IS NOT NULL UNION
    SELECT *, 1991 as year FROM offense_victim_counts_1991 WHERE ori IS NOT NULL;

DROP INDEX IF EXISTS offense_victim_counts_state_id_idx;
DROP INDEX IF EXISTS offense_victim_counts_ori_idx;
CREATE INDEX offense_victim_counts_state_id_idx ON offense_victim_counts_states (state_id, year, offense_name);
CREATE INDEX offense_victim_counts_ori_idx ON offense_victim_counts_ori (ori, year, offense_name);

--------------
-- OFFENSES
--------------

DO
$do$
DECLARE
   arr integer[] := array[2015];
   i integer;
BEGIN
   FOREACH i IN ARRAY arr
   LOOP
    SET work_mem='2GB';
    -- needed when run locally
    EXECUTE 'CREATE TABLE IF NOT EXISTS nibrs_offense_denorm_' || i::TEXT || ' () INHERITS (nibrs_offense_denorm)';
    RAISE NOTICE 'Dropping view for year: %', i;
    EXECUTE 'drop materialized view IF EXISTS  offense_counts_' || i::TEXT || ' CASCADE';
    RAISE NOTICE 'Creating view for year: %', i;
    EXECUTE 'create materialized view offense_counts_' || i::TEXT || ' as select count(offense_id), ori, offense_name,weapon_name, method_entry_code, num_premises_entered,location_name, state_id 
    from ( 
        SELECT DISTINCT(offense_id), ref_agency.ori, offense_name, weapon_name, method_entry_code, num_premises_entered,location_name, nibrs_offense_denorm_' || i::TEXT || '.state_id, year from nibrs_offense_denorm_' || i::TEXT || ' 
        JOIN ref_agency ON ref_agency.agency_id = nibrs_offense_denorm_' || i::TEXT || '.agency_id 
        where year::integer = ' || i || ' 
        ) as temp
    GROUP BY GROUPING SETS (
        (year, offense_name),
        (year, weapon_name),
        (year, method_entry_code),
        (year, num_premises_entered),
        (year, location_name),
        (year, state_id, offense_name),
        (year, state_id, weapon_name),
        (year, state_id, method_entry_code),
        (year, state_id, num_premises_entered),
        (year, state_id, location_name),
        (year, ori, offense_name),
        (year, ori, weapon_name),
        (year, ori, method_entry_code),
        (year, ori, num_premises_entered),
        (year, ori, location_name)
    );';
   END LOOP;
END
$do$;

drop materialized view  IF EXISTS offense_counts_states CASCADE;
create materialized view offense_counts_states as 
    SELECT *,2015 as year  FROM offense_counts_2015 WHERE ori IS NULL UNION 
    SELECT *,2014 as year  FROM offense_counts_2014 WHERE ori IS NULL UNION 
    SELECT *,2013 as year  FROM offense_counts_2013 WHERE ori IS NULL UNION
    SELECT *,2012 as year  FROM offense_counts_2012 WHERE ori IS NULL UNION 
    SELECT *,2011 as year  FROM offense_counts_2011 WHERE ori IS NULL UNION 
    SELECT *,2010 as year  FROM offense_counts_2010 WHERE ori IS NULL UNION
    SELECT *,2009 as year  FROM offense_counts_2009 WHERE ori IS NULL UNION 
    SELECT *,2008 as year  FROM offense_counts_2008 WHERE ori IS NULL UNION 
    SELECT *,2007 as year  FROM offense_counts_2007 WHERE ori IS NULL UNION
    SELECT *,2006 as year  FROM offense_counts_2006 WHERE ori IS NULL UNION 
    SELECT *,2005 as year  FROM offense_counts_2005 WHERE ori IS NULL UNION 
    SELECT *,2004 as year  FROM offense_counts_2004 WHERE ori IS NULL UNION
    SELECT *,2003 as year  FROM offense_counts_2003 WHERE ori IS NULL UNION 
    SELECT *,2002 as year  FROM offense_counts_2002 WHERE ori IS NULL UNION 
    SELECT *,2001 as year  FROM offense_counts_2001 WHERE ori IS NULL UNION
    SELECT *,2000 as year  FROM offense_counts_2000 WHERE ori IS NULL UNION 
    SELECT *,1999 as year  FROM offense_counts_1999 WHERE ori IS NULL UNION 
    SELECT *,1998 as year  FROM offense_counts_1998 WHERE ori IS NULL UNION
    SELECT *,1997 as year  FROM offense_counts_1997 WHERE ori IS NULL UNION 
    SELECT *,1996 as year  FROM offense_counts_1996 WHERE ori IS NULL UNION 
    SELECT *,1995 as year  FROM offense_counts_1995 WHERE ori IS NULL UNION
    SELECT *,1994 as year  FROM offense_counts_1994 WHERE ori IS NULL UNION 
    SELECT *,1993 as year  FROM offense_counts_1993 WHERE ori IS NULL UNION 
    SELECT *,1992 as year  FROM offense_counts_1992 WHERE ori IS NULL UNION
    SELECT *,1991 as year  FROM offense_counts_1991 WHERE ori IS NULL;

drop materialized view  IF EXISTS offense_counts_ori CASCADE;
create materialized view offense_counts_ori as 
    SELECT *,2015 as year  FROM offense_counts_2015 WHERE ori IS NOT NULL UNION 
    SELECT *,2014 as year  FROM offense_counts_2014 WHERE ori IS NOT NULL UNION 
    SELECT *,2013 as year  FROM offense_counts_2013 WHERE ori IS NOT NULL UNION
    SELECT *,2012 as year  FROM offense_counts_2012 WHERE ori IS NOT NULL UNION 
    SELECT *,2011 as year  FROM offense_counts_2011 WHERE ori IS NOT NULL UNION 
    SELECT *,2010 as year  FROM offense_counts_2010 WHERE ori IS NOT NULL UNION
    SELECT *,2009 as year  FROM offense_counts_2009 WHERE ori IS NOT NULL UNION 
    SELECT *,2008 as year  FROM offense_counts_2008 WHERE ori IS NOT NULL UNION 
    SELECT *,2007 as year  FROM offense_counts_2007 WHERE ori IS NOT NULL UNION
    SELECT *,2006 as year  FROM offense_counts_2006 WHERE ori IS NOT NULL UNION 
    SELECT *,2005 as year  FROM offense_counts_2005 WHERE ori IS NOT NULL UNION 
    SELECT *,2004 as year  FROM offense_counts_2004 WHERE ori IS NOT NULL UNION
    SELECT *,2003 as year  FROM offense_counts_2003 WHERE ori IS NOT NULL UNION 
    SELECT *,2002 as year  FROM offense_counts_2002 WHERE ori IS NOT NULL UNION 
    SELECT *,2001 as year  FROM offense_counts_2001 WHERE ori IS NOT NULL UNION
    SELECT *,2000 as year  FROM offense_counts_2000 WHERE ori IS NOT NULL UNION 
    SELECT *,1999 as year  FROM offense_counts_1999 WHERE ori IS NOT NULL UNION 
    SELECT *,1998 as year  FROM offense_counts_1998 WHERE ori IS NOT NULL UNION
    SELECT *,1997 as year  FROM offense_counts_1997 WHERE ori IS NOT NULL UNION 
    SELECT *,1996 as year  FROM offense_counts_1996 WHERE ori IS NOT NULL UNION 
    SELECT *,1995 as year  FROM offense_counts_1995 WHERE ori IS NOT NULL UNION
    SELECT *,1994 as year  FROM offense_counts_1994 WHERE ori IS NOT NULL UNION 
    SELECT *,1993 as year  FROM offense_counts_1993 WHERE ori IS NOT NULL UNION 
    SELECT *,1992 as year  FROM offense_counts_1992 WHERE ori IS NOT NULL UNION
    SELECT *,1991 as year  FROM offense_counts_1991 WHERE ori IS NOT NULL;

DROP INDEX IF EXISTS offense_counts_state_year_id_idx;
DROP INDEX IF EXISTS offense_counts_ori_year_idx;
CREATE INDEX offense_counts_state_year_id_idx ON offense_counts_states (state_id, year);
CREATE INDEX offense_counts_ori_year_idx ON offense_counts_ori (ori, year);


--------------
-- OFFENSE - OFFENSES
--------------
DO
$do$
DECLARE
   arr integer[] := array[2015];
   i integer;
BEGIN
   FOREACH i IN ARRAY arr
   LOOP
    SET work_mem='2GB';
    RAISE NOTICE 'Dropping view for year: %', i;
    EXECUTE 'drop materialized view IF EXISTS  offense_offense_counts_' || i::TEXT || ' CASCADE';
    RAISE NOTICE 'Creating view for year: %', i;
    EXECUTE 'create materialized view offense_offense_counts_' || i::TEXT || ' as select count(offense_id), ori, offense_name,weapon_name, method_entry_code, num_premises_entered,location_name, state_id 
    from ( 
        SELECT DISTINCT(offense_id), ref_agency.ori, offense_name, weapon_name, method_entry_code, num_premises_entered,location_name, nibrs_offense_denorm_' || i::TEXT || '.state_id, year from nibrs_offense_denorm_' || i::TEXT || ' 
        JOIN ref_agency ON ref_agency.agency_id = nibrs_offense_denorm_' || i::TEXT || '.agency_id 
        where year::integer = ' || i || ' 
        ) as temp
    GROUP BY GROUPING SETS (
        (year, offense_name, weapon_name),
        (year, offense_name, method_entry_code),
        (year, offense_name, num_premises_entered),
        (year, offense_name, location_name),
        (year, state_id, offense_name, weapon_name),
        (year, state_id, offense_name, method_entry_code),
        (year, state_id, offense_name, num_premises_entered),
        (year, state_id, offense_name, location_name),
        (year, ori, offense_name, weapon_name),
        (year, ori, offense_name, method_entry_code),
        (year, ori, offense_name, num_premises_entered),
        (year, ori, offense_name, location_name)
    );';
   END LOOP;
END
$do$;

drop materialized view IF EXISTS  offense_offense_counts_states;
create materialized view offense_offense_counts_states as 
    SELECT *,2015 as year FROM offense_offense_counts_2015 WHERE ori IS NULL UNION 
    SELECT *,2014 as year FROM offense_offense_counts_2014 WHERE ori IS NULL UNION 
    SELECT *,2013 as year  FROM offense_offense_counts_2013 WHERE ori IS NULL UNION
    SELECT *,2012 as year  FROM offense_offense_counts_2012 WHERE ori IS NULL UNION 
    SELECT *,2011 as year  FROM offense_offense_counts_2011 WHERE ori IS NULL UNION 
    SELECT *,2010 as year  FROM offense_offense_counts_2010 WHERE ori IS NULL UNION
    SELECT *,2009 as year  FROM offense_offense_counts_2009 WHERE ori IS NULL UNION 
    SELECT *,2008 as year  FROM offense_offense_counts_2008 WHERE ori IS NULL UNION 
    SELECT *,2007 as year  FROM offense_offense_counts_2007 WHERE ori IS NULL UNION
    SELECT *,2006 as year  FROM offense_offense_counts_2006 WHERE ori IS NULL UNION 
    SELECT *,2005 as year  FROM offense_offense_counts_2005 WHERE ori IS NULL UNION 
    SELECT *,2004 as year  FROM offense_offense_counts_2004 WHERE ori IS NULL UNION
    SELECT *,2003 as year  FROM offense_offense_counts_2003 WHERE ori IS NULL UNION 
    SELECT *,2002 as year  FROM offense_offense_counts_2002 WHERE ori IS NULL UNION 
    SELECT *,2001 as year  FROM offense_offense_counts_2001 WHERE ori IS NULL UNION
    SELECT *,2000 as year  FROM offense_offense_counts_2000 WHERE ori IS NULL UNION 
    SELECT *,1999 as year  FROM offense_offense_counts_1999 WHERE ori IS NULL UNION 
    SELECT *,1998 as year  FROM offense_offense_counts_1998 WHERE ori IS NULL UNION
    SELECT *,1997 as year  FROM offense_offense_counts_1997 WHERE ori IS NULL UNION 
    SELECT *,1996 as year  FROM offense_offense_counts_1996 WHERE ori IS NULL UNION 
    SELECT *,1995 as year  FROM offense_offense_counts_1995 WHERE ori IS NULL UNION
    SELECT *,1994 as year  FROM offense_offense_counts_1994 WHERE ori IS NULL UNION 
    SELECT *,1993 as year  FROM offense_offense_counts_1993 WHERE ori IS NULL UNION 
    SELECT *,1992 as year  FROM offense_offense_counts_1992 WHERE ori IS NULL UNION
    SELECT *,1991 as year  FROM offense_offense_counts_1991 WHERE ori IS NULL;

drop materialized view IF EXISTS  offense_offense_counts_ori;
create materialized view offense_offense_counts_ori as 
    SELECT *,2015 as year FROM offense_offense_counts_2015 WHERE ori IS NOT NULL UNION 
    SELECT *,2014 as year FROM offense_offense_counts_2014 WHERE ori IS NOT NULL UNION 
    SELECT *,2013 as year  FROM offense_offense_counts_2013 WHERE ori IS NOT NULL UNION
    SELECT *,2012 as year  FROM offense_offense_counts_2012 WHERE ori IS NOT NULL UNION 
    SELECT *,2011 as year  FROM offense_offense_counts_2011 WHERE ori IS NOT NULL UNION 
    SELECT *,2010 as year  FROM offense_offense_counts_2010 WHERE ori IS NOT NULL UNION
    SELECT *,2009 as year  FROM offense_offense_counts_2009 WHERE ori IS NOT NULL UNION 
    SELECT *,2008 as year  FROM offense_offense_counts_2008 WHERE ori IS NOT NULL UNION 
    SELECT *,2007 as year  FROM offense_offense_counts_2007 WHERE ori IS NOT NULL UNION
    SELECT *,2006 as year  FROM offense_offense_counts_2006 WHERE ori IS NOT NULL UNION 
    SELECT *,2005 as year  FROM offense_offense_counts_2005 WHERE ori IS NOT NULL UNION 
    SELECT *,2004 as year  FROM offense_offense_counts_2004 WHERE ori IS NOT NULL UNION
    SELECT *,2003 as year  FROM offense_offense_counts_2003 WHERE ori IS NOT NULL UNION 
    SELECT *,2002 as year  FROM offense_offense_counts_2002 WHERE ori IS NOT NULL UNION 
    SELECT *,2001 as year  FROM offense_offense_counts_2001 WHERE ori IS NOT NULL UNION
    SELECT *,2000 as year  FROM offense_offense_counts_2000 WHERE ori IS NOT NULL UNION 
    SELECT *,1999 as year  FROM offense_offense_counts_1999 WHERE ori IS NOT NULL UNION 
    SELECT *,1998 as year  FROM offense_offense_counts_1998 WHERE ori IS NOT NULL UNION
    SELECT *,1997 as year  FROM offense_offense_counts_1997 WHERE ori IS NOT NULL UNION 
    SELECT *,1996 as year  FROM offense_offense_counts_1996 WHERE ori IS NOT NULL UNION 
    SELECT *,1995 as year  FROM offense_offense_counts_1995 WHERE ori IS NOT NULL UNION
    SELECT *,1994 as year  FROM offense_offense_counts_1994 WHERE ori IS NOT NULL UNION 
    SELECT *,1993 as year  FROM offense_offense_counts_1993 WHERE ori IS NOT NULL UNION 
    SELECT *,1992 as year  FROM offense_offense_counts_1992 WHERE ori IS NOT NULL UNION
    SELECT *,1991 as year  FROM offense_offense_counts_1991 WHERE ori IS NOT NULL;

DROP INDEX IF EXISTS offense_offense_counts_state_id_idx;
DROP INDEX IF EXISTS offense_offense_counts_ori_idx;
CREATE INDEX offense_offense_counts_state_id_idx ON offense_counts_states (state_id, year, offense_name);
CREATE INDEX offense_offense_counts_ori_idx ON offense_counts_ori (ori, year, offense_name);



-- Rebuild any aggregate views

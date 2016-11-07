
------------------------------------------
------------------------------------------
----------- COHORT DEFINITIONS -----------
------------------------------------------
------------------------------------------

---------------------
-- POSITIVE COHORT --
---------------------

-- Create a table containing all SUBJECT_IDs with more than 3 admissions
drop table ff_positive_cohort;
create table ff_positive_cohort as
WITH temp AS
(SELECT
adm1.subject_id
, adm1.hadm_id as first_adm
, adm1.admittime as first_dt
, count(adm2.admittime) as ADM_COUNT -- number of matched admissions
FROM MIMIC2V30.admissions adm1
INNER JOIN MIMIC2V30.patients pat -- join to patients table to get DOB
  on adm1.subject_id = pat.subject_id
JOIN MIMIC2V30.admissions adm2 
  ON adm1.subject_id = adm2.subject_id 
  AND adm2.admittime BETWEEN adm1.admittime AND adm1.admittime + 365
  AND adm1.hadm_id != adm2.hadm_id
where (adm1.admittime-pat.dob)>(365*16) -- only adults, i.e. >16 yrs old
GROUP BY adm1.subject_id, adm1.hadm_id, adm1.admittime
ORDER BY 1,2
)
--Distinct positive cohort ids
SELECT DISTINCT subject_id
FROM temp 
WHERE adm_count>=2;


---------------------
-- NEGATIVE COHORT --
---------------------

-- Set the seed so we consistently select the same cohort.
exec DBMS_RANDOM.SEED ('iamawalrus');

-- Randomly select 400 SUBJECT_IDs who are not in the positive cohort
drop table ff_negative_cohort;
create table ff_negative_cohort as
select SUBJECT_ID from
(
select adm.SUBJECT_ID, dbms_random.value as RAND_THING 
from mimic2v30.admissions adm
-- filter out the positive cohort
left join ff_positive_cohort o3
  on adm.subject_id = o3.subject_id
INNER JOIN MIMIC2V30.patients pat -- join to patients table to get DOB
  on adm.subject_id = pat.subject_id
where o3.subject_id is NULL -- left join where o3 is null eliminates all the positive cohort subject_ids
and (adm.admittime-pat.dob)>(365*16) -- only adults, i.e. >16 yrs old
order by RAND_THING
)
where ROWNUM <= 400;

--------------------------------------------
--------------------------------------------
----------- NOTE DATA EXTRACTION -----------
--------------------------------------------
--------------------------------------------

---------------------
-- POSITIVE COHORT --
---------------------

-- Discharge summaries: Please save as "pos_discharge.csv"
create table pos_discharge as
SELECT ne.*
FROM MIMIC2V30.noteevents ne
-- inner join to the over3adm table to subselect only the positive cohort
inner join ff_positive_cohort o3
  on ne.subject_id = o3.subject_id
where ne.category = 'Discharge'
ORDER BY ne.subject_id, chartdate;

--First nursing notes: Please save as "pos_nursingnotes.csv"
create table pos_nursingnotes as
SELECT * from (
select ne.*, ROW_NUMBER() OVER(PARTITION BY hadm_id ORDER BY chartdate) AS rk
FROM MIMIC2V30.noteevents ne
-- inner join to the over3adm table to subselect only the positive cohort
inner join ff_positive_cohort o3
  on ne.subject_id = o3.subject_id
WHERE category in ('Nursing','Nursing/other')
) ft
where ft.rk = 1; -- only the *first* nursing note


---------------------
-- NEGATIVE COHORT --
---------------------

--Discharge summaries: Please save as "neg1_discharge.csv"
create table neg1_discharge as
SELECT 
  ne.*
FROM MIMIC2V30.noteevents ne
-- inner join to the over3adm table to subselect only the positive cohort
inner join ff_negative_cohort o3
  on ne.subject_id = o3.subject_id
where ne.category = 'Discharge'
ORDER BY ne.subject_id, chartdate;

--Nursing notes: Please save as "neg1_nursingnotes.csv"
DROP TABLE neg1_nursingnotes;
create table neg1_nursingnotes as
SELECT * from (
select ne.*, ROW_NUMBER() OVER(PARTITION BY hadm_id ORDER BY chartdate) AS rk
FROM MIMIC2V30.noteevents ne
-- inner join to the over3adm table to subselect only the positive cohort
inner join ff_negative_cohort o3
  on ne.subject_id = o3.subject_id
WHERE category in ('Nursing','Nursing/other')
) ft
where ft.rk = 1; -- only the *first* nursing note


select count(*) from neg1_discharge
where length(text)>4000;

select count(*) from neg1_nursingnotes
where length(text)>4000;


-- 4084
-- 404

commit;


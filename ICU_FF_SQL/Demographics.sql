--defining frequent flyer (ff) cohort
WITH temp AS
(SELECT DISTINCT
adm1.subject_id
, adm1.hadm_id as first_adm
, adm1.admit_dt as first_dt
, adm2.hadm_id as subsequent_adm
, adm2.admit_dt as second_dt
FROM MIMIC2V26.admissions adm1
JOIN mimic2v26.admissions adm2 
  ON adm1.subject_id = adm2.subject_id 
  AND adm2.admit_dt BETWEEN adm1.admit_dt AND DATE(adm1.admit_dt) + 365 
  AND adm1.hadm_id != adm2.hadm_id
ORDER BY 1,2
)

, temp1 AS
(SELECT subject_id
, first_adm
, COUNT(*) AS adm_count
FROM temp
GROUP BY subject_id, first_adm
)

, over3adm_id AS
(SELECT DISTINCT subject_id
FROM temp1 
WHERE adm_count>=2
)

--weeding out neonates with icu_detail table
, over3adm_table AS (
 SELECT DISTINCT *	
 FROM mimic2v26.icustay_detail 
 WHERE subject_id IN (SELECT subject_id FROM over3adm_id) 
	AND icustay_age_group NOT LIKE '%neonate%'
 ORDER BY subject_id, hadm_id --,hospital_seq
)

, First_icu_admit AS (
SELECT *
FROM over3adm_table
WHERE subject_icustay_seq = 1
)

, Demographics AS (
SELECT demo.subject_id
, demo.hadm_id
, fia.icustay_id
, fia.icustay_seq
, fia.subject_icustay_seq
, fia.icustay_admit_age AS admit_age
, fia.gender
, fia.dod
, demo.marital_status_descr AS marital_status
, demo.ethnicity_descr AS ethnicity
, demo.overall_payor_group_descr AS overall_payor_group
, demo.religion_descr AS religiion
, demo.admission_type_descr AS admission_type
, demo.admission_source_descr AS admission_source
, fia.hospital_expire_flg 
, fia.expire_flg
FROM  over3adm_table fia, mimic2v26.demographic_detail demo
--instead of:
--FROM  First_icu_admit fia, mimic2v26.demographic_detail demo
--using First_icu_admit as fia where subject_icustay_seq is set to 1 would only return 419 patients due to missing values in icustay_detail table
--if we pull all the data then we can analysis where things go missing in R
WHERE fia.hadm_id = demo.hadm_id 
ORDER BY demo.subject_id, fia.icustay_id
)
--unfortunately the demographics table only has subject_id and hadm_id as identifiers
--and that the completeness of the data pulled is limited by hadm_id, which has many missing values

--SELECT count(distinct subject_id) FROM Demographics 
--421 
--SELECT count(distinct hadm_id) FROM Demographics 
--1792
--SELECT count(*) FROM Demographics 
--1946 rows

SELECT * FROM Demographics
--Maybe it's better to export this table
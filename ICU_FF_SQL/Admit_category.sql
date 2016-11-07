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

, admit_category AS (
SELECT --*
subject_id
, hadm_id
, overall_payor_group_descr AS overall_payor_group
, admission_type_descr AS admission_type
, admission_source_descr AS admission_source 
FROM mimic2v26.demographic_detail
WHERE subject_id IN (SELECT subject_id FROM over3adm_table)
--AND admission_type_descr NOT LIke '%NEWBORN%' 
--using NEWBORN admission type category as exclusion criteria still gives 425 unique subject_id, which is not right
)

, admit_info AS(
SELECT cat.*
, ot.icustay_id
, ot.hospital_seq
, ot.subject_icustay_seq
, ot.icustay_seq
, ot.icustay_admit_age AS admit_age
, ot.icustay_first_service
, ot.icustay_last_service
, round((ot.icustay_los/1440)::numeric,2) AS icustay_days
, round((ot.hospital_los/1440)::numeric,2) AS hospital_days
, ot.expire_flg
, ot.hospital_expire_flg
, ot.icustay_expire_flg
, ot.dod
, ot.icustay_intime
, ot.icustay_outtime
FROM admit_category cat, over3adm_table ot
WHERE ot.icustay_seq = 1
AND cat.hadm_id = ot.hadm_id
)

--Check missing values for admit_category
--SELECT count(DISTINCT subject_id) FROM admit_category
--421
--SELECT count(DISTINCT hadm_id) FROM admit_category
--1805
--SELECT count(*) FROM admit_category
--1805 rows
SELECT * FROM admit_category ORDER BY subject_id, hadm_id


--Check missing values for admit_info
--SELECT count(DISTINCT subject_id) FROM admit_info
--421
--SELECT count(DISTINCT hadm_id) FROM admit_info
--1792
--SELECT count(*) FROM admit_info
--1792 rows
--SELECT * FROM admit_info ORDER BY subject_id, icustay_id
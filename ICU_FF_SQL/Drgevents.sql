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
  AND adm2.admit_dt BETWEEN adm1.admit_dt AND DATE(adm1.admit_dt) +365 
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

, over3adm_table AS (
 SELECT subject_id
 , hadm_id
 , icustay_id
 FROM mimic2v26.icustay_detail 
 WHERE subject_id IN (SELECT subject_id FROM over3adm_id) 
	AND icustay_age_group NOT LIKE '%neonate%'
 ORDER BY subject_id, hadm_id, icustay_id
)

, drg_id AS (
SELECT *
FROM mimic2v26.drgevents
WHERE subject_id IN (SELECT subject_id FROM over3adm_table)
)

, drg_table AS (
SELECT drg_id.*
, cd.description
FROM drg_id, mimic2v26.d_codeditems cd
WHERE drg_id.itemid = cd.itemid
)

, cost_sum AS (
SELECT
itemid,
description,
--cost_weight,
count(*) AS hadm_count
, AVG(cost_weight) AS ave_cost_wt
FROM drg_table
GROUP BY itemid, description --, cost_weight
ORDER BY hadm_count DESC
)

--SELECT * FROM cost_sum

SELECT * FROM drg_table ORDER BY cost_weight DESC 

--SELECT count(distinct subject_id) from drg_table
--check: gets 421 distinct subject_id

--SELECT count(distinct hadm_id) from drg_table
--check: gets 1800 distinct hospital admissions

--SELECT count(*) from drg_table
--check: gets 1800 rows

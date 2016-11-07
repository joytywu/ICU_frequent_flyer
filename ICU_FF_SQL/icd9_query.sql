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
  AND adm2.admit_dt BETWEEN adm1.admit_dt AND date(adm1.admit_dt) +365 
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

, icu_id AS (
 SELECT *
 FROM MIMIC2V26.icustay_detail 
 WHERE subject_id IN (SELECT subject_id FROM over3adm_id) 
	AND icustay_age_group NOT LIKE '%neonate%'
)

, icd9_table AS (
SELECT *
FROM MIMIC2V26.ICD9
WHERE subject_id IN (SELECT DISTINCT subject_id FROM icu_id)
)

, icd9_distribution AS (
SELECT code
, count(*) AS frequency
FROM icd9_table
GROUP BY code
)

, icd9_description AS (
SELECT dist.*
, icd9.description
FROM icd9_distribution dist, icd9_table icd9
WHERE dist.code = icd9.code
)

--SELECT DISTINCT ON (frequency, code)* FROM icd9_description ORDER BY frequency DESC

SELECT * FROM icd9_table ORDER BY subject_id, hadm_id
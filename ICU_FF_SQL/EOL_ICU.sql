WITH cohort AS(
SELECT DISTINCT * 
FROM mimic2v26.icustay_detail
WHERE expire_flg LIKE '%Y%'
AND icustay_last_flg LIKE '%Y%'
AND dod BETWEEN icustay_intime AND DATE(icustay_intime) + 30
ORDER BY subject_id
)

, cohort_ids AS (
SELECT DISTINCT subject_id
FROM cohort
)

, subject_count AS (
SELECT subject_id
, count(subject_id) AS count
FROM cohort
GROUP BY subject_id
)

, duplicate AS (
SELECT * 
FROM subject_count 
WHERE count > 1
)

, duplicate_ids AS(
SELECT DISTINCT subject_id
FROM duplicate
)

, duplicated_cohort AS(
SELECT * 
FROM cohort
WHERE subject_id IN (SELECT subject_id FROM duplicate_ids)
ORDER BY subject_id
)

, cohort2 AS(
SELECT DISTINCT * 
FROM cohort
WHERE hospital_last_flg NOT LIKE '%N%'
ORDER BY subject_id
)

, cohort3 AS(
SELECT DISTINCT * 
FROM mimic2v26.icustay_detail
WHERE expire_flg LIKE '%Y%'
--AND icustay_last_flg LIKE '%Y%' is not an apprpriate criteria is it's only the icu last flg of each hospital admission
--might as well get the whole lot of icustay info
AND dod BETWEEN icustay_intime AND DATE(icustay_intime) + 30
ORDER BY subject_id, icustay_id
)

--selecting by subject_id as some tables don't have icustay_id and using hadm_id would miss out on quite a few admissions

, comorb AS (
SELECT * 
FROM mimic2v26.comorbidity_scores
WHERE subject_id IN (SELECT subject_id FROM cohort3)
ORDER BY subject_id
)

, demo AS (
SELECT *
FROM mimic2v26.demographic_detail
WHERE subject_id IN (SELECT subject_id FROM cohort3)
ORDER BY subject_id
)

, icd9 AS(
SELECT *
FROM mimic2v26.icd9
WHERE subject_id IN (SELECT subject_id FROM cohort3)
ORDER BY subject_id
)

, procedures AS (
WITH pro AS (
SELECT *
FROM mimic2v26.procedureevents 
WHERE subject_id IN (SELECT subject_id FROM cohort3)
)
SELECT pro.*
, co.description
FROM pro
LEFT JOIN mimic2v26.d_codeditems co
ON pro.itemid = co.itemid
ORDER BY subject_id
)

, DRG_events AS (
WITH drg AS (
SELECT *
FROM mimic2v26.drgevents 
WHERE subject_id IN (SELECT subject_id FROM cohort3)
)
SELECT drg.*
, co.description
FROM drg
LEFT JOIN mimic2v26.d_codeditems co
ON drg.itemid = co.itemid
ORDER BY subject_id
)

, notes AS (
SELECT *
FROM mimic2v26.noteevents
WHERE icustay_id IN (SELECT icustay_id FROM cohort3)
ORDER BY subject_id, icustay_id
)

, admit_info AS (
SELECT *
FROM mimic2v26.admissions
WHERE subject_id IN (SELECT subject_id FROM cohort3)
ORDER BY subject_id, hadm_id
)


SELECT * FROM comorb


--SELECT * FROM admit_info
--4910 rows

--##SELECT* FROM cohort3
--SELECT count(distinct subject_id) FROM cohort3
--3875 distinct subject_ids
--SELECT count(*) FROM cohort3
--4339 rows or icustay admissions
--SELECT count(distinct hadm_id) FROM cohort3
--3756, missing hadm_id again...
--SELECT count(distinct icustay_id) FROM cohort3
--4339

--SELECT * FROM cohort ORDER BY subject_id
--SELECT count(*) FROM cohort
--3964
--SELECT count(DISTINCT subject_id) FROM cohort
--3872
--SELECT count(*) FROM cohort_ids
--3872
--ie. there are 92 duplicate rows
--SELECT count(DISTINCT subject_id) FROM cohort
--3872

--SELECT sum(count) - count(*) FROM duplicate
--92 rows which account for the duplicates, out of which one patient had 3 rows, the rest 2 rows
--SELECT count(*) FROM duplicate_ids
--91 distinct ids with duplicated rows in the cohort table

--Why duplicate?
--SELECT * FROM duplicated_cohort
--183 rows (91 + 92)
--would appear the duplicates_ids all have icustay_last_flg as Y but not necessarily Y for hospital_last_flg
--So maybe hospital_last_flg needs to be selection criteria too

--SELECT count(*) FROM cohort2
--3577 rows, now it's the same
--SELECT count(DISTINCT subject_id) FROM cohort2
--3577
--Before limiting to hospital_last_flg not like N or like Y, it was 3872 distinct patients
--ie limiting too many on the hospital last flg info, which might be missing for some patients

--SELECT * FROM duplicated_cohort WHERE hospital_last_flg LIKE '%N%'
--97 rows, too many...only expect 92 rows
--SELECT count(distinct subject_id) FROM duplicated_cohort WHERE hospital_last_flg LIKE '%N%'
--91 distinct subjects
--Setting: WHERE hospital_last_flg LIKE '%N%'...doesn't work

--SELECT * FROM cohort WHERE icustay_intime = max(icustay_intime) GROUP BY subject_id
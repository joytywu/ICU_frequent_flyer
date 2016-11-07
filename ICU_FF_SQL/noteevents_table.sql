SELECT SETSEED(0.1); --setting seed for negative cohort SET-1

--GENERATING POSITIVE COHORT
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
  AND adm2.admit_dt BETWEEN adm1.admit_dt AND date(adm1.admit_dt) + 365
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

--Distinct positive cohort ids
, over3adm_id AS
(SELECT DISTINCT subject_id
FROM temp1 
WHERE adm_count>=2
)

--Need this to exclude neonates
, over3adm_table AS (
 SELECT a.subject_id
, a.hadm_id
, a.icustay_id
, a.hospital_seq
, a.icustay_seq
, a.subject_icustay_seq
 FROM MIMIC2V26.icustay_detail a, over3adm_id b
 WHERE a.subject_id = b.subject_id AND a.icustay_age_group NOT LIKE '%neonate%'
 ORDER BY a.subject_id, a.hospital_seq, a.icustay_seq
)

--Positive cohort notes
, noteevents_table AS (
SELECT *
FROM MIMIC2V26.noteevents
WHERE subject_id IN (SELECT subject_id FROM over3adm_table)
ORDER BY subject_id, charttime
)

, discharges AS (
SELECT *
FROM noteevents_table
WHERE category LIKE '%DISCHARGE_SUMMARY%' 
OR LOWER(title) LIKE LOWER('%discharge%')
)

, MD_note AS (
SELECT *
FROM noteevents_table
WHERE category LIKE '%MD%'
)

, nursing AS (
SELECT *
, ROW_NUMBER() OVER(PARTITION BY hadm_id ORDER BY charttime) AS rk
FROM noteevents_table
WHERE category LIKE '%Nursing/Other%'
)

-------
--SELECTING ALL NEGATIVE COHORT IDS
--Adding an index column to allow random selection of subject_ids
, all_neg_ids AS(
SELECT DISTINCT subject_id
,ROW_NUMBER() OVER(ORDER BY subject_id) AS row_num
FROM mimic2v26.icustay_detail
WHERE subject_id NOT IN (SELECT subject_id FROM over3adm_id)
AND icustay_age_group NOT LIKE '%neonate%'
)

--GENERATING A RANDOM SET OF 400 NEGATIVE COHORT IDS, SET-1
--setseed(0.1) at start of query
, neg_ids_set1 AS(
SELECT *
FROM (
	SELECT DISTINCT 1 + TRUNC(RANDOM()*35000)::integer AS row_num
	FROM generate_series(1, 1100) g
	) r
JOIN all_neg_ids USING (row_num)
LIMIT 408 --limit higher than 400 as some got excluded as neonate or not have discharge summaries
)

--Negative cohort notes:

, neg_disch_set1 AS (
SELECT *
FROM mimic2v26.noteevents
WHERE subject_id IN (SELECT subject_id FROM neg_ids_set1)
AND (category LIKE '%DISCHARGE_SUMMARY%' 
	OR LOWER(title) LIKE LOWER('%discharge%'))
)

, neg_MD_set1 AS (
SELECT *
FROM mimic2v26.noteevents
WHERE subject_id IN (SELECT subject_id FROM neg_disch_set1)
AND category LIKE '%MD%'
)

, neg_nursing_set1 AS (
SELECT *
, ROW_NUMBER() OVER(PARTITION BY hadm_id ORDER BY charttime) AS rk
FROM mimic2v26.noteevents
WHERE subject_id IN (SELECT subject_id FROM neg_disch_set1)
AND category LIKE '%Nursing/Other%'
)

--Combining both positive and negative notes, sorting by subject_id to mix it up (blind the reviewer)
--, joint_discharges AS(
--PROC SQL;
--SELECT * FROM discharges
--INTERSECT
--SELECT * FROM neg_disch_set1
--ORDER BY subject_id, charttime
--)
--SELECT * FROM joint_discharges
--doesn't work... :(


--SELECTING POSITIVE COHORT NOTES:
--SELECT * FROM noteevents_table
--52949 rows
--SELECT count(distinct subject_id) FROM noteevents_table
--421
--SELECT count(distinct hadm_id) FROM noteevents_table
--1730
--SELECT * FROM discharges ORDER BY subject_id, charttime
--462 rows ? why so few?!! I did not restrict by hospital admission. 
--Are all the discharge summaries from different admissions lumped together or some admission don't have discharge summaries for some reason?
--SELECT count(distinct subject_id) FROM discharges 
--421, ie all have discharge summaries
--SELECT count(distinct hadm_id) FROM discharges 
--414
--SELECT * FROM MD_note ORDER BY subject_id, charttime
--23 rows, 20 distinct subject_ids, very few people had MD notes
--SELECT * FROM nursing WHERE rk = 1 ORDER BY subject_id, charttime 
--1695 rows
--SELECT count(distinct subject_id) FROM nursing WHERE rk = 1 
--409, ie some patients did not have any nursing notes
--SELECT count(distinct hadm_id) FROM nursing WHERE rk = 1 
--1694

--SELECTING NEGATIVE COHORT, SET 1, NOTES
--SELECT count(distinct subject_id) FROM neg_disch_set1
--400
--SELECT * FROM neg_disch_set1 ORDER BY subject_id, charttime
--405 rows/notes
--SELECT * FROM neg_MD_set1 ORDER BY subject_id, charttime
--3 distinct subject_ids and rows/notes, ie too few to be useful probably
--SELECT count(distinct subject_id) FROM neg_nursing_set1 WHERE rk = 1
--300 distinct subject_ids
--SELECT * FROM neg_nursing_set1 WHERE rk = 1 ORDER BY subject_id, charttime
--466 rows/notes, ie some from different hospital admissions



 

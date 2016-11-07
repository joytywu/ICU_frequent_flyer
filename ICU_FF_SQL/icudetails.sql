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

, admissions_id AS
(SELECT *
FROM mimic2v26.admissions
WHERE subject_id IN (SELECT subject_id FROM over3adm_id)
ORDER BY subject_id, hadm_id
)
--still has neonates

, match_hadmid AS
(SELECT DISTINCT
--ad.admit_dt,
--ad.disch_dt,
*
FROM mimic2v26.icustay_detail 
WHERE hadm_id IN (SELECT hadm_id FROM admissions_id)
AND icustay_age_group NOT LIKE '%neonate%'
ORDER BY subject_id, hadm_id
)

, match_subjectid AS
(SELECT DISTINCT
--ad.admit_dt,
--ad.disch_dt,
*
FROM mimic2v26.icustay_detail
WHERE subject_id IN (SELECT subject_id FROM admissions_id)
AND icustay_age_group NOT LIKE '%neonate%'
ORDER BY subject_id, hadm_id
)


--weeding out neonates with icu_detail table
, over3adm_table AS (
 SELECT 
DISTINCT
*
 --subject_id
 --, hadm_id
 --, icustay_id
 --, hospital_admit_dt
 --, hospital_disch_dt
 --, icustay_intime
 --, icustay_outtime
 --, icustay_first_flg
 --, icustay_last_flg
 --, hospital_seq
 --, hospital_total_num
 --, icustay_seq
 --, icustay_total_num
 --, subject_icustay_seq
 --, subject_icustay_total_num
 --, hospital_los
 --, icustay_los
 FROM mimic2v26.icustay_detail 
 WHERE subject_id IN (SELECT subject_id FROM over3adm_id) 
	AND icustay_age_group NOT LIKE '%neonate%'
 ORDER BY subject_id, icustay_intime
)

, match AS (
SELECT DISTINCT * FROM match_hadmid 
union
SELECT DISTINCT * FROM match_subjectid 
)

, neonate_ids AS (
SELECT DISTINCT subject_id, hadm_id
FROM mimic2v26.icustay_detail 
WHERE subject_id IN (SELECT subject_id FROM admissions_id)
AND icustay_age_group LIKE '%neonate%'
)

--excluding neonates from admissions_id
, missing_ids1 AS (
SELECT distinct hadm_id, subject_id FROM admissions_id
WHERE subject_id NOT IN (SELECT DISTINCT subject_id FROM neonate_ids)
)

--find out which hadm_id and subject_id are still missing in adult cohort
, missing_ids2 AS (
SELECT distinct hadm_id, subject_id FROM missing_ids1
except
SELECT distinct hadm_id, subject_id FROM match
)

--SELECT * FROM missing_ids2
--13 rows
--SELECT count(distinct subject_id) FROM missing_ids2
--13, not actually missing but just the subject_id of the missing hadm_ids
--SELECT count(distinct hadm_id) FROM missing_ids2
--13 missing subject_id and hadm_id overall in the mimic2v26.icustay_detail table

--SELECT count(*) FROM missing_ids1
--1805 rows
--SELECT count(distinct subject_id) FROM missing_ids1
--421
--SELECT count(distinct hadm_id) FROM missing_ids1
--1805
--SELECT * FROM missing_ids1 ORDER BY subject_id, hadm_id
--neonate excluded
--SELECT * FROM admissions_id WHERE hadm_id IN (SELECT hadm_id FROM missing_ids1) ORDER BY subject_id, hadm_id

--SELECT * FROM neonate_ids ORDER BY subject_id
--19 rows
--SELECT count(distinct subject_id) FROM neonate_ids
--6, which we know is right
--SELECT count(distinct hadm_id) FROM neonate_ids
--17, there are 2 missing values for hadm_id


--SELECT count(DISTINCT subject_id) FROM admissions_id
--427 (as still has neonates)
--SELECT count(DISTINCT hadm_id) FROM admissions_id
--1823
--SELECT count(*) FROM admissions_id
--1823

--SELECT count(DISTINCT subject_id) FROM over3adm_table 
--421 (6 less which is expected after excluding neonates)
--SELECT count(DISTINCT hadm_id) FROM over3adm_table
--1792
--SELECT count(*) FROM over3adm_table
--2136 rows
SELECT * FROM over3adm_table ORDER BY subject_id, icustay_intime

--SELECT * FROM over3adm_table --WHERE hospital_admit_dt IS NOT null
--ORDER BY subject_id, icustay_intime

--SELECT count(distinct hadm_id) FROM match
--1792
--SELECT count(distinct subject_id) FROM match
--421
--SELECT count(*) FROM match
--2136 rows
--SELECT DISTINCT * FROM match ORDER BY subject_id

--ICUSTAY_ID is complete and is unique to each row so can use it to check whether over3adm_table
--and match have the same id's
--SELECT DISTINCT icustay_id FROM match intersect SELECT DISTINCT icustay_id FROM over3adm_table
--2136 rows
--SELECT DISTINCT icustay_id FROM match except SELECT DISTINCT icustay_id FROM over3adm_table
--0 rows
-- ie the two tables are the same so pulling icustay_detail by subject_id along is sufficient



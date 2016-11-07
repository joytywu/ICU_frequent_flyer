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
 SELECT DISTINCT
 subject_id
 , hadm_id
 --, hospital_seq
 FROM mimic2v26.icustay_detail 
 WHERE subject_id IN (SELECT subject_id FROM over3adm_id) 
	AND icustay_age_group NOT LIKE '%neonate%'
 ORDER BY subject_id, hadm_id --,hospital_seq
)

--match ff cohort with comorbidities over all hospital admissions
, comorb AS (
SELECT DISTINCT morb.* --get all distinct rows
FROM over3adm_table o, mimic2v26.comorbidity_scores morb
WHERE o.subject_id = morb.subject_id
--will need to use (WHERE o.hadm_id = morb.hadm_id AND hospital_seq = 1) instead if only want first hospital admission comorbidities
--not using hadm_id as identifier if able as it has missing values
ORDER BY morb.subject_id, morb.hadm_id
)

--collating summary comorbidities for each patient over all hospital admissions
, morb_sum AS (
SELECT DISTINCT subject_id
, CASE WHEN sum(congestive_heart_failure)>0 THEN 1 ELSE 0 END AS congestive_heart_failure
, CASE WHEN sum(cardiac_arrhythmias)>0 THEN 1 ELSE 0 END AS cardiac_arrhythmias
, CASE WHEN sum(valvular_disease)>0 THEN 1 ELSE 0 END AS valvular_disease
, CASE WHEN sum(pulmonary_circulation)>0 THEN 1 ELSE 0 END AS pulmonary_circulation
, CASE WHEN sum(peripheral_vascular)>0 THEN 1 ELSE 0 END AS peripheral_vascular
, CASE WHEN sum(hypertension)>0 THEN 1 ELSE 0 END AS hypertension
, CASE WHEN sum(paralysis)>0 THEN 1 ELSE 0 END AS paralysis
, CASE WHEN sum(other_neurological)>0 THEN 1 ELSE 0 END AS other_neurological
, CASE WHEN sum(chronic_pulmonary)>0 THEN 1 ELSE 0 END AS chronic_pulmonary
, CASE WHEN sum(diabetes_uncomplicated)>0 THEN 1 ELSE 0 END AS diabetes_uncomplicated
, CASE WHEN sum(diabetes_complicated)>0 THEN 1 ELSE 0 END AS diabetes_complicated
, CASE WHEN sum(hypothyroidism)>0 THEN 1 ELSE 0 END AS hypothyroidism
, CASE WHEN sum(renal_failure)>0 THEN 1 ELSE 0 END AS renal_failure
, CASE WHEN sum(liver_disease)>0 THEN 1 ELSE 0 END AS liver_disease
, CASE WHEN sum(peptic_ulcer)>0 THEN 1 ELSE 0 END AS peptic_ulcer
, CASE WHEN sum(aids)>0 THEN 1 ELSE 0 END AS aids
, CASE WHEN sum(lymphoma)>0 THEN 1 ELSE 0 END AS lymphoma
, CASE WHEN sum(metastatic_cancer)>0 THEN 1 ELSE 0 END AS metastatic_cancer
, CASE WHEN sum(solid_tumor)>0 THEN 1 ELSE 0 END AS solid_tumor
, CASE WHEN sum(rheumatoid_arthritis)>0 THEN 1 ELSE 0 END AS rheumatoid_arthritis
, CASE WHEN sum(coagulopathy)>0 THEN 1 ELSE 0 END AS coagulopathy
, CASE WHEN sum(obesity)>0 THEN 1 ELSE 0 END AS obesity
, CASE WHEN sum(weight_loss)>0 THEN 1 ELSE 0 END AS weight_loss
, CASE WHEN sum(fluid_electrolyte)>0 THEN 1 ELSE 0 END AS fluid_electrolyte
, CASE WHEN sum(blood_loss_anemia)>0 THEN 1 ELSE 0 END AS blood_loss_anemia
, CASE WHEN sum(deficiency_anemias)>0 THEN 1 ELSE 0 END AS deficiency_anemias
, CASE WHEN sum(alcohol_abuse)>0 THEN 1 ELSE 0 END AS alcohol_abuse
, CASE WHEN sum(drug_abuse)>0 THEN 1 ELSE 0 END AS drug_abuse
, CASE WHEN sum(psychoses)>0 THEN 1 ELSE 0 END AS psychoses
, CASE WHEN sum(depression)>0 THEN 1 ELSE 0 END AS depression 
FROM comorb
GROUP BY subject_id
ORDER BY subject_id
)

SELECT * FROM morb_sum

--Checks:
	--SELECT count(*) FROM comorb
	--gets 1780 rows
	--SELECT count(distinct subject_id) FROM comorb
	--gets 421 distinct subject_id, which is the correct number for the ff cohort
	--SELECT count(distinct hadm_id) FROM comorb
	--gets 1780 distinct hadm_id, which matches number of rows in comorb
	--SELECT count(*) FROM morb_sum
	--gets 421 rows

	
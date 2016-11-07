/*Defining the cohort - Adults of MIMIC2V26*/ 
WITH 
cohort AS(
SELECT d.icustay_id, d.hadm_id, d.subject_id
FROM MIMIC2V26.ICUSTAY_DETAIL d   
WHERE d.icustay_age_group NOT LIKE '%NEONATE%'
),

/*Find whether they were ventilated or not 
  Table: chartevents, items: 720, 722*/
ventilation AS(
SELECT DISTINCT  c.icustay_id,
CASE
  WHEN ch.charttime IS NULL
      THEN 0
      ELSE 1
END AS mech_vent
FROM cohort c
LEFT JOIN mimic2v26.chartevents ch
ON c.icustay_id=ch.icustay_id
AND ch.itemid  IN (720, 722)
),

/*Extract start and stop date*/
vent_start_stop AS (
SELECT icustay_id,
MAX(charttime) stop_time,
MIN(charttime) start_time
FROM MIMIC2V26.CHARTEVENTS ch
WHERE ch.itemid IN (720, 722)
AND ICUSTAY_ID IN (SELECT ICUSTAY_ID FROM ventilation)
GROUP BY ICUSTAY_ID
),

/*calculate days on vent based on start-stop date*/
vent_days AS (
SELECT vss.icustay_id, vss.start_time, vss.stop_time,
      --ROUND( 
      EXTRACT(DAY FROM(vss.stop_time - vss.start_time) ) +
      (EXTRACT(HOUR FROM(vss.stop_time - vss.start_time) )/24) + 
      (EXTRACT( MINUTE FROM( vss.stop_time - vss.start_time))/(60*24))
      --,2) 
      AS days_on_vent   
FROM vent_start_stop vss
JOIN MIMIC2V26.ICUSTAY_DETAIL icud
ON icud.icustay_id = vss.icustay_id
),

/*Find whether they used vasopressors or not 
  Table: medevents, 
  items: 42, 43, 44, 46, 47, 51, 119, 120, 125, 127, 128, 306, 307, 309*/
pressors AS(
SELECT DISTINCT c.icustay_id,
CASE
  WHEN m.charttime IS NULL
  THEN 0
  ELSE 1
  END AS vasopressors
FROM cohort c
LEFT JOIN mimic2v26.medevents m
ON c.icustay_id=m.icustay_id
AND m.itemid  IN (42, 43, 44, 46, 47, 51, 119, 120, 125, 127, 128, 306, 307, 309)
AND m.dose    <>0
),

/*Extract start and stop date*/
pressors_start_stop AS( 
SELECT ICUSTAY_ID,
    MAX(charttime) AS stop_time,
    MIN(charttime) AS start_time
FROM MIMIC2v26.MEDEVENTS m
WHERE m.itemid  IN (42, 43, 44, 46, 47, 51, 119, 120, 125, 127, 128, 306, 307, 309)
AND m.dose > 0
AND ICUSTAY_ID IN( SELECT ICUSTAY_ID FROM pressors)
GROUP BY ICUSTAY_ID
),

/*calculate days on pressors based on start-stop date*/
pressors_days AS(
SELECT pss.icustay_id,pss.start_time,pss.stop_time,
         --ROUND(
         EXTRACT(DAY FROM(pss.stop_time - pss.start_time) ) +
         (EXTRACT(HOUR FROM(pss.stop_time - pss.start_time) )/24) + 
         (EXTRACT( MINUTE FROM( pss.stop_time - pss.start_time))/(60*24))
         --,2) 
         AS days_on_pressors   
FROM pressors_start_stop pss
JOIN MIMIC2V26.ICUSTAY_DETAIL icud
ON icud.icustay_id = pss.icustay_id
)

/*crete a final table to show the results*/
SELECT c.icustay_id, c.subject_id, c.hadm_id,
       f.mech_vent, 
       g.days_on_vent, 
       g.start_time as vent_start_dt,
       g.stop_time as vent_stop_dt,
       h.vasopressors, j.days_on_pressors,
       j.start_time as press_start_dt,
       j.stop_time as press_stop_dt
FROM cohort c
JOIN ventilation f
ON f.icustay_id = c.icustay_id
LEFT JOIN vent_days g
ON g.icustay_id = c.icustay_id
JOIN pressors h
ON h.icustay_id = c.icustay_id
LEFT JOIN pressors_days j
ON j.icustay_id = c.icustay_id
ORDER BY c.icustay_id 
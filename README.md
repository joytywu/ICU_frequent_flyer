# ICU_frequent_flyer

#### The goals of the project
* 1. To create a Natural language processing (NLP) model that could automatically identify complex clinical concepts in patients notes (unstructured data). We targeted concepts known to be common for patients frequently admitted to the ICU. They are also concepts that are often not classified well in the structured data (biomonitor, lab and billing data)
* 2. To use the NLP model to pull notes from whole ICU database to answer interesting research questions in clinical settings

#### What the directory contains
This is the github repository containing the author's specific contributions to the code used in the ICU_frequent_flyer project. It does not contain the raw (de-identified) data because the folder is public. It contains:
* 1. SQL code used to query discharge and nursing notes, as well as patient demographic and comorbidity factors, from the MIMIC II database
* 2. Pre-process and exploratory analysis of patients' demographic and comorbidities data in R
* 3. Quality control management of annotated results files

#To run this file, save the file in the assets folder and type in R Console:
#setwd("~/Documents/ICU_Frequent_Flyers-addedfiles")
#source(paste(getwd(),"/assets/fileReader.R",sep=''))
#Should get two dataframes: summariesFinal and nsnFinal
op <- options(stringsAsFactors=F)

library(dplyr)

Resultsreader <- function(notepath){
  setwd(paste(getwd(), notepath,sep = '/')) 
  files <- list.files() #[1:n]
  #setwd("~/Documents/ICU_Frequent_Flyers-addedfiles")
  #files <- list.files(path = paste(getwd(),"data/results", notetype, sep = "/"))
  allfiles <- NULL
  for (i in 1:length(files)){
    file_i <- read.csv(files[i], sep = ",")
    #Create an annotator column called operator
    file_i$operator <- rep(substr(files[i], 1, 3), nrow(file_i))
    file_i$batch.id <- rep(tolower(substr(files[i], 4, 13)), nrow(file_i))
    colnames(file_i) <- c("Subject.ID", "Hospital.Admission.ID", "ICU.ID", "Note.Type", "Chart.time", "Category", "Real.time", "None", "Obesity", "Non.Adherence", "Developmental.Delay.Retardation", "Advanced.Heart.Disease", "Advanced.Lung.Disease", "Schizophrenia.and.other.Psychiatric.Disorders", "Alcohol.Abuse", "Other.Substance.Abuse", "Chronic.Pain.Fibromyalgia", "Chronic.Neurological.Dystrophies", "Advanced.Cancer", "Depression", "Dementia", "Unsure", "operator", "batch.id")
    allfiles <- unique(rbind(allfiles, file_i))
  }
  setwd("~/Documents/ICU_Frequent_Flyers-addedfiles")
  return(allfiles)
}

#Read and rbind all discharge results notes
disNotesRes <- Resultsreader("data/results/dis")
#Read and rbind all nursing results notes
nsnNotesRes <- Resultsreader("data/results/nsn")


#Need to merge with unannotated files to get cohort and text info

#Read and rbind all discharge unannotated notes
#Adapt Resultsreader function to:
Notesreader <- function(notepath){
  setwd(paste("~/Documents/ICU_Frequent_Flyers-addedfiles", notepath,sep = '/')) 
  files <- list.files()#[c(1:2)]
  allfiles <- NULL
  for (i in 1:length(files)){
    file_i <- read.csv(files[i], sep = ",")
    #A few of the files have different column names and arrangement
    #So I renamed some columns and got rid of some columns here
    colnames(file_i)[1] <- "subject.id"
    colnames(file_i)[2] <- "Hospital.Admission.ID"
    file_i <- file_i[, c("subject.id", "Hospital.Admission.ID", "category", "text", "cohort")]
    #Problem discharge files 3, 7, 8, 11, 15 (colnames different)
    #Create a batch.id column that matches with result files' batch.id 
    file_i$batch.id <- rep(tolower(substr(files[i], 3, 12)), nrow(file_i))
    allfiles <- unique(rbind(allfiles, file_i))
  }
  setwd("~/Documents/ICU_Frequent_Flyers-addedfiles")
  return(allfiles)
}

disNotes <- Notesreader("data/notes/dis")
nsnNotes <- Notesreader("data/notes/nsn")

#Merge results file with orginal files that have the text and cohort info:
summariesFinal <- merge(disNotes, disNotesRes, by = c("Hospital.Admission.ID","batch.id"))
nsnFinal <- merge(nsnNotes, nsnNotesRes, by = c("Hospital.Admission.ID","batch.id"))

#Read miscellaneous missing notes
setwd("~/Documents/ICU_Frequent_Flyers-addedfiles/data/results")
missednotes <- read.csv("JTWDis05OCT16Results.csv")
missednotes$operator <- rep(substr("JTWDis05OCT16Results.csv", 1, 3), nrow(missednotes))
missednotes$batch.id <- rep(tolower(substr("JTWDis05OCT16Results.csv", 4, 13)), nrow(missednotes))
colnames(missednotes) <- c("Subject.ID", "Hospital.Admission.ID", "ICU.ID", "Note.Type", "Chart.time", "Category", "Real.time", "None", "Obesity", "Non.Adherence", "Developmental.Delay.Retardation", "Advanced.Heart.Disease", "Advanced.Lung.Disease", "Schizophrenia.and.other.Psychiatric.Disorders", "Alcohol.Abuse", "Other.Substance.Abuse", "Chronic.Pain.Fibromyalgia", "Chronic.Neurological.Dystrophies", "Advanced.Cancer", "Depression", "Dementia", "Unsure", "operator", "batch.id")
missednotes <- merge(disNotes[, 1:5], missednotes, by = "Hospital.Admission.ID")
missednotes <- missednotes %>% select(Hospital.Admission.ID, batch.id, subject.id:operator)
summariesFinal <- rbind(summariesFinal, missednotes)

#Write the Final files into new .csv files in the main directory
setwd("~/Documents/ICU_Frequent_Flyers-addedfiles")
write.csv(summariesFinal, file = "AllDischargeFinal.csv", row.names = F)
write.csv(nsnNotesRes, file = "AllnursingFinal.csv", row.names = F)

options(op)
#http://stackoverflow.com/questions/25102966/why-rbind-throws-a-warning

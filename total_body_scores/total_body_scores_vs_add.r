library("tidyverse")
library("ggplot2")
library("readxl")


## ##################################################
## Read in data from Excel.

## First, read in ADDs.
fileNm <- "total_body_scores.xlsx"
listADDs <- as.vector(as.matrix(read_excel(path=fileNm, range="D1:S1", col_names=F)))

## Read in the rows with the TBS for the 6 cadavers.
rawAllT <- read_excel(path=fileNm, range="A22:S27", col_names=F)
## Drop column B which contains just the string "TBS".  Drop column C,
## which is all 0s (TBS not meaningful because this is the day on
## which cadavers were placed).
wideT <- rawAllT[,-c(2, 3)]
colnames(wideT) <- c("subj", paste("ADD", listADDs, sep="_"))
rm(fileNm)

## Now, we need to go from wide to long format.
intermedT <- gather(wideT, ADD_degdays, tbs, -subj)
## In the degdays column, we need to remove the "ADD_" prefix, so that
## we can get the numeric results (accumulated degree days).
tbsADDT <- separate(intermedT, ADD_degdays, c("add", "degdays"), sep="_", convert=T)
## Remove the column that contains only the old "ADD" prefix.
tbsADDT <- tbsADDT %>% select(-add)

with(tbsADDT, plot(log(degdays), tbs))

## ##################################################
## Code I was hoping to use to combine our ADDs with the total body
## scores doesn't work, because there are 19 days of total body scores
## and only 18 ADDs.

## ## Get the days and accumulated degree days from the other data we've
## ## already read in.
## fileNm <- "families_massaged.csv"
## rawdaysT <- read_csv(file=fileNm)
## daysADDT <- unique(rawdaysT %>% select(days, degdays))
## rm(rawdaysT, fileNm)


## rawAllT <- read_excel(path=fileNm, range="A22:S27", col_names=F)
## ## Drop the column which contains just the string "TBS".
## wideT <- rawAllT[,-2]
## colnames(wideT) <- c("subj", paste("ADD.", daysADDT$degdays, sep=""))
## rm(fileNm)

## ## Column names are unique in this sheet.
## sum(duplicated(colnames(rawAllT)))

## ## Print out our mismatched ADDs and these, side by side.
## write.table(file="mismatched_ADD_in_tbs_file.txt", cbind(c(daysADDT$degdays, NA), c(NA, listADDs)), sep="\t", row.names=F, col.names=F)

library("tidyverse")
library("randomForest")
library("figdim")

## ##################################################
## Read in the data.

## Read in the combined data in wide format.
tmpT <- read_csv("combined_taxa.csv")

## Remove subj and days variable, since they won't be used in the
## random forest.
allT <- tmpT %>%
  select(-subj, -days)

## Just for reference later, keep the days and degree days, so we can
## look at the time correspondence.
timeT <- tmpT %>% distinct(days, degdays)

rm(tmpT)
## ##################################################



## ##################################################
## Look at a cluster analysis, just to see whether observations made
## at the same time tend to be grouped together.  Results are mixed.
set.seed(7019812)
hc.out <- hclust(dist(allT %>% select(-degdays)), method="average")
plot(hc.out, labels=allT$degdays)
dev.off()
## ##################################################



## ##################################################
## Try random forests for regression using "days" as the response
## variable.

## #########
## How many predictors?  (All columns except response: "degdays").
numPredictors <- ncol(allT) - 1

## Try different numbers of bootstrap samples.
numBtSampsVec <- seq(5000, 6000, by=1000)

## Try different values for mtry (which represents how many variables
## can be chosen from at each split of the tree).
numVarSplitVec <- seq(40, 60, by=5) 
## numVarSplitVec <- seq( floor(sqrt(numPredictors)), ceiling(numPredictors/3)+10, by=2)

## Form matrix with all combinations of these.
combos <- expand.grid(numBtSamps=numBtSampsVec, numVarSplit=numVarSplitVec)


## ###########################
## Do cross-validation over and over, leaving out a different 10% of
## the 57 observations each time.

set.seed(7893910)

## Number of times to do cross-validation.
numCVs <- 50
## ## How many observations to reserve for testing each time.
numLeaveOut <- round(0.10 * nrow(allT))


## For matrix to hold cross-validation results.
cvMSE <- matrix(NA, nrow(combos), ncol=numCVs)
cvErrFrac <- matrix(NA, nrow(combos), ncol=numCVs)
origUnitsqrtcvMSE <- matrix(NA, nrow(combos), ncol=numCVs)
origUnitsqrtcvErrFrac <- matrix(NA, nrow(combos), ncol=numCVs)
sqrtcvMSE <- matrix(NA, nrow(combos), ncol=numCVs)
sqrtcvErrFrac <- matrix(NA, nrow(combos), ncol=numCVs)


## Do cross-validation.
for (i in 1:numCVs){
  
  ## Determine training and cross-validation set.
  whichLeaveOut <- sample(1:nrow(allT), size=numLeaveOut, replace=F)    
  subT <- allT[-whichLeaveOut,]
  cvsetT <- allT[whichLeaveOut,]
  
  ## ## Leave out all the rows assigned to i.
  ## whichLeaveOut <- whichFold==i
  ## cvsetT <- allT[whichLeaveOut,]
  ## subT <- allT[!whichLeaveOut,]

  ## Calculate SSTotal for the cross-validation set.
  SSTot <- sum( (cvsetT$degdays-mean(cvsetT$degdays))^2 )

  for (j in 1:nrow(combos)){    
    rf <- randomForest(degdays ~ . , data=subT, mtry=combos[j,"numVarSplit"], ntree=combos[j,"numBtSamps"], importance=T)
    fitTest <- predict(rf, newdata=cvsetT)
    
    fitResid <- fitTest - cvsetT$degdays
    cvMSE[j,i] <- mean(fitResid^2)
    cvErrFrac[j,i] <- sum(fitResid^2)/SSTot
  }
  rm(rf, fitTest, fitResid)

  ## In sqrt units:
  for (j in 1:nrow(combos)){    
    sqrtrf <- randomForest(sqrt(degdays) ~ . , data=subT, mtry=combos[j,"numVarSplit"], ntree=combos[j,"numBtSamps"], importance=T)
    sqrtfitTest <- predict(sqrtrf, newdata=cvsetT)
    sqrtfitResid <- sqrtfitTest - sqrt(cvsetT$degdays)
    origUnitResid <- sqrtfitTest^2 - cvsetT$degdays
    
    sqrtcvMSE[j,i] <- mean(sqrtfitResid^2)
    sqrtcvErrFrac[j,i] <- sum(sqrtfitResid^2)/sum( ( sqrt(cvsetT$degdays) - mean(sqrt(cvsetT$degdays)) )^2 )
    origUnitsqrtcvMSE[j,i] <- mean(origUnitResid^2)
    origUnitsqrtcvErrFrac[j,i] <- sum(origUnitResid^2)/SSTot
  }
  rm(sqrtrf, sqrtfitTest, sqrtfitResid, origUnitResid)

  if (i %% 10 == 0)
    print(paste0("Finishing cross-validation number ", i))
}
rm(i, j, SSTot)



combos$avgcvMSE <- apply(cvMSE, 1, mean)
combos$avgcvErrFrac <- apply(cvErrFrac, 1, mean)

combos$avgsqrtcvMSE <- apply(sqrtcvMSE, 1, mean)
combos$avgsqrtcvErrFrac <- apply(sqrtcvErrFrac, 1, mean)
combos$avgorigUnitsqrtcvMSE <- apply(origUnitsqrtcvMSE, 1, mean)
combos$avgorigUnitsqrtcvErrFrac <- apply(origUnitsqrtcvErrFrac, 1, mean)

write_csv(combos, path="repeated_cv_all_data_avg_cv_metrics.csv")


## Preliminary check seems to indicate that the optimal number of
## splits is between 45-50 for original units model (5000 bootstrap
## samples is sufficient).  For sqrt model, it's around 40.  It does
## better with more bootstrap samples (say around 6000).
ggplot(data=combos, aes(x=numBtSamps, y=avgcvMSE, color=as.factor(numVarSplit))) + geom_line()
X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgsqrtcvMSE, color=as.factor(numVarSplit))) + geom_line()
X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgorigUnitsqrtcvMSE, color=as.factor(numVarSplit))) + geom_line()


ggplot(data=combos, aes(x=numBtSamps, y=avgcvErrFrac, color=as.factor(numVarSplit))) + geom_line()
X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgsqrtcvErrFrac, color=as.factor(numVarSplit))) + geom_line()
X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgorigUnitsqrtcvErrFrac, color=as.factor(numVarSplit))) + geom_line()
## ####################
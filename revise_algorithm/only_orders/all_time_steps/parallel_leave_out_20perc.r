library("tidyverse")
library("randomForest")
library("figdim")
## library("foreach")
library("parallel")


## ##################################################
## Are we dealing with phlya, orders, or families?
taxalevel <- "orders"

## Read in cleaned-up phyla, orders, or families taxa.
taxaT <- read_csv(paste0("../../", taxalevel, "_massaged.csv"))
## ##################################################



## ##################################################
## Put the data in wide format; remove days, subj, and rare taxa.

## Move back to wide format.
allT <- taxaT %>%
  filter(taxa!="Rare") %>%
  select(degdays, subj, taxa, fracBySubjDay) %>%
  spread(taxa, fracBySubjDay) %>%
  select(-subj)

## Just for reference later, keep the days and degree days, so we can
## look at the time correspondence.
timeT <- taxaT %>% distinct(days, degdays)

rm(taxaT)
## ##################################################



## ##################################################
## Try random forests for regression using "days" as the response
## variable.

## #########
## How many predictors?  (All columns except response: "degdays").
numPredictors <- ncol(allT) - 1

## Try different numbers of bootstrap samples.
numBtSampsVec <- c(1260, 2520, 3780)
## numBtSampsVec <- seq(4000, 5000, by=1000)

## Try different values for mtry (which represents how many variables
## can be chosen from at each split of the tree).
numVarSplitVec <- seq(4, 16, by=2)

## Form matrix with all combinations of these.
combos <- expand.grid(numBtSamps=numBtSampsVec, numVarSplit=numVarSplitVec)


## ###########################
## Do cross-validation over and over, leaving out a different 20% of
## the 93 observations each time.

set.seed(9806291)

## Number of times to do cross-validation.
numCVs <- 1000
## How many observations to reserve for testing each time.
numLeaveOut <- round(0.20 * nrow(allT))


## For matrix to hold cross-validation results.
cvMSE <- matrix(NA, nrow(combos), ncol=numCVs)
cvErrFrac <- matrix(NA, nrow(combos), ncol=numCVs)
origUnitsqrtcvMSE <- matrix(NA, nrow(combos), ncol=numCVs)
origUnitsqrtcvErrFrac <- matrix(NA, nrow(combos), ncol=numCVs)
sqrtcvMSE <- matrix(NA, nrow(combos), ncol=numCVs)
sqrtcvErrFrac <- matrix(NA, nrow(combos), ncol=numCVs)



## #########################################
## Set up function for fitting random forest model using original
## units.
origUnitsF <- function(x, jCombo){
  rf <- randomForest(degdays ~ . , data=x$trainT, mtry=combos[jCombo, "numVarSplit"], ntree=combos[jCombo, "numBtSamps"], importance=T)
  return(predict(rf, newdata=x$validT))
}

## Set up function for fitting random forest model using square root
## units.
sqrtUnitsF <- function(x, jCombo){
  sqrtrf <- randomForest(sqrt(degdays) ~ . , data=x$trainT, mtry=combos[jCombo, "numVarSplit"], ntree=combos[jCombo, "numBtSamps"], importance=T)
  return(predict(sqrtrf, newdata=x$validT))
}
## #########################################


## #########################################
## Get set up for cross-validation.
crossvalidL <- vector("list", numCVs)
for (i in 1:numCVs){
  lvOut <- sample(1:nrow(allT), size=numLeaveOut, replace=F)
  trainT <- allT[-lvOut,]
  validT <- allT[lvOut,]
  crossvalidL[[i]] <- list(trainT=trainT, validT=validT)
}
rm(i, lvOut, trainT, validT)


## Try using lapply to fit the random forests.
origFitL <- vector("list", nrow(combos))
for (j in 1:nrow(combos)){
  origFitL[[j]] <- mclapply(crossvalidL, mc.cores=4, origUnitsF, jCombo=j)
  if (j %% 2 == 0)
    print(paste0("In orig units, finished combo number ", j))
}    
rm(j)

sqrtFitL <- vector("list", nrow(combos))
for (j in 1:nrow(combos)){
  sqrtFitL[[j]] <- mclapply(crossvalidL, mc.cores=4, sqrtUnitsF, jCombo=j)
  if (j %% 2 == 0)
    print(paste0("In sqrt units, finished combo number ", j))
}
rm(j)
## #########################################


## #########################################
## Now, calculate the various summary statistics for each cross-validation.

for (i in 1:numCVs){

  ## Get the validation set for this run from the list.
  validT <- crossvalidL[[i]][["validT"]]

  ## Calculate SSTotal for the cross-validation set.
  SSTot <- sum( (validT$degdays-mean(validT$degdays))^2 )
  
  for (j in 1:nrow(combos)){
     
    ## Calculate the MSE and error fraction of the SS Total for the
    ## validation data in the original units.
    resid <- origFitL[[j]][[i]] - validT$degdays
    cvMSE[j,i] <- mean(resid^2)
    cvErrFrac[j,i] <- sum(resid^2)/SSTot
    rm(resid)
  
    ## Calculate the MSE and error fraction of the SS Total for the
    ## validation data in the original units.
    sqrtUnitResid <- sqrtFitL[[j]][[i]] - sqrt(validT$degdays)
    origUnitResid <- sqrtFitL[[j]][[i]]^2 - validT$degdays
    sqrtcvMSE[j,i] <- mean(sqrtUnitResid^2)
    sqrtcvErrFrac[j,i] <- sum(sqrtUnitResid^2)/sum( ( sqrt(validT$degdays) - mean(sqrt(validT$degdays)) )^2 )
    origUnitsqrtcvMSE[j,i] <- mean(origUnitResid^2)
    origUnitsqrtcvErrFrac[j,i] <- sum(origUnitResid^2)/SSTot
    rm(sqrtUnitResid, origUnitResid)
  }
}
rm(i, j, validT, SSTot)
## #########################################



## ## Do cross-validation.
## for (i in 1:numCVs){
  
##   ## Determine training and cross-validation set.
##   whichLeaveOut <- sample(1:nrow(allT), size=numLeaveOut, replace=F)    
##   subT <- allT[-whichLeaveOut,]
##   cvsetT <- allT[whichLeaveOut,]
  
##   ## Calculate SSTotal for the cross-validation set.
##   SSTot <- sum( (cvsetT$degdays-mean(cvsetT$degdays))^2 )

##   for (j in 1:nrow(combos)){
##     rf <- foreach(ntree=rep(treesPerCore, 4), .combine=combine, .packages='randomForest') %dopar% randomForest(degdays ~ . , data=subT, mtry=combos[j,"numVarSplit"], ntree=combos[j,"numBtSamps"], importance=T)
##     fitTest <- predict(rf, newdata=cvsetT)
    
##     fitResid <- fitTest - cvsetT$degdays
##     cvMSE[j,i] <- mean(fitResid^2)
##     cvErrFrac[j,i] <- sum(fitResid^2)/SSTot
##   }
##   rm(rf, fitTest, fitResid)

##   ## In sqrt units:
##   for (j in 1:nrow(combos)){
##     sqrtrf <- foreach(ntree=rep(treesPerCore, 4), .combine=combine, .packages='randomForest') %dopar% randomForest(sqrt(degdays) ~ . , data=subT, mtry=combos[j,"numVarSplit"], ntree=combos[j,"numBtSamps"], importance=T)
##     sqrtfitTest <- predict(sqrtrf, newdata=cvsetT)
##     sqrtfitResid <- sqrtfitTest - sqrt(cvsetT$degdays)
##     origUnitResid <- sqrtfitTest^2 - cvsetT$degdays
    
##     sqrtcvMSE[j,i] <- mean(sqrtfitResid^2)
##     sqrtcvErrFrac[j,i] <- sum(sqrtfitResid^2)/sum( ( sqrt(cvsetT$degdays) - mean(sqrt(cvsetT$degdays)) )^2 )
##     origUnitsqrtcvMSE[j,i] <- mean(origUnitResid^2)
##     origUnitsqrtcvErrFrac[j,i] <- sum(origUnitResid^2)/SSTot
##   }
##   rm(sqrtrf, sqrtfitTest, sqrtfitResid, origUnitResid)

##   if (i %% 10 == 0)
##     print(paste0("Finishing cross-validation number ", i))
## }
## rm(i, j, SSTot)



combos$avgcvMSE <- apply(cvMSE, 1, mean)
combos$avgcvErrFrac <- apply(cvErrFrac, 1, mean)

combos$avgsqrtcvMSE <- apply(sqrtcvMSE, 1, mean)
combos$avgsqrtcvErrFrac <- apply(sqrtcvErrFrac, 1, mean)
combos$avgorigUnitsqrtcvMSE <- apply(origUnitsqrtcvMSE, 1, mean)
combos$avgorigUnitsqrtcvErrFrac <- apply(origUnitsqrtcvErrFrac, 1, mean)

write_csv(combos, path="parallel_leave_out_20perc.csv")


ggplot(data=combos, aes(x=numBtSamps, y=avgcvMSE, color=as.factor(numVarSplit))) + geom_line()
## X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgsqrtcvMSE, color=as.factor(numVarSplit))) + geom_line()
## X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgorigUnitsqrtcvMSE, color=as.factor(numVarSplit))) + geom_line()


ggplot(data=combos, aes(x=numBtSamps, y=avgcvErrFrac, color=as.factor(numVarSplit))) + geom_line()
## X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgsqrtcvErrFrac, color=as.factor(numVarSplit))) + geom_line()
## X11()
ggplot(data=combos, aes(x=numBtSamps, y=avgorigUnitsqrtcvErrFrac, color=as.factor(numVarSplit))) + geom_line()
## ####################

# 11.06.2018
# LDA-SAT
# Loop for generating results day t-1 ==> t-14 (comparing 6h/12h/24h on Accuracy & F1-score)

# clear the environment
rm(list= ls())
gc()
# load packages and set options
options(stringsAsFactors = FALSE)

#Set up working directory
setwd("~/GitHub/NextBigCrypto-Senti/")

# install packages if not available
packages <- c("readr", #read data
              "lubridate", #date time conversion
              "dplyr", #date manipulation
              "ggplot2", # plotting package
              "quanteda", #kwic function search phrases
              "stringi", #string manipulation
              "tidyquant", "openxlsx","anytime",
              "tidytext","topicmodels",
              "tm", #text mining package
              "caTools","caret", "rpart", "h2o","e1071","RWeka","randomForest") # machine learning packages

if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))
}
lapply(packages, require, character.only = TRUE)

##########################################################################################################
# Function to calculate accuracy/prediction/recall

metrics <- function(cm) {
  n = sum(cm) # number of instances
  nc = nrow(cm) # number of classes
  diag = diag(cm) # number of correctly classified instances per class 
  rowsums = apply(cm, 1, sum) # number of instances per class
  colsums = apply(cm, 2, sum) # number of predictions per class
  p = rowsums / n # distribution of instances over the actual classes
  q = colsums / n # distribution of instances over the predicted classes
  
  #Accuracy
  accuracy = sum(diag) / n
  
  #Per-class Precision, Recall, and F-1
  precision = diag / colsums 
  recall = diag / rowsums 
  f1 = 2 * precision * recall / (precision + recall) 
  
  #One-For-All
  OneVsAll = lapply(1 : nc,
                    function(i){
                      v = c(cm[i,i],
                            rowsums[i] - cm[i,i],
                            colsums[i] - cm[i,i],
                            n-rowsums[i] - colsums[i] + cm[i,i]);
                      return(matrix(v, nrow = 2, byrow = T))})
  
  s = matrix(0, nrow = 2, ncol = 2)
  for(i in 1 : nc){s = s + OneVsAll[[i]]}
  
  #Average Accuracy
  avgAccuracy = sum(diag(s)) / sum(s)
  
  #Macro Averaging
  macroPrecision = mean(precision)
  macroRecall = mean(recall)
  macroF1 = mean(f1)
  
  #Micro Averageing
  micro_prf = (diag(s) / apply(s,1, sum))[1]
  
  #####################################
  #Matthew Correlation Coefficient
  mcc_numerator<- 0
  temp <- array()
  count <- 1
  
  for (k in 1:nrow(cm)){
    for (l in 1:nrow(cm)){
      for (m in 1:nrow(cm)){
        temp[count] <- (cm[k,k]*cm[m,l])-(cm[l,k]*cm[k,m])
        count <- count+1}}}
  sum(temp)
  mcc_numerator <- sum(temp)
  
  mcc_denominator_1 <- 0 
  count <- 1
  mcc_den_1_part1 <- 0
  mcc_den_1_part2 <- 0
  
  for (k in 1:nrow(cm)){
    mcc_den_1_part1 <- 0
    for (l in 1:nrow(cm)){
      mcc_den_1_part1 <- mcc_den_1_part1 + cm[l,k]}
    
    mcc_den_1_part2 <- 0;
    
    for (f in 1:nrow(cm)){
      if (f != k){
        for (g in 1:nrow(cm)){
          mcc_den_1_part2 <- mcc_den_1_part2+cm[g,f]
        }}}
    mcc_denominator_1=(mcc_denominator_1+(mcc_den_1_part1*mcc_den_1_part2));
  }
  
  
  mcc_denominator_2 <- 0 
  count <- 1
  mcc_den_2_part1 <- 0
  mcc_den_2_part2 <- 0
  
  for (k in 1:nrow(cm)){
    mcc_den_2_part1 <- 0
    for (l in 1:nrow(cm)){
      mcc_den_2_part1 <- mcc_den_2_part1 + cm[k,l]}
    
    mcc_den_2_part2 <- 0;
    
    for (f in 1:nrow(cm)){
      if (f != k){
        for (g in 1:nrow(cm)){
          mcc_den_2_part2 <- mcc_den_2_part2+cm[f,g]
        }}}
    mcc_denominator_2=(mcc_denominator_2+(mcc_den_2_part1*mcc_den_2_part2));
  }
  
  mcc = (mcc_numerator)/((mcc_denominator_1^0.5)*(mcc_denominator_2^0.5))
  
  final <- as.data.frame(cbind(accuracy,precision,recall,avgAccuracy,
                               macroPrecision,macroRecall,macroF1,
                               micro_prf,mcc))
  return(final)
}

######################
# LDA Model
######################

# Load LDA result directly
#
token_name <- 'BTC'

files <- list.files(path = '~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',
                    pattern = paste0('^',token_name,'_clean_LDA_'))
df.LDA <- read_csv(paste0('~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',files),
                   locale = locale(encoding = 'latin1'))
df.LDA$status_id <- as.character(df.LDA$status_id)
df.LDA$user_id <- as.character(df.LDA$user_id)
# Make a list of drop.cols for loop later
mintopic <- min(df.LDA$topic)
maxtopic <- max(df.LDA$topic)

drop.cols <- c('countT')
for (i in mintopic:maxtopic){
  eval(drop.cols <- c(drop.cols,paste0('topic_',i)))
}

# put "topic" in front of number
df.LDA$topic <- paste0('topic_',df.LDA$topic)

# ###################################
# #     Load SA models (trained)    #
# ###################################

### 07.06 Pre-trained

files <- list.files(path = '~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',
                    pattern = paste0('^',token_name,'_clean_senti_trained_'))
df.senti <- read_csv(paste0('~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',files),
                     locale = locale(encoding = 'latin1'))
df.senti$status_id <- as.character(df.senti$status_id)
df.senti$user_id <- as.character(df.senti$user_id)

##########################
# load Price dataset     #
##########################

price.df <- readxl::read_xlsx('~/GitHub/NextBigCrypto-Senti/1. Crawlers/Historical_Data_HR.xlsx') %>%
  filter(symbol == token_name) %>%
  dplyr::select(-date.time)

# convert to UTC (20.05.18) -- IMPORTANT!!
price.df$time <- as_datetime(anytime::anytime(price.df$time))

###################
bk <- price.df

final.result <- data.frame('Type_hr' = character(),
                           'Time' = character(),
                           'Accuracy' = numeric(),
                           'F1_score' = numeric(), 
                           'Algo' = character())
time.set <- c(6,12,24)


###############
#
# MAIN LOOP 
#
###############

for (y in 1:length(time.set)){
  
  time.slot <- time.set[y] # insert trigger
  price.df <- bk           # get backup for price.df
  
  ## LDA + SENTI
  # Get total + percentage of each class / day
  df.senti.trained <- df.senti %>% 
    dplyr::select(date,sentiment.trained) %>%
    group_by(time = floor_date(date, paste0(time.slot,' hour')),
             sentiment.trained) %>%
    summarize(count = n()) %>% 
    group_by(time) %>% 
    mutate(countT = sum(count)) %>%
    group_by(sentiment.trained) %>%
    mutate(per = round(100* count/countT,2))
  
  # Per / topic
  df.LDA.df <- df.LDA %>% 
    dplyr::rename(date = created_at) %>%
    dplyr::select(date, topic) %>%
    group_by(time = floor_date(date, paste0(time.slot,' hour')),
             topic) %>%
    summarize(count = n()) %>%
    group_by(time) %>%
    mutate(countT = sum(count)) %>%
    group_by(topic) %>%
    mutate(per.tp = round(100* count/countT,2))
  
  # Convert to each sentiment = column
  df.LDA.df <- reshape2::dcast(df.LDA.df, time + countT ~ topic,
                                value.var = 'per.tp')
  
  df.senti.trained <- reshape2::dcast(df.senti.trained, time + countT ~ sentiment.trained,
                                       value.var = 'per')
  colnames(df.senti.trained) <- c('time','count','neg','neu','pos')
  
  # Merge senti + LDA
  df.senti.LDA.df <- inner_join(df.senti.trained, df.LDA.df, by = 'time')
  
  # Keep colnames for later loop
  name <- colnames(df.senti.LDA.df)
  name <- name[-1] # except date-time column
  #########################################
  # Price.df
  
  # filter out 24-hr mark
  price.df$mark <- NA
  
  if (time.slot == 6){target <- c(0,6,12,18)}
  if (time.slot == 12){target <- c(0,12)}
  if (time.slot == 24){target <- c(0)}
  
  for (i in 1:nrow(price.df)){
    if (lubridate::hour(price.df$time[i]) %in% target){price.df$mark[i] <- 1}  
  }
  
  price.df <- price.df %>% 
    filter(mark == 1) %>%
    dplyr::select(time,close,priceBTC)
  
  # calculate differences between close prices of each transaction dates
  price.df$pricediff <- 0
  if (token_name == 'BTC'){
    for (i in 2:nrow(price.df)){
      price.df$pricediff[i] <- price.df$close[i] - price.df$close[i-1]
    }
  }
  if (token_name != 'BTC'){
    for (i in 2:nrow(price.df)){
      price.df$pricediff[i] <- price.df$priceBTC[i] - price.df$priceBTC[i-1]
    }
  } 
  
  ###########
  # BINNING #
  ###########
  
  price.df$diff <- NA
  price.df$bin <- NA
  
  # Assigning bin to main dataframe
  if (token_name == 'BTC'){
    for (i in 2:nrow(price.df)){
      price.df$diff[i] <- round(((price.df$close[i]-price.df$close[i-1])/price.df$close[i])*100,2)
    }
  }
  if (token_name != 'BTC'){
    for (i in 2:nrow(price.df)){
      price.df$diff[i] <- round(((price.df$priceBTC[i]-price.df$priceBTC[i-1])/price.df$priceBTC[i])*100,2)
    }
  }
  
  # This version only split 2 classes
  for (i in 2:nrow(price.df)){
    price.df$bin[i] <- ifelse(price.df$diff[i] < 0,'down','up')
  }
  
  for (z in 1:14){
    
    x <- z/(time.slot/24)
    
    # Convert to categorical variables
    price.df$bin <- as.factor(price.df$bin)
    
    #############################################################
    # Loop to create columns
    
    for (k in 1:length(name)){
      # Create 14 days features
      # Generate columns through loop
      for (i in 1:x){
        eval(parse(text = paste0('df.senti.LDA.df$',name[k],'_', i,' <- NA')))
      }
      
      for (i in 1:nrow(df.senti.LDA.df)){
        for (j in 1:x){
          eval(parse(text = paste0('df.senti.LDA.df$',name[k],'_', j,' <- lag(df.senti.LDA.df$',name[k],',',j,')')))
        }
      }
    }
    
    # Fill NA value from sentiment with 0 as 0%
    ## tidyr
    df.senti.LDA.df <- df.senti.LDA.df %>%
      replace(is.na(.), 0)
    
    # Build a training and testing set
    main.df <- inner_join(price.df, df.senti.LDA.df, by = 'time')
    main.df <- unique(main.df)
    # Build a training and testing set.
    main.df <- main.df %>%
      dplyr::select(-time,-close,-diff,-pricediff,
                    -count,-neg,-neu,-pos,-priceBTC) %>%
      dplyr::select(-one_of(drop.cols))
    
    
    # Remove NA 
    main.df <- main.df[complete.cases(main.df),]
    
    # Split random
    set.seed(1908)
    split <- sample.split(main.df$bin, SplitRatio=0.8) #bin is target variable
    train <- subset(main.df, split==TRUE)
    test <- subset(main.df, split==FALSE)
    
    gc()
    ##############################
    # k-fold validation (10)
    train_control <- trainControl(## 10-fold CV
      method = "cv",
      number = 10)
    
    #################################
    # Base-line model (GLM)
    LogiModel <- train(bin ~.,
                       data = train,
                       method = "glm",
                       trControl = train_control)
    LogiModel
    
    # Prediction
    prediction.Logi <- predict(LogiModel, 
                               newdata= test[,2:ncol(test)], 
                               type = "raw")
    prediction.Logi
    
    confusionMatrix(as.factor(prediction.Logi),test$bin)
    
    cmLogi <- table(test$bin, prediction.Logi)
    metrics(cmLogi)
    
    ########################################
    # Naive Bayes
    set.seed(1234)
    NBayes <- train(bin ~., 
                    data = train, 
                    laplace = 1, 
                    method = "nb",
                    trControl = train_control)
    
    predictionsNB <- predict(NBayes, 
                             newdata = test[,2:ncol(test)])
    
    cmNB <- table(test$bin, predictionsNB)
    
    confusionMatrix(predictionsNB,test$bin)
    
    metrics(cmNB)
    
    ########################################
    # Random Forest
    set.seed(1234)
    RF <- train(bin ~.,
                data = train,
                method = "rf",
                trControl = train_control)
    
    predictionsRF <- predict(RF, 
                             newdata = test[,2:ncol(test)])
    
    cmRF <- table(test$bin, predictionsRF)
    
    confusionMatrix(predictionsRF,test$bin)
    
    metrics(cmRF)
    
    ########################################
    # Support Vector Machine
    set.seed(1234)
    SVM <- train(bin ~.,
                 data = train,
                 method = "svmLinear",
                 trControl = train_control)
    
    predictionsSVM <- predict(SVM, 
                              newdata = test[,2:ncol(test)])
    
    cmSVM <- table(test$bin, predictionsSVM)
    
    confusionMatrix(predictionsSVM,test$bin)
    
    metrics(cmSVM)
    
    ########################################
    # C5.0 tree
    set.seed(1234)
    C5.0 <- train(bin ~.,
                  data = train,
                  method = "C5.0",
                  trControl = train_control)
    
    predictionsC50 <- predict(C5.0, 
                              newdata = test[,2:ncol(test)])
    
    cmC50 <- table(test$bin, predictionsC50)
    
    confusionMatrix(predictionsC50,test$bin)
    
    metrics(cmC50) 
    
    ###############################################
    # Accuracy
    acc.mLogi <- ifelse(is.na(max(metrics(cmLogi)$avgAccuracy)),0,max(metrics(cmLogi)$avgAccuracy))
    acc.mSVM <- ifelse(is.na(max(metrics(cmSVM)$avgAccuracy)),0,max(metrics(cmSVM)$avgAccuracy))
    acc.mC50 <- ifelse(is.na(max(metrics(cmC50)$avgAccuracy)),0,max(metrics(cmC50)$avgAccuracy))
    acc.mNB <- ifelse(is.na(max(metrics(cmNB)$avgAccuracy)),0,max(metrics(cmNB)$avgAccuracy))
    acc.mRF <- ifelse(is.na(max(metrics(cmRF)$avgAccuracy)),0,max(metrics(cmRF)$avgAccuracy))
    
    acc <- max(acc.mLogi,acc.mSVM,acc.mC50,acc.mNB,acc.mRF)
    
    # F1 score
    f1.mLogi <- ifelse(is.na(max(metrics(cmLogi)$macroF1)),0,max(metrics(cmLogi)$macroF1))
    f1.mSVM <- ifelse(is.na(max(metrics(cmSVM)$macroF1)),0,max(metrics(cmSVM)$macroF1))
    f1.mC50 <- ifelse(is.na(max(metrics(cmC50)$macroF1)),0,max(metrics(cmC50)$macroF1))
    f1.mNB <- ifelse(is.na(max(metrics(cmNB)$macroF1)),0,max(metrics(cmNB)$macroF1))
    f1.mRF <- ifelse(is.na(max(metrics(cmRF)$macroF1)),0,max(metrics(cmRF)$macroF1))
    
    f1 <- max(f1.mLogi,f1.mSVM,f1.mC50,f1.mNB,f1.mRF)
    
    model <- which.max(c(f1.mLogi,
                         f1.mSVM,
                         f1.mC50,
                         f1.mNB,
                         f1.mRF))
    
    if (model == 1){model <- 'Logi'}
    if (model == 2){model <- 'SVM'}
    if (model == 3){model <- 'C50'}
    if (model == 4){model <- 'NB'}
    if (model == 5){model <- 'RF'}
    
    # Add results to final dataset
    result <- as.data.frame(cbind(paste0(time.set[y],'hr'),z,acc,f1,model))
    colnames(result) <- colnames(final.result)
    
    final.result <- rbind(final.result,result)
    
    print(paste0('Complete model type ',time.set[y],'-hr on time t-',z,'. Best model is ',model,' with ',acc,' accuracy and ',f1,' F1-score.'))
    gc() # garbage collection
  }
}

# Save final result
write.xlsx(final.result,paste0('~/GitHub/NextBigCrypto-Senti/3. Models Development/0.',token_name,'_LDA-SAT_result.xlsx'))


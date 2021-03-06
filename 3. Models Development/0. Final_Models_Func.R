################################
#                              #
# Functions of Final Generator #
#                              #
################################

#########################################################

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

##############
# PD Model   #
##############
if (model.list$PD[model.no] == 1){
  
  # Check if already loaded
  if (exists("df.PD") == FALSE){
    # Load PD result directly
    files <- list.files(path = '~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',
                        pattern = paste0('^',token_name,'_clean_PD_'))
    df.PD <- read_csv(paste0('~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',files),
                       locale = locale(encoding = 'latin1'))
    df.PD$status_id <- as.character(df.PD$status_id)
    df.PD$user_id <- as.character(df.PD$user_id)
  }
  
  drop.cols <- c('countT')
  for (i in 1:10){
    eval(drop.cols <- c(drop.cols,paste0('topic_',i)))
  }
}
##############
# LDA Model  #
##############
if (model.list$LDA[model.no] == 1){
  
  # Check if already loaded
  if (exists("df.LDA") == FALSE){
    # Load LDA result directly
    files <- list.files(path = '~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',
                        pattern = paste0('^',token_name,'_clean_LDA_'))
    df.LDA <- read_csv(paste0('~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',files),
                       locale = locale(encoding = 'latin1'))
    df.LDA$status_id <- as.character(df.LDA$status_id)
    df.LDA$user_id <- as.character(df.LDA$user_id)
    # put "topic" in front of number
    df.LDA$topic <- paste0('topic_',df.LDA$topic)
    # Make a list of drop.cols for loop later
    mintopic <- min(df.LDA$topic)
    maxtopic <- max(df.LDA$topic)
  }
  
  if (exists('df.LDA')==TRUE){
    # Make a list of drop.cols for loop later
    mintopic <- min(as.numeric(substr(df.LDA$topic,7,nchar(df.LDA$topic))))
    maxtopic <- max(as.numeric(substr(df.LDA$topic,7,nchar(df.LDA$topic))))
  }

  drop.cols <- c('countT')
  for (i in mintopic:maxtopic){
    eval(drop.cols <- c(drop.cols,paste0('topic_',i)))
  }
}
###########################
# SA models (packages)    #
###########################

if (model.list$SAP[model.no] == 1){
  if (exists("df.senti") == FALSE){
    # Load new df.senti
    files <- list.files(path = '~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',
                        pattern = paste0('^',token_name,'_clean_senti_pkg_'))
    df.senti <- read_csv(paste0('~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',files),
                         locale = locale(encoding = 'latin1')) %>%
      rename(sentiment = sentiment.packages)
    df.senti$status_id <- as.character(df.senti$status_id)
    df.senti$user_id <- as.character(df.senti$user_id)
  }
}

##########################
# SA models (trained)    #
##########################
if (model.list$SAT[model.no] == 1){
  if (exists('df.senti')==FALSE){
    # Load new df.senti
    files <- list.files(path = '~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',
                        pattern = paste0('^',token_name,'_clean_senti_trained_'))
    df.senti <- read_csv(paste0('~/GitHub/NextBigCrypto-Senti/0. Datasets/SentiTopic/',files),
                         locale = locale(encoding = 'latin1')) %>%
      rename(sentiment = sentiment.trained)
    df.senti$status_id <- as.character(df.senti$status_id)
    df.senti$user_id <- as.character(df.senti$user_id)
  }
}

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
time.set <- c(6,12,24) # 6hr / 12hr / 24hr

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

###############
#
# MAIN LOOP 
#
###############
print('**************************************************************************************')
print(paste0('* Generating models for settings ',result_filename))
print('**************************************************************************************')

for (y in 1:length(time.set)){
  
  time.slot <- time.set[y] # insert trigger
  price.df <- bk           # get backup for price.df
  
  # SAT and SAP 
  if (model.list$SAT[model.no] == 1 | model.list$SAP[model.no] == 1){
    
    # Increase list of drop columns (for later use)
    if (exists("drop.cols") == TRUE){drop.cols <- c(drop.cols,'count','neu','pos','neg')}
    if (exists("drop.cols") == FALSE){drop.cols <- c('count','neu','pos','neg')}
    
    # Get total + percentage of each class / day
    df.senti.final <- df.senti %>% 
      dplyr::select(date,sentiment) %>%
      group_by(time = floor_date(date, paste0(time.slot,' hour')),
               sentiment) %>%
      summarize(count = n()) %>% 
      group_by(time) %>% 
      mutate(countT = sum(count)) %>%
      group_by(sentiment) %>%
      mutate(per = round(100* count/countT,2))
    
    # with out topic modeling (no PD or LDA)
    if (model.list$LDA[model.no] == 0 & model.list$PD[model.no] == 0){
      # Convert to each sentiment = column
      df.final <- reshape2::dcast(df.senti.final, time + countT ~ sentiment , 
                              value.var = 'per')
      colnames(df.final) <- c('time','count','neg','neu','pos')
    }
    
    #########################################
    # LDA model + SAP/SAT
    if (model.list$LDA[model.no] == 1){
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
      
      df.senti.final <- reshape2::dcast(df.senti.final, time + countT ~ sentiment,
                                        value.var = 'per')
      colnames(df.senti.final) <- c('time','count','neg','neu','pos')
      
      # Merge senti + LDA
      df.final <- inner_join(df.senti.final, df.LDA.df, by = 'time')
    }
    #########################################
    # PD model + SAP/SAT
    if (model.list$PD[model.no] == 1){
      # Filter Topic base on time.slot
      # get total count per time slot
      df.PD.df <- df.PD %>%
        dplyr::rename(date = created_at) %>%
        dplyr::select(date,c(topic1:topic10)) %>%
        group_by(time = floor_date(date, paste0(time.slot,' hour'))) %>%
        summarize(countT = n()) %>%
        group_by(time) 
      # Get counts of topics in allocated timeslot
      # Loop for 10 topics
      for (i in 1:10){
        eval(parse(text = paste0('df.topic <- df.PD %>% ',
                                 'dplyr::rename(date = created_at, topic_',i,' = topic',i,') %>% ',
                                 'filter(topic_',i,' == 1) %>% ',
                                 'dplyr::select(date, topic_',i,') %>% ',
                                 'group_by(time = floor_date(date, paste0(time.slot,',"'",' hour',"'",')), topic_',i,') %>% ',
                                 'summarize(count = n()) %>% ',
                                 'mutate(topic_',i,' = count) %>% ',
                                 'select(-count)')))
        # merge with full PD df
        df.PD.df <- left_join(df.PD.df, df.topic, by = "time")
        df.PD.df[is.na(df.PD.df)] <- 0
        # Get percentages of topics
        eval(parse(text = paste0('df.PD.df <- df.PD.df %>% ',
                                 'mutate(topic_',i,' = round((topic_',i,'/countT) *100,2))')))
        
      }
      df.senti.final <- reshape2::dcast(df.senti.final, time + countT ~ sentiment,
                                        value.var = 'per')
      colnames(df.senti.final) <- c('time','count','neg','neu','pos')
      
      # Merge senti + LDA
      df.final <- inner_join(df.senti.final, df.PD.df, by = 'time')
    }
  }
  
  #######################
  # Exception = only LDA
  #######################
  if (model.list$LDA[model.no] == 1 & model.list$SAT[model.no] == 0 & model.list$SAP[model.no] == 0){
    # Summarize base on topics allocation each day
    # Filter Topic base on time.slot
    df.LDA.df <- df.LDA %>%
      dplyr::rename(date = created_at) %>%
      dplyr::select(date, topic) %>%
      group_by(time = floor_date(date, paste0(time.slot,' hour')),
               topic) %>%
      summarize(count = n()) %>%
      group_by(time) %>%
      mutate(countT = sum(count)) %>%
      group_by(topic) %>%
      mutate(per = round(100* count/countT,2))
    
    # Convert to each topic = column
    df.final <- reshape2::dcast(df.LDA.df, time + countT ~ topic,
                                 value.var = 'per')
  }
  
  #######################
  # Exception = only PD
  #######################
  if (model.list$PD[model.no] == 1 & model.list$SAT[model.no] == 0 & model.list$SAP[model.no] == 0){
    # Filter Topic base on time.slot
    # get total count per time slot
    df.PD.df <- df.PD %>%
      dplyr::rename(date = created_at) %>%
      dplyr::select(date,c(topic1:topic10)) %>%
      group_by(time = floor_date(date, paste0(time.slot,' hour'))) %>%
      summarize(countT = n()) %>%
      group_by(time) 
    # Get counts of topics in allocated timeslot
    # Loop for 10 topics
    for (i in 1:10){
      eval(parse(text = paste0('df.topic <- df.PD %>% ',
                               'dplyr::rename(date = created_at, topic_',i,' = topic',i,') %>% ',
                               'filter(topic_',i,' == 1) %>% ',
                               'dplyr::select(date, topic_',i,') %>% ',
                               'group_by(time = floor_date(date, paste0(time.slot,',"'",' hour',"'",')), topic_',i,') %>% ',
                               'summarize(count = n()) %>% ',
                               'mutate(topic_',i,' = count) %>% ',
                               'select(-count)')))
      # merge with full PD df
      df.PD.df <- left_join(df.PD.df, df.topic, by = "time")
      df.PD.df[is.na(df.PD.df)] <- 0
      # Get percentages of topics
      eval(parse(text = paste0('df.final <- df.PD.df %>% ',
                               'mutate(topic_',i,' = round((topic_',i,'/countT) *100,2))')))
      
    }
  }
  
  # check if it is only HP model
  onlyHP <- 0
  if (model.list$HP[model.no] == 1 & model.list$SAT[model.no] == 0 & model.list$SAP[model.no] == 0 & 
      model.list$LDA[model.no] == 0 & model.list$PD[model.no] == 0){
    onlyHP <- 1
  }
  if (onlyHP == 0){ # not only-HP model
    # Keep colnames for later loop
    name <- colnames(df.final)
    name <- name[-1] # except date-time column
  }

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
  if (token_name == 'BTC' | compare.w.BTC == 0){
    for (i in 2:nrow(price.df)){
      price.df$pricediff[i] <- price.df$close[i] - price.df$close[i-1]
    }
  }
  if (token_name != 'BTC' & compare.w.BTC == 1){
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
  if (token_name == 'BTC' | compare.w.BTC == 0){
    for (i in 2:nrow(price.df)){
      price.df$diff[i] <- round(((price.df$close[i]-price.df$close[i-1])/price.df$close[i])*100,2)
    }
  }
  if (token_name != 'BTC' & compare.w.BTC == 1){
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
    
    # Historical Price is included or not
    if (model.list$HP[model.no] == 1){
      for (i in 1:x){
        eval(parse(text = paste0('price.df$t_', i,' <- NA')))
      }
      
      for (i in 1:nrow(price.df)){
        for (j in 1:x){
          eval(parse(text = paste0('price.df$t_', j,' <- as.factor(lag(price.df$bin,',j,'))')))
        }
      }
    }

    # Convert to categorical variables
    price.df$bin <- as.factor(price.df$bin)
    # if it is only HP model
    if (onlyHP == 1){
      main.df <- price.df %>% 
        dplyr::select(-time,-close,-priceBTC,-pricediff,-diff)
    }
    
    # if it is not HP model then proceed
    if (onlyHP == 0){
      #############################################################
      # Loop to create columns
      for (k in 1:length(name)){
        # Create 14 days features
        # Generate columns through loop
        for (i in 1:x){
          eval(parse(text = paste0('df.final$',name[k],'_', i,' <- NA')))
        }
        
        for (i in 1:nrow(df.final)){
          for (j in 1:x){
            eval(parse(text = paste0('df.final$',name[k],'_', j,' <- lag(df.final$',name[k],',',j,')')))
          }
        }
      }
      # Fill NA value from sentiment / topics with 0 as 0%
      ## tidyr
      df.final <- df.final %>%
        replace(is.na(.), 0)
      
      # Build a training and testing set
      main.df <- inner_join(price.df, df.final, by = 'time')
      main.df <- unique(main.df)
      # Build a training and testing set.
      main.df <- main.df %>%
        dplyr::select(-time,-close,-diff,-pricediff,-priceBTC) %>%
        dplyr::select(-one_of(drop.cols))
    }

    
    # Remove NA 
    main.df <- main.df[complete.cases(main.df),]
    
    # Split random
    set.seed(1908)
    split <- sample.split(main.df$bin, SplitRatio=0.8) # bin is target variable
    train <- subset(main.df, split==TRUE)
    test <- subset(main.df, split==FALSE)
    
    gc()
    
    ##############################
    # MODELS GENERATOR
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
    
    print(paste0('Complete ',time.set[y],'-hr on day t-',z,'. Best model: ',model,' with ',round(acc*100,2),'% acc and ',round(f1,2),' F1-score.'))
    gc() # garbage collection
  }
}

# Save final result
write.xlsx(final.result,paste0('~/GitHub/NextBigCrypto-Senti/3. Models Development/Results/',
                               result_filename,'.xlsx'))
# Print out message
print(paste0('Completed ',result_filename,' result!'))
# Preprocessing pipeline for Twitter data 01.05.2018

# load packages and set options
options(stringsAsFactors = FALSE)

# install packages if not available
packages <- c("readr", #read data
              "lubridate", #date time conversion
              "dplyr", #date manipulation
              "data.table",
              "stringi", #string manipulation
              "stringr",
              "tm","openxlsx","qdapRegex","qdap","NLP","openNLP"
)

if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))
}
lapply(packages, require, character.only = TRUE)

######################
#
# FUNCTIONS CREATION
#
######################

# IMPORTANT - For converting non-Unicode character from csv file (took 1 month to recognize)
trueunicode.hack <- function(string){
  m <- gregexpr("<U\\+[0-9A-F]{4}>", string)
  if(-1==m[[1]][1])
    return(string)
  
  codes <- unlist(regmatches(string, m))
  replacements <- codes
  N <- length(codes)
  for(i in 1:N){
    replacements[i] <- intToUtf8(strtoi(paste0("0x", substring(codes[i], 4, 7))))
  }
  
  # if the string doesn't start with a unicode, the copy its initial part
  # until first occurrence of unicode
  if(1!=m[[1]][1]){
    y <- substring(string, 1, m[[1]][1]-1)
    y <- paste0(y, replacements[1])
  }else{
    y <- replacements[1]
  }
  
  # if more than 1 unicodes in the string
  if(1<N){
    for(i in 2:N){
      s <- gsub("<U\\+[0-9A-F]{4}>", replacements[i], 
                substring(string, m[[1]][i-1]+8, m[[1]][i]+7))
      Encoding(s) <- "UTF-8"
      y <- paste0(y, s)
    }
  }
  
  # get the trailing contents, if any
  if( nchar(string)>(m[[1]][N]+8) )
    y <- paste0( y, substring(string, m[[1]][N]+8, nchar(string)) )
  y
}

conv_fun <- function(x) iconv(x, "latin1", "ASCII", "") # delete "byte" ==> delete emoticons unicode

# Remove URL now is performed by qdapRegex 25.04.2018
# removeURL <- function(x) gsub('"(http.*) |(https.*) |(http.*)$|\n', "", x)
removeURL <- function(x) rm_url(x, pattern=pastex("@rm_twitter_url", "@rm_url"))

# Function to replace ' and " to spaces before removing punctuation 
# to avoid different words from binding 
AposToSpace = function(x){
  x= gsub("'", ' ', x)
  x= gsub('"', ' ', x)
  return(x)
}

# Constructing abbreviation list

# Abbreviation conversion 30.04.18
# myAbbrevs <- read_csv('~/GitHub/NextBigCrypto-Senti/0. Datasets/abbrev.csv')

# new version of abbrev dict 04.05.2018
myAbbrevs <- openxlsx::read.xlsx('~/GitHub/NextBigCrypto-Senti/0. Datasets/abbrev.xlsx')

# No need to do this since tokens will be put behind "$" 01.05.2018

# # Load token list --> get exceptions for not being mistaken as acronyms
# coins_list <- read_csv("./1. Crawlers/Crypto-Markets_2018-04-30.csv")
# 
# tokens <- tolower(as.vector(unique(coins_list$symbol)))
# test <- as.data.frame(setdiff(myAbbrevs$abv,tokens))
# names(test) <- 'abv'
# # Keep only non-token abbreviations
# myAbbrevs <- dplyr::left_join(test,myAbbrevs, by = 'abv')
# rm(test)

# Convert dataframe to dictionary list
t_myAbbrevs <- t(myAbbrevs$rep)
names(t_myAbbrevs) <- myAbbrevs$abv

convertAbbreviations <- function(message){
  # Replaces abbreviation with the corresporending long form
  #
  # Args:
  #   text: Text to remove the abbreviations from
  #
  # Returns:
  #   String
  if(is.na(message) || message == ""){
    return(message)
  } else {
    message_split <- strsplit(message,"\\s")
    for (i in 1:lengths(message_split)){
      try(message_split[[1]][i] <- t_myAbbrevs[[message_split[[1]][i]]],
          silent = TRUE)
    }
    # Remerge list into string
    newText <- paste(unlist(message_split), collapse=' ')
    return (newText)
  }
}

# Tag POS 14.05
tagPOS_lemma <-  function(x, ...) {
  # POS original string
  s <- as.String(x)
  word_token_annotator <- Maxent_Word_Token_Annotator()
  a2 <- Annotation(1L, "sentence", 1L, nchar(s))
  a2 <- NLP::annotate(s, word_token_annotator, a2)
  a3 <- NLP::annotate(s, Maxent_POS_Tag_Annotator(), a2)
  a3w <- a3[a3$type == "word"]
  # Collect POS tagging
  POStags <- unlist(lapply(a3w$features, `[[`, "POS"))
  POStagged <- paste(sprintf("%s_%s", s[a3w], POStags), collapse = " ")
  
  gc() # garbage collection
  
  # Lemmatization then remerge with POS-tag
  x <- unlist(strsplit(POStagged," "))
  
  for (i in 1:length(x[[1]])){
    txt <- gsub("_[^_]+$", "", x[[1]][i]) # capture everything before "_"
    x[[1]][i] <- gsub("^[^_]+", "", x[[1]][1]) #replace the captured part with blank
    txt <- textstem::lemmatize_words(txt)
    # Re-add lemmatized string back to POS-tag
    x[[1]][i] <- paste0(txt,x[[1]][i])
  }
  result <- paste(x,collapse = " ")
  return(result)
}

###################################################################
Cleandata <- function(df) {
  # Cross-validating with list of Twitter_bots
  bots <- openxlsx::read.xlsx('~/GitHub/NextBigCrypto-Senti/0. Datasets/Twitter_Bot_Users_(Final).xlsx')
  df <- inner_join(df,bots, by = 'screen_name')
  df <- df %>% filter(botprob < 0.85| is.na(botprob)) # filter users that are >85% chance a bot

  # Convert unicode
  df$text <- sapply(df$text,function(x) trueunicode.hack(x))
  
  # remove duplicates base on tweets
  df <- df[!duplicated(df$text),]
  
  df$processed <- sapply(df$text, function(x) removeURL(x)) # remove URL
  # To lower case
  df$processed <- sapply(df$processed, function(x) tolower(x))
  df$processed <- sapply(df$processed, function(x) gsub("[.,]"," ", x, perl = TRUE)) #remove . and ,
  
  
  # Remove duplicates 
  df <- df[!duplicated(df$processed),]
  
  # converting abbreviations
  df$processed <- sapply(df$processed, function(x) convertAbbreviations(x))
  df$processed <- sapply(df$processed, function(x) conv_fun(x)) # convert to delete emojis
  df$processed <- sapply(df$processed, function(x) gsub("[\r\n]", " ", x)) #change /r /n break lines into space
  
  # remove stopwords - create exception lists 25.04
  exceptions   <- c('up','down','all','above','below','under','over',
                    'few','more', 'in')
  # keep negation list
  negations <- grep(pattern = "not|n't", x = stopwords(), value = TRUE)
  exceptions <- c(exceptions,negations)
  
  my_stopwords <- setdiff(stopwords("en"), exceptions)
  
  df$processed <- sapply(df$processed, function(x) removeWords(x,c(my_stopwords))) 
  
  ###########################################
  
  # Get rid of references to other screennames
  df$processed <- str_replace_all(df$processed,"@[a-z,A-Z,_]*"," ")  
  
  # remove punctuations except for # $ 
  df$processed <- sapply(df$processed, function(x) gsub( "[^#$a-zA-Z\\s]" , "" , x , perl = TRUE ))
  
  # Apply Apos to space
  df$processed <- sapply(df$processed, function(x) AposToSpace(x)) 
  
  # removing number 02.03.18
  df$processed <- sapply(df$processed, function(x) removeNumbers(x))
  
  # Remove left-overs
  df$processed <- sapply(df$processed, function(x) gsub("ff", " ",x))
  df$processed <- sapply(df$processed, function(x) gsub("# ", " ", x))
  df$processed <- sapply(df$processed, function(x) gsub(" f ", " ", x))
  
  # remove whitespace before & after
  df$processed <- sapply(df$processed, function(x) gsub("^[[:space:]]+", "",x))
  df$processed  <- sapply(df$processed, function(x) gsub("[[:space:]]+$", "",x))
  df$processed <- sapply(df$processed, function(x) stripWhitespace(x))
  
  # Remove blank processed messages
  df <- df[!(is.na(df$processed) | df$processed %in% c(""," ")), ]
  
  # Remove duplicates 
  df <- df[!duplicated(df$processed),]
  
  # Lemmatization 26.04.18
  df$processed <- sapply(df$processed, function(x) textstem::lemmatize_strings(x))
  
  return(df)
}

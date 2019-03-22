library(tidyverse)
data <- read_csv("./Data/Court outcomes by PFA 2017.csv")
region_map <- read_csv("./Data/PFA_Region_Mapping.csv")

data <- left_join(data, region_map) %>% 
  mutate(
    Country = ifelse(Region == "Wales/Cymru", "Wales", "England")
  )

data <- data %>%
  select(
    PFA = `Police Force Area`,
    region = Region,
    country = Country,
    year = `Year of Appearance`,
    quarter = Quarter,
    deft_type = `Type of Defendant`,
    sex = Sex,
    age_group = `Age Group`,
    age_range = `Age Range`,
    ethnicity = Ethnicity,
    court = `Court Type`,
    offence_type = `Offence Type`,
    offence_group = `Offence Group`,
    offence = offence,
    convicted_flag = `Convicted/Not Convicted`,
    sentenced_flag = `Sentenced/Not Sentenced`,
    outcome = Outcome,
    sentence = `Detailed Sentence`,
    custodial_sentence_length = `Custodial Sentence Length`,
    count = Count
  )
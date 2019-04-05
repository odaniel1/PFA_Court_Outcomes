source("./Scripts/load_clean_data.R")

data <- data %>%
  filter(
    year == 2017,
    deft_type == "01: Person",
    age_group == "03: Adults",
    court == "01: Crown Court",
    offence_type %in% c("01: Indictable only", "02: Triable Either Way"),
    convicted_flag == "01: Convicted",
    sentenced_flag == "01: Sentenced"
  ) %>%
  select( -year, - deft_type, -age_group, -court, -convicted_flag, -sentenced_flag)

data <- data %>% select(-PFA, -region, -country, -quarter, -age_range, -ethnicity, -offence, -sentence, - custodial_sentence_length)

data <- data %>% group_by_at(vars(-count, -outcome)) %>%
  summarise(
    count_IC = sum( count * ( outcome == "15: Immediate custody") ),
    count = sum(count),
    rate_IC = count_IC/count
  )

data <- data %>% arrange(offence_group, sex, offence_type)

write_csv(data, "./Data/adult_gender_IC_data.csv")

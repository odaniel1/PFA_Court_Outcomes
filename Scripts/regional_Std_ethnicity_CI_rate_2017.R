# Standardised Immediate Custody Rates by Region and Demographic for 2017.
#
# ===========================================
#
# In this script we produce Standardised Immediate Custody (IC) rates, and associated 
# credible intervals for sentenced defendants.
#
# Our standardisation process is done at a regional level, and we use Wales as the 
# reference region for standardisation.
#
# We restrict attention to:
#    - A region level analysis (following a note in the publication that data
#      at PFA level can be mislead by how TSJ cases are shared within regions).
#    - Sentenced offenders only, rather than the IC rate for all defendants (which
#      would include parties not found guilty).
#    - Defendants who are people, rather than companies, etc.
#    - Data from 2017.
#
# To produce credible intervals we assume that within regions IC rates are driven
# by binomially distributed samples, with rates distinguishable by all characteristics
# up to the level of:
#    - Year, so ignore quarterly differences.
#    - Age group, so ignore individual age ranges.
#    - Offence group, so do not consider individual offence codes.
#    - Outcome, so do not consider further details of sentences, or sentence lengths.
#
# Confidence intervals are derived using Jeffrey's method for binomial 
# confidence intervals; this is equivalent to the Bayesian credible interval that
# is obtained from using the Binomial Jeffrey's prior, the Beta(1/2,1/2) distribution.

# Read in prepared master data.
source("./Scripts/load_clean_data.R")

# Reduce to the data required for the current analysis:
data <- data %>% 
  filter(
    year == 2017,
    deft_type == "01: Person",
    sentenced_flag == "01: Sentenced"
  ) %>%
  select(-PFA, -quarter, -age_range, -offence, -sentence, -custodial_sentence_length)

# Summarise at a region level, including count of IC / not IC defendants.
region_data <- data %>% 
  group_by_at(vars(-count, -outcome)) %>%
  summarise(
    outcome_IC = sum(count * (outcome == "15: Immediate custody")),
    outcome_not_IC = sum(count * (outcome != "15: Immediate custody")),
    count = sum(count)
    # NOT RUN: count_check = outcome_IC + outcome_not_IC - count
  ) %>%
  ungroup()

# Get count data by stratum for Wales only, removing ethnicity.
wales_count_data <- data %>% 
  filter(region == "Wales/Cymru") %>%
  group_by_at(vars(-ethnicity, -count, -outcome)) %>%
  summarise(
    outcome_IC = sum(count * (outcome == "15: Immediate custody")),
    outcome_not_IC = sum(count * (outcome != "15: Immediate custody")),
    count = sum(count)
    # NOT RUN: count_check = outcome_IC + outcome_not_IC - count
  ) %>%
  ungroup() %>%
  select(-region, -country, -outcome_IC, - outcome_not_IC) %>% 
  rename(wales_count = count)

# Cross the Wales count data with the region_data, so that each entry of wales_count_data is 
# duplicated once for each region.
region_data_std <- wales_count_data %>%
  crossing(data_frame(ethnicity = unique(data$ethnicity))) %>%
  crossing(data_frame(region = unique(data$region))) %>%

  # Join this with the original region_data.
  left_join(region_data) %>%
  
  # Add zeros to any entries for outcome_IC, outcome_not_IC, and count where the original region
  # did not have any matching data.
  mutate(
    outcome_IC = ifelse( is.na(outcome_IC), 0, outcome_IC),
    outcome_not_IC = ifelse( is.na(outcome_not_IC), 0, outcome_not_IC),
    count = ifelse( is.na(count), 0, count)
  )

# 
# => Below we generate confidence intervals for the regional summaries.
#

# Calculate Bayesian posterior parameters in line with the Jeffreys prior. 
region_data_std <- region_data_std %>%
  mutate(
    alpha = outcome_IC + 1/2,
    beta  = outcome_not_IC + 1/2
  )

# Set random number seed.
set.seed(17880205)

# Generate samples from each posterior distribution; we use 1000 samples per stratum.
std_samples <- region_data_std %>% crossing(data_frame(sample_id = 1:1000)) %>%
  mutate(
    theta = rbeta(n = n(), shape1 = alpha, shape2 = beta),
    wales_outcome_IC = rbinom(n = n(), size = wales_count, prob = theta)
  )

# Aggregate to region and court level
region_std_samples <- std_samples %>%
  group_by(region, court, ethnicity, sample_id) %>%
  summarise(
    outcome_IC = sum(wales_outcome_IC),
    count = sum(wales_count),
    IC_rate = outcome_IC / count
  ) %>%
  ungroup()

# Obtain credible intervals for total CI rate for each region.
region_std_CredInt <- region_std_samples %>%
  group_by(region,ethnicity, court) %>%
  summarise(
    low95 = quantile(IC_rate, 0.025),
    mid50 = quantile(IC_rate, 0.5),
    hgh95 = quantile(IC_rate, 0.975)
  ) %>% ungroup()


#
# => Below we generate plots of the confidence regions. This still needs work to find the best way to demonstrate.
#

region_to_plot <- "London"

crown_ethnicity_std_CI_plot <-region_std_CredInt %>%
  filter(court == "01: Crown Court",
         region == region_to_plot) %>%
  mutate(
    ethnicity = fct_reorder(ethnicity, desc(mid50)),
    country = ifelse(region == "Wales/Cymru", "Wales", "England")
  ) %>%
  ggplot(aes(mid50, ethnicity)) + geom_point(shape = 3) + 
  geom_errorbarh(aes(xmin = low95, xmax = hgh95)) +
  scale_x_continuous(labels = scales::percent) +
  ggtitle("Crown Court Standardised Immediate Custody Rates and 95% Credible Intervals") +
  xlab("(Standardised) Immediate Custody Rate") + ylab("Ethnicity") + theme(legend.position="bottom")

ggsave("./Outputs/Plots/crown_std_CI_2017.png", crown_std_CI_plot, width=25, height=25, units="cm")

# Magistrates court plot.
mags_ethnicity_std_CI_plot <-region_std_CredInt %>%
  filter(court == "02: Magistrates Court",
         region == region_to_plot) %>%
  mutate(
    ethnicity = fct_reorder(ethnicity, desc(mid50)),
    country = ifelse(region == "Wales/Cymru", "Wales", "England")
  ) %>%
  ggplot(aes(mid50, ethnicity)) + geom_point(shape = 3) + 
  geom_errorbarh(aes(xmin = low95, xmax = hgh95)) +
  scale_x_continuous(labels = scales::percent) +
  ggtitle("Crown Court Standardised Immediate Custody Rates and 95% Credible Intervals") +
  xlab("(Standardised) Immediate Custody Rate") + ylab("Ethnicity") + theme(legend.position="bottom")

ggsave("./Outputs/Plots/mags_std_CI_2017.png", mags_std_CI_plot, width=25, height=25, units="cm")

# The plots for the magistrates court show an interesting pattern, with broad confidence intervals for all
# ethnicity profiles other than NA, centred around a much higher average CI rate.
# I'm guessing this is because there is some conditioning in the data whereby ethnicity is only recorded
# for defendants in the magistrates court if they go on to be sentenced, or commited to the crown.
# Need to look at this further.

# Clean up.
rm(list = ls())
gc()


# Immediate Custody Rates by Region for 2017.
#
# ===========================================
#
# In this script we produce Immediate Custody (IC) rates, and associated 
# credible intervals for sentenced defendants.
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

# Create summary data frame by region and court type.
region_summary <- region_data %>%
  group_by(region, country, court) %>%
  summarise(
    count = sum(count),
    outcome_IC = sum(outcome_IC),
    IC_rate = outcome_IC / count
  ) %>%
  ungroup()

# 
# => Below we generate confidence intervals for the regional summaries.
#

# Calculate Bayesian posterior parameters in line with the Jeffreys prior. 
region_data <- region_data %>%
  mutate(
    alpha = outcome_IC + 1/2,
    beta  = outcome_not_IC + 1/2
  )

# Set random number seed.
set.seed(17880205)

# Generate samples from each posterior distribution; we use 1000 samples per stratum.
samples <- region_data %>% crossing(data_frame(sample_id = 1:1000)) %>%
  mutate(
    theta = rbeta(n = n(), shape1 = alpha, shape2 = beta),
    outcome_IC = rbinom(n = n(), size = count, prob = theta)
  )

# Aggregate to region and court level
region_samples <- samples %>%
  group_by(region, court, sample_id) %>%
  summarise(
    outcome_IC = sum(outcome_IC),
    count = sum(count),
    IC_rate = outcome_IC / count
  ) %>%
  ungroup()

# Obtain credible intervals for total CI rate for each region.
region_CredInt <- region_samples %>%
  group_by(region, court) %>%
  summarise(
    low95 = quantile(IC_rate, 0.025),
    mid50 = quantile(IC_rate, 0.5),
    hgh95 = quantile(IC_rate, 0.975)
  ) %>% ungroup()

# Join credible intervals with the summary data frame.
region_summary <- left_join(region_summary, region_CredInt)

#
# => Below we generate plots of the confidence regions.
#

# Crown court plot.
region_summary %>%
  filter(court == "01: Crown Court",
         region != "Specialist") %>%
  mutate(
    region = fct_reorder(region, desc(IC_rate))
  ) %>%
  ggplot(aes(IC_rate, region, color = country)) + geom_point() + 
  geom_point(aes(mid50, region), shape = 3) +
  geom_errorbarh(aes(xmin = low95, xmax = hgh95)) +
  scale_color_manual(values = c("Wales" = "#F2300F", "England" = "#35274A")) +
  scale_x_continuous(labels = scales::percent) +
  ggtitle("Crown Court Immediate Custody Rates and 95% Credible Intervals") +
  xlab("Immediate Custody Rate") + ylab("Region")
  
# Crown court plot.
region_summary %>%
  filter(court == "02: Magistrates Court",
         region != "Specialist") %>%
  mutate(
    region = fct_reorder(region, desc(IC_rate))
  ) %>%
  ggplot(aes(IC_rate, region, color = country)) + geom_point() + 
  geom_point(aes(mid50, region), shape = 3) +
  geom_errorbarh(aes(xmin = low95, xmax = hgh95)) +
  scale_color_manual(values = c("Wales" = "#F2300F", "England" = "#35274A")) +
  scale_x_continuous(labels = scales::percent) +
  ggtitle("Magistrates Court Immediate Custody Rates and 95% Credible Intervals") +
  xlab("Immediate Custody Rate") + ylab("Region")

# Note: Both plots show a consistent mis-estimates of the center of the credible region,
# in relation to the observed IC rate: in the case of the Crown data estimates are consistently
# below observed, whilst in the magistrates court this is reversed.
#
# This could be improved by using more informative priors than the Jeffreys prior.


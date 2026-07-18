
# Set up working directory

setwd("********")


# Load packages
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(ggplot2)


# We use the RDS file because it preserves character, numeric and other R variable classes.
  
Local_Food_Broiler <- readRDS(
    "Local_Food_Broiler_2022.rds"
)

# We examine the data structure
dim(Local_Food_Broiler)
glimpse(Local_Food_Broiler)
names(Local_Food_Broiler)




# Set up the variables required to construct the Local Market Readiness index.
lmri_required_variables <- c(
  "operations_with_broiler_sales",
  "Population",
  "Income",
  "FarmersMarkets",
  "CSA",
  "OnFarmMarket",
  "FoodHubs"
)



# Let's confirm that the variables are numeric
Local_Food_Broiler %>%
  select(
    all_of(lmri_required_variables)
  ) %>%
  summarise(
    across(
      everything(),
      class
    )
  )



# We examine the variables to see if we should transform some of them

lmri_original_summary <- Local_Food_Broiler %>%
  summarise(
    across(
      all_of(lmri_required_variables),
      list(
        observations = ~ sum(!is.na(.x)),
        minimum = ~ min(.x, na.rm = TRUE),
        mean = ~ mean(.x, na.rm = TRUE),
        median = ~ median(.x, na.rm = TRUE),
        maximum = ~ max(.x, na.rm = TRUE),
        standard_deviation = ~ sd(.x, na.rm = TRUE)
      )
    )
  ) %>%
  pivot_longer(
    cols = everything(),
    names_to = c(
      "variable",
      ".value"
    ),
    names_pattern =
      "(.+)_(observations|minimum|mean|median|maximum|standard_deviation)$"
  )

lmri_original_summary



# Some of them are skwewd and have a lot of zeroes so we transform the

LMRI_data <- Local_Food_Broiler %>%
  mutate(
    # Preserve whether USDA originally reported a value.
    broiler_data_reported = if_else(
      is.na(operations_with_broiler_sales),
      0L,
      1L
    ),
    
    # Treat counties without a published broiler value as
    # having zero observable broiler operations for the index.
    operations_with_broiler_sales = replace_na(
      operations_with_broiler_sales,
      0
    ),
    
    # Transform broiler operations after replacing NA with zero.
    log_broiler_operations = log1p(
      operations_with_broiler_sales
    ),
    
    # Transform population.
    log_population = log1p(
      Population
    ),
    
    # Transform consumer-access count variables.
    log_farmers_markets = log1p(
      FarmersMarkets
    ),
    
    log_csa = log1p(
      CSA
    ),
    
    log_on_farm_markets = log1p(
      OnFarmMarket
    ),
    
    # Convert food hubs into a presence indicator.
    food_hub_presence = if_else(
      FoodHubs >= 1,
      1,
      0,
      missing = 0
    )
  )






# Now we define a min-max function that converts a numeric variable to a scale ranging from zero to one with the help of AI.
# Formula:
# (x - minimum) / (maximum - minimum)

min_max_normalize <- function(x) {
  
  # Calculate the minimum among nonmissing observations.
  x_min <- min(
    x,
    na.rm = TRUE
  )
  
  # Calculate the maximum among nonmissing observations.
  x_max <- max(
    x,
    na.rm = TRUE
  )
  
  # If all valid observations have the same value, return
  # zero for valid observations and preserve missing values. This prevents division by zero.
  
  if (
    isTRUE(
      all.equal(
        x_min,
        x_max
      )
    )
  ) {
    
    return(
      ifelse(
        is.na(x),
        NA_real_,
        0
      )
    )
  }
  
  # Apply min-max normalization.
  (
    x - x_min
  ) / (
    x_max - x_min
  )
}


# Now we use our function to normalize our LMRI index data

LMRI_data <- LMRI_data %>%
  mutate(
    # Normalize logged broiler operations.
    norm_broiler_operations = min_max_normalize(
      log_broiler_operations
    ),
    
    # Normalize logged population.
    norm_population = min_max_normalize(
      log_population
    ),
    
    # Normalize median household income without logging it.
    norm_income = min_max_normalize(
      Income
    ),
    
    # Normalize logged Farmers Markets.
    norm_farmers_markets = min_max_normalize(
      log_farmers_markets
    ),
    
    # Normalize logged CSA counts.
    norm_csa = min_max_normalize(
      log_csa
    ),
    
    # Normalize logged On-Farm Markets.
    norm_on_farm_markets = min_max_normalize(
      log_on_farm_markets
    )
  )



# Two counties have no median income data so we impute using the median of all counties in that state

LMRI_data <- LMRI_data %>%
  group_by(
    State
  ) %>%
  mutate(
    # Calculate the median income among counties in the
    # same state with reported income values.
    state_median_income = median(
      Income,
      na.rm = TRUE
    ),
    
    # Preserve an indicator showing whether income was
    # originally reported or imputed.
    income_imputed = if_else(
      is.na(Income),
      1L,
      0L
    ),
    
    # Replace missing county income with the state median.
    Income_for_LMRI = if_else(
      is.na(Income),
      state_median_income,
      Income
    )
  ) %>%
  ungroup()



# So we recalculate normalized income

LMRI_data <- LMRI_data %>%
  mutate(
    norm_income = min_max_normalize(
      Income_for_LMRI
    )
  )



# We first construct a producer base score. Producer Base consists only of normalized logged broiler operations.

LMRI_data <- LMRI_data %>%
  mutate(
    Producer_Base = norm_broiler_operations
  )


# Now we construct the Market Potential Score which comproises of equal weighting of Population and income.
LMRI_data <- LMRI_data %>%
  mutate(
    Market_Potential =
      0.50 * norm_population +
      0.50 * norm_income
  )



# Now we construct the Consumer Access Score which weights equally Farmers Markets, CSA and On-Farm Markets.
LMRI_data <- LMRI_data %>%
  mutate(
    Consumer_Access = (
      norm_farmers_markets +
        norm_csa +
        norm_on_farm_markets
    ) / 3
  )



# We construct the infrastructure score where Consumer Access receives 80 percent of the Infrastructure weight while
# Food Hub Presence receives the remaining 20 percent.
LMRI_data <- LMRI_data %>%
  mutate(
    Infrastructure =
      0.80 * Consumer_Access +
      0.20 * food_hub_presence
  )

# Now we construct the final LMRI 

LMRI_data <- LMRI_data %>%
  mutate(
    # Combine the three dimensions using the selected
    # dimension weights.
    LMRI =
      0.40 * Producer_Base +
      0.35 * Market_Potential +
      0.25 * Infrastructure,
    
  )


# We create a smaller county-level dataset containing the identifiers and the final Local Market Readiness Index.

LMRI_export <- LMRI_data %>%
  select(
    county_geoid,
    State,
    County,
    LMRI,
    Producer_Base,
    Market_Potential,
    Consumer_Access,
    Infrastructure
  )

# Save the dataset in the current working directory.
write_csv(
  LMRI_export,
  "County_Local_Market_Readiness_Index.csv"
)



# End of Code
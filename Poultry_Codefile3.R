

# Set up working directory
setwd("**************")

# Load pacakages
library(rnassqs)
library(readxl)
library(dplyr)
library(purrr)
library(stringr)
library(stringi)
library(readr)
library(tidyr)
library(ggplot2)
library(maps)
library(viridis)
library(tigris)
library(sf)



# We cache Census shapefiles after the first download. This prevents repeatedly downloading the same files.
options(tigris_use_cache = TRUE)

# Prevent scientific notation where possible. From chatgpt
options(scipen = 999)



# Use your NASS API key here
Sys.setenv(
  NASSQS_TOKEN = "***********"
)

# Authenticate using the API key stored in the environment.
nassqs_auth(
  key = Sys.getenv("NASSQS_TOKEN")
)




# We first download all county-level 2022 Census of Agriculture records related to broiler chickens.
broiler_2022_raw <- nassqs(
  source_desc      = "CENSUS",
  group_desc       = "POULTRY",
  commodity_desc   = "CHICKENS",
  agg_level_desc   = "COUNTY",
  short_desc__LIKE = "BROILER",
  year             = 2022
)

# We then examine the dimensions and variable names of the downloaded data.
dim(broiler_2022_raw)

names(broiler_2022_raw)

glimpse(broiler_2022_raw)



# We only keep the variable reporting the number of operations with broiler sales.
# The TOTAL and NOT SPECIFIED filters ensure that we retain the overall county total rather than a subgroup or category.

broiler_operations <- broiler_2022_raw %>%
  filter(
    short_desc ==
      "CHICKENS, BROILERS - OPERATIONS WITH SALES",
    
    domain_desc == "TOTAL",
    
    domaincat_desc == "NOT SPECIFIED"
  ) %>%
  transmute(
    # Standardized state name
    state_name = str_to_upper(
      str_trim(state_name)
    ),
    
    # Original NASS county name
    county_name_nass = str_to_upper(
      str_trim(county_name)
    ),
    
    # State FIPS must always contain two digits.
    state_fips = str_pad(
      as.character(state_fips_code),
      width = 2,
      side = "left",
      pad = "0"
    ),
    
    # County FIPS must always contain three digits.
    county_fips = str_pad(
      as.character(county_code),
      width = 3,
      side = "left",
      pad = "0"
    ),
    
    # Combine state and county FIPS to create the unique
    # five-digit county GEOID.
    county_geoid = paste0(
      state_fips,
      county_fips
    ),
    
    # Convert the NASS Value column from character to numeric.
    operations_with_broiler_sales =
      parse_number(
        as.character(Value)
      )
  )



# We examine the structure of the resulting dataset.
glimpse(broiler_operations)
nrow(broiler_operations)



# Histogram of the  number of broiler operations.
hist(
  broiler_operations$operations_with_broiler_sales,
  breaks = 50,
  main = "Distribution of Broiler Operations",
  xlab = "Operations with Broiler Sales"
)
# This shows that broiler sales is also very right skewed with a lot of zeroes




# we try to reduce the skew by transforming the variable using log(1 + x).
# log1p() is appropriate because it can accommodate zero values.
hist(
  log1p(
    broiler_operations$operations_with_broiler_sales
  ),
  breaks = 50,
  main = "Log-Transformed Broiler Operations",
  xlab = "log(1 + Operations)"
)



# We now import our self collected excel data of FAME variables
# Name of the Excel workbook containing the local-food measures.
file_name <- "Key_Local_Food_Metrics.xlsx"


# Display the sheet names to verify that all required sheets exist because each sheet in the file contains a different
# FAME food metric data point.
excel_sheets(file_name)


# We create a function to import each excel file
# Each sheet contains: State, County and One local-food measure.
# The function imports the sheet, renames the third column, cleans the state and county text, and retains only the
# necessary columns.

read_sheet <- function(sheet_name, value_name) {
  
  sheet_data <- read_excel(
    path = file_name,
    sheet = sheet_name
  )
  
  # Rename the third column using the desired variable name.
  names(sheet_data)[3] <- value_name
  
  sheet_data %>%
    mutate(
      State = str_to_upper(
        str_trim(State)
      ),
      
      County = str_squish(
        str_trim(County)
      )
    ) %>%
    select(
      State,
      County,
      all_of(value_name)
    )
}


# Now we import the local food metrics

# Total county population
population <- read_sheet(
  sheet_name = "Total Population",
  value_name = "Population"
)

# Median household income
income <- read_sheet(
  sheet_name = "Median HH Income",
  value_name = "Income"
)

# Percentage of farms selling directly to consumers
pct_direct <- read_sheet(
  sheet_name = "Farms Pct DirectConsumer",
  value_name = "FarmsPctDirectConsumer"
)

# Percentage of farms using local market channels
pct_local <- read_sheet(
  sheet_name = "Farms Pct LocalMktChannel",
  value_name = "FarmsPctLocalMkt"
)

# Percentage of farms selling directly
pct_sell <- read_sheet(
  sheet_name = "Farms Pct SellingDirect",
  value_name = "FarmsPctSellingDirect"
)

# Number of farmers markets
farmers_mkt <- read_sheet(
  sheet_name = "Farmers Markets",
  value_name = "FarmersMarkets"
)

# Number of CSA businesses
csa <- read_sheet(
  sheet_name = "CSA Businesses",
  value_name = "CSA"
)

# Number of food hubs
food_hubs <- read_sheet(
  sheet_name = "Food Hubs",
  value_name = "FoodHubs"
)

# Number of on-farm markets
on_farm <- read_sheet(
  sheet_name = "On Farm Market",
  value_name = "OnFarmMarket"
)





# Now we use population as the master county list to combine all other coynty food metrics by matching State and County.
# relationship = "one-to-one" ensures that each county appears


Local_Food <- population %>%
  left_join(
    income,
    by = c("State", "County"),
    relationship = "one-to-one"
  ) %>%
  left_join(
    pct_direct,
    by = c("State", "County"),
    relationship = "one-to-one"
  ) %>%
  left_join(
    pct_local,
    by = c("State", "County"),
    relationship = "one-to-one"
  ) %>%
  left_join(
    pct_sell,
    by = c("State", "County"),
    relationship = "one-to-one"
  ) %>%
  left_join(
    farmers_mkt,
    by = c("State", "County"),
    relationship = "one-to-one"
  ) %>%
  left_join(
    csa,
    by = c("State", "County"),
    relationship = "one-to-one"
  ) %>%
  left_join(
    food_hubs,
    by = c("State", "County"),
    relationship = "one-to-one"
  ) %>%
  left_join(
    on_farm,
    by = c("State", "County"),
    relationship = "one-to-one"
  )


# Inspect the combined local-food data.
glimpse(Local_Food)


# A missing value in these specific sheets is treated as zero.
# Note that this replacement is limited to the business-count variables and not population, income, or farm percentages.

count_cols <- c(
  "FarmersMarkets",
  "CSA",
  "FoodHubs",
  "OnFarmMarket"
)

Local_Food <- Local_Food %>%
  mutate(
    across(
      all_of(count_cols),
      ~ replace(
        .x,
        is.na(.x),
        0
      )
    )
  )




# Now we Create a key that retains the complete legal geographic name.
clean_full_county_key <- function(x) {
  
  x %>%
    stringi::stri_trans_general("Latin-ASCII") %>%
    str_to_upper() %>%
    str_squish() %>%
    str_replace(
      "^SAINT\\s+",
      "ST "
    ) %>%
    str_replace_all(
      "[^A-Z0-9]",
      ""
    )
}


# We create a base-name key that removes county-equivalent suffixes with the help of AI.
# Standalone "CITY" is not removed because it may be part of the
clean_base_county_key <- function(x) {
  
  x %>%
    stringi::stri_trans_general("Latin-ASCII") %>%
    str_to_upper() %>%
    str_squish() %>%
    str_replace(
      "^SAINT\\s+",
      "ST "
    ) %>%
    
    # Remove geographic suffixes.
    #
    # "CITY AND BOROUGH" is removed as a complete suffix,
    # but standalone "CITY" is deliberately retained.
    str_remove(
      paste0(
        "\\s+(",
        "CITY AND BOROUGH|",
        "CONSOLIDATED GOVERNMENT|",
        "UNIFIED GOVERNMENT|",
        "METROPOLITAN GOVERNMENT|",
        "PLANNING REGION|",
        "CENSUS AREA|",
        "MUNICIPALITY|",
        "BOROUGH|",
        "PARISH|",
        "COUNTY",
        ")$"
      )
    ) %>%
    str_replace_all(
      "[^A-Z0-9]",
      ""
    )
}




# Now we create standardized state and county matching variables for the Local_Food dataset.

Local_Food <- Local_Food %>%
  mutate(
    # Standardize the two-letter state abbreviation.
    state_alpha = str_to_upper(
      str_trim(State)
    ),
    
    # Preserve the original county name from the Excel workbook.
    county_name_original = County,
    
    # Create a complete county-name key.
    county_key_full = clean_full_county_key(
      County
    ),
    
    # Create the corrected base county-name key.
    county_key_base = clean_base_county_key(
      County
    )
  )


Local_Food %>%
  filter(
    State == "VA",
    County %in% c(
      "Charles City",
      "James City"
    )
  ) %>%
  select(
    State,
    County,
    county_key_full,
    county_key_base
  )




# Now we download the official 2022 county and county-equivalent geographic identifiers from the Census Bureau.

county_lookup <- counties(
  cb = TRUE,
  resolution = "20m",
  year = 2022,
  class = "sf"
) %>%
  st_drop_geometry() %>%
  transmute(
    # Two-letter state abbreviation.
    state_alpha = STUSPS,
    
    # Two-digit state FIPS code.
    state_fips = STATEFP,
    
    # Three-digit county FIPS code.
    county_fips = COUNTYFP,
    
    # Complete five-digit county GEOID.
    county_geoid = GEOID,
    
    # Official Census county or county-equivalent name.
    county_name_census = NAMELSAD,
    
    # Complete county-name matching key.
    county_key_full = clean_full_county_key(
      NAMELSAD
    ),
    
    # Corrected base county-name matching key.
    county_key_base = clean_base_county_key(
      NAMELSAD
    )
  )


# Now we restrict the lookup to keep only states represented in the Local_Food dataset.

county_lookup <- county_lookup %>%
  filter(
    state_alpha %in% unique(
      Local_Food$state_alpha
    )
  )


# Check the number of county records
nrow(county_lookup)


glimpse(county_lookup)




# Some geographic names may share the same base name within a state.So we keep only base names that occur once within each state so   #  that the second-stage match cannot assign an ambiguous county GEOID.

county_lookup_unique_base <- county_lookup %>%
  group_by(
    state_alpha,
    county_key_base
  ) %>%
  filter(
    n() == 1
  ) %>%
  ungroup()




# Now we match Local_Food counties to Census counties using: State abbreviation and Complete county-name key
# This should match counties whose legal geographic labels are already consistent across both datasets.

Local_Food_stage1 <- Local_Food %>%
  left_join(
    county_lookup %>%
      select(
        state_alpha,
        county_key_full,
        state_fips,
        county_fips,
        county_geoid,
        county_name_census
      ),
    
    by = c(
      "state_alpha",
      "county_key_full"
    ),
    
    relationship = "many-to-one"
  )


# We look at how the first stage match does

stage1_summary <- Local_Food_stage1 %>%
  summarise(
    total_counties = n(),
    
    exact_matches = sum(
      !is.na(county_geoid)
    ),
    
    unmatched_after_exact_match = sum(
      is.na(county_geoid)
    )
  )

stage1_summary
# We have 106 counties still unmatched so we move to a second stage



# Rename the geographic identifier variables so they do not overwrite the first-stage match variables during the join.

base_match_lookup <- county_lookup_unique_base %>%
  select(
    state_alpha,
    county_key_base,
    
    state_fips_base = state_fips,
    county_fips_base = county_fips,
    county_geoid_base = county_geoid,
    county_name_census_base = county_name_census
  )




# Now we match counties using state and the base county-name key.
# This resolves differences such as: County versus Parish, County versus Borough, County versus Census Area
# and County versus Planning Region
# Because the base lookup contains only unique names within each state, ambiguous geographic names are excluded.

Local_Food_stage2 <- Local_Food_stage1 %>%
  left_join(
    base_match_lookup,
    
    by = c(
      "state_alpha",
      "county_key_base"
    ),
    
    relationship = "many-to-one"
  )

# We now combine the 2 matching stages

Local_Food_with_geoid <- Local_Food_stage2 %>%
  mutate(
    # Identify counties matched during the exact-name stage.
    matched_exactly = !is.na(
      county_geoid
    ),
    
    # Identify counties matched only through the base-name stage.
    matched_by_base =
      is.na(county_geoid) &
      !is.na(county_geoid_base),
    
    # Retain the exact-match values where available.
    # Otherwise, use the second-stage base-name values.
    state_fips = coalesce(
      state_fips,
      state_fips_base
    ),
    
    county_fips = coalesce(
      county_fips,
      county_fips_base
    ),
    
    county_geoid = coalesce(
      county_geoid,
      county_geoid_base
    ),
    
    county_name_census = coalesce(
      county_name_census,
      county_name_census_base
    ),
    
    # Record how each county was matched.
    county_match_method = case_when(
      matched_exactly ~
        "Exact full-name match",
      
      matched_by_base ~
        "Unique base-name match",
      
      TRUE ~
        "Unmatched"
    )
  ) %>%
  
  # Remove temporary variables used in the second-stage match.
  select(
    -state_fips_base,
    -county_fips_base,
    -county_geoid_base,
    -county_name_census_base,
    -matched_exactly,
    -matched_by_base
  )



# We evaluate this match too
final_county_match_summary <- Local_Food_with_geoid %>%
  count(
    county_match_method,
    name = "number_of_counties"
  )

final_county_match_summary


final_geoid_summary <- Local_Food_with_geoid %>%
  summarise(
    total_counties = n(),
    
    counties_with_geoid = sum(
      !is.na(county_geoid)
    ),
    
    counties_without_geoid = sum(
      is.na(county_geoid)
    )
  )

final_geoid_summary
# Now all counties are matched successfully!






# Now we merge county-level broiler operations into the Local_Food dataset using the five-digit Census county GEOID.

Local_Food_Broiler <- Local_Food_with_geoid %>%
  left_join(
    broiler_operations %>%
      select(
        county_geoid,
        operations_with_broiler_sales
      ),
    
    by = "county_geoid",
    
    relationship = "one-to-one"
  )


glimpse(Local_Food_Broiler)

nrow(Local_Food_Broiler)




# We try not to immediately interpret every missing NASS value as zero.First create an indicator showing whether a county has a
# published broiler-operations observation in the extracted data.

Local_Food_Broiler <- Local_Food_Broiler %>%
  mutate(
    broiler_data_reported = if_else(
      !is.na(operations_with_broiler_sales),
      1L,
      0L
    )
  )


Local_Food_Broiler %>%
  count(
    broiler_data_reported
  )



# We save the matched data

write_csv(
  Local_Food_Broiler,
  "Local_Food_Broiler_2022.csv",
  na = ""
)



# We also save an RDS version that preserves the R variable classes.

saveRDS(
  Local_Food_Broiler,
  file = "Local_Food_Broiler_2022.rds"
)
 

# End of Code.




















































































































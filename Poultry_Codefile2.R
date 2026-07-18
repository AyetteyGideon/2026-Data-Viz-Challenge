

# Set up working directory
setwd("xxxxx")




# LOCAL PROCESSING ACCESS INDEX
# This section constructs county-level measures of access to federally inspected chicken-processing establishments.
# The primary access measures will focus on Small and Very Small establishments because they are more closely
# aligned with independent and local-market poultry systems.
# Large establishments will be measured separately as an indicator of industrial processing presence.




## Load the required packages
library(dplyr)
library(sf)
library(tigris)
library(stringr)
library(units)
library(ggplot2)
library(readr)




# We first download 2022 county boundaries because it matches the year of the Census of Agriculture production data.

us_counties <- counties(
  cb = TRUE,
  resolution = "20m",
  year = 2022
)



# We inspect the dimensions of the county file
dim(us_counties)




# We only keep counties in the contiguous United States

contiguous_counties <- us_counties |>
  filter(
    !STATEFP %in% c(
      "02",  # Alaska
      "15",  # Hawaii
      "72",  # Puerto Rico
      "60",  # American Samoa
      "66",  # Guam
      "69",  # Northern Mariana Islands
      "78"   # U.S. Virgin Islands
    )
  )




# We then create standardized county identification fields like GEOID is the five-digit county FIPS identifier.
# State and county names are retained so we can easily merge it with other datasets

contiguous_counties <- contiguous_counties |>
  transmute(
    county_geoid = GEOID,
    state_fips = STATEFP,
    county_fips = COUNTYFP,
    state_name = STATE_NAME,
    county_name = NAME,
    geometry
  )




# We transform county boundaries to the NAD83 / Conus Albers projected coordinate system EPSG 5070 uses meters as 
# its distance unit and is suitable for spatial calculations across the contiguous U.S.

contiguous_counties_5070 <- contiguous_counties |>
  st_transform(
    crs = 5070
  )



# We create county centroids. Since we do not have location of farms, we take that as representative location for
# each county from which processing accessibility is measured. 
# Source: U.S. Department of Agriculture, Agricultural Marketing Service. (2024). Inclusive Competition and Market 
# Integrity Under the Packers and Stockyards Act. Federal Register, 89(45), 16092–16199. Final Rule.

county_points_5070 <- contiguous_counties_5070 |>
  st_centroid()



# We import the merged FSIS processor dataset
fsis_chicken_processors <- read_csv(
  "fsis_chicken_processors_with_haccp_size.csv",
  show_col_types = FALSE
)


# Inspect the imported dataset
glimpse(fsis_chicken_processors)

dim(fsis_chicken_processors)

names(fsis_chicken_processors)



# Start with creating a dataset that has the variables we require - size, longitude, latitude 
processors_for_access <- fsis_chicken_processors |>
  filter(
    !is.na(latitude),
    !is.na(longitude),
    !is.na(haccp_size),
    haccp_size %in% c(
      "Large",
      "Small",
      "Very Small"
    )
  )



# We then extract the two-letter state abbreviation and retain establishments in the contiguous United States

processors_for_access <- processors_for_access |>
  mutate(
    state_alpha = str_extract(
      city_state,
      "[A-Z]{2}$"
    )
  ) |>
  filter(
    !state_alpha %in% c(
      "AK",
      "HI",
      "PR",
      "GU",
      "VI",
      "MP",
      "AS"
    )
  )




# We then convert processor coordinates to an sf point object Longitude is the x-coordinate and latitude is the y-coordinate.
# This makes those variables actual geographic points

processors_access_sf <- processors_for_access |>
  st_as_sf(
    coords = c(
      "longitude",
      "latitude"
    ),
    crs = 4326,
    remove = FALSE
  ) |>
  st_transform(
    crs = 5070
  )



# We then create separate processor datasets:
# Local-scale processors: Small and Very Small, because they are more likely to serve an independent producer
# Industrial processors:  Large


local_processors_sf <- processors_access_sf |>
  filter(
    haccp_size %in% c(
      "Small",
      "Very Small"
    )
  )


large_processors_sf <- processors_access_sf |>
  filter(
    haccp_size == "Large"
  )



# Confirm the number of processors in each group, since we have taken out those not in contiguous US

local_processor_counts <- processors_access_sf |>
  st_drop_geometry() |>
  count(
    haccp_size,
    name = "processors"
  )

local_processor_counts




# Define the local processing access radius. One mile equals 1,609.344 meters.Because EPSG 5070 uses meters,
# the 50-mile threshold must be converted to meters before calculating distances.


access_radius_miles <- 50

access_radius_meters <-access_radius_miles * 1609.344

access_radius_meters



# Now for each county we identify local-scale processors within 50 miles
# st_is_within_distance() returns a list.
# Each list element contains the row numbers of Small or Very Small processors located within 50 miles of a county's centroid


local_processors_within_50 <- st_is_within_distance(
  county_points_5070,
  local_processors_sf,
  dist = access_radius_meters
)



# We count the number of Small and Very Small processors found within 50 miles of each county point
county_points_5070$local_processors_50mi <-
  lengths(
    local_processors_within_50
  )


# Summarize the number of Small and Very Small processors within 50 miles
summary(
  county_points_5070$local_processors_50mi
)




# Calculate the distance from every county point to every Small or Very Small processor
# The result is a matrix:
# - rows represent counties;
# - columns represent processors;
# - each cell contains the distance in meters.

distance_to_local_processors <- st_distance(
  county_points_5070,
  local_processors_sf
)



# We identify the nearest Small or Very Small processor for every county apply(..., 1, min) finds the minimum distance across each
# county row of the distance matrix.
nearest_local_distance_meters <- apply(
  distance_to_local_processors,
  1,
  min
)



# We convert the nearest-processor distance from meters to miles
county_points_5070$nearest_local_processor_miles <-
  as.numeric(
    nearest_local_distance_meters
  ) /
  1609.344



# We summarize county distances to the nearest Small or Very Small chicken-processing establishment
summary(
  county_points_5070$nearest_local_processor_miles
)



# Now we also identify Large processors within 50 miles. This measure will not enter the Local Processing Access
# Index. It will be retained separately as an indicator of industrial processing presence.

large_processors_within_50 <- st_is_within_distance(
  county_points_5070,
  large_processors_sf,
  dist = access_radius_meters
)



# We now count Large establishments within 50 miles of each county

county_points_5070$large_processors_50mi <-
  lengths(
    large_processors_within_50
  )



# Create a nonspatial county-level processing access dataset
# The dataset contains - county identifiers; local processor count within 50 miles; distance to nearest local processor;
# Large processor count within 50 miles; distance to nearest Large processor.


county_processing_access <- county_points_5070 |>
  st_drop_geometry() |>
  select(
    county_geoid,
    state_name,
    state_fips,
    county_name,
    county_fips,
    local_processors_50mi,
    nearest_local_processor_miles,
    large_processors_50mi
  )



# Inspect the completed raw processing-access measures
glimpse(county_processing_access)



# Looking at distribution of processors
hist(
  county_processing_access$local_processors_50mi,
  breaks = 60,
  main = "Processors within 50 miles",
  xlab = "Number of Small and Very Small Processors"
)


summary(
  county_processing_access$local_processors_50mi
)

quantile(
  county_processing_access$local_processors_50mi,
  probs = c(.90,.95,.99)
)
# Median = 6.597, 3rd quartile = 6, max = 182
#So the access variable is very skewed





# CONSTRUCTION THE LOCAL PROCESSING ACCESS INDEX
# The index combines three equally weighted components:
# 1. Availability: Number of Small and Very Small processors within  50 miles.
# 2. Proximity: Distance to the nearest Small or Very Small processor.
# 3. Local orientation: Share of all processors within 50 miles that are Small or Very Small.
# Each component ranges from 0 to 1. The final index is the simple average of the three components.


# We define the availability cap. We use 95th percentile of the local processor count of 25 as cap.
# Counts above 25 are therefore assigned the same maximum availability score.
availability_cap <- 25



# We construct the three index components
county_processing_access <- county_processing_access |>
  mutate(
    

# COMPONENT 1: Availability score
# The processor count is capped at 25 and transformed using the natural logarithm.
# The denominator scales the transformed count so the score ranges from 0 to 1.
    
    
    availability_score =
      log1p(
        pmin(
          local_processors_50mi,
          availability_cap
        )
      ) /
      log1p(
        availability_cap
      ),
    
    

# COMPONENT 2: Proximity score
# The score declines linearly from: 1 at zero miles,0 at 50 miles or more. The original distance variable is not changed.
    
    proximity_score =
      pmax(
        0,
        1 -
          nearest_local_processor_miles / 50
      ),
    
    

# COMPONENT 3: Local orientation score
# This measures the share of processors within 50 miles that are Small or Very Small.
# Counties with no processors of any size within 50 miles receive a score of zero.
    
    local_orientation_score =
      if_else(
        local_processors_50mi +
          large_processors_50mi > 0,
        
        local_processors_50mi /
          (
            local_processors_50mi +
              large_processors_50mi
          ),
        
        0
      ),
    
    

# FINAL LOCAL PROCESSING ACCESS INDEX
# Equal weights are used because there is no established empirical basis for assigning different importance to
# the three dimensions.

    
    local_processing_access_index =
      (
        availability_score +
          proximity_score +
          local_orientation_score
      ) / 3
  )




# We look at selected percentiles of the final index

quantile(
  county_processing_access$
    local_processing_access_index,
  probs = c(
    0,
    0.10,
    0.25,
    0.50,
    0.75,
    0.90,
    0.95,
    0.99,
    1
  ),
  na.rm = TRUE
)
    


# Save the completed county processing-access file
write_csv(
  county_processing_access,
  "county_local_processing_access_index.csv"
)


###### End of Code #########
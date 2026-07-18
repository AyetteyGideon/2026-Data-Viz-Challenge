
# FSIS CHICKEN PROCESSING DATA:
# IMPORT, CLEAN, MERGE HACCP SIZE, AND VALIDATE
# This script:
# 1. Sets the working directory.
# 2. Loads the required packages.
# 3. Imports the four Tableau files.
# 4. Preserves ZIP codes as five-character text fields.
# 5. Standardizes establishment identifiers.
# 6. Checks for missing and duplicate establishment numbers.
# 7. Creates a HACCP-size lookup.
# 8. Merges HACCP size into the complete establishment file.




# Set the working directory
# All four Tableau files should be saved in this folder.

# setwd(**************)



# Load the required packages


library(readr)
library(dplyr)
library(stringr)



# Import the All Sizes Tableau file
# Tableau exported the data as a UTF-16LE tab-delimited file,even though the filename ends in .csv.
# This is so that Postal Code is imported as character so leading zeros are preserved.
# For example, 06516 remains 06516 rather than becoming 6516.

fsis_chicken_all <- read_tsv(
  "fsis_chicken_all_sizes.csv",
  
  locale = locale(
    encoding = "UTF-16LE"
  ),
  
  col_types = cols(
    `Postal Code` = col_character()
  ),
  
  name_repair = "unique",
  show_col_types = FALSE
)


# Import the Large establishment file

fsis_chicken_large <- read_tsv(
  "fsis_chicken_large.csv",
  
  locale = locale(
    encoding = "UTF-16LE"
  ),
  
  col_types = cols(
    `Postal Code` = col_character()
  ),
  
  name_repair = "unique",
  show_col_types = FALSE
)


# Import the Small establishment file


fsis_chicken_small <- read_tsv(
  "fsis_chicken_small.csv",
  
  locale = locale(
    encoding = "UTF-16LE"
  ),
  
  col_types = cols(
    `Postal Code` = col_character()
  ),
  
  name_repair = "unique",
  show_col_types = FALSE
)



# Import the Very Small establishment file


fsis_chicken_very_small <- read_tsv(
  "fsis_chicken_very_small.csv",
  
  locale = locale(
    encoding = "UTF-16LE"
  ),
  
  col_types = cols(
    `Postal Code` = col_character()
  ),
  
  name_repair = "unique",
  show_col_types = FALSE
)


# Inspect the dimensions of the four files

dim(fsis_chicken_all)
dim(fsis_chicken_large)
dim(fsis_chicken_small)
dim(fsis_chicken_very_small) #The individual size sets sum up to the dimension of the full set 


# Inspect the imported column names

names(fsis_chicken_all)



# Rename the main variables in each dataset to make it easier to code with

fsis_chicken_all <- fsis_chicken_all |>
  rename(
    address = AddressLine11,
    city_state = `City State`,
    establishment_name = `Establishment Name`,
    establishment_number = `Establishment Number`,
    inspection_activities = `Inspection Activities`,
    main_phone_number = `Main Phone Number`,
    postal_code = `Postal Code`,
    salmonella_category = map_cat_tooltip,
    salmonella_category_window =
      `Salmonella Category Window`,
    latitude = `Latitude (generated)`,
    longitude = `Longitude (generated)`
  )

fsis_chicken_large <- fsis_chicken_large |>
  rename(
    address = AddressLine11,
    city_state = `City State`,
    establishment_name = `Establishment Name`,
    establishment_number = `Establishment Number`,
    inspection_activities = `Inspection Activities`,
    main_phone_number = `Main Phone Number`,
    postal_code = `Postal Code`,
    salmonella_category = map_cat_tooltip,
    salmonella_category_window =
      `Salmonella Category Window`,
    latitude = `Latitude (generated)`,
    longitude = `Longitude (generated)`
  )

fsis_chicken_small <- fsis_chicken_small |>
  rename(
    address = AddressLine11,
    city_state = `City State`,
    establishment_name = `Establishment Name`,
    establishment_number = `Establishment Number`,
    inspection_activities = `Inspection Activities`,
    main_phone_number = `Main Phone Number`,
    postal_code = `Postal Code`,
    salmonella_category = map_cat_tooltip,
    salmonella_category_window =
      `Salmonella Category Window`,
    latitude = `Latitude (generated)`,
    longitude = `Longitude (generated)`
  )

fsis_chicken_very_small <- fsis_chicken_very_small |>
  rename(
    address = AddressLine11,
    city_state = `City State`,
    establishment_name = `Establishment Name`,
    establishment_number = `Establishment Number`,
    inspection_activities = `Inspection Activities`,
    main_phone_number = `Main Phone Number`,
    postal_code = `Postal Code`,
    salmonella_category = map_cat_tooltip,
    salmonella_category_window =
      `Salmonella Category Window`,
    latitude = `Latitude (generated)`,
    longitude = `Longitude (generated)`
  )



# Standardize establishment numbers and ZIP codes by converting establishment numbers to uppercase and
# unnecessary spaces are removed. ZIP codes are added to five characters so any leading zeros are preserved.

fsis_chicken_all <- fsis_chicken_all |>
  mutate(
    establishment_number =
      establishment_number |>
      str_squish() |>
      str_to_upper(),
    
    postal_code = str_pad(
      postal_code,
      width = 5,
      side = "left",
      pad = "0"
    )
  )

fsis_chicken_large <- fsis_chicken_large |>
  mutate(
    establishment_number =
      establishment_number |>
      str_squish() |>
      str_to_upper(),
    
    postal_code = str_pad(
      postal_code,
      width = 5,
      side = "left",
      pad = "0"
    )
  )

fsis_chicken_small <- fsis_chicken_small |>
  mutate(
    establishment_number =
      establishment_number |>
      str_squish() |>
      str_to_upper(),
    
    postal_code = str_pad(
      postal_code,
      width = 5,
      side = "left",
      pad = "0"
    )
  )

fsis_chicken_very_small <- fsis_chicken_very_small |>
  mutate(
    establishment_number =
      establishment_number |>
      str_squish() |>
      str_to_upper(),
    
    postal_code = str_pad(
      postal_code,
      width = 5,
      side = "left",
      pad = "0"
    )
  )



# Remove empty Tableau fields that are not needed

fsis_chicken_all <- fsis_chicken_all |>
  select(
    -any_of(
      c(
        "Namelsad...8",
        "Namelsad...9",
        "Geometry",
        "EstablishmentMakePoint"
      )
    )
  )

fsis_chicken_large <- fsis_chicken_large |>
  select(
    -any_of(
      c(
        "Namelsad...8",
        "Namelsad...9",
        "Geometry",
        "EstablishmentMakePoint"
      )
    )
  )

fsis_chicken_small <- fsis_chicken_small |>
  select(
    -any_of(
      c(
        "Namelsad...8",
        "Namelsad...9",
        "Geometry",
        "EstablishmentMakePoint"
      )
    )
  )

fsis_chicken_very_small <- fsis_chicken_very_small |>
  select(
    -any_of(
      c(
        "Namelsad...8",
        "Namelsad...9",
        "Geometry",
        "EstablishmentMakePoint"
      )
    )
  )




# Check for duplicate establishment numbers

duplicate_all_establishments <- fsis_chicken_all |>
  count(
    establishment_number,
    name = "records_per_establishment"
  ) |>
  filter(
    records_per_establishment > 1
  )

duplicate_large_establishments <- fsis_chicken_large |>
  count(
    establishment_number,
    name = "records_per_establishment"
  ) |>
  filter(
    records_per_establishment > 1
  )

duplicate_small_establishments <- fsis_chicken_small |>
  count(
    establishment_number,
    name = "records_per_establishment"
  ) |>
  filter(
    records_per_establishment > 1
  )

duplicate_very_small_establishments <-
  fsis_chicken_very_small |>
  count(
    establishment_number,
    name = "records_per_establishment"
  ) |>
  filter(
    records_per_establishment > 1
  )



# Display all duplicate checks

duplicate_all_establishments
duplicate_large_establishments
duplicate_small_establishments
duplicate_very_small_establishments




# Create one HACCP-size lookup table because our problem is the data from the FSIS website when downloaded does not include the size classification
# That is what leads us to filtering for each size and downloading those as separate files. So in essence what we are doing is 
# establish ment in the say small file, we will tag it small and repeat for large aand very small files too.
# So when we combine all 3 datasets, we can have a variable that gives the size classification for each establishment.

large_size_lookup <- fsis_chicken_large |>
  transmute(
    establishment_number,
    haccp_size = "Large"
  )

small_size_lookup <- fsis_chicken_small |>
  transmute(
    establishment_number,
    haccp_size = "Small"
  )

very_small_size_lookup <- fsis_chicken_very_small |>
  transmute(
    establishment_number,
    haccp_size = "Very Small"
  )



# Now Combine the three size lookup tables

haccp_size_lookup <- bind_rows(
  large_size_lookup,
  small_size_lookup,
  very_small_size_lookup
) |>
  distinct(
    establishment_number,
    haccp_size
  )





# Merge HACCP size into the complete All Sizes establishment dataset. We use a left join to retain every establishment 
# from the complete Tableau download.

fsis_chicken_processors <- fsis_chicken_all |>
  left_join(
    haccp_size_lookup,
    by = "establishment_number"
  )


# We Confirm that the merge did not change the number of establishment records

nrow(fsis_chicken_all)
nrow(fsis_chicken_processors)




# Now we inspect the final merged dataset
glimpse(fsis_chicken_processors)

View(fsis_chicken_processors)



# Save the merged FSIS chicken-processing dataset

write_csv(
  fsis_chicken_processors,
  "fsis_chicken_processors_with_haccp_size.csv"
)


# End of Code!





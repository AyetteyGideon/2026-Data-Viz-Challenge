

# Load packages
library(dplyr)
library(readr)
library(stringr)
library(sf)
library(tigris)
library(ggplot2)
library(scales)
library(readxl)
library(ggrepel)
library(patchwork)
library(grid)


# Allow Census boundary files to be cached.
options(tigris_use_cache = TRUE)

# Set the working directory 
setwd("*************")


# Load in Local Poultry Market Readiness Index data
lpmri_data <- read_csv("County_Local_Market_Readiness_Index.csv",
  show_col_types = FALSE)

# We check the structure of the imported dataset.
dim(lpmri_data)
names(lpmri_data)




# We now also Load in the Local Poultry Proxessing Access Index
processing_access_data <- read_csv("County_Local_Processing_Access_Index.csv",
  show_col_types = FALSE)

# We check the structure here too

dim(processing_access_data)
names(processing_access_data)





# Now we try to set up the two index datafiles for merging. We will keep the relevant LPMRI variables and ensure GEOID is
# stored as a five-character text variable.

lpmri_for_merge <- lpmri_data %>%
  transmute(
    county_geoid = str_pad(
      as.character(
        county_geoid
      ),
      width = 5,
      side = "left",
      pad = "0"
    ),
    
    State,
    County,
    LPMRI = LMRI,
    LPMRI_100 = LMRI_100,
    Producer_Base,
    Market_Potential,
    Consumer_Access,
    Infrastructure
  )



# Same for relevant processing-access variables 

processing_for_merge <- processing_access_data %>%
  transmute(
    county_geoid = str_pad(
      as.character(
        county_geoid
      ),
      width = 5,
      side = "left",
      pad = "0"
    ),
    
    state_name,
    county_name,
    local_processors_50mi,
    nearest_local_processor_miles,
    large_processors_50mi,
    availability_score,
    proximity_score,
    local_orientation_score,
    Local_Processing_Access_Index =
      local_processing_access_index
  )





# Now we both indexes
combined_index_data <- processing_for_merge %>%
  left_join(
    lpmri_for_merge,
    by = "county_geoid"
  )

combined_index_data %>%
  summarise(
    total_counties = n(),
    
    counties_with_processing_index = sum(
      !is.na(Local_Processing_Access_Index)
    ),
    
    counties_with_lpmri = sum(
      !is.na(LPMRI)
    ),
    
    counties_with_both_indices = sum(
      !is.na(Local_Processing_Access_Index) &
        !is.na(LPMRI)
    ),
    
    counties_missing_lpmri = sum(
      is.na(LPMRI)
    )
  )




##  Now we Calculate The Local Poultry Market Opportunity Index. This is calculated as the harmonic mean of Local 
# Poultry Market Readiness Index and Local Processing Access Index
# The harmonic mean gives a lower score when either component is weak. This reflects the idea that strong market readiness
# cannot fully compensate for poor processing access, and strong processing access cannot fully compensate for weak
# market readiness.

combined_index_data <- combined_index_data %>%
  mutate(
    LPMOI = if_else(
      LPMRI + Local_Processing_Access_Index == 0,
      0,
      (
        2 *
          LPMRI *
          Local_Processing_Access_Index
      ) / (
        LPMRI +
          Local_Processing_Access_Index
      )
    ),
    
    # Create a 0-to-100 version for presentation.
    
    LPMOI_100 = 100 * LPMOI
  )



# Let's save the final index
write_csv(
  combined_index_data,
  "County_Local_Poultry_Market_Opportunity_Index.csv"
)




# Now we prepare for visualization
# We use the actual observed range of the Local Poultry Market Opportunity Index for the continuous color scale.

lpmoi_map_minimum <- min(
  combined_index_data$LPMOI,
  na.rm = TRUE
)

lpmoi_map_maximum <- max(
  combined_index_data$LPMOI,
  na.rm = TRUE
)

# We create six evenly spaced legend values.

lpmoi_legend_breaks <- seq(
  from = lpmoi_map_minimum,
  to = lpmoi_map_maximum,
  length.out = 6
)

# Display the map range and legend breaks.
lpmoi_map_minimum
lpmoi_map_maximum
lpmoi_legend_breaks


#Now we load the US county and state boundaries using tigris. Using cb = TRUE produces cartographic boundary files,
# which are smaller and more suitable for national maps.

us_counties <- tigris::counties(
  cb = TRUE,
  year = 2022,
  class = "sf"
)

# Download generalized 2022 state boundaries.

us_states <- tigris::states(
  cb = TRUE,
  year = 2022,
  class = "sf"
)


# We keep only contiguous US states by noting the non-contiguous ones

non_contiguous_fips <- c(
  "02",
  "15",
  "60",
  "66",
  "69",
  "72",
  "78"
)

# We retain only contiguous U.S. counties.
contiguous_us_counties <- us_counties %>%
  filter(
    !STATEFP %in% non_contiguous_fips
  )

# and now for states
contiguous_us_states <- us_states %>%
  filter(
    !STATEFP %in% non_contiguous_fips
  )



# We prepare LPMOI for the map with the help of AI
lpmoi_map_data <- combined_index_data %>%
  transmute(
    county_geoid = str_pad(
      as.character(
        county_geoid
      ),
      width = 5,
      side = "left",
      pad = "0"
    ),
    
    state_name,
    county_name,
    
    # Retain the two component indices.
    
    LPMRI,
    Local_Processing_Access_Index,
    
    # Retain the final opportunity index and its
    # 0-to-100 version.
    
    LPMOI,
    LPMOI_100
  )




# Join the Index to county boundaries
lpmoi_county_map <- contiguous_us_counties %>%
  left_join(
    lpmoi_map_data,
    by = c(
      "GEOID" = "county_geoid"
    )
  )



# We transform counties to the current equal-area projection recommended as a replacement for EPSG 2163 with the help of AI.
lpmoi_county_map <- lpmoi_county_map %>%
  st_transform(
    crs = 9311
  )

# We apply the same coordinate reference system to state boundaries.
contiguous_us_states <- contiguous_us_states %>%
  st_transform(
    crs = 9311
  )




# Let's read in Poultry MCAP funded plants data
mcap_plants <- read_excel(
  "MCAPData.xlsx"
)

mcap_plants_clean <- mcap_plants %>%
  filter(
    !is.na(latitude),
    !is.na(longitude),
    !is.na(state)
  )


# We will convert the latitude and longitude into spatial points

mcap_plants_sf <- mcap_plants_clean %>%
  st_as_sf(
    coords = c(
      "longitude",
      "latitude"
    ),
    crs = 4326,
    remove = FALSE
  ) %>%
  st_transform(
    crs = st_crs(
      lpmoi_county_map
    )
  )


# We will define our comparison regions

northeast_states <- c(
  "CT",
  "ME",
  "MA",
  "NH",
  "RI",
  "VT",
  "NJ",
  "NY",
  "PA"
)

southeast_states <- c(
  "AR",
  "AL",
  "GA",
  "MS"
)

# Now we filter counties by regions
northeast_counties_sf <- lpmoi_county_map %>%
  filter(
    STUSPS %in% northeast_states
  )

southeast_counties_sf <- lpmoi_county_map %>%
  filter(
    STUSPS %in% southeast_states
  )


# And filter boundaries by regions too
northeast_states_sf <- contiguous_us_states %>%
  filter(
    STUSPS %in% northeast_states
  ) %>%
  st_transform(
    st_crs(
      lpmoi_county_map
    )
  )

southeast_states_sf <- contiguous_us_states %>%
  filter(
    STUSPS %in% southeast_states
  ) %>%
  st_transform(
    st_crs(
      lpmoi_county_map
    )
  )


# Now we filter MCAP funded plants by region
northeast_mcap_sf <- mcap_plants_sf %>%
  filter(
    state %in% northeast_states
  )

southeast_mcap_sf <- mcap_plants_sf %>%
  filter(
    state %in% southeast_states
  )


# With the help of AI, we create positions where we will label states
northeast_state_labels <- northeast_states_sf %>%
  st_point_on_surface()

southeast_state_labels <- southeast_states_sf %>%
  st_point_on_surface()


northeast_state_coordinates <- st_coordinates(
  northeast_state_labels
)

northeast_state_labels <- northeast_state_labels %>%
  mutate(
    label_x = northeast_state_coordinates[, 1],
    label_y = northeast_state_coordinates[, 2]
  )


southeast_state_coordinates <- st_coordinates(
  southeast_state_labels
)

southeast_state_labels <- southeast_state_labels %>%
  mutate(
    label_x = southeast_state_coordinates[, 1],
    label_y = southeast_state_coordinates[, 2]
  )


# We do same for plants
northeast_plant_coordinates <- st_coordinates(
  northeast_mcap_sf
)

northeast_mcap_labels <- northeast_mcap_sf %>%
  st_drop_geometry() %>%
  mutate(
    label_x = northeast_plant_coordinates[, 1],
    label_y = northeast_plant_coordinates[, 2],
    
    plant_label = establishment_name %>%
      str_remove(", LLC$") %>%
      str_remove(" LLC$") %>%
      str_remove(", Inc\\.$") %>%
      str_remove(" Inc\\.$") %>%
      str_remove(", Ltd\\.$") %>%
      str_remove(" Ltd\\.$") %>%
      str_remove(" Cooperative$")
  )



southeast_plant_coordinates <- st_coordinates(
  southeast_mcap_sf
)

southeast_mcap_labels <- southeast_mcap_sf %>%
  st_drop_geometry() %>%
  mutate(
    label_x = southeast_plant_coordinates[, 1],
    label_y = southeast_plant_coordinates[, 2],
    
    plant_label = establishment_name %>%
      str_remove(", LLC$") %>%
      str_remove(" LLC$") %>%
      str_remove(", Inc\\.$") %>%
      str_remove(" Inc\\.$") %>%
      str_remove(", Ltd\\.$") %>%
      str_remove(" Ltd\\.$") %>%
      str_remove(" Cooperative$")
  )

# Now we define our colour scale for the visualizaton
# Use the full national LPMOI range so the colors mean the
# same thing in the Northeast and Southeast maps.

common_lpmoi_limits <- range(
  lpmoi_county_map$LPMOI,
  na.rm = TRUE
)

common_lpmoi_breaks <- pretty(
  common_lpmoi_limits,
  n = 5
)

common_lpmoi_scale <- scale_fill_gradientn(
  colours = c(
    "#f7fcf5",
    "#e5f5e0",
    "#c7e9c0",
    "#a1d99b",
    "#74c476",
    "#41ab5d",
    "#238b45",
    "#005a32"
  ),
  
  limits = common_lpmoi_limits,
  breaks = common_lpmoi_breaks,
  
  labels = scales::label_number(
    accuracy = 0.01
  ),
  
  oob = scales::squish,
  na.value = "grey90",
  
  name = paste(
    "Local Poultry Market",
    "Opportunity Index"
  )
)

# We create the Northeast map with the help of AI to make it look better
northeast_map <- ggplot() +
  
  geom_sf(
    data = northeast_counties_sf,
    aes(
      fill = LPMOI
    ),
    color = "white",
    linewidth = 0.12
  ) +
  
  geom_sf(
    data = northeast_states_sf,
    fill = NA,
    color = "grey20",
    linewidth = 0.65
  ) +
  
  geom_sf(
    data = northeast_mcap_sf,
    aes(
      color = "MCAP-awarded plant"
    ),
    shape = 21,
    fill = "red",
    size = 3,
    stroke = 0.6,
    alpha = 0.95
  ) +
  
  geom_text(
    data = northeast_state_labels,
    aes(
      x = label_x,
      y = label_y,
      label = STUSPS
    ),
    size = 5,
    fontface = "bold",
    color = "black"
  ) +
  
  geom_text_repel(
    data = northeast_mcap_labels,
    aes(
      x = label_x,
      y = label_y,
      label = plant_label
    ),
    size = 3,
    fontface = "plain",
    color = "grey20",
    box.padding = 0.4,
    point.padding = 0.3,
    min.segment.length = 0,
    segment.color = "grey40",
    segment.size = 0.3,
    max.overlaps = Inf,
    seed = 123
  ) +
  
  common_lpmoi_scale +
  
  scale_color_manual(
    values = c(
      "MCAP-awarded plant" = "red"
    ),
    name = NULL
  ) +
  
  coord_sf(
    datum = NA,
    expand = FALSE
  ) +
  
  labs(
    title = "Northeastern Consumer Markets",
    
    subtitle = paste0(
      "Connecticut (CT) • Maine (ME) • Massachusetts (MA) • ",
      "New Hampshire (NH) • Rhode Island (RI)\n",
      "Vermont (VT) • New Jersey (NJ) • New York (NY) • ",
      "Pennsylvania (PA)"
    )
  ) +
  
  theme_void() +
  
  theme(
    plot.title = element_text(
      size = 17,
      face = "bold",
      hjust = 0.5,
      margin = margin(
        b = 5
      )
    ),
    
    plot.subtitle = element_text(
      size = 8.5,
      hjust = 0.5,
      lineheight = 1.15,
      margin = margin(
        b = 10
      )
    ),
    
    legend.position = "bottom",
    
    legend.box = "vertical",
    
    legend.title = element_text(
      size = 9,
      face = "bold"
    ),
    
    legend.text = element_text(
      size = 8
    ),
    
    plot.margin = margin(
      t = 10,
      r = 10,
      b = 10,
      l = 10
    )
  ) +
  
  guides(
    fill = guide_colorbar(
      title.position = "top",
      title.hjust = 0.5,
      barwidth = unit(
        4.5,
        "in"
      ),
      barheight = unit(
        0.18,
        "in"
      ),
      direction = "horizontal",
      order = 1
    ),
    
    color = guide_legend(
      override.aes = list(
        shape = 21,
        fill = "red",
        color = "red",
        size = 3
      ),
      order = 2
    )
  )




# And now we create the Southeast map
southeast_map <- ggplot() +
  
  geom_sf(
    data = southeast_counties_sf,
    aes(
      fill = LPMOI
    ),
    color = "white",
    linewidth = 0.12
  ) +
  
  geom_sf(
    data = southeast_states_sf,
    fill = NA,
    color = "grey20",
    linewidth = 0.65
  ) +
  
  geom_sf(
    data = southeast_mcap_sf,
    aes(
      color = "MCAP-awarded plant"
    ),
    shape = 21,
    fill = "red",
    size = 3,
    stroke = 0.6,
    alpha = 0.95
  ) +
  
  geom_text(
    data = southeast_state_labels,
    aes(
      x = label_x,
      y = label_y,
      label = STUSPS
    ),
    size = 5,
    fontface = "bold",
    color = "black"
  ) +
  
  geom_text_repel(
    data = southeast_mcap_labels,
    aes(
      x = label_x,
      y = label_y,
      label = plant_label
    ),
    size = 3.4,
    fontface = "bold",
    color = "#5C0000",
    box.padding = 0.4,
    point.padding = 0.3,
    min.segment.length = 0,
    segment.color = "#7A0000",
    segment.size = 0.35,
    max.overlaps = Inf,
    seed = 123
  ) +
  
  common_lpmoi_scale +
  
  scale_color_manual(
    values = c(
      "MCAP-awarded plant" = "red"
    ),
    name = NULL
  ) +
  
  coord_sf(
    datum = NA,
    expand = FALSE
  ) +
  
  labs(
    title = "Southeastern Commercial Broiler Region",
    
    subtitle = paste0(
      "Arkansas (AR) • Alabama (AL) • Georgia (GA) • ",
      "Mississippi (MS)"
    )
  ) +
  
  theme_void() +
  
  theme(
    plot.title = element_text(
      size = 17,
      face = "bold",
      hjust = 0.5,
      margin = margin(
        b = 5
      )
    ),
    
    plot.subtitle = element_text(
      size = 8.5,
      hjust = 0.5,
      lineheight = 1.15,
      margin = margin(
        b = 10
      )
    ),
    
    legend.position = "bottom",
    
    legend.box = "vertical",
    
    legend.title = element_text(
      size = 9,
      face = "bold"
    ),
    
    legend.text = element_text(
      size = 8
    ),
    
    plot.margin = margin(
      t = 10,
      r = 10,
      b = 10,
      l = 10
    )
  ) +
  
  guides(
    fill = guide_colorbar(
      title.position = "top",
      title.hjust = 0.5,
      barwidth = unit(
        4.5,
        "in"
      ),
      barheight = unit(
        0.18,
        "in"
      ),
      direction = "horizontal",
      order = 1
    ),
    
    color = guide_legend(
      override.aes = list(
        shape = 21,
        fill = "red",
        color = "red",
        size = 3
      ),
      order = 2
    )
  )

# We create an interpretation panel for the Northeast
northeast_insight_panel <- ggplot() +
  
  annotate(
    geom = "label",
    x = 0.02,
    y = 0.98,
    
    label = paste0(
      "WHY THE NORTHEAST STANDS OUT\n\n",
      "• Relatively lower commercial broiler production\n",
      "• High demand for poultry and locally produced foods\n",
      "• More diverse consumer preferences\n",
      "• Relatively higher median household incomes\n",
      "• Good access to local processing facilities\n\n",
      "POLICY IMPLICATION\n",
      "Strong consumer demand, purchasing capacity, market diversity,\n",
      "and local processing access make the Northeast a prime target\n",
      "for MCAP investment. Additional processing capacity may better\n",
      "connect regional producers with high-value consumer markets."
    ),
    
    hjust = 0,
    vjust = 1,
    size = 3.1,
    lineheight = 1.12,
    
    label.padding = unit(
      0.7,
      "lines"
    ),
    
    label.r = unit(
      0.15,
      "lines"
    ),
    
    linewidth = 0.4,
    fill = "#f7fcf5",
    color = "grey10"
  ) +
  
  xlim(
    0,
    1
  ) +
  
  ylim(
    0,
    1
  ) +
  
  coord_cartesian(
    clip = "off"
  ) +
  
  theme_void() +
  
  theme(
    plot.margin = margin(
      t = 5,
      r = 15,
      b = 5,
      l = 15
    )
  )


# We also create an interpretation panel for the Southeast
southeast_insight_panel <- ggplot() +
  
  annotate(
    geom = "label",
    x = 0.02,
    y = 0.98,
    
    label = paste0(
      "WHY THE SOUTHEAST LOOKS DIFFERENT\n\n",
      "• One of the largest contributors to U.S. broiler production\n",
      "• Highly industrialized and vertically coordinated production\n",
      "• Extensive existing commercial processing infrastructure\n",
      "• Relatively lower median household incomes\n",
      "• Less diverse local consumer markets in many counties\n\n",
      "POLICY IMPLICATION\n",
      "Because large-scale poultry production and processing capacity\n",
      "are already highly developed, additional MCAP investment may\n",
      "generate smaller marginal local-market benefits than in regions\n",
      "with greater unmet demand for decentralized processing."
    ),
    
    hjust = 0,
    vjust = 1,
    size = 3.1,
    lineheight = 1.12,
    
    label.padding = unit(
      0.7,
      "lines"
    ),
    
    label.r = unit(
      0.15,
      "lines"
    ),
    
    linewidth = 0.4,
    fill = "#f7fcf5",
    color = "grey10"
  ) +
  
  xlim(
    0,
    1
  ) +
  
  ylim(
    0,
    1
  ) +
  
  coord_cartesian(
    clip = "off"
  ) +
  
  theme_void() +
  
  theme(
    plot.margin = margin(
      t = 5,
      r = 15,
      b = 5,
      l = 15
    )
  )



# We prepare the Northeast regional map panel
#
# We retain the legends on this map so that the final figure
# has one copy of the LPMOI and MCAP legends.
northeast_map_panel <- northeast_map


# We prepare the Southeast regional map panel
#
# We remove its legends because they duplicate the legends
# already retained on the Northeast regional map.
southeast_map_panel <- southeast_map +
  
  theme(
    legend.position = "none"
  )


# We shift the Southeast map toward the right
#
# We add a narrow blank panel to the left of the Southeast map.
# Unlike plot margins or coordinate limits, this changes the
# actual position of the full Southeast plot within its space.
southeast_map_panel_shifted <-
  
  plot_spacer() |
  southeast_map_panel +
  
  plot_layout(
    widths = c(
      0.12,
      0.88
    )
  )


############################################################
## ADJUST RELATIVE MAP WIDTHS
############################################################

# We place the two regional maps in the same row.
#
# The Northeast receives more horizontal space because its
# geography is narrower and taller than the Southeast region.
# The internal spacer moves the Southeast map farther right.

regional_maps_row <-
  (
    northeast_map_panel |
      southeast_map_panel
  ) +
  
  plot_layout(
    widths = c(
      1.25,
      0.75
    )
  )




# We place the two interpretation panels in the same row
#
# Unlike the regional maps, the two interpretation panels are
# assigned equal widths so that both panels remain readable.
regional_insight_row <-
  
  northeast_insight_panel |
  southeast_insight_panel +
  
  plot_layout(
    widths = c(
      1,
      1
    )
  )


# We rebuild the final regional comparison figure
#
# We place the regional maps above the interpretation panels.
# The regional maps receive more vertical space, while the
# final legends are collected and positioned at the bottom.
final_regional_comparison <-
  
  regional_maps_row /
  
  regional_insight_row +
  
  plot_layout(
    heights = c(
      4.8,
      2.2
    ),
    guides = "collect"
  ) +
  
  plot_annotation(
    title = paste0(
      "Local Poultry Market Opportunity and MCAP Investment ",
      "Across Two Contrasting U.S. Regions"
    ),
    
    subtitle = paste0(
      "Comparing Northeastern local-market opportunity with the ",
      "highly industrialized Southeastern broiler belt"
    ),
    
    caption = paste0(
      "Notes: LPMOI is the harmonic mean of the Local Poultry Market ",
      "Readiness Index and the Local Processing Access Index. ",
      "Darker green counties indicate higher local poultry market ",
      "opportunity. Red points represent MCAP-awarded plants."
    ),
    
    theme = theme(
      plot.title = element_text(
        size = 22,
        face = "bold",
        hjust = 0.5,
        margin = margin(
          b = 7
        )
      ),
      
      plot.subtitle = element_text(
        size = 11,
        hjust = 0.5,
        margin = margin(
          b = 14
        )
      ),
      
      plot.caption = element_text(
        size = 8.5,
        hjust = 0,
        lineheight = 1.1,
        margin = margin(
          t = 10
        )
      ),
      
      plot.margin = margin(
        t = 15,
        r = 18,
        b = 12,
        l = 18
      )
    )
  ) &
  
  theme(
    legend.position = "bottom"
  )

# We display the final regional comparison figure
final_regional_comparison


# We save the final regional comparison as a high-resolution PNG
ggsave(
  filename =
    "Northeast_vs_Southeast_LPMOI_MCAP_Comparison.png",
  plot = final_regional_comparison,
  width = 18,
  height = 12,
  units = "in",
  dpi = 300,
  bg = "white"
)


# We also save the final regional comparison as a PDF
ggsave(
  filename =
    "Northeast_vs_Southeast_LPMOI_MCAP_Comparison.pdf",
  plot = final_regional_comparison,
  width = 18,
  height = 12,
  units = "in",
  device = "pdf",
  bg = "white"
)







# We first create one common scale for the Local Poultry Market
# Readiness Index.
#
# The national range is used so that the same color represents
# the same LPMRI value in both regional maps.

common_lpmri_limits <- range(
  lpmoi_county_map$LPMRI,
  na.rm = TRUE
)


# We create readable breaks for the LPMRI legend.

common_lpmri_breaks <- pretty(
  common_lpmri_limits,
  n = 5
)


# We define the color scale that will be used for both
# the Northeast and Southeast LPMRI maps.

common_lpmri_scale <- scale_fill_gradientn(
  colours = c(
    "#fff7ec",
    "#fee8c8",
    "#fdd49e",
    "#fdbb84",
    "#fc8d59",
    "#ef6548",
    "#d7301f",
    "#990000"
  ),
  
  limits = common_lpmri_limits,
  breaks = common_lpmri_breaks,
  
  labels = scales::label_number(
    accuracy = 0.01
  ),
  
  oob = scales::squish,
  na.value = "grey90",
  
  name = paste(
    "Local Poultry Market",
    "Readiness Index"
  )
)


# We now create one common scale for the Local Processing
# Access Index.
#
# We again use the national range so that the Northeast and
# Southeast LPAI maps can be compared directly.

common_lpai_limits <- range(
  lpmoi_county_map$Local_Processing_Access_Index,
  na.rm = TRUE
)


# We create readable breaks for the LPAI legend.

common_lpai_breaks <- pretty(
  common_lpai_limits,
  n = 5
)


# We define the color scale that will be used for both
# the Northeast and Southeast LPAI maps.

common_lpai_scale <- scale_fill_gradientn(
  colours = c(
    "#f7fbff",
    "#deebf7",
    "#c6dbef",
    "#9ecae1",
    "#6baed6",
    "#4292c6",
    "#2171b5",
    "#084594"
  ),
  
  limits = common_lpai_limits,
  breaks = common_lpai_breaks,
  
  labels = scales::label_number(
    accuracy = 0.01
  ),
  
  oob = scales::squish,
  na.value = "grey90",
  
  name = paste(
    "Local Processing",
    "Access Index"
  )
)


# We create the Northeast LPMRI map.
#
# This map does not include MCAP-awarded plants because the
# purpose of the four-panel figure is to compare the two
# component indices directly.

northeast_lpmri_map <- ggplot() +
  
  geom_sf(
    data = northeast_counties_sf,
    aes(
      fill = LPMRI
    ),
    color = "white",
    linewidth = 0.12
  ) +
  
  geom_sf(
    data = northeast_states_sf,
    fill = NA,
    color = "grey20",
    linewidth = 0.65
  ) +
  
  geom_text(
    data = northeast_state_labels,
    aes(
      x = label_x,
      y = label_y,
      label = STUSPS
    ),
    size = 5,
    fontface = "bold",
    color = "black"
  ) +
  
  common_lpmri_scale +
  
  coord_sf(
    datum = NA,
    expand = FALSE
  ) +
  
  labs(
    title = "A. Northeast LPMRI",
    
    subtitle = paste0(
      "Connecticut (CT) • Maine (ME) • Massachusetts (MA) • ",
      "New Hampshire (NH) • Rhode Island (RI)\n",
      "Vermont (VT) • New Jersey (NJ) • New York (NY) • ",
      "Pennsylvania (PA)"
    )
  ) +
  
  theme_void() +
  
  theme(
    plot.title = element_text(
      size = 17,
      face = "bold",
      hjust = 0.5,
      margin = margin(
        b = 5
      )
    ),
    
    plot.subtitle = element_text(
      size = 8.5,
      hjust = 0.5,
      lineheight = 1.15,
      margin = margin(
        b = 10
      )
    ),
    
    legend.position = "bottom",
    
    legend.box = "vertical",
    
    legend.title = element_text(
      size = 9,
      face = "bold",
      hjust = 0.5
    ),
    
    legend.text = element_text(
      size = 8
    ),
    
    plot.margin = margin(
      t = 10,
      r = 10,
      b = 10,
      l = 10
    )
  ) +
  
  guides(
    fill = guide_colorbar(
      title.position = "top",
      title.hjust = 0.5,
      
      barwidth = unit(
        4.5,
        "in"
      ),
      
      barheight = unit(
        0.18,
        "in"
      ),
      
      direction = "horizontal"
    )
  )


# We create the Southeast LPMRI map.
#
# The same national LPMRI scale is used here so the county
# colors remain comparable with the Northeast map.

southeast_lpmri_map <- ggplot() +
  
  geom_sf(
    data = southeast_counties_sf,
    aes(
      fill = LPMRI
    ),
    color = "white",
    linewidth = 0.12
  ) +
  
  geom_sf(
    data = southeast_states_sf,
    fill = NA,
    color = "grey20",
    linewidth = 0.65
  ) +
  
  geom_text(
    data = southeast_state_labels,
    aes(
      x = label_x,
      y = label_y,
      label = STUSPS
    ),
    size = 5,
    fontface = "bold",
    color = "black"
  ) +
  
  common_lpmri_scale +
  
  coord_sf(
    datum = NA,
    expand = FALSE
  ) +
  
  labs(
    title = "B. Southeast LPMRI",
    
    subtitle = paste0(
      "Arkansas (AR) • Alabama (AL) • Georgia (GA) • ",
      "Mississippi (MS)"
    )
  ) +
  
  theme_void() +
  
  theme(
    plot.title = element_text(
      size = 17,
      face = "bold",
      hjust = 0.5,
      margin = margin(
        b = 5
      )
    ),
    
    plot.subtitle = element_text(
      size = 8.5,
      hjust = 0.5,
      lineheight = 1.15,
      margin = margin(
        b = 10
      )
    ),
    
    legend.position = "none",
    
    plot.margin = margin(
      t = 10,
      r = 10,
      b = 10,
      l = 10
    )
  )


# We create the Northeast LPAI map.
#
# Counties are shaded using the Local Processing Access Index.
# Darker blue counties have greater access to poultry processing.

northeast_lpai_map <- ggplot() +
  
  geom_sf(
    data = northeast_counties_sf,
    aes(
      fill = Local_Processing_Access_Index
    ),
    color = "white",
    linewidth = 0.12
  ) +
  
  geom_sf(
    data = northeast_states_sf,
    fill = NA,
    color = "grey20",
    linewidth = 0.65
  ) +
  
  geom_text(
    data = northeast_state_labels,
    aes(
      x = label_x,
      y = label_y,
      label = STUSPS
    ),
    size = 5,
    fontface = "bold",
    color = "black"
  ) +
  
  common_lpai_scale +
  
  coord_sf(
    datum = NA,
    expand = FALSE
  ) +
  
  labs(
    title = "C. Northeast LPAI",
    
    subtitle = paste0(
      "Connecticut (CT) • Maine (ME) • Massachusetts (MA) • ",
      "New Hampshire (NH) • Rhode Island (RI)\n",
      "Vermont (VT) • New Jersey (NJ) • New York (NY) • ",
      "Pennsylvania (PA)"
    )
  ) +
  
  theme_void() +
  
  theme(
    plot.title = element_text(
      size = 17,
      face = "bold",
      hjust = 0.5,
      margin = margin(
        b = 5
      )
    ),
    
    plot.subtitle = element_text(
      size = 8.5,
      hjust = 0.5,
      lineheight = 1.15,
      margin = margin(
        b = 10
      )
    ),
    
    legend.position = "bottom",
    
    legend.box = "vertical",
    
    legend.title = element_text(
      size = 9,
      face = "bold",
      hjust = 0.5
    ),
    
    legend.text = element_text(
      size = 8
    ),
    
    plot.margin = margin(
      t = 10,
      r = 10,
      b = 10,
      l = 10
    )
  ) +
  
  guides(
    fill = guide_colorbar(
      title.position = "top",
      title.hjust = 0.5,
      
      barwidth = unit(
        4.5,
        "in"
      ),
      
      barheight = unit(
        0.18,
        "in"
      ),
      
      direction = "horizontal"
    )
  )


# We create the Southeast LPAI map.
#
# The same national LPAI scale is used here so that county
# processing access can be compared with the Northeast.

southeast_lpai_map <- ggplot() +
  
  geom_sf(
    data = southeast_counties_sf,
    aes(
      fill = Local_Processing_Access_Index
    ),
    color = "white",
    linewidth = 0.12
  ) +
  
  geom_sf(
    data = southeast_states_sf,
    fill = NA,
    color = "grey20",
    linewidth = 0.65
  ) +
  
  geom_text(
    data = southeast_state_labels,
    aes(
      x = label_x,
      y = label_y,
      label = STUSPS
    ),
    size = 5,
    fontface = "bold",
    color = "black"
  ) +
  
  common_lpai_scale +
  
  coord_sf(
    datum = NA,
    expand = FALSE
  ) +
  
  labs(
    title = "D. Southeast LPAI",
    
    subtitle = paste0(
      "Arkansas (AR) • Alabama (AL) • Georgia (GA) • ",
      "Mississippi (MS)"
    )
  ) +
  
  theme_void() +
  
  theme(
    plot.title = element_text(
      size = 17,
      face = "bold",
      hjust = 0.5,
      margin = margin(
        b = 5
      )
    ),
    
    plot.subtitle = element_text(
      size = 8.5,
      hjust = 0.5,
      lineheight = 1.15,
      margin = margin(
        b = 10
      )
    ),
    
    legend.position = "none",
    
    plot.margin = margin(
      t = 10,
      r = 10,
      b = 10,
      l = 10
    )
  )


# We place the two LPMRI maps in the first row.
#
# The Northeast map retains the LPMRI legend and the Southeast
# map does not display a duplicate legend.

lpmri_maps_row <-
  (
    northeast_lpmri_map |
      southeast_lpmri_map
  ) +
  
  plot_layout(
    widths = c(
      1.4,
    0.75
    )
  )




# We combine the two rows to create the final four-panel figure.
#
# The LPMRI maps appear in the first row and the LPAI maps
# appear in the second row.

final_lpmri_lpai_comparison <-
  
  lpmri_maps_row /
  
  lpai_maps_row +
  
  plot_layout(
    heights = c(
      1,
      1
    )
  ) +
  
  plot_annotation(
    title = paste0(
      "Local Poultry Market Readiness and Processing Access ",
      "Across Two Contrasting U.S. Regions"
    ),
    
    subtitle = paste0(
      "Comparing county-level market readiness and processing ",
      "access in the Northeast and Southeastern commercial ",
      "broiler region"
    ),
    
    caption = paste0(
      "Notes: LPMRI represents the Local Poultry Market Readiness ",
      "Index, while LPAI represents the Local Processing Access ",
      "Index. Darker colors indicate higher index values. ",
      "The same scale is used within each index to support ",
      "comparison across regions."
    ),
    
    theme = theme(
      plot.title = element_text(
        size = 22,
        face = "bold",
        hjust = 0.5,
        margin = margin(
          b = 7
        )
      ),
      
      plot.subtitle = element_text(
        size = 11,
        hjust = 0.5,
        lineheight = 1.15,
        margin = margin(
          b = 14
        )
      ),
      
      plot.caption = element_text(
        size = 8.5,
        hjust = 0,
        lineheight = 1.1,
        margin = margin(
          t = 10
        )
      ),
      
      plot.margin = margin(
        t = 15,
        r = 18,
        b = 12,
        l = 18
      )
    )
  )


# We display the final four-panel figure.

final_lpmri_lpai_comparison


# We save the final four-panel comparison as a high-resolution
# PNG file.

ggsave(
  filename =
    "Northeast_vs_Southeast_LPMRI_LPAI_Comparison.png",
  plot = final_lpmri_lpai_comparison,
  width = 18,
  height = 18,
  units = "in",
  dpi = 300,
  bg = "white"
)


# We also save the final four-panel comparison as a PDF file.

ggsave(
  filename =
    "Northeast_vs_Southeast_LPMRI_LPAI_Comparison.pdf",
  plot = final_lpmri_lpai_comparison,
  width = 18,
  height = 18,
  units = "in",
  bg = "white"
)


#End of Code

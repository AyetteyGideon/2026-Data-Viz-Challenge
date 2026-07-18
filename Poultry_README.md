## Data sources

`Key_Local_Food_Metrics.xlsx`, a workbook with one sheet per raw indicator. All of those indicators were originally pulled from the **FAME (Food and Agriculture Mapper and Explorer)** 
public dashboard: [public.tableau.com/app/profile/dataelevates/viz/FAME_2026_17763829701230/FAMEHomePage](https://public.tableau.com/app/profile/dataelevates/viz/FAME_2026_17763829701230/FAMEHomePage),
via a crosstab export (`Show = All values`) on 2026-07-15. FAME itself aggregates several underlying federal sources, listed indicator-by-indicator below.

We use the same two key columns, `State` (two-letter abbreviation) and `County` (county name, matching the U.S. Census/FIPS naming convention — see [County-name reconciliation] below) in each of the sheets our script reads.

| Sheet read by the script | Indicator | Underlying source | Why it matters to the index |
|---|---|---|---|
| `CSA Businesses` | Number of Community Supported Agriculture (CSA) businesses, 2025 | USDA Local Food Directories (USDA FAME) | One of the "local food ecosystem" signals — counties with active CSAs have existing direct-to-consumer food infrastructure a new processor could tap into. |
| `Farmers Markets` | Number of farmers markets, 2025 | USDA Local Food Directories (self-reported) | Same rationale as CSAs — a proxy for local demand and existing farm-to-consumer channels. |
| `Farms Pct DirectConsumer` | Direct-to-consumer sales as % of all farm sales, 2022 | USDA FAME Data | Measures how oriented the local farm economy already is toward direct sales — a readiness signal for local/regional meat marketing. |
| `Farms Pct LocalMktChannel` | Local marketing channel sales as % of all farm sales, 2022 | USDA FAME Data | Broader than direct-to-consumer — capturing a wider local-food supply chain. |
| `Farms Pct SellingDirect` | % of all farms selling direct-to-consumer, 2022 | USDA NASS Census of Agriculture | Measures breadth (how many farms participate) rather than sales volume — we use this to complement the two sales-share indicators above. |
| `Food Hubs` | Number of food hubs, 2025 | USDA Local Food Directories (self-reported) | Food hubs aggregate and distribute local product; their presence signals existing mid-supply-chain infrastructure relevant to processing investment. |
| `On Farm Market` | Number of on-farm market businesses, 2025 | USDA Local Food Directories (USDA FAME) | Another local-food-channel signal|
| `Total Population` | Total resident population, 2019–2023 (ACS 5-Year Estimates, Table B01003) | U.S. Census Bureau, ACS 5-Year Estimates | Used both as a "scale" signal (larger population = more addressable market), as the denominator for every per-capita rate the script computes, and as the base table the script joins everything else onto. |
| `Median HH Income` | Median household income, 2019–2023 (ACS 5-Year Estimates, Table B19013) | U.S. Census Bureau, ACS 5-Year Estimates | A need indicator (inverted — lower income scores higher). Two counties have Census-suppressed values (small sample size) and are left blank. |
| `Broiler Operation Count` | the input file the LMRI script reads. It pulls county-level broiler (meat chicken) operation counts directly from USDA's |
| `FSIS Establishment Count` | the data was extracted from the FSIS Official webpage tableau map of the poultry and meat processing directory | Interactive dashboard

### County-name reconciliation

The raw FAME export used inconsistent county-naming conventions across sheets — for example, Alaska entries appeared as `Aleutians East County` in some sheets but `Aleutians East Borough` in others, and full state names (`Alabama`) in the `Grocery Stores per 1000` sheet instead of the two-letter abbreviations (`AL`) used everywhere else. Before running `New MPI Code.R`, every sheet in `Key_Local_Food_Metrics.xlsx` was reconciled manually, to a single, consistent naming convention, matching the `CSA Businesses` sheet as the reference:

- State names were converted to two-letter USPS abbreviations.
- County names were standardized to include the correct suffix (`County`, `Parish`, or, for independent cities, `City`) as used in `CSA Businesses`.

### Joining

The script reads each of the 14 raw indicator sheets into its own two-column-plus-value data frame (`State`, `County`, and one named value column), then left-joins all of them onto the `Total Population` sheet using `State` and `County` as the join key.
`Total Population` is used as the base because it has full 3,144-county coverage;

### Filtering 

- **Count-type indicators** (`Farmers Markets`, `CSA Businesses`, `Food Hubs`, `On Farm Market`) 
    have missing values replaced with `0`, on the assumption that no record in these self-reported/administrative directories means no such business exists in that county.
- **Rate/percent-type indicators** (poverty %, income, farm-sales percentages, store-per-1000 rates) are **left as `NA`** when missing, and are simply excluded from that county's dimension average rather than treated as zero 
   — a county missing one input isn't penalized as if that input were the worst possible value.
- No counties are dropped; every county present in `Total Population` (3,144 total) flows through to the final ranked output, even if some of its inputs are missing.




## FSIS Chicken Processing Data: Import, Clean, Merge HACCP Size, and Validate

A separate script (referred to here as the FSIS HACCP merge script) prepares the FSIS-inspected chicken/poultry processing establishment list used in this project. Unlike `New MPI Code.R`, this script doesn't compute the MPI Index itself — This is a data-preparation step that produces a clean establishment-level file, `fsis_chicken_processors_with_haccp_size.csv`, with each establishment tagged by its HACCP size class (Large, Small, or Very Small).

### Data source

The four input files (`fsis_chicken_all_sizes.csv`, `fsis_chicken_large.csv`, `fsis_chicken_small.csv`, `fsis_chicken_very_small.csv`) are crosstab exports from a Tableau dashboard of FSIS-inspected establishments and their production activities.

### Data transformations

- **Encoding.** All four files are read with `read_tsv()` and `locale(encoding = "UTF-16LE")`
- **ZIP code preservation.** `Postal Code` is explicitly imported as `col_character()` (not the default numeric guess)
- **Column renaming.** Each file's Tableau-generated column names (`AddressLine11`, `City State`, `map_cat_tooltip`, `Latitude (generated)`, etc.) are renamed to consistent.
- **Identifier standardization.** `establishment_number` is whitespace-squished (`str_squish()`) and uppercased (`str_to_upper()`) in every file, so the same establishment can't fail to match across files due to a stray space or inconsistent casing — We use this join key to merge in the HACCP size.
- **Duplicate-establishment check.** Each of the four cleaned files is checked for establishment numbers that appear more than once (`count()` + `filter(records_per_establishment > 1)`)
- **HACCP size lookup.** Since the size classification only exists implicitly (via which filtered file a row appears in), the script builds it explicitly: the large, small, and very-small files are each reduced to just `establishment_number` plus a hardcoded `haccp_size` label ("Large", "Small", "Very Small")
- **Merge and validation.** The HACCP size lookup is left-joined onto the full "all sizes" file by `establishment_number`, so every establishment in the complete export is kept regardless of whether a size label was found for it. 

### Code structure

The script follows the 8 steps outlined in the header comment, run top to bottom:

1. **Set working directory** — We had all four raw Tableau files in the same folder.
2. **Load packages** — `readr`, `dplyr`, `stringr`.
3. **Import the four Tableau files** — each read with `read_tsv()` and the UTF-16LE locale described above.
4. **Preserve ZIP codes** — handled inline during import (`col_character()`) and in the standardization step (`str_pad()`).
5. **Standardize establishment identifiers** — column renaming, `establishment_number`/`postal_code` cleanup, and unused-column pruning, repeated identically across all four data frames.
6. **Check for missing and duplicate establishment numbers** — currently implements the duplicate check only (see note above).
7. **Create a HACCP-size lookup** — tags and combines the three size-specific files into one lookup table.
8. **Merge HACCP size into the complete establishment file** — left-join, row-count validation, and export to `fsis_chicken_processors_with_haccp_size.csv`.


## Local Processing Access Index

We create a third script: Local Processing Access Index script. It takes the cleaned, size-tagged establishment file (`fsis_chicken_processors_with_haccp_size.csv`) and turns it into a **county-level spatial measure of how accessible chicken-processing capacity is**, producing `county_local_processing_access_index.csv`.

This index is built from actual geographic distances between each county and the nearest processing establishments.

### Data source

Two inputs feed this script:

- **County boundaries.** 2022 TIGER/Line county boundaries (cartographic boundary, 20m resolution), pulled live via the `tigris` package's `counties()` function, direct from the U.S. Census Bureau. 
- **FSIS chicken processor locations.** The output of the FSIS HACCP merge script (`fsis_chicken_processors_with_haccp_size.csv`), which supplies each establishment's latitude/longitude and its HACCP size class (Large, Small, Very Small).

The 50-mile access radius used throughout this script is the same distance standard USDA's Agricultural Marketing Service uses to define a "local" or "regional" market area for competition purposes (USDA AMS, *Inclusive Competition and Market Integrity Under the Packers and Stockyards Act*, Federal Register 89(45): 16092–16199, 2024 final rule).

### Data transformations

- **Geographic scope.** County boundaries are filtered down to the contiguous United States only, dropping Alaska, Hawaii, Puerto Rico, and the other U.S. territories (by state FIPS code) — the same exclusion is applied on the processor side by state abbreviation, so both sides of every distance calculation are limited to the Lower 48 (plus DC).
- **Standardized county keys.** County boundaries are reduced to `county_geoid` (5-digit FIPS), `state_fips`, `county_fips`, `state_name`, and `county_name`, so the output can be joined to other county-level files in this project (e.g. `Key_Local_Food_Metrics.xlsx`) later.
- **Projection.** Both counties and processor points are transformed to EPSG:5070 (NAD83 / Conus Albers), an equal-area projection in meters appropriate for distance calculations across the contiguous U.S. — geographic (lat/long) coordinates aren't suitable for measuring real-world distance directly.
- **County centroids as a stand-in for farm location.** Because actual farm locations aren't available, each county's geometric centroid is used as the representative point from which processing accessibility is measured — an approximation, not an actual producer location.
- **Splitting by size.** Filtered establishments are split into two groups: **local-scale processors** (Small + Very Small — the ones this index is built around, on the premise that they're more likely to serve independent/local producers) and **industrial processors** (Large — tracked separately as a presence indicator, not folded into the index itself).
- **Distance calculations.** For every county centroid: (1) the count of local-scale processors within 50 miles (`st_is_within_distance()`), (2) the straight-line distance in miles to the *nearest* local-scale processor (`st_distance()` + row-wise minimum), and (3) the count of Large processors within 50 miles. 
- **Skew check.** Before building the index, we inspect the distribution of the raw local-processor count (histogram + quantiles) and finds it heavily right-skewed (median count ≈ 6.6, 3rd quartile = 6, max = 182) — this finding directly motivates the log transform used in the availability component below.

### Constructing the index

The **Local Processing Access Index** is an equal-weighted average of three 0–1 components, computed independently for every county:

1. **Availability score** — the local-processor count within 50 miles, capped at 25 (the count's 95th percentile, chosen so a handful of extreme outlier counties don't dominate the scale) and log-transformed (`log1p`) to correct the skew identified above, then rescaled to 0–1 by dividing by `log1p(25)`.
2. **Proximity score** — a simple linear decay from 1 (a local-scale processor sits right at the county centroid) to 0 (the nearest one is 50 miles away or farther): `max(0, 1 - distance_miles / 50)`.
3. **Local orientation score** — of all processors (local-scale + industrial) within 50 miles, the share that are local-scale (Small/Very Small). Counties with no processors of any size within 50 miles score 0 rather than being left undefined.

`local_processing_access_index = (availability_score + proximity_score + local_orientation_score) / 3`.

### Code structure


1. **Setup** — working directory and package loads (`dplyr`, `sf`, `tigris`, `stringr`, `units`, `ggplot2`, `readr`).
2. **County boundaries** — downloads 2022 TIGER/Line counties via `tigris::counties()`, restricts to the contiguous U.S., standardizes identifier columns, and reprojects to EPSG:5070.
3. **County centroids** — collapses each county polygon to a single representative point.
4. **Load processors** — reads the FSIS HACCP merge script's output file.
5. **Filter and geocode processors** — drops incomplete records, restricts to the contiguous U.S., and converts lat/long into `sf` point geometry, reprojected to match the counties.
6. **Split by size** — separates local-scale (Small/Very Small) from industrial (Large) processors.
7. **Distance calculations** — local-processor counts within 50 miles, nearest-local-processor distance, and industrial-processor counts within 50 miles, for every county.
8. **Assemble & inspect** — drops geometry to produce a plain (non-spatial) county-level table, with a histogram and summary statistics of the raw access measure.
9. **Build the index** — computes the three components and the final equal-weighted index.
10. **Export** — writes `county_local_processing_access_index.csv`.



## Local Market Readiness Index (LMRI)

Our fourth script builds a county-level **Local Market Readiness Index**, exported as `County_Local_Market_Readiness_Index.csv`. Where the Local Processing Access Index measures physical proximity to processing capacity.
### Data source

We read a single input, `Local_Food_Broiler_2022.rds` — an R data (RDS) file rather than a CSV, chosen specifically because RDS preserves each column's original R class (numeric, character, etc.) on reload.
### Data transformations

- **Variable-type check.** Before any transformation, we confirm all seven required variables (`operations_with_broiler_sales`, `Population`, `Income`, `FarmersMarkets`, `CSA`, `OnFarmMarket`, `FoodHubs`) are numeric.
- **Distribution check.** A summary table (observation count, min, mean, median, max, standard deviation per variable, reshaped long with `pivot_longer()`) is printed to inspect each variable's distribution.
- **Log transforms.** `operations_with_broiler_sales`, `Population`, `FarmersMarkets`, `CSA`, and `OnFarmMarket` are all log-transformed (`log1p`, i.e. `log(1 + x)`, which handles the many zero values these count variables have) 
- **Food hub presence, not count.** Rather than logging and normalizing a `FoodHubs` count like the other local-food variables, we collapse it to a binary `food_hub_presence` indicator (1 if a county has at least one food hub, 0 otherwise, including for missing values). This is a different modeling choice than the MPI Index workflow, which uses food hubs as a continuous per-capita rate.
- **Min-max normalization.** A `min_max_normalize()` function rescales each transformed variable to 0–1 
- **Income imputation.** Two counties are missing `Income` entirely. Rather than excluding them from the Market Potential component, the script imputes each missing county's income with the **median income of all other counties in the same state** (`group_by(State)`)

### Constructing the index

The LMRI combines three dimensions, weighted 40/35/25:

1. **Producer Base (40%)** — normalized, logged broiler operations count alone. This is the only component measuring actual poultry-production activity already present in the county.
2. **Market Potential (35%)** — an equal-weighted (50/50) average of normalized population and normalized (imputed) income, representing the size and purchasing power of the local customer base.
3. **Infrastructure (25%)**, itself built from two sub-components:
   - **Consumer Access** — an equal-weighted average of normalized, logged farmers markets, CSA businesses, and on-farm markets.
   - **Food Hub Presence** — the binary indicator described above.
   - `Infrastructure = 0.80 × Consumer_Access + 0.20 × food_hub_presence` — Consumer Access carries most of the weight, with food hub presence as a smaller supporting signal.

`LMRI = 0.40 × Producer_Base + 0.35 × Market_Potential + 0.25 × Infrastructure`. Unlike the MPI Index's 35/35/30 split.

### Code structure

The script runs as one continuous pipeline:

1. **Setup** — working directory and package loads (`dplyr`, `readr`, `stringr`, `tidyr`, `ggplot2`).
2. **Load & inspect** — reads the RDS file and checks its dimensions, structure, and column names.
3. **Variable-type and distribution check** — confirms the seven required variables are numeric and summarizes their distributions.
4. **Transform** — log transforms, the broiler-data-reported flag, and the food-hub presence indicator.
5. **Normalize** — applies `min_max_normalize()` to each transformed variable.
6. **Income imputation** — fills the two missing income values with each county's state median and re-normalizes income.
7. **Build dimensions** — computes `Producer_Base`, `Market_Potential`, `Consumer_Access`, and `Infrastructure`.
8. **Combine into the final index** — computes `LMRI` from the three weighted dimensions.
9. **Export** — selects the identifier and score columns and writes `County_Local_Market_Readiness_Index.csv`.



## Building the Broiler + Local Food County Match (`Local_Food_Broiler_2022`)

Our fifth script, the broiler-match script  produces `Local_Food_Broiler_2022.rds` — the input file the LMRI script reads. It pulls county-level broiler (meat chicken) operation counts directly from USDA's 
NASS QuickStats API, matches those counties against a subset of the local-food metrics workbook, and reconciles both to the Census Bureau's official county GEOID codes. 
This confirms and supersedes the inference in the LMRI section above about where that RDS file comes from — see the note at the end of this section.

### Data source

- **Broiler operations.** Pulled from the USDA NASS QuickStats API via the `rnassqs` package (requires a free NASS API key)
- Filtered to `source_desc = "CENSUS"`, `group_desc = "POULTRY"`, `commodity_desc = "CHICKENS"`, `agg_level_desc = "COUNTY"`, `year = 2022` — i.e., the 2022 Census of Agriculture.
- **Local-food metrics.** A subset of `Key_Local_Food_Metrics.xlsx` — specifically `Total Population`, `Median HH Income`, `Farms Pct DirectConsumer`, `Farms Pct LocalMktChannel`, `Farms Pct SellingDirect`, `Farmers Markets`, `CSA Businesses`, `Food Hubs`, and `On Farm Market`. 
- **Official county geography.** 2022 TIGER/Line county boundaries (cartographic boundary, 20m resolution) via `tigris::counties()`, used purely as a lookup table for each county's official name and five-digit GEOID — the geometry itself is dropped immediately (`st_drop_geometry()`)




## Local Poultry Market Opportunity Index (LPMOI) & Regional Comparison Maps

Our sixth script combines the two indices built earlier 
— the Local Market Readiness Index (`County_Local_Market_Readiness_Index.csv`) and 
- the Local Processing Access Index (`County_Local_Processing_Access_Index.csv`) 
— into a single **Local Poultry Market Opportunity Index (LPMOI)**, 
- then visualizes it alongside USDA MCAP-awarded plant locations.

**Combining the indices.** The two files are joined on `county_geoid`. 
LPMOI is the **harmonic mean** of the two component indices (rather than a simple average)

**Visualization.** Using 2022 Census county/state boundaries (`tigris`) and a plant-location file (`MCAPData.xlsx`)
- The script builds two multi-panel comparison figures contrasting the Northeast (CT, ME, MA, NH, RI, VT, NJ, NY, PA) 
- against the Southeastern broiler belt (AR, AL, GA, MS):

- `Northeast_vs_Southeast_LPMOI_MCAP_Comparison.png/.pdf` — county maps of LPMOI for each region, MCAP-awarded plant locations marked and labeled, plus a short written 
   * "why this region looks this way" interpretation panel for each.
- `Northeast_vs_Southeast_LPMRI_LPAI_Comparison.png/.pdf` — a four-panel map breaking LPMOI back down into its two underlying components (LPMRI and processing access) side by side
- So the regional contrast in each component can be seen individually rather than only in the blended index.

Both figures use a single national color scale per index, so color intensity is directly comparable between the Northeast and Southeast panels.

**To replicate:** run with `dplyr`, `readr`, `stringr`, `sf`, `tigris`, `ggplot2`, `scales`, `readxl`, `ggrepel`, `patchwork`, 
  ** and `grid` installed; `County_Local_Market_Readiness_Index.csv`, `County_Local_Processing_Access_Index.csv`, and `MCAPData.xlsx` 
  ** all need to be in the working directory first, and an internet connection is required for the `tigris` boundary download.



## Replicating the outputs

### Prerequisites

- R (4.0 or later recommended).
- These packages: `readxl`, `dplyr`, `stringr`, `ggplot2`, `maps`, `viridis`. Install any that are missing with:
  ```r
  install.packages(c("readxl", "dplyr", "stringr", "ggplot2", "maps", "viridis"))
  ```
- `Key_Local_Food_Metrics.xlsx` (with reconciled county names, as described above) in the same folder as `New MPI Code.R`.

### Steps

1. Open each R script and fix the working directory
2. Run the full script (e.g. `Rscript "New MPI Code.R"` from a terminal, or source it in RStudio). This will:
   


## Use of generative AI

Generative AI (Claude, via Anthropic's Cowork) was used in the enhancement of `New MPI Code.R` and this documentation, specifically for:

- **Code explanation.** Claude explained the logic of specific functions (e.g., the `normalize()` min-max scaling function) and the reasons the MPI Index's observed range doesn't reach the full 0–1 scale, on request, for the authors' own understanding.
- **Chat GPT** was assisted in county matching between USDA NASS and the local food matrix.
- **Chat GPT** was also used to enhance the coding for the visualization.
- **This README** was drafted by authors and enhanced further enhanced with Claude, using the workbook's `Notes` sheet and the source data documentation as reference material.


## Citation: Every code should be attributed to:
Authors:
Bobbie, K, Oluwabusolami, O, Ayettey, G. (2026) Title of the Code. 2026 Data Viz Challenge

## Stop


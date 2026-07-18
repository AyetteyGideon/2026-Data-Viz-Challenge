# Script 1: Poultry_Codefile1: Establishment Size Classification

## Purpose

This script prepares the USDA Food Safety and Inspection Service (FSIS) poultry processing establishment data for use in subsequent analyses. Specifically, it reconstructs the HACCP establishment size classification (Large, Small, and Very Small), which is not included in the complete establishment directory downloaded from the FSIS Tableau dashboard. The resulting dataset serves as the foundation for constructing the Local Processing Access Index (LPAI).

------------------------------------------------------------------------

## Data Sources

This script uses four datasets obtained from the **USDA Food Safety and Inspection Service (FSIS) Meat, Poultry and Egg Product Inspection Directory**, available through the agency's interactive Tableau dashboard.

The Tableau dashboard allows users to filter establishments by HACCP size classification and export the filtered records as Crosstab files. Because the complete establishment download does not include HACCP size, four separate exports were required.

| Dataset | Description | Purpose |
|----|----|----|
| **fsis_chicken_all_sizes.csv** | Complete directory of federally inspected poultry establishments | Serves as the master establishment dataset |
| **fsis_chicken_large.csv** | Establishments classified as Large | Used to identify Large establishments |
| **fsis_chicken_small.csv** | Establishments classified as Small | Used to identify Small establishments |
| **fsis_chicken_very_small.csv** | Establishments classified as Very Small | Used to identify Very Small establishments |

All four files were downloaded from the same version of the FSIS Tableau dashboard to ensure consistency. <https://www.fsis.usda.gov/inspection/establishments/meat-poultry-and-egg-product-inspection-directory>

------------------------------------------------------------------------

## Data Processing

The following preprocessing steps were performed:

1.  Imported all four Tableau Crosstab exports using UTF-16LE encoding while preserving postal codes as character variables to retain leading zeros.

2.  Renamed Tableau-generated variable names to concise and consistent names used throughout the project.

3.  Standardized establishment identifiers by:

    -   removing unnecessary whitespace,
    -   converting establishment numbers to uppercase, and
    -   padding ZIP codes to five digits.

4.  Removed Tableau-generated geometry and mapping fields that were not required for the analysis.

5.  Checked each dataset for duplicate establishment numbers to verify data integrity before merging.

6.  Constructed a HACCP size lookup table by assigning each establishment in the filtered downloads its corresponding size classification (Large, Small, or Very Small).

7.  Merged the HACCP size lookup table with the complete establishment directory using the establishment number as the unique identifier.

8.  Verified that the merge preserved the total number of establishment records.

------------------------------------------------------------------------

## Output

The script produces one cleaned establishment dataset:

`fsis_chicken_processors_with_haccp_size.csv`

This dataset contains standardized establishment information together with HACCP size classifications and serves as the primary input for **Script 2**, where processor locations are used to calculate the **Local Processing Access Index (LPAI)**.

------------------------------------------------------------------------

## Required R Packages

-   readr
-   dplyr
-   stringr

# Script 2: Poultry_Codefile2 - Local Processing Access Index (LPAI)

## Purpose

This script constructs the **Local Processing Access Index (LPAI)**, a county-level measure of access to federally inspected poultry processing establishments across the contiguous United States. The index is designed to capture the availability and accessibility of local-scale poultry processing infrastructure that supports independent producers and regional food systems.

The analysis focuses on **Small** and **Very Small** federally inspected establishments because these facilities are more closely aligned with local and regional poultry markets. **Large** establishments are retained separately to characterize industrial processing presence but are not incorporated into the final index.

The resulting county-level processing accessibility measures are later combined with the Local Market Readiness Index (LMRI) to construct the **Local Poultry Market Opportunity Index (LPMOI).**

------------------------------------------------------------------------

## Data Sources

This script uses two primary datasets.

| Dataset | Source | Purpose |
|----|----|----|
| **County Boundaries (2022 TIGER/Line Cartographic Boundary Files)** | U.S. Census Bureau | Defines county boundaries and county centroids used for spatial accessibility calculations. |
| **fsis_chicken_processors_with_haccp_size.csv** | Script 1 | Provides the locations and HACCP size classifications of federally inspected poultry processing establishments. |

### Data Source Links

**U.S. Census Bureau TIGER/Line Shapefiles**

<https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html>

**USDA Food Safety and Inspection Service (FSIS) Meat, Poultry and Egg Product Inspection Directory**

<https://www.fsis.usda.gov/inspection/establishments/meat-poultry-and-egg-product-inspection-directory>

------------------------------------------------------------------------

## Methodology

### County Geography

County boundaries for 2022 are downloaded directly from the U.S. Census Bureau using the **tigris** R package. The analysis is restricted to counties in the contiguous United States by excluding Alaska, Hawaii, Puerto Rico, and U.S. territories.

County boundaries are transformed into the **NAD83 / Conus Albers Equal Area (EPSG:5070)** projected coordinate system. This projection expresses coordinates in meters and is appropriate for calculating distances consistently across the contiguous United States.

County centroids are then generated to represent the approximate geographic location from which poultry producers access processing facilities. Following USDA guidance, accessibility is measured from county centroids because establishment-level farm locations are unavailable.

------------------------------------------------------------------------

### Processor Dataset

The cleaned processor dataset generated in **Script 1** is imported and filtered to retain only establishments with valid geographic coordinates and HACCP size classifications.

Processor locations are converted into spatial point features and transformed into the same projected coordinate system (EPSG:5070) to ensure accurate distance calculations.

Processors are divided into two groups:

-   **Local processors:** Small and Very Small establishments.
-   **Industrial processors:** Large establishments.

Only local processors are incorporated into the Local Processing Access Index.

------------------------------------------------------------------------

### Spatial Accessibility Measures

Accessibility is measured using a **50-mile service radius**, consistent with USDA guidance for evaluating producer access to processing facilities.

For every county, the following measures are calculated:

1.  **Local processor availability**
    -   Number of Small and Very Small federally inspected processors located within 50 miles of the county centroid.
2.  **Nearest processor distance**
    -   Distance (miles) from the county centroid to the closest Small or Very Small processor.
3.  **Industrial processor presence**
    -   Number of Large federally inspected processors located within 50 miles of the county centroid.

The industrial processor measure is retained for descriptive purposes but is not incorporated into the final accessibility index.

------------------------------------------------------------------------

### Local Processing Access Index

The Local Processing Access Index combines three equally weighted dimensions of processing accessibility.

#### 1. Availability

Measures the number of Small and Very Small processors located within 50 miles.

Processor counts are capped at the 95th percentile (25 processors) and transformed using the natural logarithm to reduce the influence of counties with exceptionally high processor concentrations.

#### 2. Proximity

Measures proximity to the nearest Small or Very Small processor.

The score decreases linearly from 1 for counties with a processor located at the county centroid to 0 for counties located 50 miles or more from the nearest processor.

#### 3. Local Orientation

Measures the share of all processors within 50 miles that are classified as Small or Very Small.

This component distinguishes counties dominated by local-scale processing infrastructure from those served primarily by large industrial facilities.

------------------------------------------------------------------------

### Index Construction

Each component is scaled to range between 0 and 1.

The Local Processing Access Index is calculated as the simple arithmetic mean of the three standardized components:

-   Availability
-   Proximity
-   Local Orientation

Equal weighting is used because no established empirical evidence exists to justify assigning greater importance to one dimension of processing accessibility over another.

------------------------------------------------------------------------

## Output

This script produces one county-level dataset:

`county_local_processing_access_index.csv`

The dataset contains:

-   county identifiers
-   number of local processors within 50 miles
-   distance to the nearest local processor
-   number of large processors within 50 miles
-   availability score
-   proximity score
-   local orientation score
-   Local Processing Access Index (LPAI)

This dataset serves as one of the principal inputs for constructing the **Local Poultry Market Opportunity Index (LPMOI)** in a subsequent script.

------------------------------------------------------------------------

## Required R Packages

-   dplyr
-   sf
-   tigris
-   stringr
-   units
-   ggplot2
-   readr

# Script 3: Poultry_Codefile3 - County-Level Broiler Production and Local Food Market Dataset

## Purpose

This script constructs a unified county-level dataset that combines broiler production with local food market characteristics for counties across the United States. The resulting dataset serves as the foundation for constructing the **Local Market Readiness Index (LMRI)** by integrating measures of poultry production capacity with indicators of local food demand and market infrastructure.

Because the input data originate from multiple independent sources that use different county naming conventions, the script implements a two-stage county matching procedure based on official Census geographic identifiers (GEOIDs). This ensures that all datasets are accurately linked prior to index construction.

------------------------------------------------------------------------

## Data Sources

This script integrates information from four publicly available data sources.

| Dataset | Source | Purpose |
|----|----|----|
| **2022 Census of Agriculture** | USDA National Agricultural Statistics Service (NASS) Quick Stats API | Provides county-level broiler production data. |
| **Key_Local_Food_Metrics.xlsx** | Compiled from the U.S. Census Bureau and USDA Food and Agriculture Mapper and Explorer (FAME 1.0 & 2.0) | Provides county-level indicators describing local food market characteristics. |
| **2022 TIGER/Line Cartographic Boundary Files** | U.S. Census Bureau | Provides official county geographic identifiers (GEOIDs) used to reconcile county names across datasets. |
| **County GEOID Lookup** | U.S. Census Bureau TIGER/Line Shapefiles | Provides official county names and geographic identifiers for county matching. |

------------------------------------------------------------------------

## Data Source Links

### USDA National Agricultural Statistics Service (NASS) Quick Stats API

<https://quickstats.nass.usda.gov/>

### U.S. Census Bureau

<https://www.census.gov/>

### USDA Food and Agriculture Mapper and Explorer

<https://localfoodeconomics.com/data/food-and-agriculture-data-explorer/>

### U.S. Census Bureau TIGER/Line Cartographic Boundary Files

<https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html>

------------------------------------------------------------------------

## Local Food Market Metrics

County-level local food market indicators were compiled into the workbook `Key_Local_Food_Metrics.xlsx`.

The workbook combines variables obtained from two public sources.

### U.S. Census Bureau

The following demographic variables were obtained from the U.S. Census Bureau:

-   Total population
-   Median household income

### USDA Food and Agriculture Mapper and Explorer (FAME)

The remaining indicators were obtained from the USDA-supported **Food and Agriculture Mapper and Explorer (FAME 1.0 and FAME 2.0)** platform.

These variables include:

-   Percent of farms selling directly to consumers
-   Percent of farms using local market channels
-   Percent of farms selling directly
-   Number of farmers markets
-   Number of Community Supported Agriculture (CSA) businesses
-   Number of food hubs
-   Number of on-farm markets

Each variable was imported from a separate worksheet within the workbook and merged into a single county-level dataset.

Because missing observations for farmers markets, CSA businesses, food hubs, and on-farm markets represent the absence of those facilities rather than unavailable data, missing values for these business-count variables were replaced with zero. Missing values for demographic variables and percentage measures were retained.

------------------------------------------------------------------------

## Broiler Production Data

County-level broiler production data were downloaded directly from the USDA National Agricultural Statistics Service (NASS) Quick Stats API for the 2022 Census of Agriculture.

The analysis extracts the county-level measure:

-   Operations with broiler sales

State and county FIPS codes supplied by NASS were standardized and combined to construct the official five-digit Census county GEOID used throughout the project.

Exploratory analyses indicated that the distribution of broiler operations was highly right-skewed. Histograms of both the original values and log-transformed values were examined to evaluate the distribution before index construction.

------------------------------------------------------------------------

## County Name Standardization

County names differ across federal datasets because some agencies report legal geographic names while others omit county-equivalent suffixes such as:

-   County
-   Parish
-   Borough
-   Census Area
-   Municipality
-   Planning Region

To ensure consistent county matching, two standardized county-name keys were constructed.

### Full County Key

The first key preserves the complete legal geographic name after:

-   converting text to uppercase,
-   removing accents,
-   standardizing whitespace, and
-   standardizing common abbreviations (e.g., Saint → St.).

This key supports direct matching between datasets whose county names already agree.

### Base County Key

The second key removes county-equivalent suffixes while preserving the underlying county name.

To avoid incorrect assignments, second-stage matching is restricted to county names that occur only once within each state.

------------------------------------------------------------------------

## Two-Stage County Matching

County reconciliation proceeds in two stages.

### Stage 1: Exact Match

Counties are matched using:

-   State abbreviation
-   Full county-name key

This stage successfully matches counties whose legal geographic names are identical across datasets.

### Stage 2: Base Name Match

Counties that remain unmatched are matched using:

-   State abbreviation
-   Base county-name key

This stage resolves naming differences such as:

-   County versus Parish
-   County versus Borough
-   County versus Census Area
-   County versus Municipality
-   County versus Planning Region

Following the two-stage procedure, every county is successfully assigned its official Census GEOID.

The script also records the matching method used for every county, providing a transparent audit trail for the county reconciliation process.

------------------------------------------------------------------------

## Merging Broiler Production

After county GEOIDs have been assigned, county-level broiler production data are merged into the local food dataset using the five-digit Census GEOID.

Rather than immediately interpreting missing NASS values as zero, the script creates an indicator variable identifying whether a county has a published broiler production estimate. This distinction preserves the difference between counties with no reported value and counties for which production may have been withheld or unavailable.

------------------------------------------------------------------------

## Output

This script produces two files:

`Local_Food_Broiler_2022.csv`

`Local_Food_Broiler_2022.rds`

The resulting dataset contains:

-   county geographic identifiers,
-   local food market indicators,
-   county-level broiler production,
-   county matching diagnostics, and
-   broiler data reporting indicators.

This dataset serves as the primary input for constructing the **Local Market Readiness Index (LMRI)** in the subsequent script.

------------------------------------------------------------------------

## Required R Packages

-   rnassqs
-   readxl
-   dplyr
-   purrr
-   stringr
-   stringi
-   readr
-   tidyr
-   ggplot2
-   maps
-   viridis
-   tigris
-   sf

# Script 4: Poultry_Codefile4 - Local Market Readiness Index (LMRI)

## Purpose

This script constructs the **Local Market Readiness Index (LMRI)**, a county-level measure designed to capture the extent to which local market conditions support poultry production and local food marketing opportunities.

The index integrates indicators describing:

-   producer capacity,
-   market demand, and
-   local food infrastructure.

All variables are standardized to a common scale before being combined into a weighted composite index. The resulting LMRI serves as one of the two principal components of the **Local Poultry Market Opportunity Index (LPMOI)**.

------------------------------------------------------------------------

## Data Sources

This script uses the county-level dataset created in **Script 3**.

| Dataset | Source | Purpose |
|----|----|----|
| **Local_Food_Broiler_2022.rds** | Script 3 | Provides county-level broiler production, demographic characteristics, and local food market indicators used to construct the LMRI. |

------------------------------------------------------------------------

## Methodology

### Variable Selection

The Local Market Readiness Index is constructed from seven county-level indicators representing three broad dimensions of market readiness.

#### Producer Capacity

-   Operations with broiler sales

#### Market Potential

-   Total population
-   Median household income

#### Local Food Infrastructure

-   Farmers markets
-   Community Supported Agriculture (CSA) businesses
-   On-farm markets
-   Food hubs

These variables were selected to capture the supply of broiler producers, the size and purchasing power of local consumers, and the infrastructure supporting local food distribution.

------------------------------------------------------------------------

### Data Transformation

Several variables exhibit highly right-skewed distributions with substantial numbers of zero observations.

To reduce the influence of extreme values while preserving counties with zero observations, the following variables are transformed using the natural logarithm:

-   Broiler operations
-   Population
-   Farmers markets
-   CSA businesses
-   On-farm markets

Median household income is retained on its original scale because its distribution is considerably less skewed.

Food hubs are converted to a binary indicator representing the presence or absence of at least one food hub within the county.

------------------------------------------------------------------------

### Missing Data

Counties without published broiler production estimates are assigned zero observable broiler operations for purposes of index construction. A separate indicator variable is retained to distinguish counties with published data from counties whose values were unavailable.

Two counties lack reported median household income. Rather than removing these counties from the analysis, missing income values are imputed using the median county income within the corresponding state. An indicator identifying imputed observations is retained for transparency.

------------------------------------------------------------------------

### Variable Standardization

Because the component variables are measured on different scales, each variable is standardized using **min–max normalization**.

Normalization rescales every variable to range from 0 to 1 while preserving the relative ordering of counties.

This allows all variables to contribute comparably to the composite index regardless of their original measurement units.

------------------------------------------------------------------------

## Index Construction

The Local Market Readiness Index consists of four intermediate scores.

### Producer Base

Producer Base measures county-level poultry production capacity and is represented by the normalized number of broiler operations.

------------------------------------------------------------------------

### Market Potential

Market Potential represents the strength of local consumer demand and combines:

-   normalized population
-   normalized median household income

Both variables receive equal weight.

------------------------------------------------------------------------

### Consumer Access

Consumer Access measures the availability of local food marketing outlets by combining:

-   farmers markets,
-   CSA businesses, and
-   on-farm markets.

Each component receives equal weight.

------------------------------------------------------------------------

### Infrastructure

Infrastructure combines:

-   Consumer Access (80%)
-   Food Hub Presence (20%)

This recognizes that food hubs provide important aggregation and distribution services while consumer-facing marketing channels remain the primary mechanism connecting producers and consumers.

------------------------------------------------------------------------

## Local Market Readiness Index

The final Local Market Readiness Index combines the three major dimensions using the following weights:

| Dimension        | Weight |
|------------------|-------:|
| Producer Base    |    40% |
| Market Potential |    35% |
| Infrastructure   |    25% |

Greater emphasis is placed on producer capacity because a functioning local poultry market requires an adequate production base. Market demand receives the second-largest weight, while local food infrastructure supports—but does not replace—the presence of producers and consumers.

The final LMRI ranges from 0 to 1, where higher values indicate counties with stronger local market readiness.

------------------------------------------------------------------------

## Output

This script produces one county-level dataset:

`County_Local_Market_Readiness_Index.csv`

The dataset contains:

-   county identifiers,
-   Producer Base score,
-   Market Potential score,
-   Consumer Access score,
-   Infrastructure score, and
-   Local Market Readiness Index (LMRI).

This dataset is merged with the Local Processing Access Index in the subsequent script to construct the **Local Poultry Market Opportunity Index (LPMOI).**

------------------------------------------------------------------------

## Required R Packages

-   dplyr
-   readr
-   stringr
-   tidyr
-   ggplot2

# Script 5: Poultry_Codefile5 - Local Poultry Market Opportunity Index (LPMOI) and Visualization

## Purpose

This script integrates the **Local Market Readiness Index (LMRI)** and the **Local Processing Access Index (LPAI)** to construct the final **Local Poultry Market Opportunity Index (LPMOI)**. The script then produces the county-level analytical dataset and generates the publication-quality maps and regional comparison figures used throughout the project.

The LPMOI is designed to identify counties where investments in local poultry processing are most likely to succeed by jointly considering market readiness and access to processing infrastructure.

------------------------------------------------------------------------

## Data Sources

This script combines the outputs of previous scripts with publicly available geographic data and USDA Meat and Poultry Processing Expansion Program (MCAP) award information.

| Dataset | Source | Purpose |
|----|----|----|
| **County_Local_Market_Readiness_Index.csv** | Script 4 | County-level Local Market Readiness Index (LMRI). |
| **County_Local_Processing_Access_Index.csv** | Script 2 | County-level Local Processing Access Index (LPAI). |
| **2022 TIGER/Line Cartographic Boundary Files** | U.S. Census Bureau | County and state boundaries used for mapping. |
| **MCAPData.xlsx** | USDA Meat and Poultry Processing Expansion Program (MCAP) awards | Locations of funded poultry processing facilities used for comparison with the opportunity index. |

------------------------------------------------------------------------

## Data Source Links

### U.S. Census Bureau TIGER/Line Cartographic Boundary Files

<https://www.census.gov/geographies/mapping-files/time-series/geo/cartographic-boundary.html>

### USDA Meat and Poultry Processing Expansion Program (MCAP) Awarded Grants

<https://www.ams.usda.gov/services/grants/localmcap/awards> \### USDA Meat and Poultry Processing Expansion Program (MCAP)

MCAP award recipients were downloaded from the USDA Meat and Poultry Processing Expansion Program (MCAP). Awarded establishments were matched to the USDA Food Safety and Inspection Service (FSIS) Meat, Poultry, and Egg Product Inspection Directory using establishment names. Facilities identified as poultry processors, based on their processing descriptions, were retained for the analysis. Geographic coordinates (latitude and longitude) were then extracted from the matched FSIS records and used to map MCAP-funded poultry processing facilities.

------------------------------------------------------------------------

## Methodology

### Merging Component Indices

The county-level Local Market Readiness Index (LMRI) and Local Processing Access Index (LPAI) are merged using the five-digit Census county GEOID.

Before merging, county identifiers are standardized to ensure that all GEOIDs are stored as five-character character strings with leading zeros preserved.

The merged dataset contains every component required to construct the final Local Poultry Market Opportunity Index.

------------------------------------------------------------------------

### Local Poultry Market Opportunity Index

The Local Poultry Market Opportunity Index (LPMOI) combines the Local Market Readiness Index and the Local Processing Access Index using the **harmonic mean**.

Unlike the arithmetic mean, the harmonic mean penalizes imbalance between the two component indices. Consequently, counties receive high opportunity scores only when both market readiness and processing accessibility are strong.

This reflects the conceptual framework underlying the project:

-   strong local demand cannot fully compensate for inadequate processing access; and
-   strong processing infrastructure cannot fully compensate for weak market conditions.

For presentation purposes, the index is reported both on its original 0–1 scale and on a 0–100 scale.

------------------------------------------------------------------------

### Final County-Level Dataset

The completed analytical dataset contains:

-   county identifiers,
-   Local Market Readiness Index,
-   Local Processing Access Index,
-   Local Poultry Market Opportunity Index,
-   all intermediate index components, and
-   supporting county-level variables.

This dataset represents the principal analytical output of the project.

------------------------------------------------------------------------

### Geographic Visualization

County and state boundaries are obtained from the U.S. Census Bureau TIGER/Line Cartographic Boundary Files.

To improve cartographic accuracy, all spatial data are transformed into an equal-area projection before visualization.

County-level LPMOI values are joined to county polygons using Census GEOIDs.

National color scales are used consistently across all maps so that identical colors represent identical index values regardless of geographic region.

------------------------------------------------------------------------

### MCAP Award Locations

Locations of USDA Meat and Poultry Processing Expansion Program (MCAP) award recipients are imported and converted into spatial point features.

These locations are overlaid on the opportunity maps to facilitate visual comparison between existing federal investments and counties exhibiting high Local Poultry Market Opportunity Index values.

------------------------------------------------------------------------

### Regional Comparison

To illustrate differences in regional poultry market conditions, the analysis develops detailed comparison maps for two contrasting regions:

**Northeastern Consumer Markets**

-   Connecticut
-   Maine
-   Massachusetts
-   New Hampshire
-   Rhode Island
-   Vermont
-   New Jersey
-   New York
-   Pennsylvania

**Southeastern Commercial Broiler Region**

-   Arkansas
-   Alabama
-   Georgia
-   Mississippi

The comparison highlights differences in:

-   Local Market Readiness,
-   Processing Access,
-   Local Poultry Market Opportunity, and
-   Existing MCAP-funded processing facilities.

Interpretation panels accompany the regional maps to summarize the principal policy insights for each region.

------------------------------------------------------------------------

## Outputs

This script produces the final analytical dataset:

`County_Local_Poultry_Market_Opportunity_Index.csv`

It also generates several publication-quality figures, including:

-   National and regional Local Poultry Market Opportunity Index maps.
-   Regional comparisons of the Local Market Readiness Index.
-   Regional comparisons of the Local Processing Access Index.
-   Maps showing MCAP-awarded poultry processing facilities relative to county opportunity scores.
-   Multi-panel figures comparing the Northeastern consumer markets and the Southeastern commercial broiler region.

Figures are exported in both **PNG** and **PDF** formats.

------------------------------------------------------------------------

## Required R Packages

-   dplyr
-   readr
-   stringr
-   sf
-   tigris
-   ggplot2
-   scales
-   readxl
-   ggrepel
-   patchwork
-   grid

# Use of Generative AI

Generative AI tools (OpenAI ChatGPT) were used during the development of this project to assist with code debugging, improving code readability, refining documentation, and explaining programming concepts.

All research questions, methodological decisions, index construction, data processing, statistical analyses, interpretation of results, visualization design, and final validation of the code were developed, reviewed, and approved by the authors. The authors assume full responsibility for the accuracy, originality, and integrity of all analyses and conclusions presented in this repository.

# Citation

If you use this repository, please cite:

Bobbie, K., Ogunmoyero, O., & Ayettey, G. (2026). *Local Poultry Market Opportunity Index (LPMOI): Data and Code Repository for the USDA Local Meat Capacity Grant Program Data Visualization Challenge*. Texas A&M University, Texas Tech University and Louisiana State University.

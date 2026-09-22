# Task: Construct PUMA-Level Hotel Minimum Wage Treatment Exposure

## Research objective

We are studying employment effects of the Los Angeles hotel minimum wage ordinance (HWMO).

EDD employment outcomes are observed at the PUMA × 4-digit NAICS × month level. For the hotel analysis, the relevant EDD industry is:

- NAICS 7211: Traveler Accommodation

The hotel minimum wage policy applies only to certain hotels within the City of Los Angeles. Treatment occurs at the individual-hotel level, whereas the EDD employment outcome is observed at the PUMA level.

The goal of this task is therefore to construct a PUMA-level treatment exposure measure:

    treated_room_share_p =
        rooms in HWMO-covered hotels in PUMA p /
        total hotel rooms in PUMA p

The preferred exposure measure is based on rooms rather than hotel counts because hotel rooms should better proxy the amount of hotel employment exposed to the policy.

Do not use PUMA land-area overlap with Los Angeles to construct treatment intensity.

---

## Existing treatment classification

A separate existing dataset has already carefully classified hotels within the City of Los Angeles according to HWMO treatment status.

The classification distinguishes:

1. Subject to HWMO
2. Not subject to HWMO because hotel has <60 rooms
3. Not subject to HWMO because of a union contract
4. Not subject to HWMO because hotel is outside the City of Los Angeles

Do NOT recreate the treatment classification from scratch.

For hotels inside the City of Los Angeles, treatment status should come from the existing classified hotel dataset.

For hotels outside the City of Los Angeles:

    treated = 0

by construction.

Any hotel that the new countywide CoStar data place inside the City of Los Angeles but that cannot be matched to the existing classified hotel dataset should NOT automatically be assigned a treatment status. Flag these hotels for manual review.

---

# New CoStar Countywide Hotel Data

A new CoStar extraction contains the hotel universe for Los Angeles County.

CoStar limits exports to 500 properties, so the extraction was divided into three mutually exclusive room-count groups:

- `CostarExport_LACounty_Rooms101+.xlsx`
- `CostarExport_LACounty_Rooms31_100.xlsx`
- `CostarExport_LACounty_Rooms1_30.xlsx`

Together these should represent all CoStar hospitality properties in Los Angeles County with at least one hotel room.

The CoStar search contained approximately:

- 1,100 properties
- 103,000 hotel rooms

The approximately 103,000-room total is consistent with external estimates of the Los Angeles County hotel-room inventory and should be used as a rough QA benchmark.

Do not assume the exact total must equal 103,000, but a large departure from this after importing/cleaning should be investigated.

---

# CoStar Variables

The countywide files contain the following variables:

- `PropertyID`
- `Property Address`
- `Property Name`
- `Property Type`
- `Rooms`
- `Building Status`
- `Secondary Type`
- `Market Name`
- `Submarket Name`
- `Submarket Cluster`
- `City`
- `County Name`
- `Zip`
- `Last Sale Date`
- `Last Sale Price`
- `Year Built`
- `Taxes Total`
- `Year Renovated`
- `Month Renovated`
- `Restaurant`
- `Avg Concessions %`
- `Hotel Open Date`
- `Hotel Operator`
- `True Owner Name`
- `Hotel Class`
- `Taxes Per SF`
- `Longitude`
- `Latitude`
- `Electric Utility`
- `Brand`
- `For Sale Status`
- `Hotel Grade`
- `Hotel Location Type`
- `Market Segment`
- `Mtg Rooms`
- `Owner Name`
- `Parcel Number 1(Min)`
- `Parcel Number 2(Max)`
- `Parking Spaces/Room`
- `Power`
- `Recorded Owner Name`
- `Star Rating`
- demographic variables following these fields

For the immediate task, the essential variables are:

- `PropertyID`
- `Property Name`
- `Property Address`
- `Rooms`
- `Longitude`
- `Latitude`

Retain other useful hotel characteristics where convenient, but do not allow irrelevant CoStar fields to complicate the geographic/treatment construction.

---

# Step 1: Import and Combine CoStar Files

Read the three Excel files and append them into one countywide hotel dataset.

Add a variable indicating the source file / room-size group before appending if useful for QA.

Clean variable names consistently (e.g. with `janitor::clean_names()`).

At minimum, ensure:

- `property_id` has a consistent type
- `rooms` is numeric
- `longitude` is numeric
- `latitude` is numeric

Do not silently drop records during type conversion.

---

# Step 2: QA the Countywide Hotel Universe

Before doing any spatial work, report:

- total rows
- number of unique `PropertyID`
- duplicate `PropertyID` count
- total rooms
- missing room counts
- zero room counts
- missing longitude
- missing latitude
- counts and room totals by source file

The three room-size extracts should be mutually exclusive.

Check that their observed room counts obey the intended ranges:

- Rooms101+: Rooms >= 101
- Rooms31_100: Rooms 31–100
- Rooms1_30: Rooms 1–30

Flag violations rather than silently removing them.

Check whether duplicate PropertyIDs occur across extracts.

The combined total room count should remain approximately consistent with the ~103,000 rooms shown in the CoStar search.

---

# Step 3: Create Hotel Point Geometry

Use hotel longitude/latitude to create an `sf` point object.

CoStar longitude/latitude should initially be treated as WGS84 coordinates:

    EPSG:4326

Preserve the original longitude and latitude variables.

Flag hotels with missing or implausible coordinates.

---

# Step 4: Determine Whether Each Hotel Is Inside Los Angeles City

Use the official City of Los Angeles boundary shapefile already available in the project.

Spatially classify each hotel as:

    in_la_city = TRUE/FALSE

Do NOT use CoStar's `City` field as the authoritative treatment geography.

The spatial intersection with the official city boundary is authoritative.

However, compare the spatial classification with CoStar's `City` field as a QA check and inspect important disagreements.

Hotels outside the official City of Los Angeles boundary are untreated:

    treated = 0

They do not require further HWMO eligibility classification.

---

# Step 5: Merge Existing HWMO Classification

Locate the existing hotel-level HWMO classification dataset in the project.

Prefer matching on a stable unique identifier such as CoStar `PropertyID` if that identifier exists in both datasets.

Do not use fuzzy hotel-name matching automatically without first determining whether a reliable identifier is available.

For hotels spatially located inside Los Angeles City:

- merge the existing HWMO treatment classification
- preserve the detailed treatment category
- flag unmatched hotels for manual review

Expected categories include approximately:

    treated
    untreated_less_than_60_rooms
    untreated_union
    untreated_outside_city

The exact existing labels should be preserved or mapped transparently rather than guessed.

For hotels outside LA City:

    treated = 0
    treatment_category = "outside_city"

Do not overwrite an existing treatment classification until consistency has been checked.

---

# Step 6: Assign Hotels to PUMAs

Use the 2020 Census PUMA boundaries already used for the EDD analysis.

Spatially assign every hotel to its PUMA using its longitude/latitude.

The resulting hotel-level analytic crosswalk should contain at minimum:

    property_id
    property_name
    property_address
    rooms
    longitude
    latitude
    in_la_city
    puma
    treatment_category
    treated

Retain geometry separately or in the same `sf` object as appropriate.

Check for:

- hotels that fail to match a PUMA
- hotels assigned outside Los Angeles County unexpectedly
- duplicate hotel-PUMA assignments

Each hotel should belong to exactly one PUMA.

---

# Step 7: Construct PUMA-Level Treatment Exposure

Aggregate the hotel-level data to PUMA.

For each PUMA calculate at minimum:

    total_hotels
    total_rooms

    treated_hotels
    treated_rooms

    untreated_outside_city_hotels
    untreated_outside_city_rooms

    untreated_union_hotels
    untreated_union_rooms

    untreated_less_than_60_hotels
    untreated_less_than_60_rooms

Then calculate:

    treated_hotel_share = treated_hotels / total_hotels

    treated_room_share = treated_rooms / total_rooms

The PRIMARY treatment exposure measure is:

    treated_room_share

because rooms are expected to be more closely related to hotel employment than hotel counts.

For a PUMA entirely outside Los Angeles City:

    treated_room_share = 0

even though the countywide CoStar data now allow us to observe its total room inventory as well.

For PUMAs crossing the Los Angeles City boundary, the denominator MUST contain hotel rooms on BOTH sides of the city boundary.

Example:

- 1,500 treated rooms inside LA
- 500 untreated rooms inside LA
- 1,000 hotel rooms outside LA but in the same PUMA

Then:

    treated_room_share = 1500 / 3000 = 0.50

NOT:

    1500 / 2000 = 0.75

This is important because EDD NAICS 7211 employment is observed for the entire PUMA.

---

# Step 8: PUMA-Level QA

Create a table showing for each PUMA:

- PUMA ID
- total hotels
- total rooms
- treated hotels
- treated rooms
- treated hotel share
- treated room share
- rooms outside LA City
- rooms untreated because <60 rooms
- rooms untreated because union contract

Check that:

    treated_rooms <= total_rooms

and:

    0 <= treated_room_share <= 1

Room categories should reconcile with total rooms once all inside-LA hotels have valid classifications.

Flag rather than silently resolve any discrepancy.

---

# Step 9: Geographic QA Maps

Create maps useful for validating the construction.

At minimum:

## Map A: Hotel room inventory by PUMA

Map total hotel rooms by PUMA.

## Map B: HWMO treatment exposure

Map `treated_room_share` by PUMA.

Suggested bins:

- 0–20%
- 20–40%
- 40–60%
- 60–80%
- 80–100%

Distinguish PUMAs with no hotels if relevant.

Overlay the City of Los Angeles boundary where useful.

These maps should allow visual comparison with the existing hotel-level treatment map.

---

# Interpretation

Treatment is NOT defined as:

    PUMA intersects Los Angeles City

and is NOT defined as:

    fraction of PUMA land area inside Los Angeles City

Instead, treatment is a continuous measure of the fraction of hotel-room capacity in each PUMA that is subject to HWMO.

This matches the geography of the EDD outcome better because EDD observes NAICS 7211 employment for the entire PUMA.

A boundary PUMA can therefore have an exposure such as 0.25, 0.50, or 0.75 depending on its hotel composition.

A PUMA wholly outside Los Angeles City has exposure 0.

---

# Coding Requirements

- Use R.
- Prefer `dplyr`, `tidyr`, `readxl`, `janitor`, `sf`, and `ggplot2`.
- Keep raw data unchanged.
- Create intermediate objects rather than overwriting raw imports.
- Make all spatial classifications programmatic and reproducible.
- Use official geographic boundaries rather than CoStar city labels.
- Do not silently discard unmatched hotels.
- Do not infer HWMO treatment status for unmatched inside-LA hotels.
- Produce explicit QA output before constructing final treatment measures.
- Preserve `PropertyID` throughout the pipeline.
- Keep the hotel-level crosswalk as an output in addition to the PUMA-level aggregation.

Before writing substantial new code, inspect the repository for:
1. existing City of Los Angeles boundary objects/files,
2. existing 2020 PUMA objects/files,
3. the existing HWMO hotel classification,
4. existing naming conventions and helper functions.

Reuse those resources rather than creating parallel versions when possible.
# Countywide hotel-room treatment exposure by 2020 PUMA.
source("script/0-config.R")

# Import and QA the three mutually exclusive CoStar extracts.
costar_files <- c(
    rooms_1_30 = file.path(costar_path, "CostarExport_LACounty_Rooms1_30.xlsx"),
    rooms_31_100 = file.path(costar_path, "CostarExport_LACounty_Rooms31_100.xlsx"),
    rooms_101_plus = file.path(costar_path, "CostarExport_LACounty_Rooms101+.xlsx")
)
stopifnot(all(file.exists(costar_files)))
imports <- lapply(names(costar_files), function(g) {
    x <- janitor::clean_names(readxl::read_excel(costar_files[[g]]))
    x$source_group <- g
    x$source_row <- seq_len(nrow(x))
    x
})
hotels_raw <- dplyr::bind_rows(imports)
hotels <- dplyr::mutate(
    hotels_raw,
    property_id = trimws(format(property_id, scientific = FALSE, trim = TRUE)),
    rooms_failed = !is.na(rooms) & is.na(suppressWarnings(as.numeric(rooms))),
    longitude_failed = !is.na(longitude) & is.na(suppressWarnings(as.numeric(longitude))),
    latitude_failed = !is.na(latitude) & is.na(suppressWarnings(as.numeric(latitude))),
    rooms = suppressWarnings(as.numeric(rooms)),
    longitude = suppressWarnings(as.numeric(longitude)),
    latitude = suppressWarnings(as.numeric(latitude)),
    duplicate_property_id = duplicated(property_id) | duplicated(property_id, fromLast = TRUE),
    valid_coordinates = is.finite(longitude) & longitude >= -180 & longitude <= 180 &
        is.finite(latitude) & latitude >= -90 & latitude <= 90,
    source_room_range_violation = dplyr::case_when(
        source_group == "rooms_1_30" ~ !(rooms >= 1 & rooms <= 30),
        source_group == "rooms_31_100" ~ !(rooms >= 31 & rooms <= 100),
        source_group == "rooms_101_plus" ~ !(rooms >= 101),
        TRUE ~ TRUE
    )
)
import_qa <- hotels |>
    dplyr::group_by(source_group) |>
    dplyr::summarise(
        rows = dplyr::n(), unique_property_ids = dplyr::n_distinct(property_id),
        duplicate_property_ids = sum(duplicate_property_id), total_rooms = sum(rooms, na.rm = TRUE),
        missing_rooms = sum(is.na(rooms)), zero_rooms = sum(rooms == 0, na.rm = TRUE),
        missing_longitude = sum(is.na(longitude)), missing_latitude = sum(is.na(latitude)),
        room_range_violations = sum(source_room_range_violation),
        conversion_failures = sum(rooms_failed | longitude_failed | latitude_failed), .groups = "drop"
    )
print(import_qa)
stopifnot(nrow(hotels) == dplyr::n_distinct(hotels$property_id),
          !any(hotels$source_room_range_violation),
          !any(hotels$rooms_failed | hotels$longitude_failed | hotels$latitude_failed))

# Authoritative geography: dissolved LA council districts and Census PUMAs.
districts <- sf::read_sf(council_district_file)
la_city <- sf::st_union(sf::st_make_valid(sf::st_transform(districts, 4326)))
ca_pumas <- tigris::pumas(state = "CA", year = 2023, cb = FALSE,
                          class = "sf", progress_bar = FALSE)
la_pumas <- ca_pumas[grepl("Los Angeles County", ca_pumas$NAMELSAD20), ]
la_pumas$puma <- as.character(as.integer(la_pumas$PUMACE20))
la_pumas$puma_name <- la_pumas$NAMELSAD20
stopifnot(nrow(la_pumas) == 71, !anyDuplicated(la_pumas$puma))

points <- sf::st_as_sf(dplyr::filter(hotels, valid_coordinates),
                       coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
city_hits <- sf::st_within(points, la_city)
puma_hits <- sf::st_intersects(points, sf::st_transform(la_pumas, 4326))
geo <- data.frame(source_group = points$source_group, source_row = points$source_row,
                  in_la_city = lengths(city_hits) == 1, city_matches = lengths(city_hits),
                  puma_matches = lengths(puma_hits), puma = NA_character_)
one_puma <- geo$puma_matches == 1
geo$puma[one_puma] <- la_pumas$puma[unlist(puma_hits[one_puma], use.names = FALSE)]
crosswalk <- dplyr::left_join(hotels, geo, by = c("source_group", "source_row"))

# Existing roster supplies the initial binary status. Both the aggregate union
# export and detailed union control groups C01-C04 override conflicting treated
# labels, reflecting the confirmed union exemption.
old <- readRDS(file.path(clean_path, "HotelsLACInfo_allSizeallTreatStatus.rds")) |>
    dplyr::transmute(property_id = trimws(format(PropertyID, scientific = FALSE, trim = TRUE)),
                     existing_treated = as.numeric(treated))
stopifnot(nrow(dplyr::filter(dplyr::count(old, property_id, existing_treated), n > 1 & is.na(property_id))) == 0)
old <- dplyr::distinct(old, property_id, .keep_all = TRUE)
detail <- readRDS(file.path(clean_path, "AnalysisHotelInfo_aggData_includeNoDataReported.rds"))
if (inherits(detail, "sf")) detail <- sf::st_drop_geometry(detail)
detail <- dplyr::transmute(
    detail, property_id = trimws(format(PropertyID, scientific = FALSE, trim = TRUE)), label
)
analysis_groups <- readRDS(file.path(clean_path, "AnalysisHotelInfo_DataReported.rds"))
if (inherits(analysis_groups, "sf")) analysis_groups <- sf::st_drop_geometry(analysis_groups)
analysis_union <- analysis_groups |>
    dplyr::filter(label %in% paste0("C0", 1:4)) |>
    dplyr::transmute(
        property_id = trimws(format(PropertyID, scientific = FALSE, trim = TRUE)),
        label = "CG_Union"
    )
detail <- dplyr::bind_rows(detail, analysis_union) |>
    dplyr::group_by(property_id) |>
    dplyr::summarise(has_treated_label = any(label == "AllTreated"),
                     has_union_label = any(label == "CG_Union"),
                     has_small_label = any(label == "CG_Small"),
                     detail_conflict = sum(c(has_treated_label, has_union_label, has_small_label)) > 1,
                     .groups = "drop")
crosswalk <- crosswalk |>
    dplyr::left_join(old, by = "property_id") |>
    dplyr::left_join(detail, by = "property_id") |>
    dplyr::mutate(
        in_la_city = dplyr::coalesce(in_la_city, FALSE),
        treatment_category = dplyr::case_when(
            !in_la_city ~ "outside_city",
            is.na(existing_treated) ~ "manual_review_unmatched_inside_la",
            has_union_label %in% TRUE ~ "untreated_union",
            existing_treated == 1 ~ "treated",
            existing_treated == 0 & rooms < 60 ~ "untreated_less_than_60_rooms",
            existing_treated == 0 ~ "untreated_inside_la_other",
            TRUE ~ "manual_review_classification_conflict"),
        treated = dplyr::case_when(
            !in_la_city ~ 0,
            has_union_label %in% TRUE ~ 0,
            existing_treated %in% c(0, 1) ~ existing_treated,
            TRUE ~ NA_real_),
        costar_city_says_la = toupper(trimws(city)) == "LOS ANGELES",
        city_field_disagrees = costar_city_says_la != in_la_city
    )

manual_review <- dplyr::filter(crosswalk, is.na(treated) | puma_matches != 1 |
                               duplicate_property_id | !valid_coordinates)

# Preserve a regenerable review template, then apply the separately saved manual
# decisions. The completed file is never written by this script.
dir.create("output", recursive = TRUE, showWarnings = FALSE)
utils::write.csv(sf::st_drop_geometry(manual_review),
                 "output/costar_puma_treatment_manual_review.csv", row.names = FALSE)
review_file <- "output/costar_puma_treatment_manual_review_filled.csv"
stopifnot(file.exists(review_file))
review <- utils::read.csv(review_file, stringsAsFactors = FALSE,
                          na.strings = c("", "NA"), check.names = FALSE) |>
    dplyr::mutate(
        property_id = trimws(as.character(property_id)),
        final_in_scope = tolower(trimws(final_in_scope)),
        final_in_la_city = tolower(trimws(final_in_la_city)),
        final_treatment_category = trimws(final_treatment_category)
    )
required_review_columns <- c("property_id", "final_in_scope", "final_in_la_city",
                             "final_treatment_category", "review_notes")
stopifnot(all(required_review_columns %in% names(review)),
          !anyDuplicated(review$property_id),
          all(manual_review$property_id %in% review$property_id),
          all(review$property_id %in% crosswalk$property_id),
          all(review$final_in_scope %in% c("yes", "no")),
          all(review$final_in_la_city %in% c("yes", "no")),
          all(!is.na(review$final_treatment_category)),
          all(review$final_treatment_category[review$final_in_scope == "no"] == "out_of_scope"))
allowed_review_categories <- c("treated", "untreated_union",
                               "untreated_less_than_60_rooms", "outside_city",
                               "out_of_scope")
stopifnot(all(review$final_treatment_category %in% allowed_review_categories))

review_decisions <- review |>
    dplyr::transmute(
        property_id,
        reviewed_in_scope = final_in_scope == "yes",
        reviewed_in_la_city = final_in_la_city == "yes",
        reviewed_treatment_category = final_treatment_category,
        manual_review_notes = review_notes
    )
crosswalk <- crosswalk |>
    dplyr::left_join(review_decisions, by = "property_id") |>
    dplyr::mutate(
        in_scope = dplyr::coalesce(reviewed_in_scope, TRUE),
        in_la_city = dplyr::coalesce(reviewed_in_la_city, in_la_city),
        treatment_category = dplyr::coalesce(reviewed_treatment_category,
                                             treatment_category),
        treated = dplyr::case_when(
            !in_scope ~ NA_real_,
            reviewed_treatment_category == "treated" ~ 1,
            reviewed_treatment_category %in% c("untreated_union",
                                                "untreated_less_than_60_rooms",
                                                "outside_city") ~ 0,
            TRUE ~ treated
        )
    )
stopifnot(!any(is.na(crosswalk$treated[crosswalk$in_scope &
                                      crosswalk$puma_matches == 1])))
print(dplyr::count(crosswalk, treatment_category, sort = TRUE))
print(dplyr::summarise(
    crosswalk,
    rows = dplyr::n(), rooms = sum(rooms, na.rm = TRUE),
    in_scope_hotels = sum(in_scope), excluded_hotels = sum(!in_scope),
    inside_la = sum(in_la_city),
    in_scope_unclassified = sum(in_scope & is.na(treated)),
    city_field_disagreements = sum(city_field_disagrees, na.rm = TRUE),
    failed_puma_matches = sum(is.na(puma_matches) | puma_matches != 1)
))

# PUMA totals include rooms on both sides of the city boundary.
puma_exposure <- crosswalk |>
    dplyr::filter(in_scope, puma_matches == 1) |>
    dplyr::group_by(puma) |>
    dplyr::summarise(
        total_hotels = dplyr::n(), total_rooms = sum(rooms, na.rm = TRUE),
        treated_hotels = sum(treated == 1, na.rm = TRUE), treated_rooms = sum(rooms[treated == 1], na.rm = TRUE),
        untreated_outside_city_hotels = sum(treatment_category == "outside_city"),
        untreated_outside_city_rooms = sum(rooms[treatment_category == "outside_city"], na.rm = TRUE),
        untreated_union_hotels = sum(treatment_category == "untreated_union"),
        untreated_union_rooms = sum(rooms[treatment_category == "untreated_union"], na.rm = TRUE),
        untreated_less_than_60_hotels = sum(treatment_category == "untreated_less_than_60_rooms"),
        untreated_less_than_60_rooms = sum(rooms[treatment_category == "untreated_less_than_60_rooms"], na.rm = TRUE),
        untreated_inside_other_rooms = sum(rooms[treatment_category == "untreated_inside_la_other"], na.rm = TRUE),
        unclassified_inside_hotels = sum(in_la_city & is.na(treated)),
        unclassified_inside_rooms = sum(rooms[in_la_city & is.na(treated)], na.rm = TRUE), .groups = "drop")
puma_exposure <- dplyr::left_join(dplyr::select(sf::st_drop_geometry(la_pumas), puma, puma_name),
                                    puma_exposure, by = "puma")
numeric_columns <- setdiff(names(puma_exposure), c("puma", "puma_name"))
puma_exposure[numeric_columns] <- lapply(puma_exposure[numeric_columns],
                                         function(x) replace(x, is.na(x), 0))
puma_exposure <- dplyr::mutate(
    puma_exposure,
    treated_hotel_share = dplyr::if_else(total_hotels > 0 & unclassified_inside_hotels == 0,
                                          treated_hotels / total_hotels, NA_real_),
    treated_room_share = dplyr::if_else(total_rooms > 0 & unclassified_inside_hotels == 0,
                                         treated_rooms / total_rooms, NA_real_),
    category_rooms_reconcile = total_rooms == treated_rooms + untreated_outside_city_rooms +
        untreated_union_rooms + untreated_less_than_60_rooms + untreated_inside_other_rooms +
        unclassified_inside_rooms)
puma_exposure$intersects_la_city <- lengths(sf::st_intersects(
    la_pumas, sf::st_transform(la_city, sf::st_crs(la_pumas))
)) > 0
puma_exposure$treated_hotel_share[!puma_exposure$intersects_la_city] <- 0
puma_exposure$treated_room_share[!puma_exposure$intersects_la_city] <- 0
stopifnot(all(puma_exposure$treated_rooms <= puma_exposure$total_rooms),
          all(is.na(puma_exposure$treated_room_share) |
              dplyr::between(puma_exposure$treated_room_share, 0, 1)))
print(dplyr::as_tibble(puma_exposure), n = Inf)

dir.create(clean_path, recursive = TRUE, showWarnings = FALSE)
saveRDS(crosswalk, file.path(clean_path, "hotel_countywide_puma_crosswalk.rds"))
saveRDS(puma_exposure, file.path(clean_path, "puma_treated_room_share_countywide.rds"))
utils::write.csv(import_qa, "output/costar_countywide_import_qa.csv", row.names = FALSE)

# Countywide geographic QA maps.
map_data <- dplyr::left_join(la_pumas, puma_exposure, by = c("puma", "puma_name"))
map_data <- sf::st_transform(map_data, 3310)
city_map <- sf::st_transform(la_city, 3310)
puma_parts <- suppressWarnings(sf::st_cast(map_data, "POLYGON"))
part_centers <- sf::st_transform(sf::st_point_on_surface(sf::st_geometry(puma_parts)), 4326)
map_data <- puma_parts[sf::st_coordinates(part_centers)[, 2] > 33.5, ]
map_bounds <- sf::st_bbox(map_data)
room_breaks <- unique(pretty(c(0, max(map_data$total_rooms)), n = 6))
room_colors <- rev(grDevices::hcl.colors(length(room_breaks) - 1, "YlOrRd"))
room_bin <- cut(map_data$total_rooms, room_breaks, include.lowest = TRUE)
share_breaks <- seq(0, 1, 0.2)
share_colors <- rev(grDevices::hcl.colors(5, "Blues 3"))
share_bin <- cut(map_data$treated_room_share, share_breaks, include.lowest = TRUE)
share_fill <- share_colors[share_bin]
share_fill[is.na(share_fill)] <- "gray80"

dir.create("figures/raw", recursive = TRUE, showWarnings = FALSE)
pdf("figures/raw/PUMA-countywide-hotel-treatment.pdf", width = 10, height = 6)
par(mfrow = c(1, 2), mar = c(1, 1, 3, 1), oma = c(3, 0, 2, 0))
plot(sf::st_geometry(map_data), col = room_colors[room_bin], border = "white", lwd = 0.5,
     xlim = map_bounds[c("xmin", "xmax")], ylim = map_bounds[c("ymin", "ymax")],
     axes = FALSE, main = "Total hotel rooms")
plot(city_map, add = TRUE, border = "black", lwd = 1.2)
legend("bottomleft", legend = levels(room_bin), fill = room_colors,
       border = NA, bty = "n", cex = 0.7, title = "Rooms")
plot(sf::st_geometry(map_data), col = share_fill, border = "white", lwd = 0.5,
     xlim = map_bounds[c("xmin", "xmax")], ylim = map_bounds[c("ymin", "ymax")],
     axes = FALSE, main = "Share of hotel rooms treated")
plot(city_map, add = TRUE, border = "black", lwd = 1.2)
legend("bottomleft", legend = c("0-20%", "20-40%", "40-60%", "60-80%",
                                "80-100%", "Unresolved/no hotels"),
       fill = c(share_colors, "gray80"), border = NA, bty = "n", cex = 0.7)
mtext("Countywide hotel inventory and HWMO exposure by PUMA",
      outer = TRUE, side = 3, line = 0.3)
mtext("Black line: LA City | PUMA denominators include rooms on both sides of the boundary",
      outer = TRUE, side = 1, line = 1, cex = 0.8)
dev.off()

# LA City extent version for comparison with the hotel-level maps.
city_bounds <- sf::st_bbox(city_map)
pdf("figures/raw/PUMA-hotel-room-treatment.pdf", width = 10, height = 6)
par(mfrow = c(1, 2), mar = c(1, 1, 3, 1), oma = c(3, 0, 2, 0))
plot(sf::st_geometry(map_data), col = room_colors[room_bin], border = "white", lwd = 0.5,
     xlim = city_bounds[c("xmin", "xmax")], ylim = city_bounds[c("ymin", "ymax")],
     axes = FALSE, main = "Total hotel rooms")
plot(city_map, add = TRUE, border = "black", lwd = 1.2)
legend("bottomleft", legend = levels(room_bin), fill = room_colors,
       border = NA, bty = "n", cex = 0.7, title = "Rooms")
plot(sf::st_geometry(map_data), col = share_fill, border = "white", lwd = 0.5,
     xlim = city_bounds[c("xmin", "xmax")], ylim = city_bounds[c("ymin", "ymax")],
     axes = FALSE, main = "Share of hotel rooms treated")
plot(city_map, add = TRUE, border = "black", lwd = 1.2)
legend("bottomleft", legend = c("0-20%", "20-40%", "40-60%", "60-80%",
                                "80-100%"),
       fill = share_colors, border = NA, bty = "n", cex = 0.7)
mtext("Countywide hotel inventory and HWMO exposure by PUMA",
      outer = TRUE, side = 3, line = 0.3)
mtext("LA City extent | Full countywide CoStar sample | Black line: LA City boundary",
      outer = TRUE, side = 1, line = 1, cex = 0.8)
dev.off()

# Parallel distributions for PUMAs intersecting LA City.
histogram_data <- dplyr::filter(puma_exposure, intersects_la_city)
resolved_shares <- histogram_data$treated_room_share[
    !is.na(histogram_data$treated_room_share)
]
unresolved_pumas <- sum(is.na(histogram_data$treated_room_share))
hist_room_breaks <- seq(0, ceiling(max(histogram_data$total_rooms) / 1000) * 1000,
                        by = 1000)
hist_room_colors <- rev(grDevices::hcl.colors(length(hist_room_breaks) - 1,
                                               "YlOrRd"))
hist_share_breaks <- seq(0, 1, 0.1)
hist_share_colors <- rev(grDevices::hcl.colors(length(hist_share_breaks) - 1,
                                                "Blues 3"))

pdf("figures/raw/PUMA-hotel-room-treatment-histograms.pdf",
    width = 10, height = 5.5, useDingbats = FALSE)
par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1), oma = c(2.5, 0, 2, 0))
hist(histogram_data$total_rooms,
     breaks = hist_room_breaks, col = hist_room_colors, border = "white",
     main = "Total hotel rooms", xlab = "Hotel rooms in PUMA",
     ylab = "Number of PUMAs", xaxt = "n")
axis(1, at = hist_room_breaks,
     labels = format(hist_room_breaks, big.mark = ",", scientific = FALSE),
     cex.axis = 0.8)
hist(resolved_shares,
     breaks = hist_share_breaks, col = hist_share_colors, border = "white",
     main = "Share of hotel rooms treated", xlab = "Treated-room share",
     ylab = "Number of PUMAs", xaxt = "n")
axis(1, at = hist_share_breaks, labels = paste0(hist_share_breaks * 100, "%"),
     cex.axis = 0.8)
mtext("Distribution across PUMAs intersecting LA City",
      outer = TRUE, side = 3, line = 0.3)
mtext(paste0("Full countywide CoStar sample | Treatment-share histogram excludes ",
             unresolved_pumas, " PUMAs pending review"),
      outer = TRUE, side = 1, line = 0.8, cex = 0.8)
dev.off()

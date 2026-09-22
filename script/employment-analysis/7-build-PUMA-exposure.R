# PUMA overlap with official LA city boundaries.
# Run from the repository root. Spatial objects remain in memory for inspection.
# PUMA-level city overlap and treated-room shares are saved in clean data.

# Inputs -----------------------------------------------------------------
    source("script/0-config.R")
    clean_path <- file.path(data_path, "clean")
    dir.create(clean_path, recursive = TRUE, showWarnings = FALSE)
# Detailed TIGER/Line boundaries use the 2020 PUMA definitions matching EDD.
# Do not use the generalized cartographic polygons from the coverage map.
    ca_pumas <- tigris::pumas(state = "CA", year = 2023, cb = FALSE,
                             class = "sf", progress_bar = FALSE)
    la_pumas <- ca_pumas[grepl("Los Angeles County", ca_pumas$NAMELSAD20), ]
    la_pumas$puma <- as.character(as.integer(la_pumas$PUMACE20))
    la_pumas$puma_name <- la_pumas$NAMELSAD20
    stopifnot(nrow(la_pumas) == 71, !anyDuplicated(la_pumas$puma))

# Calculate treated-room share by workplace PUMA -------------------------
# The clean hotel roster already identifies covered hotels and room counts.
    hotels <- readRDS(file.path(clean_path, "HotelsLACInfo_allSizeallTreatStatus.rds"))
    stopifnot(all(hotels$treated %in% c(0, 1)),
              all(is.na(hotels$Rooms) | hotels$Rooms >= 0))
    hotels$hotel_row <- seq_len(nrow(hotels))

# Assign hotels with valid coordinates to PUMAs.
    valid_coordinates <- with(hotels, is.finite(Longitude) & is.finite(Latitude) &
                               Longitude >= -180 & Longitude <= 180 &
                               Latitude >= -90 & Latitude <= 90)
    hotel_points <- sf::st_as_sf(hotels[valid_coordinates, ],
                                coords = c("Longitude", "Latitude"),
                                crs = 4326, remove = FALSE)
    hotel_points <- sf::st_transform(hotel_points, sf::st_crs(la_pumas))
    hotel_matches <- sf::st_intersects(hotel_points, la_pumas)
    match_count <- lengths(hotel_matches)

# Use only unique spatial matches so rooms are never counted more than once.
    hotel_assignments <- data.frame(
        hotel_row = hotel_points$hotel_row, puma = NA_character_,
        puma_matches = match_count
    )
    unique_match <- match_count == 1
    puma_rows <- unlist(hotel_matches[unique_match], use.names = FALSE)
    hotel_assignments$puma[unique_match] <- la_pumas$puma[puma_rows]
    hotels <- dplyr::left_join(hotels, hotel_assignments, by = "hotel_row")
    print(dplyr::count(hotels, puma_matches, .drop = FALSE))

    puma_treated_share <- hotels |>
        dplyr::filter(puma_matches == 1) |>
        dplyr::group_by(puma) |>
        dplyr::summarise(
            hotel_count = dplyr::n(),
            treated_hotel_count = sum(treated == 1),
            total_rooms = sum(Rooms, na.rm = TRUE),
            treated_rooms = sum(Rooms[treated == 1], na.rm = TRUE),
            hotels_missing_rooms = sum(is.na(Rooms)),
            .groups = "drop"
        )
    puma_treated_share <- dplyr::left_join(
        dplyr::select(sf::st_drop_geometry(la_pumas), puma, puma_name),
        puma_treated_share, by = "puma"
    )
    count_columns <- c("hotel_count", "treated_hotel_count", "total_rooms",
                       "treated_rooms", "hotels_missing_rooms")
    puma_treated_share[count_columns] <- lapply(
        puma_treated_share[count_columns], function(x) replace(x, is.na(x), 0)
    )
    puma_treated_share$treated_room_share <- dplyr::if_else(
        puma_treated_share$total_rooms > 0,
        puma_treated_share$treated_rooms / puma_treated_share$total_rooms,
        NA_real_
    )
    stopifnot(all(puma_treated_share$treated_rooms <= puma_treated_share$total_rooms),
              all(puma_treated_share$treated_room_share >= 0 |
                  is.na(puma_treated_share$treated_room_share)),
              all(puma_treated_share$treated_room_share <= 1 |
                  is.na(puma_treated_share$treated_room_share)))
    puma_treated_share <- dplyr::arrange(
        puma_treated_share, dplyr::desc(treated_room_share)
    )

# City overlap is independent of hotel assignment. The 15 council districts
# collectively cover LA City, so dissolve every district into one city boundary.
    if (!file.exists(council_district_file)) {
        stop("Council-district shapefile is missing: ", council_district_file)
    }
    council_districts <- sf::read_sf(council_district_file)
    stopifnot(nrow(council_districts) == 15, !any(sf::st_is_empty(council_districts)))

# California Albers is an equal-area projection with coordinates in meters.
# Union districts so internal council boundaries do not affect intersections.
    council_districts <- sf::st_make_valid(sf::st_transform(council_districts, 3310))
    la_city <- sf::st_union(sf::st_geometry(council_districts))
    la_pumas <- sf::st_make_valid(sf::st_transform(la_pumas, 3310))
    la_pumas$puma_area_km2 <- as.numeric(sf::st_area(la_pumas)) / 1e6

# This is share of total polygon area, including water, NOT land-only share.
# Keep offshore PUMA pieces in the denominator even though maps omit them.
    city_overlap <- sf::st_intersection(la_pumas[c("puma")], la_city)
    city_overlap$city_area_km2 <- as.numeric(sf::st_area(city_overlap)) / 1e6
    overlap_area <- sf::st_drop_geometry(city_overlap)
    overlap_area <- dplyr::group_by(overlap_area, puma)
    overlap_area <- dplyr::summarise(overlap_area,
                                    city_area_km2 = sum(city_area_km2), .groups = "drop")
    puma_city_share <- sf::st_drop_geometry(la_pumas)
    puma_city_share <- dplyr::select(puma_city_share, puma, puma_name, puma_area_km2)
    puma_city_share <- dplyr::left_join(puma_city_share, overlap_area, by = "puma")
    puma_city_share$city_area_km2[is.na(puma_city_share$city_area_km2)] <- 0
    puma_city_share$city_area_share <- puma_city_share$city_area_km2 / puma_city_share$puma_area_km2
    stopifnot(all(puma_city_share$city_area_share >= 0),
              all(puma_city_share$city_area_share <= 1 + 1e-8))

# Separate tiny boundary slivers from substantive overlap using an explicit
# 0.1% area tolerance. Keep exact shares so this choice can be reviewed.
    boundary_tolerance <- 0.001
    puma_city_share <- dplyr::mutate(
        puma_city_share,
        city_class = dplyr::case_when(
            city_area_share <= boundary_tolerance ~ "Outside (within tolerance)",
            city_area_share >= 1 - boundary_tolerance ~ "Inside (within tolerance)",
            TRUE ~ "Mixed"
        )
    )
    puma_city_share <- dplyr::arrange(puma_city_share, dplyr::desc(city_area_share))
    print(dplyr::as_tibble(puma_city_share), n = Inf)
    print(dplyr::count(puma_city_share, city_class))
    saveRDS(puma_city_share,
            file.path(clean_path, "puma_la_city_overlap_crosswalk.rds"))

# PUMAs wholly outside LA City are untreated by definition for this analysis.
# Preserve observed values for every positive overlap, including tiny slivers,
# so those PUMAs remain available for the CoStar completeness review.
    non_city_pumas <- puma_city_share$puma[puma_city_share$city_area_km2 == 0]
    puma_treated_share$total_rooms[
        puma_treated_share$puma %in% non_city_pumas
    ] <- NA_real_
    puma_treated_share$treated_room_share[
        puma_treated_share$puma %in% non_city_pumas
    ] <- 0
    print(dplyr::as_tibble(puma_treated_share), n = Inf)
    saveRDS(puma_treated_share,
            file.path(clean_path, "puma_treated_room_share.rds"))

# Two-panel map of PUMAs overlapping LA City ----------------------------
# Draw the dissolved city first, then overlay only substantive PUMA overlaps.
    overlapping_pumas <- dplyr::filter(
        puma_city_share, city_area_share > boundary_tolerance
    )
    hotel_room_map <- dplyr::inner_join(
        la_pumas, dplyr::select(overlapping_pumas, puma), by = "puma"
    )
    hotel_room_map <- dplyr::left_join(hotel_room_map, puma_treated_share,
                                       by = c("puma", "puma_name"))
    map_bounds <- sf::st_bbox(la_city)

    total_breaks <- unique(pretty(c(0, max(hotel_room_map$total_rooms)), n = 6))
    total_colors <- rev(grDevices::hcl.colors(length(total_breaks) - 1, "YlOrRd"))
    total_bin <- cut(hotel_room_map$total_rooms, breaks = total_breaks,
                     include.lowest = TRUE)
    total_labels <- paste0(
        format(head(total_breaks, -1), big.mark = ",", scientific = FALSE), "-",
        format(tail(total_breaks, -1), big.mark = ",", scientific = FALSE)
    )

    share_breaks <- seq(0, 1, by = 0.2)
    share_colors <- rev(grDevices::hcl.colors(length(share_breaks) - 1, "Blues 3"))
    share_bin <- cut(hotel_room_map$treated_room_share, breaks = share_breaks,
                     include.lowest = TRUE)
    share_labels <- paste0(head(share_breaks, -1) * 100, "-",
                           tail(share_breaks, -1) * 100, "%")
    share_fill <- share_colors[share_bin]
    share_fill[is.na(share_fill)] <- "gray90"

    dir.create("figures/raw", recursive = TRUE, showWarnings = FALSE)
    pdf("figures/raw/PUMA-hotel-room-treatment.pdf", width = 10, height = 6)
    par(mfrow = c(1, 2), mar = c(1, 1, 3, 1), oma = c(3, 0, 2, 0))

    plot(la_city, col = "gray95", border = "gray55", lwd = 0.8,
         xlim = map_bounds[c("xmin", "xmax")],
         ylim = map_bounds[c("ymin", "ymax")], axes = FALSE,
         main = "Total hotel rooms")
    plot(sf::st_geometry(hotel_room_map), add = TRUE,
         col = total_colors[total_bin], border = "white", lwd = 0.5)
    legend("bottomleft", legend = total_labels, fill = total_colors,
           border = NA, bty = "n", cex = 0.75, title = "Rooms")

    plot(la_city, col = "gray95", border = "gray55", lwd = 0.8,
         xlim = map_bounds[c("xmin", "xmax")],
         ylim = map_bounds[c("ymin", "ymax")], axes = FALSE,
         main = "Share of hotel rooms treated")
    plot(sf::st_geometry(hotel_room_map), add = TRUE,
         col = share_fill, border = "white", lwd = 0.5)
    legend("bottomleft", legend = c(share_labels, "No hotels"),
           fill = c(share_colors, "gray90"), border = NA, bty = "n",
           cex = 0.75, title = "Treated share")

    mtext("Hotel rooms and HWMO treatment by PUMA", outer = TRUE,
          side = 3, line = 0.3)
    mtext("PUMAs overlapping LA City | Source: CoStar hotel roster; Census boundaries",
          outer = TRUE, side = 1, line = 1, cex = 0.8)
    dev.off()

# CoStar reference map for PUMAs crossing the LA City boundary ------------
# Show only mixed PUMAs: each has substantive area both inside and outside
# the city. The surrounding map buffer makes their external portions visible.
    border_pumas <- dplyr::inner_join(
        la_pumas,
        dplyr::select(dplyr::filter(puma_city_share, city_class == "Mixed"), puma),
        by = "puma"
    )
    border_pumas_3857 <- sf::st_transform(border_pumas, 3857)
    la_city_3857 <- sf::st_transform(la_city, 3857)
    reference_extent <- sf::st_bbox(sf::st_buffer(la_city_3857, 10000))
    reference_tiles <- maptiles::get_tiles(
        x = sf::st_as_sfc(reference_extent), provider = "OpenStreetMap",
        crop = TRUE, zoom = 10
    )

# Place each code within the portion of its PUMA near LA City, avoiding labels
# far offshore or outside the useful CoStar comparison extent.
    label_areas <- suppressWarnings(sf::st_intersection(
        border_pumas_3857[c("puma")], sf::st_buffer(la_city_3857, 5000)
    ))
    label_points <- suppressWarnings(sf::st_point_on_surface(label_areas))
    label_xy <- sf::st_coordinates(label_points)
    puma_colors <- grDevices::hcl.colors(nrow(border_pumas_3857), "Dynamic")

    pdf("figures/raw/PUMA-LA-city-border-CoStar-reference.pdf",
        width = 9, height = 7, useDingbats = FALSE)
    terra::plotRGB(reference_tiles,
                   xlim = reference_extent[c("xmin", "xmax")],
                   ylim = reference_extent[c("ymin", "ymax")])
    rect(reference_extent["xmin"], reference_extent["ymin"],
         reference_extent["xmax"], reference_extent["ymax"],
         col = grDevices::adjustcolor("white", alpha.f = 0.45), border = NA)
    plot(sf::st_geometry(la_city_3857), add = TRUE,
         col = grDevices::adjustcolor("lightblue", alpha.f = 0.18),
         border = "black", lwd = 2.2)
    for (i in seq_len(nrow(border_pumas_3857))) {
        plot(sf::st_geometry(border_pumas_3857[i, ]), add = TRUE,
             col = grDevices::adjustcolor(puma_colors[i], alpha.f = 0.12),
             border = puma_colors[i], lwd = 1.8)
    }
    text(label_xy[, 1], label_xy[, 2], labels = label_points$puma,
         col = "white", cex = 1.25, font = 2)
    text(label_xy[, 1], label_xy[, 2], labels = label_points$puma,
         col = "black", cex = 0.8, font = 2)
    title("PUMAs crossing the LA City boundary", cex.main = 1.3)
    legend("bottomleft", legend = c("LA City boundary", "PUMA boundary"),
           col = c("black", "gray35"), lwd = c(2.2, 1.8),
           bty = "n", cex = 0.9)
    dev.off()

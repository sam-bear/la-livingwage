data_path <- "/Users/sam-heft-neal/Library/CloudStorage/OneDrive2-SharedLibraries-BEAR/BEARLLC\ -\ Documents/Projects/California/CIty/Los\ Angeles/Living\ Wage/Updates/data"
clean_path <- file.path(data_path, "clean")
costar_path <- file.path(data_path, "costar")
costar_v1_path <- file.path(costar_path, "v1")
costar_downloads_path <- file.path(costar_path, "downloads")
costar_tgv2_path <- file.path(costar_downloads_path, "TGv2")
hotel_lists_path <- file.path(data_path, "hotellists")
edd_path <- file.path(data_path, "EDD")
flights_path <- file.path(data_path, "Flights")
flight_price_path <- file.path(flights_path, "Price")
flight_traffic_path <- file.path(flights_path, "Traffic")
tot_path <- file.path(data_path, "TOT")
research_data_path <- file.path(dirname(dirname(data_path)), "Research", "data")
research_clean_path <- file.path(research_data_path, "clean")
city_boundary_file <- file.path(research_data_path, "inputs", "boundaries",
                                "City_Boundary", "City.shp")
ces_boundary_file <- file.path(research_data_path, "inputs",
                               "calenviroscreen40shpf2021shp", "CES4 Final Shapefile.shp")
council_district_file <- file.path("inputs", "boundaries", "council_districts",
                                   "Council_Districts.shp")

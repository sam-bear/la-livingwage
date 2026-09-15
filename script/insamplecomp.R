source("script/0-config.R")
ah = read_rds(file.path(clean_path, "HotelsLACInfo_allSizeallTreatStatus.rds"))
hi = read_rds(file.path(clean_path, "AnalysisHotelInfo_DataReported.rds"))


insamp = hi %>% filter(treated == 1)
outsamp = ah %>% filter(treated == 1 & PropertyID %in% hi$PropertyID==F)

outsamp %>% summarize(Rooms = mean(Rooms, na.rm = T), Rest = mean(Restaurant=="Yes", na.rm = T), star = mean(Star.Rating, na.rm = T) )
5

source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")


      #load data
          lac <- read_sf("../Research/data/inputs/boundaries/City Boundary of Los Angeles/geo_export_85d35a5d-88a0-4517-8f0f-94c8f2139bd6.shp")
          allhotels <- read_rds("data/clean/HotelsLACInfo_allSizeallTreatStatus.rds")
          hotels_sf <- allhotels %>%
            st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE)
          dist <- read_sf("../Research/data/inputs/boundaries/LA_City_Council_Districts_(Adopted_2021)/LA_City_Council_Districts_(Adopted_2021).shp")  
            
      # make sure both are in Web Mercator for basemap tiles
          lac_3857    <- st_transform(lac, 3857)
          hotels_3857 <- st_transform(hotels_sf, 3857)
          dist_3857 <- st_transform(dist, 3857)

          
      
     
          
          
          
          
      
      
      
      
      
################################
    ### Make Maps ###
################################
          
          
  ###### [1]  MAIN PANEL OF FULL CITY ######      
          # download basemap covering the LA boundary
          bb <- st_bbox(lac_3857)
          
          basemap <- get_tiles(
            x = st_as_sfc(bb),
            provider = "OpenStreetMap",
            crop = TRUE,
            zoom = 11
          )
          
          # plot basemap in base graphics
          pal <- met.brewer("Tiepolo")
          
      
      pdf("figures/raw/Map_LA_treatedVSuntreated_raw.pdf", width = 9, height = 6)
            plotRGB(basemap)
            rect(xleft = st_bbox(lac_3857)[1], ybottom = st_bbox(lac_3857)[2],xright = st_bbox(lac_3857)[3], ytop = st_bbox(lac_3857)[4] , col = add.alpha('white', .5), border = NA)
            
            # add city boundary
            plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
            plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
            plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
            
            
            
            # add hotels
            

            hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/120
            hotels_3857$hr = hr
            hotels_3857$hr[hotels_3857$hr<.7]<-.7
            hotels_3857 = hotels_3857 %>% arrange(-hr)

            #plot control then treated on top
            plot(st_geometry(filter(hotels_3857, treated == 0)),cex = hotels_3857$hr[hotels_3857$treated==0], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
            plot(st_geometry(filter(hotels_3857, treated == 1)), add = TRUE, pch = 21, cex = hotels_3857$hr[hotels_3857$treated==1], bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )


            #add legend
            legend(x = "bottomleft", bty = "n",  fill = pal[c(1,8)], legend = c("Untreated","Treated"),cex = 2)
            

            legend(
              x = -13210000, y = 4015000,xpd = T,
              legend = c("Hotels subject to ordinance (135)", "Hotels not subject to ordinance (302)"),
              pch = 21,
              pt.bg = c(add.alpha(pal[1], 0.6), add.alpha(pal[7], 0.6)),
              col = "white",        # border color
              pt.cex = 3,
              bty = "n",
              cex = .8
            )
            
            
      
      dev.off()
     
      
      
      
      ### SUB PANEL 1 ####      
      #### DOWNTOWN #####
      
            #boundary: 
            shape2match = filter(hotels_3857, Submarket.Name=="Los Angeles CBD")
           
            
            bb <- st_bbox(shape2match)
            # expand (units = meters in EPSG:3857)
            
            bb_expanded <- bb
            bb_expanded["xmax"] <- -13160000
            bb_expanded["xmax"]  = bb_expanded["xmax"]  + 3000
            bb_expanded["xmin"]  = bb_expanded["xmin"] + 2500
            
            
            # convert to geometry
            bb_geom <- st_as_sfc(bb_expanded)
            
            basemap1 <- get_tiles(
              x = bb_geom,
              provider = "OpenStreetMap",
              crop = TRUE
            )
            
      pdf("figures/raw/Map_LA_treatedVSuntreated_downtown_raw.pdf", width = 6, height = 6)
              
              
              plotRGB(basemap1, ylim = c(4028500, 4040500), xlim = c(-13172000 +1200, -13160000+3000))
              rect(xleft = st_bbox(bb_expanded)[1], ybottom = st_bbox(bb_expanded)[2],xright = st_bbox(bb_expanded)[3], ytop = st_bbox(bb_expanded)[4] , col = add.alpha('white', .5), border = NA)
              
              # add city boundary
              plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
              plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
              plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
              
              
              
              # add hotels
              
            
              
              hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/70
              hotels_3857$hr = hr
              hotels_3857 = hotels_3857 %>% arrange(-hr)
              
              #plot control then treated on top
              plot(st_geometry(filter(hotels_3857, treated == 0)),cex = hotels_3857$hr[hotels_3857$treated==0], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
              plot(st_geometry(filter(hotels_3857, treated == 1)), add = TRUE, pch = 21, cex = hotels_3857$hr[hotels_3857$treated==1], bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
              
              
              
              plot(st_geometry(treated_3857_sub), add = TRUE, pch = 21, cex = tr, bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
              
        
              
            title("Downtown", cex.main = 2,  adj =1, line = 2)
              
      
      dev.off()

      
      
      
      
      
      
      
      ######## WESTSIDE
                #boundary: 
                shape2match = filter(hotels_3857, Submarket.Name%in% c("Hollywood/Beverly Hills", "Santa Monica/Marina Del Rey") )
                
                
                bb <- st_bbox(shape2match)
                # expand (units = meters in EPSG:3857)
                
                bb_expanded <- bb
              
                bb_expanded["xmax"]  = bb_expanded["xmax"]  + 20000
                bb_expanded["xmin"]  = bb_expanded["xmin"] - 2500
                bb_expanded["ymin"]  = bb_expanded["ymin"] - 10000
                
                
                # convert to geometry
                bb_geom <- st_as_sfc(bb_expanded)
                
                basemap1 <- get_tiles(
                  x = bb_geom,
                  provider = "OpenStreetMap",
                  crop = TRUE
                )
      
      pdf("figures/raw/Map_LA_treatedVSuntreated_westside_raw.pdf", width = 6, height = 6)
      
      
              plotRGB(basemap1, xlim = c(-13190000, -13170000), ylim = c(4024300, 4044000))
              rect(xleft = st_bbox(bb_expanded)[1], ybottom = st_bbox(bb_expanded)[2],xright = st_bbox(bb_expanded)[3], ytop = st_bbox(bb_expanded)[4] , col = add.alpha('white', .5), border = NA)
              
              # add city boundary
              plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
              plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
              plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
              
              
      
      # add hotels
        
              hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/70
              hotels_3857$hr = hr
              hotels_3857 = hotels_3857 %>% arrange(-hr)
              
              #plot control then treated on top
              plot(st_geometry(filter(hotels_3857, treated == 0)),cex = hotels_3857$hr[hotels_3857$treated==0], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
              plot(st_geometry(filter(hotels_3857, treated == 1)), add = TRUE, pch = 21, cex = hotels_3857$hr[hotels_3857$treated==1], bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
             
      
      
      
      plot(st_geometry(treated_3857_sub), add = TRUE, pch = 21, cex = tr, bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
      
      
      
      title("Beverly Hills/Hollywood & Westside", cex.main = 1.5,  adj =1, line = 2)
      
      
      dev.off()
      
      
      
      
      
      
      
      
      
      ######## LAX
      #boundary: 
                shape2match = filter(hotels_3857, Submarket.Name == "Los Angeles Airport" )
                
                
                bb <- st_bbox(shape2match)
                # expand (units = meters in EPSG:3857)
                
                bb_expanded <- bb
                
                # bb_expanded["xmax"]  = bb_expanded["xmax"]  + 20000
                # bb_expanded["xmin"]  = bb_expanded["xmin"] - 2500
                  bb_expanded["ymin"]  = bb_expanded["ymin"] -3000
                 bb_expanded["ymax"]  = bb_expanded["ymax"] - 4000
                 # 
                
                # convert to geometry
                bb_geom <- st_as_sfc(bb_expanded)
                
                basemap1 <- get_tiles(
                  x = st_as_sfc(hotels_3857),
                  provider = "OpenStreetMap",
                  crop = F
                )
      
      pdf("figures/raw/Map_LA_treatedVSuntreated_lax_raw.pdf", width = 6, height = 6)
      
      
            plotRGB(basemap1, ylim = c(4015500, 4028000), xlim = c(-13189000, -13170000))
            rect(xleft = st_bbox(st_as_sfc(hotels_3857))[1], ybottom = st_bbox(st_as_sfc(hotels_3857))[2],xright = st_bbox(st_as_sfc(hotels_3857))[3], ytop = st_bbox(st_as_sfc(hotels_3857))[4] , col = add.alpha('white', .5), border = NA)
            
            # add city boundary
            plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
            plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
            plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
            
      
      
      # add hotels
            
            hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/70
            hotels_3857$hr = hr
            hotels_3857 = hotels_3857 %>% arrange(-hr)
            
            #plot control then treated on top
            plot(st_geometry(filter(hotels_3857, treated == 0)),cex = hotels_3857$hr[hotels_3857$treated==0], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
            plot(st_geometry(filter(hotels_3857, treated == 1)), add = TRUE, pch = 21, cex = hotels_3857$hr[hotels_3857$treated==1], bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
            
    
      title("LAX", cex.main = 1.5,  adj =1, line = 2)
      
      
      dev.off()
      

      
      
      
      
        
################################################################################################################################################      
####### NOW DO FOR THE ANALYTICAL SAMPLE ########        
        
      allhotels <- read_rds("data/clean/AnalysisHotelInfo_DataReported.rds") 
      
        plotmapping = data.frame(label = sort(unique(allhotels$label)), plotgroup = NA)
        plotmapping$plotgroup[plotmapping$label %in% paste0("C0",1:4)]<-"control_union"
        plotmapping$plotgroup[plotmapping$label %in% paste0("C0",5:6)]<-"control_small"
        plotmapping$plotgroup[plotmapping$label %in% paste0("C0",7:9)]<-"control_city"
        plotmapping$plotgroup[plotmapping$label %in% paste0("C",10:11)]<-"control_city"
        plotmapping$plotgroup[substr(plotmapping$label,1,1)=="T"]<-"treated"
      
        #load data
        allhotels <- allhotels%>% left_join(plotmapping)
        
        hotels_sf <- allhotels %>%
          st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326, remove = FALSE)

        # make sure both are in Web Mercator for basemap tiles
            hotels_3857 <- st_transform(hotels_sf, 3857)

        
        # download basemap covering the LA boundary
        bb <- st_bbox(lac_3857)
        
        basemap <- get_tiles(
          x = st_as_sfc(bb),
          provider = "OpenStreetMap",
          crop = TRUE,
          zoom = 11
        )
        
        # plot basemap in base graphics
        pal <- met.brewer("Tiepolo")
        
        
        ################################
        
        
        ###### [1]  MAIN PANEL OF FULL CITY ######      
        # download basemap covering the LA boundary
        bb <- st_bbox(lac_3857)
        
        basemap <- get_tiles(
          x = st_as_sfc(bb),
          provider = "OpenStreetMap",
          crop = TRUE,
          zoom = 11
        )
        
        # plot basemap in base graphics
        pal <- met.brewer("Tiepolo")
        
        
        pdf("figures/raw/Map_LA_treatedVSuntreated_analysisSample_raw.pdf", width = 9, height = 6)
                plotRGB(basemap)
                rect(xleft = st_bbox(lac_3857)[1], ybottom = st_bbox(lac_3857)[2],xright = st_bbox(lac_3857)[3], ytop = st_bbox(lac_3857)[4] , col = add.alpha('white', .5), border = NA)
                
                # add city boundary
                plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
                plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
                plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
                
                
                
                # add hotels
                
                
                hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/120
                hotels_3857$hr = hr
                hotels_3857$hr[hotels_3857$hr<.7]<-.7
                hotels_3857 = hotels_3857 %>% arrange(-hr)
                

                #plot control then treated on top
                plot(st_geometry(filter(hotels_3857, plotgroup == "control_union")), cex = hotels_3857$hr[hotels_3857$plotgroup=="control_union"], add = TRUE, pch = 21,  bg = add.alpha(pal[5], 0.6), col = add.alpha('white', .75))
                plot(st_geometry(filter(hotels_3857, plotgroup == "control_small")), cex = hotels_3857$hr[hotels_3857$plotgroup=="control_small"], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
                plot(st_geometry(filter(hotels_3857, plotgroup == "control_city")), cex = hotels_3857$hr[hotels_3857$plotgroup=="control_city"], add = TRUE, pch = 21,  bg = add.alpha(pal[8], 0.6), col = add.alpha('white', .75))
                plot(st_geometry(filter(hotels_3857, plotgroup == "treated")), cex = hotels_3857$hr[hotels_3857$plotgroup=="treated"], add = TRUE, pch = 21,  bg = add.alpha(pal[1], 0.6), col = add.alpha('white', .75) )
                
                
                #add legend
               # legend(x = "bottomleft", bty = "n",  fill = pal[c(1,8)], legend = c("Untreated","Treated"),cex = 2)
                
                
                legend(
                  x = -13210000, y = 4015000,xpd = T,
                  legend = c("Subject to HWMO", "Not subject to HWMO (<60 rooms)","Not subject to HWMO (union contracts)","Not subject to HWMO (outside city)"),
                  pch = 21,
                  pt.bg = c(add.alpha(pal[1], 0.6), add.alpha(pal[7], 0.6), add.alpha(pal[5], 0.6), add.alpha(pal[8], 0.6)),
                  col = "white",        # border color
                  pt.cex = 3,
                  bty = "n",
                  cex = .8
                )
                
        
        
        dev.off()
        
        
        # 
        # 
        # ### SUB PANEL 1 ####      
        # #### DOWNTOWN #####
        # 
        # #boundary: 
        # shape2match = filter(hotels_3857, Submarket.Name=="Los Angeles CBD")
        # 
        # 
        # bb <- st_bbox(shape2match)
        # # expand (units = meters in EPSG:3857)
        # 
        # bb_expanded <- bb
        # bb_expanded["xmax"] <- -13160000
        # bb_expanded["xmax"]  = bb_expanded["xmax"]  + 3000
        # bb_expanded["xmin"]  = bb_expanded["xmin"] + 2500
        # 
        # 
        # # convert to geometry
        # bb_geom <- st_as_sfc(bb_expanded)
        # 
        # basemap1 <- get_tiles(
        #   x = bb_geom,
        #   provider = "OpenStreetMap",
        #   crop = TRUE
        # )
        # 
        # pdf("figures/raw/Map_LA_treatedVSuntreated_downtown_raw.pdf", width = 6, height = 6)
        # 
        # 
        # plotRGB(basemap1, ylim = c(4028500, 4040500), xlim = c(-13172000 +1200, -13160000+3000))
        # rect(xleft = st_bbox(bb_expanded)[1], ybottom = st_bbox(bb_expanded)[2],xright = st_bbox(bb_expanded)[3], ytop = st_bbox(bb_expanded)[4] , col = add.alpha('white', .5), border = NA)
        # 
        # # add city boundary
        # plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
        # plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
        # plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
        # 
        # 
        # 
        # # add hotels
        # 
        # 
        # 
        # hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/70
        # hotels_3857$hr = hr
        # hotels_3857 = hotels_3857 %>% arrange(-hr)
        # 
        # #plot control then treated on top
        # plot(st_geometry(filter(hotels_3857, treated == 0)),cex = hotels_3857$hr[hotels_3857$treated==0], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
        # plot(st_geometry(filter(hotels_3857, treated == 1)), add = TRUE, pch = 21, cex = hotels_3857$hr[hotels_3857$treated==1], bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
        # 
        # 
        # 
        # plot(st_geometry(treated_3857_sub), add = TRUE, pch = 21, cex = tr, bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
        # 
        # 
        # 
        # title("Downtown", cex.main = 2,  adj =1, line = 2)
        # 
        # 
        # dev.off()
        # 
        # 
        # 
        # 
        # 
        # 
        # 
        # 
        # ######## WESTSIDE
        # #boundary: 
        # shape2match = filter(hotels_3857, Submarket.Name%in% c("Hollywood/Beverly Hills", "Santa Monica/Marina Del Rey") )
        # 
        # 
        # bb <- st_bbox(shape2match)
        # # expand (units = meters in EPSG:3857)
        # 
        # bb_expanded <- bb
        # 
        # bb_expanded["xmax"]  = bb_expanded["xmax"]  + 20000
        # bb_expanded["xmin"]  = bb_expanded["xmin"] - 2500
        # bb_expanded["ymin"]  = bb_expanded["ymin"] - 10000
        # 
        # 
        # # convert to geometry
        # bb_geom <- st_as_sfc(bb_expanded)
        # 
        # basemap1 <- get_tiles(
        #   x = bb_geom,
        #   provider = "OpenStreetMap",
        #   crop = TRUE
        # )
        # 
        # pdf("figures/raw/Map_LA_treatedVSuntreated_westside_raw.pdf", width = 6, height = 6)
        # 
        # 
        # plotRGB(basemap1, xlim = c(-13190000, -13170000), ylim = c(4024300, 4044000))
        # rect(xleft = st_bbox(bb_expanded)[1], ybottom = st_bbox(bb_expanded)[2],xright = st_bbox(bb_expanded)[3], ytop = st_bbox(bb_expanded)[4] , col = add.alpha('white', .5), border = NA)
        # 
        # # add city boundary
        # plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
        # plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
        # plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
        # 
        # 
        # 
        # # add hotels
        # 
        # hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/70
        # hotels_3857$hr = hr
        # hotels_3857 = hotels_3857 %>% arrange(-hr)
        # 
        # #plot control then treated on top
        # plot(st_geometry(filter(hotels_3857, treated == 0)),cex = hotels_3857$hr[hotels_3857$treated==0], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
        # plot(st_geometry(filter(hotels_3857, treated == 1)), add = TRUE, pch = 21, cex = hotels_3857$hr[hotels_3857$treated==1], bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
        # 
        # 
        # 
        # 
        # plot(st_geometry(treated_3857_sub), add = TRUE, pch = 21, cex = tr, bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
        # 
        # 
        # 
        # title("Beverly Hills/Hollywood & Westside", cex.main = 1.5,  adj =1, line = 2)
        # 
        # 
        # dev.off()
        # 
        # 
        # 
        # 
        # 
        # 
        # 
        # 
        # 
        # ######## LAX
        # #boundary: 
        # shape2match = filter(hotels_3857, Submarket.Name == "Los Angeles Airport" )
        # 
        # 
        # bb <- st_bbox(shape2match)
        # # expand (units = meters in EPSG:3857)
        # 
        # bb_expanded <- bb
        # 
        # # bb_expanded["xmax"]  = bb_expanded["xmax"]  + 20000
        # # bb_expanded["xmin"]  = bb_expanded["xmin"] - 2500
        # bb_expanded["ymin"]  = bb_expanded["ymin"] -3000
        # bb_expanded["ymax"]  = bb_expanded["ymax"] - 4000
        # # 
        # 
        # # convert to geometry
        # bb_geom <- st_as_sfc(bb_expanded)
        # 
        # basemap1 <- get_tiles(
        #   x = st_as_sfc(hotels_3857),
        #   provider = "OpenStreetMap",
        #   crop = F
        # )
        # 
        # pdf("figures/raw/Map_LA_treatedVSuntreated_lax_raw.pdf", width = 6, height = 6)
        # 
        # 
        # plotRGB(basemap1, ylim = c(4015500, 4028000), xlim = c(-13189000, -13170000))
        # rect(xleft = st_bbox(st_as_sfc(hotels_3857))[1], ybottom = st_bbox(st_as_sfc(hotels_3857))[2],xright = st_bbox(st_as_sfc(hotels_3857))[3], ytop = st_bbox(st_as_sfc(hotels_3857))[4] , col = add.alpha('white', .5), border = NA)
        # 
        # # add city boundary
        # plot(st_geometry(dist_3857), add = TRUE, border = "black", lwd = .4)
        # plot(st_geometry(lac_3857), add = TRUE, border = NA, lwd = 1.2, col =add.alpha('lightblue', .25))
        # plot(st_geometry(lac_3857), add = TRUE, border = "black", lwd = 1.2, col =add.alpha('gray', .25))
        # 
        # 
        # 
        # # add hotels
        # 
        # hr = hotels_3857$Rooms; hr[hr>300]<-300;hr[hr>100 & hr<300]<-100; hr[hr<60]<-60; hr = hr/70
        # hotels_3857$hr = hr
        # hotels_3857 = hotels_3857 %>% arrange(-hr)
        # 
        # #plot control then treated on top
        # plot(st_geometry(filter(hotels_3857, treated == 0)),cex = hotels_3857$hr[hotels_3857$treated==0], add = TRUE, pch = 21,  bg = add.alpha(pal[7], 0.6), col = add.alpha('white', .75))
        # plot(st_geometry(filter(hotels_3857, treated == 1)), add = TRUE, pch = 21, cex = hotels_3857$hr[hotels_3857$treated==1], bg = add.alpha(pal[1], 0.6), col= add.alpha('white', .75) )
        # 
        # 
        # title("LAX", cex.main = 1.5,  adj =1, line = 2)
        # 
        # 
        # dev.off()
        # 
        # 
        # 
        # 
        # 

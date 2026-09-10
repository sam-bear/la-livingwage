library(tidyverse)
library(lubridate)



tot_h = read_csv("data/TOT/hotel_TOT_2023_2025.csv") %>% as.data.frame()
names(tot_h) <- c("district","date","rev_type","amt_liab","amt_int","amt_pen","amt_fee","amnt_op","amt_tot")
tot_h$date <- as.Date(paste0(tot_h$date, "/01"), format = "%Y/%m/%d")
tot_h$amt_liab <- as.numeric(gsub("[^0-9.-]", "", tot_h$amt_liab))
tot_h$amt_tot <- as.numeric(gsub("[^0-9.-]", "", tot_h$amt_tot))
tot_h$year = year(tot_h$date)
tot_h$month = month(tot_h$date)
tot = tot_h





 #monthly panel


          # 
          # tot_h %>% group_by(date) %>% summarise(tot = sum(amt_tot)) %>% plot(type ="l", ylab = "tot revenue")
          # abline(v = as.Date("2025-09-01"), col = 'red',lty=2)
          # 
          # tot_h$month = month(tot_h$date)
          # tot_h$year = year(tot_h$date)
          # 
          # yrs = 2003:2025
          tot_h$amt_tot = tot_h$amt_tot/1e6          

          
      pdf("figures/raw/TOT-raw.pdf", width =9, height = 7)    
          par(mfrow = c(2,1))
          subd = filter(tot_h, year == 2023)
          subd %>% group_by(month) %>% summarise(tot = sum(amt_tot)) %>% plot(type ="l", ylab = "tot revenue", ylim = c(18,30),col =pal[7], lwd = 2, axes = F)
          
          subd = filter(tot_h, year == 2024)
          subd %>% group_by(month) %>% summarise(tot = sum(amt_tot)) %>% lines(col = pal[5], lwd=2)
          
          
          subd = filter(tot_h, year == 2025)
          subd %>% group_by(month) %>% summarise(tot = sum(amt_tot)) %>% lines(col = pal[2], lwd=2)
          subd %>% filter(month >=9) %>%  group_by(month) %>% summarise(tot = sum(amt_tot)) %>% lines(col = pal[1],lwd=6)
          
          axis(1, at = 1:12, labels =c("jan","feb","mar","apr","may","jun","jul","aug","sep","oct","nov","dec"))
          axis(2, las =2)
          
          legend(x= 'topleft', fill = c(pal[c(7,5,2,1)]), legend = c(2023:2024, "2025-pre","2025-post"),bty="n")


 
  
  
  #yoy panel
        
        tot_yoy <- tot %>%
          mutate(date = as.Date(date)) %>%
          group_by(date) %>%
          summarise(amt_tot = sum(amt_tot, na.rm = TRUE), .groups = "drop") %>%
          arrange(.data$date) %>%
          mutate(yoy = amt_tot / lag(amt_tot, 12) - 1) %>% filter(date>="2024-01-01")
        

          plot(tot_yoy[,c("date", "yoy")], type = "l", col = pal[2],lwd=2, axes = F, xlab = "", ylab = "", ylim = c(-.15, .1))
          rect(xleft = as.Date("2025-09-01"), xright = as.Date("2025-12-01"), ybottom =-.15,ytop = .1, col = 'gray95', border = NA)
          abline(v = as.Date("2025-09-01"),lty=2, col = 'gray')
          lines(filter(tot_yoy, date>="2025-09-01")[,c("date","yoy")],  col= pal[1], lwd =6)
          axis(2, las=2, at = seq(-0.15, .1, by = .05), labels = paste0(round(seq(-0.15, .1, by = .05),2)*100, "%"))
          axis.Date(1, at = seq(min(tot_yoy$date), max(tot_yoy$date), by = "month"), labels = FALSE)  
          axis.Date(1, at = seq(min(tot_yoy$date), max(tot_yoy$date), by = "2 months"), format = "%b %Y")
          mtext(side = 2, text = "Year-over-year change (%)",line=3)
          abline(h = 0,lty=2, col = 'gray')
          
  
  dev.off()
          
          
          
          
  
  ######## TABLE #########
  
    

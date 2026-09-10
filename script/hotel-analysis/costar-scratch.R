library(tidyverse)
library(lubridate)

#[1] load groups

gp <- read_csv("data/costar/Covered_Hotel_Background_STR_Groups_Min5_Final.csv") %>% dplyr::select(PropertyID, costar_group,`Property Name`, `Property Address`)





# dat <- read_csv("data/costar/Covered_Hotel_Background_Groups_Min3.csv")
# 
# 
# 
# searches <- dat %>% dplyr::select(GroupingBucket, GroupID_num_final) %>% distinct()
# searches$searchGroup = as.numeric(as.factor(searches$GroupingBucket))
# searches = searches %>% arrange(GroupID_num_final, searchGroup)



#[2]

trt <- read_csv("data/costar/downloads/AllCoveredHotels_download020726.csv")
ctl <- read_csv("data/costar/downloads/ControlHotelsOtherCities021326.csv")

trt$RevPAR = as.numeric(gsub("[^0-9.-]", "", trt$RevPAR))
ctl$RevPAR = as.numeric(gsub("[^0-9.-]", "", ctl$RevPAR))

trt$Period = as.Date(paste0("01 ", trt$Period), format = "%d %b %Y")
ctl$Period = as.Date(paste0("01 ", ctl$Period), format = "%d %b %Y")

trt$treat = 1
ctl$treat = 0

dat = rbind(trt, ctl)



par(mfrow = c(3,1))
plot(dat$Period[dat$treat == 1], dat$RevPAR[dat$treat == 1],type = "l", xlab = "", ylab = "RevPAR", col = 'red3', ylim = c(0, 300))
lines(dat$Period[dat$treat == 0], dat$RevPAR[dat$treat == 0], col = 'navy')
legend(x = "topleft", col = c("navy",'red3'), legend = c("control","treated"),bty="n",lty=1, lwd = 2)


plot(dat$Period[dat$treat == 1 & dat$Period>="2021-01-01"], dat$RevPAR[dat$treat == 1& dat$Period>="2021-01-01"],type = "l", xlab = "", ylab = "RevPAR", col = 'red3', ylim = c(0, 300))
lines(dat$Period[dat$treat == 0& dat$Period>="2021-01-01"], dat$RevPAR[dat$treat == 0& dat$Period>="2021-01-01"], col = 'navy')
legend(x = "topleft", col = c("navy",'red3'), legend = c("control","treated"),bty="n",lty=1, lwd = 2)


diff = dat %>% dplyr::select(Period, RevPAR, treat) %>% pivot_wider(names_from = treat, values_from = RevPAR) %>% mutate(diff = `1`-`0`)

plot(diff$Period[diff$Period>="2021-01-01"], diff$diff[diff$Period>="2021-01-01"],type = "l",lwd=2, xlab = "",ylab = "RevPAR Treat - Control", ylim = c(-100,0))

abline(v = as.Date("2025-09-01"), lty=2)




trt$Occupancy = as.numeric(gsub("[^0-9.-]", "", trt$Occupancy))
ctl$Occupancy = as.numeric(gsub("[^0-9.-]", "", ctl$Occupancy))

dat_occ = rbind(trt, ctl)

par(mfrow = c(3,1))

plot(dat_occ$Period[dat_occ$treat == 1],
     dat_occ$Occupancy[dat_occ$treat == 1],
     type = "l", xlab = "", ylab = "Occupancy",
     col = 'red3', ylim = c(20, 100))

lines(dat_occ$Period[dat_occ$treat == 0],
      dat_occ$Occupancy[dat_occ$treat == 0],
      col = 'navy')

legend(x = "topleft", col = c("navy",'red3'),
       legend = c("control","treated"), bty="n", lty=1, lwd=2)


plot(dat_occ$Period[dat_occ$treat == 1 & dat_occ$Period >= "2021-01-01"],
     dat_occ$Occupancy[dat_occ$treat == 1 & dat_occ$Period >= "2021-01-01"],
     type = "l", xlab = "", ylab = "Occupancy",
     col = 'red3', ylim = c(20, 100))

lines(dat_occ$Period[dat_occ$treat == 0 & dat_occ$Period >= "2021-01-01"],
      dat_occ$Occupancy[dat_occ$treat == 0 & dat_occ$Period >= "2021-01-01"],
      col = 'navy')

legend(x = "topleft", col = c("navy",'red3'),
       legend = c("control","treated"), bty="n", lty=1, lwd=2)


diff_occ =
  dat_occ %>%
  dplyr::select(Period, Occupancy, treat) %>%
  pivot_wider(names_from = treat, values_from = Occupancy) %>%
  mutate(diff = `1` - `0`)

plot(diff_occ$Period[diff_occ$Period >= "2021-01-01"],
     diff_occ$diff[diff_occ$Period >= "2021-01-01"],
     type = "l", lwd = 2,
     xlab = "", ylab = "Occupancy Treat - Control",
     ylim = c(-10, 10))

abline(v = as.Date("2025-09-01"), lty = 2)










trt$ADR = as.numeric(gsub("[^0-9.-]", "", trt$ADR))
ctl$ADR = as.numeric(gsub("[^0-9.-]", "", ctl$ADR))

dat_adr = rbind(trt, ctl)

par(mfrow = c(3,1))

plot(dat_adr$Period[dat_adr$treat == 1],
     dat_adr$ADR[dat_adr$treat == 1],
     type = "l", xlab = "", ylab = "ADR",
     col = 'red3', ylim = c(0, 350))

lines(dat_adr$Period[dat_adr$treat == 0],
      dat_adr$ADR[dat_adr$treat == 0],
      col = 'navy')

legend(x = "topleft", col = c("navy",'red3'),
       legend = c("control","treated"), bty="n", lty=1, lwd=2)


plot(dat_adr$Period[dat_adr$treat == 1 & dat_adr$Period >= "2021-01-01"],
     dat_adr$ADR[dat_adr$treat == 1 & dat_adr$Period >= "2021-01-01"],
     type = "l", xlab = "", ylab = "ADR",
     col = 'red3', ylim = c(0, 350))

lines(dat_adr$Period[dat_adr$treat == 0 & dat_adr$Period >= "2021-01-01"],
      dat_adr$ADR[dat_adr$treat == 0 & dat_adr$Period >= "2021-01-01"],
      col = 'navy')

legend(x = "topleft", col = c("navy",'red3'),
       legend = c("control","treated"), bty="n", lty=1, lwd=2)


diff_adr =
  dat_adr %>%
  dplyr::select(Period, ADR, treat) %>%
  pivot_wider(names_from = treat, values_from = ADR) %>%
  mutate(diff = `1` - `0`)

plot(diff_adr$Period[diff_adr$Period >= "2021-01-01"],
     diff_adr$diff[diff_adr$Period >= "2021-01-01"],
     type = "l", lwd = 2,
     xlab = "", ylab = "ADR Treat - Control",
     ylim = c(-150, 0))

abline(v = as.Date("2025-09-01"), lty = 2)











# Supply plots (treated vs control + post-2021 zoom + treated-control diff)

trt <- read_csv("data/costar/downloads/AllCoveredHotels_download020726.csv")
ctl <- read_csv("data/costar/downloads/ControlHotelsOtherCities021326.csv")

# parse Supply (strips commas, etc.)
trt$Supply = as.numeric(gsub("[^0-9.-]", "", trt$Supply))
ctl$Supply = as.numeric(gsub("[^0-9.-]", "", ctl$Supply))

# parse Period (assumes "Feb 2025" style)
trt$Period = as.Date(paste0("01 ", trt$Period), format = "%d %b %Y")
ctl$Period = as.Date(paste0("01 ", ctl$Period), format = "%d %b %Y")

trt$treat = 1
ctl$treat = 0

dat = rbind(trt, ctl)

par(mfrow = c(3,1))

plot(dat$Period[dat$treat == 1],
     dat$Supply[dat$treat == 1],
     type = "l", xlab = "", ylab = "Supply",
     col = 'red3', ylim = c(2e+05, 12e+05))

lines(dat$Period[dat$treat == 0],
      dat$Supply[dat$treat == 0],
      col = 'navy')

legend(x = "topleft", col = c("navy",'red3'),
       legend = c("control","treated"), bty="n", lty=1, lwd=2)


plot(dat$Period[dat$treat == 1 & dat$Period >= "2021-01-01"],
     dat$Supply[dat$treat == 1 & dat$Period >= "2021-01-01"],
     type = "l", xlab = "", ylab = "Supply",
     col = 'red3', ylim = c(5e+05, 11e+05))

lines(dat$Period[dat$treat == 0 & dat$Period >= "2021-01-01"],
      dat$Supply[dat$treat == 0 & dat$Period >= "2021-01-01"],
      col = 'navy')

legend(x = "topleft", col = c("navy",'red3'),
       legend = c("control","treated"), bty="n", lty=1, lwd=2)


diff =
  dat %>%
  dplyr::select(Period, Supply, treat) %>%
  tidyr::pivot_wider(names_from = treat, values_from = Supply) %>%
  dplyr::mutate(diff = `1` - `0`)

plot(diff$Period[diff$Period >= "2021-01-01"],
     diff$diff[diff$Period >= "2021-01-01"],
     type = "l", lwd = 2,
     xlab = "", ylab = "Supply Treat - Control")

abline(v = as.Date("2025-09-01"), lty = 2)
















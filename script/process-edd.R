source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")




pdf("figures/raw/FigAX-edd-emp.pdf", width= 8, height = 8)


edd = readxl::read_xlsx("data/EDD/edd-la-hws.xlsx")%>% filter(`SS-NAICS`=="70-721000") %>% dplyr::select(-SORTORDER, -BMYEAR, -AREA, -INCLUDES, -BREAKS, -PNCO)#LA MSA only

emp <- data.frame(date =as.Date(as.numeric(names(edd)[3:ncol(edd)]), origin = "1899-12-30"), n = as.numeric(edd[1,3:ncol(edd)]))

emp = emp %>% filter(date>="2023-01-01")

COL = met.brewer("Tiepolo",8)[1]


emp_sub = filter(emp, date>="2025-09-01")


par(mfrow = c(2,1))
par(mar = c(4,6,4,4))
plot(emp,type ="l", col = COL, lwd = 1, axes = F, xlab = "", ylab = "", ylim = c(45000,50000))

rect(xleft = as.Date("2025-09-01"), xright = as.Date("2026-01-01"), ybottom= 44000, ytop = 51000, col = add.alpha('gray80',.5), border = NA)


abline(v = as.Date("2025-09-01"),lty=2)
lines(emp_sub, lwd = 3, col = COL)
axis(2, las = 2, at = seq(45000,50000,1000), labels = format(seq(45000,50000,1000), big.mark = ","))

mtext(side= 2, text = "Accommodation Employment \n— Los Angeles–Long Beach–Anaheim MSA", line = 4)

ticks_month <- seq(as.Date("2023-01-01"), as.Date("2025-12-01"), by = "month")

# quarterly labeled ticks
ticks_quarter <- seq(as.Date("2023-01-01"), as.Date("2025-12-01"), by = "3 months")


axis.Date(1,
          at = ticks_month,
          labels = FALSE,
          tcl = -0.2)

axis.Date(1,
          at = ticks_quarter,
          format = "%b\n%Y",
          tcl = -0.25, line = 0)


emp <- data.frame(date =as.Date(as.numeric(names(edd)[3:ncol(edd)]), origin = "1899-12-30"), n = as.numeric(edd[1,3:ncol(edd)]))

emp = emp %>% filter(date>="2022-01-01")

emp <- emp %>%
  arrange(date) %>%
  mutate(yoy = 100 * (n / lag(n, 12) - 1))

emp_sub = emp %>% filter(date>="2025-09-01")



plot(emp$date, emp$yoy, type = "l", xlim= as.Date(c("2023-01-01","2025-12-01")), col = COL, lwd = 1.5, xlab = "", ylab = "", axes = F, ylim= c(-5,20))
axis(2, las = 2, at = seq(-5,20,5))

mtext(side = 2, text = "Year-over-Year Change (%)", line =3)
rect(xleft = as.Date("2025-09-01"), xright = as.Date("2026-01-01"), ybottom= -6, ytop = 20, col = add.alpha('gray80',.5), border = NA)
abline(h = 0, lty=1, col ='gray80')
#abline(v = as.Date("2025-05-01"),lty=2)
abline(v = as.Date("2025-09-01"),lty=2)
lines(emp$date, emp$yoy, col = COL, lwd =1.5)

lines(emp_sub$date, emp_sub$yoy, col = COL, lwd =3)



ticks_month <- seq(as.Date("2023-01-01"), as.Date("2025-12-01"), by = "month")

# quarterly labeled ticks
ticks_quarter <- seq(as.Date("2023-01-01"), as.Date("2025-12-01"), by = "3 months")

axis.Date(1,
          at = ticks_month,
          labels = FALSE,
          tcl = -0.2)

axis.Date(1,
          at = ticks_quarter,
          format = "%b\n%Y",
          tcl = -0.25, line = 0)
dev.off()

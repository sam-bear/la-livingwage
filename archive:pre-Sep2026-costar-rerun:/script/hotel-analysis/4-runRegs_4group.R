source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")





      #define variables
      df_plot <- read_rds(file.path(clean_path, "AnalysisData_LargeGroups.rds")) %>% filter(date>="2020-01-01") %>%
        filter(group %in% c("AllTreated", "CG_Small", "CG_Union", "CG_EmbCity")) %>%
        arrange(group, date) %>%
        filter(date>="2023-01-01")
      
     
          ##define true treatemnt  
            df_reg <- df_plot %>% 
            mutate(
              treated = (group == "AllTreated"),
              post = (date >= as.Date("2025-09-01"))
            )
        
          
          
          ## add anticipatory effects
          df_reg <- df_reg %>%
            mutate(
              period = case_when(
                date < as.Date("2025-05-01") ~ "pre",
                date < as.Date("2025-09-01") ~ "anticip",
                TRUE ~ "post"
              ),
              treated = (group == "AllTreated")
            )
          
    ######## RUN REGRESSIONS #########        
          
       
  ### Regressions for 4 group split:        
             
    #main regs      
          m_adr <- feols(
            log(ADR) ~ treated * post | group + date,
            data = df_reg, weights = df_reg$Rooms
          )
          
          m_revpar <- feols(
            log(RevPAR) ~ treated * post | group + date,
            data = df_reg, weights = df_reg$Rooms
          )


    #anticipatory
        m_adr2 <- feols(
          log(ADR) ~ i(period, treated, ref = "pre") | group + date,
          data = df_reg, weights = df_reg$Rooms
        )
        
        
        m_revpar2 <- feols(
          log(RevPAR) ~ i(period, treated, ref = "pre") | group + date,
          data = df_reg, weights = df_reg$Rooms
        )
        
        
        #functions for pulling out terms
        find_post_term <- function(model) {
          nm <- names(coef(model))
          hit <- grep("^treated.*:postTRUE$|^treatedTRUE:postTRUE$|^treated:postTRUE$", nm, value = TRUE)
          if (length(hit) == 0) stop("Could not find treated x post term.")
          hit[1]
        }
        pull_fx <- function(model, term, outcome, spec, effect_label) {
          ct <- coeftable(model)
          
          est <- unname(ct[term, "Estimate"])
          se  <- unname(ct[term, "Std. Error"])
          p   <- unname(ct[term, "Pr(>|t|)"])
          
          ci_low  <- est - 1.96 * se
          ci_high <- est + 1.96 * se
          
          tibble(
            outcome = outcome,
            spec = spec,
            effect = effect_label,
            term = term,
            estimate_log = est,
            se_log = se,
            ci_low_log = ci_low,
            ci_high_log = ci_high,
            estimate_pct = 100 * (exp(est) - 1),
            ci_low_pct = 100 * (exp(ci_low) - 1),
            ci_high_pct = 100 * (exp(ci_high) - 1),
            p_value = p
          )
        }
        
        term_post_simple_adr    <- find_post_term(m_adr)
        term_post_simple_revpar <- find_post_term(m_revpar)
        
        term_anticip     <- "period::anticip:treated"
        term_post_period <- "period::post:treated"
        
        results_main <- bind_rows(
          pull_fx(m_adr,     term_post_simple_adr,    "ADR",    "Post only",         "Post"),
          pull_fx(m_revpar,  term_post_simple_revpar, "RevPAR", "Post only",         "Post"),
          pull_fx(m_adr2,    term_anticip,            "ADR",    "Anticipation/Post", "Anticipation"),
          pull_fx(m_adr2,    term_post_period,        "ADR",    "Anticipation/Post", "Post"),
          pull_fx(m_revpar2, term_anticip,            "RevPAR", "Anticipation/Post", "Anticipation"),
          pull_fx(m_revpar2, term_post_period,        "RevPAR", "Anticipation/Post", "Post")
        )
        
        plot_df <- results_main %>%
          select(outcome, spec, effect, estimate_pct, ci_low_pct, ci_high_pct, p_value)
        
        
        
        ## optional: force plotting order
        plot_df$outcome <- factor(plot_df$outcome, levels = c("ADR", "RevPAR"))
        plot_df$spec <- factor(plot_df$spec, levels = c("Post only", "Anticipation/Post"))
        plot_df$effect <- factor(plot_df$effect, levels = c("Anticipation", "Post"))
        
        ## split data
        df_post <- subset(plot_df, spec == "Post only")
        df_ap   <- subset(plot_df, spec == "Anticipation/Post")
        
        ## panel limits
        xlim <- range(c(plot_df$ci_low_pct, plot_df$ci_high_pct), na.rm = TRUE)
        xpad <- 0.5
        xlim <- c(floor(xlim[1] - xpad), ceiling(xlim[2] + xpad))
        
        ## colors / plotting symbols
        col_post <- pal[1]
        col_ant  <- pal[2]
        pch_post <- 16
        pch_ant  <- 16
        
        ## save par
        op <- par(no.readonly = TRUE)
        
        
        
        pdf("figures/raw/figAX-4group-pooled-est.pdf", width= 8, height = 5)      
        par(
          mfrow = c(1, 2),
          mar = c(5, 6, 4, 1),
          oma = c(0, 0, 1, 0),
          xpd = NA
        )
        
        ## ------------------------------------------------------------
        ## Panel A: Post only
        ## ------------------------------------------------------------
        y_post <- c(2, 1)  # ADR on top, RevPAR below
        
        plot(
          NA, NA,
          xlim = xlim,
          ylim = c(0.5, 2.5),
          xaxt = "n",
          yaxt = "n",
          xlab = "Estimated % change",
          ylab = "",
          main = "A. Post only", axes = F
        )
        
        abline(v = 0, lty = 2, col = "gray40")
        
        axis(1)
        axis(2, at = y_post, labels = c("ADR", "RevPAR"), las = 1)
        
        ## add CIs and points
        for (i in seq_len(nrow(df_post))) {
          yy <- if (df_post$outcome[i] == "ADR") 2 else 1
          
          segments(
            x0 = df_post$ci_low_pct[i], y0 = yy,
            x1 = df_post$ci_high_pct[i], y1 = yy,
            lwd = 2, col = col_post
          )
          
          points(
            x = df_post$estimate_pct[i], y = yy,
            pch = pch_post, cex = 3, col = col_post
          )
        }
        
        #box()
        
        ## ------------------------------------------------------------
        ## Panel B: Anticipation + post
        ## ------------------------------------------------------------
        ## slight vertical offsets so anticip/post are both visible
        y_base <- c(2, 1)  # ADR, RevPAR
        offset <- 0.12
        
        plot(
          NA, NA,
          xlim = xlim,
          ylim = c(0.5, 2.5),
          xaxt = "n",
          yaxt = "n",
          xlab = "Estimated % change",
          ylab = "",
          main = "B. Anticipation + post",axes = F
        )
        
        abline(v = 0, lty = 2, col = "gray40")
        
        axis(1)
        axis(2, at = y_base, labels = c("ADR", "RevPAR"), las = 1)
        
        for (i in seq_len(nrow(df_ap))) {
          yy <- if (df_ap$outcome[i] == "ADR") 2 else 1
          yy <- if (df_ap$effect[i] == "Anticipation") yy - offset else yy + offset
          
          this_col <- if (df_ap$effect[i] == "Anticipation") col_ant else col_post
          this_pch <- if (df_ap$effect[i] == "Anticipation") pch_ant else pch_post
          
          segments(
            x0 = df_ap$ci_low_pct[i], y0 = yy,
            x1 = df_ap$ci_high_pct[i], y1 = yy,
            lwd = 2, col = this_col
          )
          
          points(
            x = df_ap$estimate_pct[i], y = yy,
            pch = this_pch, cex = 3, col = this_col, bg = this_col
          )
        }
        
        legend(
          "bottomleft",
          legend = c("Anticipation", "Post"),
          pch = c(pch_ant, pch_post),
          col = c(col_ant, col_post),
          pt.cex = 3,
          bty = "n",
          horiz = TRUE,
          inset = 0.02
        )
        
        #box()
        
        par(op)
        dev.off()
        

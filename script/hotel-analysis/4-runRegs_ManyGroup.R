source("script/0-loadFunctions.R")
source("script/0-loadPackages.R")
pal <- met.brewer("Tiepolo")





      #define variables
      df <- read_rds(file.path(clean_path, "AnalysisData_SubGroups.rds")) %>% filter(date>="2023-01-01") %>%
        arrange(group, date) %>%
        mutate(
          period = case_when(
            date < as.Date("2025-05-01") ~ "pre",
            date >= as.Date("2025-05-01") & date < as.Date("2025-09-01") ~ "anticip",
            date >= as.Date("2025-09-01") ~ "post"
          ),
          period = factor(period, levels = c("pre", "anticip", "post"))
        ) %>%
        mutate(
          post = date >= as.Date("2025-09-01")
        )
      
      
      table(df$treated)
      table(df$period)
      table(df$treated, df$period)
      
      
      #### Labeling
      
      
      #clean up labeling ---
      plot_labels <- df %>% filter(substr(label,1,1)=="T") %>% 
                            mutate(rooms_per = Rooms/n_hotels) %>% 
                            group_by(label, Hotel.Class, Submarket.Name) %>% 
                            summarise(stars = mean(Star.Rating), mstar = min(Star.Rating), rooms = mean(rooms_per)) %>% 
                            mutate(
                                  rooms_label = "Small", 
                                  rooms_label = replace(rooms_label, rooms >=90 & rooms<120, "Medium"),
                                  rooms_label = replace(rooms_label, rooms >=120 & rooms<300, "Large"),
                                  rooms_label = replace(rooms_label, rooms >=300 , "Mega"),
                                  
                                  mkt_label = "Hollywood/West LA",
                                  mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
                                  mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles CBD", "Downtown (CBD)"),
                                  mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles North", "North LA"),
                                  mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
                                  
                                  class_label = "Luxury",
                                  class_label = replace(class_label, Hotel.Class == "Upper Midscale", "Midscale"),
                                  class_label = replace(class_label, Hotel.Class == "Upscale", "Upscale"),
                                  class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label!="North LA", "Upscale"),
                                  class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label=="North LA" & stars>3.8, "Luxury"),
                                  
                                  
                                  ) %>% 
                            as.data.frame() %>% arrange(Submarket.Name) %>% 
                          mutate(plot_label = paste(mkt_label, class_label, rooms_label, sep =" - "))
      
     # df = df %>% filter(date <="2026-01-01")
          
    ######## RUN REGRESSIONS #########        
          
       
  ### Regressions for 20+ group split:        
             
    #main regs      
      
        m_adr <- feols(
              log(ADR) ~ treated * post | label + date,
              data = df,
              weights = df$Rooms, vcov = ~label
            )

            
            
      m_revpar <- feols(
        log(RevPAR) ~ treated * post | label + date,
        data = df,
        weights = df$Rooms, vcov = ~label
      )
        


    #anticipatory
        m_adr2 <- feols(
          log(ADR) ~ i(period, treated, ref = "pre") | label + date,
          data = df, weights = df$Rooms, vcov = ~label
        )
        
        
        m_revpar2 <- feols(
          log(RevPAR) ~ i(period, treated, ref = "pre") | label + date,
          data = df, weights = df$Rooms, vcov = ~label
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
        
        
        
  pdf("figures/raw/fig4-pooled-est.pdf", width= 8, height = 5)      
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
        
############################################################################################################        
    #heterogeneity by subgroup
        
      
        
      #run reg  
        m_het_r <- feols(
          log(RevPAR) ~ i(label, post) | label + date,
          data = df,
          weights = df$Rooms,
          cluster = ~label
        )
        summary(m_het_r)
        
      res_het_r =  data.frame(est = coef(m_het_r), se = se(m_het_r), label = substr(names(coef(m_het_r)), 8,10 ) )
      res_het_r = left_join(res_het_r, plot_labels) %>% drop_na(plot_label)
        
      
      res_het_r <- res_het_r %>%
        mutate(
          pct = 100 * (exp(est) - 1),
          pct_low = 100 * (exp(est - 1.96 * se) - 1),
          pct_high = 100 * (exp(est + 1.96 * se) - 1)
        ) %>% arrange(-pct)
        
      
                
                
      ### now for ADR
                
                #run reg  
                m_het_a <- feols(
                  log(ADR) ~ i(label, post) | label + date,
                  data = df,
                  weights = df$Rooms,
                  cluster = ~label
                )
                summary(m_het_a)
                
                res_het_a =  data.frame(est = coef(m_het_a), se = se(m_het_a), label = substr(names(coef(m_het_a)), 8,10 ) )
                res_het_a = left_join(res_het_a, plot_labels) %>% drop_na(plot_label)
                
                
                res_het_a <- res_het_a %>%
                  mutate(
                    pct = 100 * (exp(est) - 1),
                    pct_low = 100 * (exp(est - 1.96 * se) - 1),
                    pct_high = 100 * (exp(est + 1.96 * se) - 1)
                  ) %>% arrange(-pct)
                
                
              
                
      pdf("figures/raw/fig5-impact-hetero.pdf", width = 12, height = 10)
          
      par(mfrow = c(2,1))
          
          
      
          plot(y = 1:nrow(res_het_a), x = res_het_a$pct, axes = F, xlab = "", ylab = "", pch = 16, col = NA, cex= res_het_a$rooms_per/120, xlim = c(-40,12))
          abline(v = 0,lty = 2)
          
          points(y=1:nrow(res_het_a), x = res_het_a$pct,pch = 16, col = pal[1], cex= res_het_a$rooms/100)
          segments(y0 = 1:nrow(res_het_a), x0 = res_het_a$pct_low, x1 = res_het_a$pct_high, col = pal[1])
          axis(1, at = seq(-12,12,2))
          text(x =-25, y = 1:nrow(res_het_a), label = res_het_a$plot_label )
          mtext(side = 3, adj = 1, cex = 1.25, text = "ADR")
          mtext(side = 1, text = "% change", line=1)
      
      
          plot(y = 1:nrow(res_het_r), x = res_het_r$pct, axes = F, xlab = "", ylab = "", pch = 16, col = NA, cex= res_het_r$rooms_per/120, xlim = c(-40,12))
          abline(v = 0,lty = 2)
          
          points(y=1:nrow(res_het_r), x = res_het_r$pct,pch = 16, col = pal[1], cex= res_het_r$rooms/100)
          segments(y0 = 1:nrow(res_het_r), x0 = res_het_r$pct_low, x1 = res_het_r$pct_high, col = pal[1])
          axis(1, at = seq(-12,12,2))
          text(x =-25, y = 1:nrow(res_het_r), label = res_het_r$plot_label )
          mtext(side = 3, adj = 1, cex = 1.25, text = "RevPAR")
          mtext(side = 1, text = "% change", line=1)  
          
          
          
          
      dev.off()    
          
      
      
      
      
      
      
      
################################
      #########################################
            ########################################################
      
      
      
      #define variables
      df <- read_rds(file.path(clean_path, "AnalysisData_SubGroups.rds")) %>% filter(date>="2023-01-01") %>%
        arrange(group, date) %>%
        mutate(
          period = case_when(
            date < as.Date("2025-05-01") ~ "pre",
            date >= as.Date("2025-05-01") & date < as.Date("2025-09-01") ~ "anticip",
            date >= as.Date("2025-09-01") ~ "post"
          ),
          period = factor(period, levels = c("pre", "anticip", "post"))
        ) %>%
        mutate(
          post = date >= as.Date("2025-09-01")
        )
      
      
      table(df$treated)
      table(df$period)
      table(df$treated, df$period)
      
      
      #### Labeling
      
      
      #clean up labeling ---
      plot_labels <- df %>% filter(substr(label,1,1)=="T") %>% 
        mutate(rooms_per = Rooms/n_hotels) %>% 
        group_by(label, Hotel.Class, Submarket.Name) %>% 
        summarise(stars = mean(Star.Rating), mstar = min(Star.Rating), rooms = mean(rooms_per)) %>% 
        mutate(
          rooms_label = "Small", 
          rooms_label = replace(rooms_label, rooms >=90 & rooms<120, "Medium"),
          rooms_label = replace(rooms_label, rooms >=120 & rooms<300, "Large"),
          rooms_label = replace(rooms_label, rooms >=300 , "Mega"),
          
          mkt_label = "Hollywood/West LA",
          mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
          mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles CBD", "Downtown (CBD)"),
          mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles North", "North LA"),
          mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
          
          class_label = "Luxury",
          class_label = replace(class_label, Hotel.Class == "Upper Midscale", "Midscale"),
          class_label = replace(class_label, Hotel.Class == "Upscale", "Upscale"),
          class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label!="North LA", "Upscale"),
          class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label=="North LA" & stars>3.8, "Luxury"),
          
          
        ) %>% 
        as.data.frame() %>% arrange(Submarket.Name) %>% 
        mutate(plot_label = paste(mkt_label, class_label, rooms_label, sep =" - "))
      
      
      
      ######## RUN REGRESSIONS #########        
      
      
      ### Regressions for 20+ group split:        
      # by sub control
      
      
      c_union <- paste0("C0",1:4)
      c_small <- paste0("C0",5:6)
      c_adj <- c(paste0("C0",7:9),paste0("C",10:11))
      c_all <- c(c_union, c_small, c_adj)
      t_all <- unique(df$label) %>% grep(pattern = "T", value = T)
      
      #main regs      
      
      m_adr_ap = m_revpar_ap = list()
      
      
      
      
      m_adr_ap[["all"]] <- feols(
        log(ADR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_all, t_all)), 
        weights = df$Rooms[df$label %in% c(c_all, t_all)]
      )
      
      
      m_adr_ap[["dropUnion"]] <- feols(
        log(ADR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_small, c_adj, t_all)), 
        weights = df$Rooms[df$label %in% c(c_small, c_adj, t_all)]
      )
      
      m_adr_ap[["dropSmall"]] <- feols(
        log(ADR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_union,c_adj, t_all)), 
        weights = df$Rooms[df$label %in% c(c_union, c_adj, t_all)]
      )
      
      m_adr_ap[["dropAdj"]] <- feols(
        log(ADR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_union,c_small, t_all)), 
        weights = df$Rooms[df$label %in% c(c_union, c_small, t_all)]
      )
      
      
      m_revpar <- feols(
        log(RevPAR) ~ treated * post | label + date,
        data = df,
        weights = df$Rooms
      )
      
      
      
      
      m_revpar_ap[["all"]] <- feols(
        log(RevPAR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_all, t_all)), 
        weights = df$Rooms[df$label %in% c(c_all, t_all)]
      )
      
      
      m_revpar_ap[["dropUnion"]] <- feols(
        log(RevPAR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_small, c_adj, t_all)), 
        weights = df$Rooms[df$label %in% c(c_small, c_adj, t_all)]
      )
      
      m_revpar_ap[["dropSmall"]] <- feols(
        log(RevPAR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_union,c_adj, t_all)), 
        weights = df$Rooms[df$label %in% c(c_union, c_adj, t_all)]
      )
      
      m_revpar_ap[["dropAdj"]] <- feols(
        log(RevPAR) ~ treated * post | label + date,
        data = filter(df, label %in% c(c_union,c_small, t_all)), 
        weights = df$Rooms[df$label %in% c(c_union, c_small, t_all)]
      )
      
      
      
    adr_rob =   
      sapply(m_adr_ap, function(x){data.frame(est=coef(x), se=se(x))}) %>% t() %>%as.data.frame() %>%  
        mutate(est = as.numeric(est), se = as.numeric(se), low = est+qnorm(0.025)*se, high = est + qnorm(0.975)*se) %>% 
        mutate(
        pct_est = 100 * (exp(est) - 1),
        pct_low = 100 * (exp(low) - 1),
        pct_high = 100 * (exp(high) - 1)
      
        )
        
    
    rp_rob =   
      sapply(m_revpar_ap, function(x){data.frame(est=coef(x), se=se(x))}) %>% t() %>%as.data.frame() %>%  
      mutate(est = as.numeric(est), se = as.numeric(se), low = est+qnorm(0.025)*se, high = est + qnorm(0.975)*se) %>% 
      mutate(
        pct_est = 100 * (exp(est) - 1),
        pct_low = 100 * (exp(low) - 1),
        pct_high = 100 * (exp(high) - 1)
        
      ) 
    
    
    
    pdf("figures/raw/figAX-pooled-est-byControls.pdf", width= 12, height = 6)      
          par(mfrow =c(1,2))
          plot(1,1, col = NA, xlim = c(-12, 6), ylim = c(0.5, 4.5),axes = F, xlab = "", ylab = "")
          points(adr_rob$pct_est,4:1, pch = 16, col = pal[1], cex = 2)
          segments(x0 = adr_rob$pct_low, x1 = adr_rob$pct_high, y0=4:1, col = pal[1])
          abline( v= 0, lty=2)  
          axis(1, at = seq(-8,4,2))
          
          text(x = -12, y = 4:1, labels = c("All controls", "Exclude union controls", "Exclude <60 room controls","Exclude other city controls"))
          mtext(side = 3, text = "ADR", cex = 1.25)
          
          plot(1,1, col = NA, xlim = c(-9, 6), ylim = c(0.5, 4.5),axes = F, xlab = "", ylab = "")
          points(rp_rob$pct_est,4:1, pch = 16, col = pal[1], cex = 2)
          segments(x0 = rp_rob$pct_low, x1 = rp_rob$pct_high, y0=4:1, col = pal[1])
          abline( v= 0, lty=2)
          axis(1, at = seq(-8,4,2))
          mtext(side = 3, text = "RevPAR", cex = 1.25)
    dev.off()      
    
      
      
      
################# ABOVE IS FOR ALL TREAT NOW MATCH TO SIMILAR TREAT ######
    
    
    
    
    ### Regressions for 20+ group split:        
    # by sub control
    
    
    t_all <- unique(df$label) %>% grep(pattern = "T", value = T)
    group_union <- c(paste0("C0",1:4), plot_labels$label[plot_labels$rooms_label%in% c("Large","Mega")])
    group_small <- c(paste0("C0",5:6), plot_labels$label[plot_labels$rooms_label%in% "Small"])
    group_adj <- c(paste0("C0",7:9),paste0("C",10:11), t_all)
    
    
    #main regs      
    
    m_adr_ap = m_revpar_ap = list()
    
    
    
    m_adr_ap[["all"]] <- feols(
      log(ADR) ~ treated * post | label + date,
      data = df, 
      weights = df$Rooms
    )
    
    
    m_adr_ap[["unionComp"]] <- feols(
      log(ADR) ~ treated * post | label + date,
      data = filter(df, label %in% group_union), 
      weights = df$Rooms[df$label %in% group_union]
    )
    
    m_adr_ap[["smallComp"]] <- feols(
      log(ADR) ~ treated * post | label + date,
      data = filter(df, label %in% group_small), 
      weights = df$Rooms[df$label %in% group_small]
    )
    
    m_adr_ap[["ctyComp"]] <- feols(
      log(ADR) ~ treated * post | label + date,
      data = filter(df, label %in% group_adj), 
      weights = df$Rooms[df$label %in% group_adj]
    )
    
        
            
        m_revpar_ap[["all"]] <- feols(
          log(RevPAR) ~ treated * post | label + date,
          data = df, 
          weights = df$Rooms
        )
        
        
        m_revpar_ap[["unionComp"]] <- feols(
          log(RevPAR) ~ treated * post | label + date,
          data = filter(df, label %in% group_union), 
          weights = df$Rooms[df$label %in% group_union]
        )
        
        m_revpar_ap[["smallComp"]] <- feols(
          log(RevPAR) ~ treated * post | label + date,
          data = filter(df, label %in% group_small), 
          weights = df$Rooms[df$label %in% group_small]
        )
        
        m_revpar_ap[["ctyComp"]] <- feols(
          log(RevPAR) ~ treated * post | label + date,
          data = filter(df, label %in% group_adj), 
          weights = df$Rooms[df$label %in% group_adj]
        )

    
    
    adr_rob =   
      sapply(m_adr_ap, function(x){data.frame(est=coef(x), se=se(x))}) %>% t() %>%as.data.frame() %>%  
      mutate(est = as.numeric(est), se = as.numeric(se), low = est+qnorm(0.025)*se, high = est + qnorm(0.975)*se) %>% 
      mutate(
        pct_est = 100 * (exp(est) - 1),
        pct_low = 100 * (exp(low) - 1),
        pct_high = 100 * (exp(high) - 1)
        
      )
    
    
    rp_rob =   
      sapply(m_revpar_ap, function(x){data.frame(est=coef(x), se=se(x))}) %>% t() %>%as.data.frame() %>%  
      mutate(est = as.numeric(est), se = as.numeric(se), low = est+qnorm(0.025)*se, high = est + qnorm(0.975)*se) %>% 
      mutate(
        pct_est = 100 * (exp(est) - 1),
        pct_low = 100 * (exp(low) - 1),
        pct_high = 100 * (exp(high) - 1)
        
      ) 
    
    
    
    pdf("figures/raw/figAX-pooled-est-byTreatControls.pdf", width= 12, height = 6)      
    par(mfrow =c(1,2))
    plot(1,1, col = NA, xlim = c(-12, 6), ylim = c(0.5, 4.5),axes = F, xlab = "", ylab = "")
    points(adr_rob$pct_est,4:1, pch = 16, col = pal[1], cex = 2)
    segments(x0 = adr_rob$pct_low, x1 = adr_rob$pct_high, y0=4:1, col = pal[1])
    abline( v= 0, lty=2)  
    axis(1, at = seq(-8,4,2))
    
    text(x = -12, y = 4:1, labels = c("Full Sample", "Comparing large upscale hotels to unionized hotels", "Comparing hotels 60-90 rooms to hotels with 40-59 rooms","Comparing full treated sample to other city hotels"))
    mtext(side = 3, text = "ADR", cex = 1.25)
    
    plot(1,1, col = NA, xlim = c(-9, 6), ylim = c(0.5, 4.5),axes = F, xlab = "", ylab = "")
    points(rp_rob$pct_est,4:1, pch = 16, col = pal[1], cex = 2)
    segments(x0 = rp_rob$pct_low, x1 = rp_rob$pct_high, y0=4:1, col = pal[1])
    abline( v= 0, lty=2)
    axis(1, at = seq(-8,4,2))
    mtext(side = 3, text = "RevPAR", cex = 1.25)
    dev.off()      
    
    
    
    
    
    
    
    
    
    
    ############################################################################################################        
    
    
    ############################################################################################################        
    
    
    
    ############################################################################################################        
    
    
    ######## DIFFERENT OUTCOMES #####

    
    
    
    #define variables
    df <- read_rds(file.path(clean_path, "AnalysisData_SubGroups.rds")) %>% filter(date>="2023-01-01") %>%
      arrange(group, date) %>%
      mutate(
        period = case_when(
          date < as.Date("2025-05-01") ~ "pre",
          date >= as.Date("2025-05-01") & date < as.Date("2025-09-01") ~ "anticip",
          date >= as.Date("2025-09-01") ~ "post"
        ),
        period = factor(period, levels = c("pre", "anticip", "post"))
      ) %>%
      mutate(
        post = date >= as.Date("2025-09-01")
      )
    
    
    table(df$treated)
    table(df$period)
    table(df$treated, df$period)
    
    
    #### Labeling
    
    
    #clean up labeling ---
    plot_labels <- df %>% filter(substr(label,1,1)=="T") %>% 
      mutate(rooms_per = Rooms/n_hotels) %>% 
      group_by(label, Hotel.Class, Submarket.Name) %>% 
      summarise(stars = mean(Star.Rating), mstar = min(Star.Rating), rooms = mean(rooms_per)) %>% 
      mutate(
        rooms_label = "Small", 
        rooms_label = replace(rooms_label, rooms >=90 & rooms<120, "Medium"),
        rooms_label = replace(rooms_label, rooms >=120 & rooms<300, "Large"),
        rooms_label = replace(rooms_label, rooms >=300 , "Mega"),
        
        mkt_label = "Hollywood/West LA",
        mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
        mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles CBD", "Downtown (CBD)"),
        mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles North", "North LA"),
        mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
        
        class_label = "Luxury",
        class_label = replace(class_label, Hotel.Class == "Upper Midscale", "Midscale"),
        class_label = replace(class_label, Hotel.Class == "Upscale", "Upscale"),
        class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label!="North LA", "Upscale"),
        class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label=="North LA" & stars>3.8, "Luxury"),
        
        
      ) %>% 
      as.data.frame() %>% arrange(Submarket.Name) %>% 
      mutate(plot_label = paste(mkt_label, class_label, rooms_label, sep =" - "))
    
    
    
    ######## RUN REGRESSIONS #########        
    
    
    ### Regressions for 20+ group split:        
    
    #main regs      
    
    
    outcomes <- c("ADR","RevPAR","Occupancy","Demand","Revenue")
    
    
    mm = list()
    
    for(m in 1:length(outcomes)){
    mm[[m]] <- feols(
      as.formula(paste0("log(",outcomes[m],") ~ treated * post |  label + date")) ,
      data = df,
      weights = df$Rooms
    )
    
    }
    
    
    
    outres =   
      sapply(mm, function(x){data.frame(est=coef(x), se=se(x))}) %>% t() %>%as.data.frame() %>%  
      mutate(est = as.numeric(est), se = as.numeric(se), low = est+qnorm(0.025)*se, high = est + qnorm(0.975)*se) %>% 
      mutate(
        pct_est = 100 * (exp(est) - 1),
        pct_low = 100 * (exp(low) - 1),
        pct_high = 100 * (exp(high) - 1)
        
      )  %>% mutate(outcome = outcomes)  #%>% filter(outcome !="Demand")
    
    
    outres <- outres %>% rename(pct = pct_est )
    outres = outres %>% mutate(outcome = replace(outcome, outcome == "Revenue","Room Revenue"))
    
    
    outres = outres[c(3:4,5,2:1),]
            
    
            pdf("figures/raw/FigAX-differentOutcomes.pdf", width = 6, height = 4)
            plot(y = 1:nrow(outres), x = outres$pct, axes = F, xlab = "", ylab = "", pch = 16, col = NA, cex= outres$rooms_per/120, xlim = c(-18,6), ylim = c(0.5, 5.5))
            abline(v = 0,lty = 2)
            
            points(y=1:nrow(outres), x = outres$pct,pch = 16, col = pal[1], cex= outres$rooms/100)
            segments(y0 = 1:nrow(outres), x0 = outres$pct_low, x1 = outres$pct_high, col = pal[1])
            axis(1, at = seq(-6,4,2))
            text(x =-15, y = 1:nrow(outres), label = outres$outcome )
            mtext(side = 3, adj = 1, cex = 1.25, text = "")
            mtext(side = 1, text = "% change", line=1)
            
            dev.off()

            
            
            
            
            
            
            #######################
            ###################################################
            ####################
            
            ### event study stuyle
            
            #define variables
            df <- read_rds(file.path(clean_path, "AnalysisData_SubGroups.rds")) %>% filter(date>="2023-01-01") %>%
              arrange(group, date) %>%
              mutate(
                period = case_when(
                  date < as.Date("2025-05-01") ~ "pre",
                  date >= as.Date("2025-05-01") & date < as.Date("2025-09-01") ~ "anticip",
                  date >= as.Date("2025-09-01") ~ "post"
                ),
                period = factor(period, levels = c("pre", "anticip", "post"))
              ) %>%
              mutate(
                post = date >= as.Date("2025-09-01")
              ) 
            
            policy_date <- as.Date("2025-09-01")
            df$event_time <- with(df,
                                  12 * (as.integer(format(date, "%Y")) - as.integer(format(policy_date, "%Y"))) +
                                    (as.integer(format(date, "%m")) - as.integer(format(policy_date, "%m")))
            )
            df <- df[df$event_time >= -12 & df$event_time <= 12, ]
            
            
            df$event_time_binned <- df$event_time
            df$event_time_binned[df$event_time <= -6] <- -6
            df$event_time_binned[df$event_time >= 6]  <- 6
            
            # Retain all available post months within the event window.
            
            df$post_group <- with(df,
                                  ifelse(event_time < 0, event_time,
                                         ifelse(event_time <= 2, 1,
                                                ifelse(event_time <= 4, 2, NA)))
            )
            
            df$post_group[ df$post_group %in% -2:-3] <- -2
            df$post_group[ df$post_group %in% -4:-5]<- -3
            df$post_group[ df$post_group %in% -6:-12]<- -4
            
           m_es_adr<- feols(
              log(ADR) ~ i(event_time, treated, ref = -1) | label + date,
              data = df,
              weights = ~Rooms,
              cluster = ~label
            )

           
           m_es_revpar<- feols(
             log(RevPAR) ~ i(event_time, treated, ref = -1) | label + date,
             data = df,
             weights = ~Rooms,
             cluster = ~label
           )
           
           
           
           
        #plot   
           
          pdf("figures/raw/figAX-eventStudyReg.pdf", width = 10, height = 4) 
           
           # helper to extract event-study coefficients from fixest model
           extract_event_study <- function(model, outcome_label) {
             ct <- as.data.frame(coeftable(model))
             ct$term <- rownames(ct)
             rownames(ct) <- NULL
             
             es <- ct %>%
               filter(grepl("^event_time::", term)) %>%
               mutate(
                 event_time = sub("^event_time::", "", term),
                 event_time = sub(":treated$", "", event_time),
                 event_time = as.integer(event_time),
                 outcome = outcome_label,
                 estimate_pct = 100 * (exp(Estimate) - 1),
                 ci_low_pct = 100 * (exp(Estimate - 1.96 * `Std. Error`) - 1),
                 ci_high_pct = 100 * (exp(Estimate + 1.96 * `Std. Error`) - 1)
               ) %>%
               select(outcome, event_time, estimate_pct, ci_low_pct, ci_high_pct)
             
             # add reference period manually at -1
             ref_row <- data.frame(
               outcome = outcome_label,
               event_time = -1,
               estimate_pct = 0,
               ci_low_pct = 0,
               ci_high_pct = 0
             )
             
             bind_rows(es, ref_row) %>%
               arrange(event_time)
           }
           
           # build plotting data
           es_adr <- extract_event_study(m_es_adr, "ADR")
           es_revpar <- extract_event_study(m_es_revpar, "RevPAR")
           
           # common x/y limits
           all_df <- bind_rows(es_adr, es_revpar)
           
           ylim <- range(c(all_df$ci_low_pct, all_df$ci_high_pct), na.rm = TRUE)
           ypad <- 0.5
           ylim <- c(floor(ylim[1] - ypad), ceiling(ylim[2] + ypad))
           
           xlim <- range(all_df$event_time, na.rm = TRUE)
           
           # plotting function
           plot_es_panel <- function(df, main_title) {
             plot(
               df$event_time, df$estimate_pct,
               type = "n",
               xlim = xlim,
               ylim = ylim,
               xlab = "Months relative to implementation",
               ylab = "Estimated % change",
               main = main_title,
               xaxt = "n", axes = F
             )
             
             # reference lines
             abline(h = 0, lty = 2, col = "gray40")
             abline(v = 0, lty = 2, col = "gray40")
             
             # x-axis at every month, labels only at selected values
             axis(1, at = seq(min(xlim), max(xlim), by = 1), labels = FALSE)
             label_months <- unique(c(seq(min(xlim), max(xlim), by = 4), max(xlim)))
             axis(1, at = label_months, labels = label_months, tick = FALSE)

             axis(2, las = 2)
             
             # CIs
             segments(
               x0 = df$event_time, y0 = df$ci_low_pct,
               x1 = df$event_time, y1 = df$ci_high_pct,
               lwd = 1.5, col = "#8C2D19"
             )
             
             # points
             points(
               df$event_time, df$estimate_pct,
               pch = 16, cex = 1.2, col = "#8C2D19"
             )
             
             # connect points
             lines(
               df$event_time, df$estimate_pct,
               lwd = 1.2, col = "#8C2D19"
             )
           }
           
           # plot
           op <- par(no.readonly = TRUE)
           par(mfrow = c(1, 2), mar = c(5, 5, 4, 1), oma = c(0, 0, 1, 0))
           
           plot_es_panel(es_adr, "A. ADR")
           plot_es_panel(es_revpar, "B. RevPAR")
           
           par(op)
           
           dev.off()
           dir.create("output/hotel-time-series", recursive = TRUE, showWarnings = FALSE)
           write.csv(all_df, "output/hotel-time-series/event-study-estimates.csv", row.names = FALSE)

           
           

           
           
###### ######## ############ ########### ###################
#check demand shocks
                      
           
           
           
           #define variables
           df <- read_rds(file.path(clean_path, "AnalysisData_SubGroups.rds")) %>% filter(date>="2023-01-01") %>%
             arrange(group, date) %>%
             mutate(
               period = case_when(
                 date < as.Date("2025-05-01") ~ "pre",
                 date >= as.Date("2025-05-01") & date < as.Date("2025-09-01") ~ "anticip",
                 date >= as.Date("2025-09-01") ~ "post"
               ),
               period = factor(period, levels = c("pre", "anticip", "post"))
             ) %>%
             mutate(
               post = date >= as.Date("2025-09-01")
             )
           
           
           table(df$treated)
           table(df$period)
           table(df$treated, df$period)
           
           
           #### Labeling
           
           
           #clean up labeling ---
           plot_labels <- df %>% filter(substr(label,1,1)=="T") %>% 
             mutate(rooms_per = Rooms/n_hotels) %>% 
             group_by(label, Hotel.Class, Submarket.Name) %>% 
             summarise(stars = mean(Star.Rating), mstar = min(Star.Rating), rooms = mean(rooms_per)) %>% 
             mutate(
               rooms_label = "Small", 
               rooms_label = replace(rooms_label, rooms >=90 & rooms<120, "Medium"),
               rooms_label = replace(rooms_label, rooms >=120 & rooms<300, "Large"),
               rooms_label = replace(rooms_label, rooms >=300 , "Mega"),
               
               mkt_label = "Hollywood/West LA",
               mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
               mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles CBD", "Downtown (CBD)"),
               mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles North", "North LA"),
               mkt_label = replace(mkt_label, Submarket.Name == "Los Angeles Airport", "Airport"),
               
               class_label = "Luxury",
               class_label = replace(class_label, Hotel.Class == "Upper Midscale", "Midscale"),
               class_label = replace(class_label, Hotel.Class == "Upscale", "Upscale"),
               class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label!="North LA", "Upscale"),
               class_label = replace(class_label, Hotel.Class == "Upper Upscale" & mkt_label=="North LA" & stars>3.8, "Luxury"),
               
               
             ) %>% 
             as.data.frame() %>% arrange(Submarket.Name) %>% 
             mutate(plot_label = paste(mkt_label, class_label, rooms_label, sep =" - "))
           
           # df = df %>% filter(date <="2026-01-01")
           
           ######## RUN REGRESSIONS #########        
           
           
           ### Regressions for 20+ group split:        
           
           #main regs      
           
           m_dem <- feols(
             log(Demand) ~ treated * post | label + date,
             data = df,
             weights = df$Rooms
           )
           
           
           
           
           
           
           
           
           
           
           
           #############################
           
           df$share_rest10 = df$rest_num*10
           
           m_adr <- feols(
             log(ADR) ~ treated * post *share_rest10  | label + date,
             data = df,
             weights = df$Rooms
           )
           
           
           
           m_revpar <- feols(
             log(RevPAR) ~ treated * post*share_rest10 | label + date,
             data = df,
             weights = df$Rooms
           )
           

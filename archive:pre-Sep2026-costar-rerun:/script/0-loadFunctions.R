#add a function for adding alphas to colors	in plots
add.alpha <- function(col, alpha=1){
  if(missing(col))
    stop("Please provide a vector of colours.")
  apply(sapply(col, col2rgb)/255, 2, 
        function(x) 
          rgb(x[1], x[2], x[3], alpha=alpha))  
}	

# The doughnut function permits to draw a donut plot
doughnut <-
  function (x, labels = names(x), edges = 200, outer.radius = 0.8,
            inner.radius=0.6, clockwise = FALSE,
            init.angle = if (clockwise) 90 else 0, density = NULL,
            angle = 45, col = NULL, border = FALSE, lty = NULL,add = F,
            main = NULL, ...)
  {
    if (!is.numeric(x) || any(is.na(x) | x < 0))
      stop("'x' values must be positive.")
    if (is.null(labels))
      labels <- as.character(seq_along(x))
    else labels <- as.graphicsAnnot(labels)
    x <- c(0, cumsum(x)/sum(x))
    dx <- diff(x)
    nx <- length(dx)
    if(add != T){ plot.new()}
    pin <- par("pin")
    xlim <- ylim <- c(-1, 1)
    if (pin[1L] > pin[2L])
      xlim <- (pin[1L]/pin[2L]) * xlim
    else ylim <- (pin[2L]/pin[1L]) * ylim
    plot.window(xlim, ylim, "", asp = 1)
    if (is.null(col))
      col <- if (is.null(density))
        palette()
    else par("fg")
    col <- rep(col, length.out = nx)
    border <- rep(border, length.out = nx)
    angle <- rep(angle, length.out = nx)
    twopi <- if (clockwise)
      -2 * pi
    else 2 * pi
    t2xy <- function(t, radius) {
      t2p <- twopi * t + init.angle * pi/180
      list(x = radius * cos(t2p),
           y = radius * sin(t2p))
    }
    for (i in 1L:nx) {
      n <- max(2, floor(edges * dx[i]))
      P <- t2xy(seq.int(x[i], x[i + 1], length.out = n),
                outer.radius)
      polygon(c(P$x, 0), c(P$y, 0), density = density[i],
              angle = angle[i], border = border[i],
              col = col[i], lty = lty[i])
      Pout <- t2xy(mean(x[i + 0:1]), outer.radius)
      lab <- as.character(labels[i])
      if (!is.na(lab) && nzchar(lab)) {
        lines(c(1, 1.05) * Pout$x, c(1, 1.05) * Pout$y)
        text(1.1 * Pout$x, 1.1 * Pout$y, labels[i],
             xpd = TRUE, adj = ifelse(Pout$x < 0, 1, 0),
             ...)
      }
      ## Add white disc          
      Pin <- t2xy(seq.int(0, 1, length.out = n*nx),
                  inner.radius)
      polygon(Pin$x, Pin$y, density = density[i],
              angle = angle[i], border = border[i],
              col = "white", lty = lty[i])
    }
    
    title(main = main, ...)
    invisible(NULL)
  }




### for pulling out reg coefficients and cleaning up log coef


# helper: safely pull coef / SE / p-value
grab_term <- function(model, term) {
  ct <- coeftable(model)
  
  if (!term %in% rownames(ct)) {
    return(tibble(
      term = term,
      estimate = NA_real_,
      std_error = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_
    ))
  }
  
  tibble(
    term = term,
    estimate = unname(ct[term, "Estimate"]),
    std_error = unname(ct[term, "Std. Error"]),
    statistic = unname(ct[term, "t value"]),
    p_value = unname(ct[term, "Pr(>|t|)"])
  )
}

# helper: add percent interpretation for log models
add_pct <- function(df) {
  df %>%
    mutate(
      pct_effect = 100 * (exp(estimate) - 1),
      pct_low_95 = 100 * (exp(estimate - 1.96 * std_error) - 1),
      pct_high_95 = 100 * (exp(estimate + 1.96 * std_error) - 1)
    )
}


get_mode <- function(x) {
  # Create a frequency table
  freq_table <- table(x)
  # Find the name (value) that has the maximum frequency
  mode_value <- names(freq_table)[which.max(freq_table)]
  # Return the mode
  return(mode_value)
}


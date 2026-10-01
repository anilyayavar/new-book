# Quarto cannot cross-reference a code chunk that draws several plots under one
# caption (bookdown's fig.show='hold'). This wraps such chunks in a figure block:
#
#   ::: {#fig-label}
#   ```{r} ... ```
#   caption
#   :::
#
# Usage:  Rscript tools/fix_multipanel_figures.R fig-a fig-b ...
setwd(normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))), "..")))
labels <- commandArgs(TRUE)
cap_re <- "fig\\.cap\\s*=\\s*(\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*')"

for (f in list.files(pattern = "\\.qmd$")) {
  x <- readLines(f, encoding = "UTF-8", warn = FALSE)
  # leftover ```{=tex} wrappers around $$ equations
  tex <- which(x == "```{=tex}" & c(x[-1], "") == "$$")
  for (i in rev(tex)) {
    j <- i + which(x[(i + 1):length(x)] == "```")[1]
    x <- x[-c(i, j)]
  }
  changed <- length(tex) > 0
  for (lab in labels) {
    h <- grep(paste0("^```\\{r ", lab, "\\s*[,}]"), x)
    if (length(h) != 1) next
    m <- regmatches(x[h], regexpr(cap_re, x[h], perl = TRUE))
    if (!length(m)) { message("no literal fig.cap for ", lab, " in ", f); next }
    cap <- eval(parse(text = sub("^fig\\.cap\\s*=\\s*", "", m)))
    hdr <- sub(cap_re, "", x[h], perl = TRUE)
    hdr <- sub(paste0("^```\\{r ", lab, "\\s*,?"), "```{r ", hdr)
    hdr <- gsub(",\\s*,", ",", hdr)
    hdr <- sub("\\{r\\s*,\\s*", "{r ", hdr)
    hdr <- sub(",\\s*\\}$", "}", hdr)
    e <- h + which(grepl("^```\\s*$", x[(h + 1):length(x)]))[1]
    x <- c(x[seq_len(h - 1)], paste0("::: {#", lab, "}"), "", hdr, x[(h + 1):e], "", cap, ":::",
           if (e < length(x)) x[(e + 1):length(x)])
    changed <- TRUE
    message("wrapped ", lab, " in ", f)
  }
  if (changed) writeLines(enc2utf8(x), f, useBytes = TRUE)
}

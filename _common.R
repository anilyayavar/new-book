# Shared setup, sourced at the top of every chapter.
# Bookdown ran all chapters in one R session. Quarto runs each chapter separately,
# so anything a chapter needs from an earlier one must be loaded here or in that chapter.
library(knitr)
options(knitr.kable.NA = "")

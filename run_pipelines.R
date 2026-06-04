library(rmarkdown)
library(here)

run_pipeline <- function(){
  render(here("preprocessing", "Tidy_Cycle_Data.Rmd"), quiet = TRUE)
  print("Tidy Cycle Data succesfull!")
  
  
  render(here("preprocessing", "Tidy_Recovery_Data.Rmd"), quiet = TRUE)
  print("Tidy Recovery Data succesfull!")
  
  render(here("preprocessing", "Tidy_Sleep_Data.Rmd"), quiet = TRUE)
  print("Tidy Sleep Data succesfull!")
  
  render(here("preprocessing", "combine_tidy_data.Rmd"), quiet = TRUE)
  print("Data successfully combined")
}




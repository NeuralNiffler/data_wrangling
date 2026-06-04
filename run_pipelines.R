library(rmarkdown)
library(here)

run_pipeline <- function(){
  render(here("", "Tidy_Cycle_Data.Rmd"), quiet = TRUE)
  print("Tidy Cycle Data succesfull!")
  
  
  render(here("", "Tidy_Recovery_Data.Rmd"), quiet = TRUE)
  print("Tidy Recovery Data succesfull!")
  
  render(here("", "Tidy_Sleep_Data.Rmd"), quiet = TRUE)
  print("Tidy Sleep Data succesfull!")
  
  render(here("", "Notebook.Rmd"), quiet = TRUE)
  print("Data successfully combined")
}




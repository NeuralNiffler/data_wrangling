# data_wrangeling
data wrangeling for wearable data retrieved in JSON format. Goal is to add the 
whole set of data_wrangeling to these data.

this is done step by step in notebook.Rmd however in order to not overload the file 
some functions are externalized into a util/helpers.R file

## R-dependencies (renv)
This project uses `renv` for reproducible package versions.

1. Clone the project and open it in RStudio (or start R in the project directory). `renv` will bootstrap itself automatically.
2. Install the packages exactly as specified in `renv.lock`:
   ```R
   renv::restore()

## Devs
Documentation about the API and what the data retrieved means can be found here https://developer.whoop.com/api

If you add a new library please update renv accordingly:
renv::snapshot()




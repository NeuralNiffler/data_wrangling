library(httr)
library(jsonlite)
library(here)
library(lubridate)
library(dplyr)

# --- HAUPTFUNKTION ---

load_data <- function(datatype) {
   filename <- .get_data_filename(datatype)
   
    whoop_data <- jsonlite::read_json(here("data", filename), simplifyVector = TRUE, flatten = TRUE)
   
    return(whoop_data)
}

to_datetime <- function(variable) {
  return(lubridate::ymd_hms(variable) )
}

to_date <- function(variable) {
  return(lubridate::ymd(variable))
}

apply_timezone_offset <- function(utc_timestamp, offset_str) {
  
  dt_utc <- to_datetime(utc_timestamp)
  
  # 2. Vorzeichen bestimmen
  sign <- ifelse(str_sub(offset_str, 1, 1) == "-", -1, 1)
  
  # 3. Stunden und Minuten extrahieren
  clean_offset <- str_remove(offset_str, "^[+-]")
  parts <- str_split_fixed(clean_offset, ":", 2)
  hours <- as.numeric(parts[, 1])
  minutes <- as.numeric(parts[, 2])
  
  # 4. Offset in Sekunden umrechnen
  offset_seconds <- sign * ((hours * 3600) + (minutes * 60))
  
  # 5. Sekunden addieren
  dt_local <- dt_utc + seconds(offset_seconds)
  
  return(dt_local)
}

kj_to_calorie <- function(kilojoules) {
  return(kilojoules * 0.239006)
}

sanitize_data_structure <- function(df) {
  df %>%
    # 1. Leere Listen flachklopfen
    mutate(across(where(is.list), ~ map(.x, ~ if(length(.x) == 0) NA else .x) %>% unlist())) %>%
    # 2. Leere Text-Artefakte bereinigen
    mutate(across(where(is.character), ~na_if(.x, "character(0)")))
}

get_whoop_records <- function(endpoint, max_records = 100, records_per_batch = 25) {
  base_url <- "https://api.prod.whoop.com/developer/v2"
  
  path <- if (endpoint %in% c("sleep", "workout")) {
    paste0("activity/", endpoint)
  } else {
    endpoint
  }
  
  full_url <- paste(base_url, path, sep = "/")
  
  all_data <- list()
  current_token <- NULL
  total_fetched <- 0
  
  while (total_fetched < max_records) {
    
    req <- request(full_url) %>%
      req_url_query(limit = records_per_batch) %>%
      req_auth_bearer_token(get_whoop_token())
    
    if (!is.null(current_token)) {
      req <- req %>% req_url_query(nextToken = current_token)
    }
    
    resp <- req %>% req_perform() %>% resp_body_json()
    
    all_data <- c(all_data, resp$records)
    
    # Update Status
    current_token <- resp$next_token
    total_fetched <- length(all_data)
    
    print(length(all_data))
    
    # Abbruch, Ende der Daten
    if (is.null(current_token)) break
  }
  
  return(all_data)
}

get_whoop_token <- function() {
  
  .load_secret_variables()
  
  client_id     <- Sys.getenv("WHOOP_CLIENT_ID")
  client_secret <- Sys.getenv("WHOOP_CLIENT_SECRET")
  redirect_uri  <- Sys.getenv("WHOOP_REDIRECT_URI")
  
  token_path    <- "~/secrets/whoop_tokens.rds"
  
  # 1. Prüfen, ob bereits Tokens existieren
  if (!file.exists(token_path)) {
    message("Keine Token-Datei gefunden. Starte initialen Login-Prozess...")
 
    auth_url <- paste0(
      "https://api.prod.whoop.com/oauth/oauth2/auth?",
      "client_id=", client_id,
      "&redirect_uri=", URLencode(redirect_uri, reserved = TRUE),
      "&response_type=code",
      "&scope=offline%20read:profile%20read:body_measurement%20read:recovery%20read:cycles%20read:workout%20read:sleep",
      "&state=init_setup"
    )
    
    cat("1. Öffne diesen Link im Browser:\n", auth_url, "\n\n")
    cat("2. Logge dich ein und kopiere den 'code' aus der Adresszeile.\n")
    
    auth_code <- readline(prompt = "3. Gib hier den kopierten Code ein: ")
    
    tokens <- .create_token_from_code(client_id, client_secret, auth_code, redirect_uri, token_path)
  } else {
    tokens <- readRDS(token_path)
  }
  
  # 2. Token Expiry prüfen
  if (Sys.time() > tokens$expiry_time) {
    message("Access Token ist abgelaufen. Automatische Erneuerung (Refresh)...")
    tokens <- .refresh_whoop_token(client_id, client_secret, tokens$refresh_token, token_path)
  }
  
  return(tokens$access_token)
}

# --- HILFSFUNKTIONEN ---

.create_token_from_code <- function(client_id, client_secret, code, redirect_uri, token_path) {
  res <- POST(
    url = "https://api.prod.whoop.com/oauth/oauth2/token",
    encode = "form",
    body = list(
      grant_type = "authorization_code",
      code = code,
      client_id = client_id,
      client_secret = client_secret,
      redirect_uri = redirect_uri
    )
  )
  
  if (status_code(res) != 200) stop("Fehler beim Erstellen des Tokens: ", content(res)$error_description)
  
  token_data <- content(res)
  token_data$expiry_time <- Sys.time() + as.numeric(token_data$expires_in) - 60
  saveRDS(token_data, token_path)
  
  return(token_data)
}


.refresh_whoop_token <- function(client_id, client_secret, r_token, token_path) {
  res <- POST(
    url = "https://api.prod.whoop.com/oauth/oauth2/token",
    encode = "form",
    body = list(
      grant_type = "refresh_token",
      refresh_token = r_token,
      client_id = client_id,
      client_secret = client_secret
    )
  )
  
  if (status_code(res) != 200) {
    if (file.exists(token_path)) file.remove(token_path)
    stop("Refresh fehlgeschlagen. Token-Datei gelöscht. Bitte Skript für Neu-Login starten.")
  }
  
  token_data <- content(res)
  token_data$expiry_time <- Sys.time() + as.numeric(token_data$expires_in) - 60
  saveRDS(token_data, token_path)
  
  return(token_data)
}

.get_data_filename <- function(datatype) {
  
  return(paste0("whoop_", datatype , "_data_batch.json"))
}

# --- SLEEP CLEANING ---

# --- SLEEP CLEANING ---
# --- SLEEP CLEANING ---
clean_sleep <- function(raw_sleep) {
  
  # ── Task 1: Fix empty lists and parse dates ───────────────
  sleep <- raw_sleep %>%
    mutate(across(where(is.list),
                  ~ map(.x, ~ if(length(.x) == 0) NA else .x) %>%
                    unlist())) %>%
    mutate(
      date       = as.Date(lubridate::ymd_hms(created_at)),
      start_date = lubridate::ymd_hms(start),
      end_date   = lubridate::ymd_hms(end)
    ) %>%
    select(-created_at, -start, -end)
  
  # ── Task 2: Remove naps ───────────────────────────────────
  # WHOOP records naps as separate entries
  # We only want main sleep sessions
  sleep <- sleep %>%
    filter(nap == FALSE)
  
  # ── Task 3: Handle duplicates ─────────────────────────────
  # If two main sleep sessions exist on the same date
  # Keep only the longest one — it's the most complete record
  sleep <- sleep %>%
    mutate(
      duration = as.numeric(difftime(end_date, start_date, units = "hours"))
    ) %>%
    group_by(date) %>%
    slice_max(duration, n = 1) %>%
    ungroup()
  
  # ── Task 4: Extract sleep metrics ─────────────────────────
  # Convert milliseconds to hours (divide by 3,600,000)
  # Calculate derived metrics like deficit and total sleep
  sleep <- sleep %>%
    mutate(
      # sleep duration in hours
      sleep_duration = as.numeric(difftime(end_date, start_date, units = "hours")),
      
      # sleep deficit — negative means didn't sleep enough
      sleep_deficit = sleep_duration - (score.sleep_needed.baseline_milli / 3600000),
      
      # convert sleep stages from milliseconds to hours
      total_in_bed_hours      = score.stage_summary.total_in_bed_time_milli          / 3600000,
      total_awake_hours       = score.stage_summary.total_awake_time_milli           / 3600000,
      total_light_sleep_hours = score.stage_summary.total_light_sleep_time_milli     / 3600000,
      total_deep_sleep_hours  = score.stage_summary.total_slow_wave_sleep_time_milli / 3600000,
      total_rem_sleep_hours   = score.stage_summary.total_rem_sleep_time_milli       / 3600000,
      
      # total actual sleep = deep + rem + light combined
      total_sleep_hours = total_deep_sleep_hours +
        total_rem_sleep_hours  +
        total_light_sleep_hours
    ) %>%
    
    # ── Keep only useful columns ───────────────────────────
    # Drop raw millisecond columns — we have hours versions now
    select(
      cycle_id, date, start_date, end_date,
      sleep_duration, sleep_deficit,
      total_in_bed_hours, total_awake_hours,
      total_light_sleep_hours, total_deep_sleep_hours,
      total_rem_sleep_hours, total_sleep_hours,
      score.respiratory_rate,
      score.sleep_performance_percentage,
      score.sleep_consistency_percentage,
      score.sleep_efficiency_percentage,
      score.stage_summary.sleep_cycle_count,
      score.stage_summary.disturbance_count
    )
  
  return(sleep)
}
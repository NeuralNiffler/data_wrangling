library(httr)
library(jsonlite)

# --- HAUPTFUNKTION ---
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

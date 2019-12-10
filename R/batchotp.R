### External Dependencies
library(tidyverse)
library(httr)
library(whisker)
library(base64enc)
library(jsonlite)

### Class - BatchOTP
# Purpose: Communicate with otp server for remote batch scripting

# Constructor
BatchOTP <- function(ip="localhost", port=8080) {
  structure(list(ip=ip, port=port), class = "BatchOTP")
}

## Class Functions

# Purpose: Load a router from a graph on the otp server
LoadRouter <- function(otp, router_id) { UseMethod("LoadRouter") } # Generic
LoadRouter.BatchOTP <- function(otp, router_id) {
  # load the router
  resp <- httr::PUT(
    paste0(.otp_server_base_url(otp), "/otp/routers/", router_id)
  )

  # fetch the router information
  resp <- httr::GET(
    paste0(.otp_server_base_url(otp), "/otp/routers/", router_id)
  )
  json <- fromJSON(content(resp, "text", encoding="UTF-8"))

  print(paste0("Loaded router ", json$routerId, ": ", json$centerLatitude, "? ", json$centerLongitude, "? | ",
               .seconds_to_date(json$transitServiceStarts), " to ", .seconds_to_date(json$transitServiceEnds)))
}

# Purpose: Send a batch request to the otp server
BatchRequest <- function(otp, req) { UseMethod("BatchRequest") } # Generic
BatchRequest.BatchOTP <- function(otp, req) {
  # process csv files to base64 python strings
  req$origs_data_base64 <- BreakupString(.csv_to_base64(req$origs_filename, !as.logical(req$arrive_by)), 2000, "\" + \\\n\"")
  req$dests_data_base64 <- BreakupString(.csv_to_base64(req$dests_filename, as.logical(req$arrive_by)), 2000, "\" + \\\n\"")
  req$origs_filename <- NULL
  req$dests_filename <- NULL

  # customize the python template script for the job parameters
  template <- readLines("otp_script_template.py")
  writeLines(whisker::whisker.render(template, req), "otp_script_output.py")

  # send the python template script to the server
  f <- upload_file("otp_script_output.py")
  resp <- httr::POST(
    paste0(.otp_server_base_url(otp), "/otp/scripting/run"),
    body=list(scriptfile=f),
    encode="multipart"
  )

  # create a data frame from the server response
  raw_csv <- paste0(content(resp, "text", encoding="UTF-8"), "\n")
  df <- read.csv(text=raw_csv)

  return(df)
}

.otp_server_base_url <- function(otp) {
  paste0("http://", otp$ip, ":", otp$port)
}

.csv_to_base64 <- function(csv_file_path, has_time) {
  # validate csv and reduce size
  csv_df <- read.csv(file=csv_file_path)
  if (has_time) {
    validate_df_columns(csv_df, c("id", "lat", "lon", "time"), csv_file_path)
    csv_df <- select(csv_df, id, lat, lon, time)
  } else {
    validate_df_columns(csv_df, c("id", "lat", "lon"), csv_file_path)
    csv_df <- select(csv_df, id, lat, lon)
  }

  # save and reload compressed valid csv
  write.csv(csv_df, file="temp.csv", row.names=FALSE)
  csv_text <- readChar("temp.csv", file.info("temp.csv")$size)
  file.remove("temp.csv")

  # convert to base64
  csv_text %>% gsub("\r\n", "\n", .) %>% charToRaw %>% base64enc::base64encode(.)
}

.seconds_to_date <- function(s) {
  as.Date(floor(s/(3600*24)), origin = "1970-01-01")
}

### End Class


### Generic Functions

# Purpose: Add break characters into a string s every n characters
BreakupString <- function(s, n, break_chars="|") {
  s_array <- strsplit(s, "")[[1]]
  s_return <- ""

  i <- 1
  while(i <= length(s_array)) {
    start <- i
    end <- i + (n-1)
    if (end >= length(s_array)) {
      s_return <- paste0(s_return, paste0(s_array[start:length(s_array)], collapse=""))
    } else {
      s_return <- paste0(s_return, paste0(s_array[start:end], collapse=""), break_chars)
    }

    i <- end + 1
  }

  return(s_return)
}

# Purpose: Validate that a data source contains a set of columns
validate_df_columns <- function(df, columns, orig_var_name) {
  if (!all(i <- rlang::has_name(df, columns)))
    stop(sprintf(
      "%s doesn't contain: %s",
      orig_var_name, #deparse(substitute(df)),
      paste(columns[!i], collapse=", ")))
}

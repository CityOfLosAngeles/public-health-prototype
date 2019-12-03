library(dplyr)
library(DBI)
library(sys)
library(stringr)

conn_string = Sys.getenv('POSTGRES_URI')

split <- conn_string %>% str_split(":") 

username <- split[[1]][2] %>% str_remove('//')

second_split <- split[[1]][3] %>% str_split('@') 
password <- second_split[[1]][1]
host <- second_split[[1]][2]

db_name <- split[[1]][4] %>% str_remove('5432/')

con <- dbConnect(RPostgres::Postgres(),
                 dbname = db_name, 
                 host = host,
                 port = 5432, 
                 user = username,
                 password = password)


cases <- tbl(con, dbplyr::in_schema('"public-health"','"311-cases-homelessness"')) %>% collect()


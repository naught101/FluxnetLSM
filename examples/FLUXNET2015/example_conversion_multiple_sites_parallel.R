#' Example data conversion for multiple sites using parallel programming.
#'
#' Converts useful variables from a FLUXNET2015 "FULLSET" spreatsheet format into two
#' netcdf files, one for fluxes, and one for met forcings. For "SUBSET" data,
#' set flx2015_version="SUBSET" in the main function.
#' 
#' The user must provide the input directory path and
#' output directory path. Code will automatically retrieve
#' input files. All other input arguments are optional and 
#' are set to their default values in this example.
#' 
#' Requires package "parallel"
#' 

library(FluxnetLSM)
library(parallel)

#clear R environment
rm(list=ls(all=TRUE))


#############################
###--- Required inputs ---###
#############################

#--- User must define these ---#

# This directory should contain appropriate data from 
# http://fluxnet.fluxdata.org/data/fluxnet2015-dataset/
in_path <- "./Inputs"
ERA_path <- "./ERA_inputs"

#Outputs will be saved to this directory
out_path <- "./Outputs"

# Get default conversion options. See help(get_default_conversion_options)
conv_opts <- get_default_conversion_options()


#--- Automatically retrieve all Fluxnet files in input directory ---#

# Input Fluxnet data files (using FULLSET in this example, se R/Helpers.R for details)
infiles <- get_fluxnet_files(in_path,
                             datasetname = conv_opts$datasetname,
                             subset = conv_opts$flx2015_version)

#Retrieve dataset versions
datasetversions <- sapply(infiles, get_fluxnet_version_no)

#Retrieve site codes
site_codes <- sapply(infiles, get_path_site_code)


###############################
###--- Optional settings ---###
###############################

# ERAinterim meteo file for gap-filling met data (set to FALSE if not desired)
# Find ERA-files corresponding to site codes
ERA_gapfill  <- TRUE
ERA_files <- sapply(site_codes, function(x) {
                    get_fluxnet_erai_files(ERA_path, site_code = x,
                                           datasetname = conv_opts$datasetname)
                    })

#Stop if didn't find ERA files
if(any(sapply(ERA_files, length)==0) & ERA_gapfill==TRUE){
  stop("No ERA files found, amend input path")
}


#Thresholds for missing and gap-filled time steps
#Note: Always checks for missing values. If no gapfilling 
#thresholds set, will not check for gap-filling.
conv_opts$missing      <- 15 #max. percent missing (must be set)
conv_opts$gapfill_all  <- 20 #max. percent gapfilled (optional)
conv_opts$gapfill_good <- NA #max. percent good-quality gapfilled (optional, ignored if gapfill_all set)
conv_opts$gapfill_med  <- NA #max. percent medium-quality gapfilled (optional, ignored if gapfill_all set)
conv_opts$gapfill_poor <- NA #max. percent poor-quality gapfilled (optional, ignored if gapfill_all set)
conv_opts$min_yrs      <- 2  #min. number of consecutive years
conv_opts$met_gapfill  <- "ERAinterim"  #min. number of consecutive years

#Should code produce plots to visualise outputs? Set to NA if not desired.
#(annual: average monthly cycle; diurnal: average diurnal cycle by season;
#timeseries: 14-day running mean time series)
plot <- c("annual", "diurnal","timeseries")

#Should all evaluation variables be included regardless of data gaps?
#If FALSE, removes evaluation variables with gaps in excess of thresholds
conv_opts$include_all_eval <- TRUE


##########################
###--- Run analysis ---###
##########################

#Initialise clusters (using 2 cores here)
cl <- makeCluster(getOption('cl.cores', 2))

#Import variables to cluster
clusterExport(cl, "out_path")
if(exists("conv_opts"))  {clusterExport(cl, "conv_opts")}
if(exists("datasetversion"))   {clusterExport(cl, "datasetversion")}
if(exists("plot"))             {clusterExport(cl, "plot")}


#Loops through sites
clusterMap(cl = cl, function(site_code, infile, ERA_file, datasetversion) {
    library(FluxnetLSM)
    tryCatch(
        convert_fluxnet_to_netcdf(
            site_code = site_code,
            infile = infile,
            era_file = ERA_file,
            out_path=out_path,
            conv_opts = conv_opts,
            plot = plot,
            datasetversion = datasetversion  # overrides conv_opts
            ),
         error = function(e) NULL)
    },
    site_code = site_codes,
    infile = infiles,
    datasetversion = datasetversions,
    ERA_file = ERA_files)


stopCluster(cl)

#' ---	
#' title: "Intersect VarScan and Strelka"	
#' author: "Stacy Hung"	
#' date: "May 30, 2017"	
#' output: html_document	
#' ---	
#' 	
#' This script performs the following tasks:	
#' 1. Filters varScan predictions (output produced from running varScan.mk with appropriate parameters)	
#' 2. Intersects varScan and Strelka predictions (indels from VarScan only)	
#' 3. Retrieves meta-data associated with mutation calls, and organizes all this into format ready to be merged with master file	
#' 	
#' For details on filters used in Varscan, please consult http://varscan.sourceforge.net/somatic-calling.html	
#' 	
#' For effect and codon annotation, SnpEff-4.0 is used, while for HGVS annotation (cds and protein), SnpEff-4.2 is used.	
#' 	
#' How to run this script:	
#' 	
#' Rscript GPH-varscan+strelka_to_masterlist.R <1> <2> <3> <4> <5> <6>
#' 	
#' where 	
#' 	
#' <1> is the absolute file path of the varscan snp table annotated with SnpEff-4.0	
#' <2> is the absolute file path of the varscan indel table annotated with SnpEff-4.0	
#' <3> is the absolute file path of the varscan snp table annotated with SnpEff-4.2	
#' <4> is the absolute file path of the varscan indel table annotated with SnpEff-4.2	
#' <5> is the absolute file path of the strelka passed.snvs
#' <6> is the absolute file path of the output results directory
#' 	
#' 	
#' ## Load and filter varScan dataset	
#' 	
#' 	
install.packages("plyr", repos='http://cran.rstudio.com/')
install.packages("dplyr", repos='http://cran.rstudio.com/')
install.packages("tidyr", repos='http://cran.rstudio.com/')
install.packages("DataCombine", repos='http://cran.rstudio.com/')
install.packages("xlsx", repos='http://cran.rstudio.com/')	

library(dplyr)    # filter	
library(tidyr)    # separate	
library(DataCombine) # find and replace	
	
args <- commandArgs(trailingOnly = TRUE)	
	
# use SnpEff-4.0 for effect annotation	
varscan_snvs.snpEff_4.0 <- args[1]	
varscan_indels.snpEff_4.0 <- args[2]	
	
# read in the files	
varscan.snvs <- read.table(varscan_snvs.snpEff_4.0, sep = "\t", header = TRUE, fill = TRUE)	
varscan.indels <- read.table(varscan_indels.snpEff_4.0, sep = "\t", header = TRUE, fill = TRUE)	
# combine snvs + indels for SnpEFf-4.0 effect annotations	
varscan.snvs$type = "snv"	
varscan.indels$type = "indel"	
varscan.calls <- rbind(varscan.snvs, varscan.indels)	
	
# use SnpEff-4.2 for HGVS annotation	
varscan_snvs.snpEff_4.2 <- args[3]	
varscan_indels.snpEff_4.2 <- args[4]	
	
# read in the files	
varscan.snvs.hgvs <- read.table(varscan_snvs.snpEff_4.2, sep = "\t", header = TRUE, fill = TRUE)	
varscan.indels.hgvs <- read.table(varscan_indels.snpEff_4.2, sep = "\t", header = TRUE, fill = TRUE)	
# combine snvs + indels for SnpEff-4.2 HGVS annotations	
varscan.snvs.hgvs$type = "snv"	
varscan.indels.hgvs$type = "indel"	
varscan.calls.hgvs <- rbind(varscan.snvs.hgvs, varscan.indels.hgvs)	
	
# clean up - remove unused datasets	
rm(varscan.snvs)	
rm(varscan.indels)	
rm(varscan.snvs.hgvs)	
rm(varscan.indels.hgvs)	
	
# rename columns	
colnames(varscan.calls) <- c("sample", "chr", "pos", "external_id", "ref", "alt", "qual", "filter",	
                            "depth", "somatic_status", "ssc", "gpv", "somatic_p_value", "cda",	
                            "KG_validated", "om", "pm", "gmaf", "gt_normal", "gt_tumor", "gq_normal", "gq_tumor",	
                            "depth_normal", "depth_tumor", "ref_reads_normal", "ref_reads_tumor",	
                            "var_reads_normal", "var_reads_tumor", "allele_freq_normal", "allele_freq_tumor",	
                            "depth4_normal", "depth4_tumor", "effect", "impact", "fun_class", "codon",	
                            "HGVS", "gene", "biotype", "coding", "transcript_id", "exon_rank", "type")	
colnames(varscan.calls.hgvs) <- colnames(varscan.calls)	
	
# create a case_id column based on the sample id (format is <case_id>_<normal_id>) - e.g. GE0556B_GE0556-N	
varscan.calls$case_id <- gsub("(.*)\\_(.*)","\\1", varscan.calls$sample)	
varscan.calls.hgvs$case_id <- gsub("(.*)\\_(.*)","\\1", varscan.calls.hgvs$sample)	
# after merging with strelka calls, we will need to remove the scroll identifier (e.g. A, B, etc.)	
	
# remove unneeded columns and rearrange as necessary	
# last few columns are for initial filtering and reference and can be removed later	
keeps <- c("case_id", "chr", "pos", "gene", "codon", "ref", "alt", "HGVS",	
           "somatic_p_value", "allele_freq_normal", "allele_freq_tumor", 	
           "depth4_normal", "depth4_tumor", "var_reads_normal", "var_reads_tumor", 	
           "effect", "impact", "fun_class", "transcript_id", "external_id", 	
           "filter", "somatic_status", "gmaf", "gt_normal", "gt_tumor", "type")	
varscan.calls <- varscan.calls[keeps]	
	
# we only need key and HGVS information from the HGVS dataset	
keeps <- c("case_id", "chr", "pos", "gene", "ref", "alt", "HGVS", 	
           "effect", "filter", "somatic_status", "gmaf", "type")	
varscan.calls.hgvs <- varscan.calls.hgvs[keeps]	
	
# remove "%" from the allele frequency	
varscan.calls$allele_freq_normal <- gsub("(.*)\\%(.*)","\\1", varscan.calls$allele_freq_normal)	
varscan.calls$allele_freq_tumor <- gsub("(.*)\\%(.*)","\\1", varscan.calls$allele_freq_tumor)	
	
# split the HGVS column into HGVS protein and HGVS cds	
# NB: need to account for cases that migth not have one or both	
# e.g. in many cases, there will only be the CDS annotation present - in cases like this, it will get assigned to the first column listed in the "into" parameter of separate	
varscan.calls.hgvs <-	
  separate(data = varscan.calls.hgvs,	
           col = HGVS,	
           into = c("HGVS_protein_snpEff_4.2", "HGVS_cds_snpEff_4.2"),	
           sep = "/",	
           remove = TRUE,	
           fill = "left")	
	
# mappings for 3-letter amino acids to 1-letter amino acid codes	
AA.replaces <- data.frame(from = c("Ala", "Arg", "Asn", "Asp", "Asx", "Cys", "Glu", "Gln", "Glx", "Gly", "His", 	
                                   "Ile", "Leu", "Lys", "Met", "Phe", "Pro", "Ser", "Thr", "Trp", "Tyr", "Val"), 	
                          to = c("A", "R", "N", "D", "B", "C", "E", "Q", "Z", "G", "H", 	
                                 "I", "L", "K", "M", "F", "P", "S", "T", "W", "Y", "V"))	
	
varscan.calls.hgvs <- FindReplace(data = varscan.calls.hgvs, 	
                                    Var = "HGVS_protein_snpEff_4.2",	
                                    replaceData = AA.replaces,	
                                    from = "from",	
                                    to = "to",	
                                    exact = FALSE)	
	
# replace NA values with blanks in the HGVS_protein_snpEff_4.2 column
varscan.calls.hgvs$HGVS_protein_snpEff_4.2 <- sapply(varscan.calls.hgvs$HGVS_protein_snpEff_4.2, as.character)
varscan.calls.hgvs$HGVS_protein_snpEff_4.2[is.na(varscan.calls.hgvs$HGVS_protein_snpEff_4.2)] <- " "

# filter varscan calls for somatic calls (SS = 2, GMAF < 0.001 [if available]) and have a PASS filter	
varscan.calls <- filter(varscan.calls, somatic_status == 2 & filter == 'PASS' & (gmaf < 0.001 | is.na(gmaf)))	
varscan.calls.hgvs <- filter(varscan.calls.hgvs, somatic_status == 2 & filter == 'PASS' & (gmaf < 0.001 | is.na(gmaf)))	
	
# remove duplicates (e.g. due to multiple effects) in the HGVS dataset	
varscan.calls.hgvs <- unique(varscan.calls.hgvs)	
	
# filter HGVS calls for obvious effects	
varscan.calls <- unique(rbind(	
                varscan.calls[grep("FRAME_SHIFT", varscan.calls$effect), ],	
                varscan.calls[grep("SPLICE_SITE_ACCEPTOR", varscan.calls$effect), ],	
                varscan.calls[grep("SPLICE_SITE_DONOR", varscan.calls$effect), ],	
                varscan.calls[grep("CODON_CHANGE_PLUS_CODON_DELETION", varscan.calls$effect), ],	
                varscan.calls[grep("CODON_DELETION", varscan.calls$effect), ],	
                varscan.calls[grep("CODON_INSERTION", varscan.calls$effect), ],	
                varscan.calls[grep("NON_SYNONYMOUS_CODING", varscan.calls$effect), ],	
                varscan.calls[grep("NON_SYNONYMOUS_START", varscan.calls$effect), ],	
                varscan.calls[grep("START_GAINED", varscan.calls$effect), ],	
                varscan.calls[grep("START_LOST", varscan.calls$effect), ],	
                varscan.calls[grep("STOP_GAINED", varscan.calls$effect), ],	
                varscan.calls[grep("STOP_LOST", varscan.calls$effect), ]	
                ))	
	
varscan.calls.hgvs <- unique(rbind(	
                varscan.calls.hgvs[grep("FRAME_SHIFT", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("SPLICE_SITE_ACCEPTOR", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("SPLICE_SITE_DONOR", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("CODON_CHANGE_PLUS_CODON_DELETION", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("CODON_DELETION", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("CODON_INSERTION", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("NON_SYNONYMOUS_CODING", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("NON_SYNONYMOUS_START", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("START_GAINED", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("START_LOST", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("STOP_GAINED", varscan.calls.hgvs$effect), ],	
                varscan.calls.hgvs[grep("STOP_LOST", varscan.calls.hgvs$effect), ]	
                ))	
	
varscan.calls$combine = as.character(paste(	
  varscan.calls$case_id, 	
  varscan.calls$chr, 	
  varscan.calls$pos, 	
  varscan.calls$ref,	
  varscan.calls$alt,	
  sep = "."	
  ))	
	
varscan.calls.hgvs$combine = as.character(paste(	
  varscan.calls.hgvs$case_id, 	
  varscan.calls.hgvs$chr, 	
  varscan.calls.hgvs$pos, 	
  varscan.calls.hgvs$ref,	
  varscan.calls.hgvs$alt,	
  sep = "."	
  ))	
	
# use combine as a hash key to map HGVS data from SnpEff-4.2 dataset to the SnpEff-4.0 dataset (should not just be appending columns as with current setup)	
	
# dataNew:	
# lookupVariable - variable in parent data that we want to match against (e.g. "varscan.calls$combine")	
# lookupValue - value of lookupVariable to match against (e.g. list of values under varscan.hgvs$combine)	
# newVariable - variable to be changed (e.g. "HGVS_protein_snpEff_4.2", "HGVS_cds_snpEff_4.2")	
# newValue - value of newVariable for matched rows (e.g. the values corresponding to the combine key in lookupVlaue and under the column newVariable)	
	
# to apply addNewData.R:	
# create dataNew, by creating a 4-column matrix as follows:	
# 1. first column (lookupVariable) contains only the values "combine" - this should be added at the end	
# 2. second column (lookupValue) is a copy of varscan.hgvs$combine	
# 3. third column (newVariable) contains either the value "HGVS_protein_snpEff_4.2" or "HGVS_cds_snpEff_4.2"	
# 4. fourth column (newValue) contains the actual HGVS, and is a copy of varscan.hgvs$HGVS_protein_snpEff_4.2 or varscan.hgvs$HGVS_cds_snpEff_4.2	
	
newData.protein <- varscan.calls.hgvs[,c("combine","HGVS_protein_snpEff_4.2")]	
colnames(newData.protein) <- c("lookupValue", "newValue")	
newData.protein$newVariable <- "HGVS_protein_snpEff_4.2"	
	
newData.cds <- varscan.calls.hgvs[,c("combine","HGVS_cds_snpEff_4.2")]	
colnames(newData.cds) <- c("lookupValue", "newValue")	
newData.cds$newVariable <- "HGVS_cds_snpEff_4.2"	
	
newData <- rbind(newData.protein, newData.cds)	
newData$lookupVariable <- "combine"	
newData <- newData[c("lookupVariable", "lookupValue", "newVariable", "newValue")] # rearrange columns	
write.csv(newData, "newData.csv", row.names = FALSE, quote = FALSE)	
	
source("~/Documents/scripts/addNewData.R")	
allowedVars <- c("HGVS_protein_snpEff_4.2", "HGVS_cds_snpEff_4.2")	
varscan.calls.hgvs.merge <- addNewData("newData.csv", varscan.calls, allowedVars)	
	
#' 	
#' 	
#' ## Load strelka dataset and intersect with filtered VarScan	
#' 	
#strelka_file <- "~/Documents/projects/GenomeCanada/Capture_GPH29/strelka/passed.snvs"	
	
strelka_file <- args[5]	
	
strelka_snvs <- read.table(strelka_file, sep="\t", header=FALSE)	
	
# extract only columns of interest	
strelka_snvs <- strelka_snvs[,c("V1", "V2", "V3", "V5", "V6")]	
	
# rename columns	
colnames(strelka_snvs) <- c("case_id", "chr", "pos", "ref", "alt")	
strelka_snvs$type <- "snv"	
	
# include mutation type for finding overlap with strelka (since we are only interested in SNVs)	
varscan.calls.hgvs.merge$combine <- as.character(paste(	
  varscan.calls.hgvs.merge$type,	
  varscan.calls.hgvs.merge$case_id, 	
  varscan.calls.hgvs.merge$chr, 	
  varscan.calls.hgvs.merge$pos, 	
  varscan.calls.hgvs.merge$ref,	
  varscan.calls.hgvs.merge$alt,	
  sep = "."	
  ))	
	
strelka_snvs$combine = as.character(paste(	
  strelka_snvs$type,	
  strelka_snvs$case_id,	
  strelka_snvs$chr,	
  strelka_snvs$pos,	
  strelka_snvs$ref,	
  strelka_snvs$alt,	
  sep = "."	
  ))	
	
overlap <- intersect(varscan.calls.hgvs.merge$combine, strelka_snvs$combine)  	
snvs.overlap <- subset(varscan.calls.hgvs.merge, varscan.calls.hgvs.merge$combine %in% overlap)	
snvs.overlap$in_strelka = "1"	
	
# add indels	
indels <- subset(varscan.calls.hgvs.merge, varscan.calls.hgvs.merge$type == 'indel')	
indels$in_strelka = "NA"	
indels$fun_class = "NONE"	
	
calls.overlap <- rbind (snvs.overlap, indels)	
	
# do some cleanup	
rm(varscan.calls)	
rm(varscan.calls.hgvs)	
rm(varscan.calls.hgvs.merge)	
rm(newData)	
#' 	
#' 	
#' ## format and insert data to fit master table	
#' 	
#' 	
# columns to fill in (from external datasets, via this script, or manually after exporting data):	
#     ...case_id...	
#     path:               pathology (grab from GPH_TARGETED_SEQUENCING.xls)	
#     ...chr, pos, gene...	
#     type:               Type of mutation {snv, indel}	
#     in_strelka:         1 if present in Strelka, 0 if not, NA if indel (not applicable)	
#     expt_id_normal:     experiment id of the normal (grab from GPH_TARGETED_SEQUENCING.xls)	
#     expt_id_tumor:      experiment id of the tumor (grab from GPH_TARGETED_SEQUENCING.xls)	
#     validation_id:      ***to be filled in manually (Stacy / Barbara)	
#     validation_result:  ***to be filled in manually (Stacy / Barbara)	
#     validation_comment: ***to be filled in manually (Stacy / Barbara)	
#     allele_info:        ***to be filled in manually (Barbara)	
#     annotation_flag:    ***to be filled in manually (Barbara)	
#     report:             ***to be filled in manually (Barbara)	
#     ...codon, ref, alt, HGVS_cds_snpEff_4.2, HGVS_protein_snpEff_4.2...	
#     !remove "HGVS" column	
#     HGVS_cds_report:    ***to be filled in manually (Barbara)	
#     HGVS_protein_report:***to be filled in manually (Barbara)	
#     ...somatic_p_value, allele_freq_normal, allele_freq_tumor, depth4_normal, depth4_tumor...	
#     has_1_or_0:         ***to be filled in by Stacy	
#     ...var_reads_normal, var_reads_tumor...	
#     avg_cov_normal:     average coverage of normal sample (grab from GPH_TARGETED_SEQUENCING.xls)	
#     avg_cov_tumor:      average coverage of tumor sample (grab from GPH_TARGETED_SEQUENCING.xls)	
#     ...effect_snpEff_4.0, impact, fun_class, transcript_id, external_id	
	
# read in external data files	
library(xlsx)	
ext_file <- "/Volumes/BCCA/docs/lymphoma/GPH/other_files/TARGETED_SEQ/GPH_TARGETED_SEQUENCING.xls"	
ext_data <- read.xlsx(ext_file, 1)  # read the first sheet	
	
# from GPH_TARGETED_SEQUNENCING.xlsx we will need to use the columns CASE_ID, PATH {NORMAL, CLL, DLBCL, FL}, EXPERIMENT_ID, and Average.Coverage	
	
keeps <- c("CASE_ID", "PATH", "EXPERIMENT_ID", "Method", "Version", "use.data", "Average.Coverage")	
ext_data <- ext_data[keeps]	
colnames(ext_data) <- c("case_id", "path", "expt_id", "Method", "Version", "use.data", "Average.Coverage")	
	
# remove scroll identifier from case id so that it can be used as a lookup key in the lookup table
#     \\d     digit {0, 1, 2, ..., 9}
#     \\D     non-digit
#     x{n}    occurs exactly n times
calls.overlap$case_id <- gsub("(GE\\d{4})(\\D+)","\\1", calls.overlap$case_id)
	
# filter out unnecessary data	
ext_data <- subset(ext_data, ext_data$Method == 'Capture')	
ext_data <- subset(ext_data, ext_data$use.data == 'yes')	
	
# data specific for tumors (pathology, experiment_id, average coverage)	
ext_data.tumors <- subset(ext_data, ext_data$path != 'NORMAL')	
colnames(ext_data.tumors) <- c("case_id", "path", "expt_id_tumor", "Method", "Version", "use.data", "avg_cov_tumor")	
# data specific for normals (experiment_id, average coverage)	
ext_data.normals <- subset(ext_data, ext_data$path == 'NORMAL')	
colnames(ext_data.normals) <- c("case_id", "path", "expt_id_normal", "Method", "Version", "use.data", "avg_cov_normal")	
	
ext_data.path <- unique(ext_data.tumors[c("case_id", "path")])	
ext_data.tumors <- unique(ext_data.tumors[c("case_id", "expt_id_tumor", "avg_cov_tumor")])	
ext_data.normals <- unique(ext_data.normals[c("case_id", "expt_id_normal", "avg_cov_normal")]) # still duplicate case ids	
	
# fill in path, expt_id_tumor and avg_cov_tumor from tumor subset of GPH_TARGETED_SEQ	
library(plyr)	
calls.overlap.path <- join(calls.overlap, ext_data.path, by = "case_id")        # retrieve pathology	
calls.overlap.path <- join(calls.overlap.path, ext_data.tumors, by = "case_id") # retrieve expt_id_tumor, avg_cov_tumor	
	
# fill in expt_id_normal and avg_cov_normal from normal subset of GPH_TARGETED_SEQ	
calls.overlap.path <- join(calls.overlap.path, ext_data.normals, by = "case_id") # retrieve expt_id_normal, avg_cov_normal	
	
# remove "NA"s for functional class	
calls.overlap.path$fun_class[calls.overlap.path$fun_class==""] <- "NONE"	
calls.overlap.path$fun_class[is.na(calls.overlap.path$fun_class)] <- "NONE"	
	
# add empty columns for manual input (Barbara to fill in)	
calls.overlap.path$validation_id = ""	
calls.overlap.path$validation_result = ""	
calls.overlap.path$validation_comment = ""	
calls.overlap.path$allele_info = ""	
calls.overlap.path$annotation_flag = ""	
calls.overlap.path$report = ""	
calls.overlap.path$HGVS_cds_report = ""	
calls.overlap.path$HGVS_protein_report = ""	
calls.overlap.path$has_1_or_0 = ""	

# assign values to the "has_1_or_0" column
#     "1or0" if depth4_tumor{a,b,c,d} has [0|1] in {a} or [0|1] in {b}
#     "not1or0" otherwise

# psuedocode:
# 1. parse out last two digits of depth4_tumor column
# 2. applying mapping / function to generate values for has_1_or_0 column

# input of this function is the depth4_tumor column
# to apply this function to a dataframe, use sapply(dataframe$column, get_has_1_or_0)
# the return value will be a vector of "0or1" or "not0or1" values
get_has_1_or_0 <- function(x)
{
  # return "1or0" or "not1or0" depending on the last two values of the input
  depths <- unlist(strsplit(x, split = ",", fixed = TRUE))
  if (depths[3] == "0" | depths[3] == "1" | depths[4] == "0" | depths[4] == "1")
    "1or0"
  else {
    "not1or0"
  }
}
calls.overlap.path$has_1_or_0 <- sapply(as.matrix(calls.overlap.path$depth4_tumor), get_has_1_or_0)

# rearrange columns in order of master file	
keeps <- c("case_id", "path", "chr", "pos", "gene", "type", "in_strelka", "expt_id_normal", "expt_id_tumor",	
           "validation_id", "validation_result", "validation_comment", "allele_info", "annotation_flag", "report",	
           "codon", "ref", "alt", "HGVS_cds_snpEff_4.2", "HGVS_protein_snpEff_4.2", "HGVS_cds_report",	
           "HGVS_protein_report", "somatic_p_value", "allele_freq_normal", "allele_freq_tumor", 	
           "depth4_normal", "depth4_tumor", "has_1_or_0", "var_reads_normal", "var_reads_tumor", 	
           "avg_cov_normal", "avg_cov_tumor", "effect", "impact", "fun_class", "transcript_id", "external_id")	
calls.final <- calls.overlap.path[keeps]	
	
# sort the calls by case, chr, then position	
calls.final <- arrange(calls.final, case_id, chr, pos)	
	
output_dir <- args[6]	
setwd(output_dir)
#setwd("~/Documents/projects/GenomeCanada/Capture_GPH29/intersect_check/")	
write.table(calls.final, "snvs.final-varscan_intersect_strelka.txt", sep = "\t", quote = FALSE, row.names = FALSE)	
#' 	

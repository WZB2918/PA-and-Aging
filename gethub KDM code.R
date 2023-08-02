setwd("D:\\Homework\\PAanddiet\\PAandOlder\\BioAge-master")
getwd()
library(BioAge)
library(dplyr)
#HD using NHANES (separate training for men and women)
hd = hd_nhanes(biomarkers=c("albumin","alp","lncrp","totchol","lncreat","hba1c","sbp","bun","uap","lymph","mcv","wbc"))

#KDM bioage using NHANES (separate training for men and women)
kdm = kdm_nhanes(biomarkers=c("albumin","alp","lncrp","totchol","lncreat","hba1c","sbp","bun","uap","lymph","mcv","wbc"))

#phenoage uinsg NHANES
phenoage = phenoage_nhanes(biomarkers=c("albumin_gL","alp","lncrp","totchol","lncreat_umol","hba1c","sbp","bun","uap","lymph","mcv","wbc"))

#assemble NHANES IV dataset with projected biological aging measures for analysis
data = merge(hd$data, kdm$data) %>% merge(., phenoage$data)

#select biological age variables
agevar = c("kdm0","phenoage0","kdm","phenoage","hd","hd_log")

#prepare labels
label = c("KDM\nBiological Age",
          "Levine\nPhenotypic Age",
          "Modified-KDM\nBiological Age",
          "Modified-Levine\nPhenotypic Age",
          "Homeostatic\nDysregulation",
          "Log\nHomeostatic\nDysregulation")

#plot age vs bioage
plot_ba(data, agevar, label)

#select biological age variables
agevar = c("kdm_advance0","phenoage_advance0","kdm_advance","phenoage_advance","hd","hd_log")

#prepare lables
#values should be formatted for displaying along diagonal of the plot
#names should be used to match variables and order is preserved
label = c(
  "kdm_advance0"="KDM\nBiological Age\nAdvancement",
  "phenoage_advance0"="Levine\nPhenotypic Age\nAdvancement",
  "kdm_advance"="Modified-KDM\nBiological Age\nAdvancement",
  "phenoage_advance"="Modified-Levine\nPhenotypic Age\nAdvancement",
  "hd" = "Homeostatic\nDysregulation",
  "hd_log" = "Log\nHomeostatic\nDysregulation")

#use variable name to define the axis type ("int" or "float")
axis_type = c(
  "kdm_advance0"="float",
  "phenoage_advance0"="float",
  "kdm_advance"="float",
  "phenoage_advance"="flot",
  "hd"="flot",
  "hd_log"="float")

#plot BAA corplot
plot_baa(data,agevar,label,axis_type)

table_surv(data, agevar, label)

table2 = table_health(data,agevar,outcome = c("health","adl","lnwalk","grip_scaled"), label)

#pull table
table2$table
#pull sample sizes
table2$n

table3 = table_ses(data,agevar,exposure = c("edu","annual_income","poverty_ratio"), label)

#pull table
table3$table
#pull sample sizes
table3$n

#The CALERIE dataset is loaded from my local drive that has previously been downloaded and cleaned
#projecting HD into the CALERIE using NHANES III (seperate training for gender)
load("NHANES3_CLEAN.rda")
load("NHANES4.rda")
CALERIE<-NHANES4
hd_fem = hd_calc(data = CALERIE %>%
                   filter(gender == 2)%>%
                   mutate(lncrp = log(crp)),
                 reference = NHANES3_CLEAN %>%
                   filter(gender == 2)%>%
                   mutate(lncrp = log(crp)),
                 biomarkers=c("albumin","alp","lncrp","totchol","lncreat","hba1c","sbp","bun","uap","lymph","mcv","wbc"))

hd_male = hd_calc(data = CALERIE %>%
                    filter(gender == 1)%>%
                    mutate(lncrp = log(crp)),
                  reference = NHANES3_CLEAN %>%
                    filter(gender == 1)%>%
                    mutate(lncrp = log(crp)),
                  biomarkers=c("albumin","alp","lncrp","totchol","lncreat","hba1c","sbp","bun","uap","lymph","mcv","wbc"))

#pull the HD dataset
hd_data = rbind(hd_fem$data, hd_male$data)

#projecting KDM bioage into the CALERIE using NHANES III (seperate training for gender)
kdm_fem = kdm_calc(data = CALERIE %>%
                     filter (gender ==2),
                   biomarkers=c("albumin","alp","lncrp","totchol","lncreat","hba1c","sbp","bun","uap","lymph","mcv","wbc"),
                   fit = kdm$fit$female,
                   s_ba2 = kdm$fit$female$s_b2)

kdm_male = kdm_calc(data = CALERIE %>%
                      filter (gender ==1),
                    biomarkers=c("albumin","alp","lncrp","totchol","lncreat","hba1c","sbp","bun","uap","lymph","mcv","wbc"),
                    fit = kdm$fit$male,
                    s_ba2 = kdm$fit$male$s_b2)

#pull the KDM dataset
kdm_data = rbind(kdm_fem$data, kdm_male$data)

phenoage_CALERIE = phenoage_calc(data = CALERIE,
                                 biomarkers = c("albumin_gL","alp","lncrp","totchol","lncreat_umol","hba1c","sbp","bun","uap","lymph","mcv","wbc"),
                                 fit = phenoage$fit)

phenoage_data = phenoage_CALERIE$data

#pull the full dataset
newdata = left_join(CALERIE, hd_data[, c("sampleID", "hd", "hd_log")], by = "sampleID") %>%
  left_join(., kdm_data[, c("sampleID", "kdm", "kdm_advance")], by = "sampleID") %>%
  left_join(., phenoage_data[, c("sampleID","phenoage","phenoage_advance")], by = "sampleID") 

summary(newdata %>% filter(fu==0) %>% select(kdm, phenoage, hd, hd_log)) 

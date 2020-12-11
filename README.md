# How is diabetes readmission rate related to patients’ pathologic conditions and medications?

## Overview
This project aims to explore the best diabetes readmission rate predictors (“readmitted” variable in the dataset which derives from UCI Machine Learning Repository ). The analysis of the variable effect will manifest the rudimentary information of patients, medications and laboratory tests taken during the diabetic encounter to identify patients with worse treatment outcomes and make them targeted to interventions to improve their outcomes and reduce costs by fewer readmission.

## Main process
* Constructed several GLMs and GLMMs and chose the one with the best predictability, relatively good inferences and scalability
* Explored the best diabetes readmission rate predictors (“readmitted”)
* Analyzed the rudimentary information of patients, medications and laboratory tests taken during the diabetic encounter to identify patients with worse treatment outcomes and made them targeted to interventions to improve their outcomes and reduce costs by fewer readmission
* Performed diagnostic check
* Interpreted the final model and discussed limitations and potentials 

## Interpretation and significance of the final model
More length of stay has positive effect on readmission rates since patients staying longer in hospital are usually severe cases which may have more chance to be readmitted. And the history of admission into emergency department are usually associated with readmission since it represents a severe degree of diabetes . In addition, t 1 he type and number of medications could also affect the readmission rate since patients taking more various medications may have complications and need multiple treatments2.

## Analysis limitations and potential
As discussed before, this model do not have a good fit compared with others, probably due to multicollinearity between variables or large number of levels of some predictors or the incorrect relationship between outcomes and predictors. None of the work to check the multicollinearity, reduce levels and change the relationship to log, exponential and square root produced a model with a significantly better fit. But since we only fit GLM and GLMM in this case, there might be other models that can fit well. Moreover, many patients do not provide information on some variables (NA), so the model might include different predictors compared with the idealized model.The failure of performing calibration plot of cross validation of GLMM might result in the uncertainty of prediction ability of the final model to some extent. However, the good predictability of hospital readmission rate based on AUC, decile plot and MPE might contribute to this model employment in preliminary diabetes studies regarding to readmission rates.

## References
1. Canadian Institute for Health Information, All-Cause Readmission to Acute Care and Return to the Emergency Department (Ottawa, Ont.: CIHI, 2012).
2. Wei, N J et al. “Intensification of diabetes medication and risk for 30-day readmission.” Diabetic medicine : a journal of the British Diabetic Association vol. 30,2 (2013): e56-62. doi:10.1111/dme.12061.

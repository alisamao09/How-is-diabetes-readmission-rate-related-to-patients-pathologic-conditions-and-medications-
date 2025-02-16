---
title: "Untitled"
output: html_document
editor_options: 
  chunk_output_type: inline
---


# Load and clean dataset
dat<-read.csv("diabetes.csv")
dat1<-dat[,-c(1,7,12,49)]
library(tidyverse)
dat1 <- as.data.frame(dat1 %>%
group_by(patient_nbr) %>% filter(row_number()==1) )
dat1$readmitted<-ifelse(dat1$readmitted=="NO", 0, 1)
nrow(dat1)
length(unique(dat1$patient_nbr))
dat1<-na.omit(dat1)
dat1<-dat1%>% filter(dat1$gender!="Unknown/Invalid")

dat$readmitted<-ifelse(dat$readmitted=="NO", 0, 1)
dat %>% ggplot(aes(x=jitter(number_emergency),y=jitter(readmitted,0.1))) + geom_point() +
labs(x="number_emergency", y="readmitted")

set.seed(1003928039)
train <- dat1[sample(nrow(dat1), size = 20000),]
nrow(train)
test <- dat1[!dat1$patient_nbr %in% train$patient_nbr,]
nrow(test)

# Fit a glm with all predictors at first
model<-glm(readmitted~.,data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)],family = binomial(link="logit"))

# Chi-square test between predictors
chisq.test(train$readmitted,train$race)

# Variable selections
#AIC
lmodred<-step(model, trace=0)
summary(lmodred)
lmodredfor<-step(model, trace=0,direction="forward")
summary(lmodredfor) #full
lmodredback<-step(model, trace=0,direction="backward")
summary(lmodredback) #same aic

# Mutate properties of the training dataset
library(tidyverse)
train <- mutate(train, predprob=predict(lmodred,type='response'),linpred=predict(lmodred))
gdfbic <- group_by(train, ntile(linpred,100))
hldfbic<-summarise(gdfbic,y=sum(readmitted=="1"),ppred=mean(predprob),count=n())
hldfbic<-mutate(hldfbic,se.fit=sqrt(ppred*(1-ppred)/count))
hlstatbic <- with(hldfbic, sum((y-count*ppred)^2/(count*ppred*(1-ppred))))
1-pchisq(hlstatbic,100-2)

#Prediction AIC, cross validation
library(rms)
lrm.final <- lrm(readmitted ~ race + gender + age + admission_type_id + discharge_disposition_id + Length.of.Stay + medical_specialty + num_procedures + number_outpatient + number_emergency + number_inpatient + number_diagnoses + metformin + repaglinide + nateglinide + glipizide + pioglitazone + rosiglitazone + acarbose + diabetesMed, data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)],  x =TRUE, y = TRUE, model= T)
cross.calib<-calibrate(lrm.final, method="crossvalidation", B=10) # model calibration
par(family = 'serif')
plot(cross.calib, las=1, xlab = "Predicted Probability")

# AUC
p <- fitted(lmodred)
roc_logit2 <- roc(train$readmitted~ p)
TPR2 <- roc_logit2$sensitivities
FPR2 <- 1 - roc_logit2$specificities
plot(FPR2, TPR2, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit2),2)))

# predicted vs observed
lmodred$xlevels[["medical_specialty"]] <- union(lmodred$xlevels[["medical_specialty"]], levels(test$medical_specialty))
model.matrix(lmodred)
lmodred$xlevels[["nateglinide"]] <- union(lmodred$xlevels[["nateglinide"]], levels(test$nateglinide))
test$pred.prob <- predict(lmodred, newdata = test, type = "response")
deciles <-  quantile(test$pred.prob, probs = seq(0,1, by =0.1))
test$decile <- findInterval(test$pred.prob, deciles, rightmost.closed = T)
pred.prob <- tapply(test$pred.prob, test$decile, mean)
obs.prob <- tapply(as.numeric(test$readmitted)-1, test$decile, mean)## The plot ##
par(family = 'serif')
plot(pred.prob, obs.prob, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

#MPE
pred.y <- predict(lmodred, newdata = test, type = "response")
mean((test$readmitted - pred.y)^2)

# Diagnostics
resid = residuals(lmodred)
gdf <- group_by(train, ntile(predict(lmodred),100))
diagdf<-summarise(gdf,residuals=mean(residuals(lmodred)),
linpred=mean(predict(lmodred)),
predprob=mean(predict(lmodred,type='response')))
plot(resid~predict(lmodred),diagdf,xlab='Linear Predictor',ylab='Deviance Residuals',pch=20)
plot(residuals~predprob,diagdf,
xlab='Fitted Values',ylab='Deviance Residuals',pch=20)

plot(residuals(lmodred)~ predict(lmodred,type="link"),
xlab=expression(hat(eta)),ylab="Deviance residuals")


plot(lmodred,which=1)
fitted = fitted(modpql)
plot(fitted,resid)
#qq plot
qqnorm(residuals)
qqline(residuals)

diagd <- tibble(residuals, fitted = fitted(lmodred))
plot1 <- diagd %>% ggplot(aes(sample=residuals)) + stat_qq()
plot2 <- diagd %>% ggplot(aes(x=fitted,y=residuals)) + geom_point(alpha=0.3) +geom_hline(yintercept=0) + labs(x="Fitted", y="Residuals")
plot1
plot2
library(faraway)
halfnorm(residuals(lmodred))


#AICsig model
modelaicsig <- glm(readmitted ~ race+gender+admission_type_id +Length.of.Stay+num_procedures+number_outpatient+number_emergency +number_inpatient+number_diagnoses+diabetesMed+insulin, family = binomial(link="logit"), data = train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)])
summary(modelaicsig)

# training dataset
train <- mutate(train, predprob=predict(modelaicsig,type='response'),linpred=predict(modelaicsig))
gdfbic <- group_by(train, ntile(linpred,100))
hldfbic<-summarise(gdfbic,y=sum(readmitted=="1"),ppred=mean(predprob),count=n())
hldfbic<-mutate(hldfbic,se.fit=sqrt(ppred*(1-ppred)/count))
hlstatbic <- with(hldfbic, sum((y-count*ppred)^2/(count*ppred*(1-ppred))))
1-pchisq(hlstatbic,100-2)

# Cross validation
lrm.finalaicsig <- lrm(readmitted ~ race+gender+admission_type_id +Length.of.Stay+num_procedures+number_outpatient+number_emergency +number_inpatient+number_diagnoses+diabetesMed, data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)],  x =TRUE, y = TRUE, model= T)
cross.calibaicsig <- calibrate(lrm.finalaicsig, method="crossvalidation", B=10) # model calibration
par(family = 'serif')
plot(cross.calibaicsig, las=1, xlab = "Predicted Probability")

#AUC
paicsig <- fitted(modelaicsig)
roc_logit2aicsig <- roc(train$readmitted~ paicsig)
TPR2aicsig <- roc_logit2aicsig$sensitivities
FPR2aicsig <- 1 - roc_logit2aicsig$specificities
plot(FPR2aicsig, TPR2aicsig, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit2aicsig),2)))

#Predicted vs observed
modelaicsig$xlevels[["medical_specialty"]] <- union(modelaicsig$xlevels[["medical_specialty"]], levels(test$medical_specialty))
modelaicsig$xlevels[["nateglinide"]] <- union(modelaicsig$xlevels[["nateglinide"]], levels(test$nateglinide))
test$pred.probaicsig <- predict(modelaicsig, newdata = test, type = "response")
decilesaicsig <-  quantile(test$pred.probaicsig, probs = seq(0,1, by =0.1))
test$decileaicsig <- findInterval(test$pred.probaicsig, decilesaicsig, rightmost.closed = T)
pred.probaicsig <- tapply(test$pred.probaicsig, test$decileaicsig, mean)
obs.probaicsig <- tapply(as.numeric(test$readmitted)-1, test$decileaicsig, mean)## The plot ##
par(family = 'serif')
plot(pred.probaicsig, obs.probaicsig, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

#MPE
pred.ysig <- predict(modelaicsig, newdata = test, type = "response")
mean((test$readmitted - pred.ysig)^2)

#Diagnostics
residsig = residuals(modelaicsig)
gdfsig <- group_by(train, ntile(predict(modelaicsig),100))
diagdfsig<-summarise(gdfsig,residuals=mean(residuals(modelaicsig)),
linpredsig=mean(predict(modelaicsig)),
predprobsig=mean(predict(modelaicsig,type='response')))
plot(residsig~predict(modelaicsig),diagdfsig,xlab='Linear Predictor',ylab='Deviance Residuals',pch=20)
plot(residsig~predict(modelaicsig,type='response'),diagdfsig,
xlab='Fitted Values',ylab='Deviance Residuals',pch=20)

plot(residuals(lmodred)~ predict(lmodred,type="link"),
xlab=expression(hat(eta)),ylab="Deviance residuals")

plot(residuals(lmodred)~ predict(lmodred,type="response"),
xlab=expression(hat(mu)),ylab="Deviance residuals")

plot(modelaicsig,which=1)
fitted = fitted(modpql)
plot(fitted,resid)
#qq plot
qqnorm(residsig)
qqline(residsig)

diagd <- tibble(residuals, fitted = fitted(lmodred))
plot1 <- diagd %>% ggplot(aes(sample=residuals)) + stat_qq()
plot2 <- diagd %>% ggplot(aes(x=fitted,y=residuals)) + geom_point(alpha=0.3) +geom_hline(yintercept=0) + labs(x="Fitted", y="Residuals")
plot1
plot2
library(faraway)
halfnorm(residuals(lmodred))

#BIC variable selection
lmod<-step(model, trace=0,k=log(20000))
summary(lmod) 
lmodfor<-step(model, trace=0,k=log(20000),direction="forward")
summary(lmodfor) #full
lmodback<-step(model, trace=0,k=log(20000),direction="backward")
summary(lmodback) #same as bic

#train
train <- mutate(train, predprob=predict(lmod,type='response'),linpred=predict(lmod))
gdfbic <- group_by(train, ntile(linpred,100))
hldfbic<-summarise(gdfbic,y=sum(readmitted=="1"),ppred=mean(predprob),count=n())
hldfbic<-mutate(hldfbic,se.fit=sqrt(ppred*(1-ppred)/count))
hlstatbic <- with(hldfbic, sum((y-count*ppred)^2/(count*ppred*(1-ppred))))
1-pchisq(hlstatbic,100-2)


#Prediction BIC
library(rms)
lrm.finalbic <- lrm(readmitted ~ admission_type_id + Length.of.Stay + num_procedures + num_medications + number_outpatient + number_emergency + number_inpatient + number_diagnoses + diabetesMed, data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)],  x =TRUE, y = TRUE, model= T)
cross.calibbic <- calibrate(lrm.finalbic, method="crossvalidation", B=10) # model calibration
par(family = 'serif')
plot(cross.calibbic, las=1, xlab = "Predicted Probability")

#AUC
p1 <- fitted(lmod)
roc_logit21 <- roc(train$readmitted~ p1)
TPR21 <- roc_logit21$sensitivities
FPR21 <- 1 - roc_logit21$specificities
plot(FPR21, TPR21, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit21),2)))

#Predicted vs observed
lmod$xlevels[["medical_specialty"]] <- union(lmod$xlevels[["medical_specialty"]], levels(test$medical_specialty))
lmod$xlevels[["nateglinide"]] <- union(lmod$xlevels[["nateglinide"]], levels(test$nateglinide))
test$pred.prob1 <- predict(lmod, newdata = test, type = "response")
deciles1 <-  quantile(test$pred.prob1, probs = seq(0,1, by =0.1))
test$decile1 <- findInterval(test$pred.prob1, deciles1, rightmost.closed = T)
pred.prob1 <- tapply(test$pred.prob1, test$decile1, mean)
obs.prob1 <- tapply(as.numeric(test$readmitted)-1, test$decile1, mean)## The plot ##
par(family = 'serif')
plot(pred.prob1, obs.prob1, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

pred.y1 <- predict(lmod, newdata = test, type = "response")
## Prediction error ##
mean((test$readmitted - pred.y1)^2)

#Diag
linpred<-predict(lmod,newdata=test,allow.new.levels = TRUE)
residuals<- residuals(lmod)
train <- mutate(train,residuals=residuals(lmod),linpred=predict(lmod),predprob=predict(lmod,type='response'))
gdbicf <- group_by(train, ntile(linpred,100))
diagdfbic<-summarise(gdbicf,residuals=mean(residuals),
                         linpred=mean(linpred),
                         predprob=mean(predprob))
plot(residuals~linpred,diagdfbic,xlab='Linear Predictor',ylab='Deviance Residuals',pch=20)
plot(residuals~predprob,diagdfbic,
xlab='Fitted Values',ylab='Deviance Residuals',pch=20)


#qq plot

diagdmmodbic <- tibble(residmmodbic, fitted = fitted(mmodbic))
plot1mmodbic <- diagdmmodbic %>% ggplot(aes(sample=residmmodbic)) + stat_qq()
plot2mmodbic <- diagdmmodbic %>% ggplot(aes(x=fitted,y=residmmodbic)) + geom_point(alpha=0.3) +geom_hline(yintercept=0) + labs(x="Fitted", y="Residuals")
plot1mmodbic
plot2mmodbic
library(faraway)
halfnorm(residuals(mmodbic))

group_by(train, Length.of.Stay  ) %>%
summarise(residuals=mean(residuals), count=n()) %>%
ggplot(aes(x= Length.of.Stay ,y=residuals,size=sqrt(count))) +  geom_point()

#LASSO model
cv.out <- cv.glmnet(x = model.matrix( ~ ., data = train[, -c(1,2,8,25,28,33,35,36,39,40,41,42,45)]), 
                    y = train$readmitted, standardize = T, alpha = 0.5)

best.lambda <- cv.out$lambda.1se
best.lambda
co<-coef(cv.out, s = "lambda.1se")
thresh <- 0.00

# select variables #
inds<-which(abs(co) > thresh )
variables<-row.names(co)[inds]
sel.var.lasso<-variables[!(variables %in% '(Intercept)')]
sel.var.lasso
modellasso<-glm(readmitted ~ race+ gender+ age+ admission_type_id+ Length.of.Stay+ medical_specialty+ num_procedures+ number_outpatient+ number_emergency+ number_inpatient+ number_diagnoses+ max_glu_serum+ metformin+ repaglinide+ pioglitazone+ acarbose+ change+diabetesMed, data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)])
summary(modellasso)

#train
train <- mutate(train, predprob=predict(modellasso,type='response'),linpred=predict(modellasso))
gdfbic <- group_by(train, ntile(linpred,100))
hldfbic<-summarise(gdfbic,y=sum(readmitted=="1"),ppred=mean(predprob),count=n())
hldfbic<-mutate(hldfbic,se.fit=sqrt(ppred*(1-ppred)/count))
hlstatbic <- with(hldfbic, sum((y-count*ppred)^2/(count*ppred*(1-ppred))))
1-pchisq(hlstatbic,100-2)

#cross validation
lrm.finallasso <- lrm(readmitted ~ race+ gender+ age+ admission_type_id+ Length.of.Stay+ medical_specialty+ num_procedures+ number_outpatient+ number_emergency+ number_inpatient+ number_diagnoses+ max_glu_serum+ metformin+ repaglinide+ pioglitazone+ acarbose+ change+diabetesMed, data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)],  x =TRUE, y = TRUE, model= T)
cross.caliblasso <- calibrate(lrm.finallasso, method="crossvalidation", B=10) # model calibration
par(family = 'serif')
plot(cross.caliblasso, las=1, xlab = "Predicted Probability")

#AUC
library(pROC)
plasso <- fitted(modellasso)
roc_logit2lasso <- roc(train$readmitted~ plasso)
TPR2lasso <- roc_logit2lasso$sensitivities
FPR2lasso <- 1 - roc_logit2lasso$specificities
plot(FPR2lasso, TPR2lasso, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit21),2)))

#Predicted vs observed
modellasso$xlevels[["medical_specialty"]] <- union(modellasso$xlevels[["medical_specialty"]], levels(test$medical_specialty))
modellasso$xlevels[["nateglinide"]] <- union(modellasso$xlevels[["nateglinide"]], levels(test$nateglinide))
test$pred.problasso <- predict(modellasso, newdata = test, type = "response")
decileslasso <-  quantile(test$pred.problasso, probs = seq(0,1, by =0.1))
test$decilelasso <- findInterval(test$pred.problasso, decileslasso, rightmost.closed = T)
pred.problasso <- tapply(test$pred.problasso, test$decilelasso, mean)
obs.problasso <- tapply(as.numeric(test$readmitted)-1, test$decilelasso, mean)## The plot ##
par(family = 'serif')
plot(pred.problasso, obs.problasso, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

pred.ylasso <- predict(modellasso, newdata = test, type = "response")
## Prediction error ##
mean((test$readmitted - pred.ylasso)^2)

# LASSO sig model
modellassosig<-glm(readmitted ~ race+ gender+admission_type_id+ Length.of.Stay+  num_procedures+ number_outpatient+ number_emergency+ number_inpatient+ number_diagnoses+diabetesMed, data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)])
summary(modellassosig)

#train
train <- mutate(train, predprob=predict(modellassosig,type='response'),linpred=predict(modellassosig))
gdfbic <- group_by(train, ntile(linpred,100))
hldfbic<-summarise(gdfbic,y=sum(readmitted=="1"),ppred=mean(predprob),count=n())
hldfbic<-mutate(hldfbic,se.fit=sqrt(ppred*(1-ppred)/count))
hlstatbic <- with(hldfbic, sum((y-count*ppred)^2/(count*ppred*(1-ppred))))
1-pchisq(hlstatbic,100-2)

# cross validation
lrm.finallassosig <- lrm(readmitted ~ race+ gender+admission_type_id+ Length.of.Stay+  num_procedures+ number_outpatient+ number_emergency+ number_inpatient+ number_diagnoses+diabetesMed, data=train[, -c(1,2,8,25,28,33,35,36,39,40,41,42)],  x =TRUE, y = TRUE, model= T)
cross.caliblassosig <- calibrate(lrm.finallassosig, method="crossvalidation", B=10) # model calibration
par(family = 'serif')
plot(cross.caliblassosig, las=1, xlab = "Predicted Probability")

# AUC
library(pROC)
plassosig <- fitted(modellassosig)
roc_logit2lassosig <- roc(train$readmitted~ plassosig)
TPR2lassosig <- roc_logit2lassosig$sensitivities
FPR2lassosig <- 1 - roc_logit2lassosig$specificities
plot(FPR2lassosig, TPR2lassosig, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit2lassosig),2)))

#Predicted vs observed
modellassosig$xlevels[["medical_specialty"]] <- union(modellassosig$xlevels[["medical_specialty"]], levels(test$medical_specialty))
modellassosig$xlevels[["nateglinide"]] <- union(modellassosig$xlevels[["nateglinide"]], levels(test$nateglinide))
test$pred.problassosig <- predict(modellassosig, newdata = test, type = "response")
decileslassosig <-  quantile(test$pred.problassosig, probs = seq(0,1, by =0.1))
test$decilelassosig <- findInterval(test$pred.problassosig, decileslassosig, rightmost.closed = T)
pred.problassosig <- tapply(test$pred.problassosig, test$decilelassosig, mean)
obs.problassosig <- tapply(as.numeric(test$readmitted)-1, test$decilelassosig, mean)## The plot ##
par(family = 'serif')
plot(pred.problassosig, obs.problassosig, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

pred.ylassosig <- predict(modellassosig, newdata = test, type = "response")
## Prediction error ##
mean((test$readmitted - pred.ylassosig)^2)

anova(modellasso, lmodred, test='Chi')
anova(modellasso, lmodred,test='LRT')

#GLMM BIC model
# clean and organize dataset
library(lme4)
dat2<-dat[,-c(1,7,12,49)]
dat2$readmitted<-ifelse(dat2$readmitted=="NO", 0, 1)
nrow(dat2)
length(unique(dat2$patient_nbr))
dat2<-na.omit(dat2)
library(dplyr)
dat2<-dat2%>% filter(dat2$gender!="Unknown/Invalid")
set.seed(1003928039)
ids <- sample(unique(dat2$patient_nbr), 20000)
train1<-as.data.frame(dat2[dat2$patient_nbr%in% ids, ])
nrow(dat2)
nrow(train1)
test1 <- dat2[!dat2$patient_nbr %in% train1$patient_nbr,]
nrow(test1)

#fit
mmodbic <- lmer(readmitted~admission_type_id + Length.of.Stay + num_procedures + num_medications + number_outpatient + number_emergency + number_inpatient + number_diagnoses + diabetesMed+(1|patient_nbr),  data = train1[, -c(25,28,33,35,36,39,40,41,42)])
summary(mmodbic)
confint(mmodbic, method='boot')
anova(mmodbic,test="F")
library(RLRsim)
exactRLRT(mmodbic)
ranef(mmodbic)$patient_nbr

#prediction 
library(pROC)
p1lmm <- fitted(mmodbic)
roc_logit2lmm <- roc(train1$readmitted~ p1lmm)
TPR2lmm <- roc_logit2lmm$sensitivities
FPR2lmm <- 1 - roc_logit2lmm$specificities
plot(FPR2lmm, TPR2lmm, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit2lmm),2)))

#Predicted vs observed
test1$pred.prob1lmm <- predict(scale, newdata = test1, type = "response",allow.new.levels = TRUE)
deciles1lmm <-  quantile(test1$pred.prob1lmm, probs = seq(0,1, by =0.1))
test1$decile1lmm <- findInterval(test1$pred.prob1lmm, deciles1lmm, rightmost.closed = T)
pred.prob1lmm <- tapply(test1$pred.prob1lmm, test1$decile1lmm, mean)
obs.prob1lmm <- tapply(as.numeric(test1$readmitted)-1, test1$decile1lmm, mean)## The plot ##
par(family = 'serif')
plot(pred.prob1lmm, obs.prob1lmm, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

pred.ybicglmm <- predict(scale, newdata = test1, type = "response",allow.new.levels = TRUE)
## Prediction error ##
mean((test1$readmitted - pred.ybicglmm)^2)

# Diagnostics
linpred<-predict(mmodbic,newdata=test1,allow.new.levels = TRUE)
residuals<- residuals(mmodbic)
train1 <- mutate(train1,residuals=residuals(mmodbic),linpred=predict(mmodbic),predprob=predict(mmodbic,type='response'))
gdmmodbicf <- group_by(train1, ntile(linpred,100))
diagdfmmodbic<-summarise(gdmmodbicf,residuals=mean(residuals),
                         linpred=mean(linpred),
                         predprob=mean(predprob))
plot(residuals~linpred,diagdfmmodbic,xlab='Linear Predictor',ylab='Deviance Residuals',pch=20)
plot(residuals~predprob,diagdfmmodbic,
xlab='Fitted Values',ylab='Deviance Residuals',pch=20)


#qq plot

library(faraway)
halfnorm(residuals,resType='pearson')

library(tidyverse)

# try to transform variables
group_by(train1, diabetesMed) %>%
summarise(residuals=mean(residuals), count=n()) %>%
ggplot(aes(x= diabetesMed ,y=residuals,size=sqrt(count))) +  geom_point()

scale<-lmer(readmitted ~ admission_type_id + Length.of.Stay + num_procedures + num_medications + number_outpatient + number_emergency + number_inpatient + number_diagnoses + diabetesMed+(1|patient_nbr),  data = test1[, -c(25,28,33,35,36,39,40,41,42)])
summary(scale)
library(pROC)
p1lmm <- fitted(scale)
roc_logit2lmm <- roc(test1$readmitted~ p1lmm)
TPR2lmm <- roc_logit2lmm$sensitivities
FPR2lmm <- 1 - roc_logit2lmm$specificities
plot(FPR2lmm, TPR2lmm, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit2lmm),2)))

test1$pred.prob1lmm <- predict(mmodbic, newdata = test1, type = "response",allow.new.levels = TRUE)
deciles1lmm <-  quantile(test1$pred.prob1lmm, probs = seq(0,1, by =0.1))
test1$decile1lmm <- findInterval(test1$pred.prob1lmm, deciles1lmm, rightmost.closed = T)
pred.prob1lmm <- tapply(test1$pred.prob1lmm, test1$decile1lmm, mean)
obs.prob1lmm <- tapply(as.numeric(test1$readmitted)-1, test1$decile1lmm, mean)## The plot ##
par(family = 'serif')
plot(pred.prob1lmm, obs.prob1lmm, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

pred.ybicglmm <- predict(mmodbic, newdata = test1, type = "response",allow.new.levels = TRUE)
## Prediction error ##
mean((test1$readmitted - pred.ybicglmm)^2)

#AICSIG model
mmodaicsig <- lmer(readmitted~race+gender+admission_type_id   +Length.of.Stay+num_procedures+number_outpatient+number_emergency +number_inpatient+number_diagnoses+diabetesMed+insulin + (1|patient_nbr), data = train1[, -c(25,28,33,35,36,39,40,41,42)])
summary(mmodaicsig)
#AUC
p1aiclmm <- fitted(mmodaicsig)
roc_logit2lmmaic <- roc(train1$readmitted~ p1aiclmm)
TPR2lmmaic <- roc_logit2lmmaic$sensitivities
FPR2lmmaic <- 1 - roc_logit2lmmaic$specificities
plot(FPR2lmmaic, TPR2lmmaic, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit2lmmaic),2)))

#Predicted vs observed
test1$pred.prob1lmmaic <- predict(mmodaicsig, newdata = test1, type = "response",allow.new.levels = TRUE)
deciles1lmmaic <-  quantile(test1$pred.prob1lmmaic, probs = seq(0,1, by =0.1))
test1$decile1lmmaic <- findInterval(test1$pred.prob1lmmaic, deciles1lmmaic, rightmost.closed = T)
pred.prob1lmmaic <- tapply(test1$pred.prob1lmmaic, test1$decile1lmmaic, mean)
obs.prob1lmmaic <- tapply(as.numeric(test1$readmitted)-1, test1$decile1lmmaic, mean)## The plot ##
par(family = 'serif')
plot(pred.prob1lmmaic, obs.prob1lmmaic, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

pred.ybicglmmaic <- predict(mmodaicsig, newdata = test1, type = "response",allow.new.levels = TRUE)
## Prediction error ##
mean((test1$readmitted - pred.ybicglmmaic)^2)

#LASSO SIG
library(lme4)
mmodlassosig <- lmer(readmitted~race+gender+admission_type_id   +Length.of.Stay+num_procedures+number_outpatient+number_emergency +number_inpatient+number_diagnoses+diabetesMed+(1|patient_nbr), data = train1[, -c(25,28,33,35,36,39,40,41,42)])
summary(mmodlassosig)

#AUC
p1lassosig <- fitted(mmodlassosig)
roc_logit2lassosig <- roc(train1$readmitted~ p1lassosig)
TPR2lassosig <- roc_logit2lassosig$sensitivities
FPR2lassosig <- 1 - roc_logit2lassosig$specificities
plot(FPR2lassosig, TPR2lassosig, xlim = c(0,1), ylim = c(0,1), type = 'l', lty = 1, lwd = 2,col = 'red', bty = "n")
abline(a = 0, b = 1, lty = 2, col = 'blue')
text(0.7,0.4,label = paste("AUC = ", round(auc(roc_logit2lassosig),2)))

#Predicted vs observed
test1$pred.prob1lassosig <- predict(mmodlassosig, newdata = test1, type = "response",allow.new.levels = TRUE)
deciles1lassosig <-  quantile(test1$pred.prob1lassosig, probs = seq(0,1, by =0.1))
test1$decile1lassosig <- findInterval(test1$pred.prob1lassosig, deciles1lassosig, rightmost.closed = T)
pred.prob1lassosig <- tapply(test1$pred.prob1lassosig, test1$decile1lassosig, mean)
obs.prob1lassosig <- tapply(as.numeric(test1$readmitted)-1, test1$decile1lassosig, mean)## The plot ##
par(family = 'serif')
plot(pred.prob1lassosig, obs.prob1lassosig, type = "l", ylab = "Observed",xlab = "Predicted", xlim = c(0,1), ylim = c(-1,1))
abline(a=0, b=1)

pred.ybicglassosig<- predict(mmodlassosig, newdata = test1, type = "response",allow.new.levels = TRUE)
## Prediction error ##
mean((test1$readmitted - pred.ybicglassosig)^2)

library(RLRsim)
library(pbkrtest)
exactRLRT(mmodbic)  
KRmodcomp(mmodlassosig, mmodaicsig) #fixed effect
anova(mmodbic, mmodlassosig)
```





#!/usr/bin/env Rscript

file <- args[1]
outpath<- args[2]
ext<- args[3]
qval <- args[4]

extension<-paste0(".",ext)
splitpath=strsplit(file,"/")
samplename=gsub(extension,"",splitpath[[1]][length(splitpath[[1]])])

tb<-read.table(file)

qtb<-subset(tb,tb$V9>=-log10(qval))
name.qtb<-paste0(samplename,"_qval_",qval,extension)
write.table(qtb, paste0(outpath,"/",name.qtb),col.names = FALSE, row.names = FALSE, quote= FALSE)


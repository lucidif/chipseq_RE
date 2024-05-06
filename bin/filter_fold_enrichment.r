#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

file <- args[1]
outpath<- args[2]

#file<-"/mnt/datawk1/analysis/Lara/test_chipseq_dowstream/nfout/narrow_0_1/star/mergedLibrary/macs2/narrowPeak/Anti-GFP.mLb.mkD.sorted_peaks.narrowPeak"
#outpath<-"/mnt/datawk1/analysis/Lara/test_chipseq_dowstream/nfout/narrow_0_1/star/mergedLibrary/macs2/narrowPeak/"


splitpath=strsplit(file,"/")
samplename=gsub(".narrowPeak","",splitpath[[1]][length(splitpath[[1]])])

tb<-read.table(file)

#peak value

summ<-summary(tb$V7)

quant1<-summ[2]
mean<-summ[4]
quant3<-summ[5]

q3tb<-subset(tb,tb$V7>=quant3)
name.q3tb<-paste0(samplename,".quant3_",round(quant3,0),".narrowPeak")
write.table(q3tb, paste0(outpath,"/",name.q3tb),col.names = FALSE, row.names = FALSE, quote= FALSE)

meantb<-subset(tb,tb$V7>=mean)
name.mean<-paste0(samplename,".mean_",round(mean,0),".narrowPeak")
write.table(meantb, paste0(outpath,"/",name.mean),col.names = FALSE, row.names = FALSE, quote= FALSE)

q1tb<-subset(tb,tb$V7>=quant1)
name.q1tb<-paste0(samplename,".quant1_",round(quant1,0),".narrowPeak")
write.table(q1tb, paste0(outpath,"/",name.q1tb),col.names = FALSE, row.names = FALSE, quote= FALSE)

nrow(q3tb)
nrow(meantb)
nrow(q1tb)




#qvalue
#summary(10^-(tb$V9))
#nrow(subset(tb,tb$V9>=-log10(9.910e-03)))

#pk<-read.table(peaksfile, header=TRUE)
#summary(pk$fold_enrichment)


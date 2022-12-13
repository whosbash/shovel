#!/bin/bash

# Nomenclature - Convert latex to pdf
pdflatex $1.tex
makeindex $1.nlo -s nomencl.ist -o $1.nls
biber $1
pdflatex $1.tex

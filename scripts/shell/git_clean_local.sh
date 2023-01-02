#!/bin/bash

git branch -v | grep '[gone]'|  grep -v "\*" | awk '{ print $1; }' | xargs -r git branch -d
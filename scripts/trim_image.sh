#!/bin/bash

echo "=========================================================="

# eps to pdf
for f in *; do 
	if [[ ${f: -3} == "eps" ]]
	then
	    epstopdf "$(basename $f .eps).eps" "$(basename $f .eps)-eps-converted-to.pdf"; 
	    echo "File" $f "converted to " "${f/_cropped.pdf/}.pdf";
	fi
done;

echo "=========================================================="

# Crop image
for f in *; do 
	if [[ ${f: -3} == "pdf" ]]
	then
		echo "Margins cropped from " $f
	    pdf-crop-margins -s -u "$(basename $f)"; 
	fi
done

echo "=========================================================="

# Remove "_cropped.pdf"
for f in *; do 
	if [[ ${f: -12} == "_cropped.pdf" ]]
	then    
		mv -- "$f" "${f%_cropped.pdf}.pdf"		
		echo "File" $f "removed!"
	
	fi
done;

echo "=========================================================="

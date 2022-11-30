#!/bin/bash
# Credits to @sputnick-dev: https://github.com/sputnick-dev

function convertDMStoDecimal() {
	echo "$1" | awk -v FS="[ \t]" '{print $0,substr($1,length($1),1)substr($2,length($2),1)}' \
			  | sed 's/\xc2\xb0\([0-9]\{1,2\}\).\([NEWS]\)/ \1 0 \2/g;s/\xc2\xb0\([NEWS]\)/ 0 0 \1/g;s/[^0-9NEWS]/ /g' \
			  | awk '{if ($9=="NE") {printf ("%.4f\t%.4f\n",$1+$2/60+$3/3600,$5+$6/60+$7/3600)} \
					 else if ($9=="NW") {printf ("%.4f\t%.4f\n",$1+$2/60+$3/3600,-($5+$6/60+$7/3600))} \
					 else if ($9=="SE") {printf ("%.4f\t%.4f\n",-($1+$2/60+$3/3600),$5+$6/60+$7/3600)} \
					 else if ($9=="SW") {printf ("%.4f\t%.4f\n",-($1+$2/60+$3/3600),-($5+$6/60+$7/3600))}}' \
			  | xargs
}

function extractGeoCoordinate() {
	fname="city.html"
	URL="https://en.wikipedia.org/wiki/$1"

	xmlstartlet_pattern='(//span[@class="latitude"]/text())[position()=1] | (//span[@class="longitude"]/text())[position()=1]'
	perl_pattern='s|^(\d+)\D+(\d+)\D+(\d+).*|$1+($2/60)+($3/60)/60|e'

	curl -s $URL > "$fname"
	xmlstarlet format -H "$fname" 2>/dev/null | sponge "$fname"
	lat_lng="$(xmlstarlet sel -t -v "$xmlstartlet_pattern" "$fname" | sed 'N;s/\n/ /')"
	rm "$fname"

	echo "$(convertDMStoDecimal "$lat_lng")"
}

extractGeoCoordinate $1






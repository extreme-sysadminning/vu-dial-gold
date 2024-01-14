#!/bin/bash

# Copyright 2024 Karsten Kruse <tecneeq@tecneeq.de> www.tecneeq.de
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS”
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

average_price_paid="1825"            # I bought my gold for this average per ounce, integer
currency="euro"                      # dollar or euro
statedir="$HOME/.vu-dial-gold"       # this is the place where we remember state
scrape_delay="30"                    # rescrape if the last scrape is older than that many minutes
dial_uuid="240043000650564139323920" # the dial to update
dial_apikey="cTpAWYuRpA2zx75Yh961Cg" # the API key to use
dial_apiserver="localhost"
dial_apiport="5340"                  # default is 5340
dial_protocoll="http"                # http or https
dial_selfsigned="false"              # if true, ignore https errors

set -e
set -u

# scrape the current price
if [ $(find "$statedir/scraped_price.txt" -mmin -$scrape_delay | wc -l) -lt 1 ] ; then
  echo -n "Need to scrape: "
  mkdir -pv "$statedir"
  case $currency in
    euro)   scraped_price=$(wget -q -O- https://www.gold.de/ | sed -e 's/<td>/\n/g' -e 's/<\/td>/\n/g' | grep '€/oz' | head -n 1 | sed -e 's/\.//' -e 's/,.*//') ;;
    dollar) scraped_price=$(wget -q -O- https://www.gold.de/ | sed -e 's/<td>/\n/g' -e 's/<\/td>/\n/g' | grep '$/oz' | head -n 1 | sed -e 's/\.//' -e 's/,.*//') ;;
  esac
  echo "scraped_price=$scraped_price" > "$statedir/scraped_price.txt"
else
  echo -n "Reusing previously scraped price: "
  . $statedir/scraped_price.txt
fi
echo "$scraped_price $currency"

# calculate how much % the current price deviates from your average price
percent=$(echo $scraped_price $average_price_paid | awk '{print (($1-$2)/$1*100)}' OFMT='%0.0f')
echo "The average price paid was $average_price_paid $currency, at $scraped_price $currency current price that is a $percent % deviation. I hope it fits to your background."

# make sure you have the right background, if not, set it
if [ -f vu-dial-gold.png ] ; then
  echo -n "Updating image: "
  curl -X POST -F "imgfile=@vu-dial-gold.png" "$dial_protocoll://$dial_apiserver:$dial_apiport/api/v0/dial/$dial_uuid/image/set?key=$dial_apikey&imgfile=vu-dial-gold.png" ; echo
else
  echo "Image vu-dial-gold.png not found, skipping background image update."
fi

# calculate and set the needle position, remember, it goes from 0 to 100:
needleposition=$(echo $scraped_price $average_price_paid 10 | awk '{print ((50/$3)*(($1-$2)/$1*100))+50}' OFMT='%0.0f')
echo -n "Sending needle position: "
wget -q -O- "$dial_protocoll://$dial_apiserver:$dial_apiport/api/v0/dial/$dial_uuid/set?key=$dial_apikey&value=$needleposition" ; echo

# decide and set the color of the VU Dial
echo -n "Sending dial color: "
if (($needleposition<=30)) ; then
  echo -n "deep green, price is below average, buy a lot get to average your position down: "
  dial_color="&red=0&green=100&blue=0"
elif ((31<=$needleposition && $needleposition<=50)) ; then
  echo -n "light green, near average, maybe buy a bit: "
  dial_color="&red=30&green=100&blue=30"
elif ((51<=$needleposition && $needleposition<=65)) ; then
  echo -n "white, do not buy: "
  dial_color="&red=100&green=100&blue=100"
elif ((51<=$needleposition && $needleposition<=70)) ; then
  echo -n "light red, do not buy, maybe take some profit by selling ugly stuffi: "
  dial_color="&red=100&green=30&blue=30"
else
  echo -n "deep red, bad time to buy, take profits now: "
  dial_color="&red=100&green=0&blue=0"
fi
wget -q -O- "$dial_protocoll://$dial_apiserver:$dial_apiport/api/v0/dial/$dial_uuid/backlight?key=$dial_apikey$dial_color" ; echo

# eof

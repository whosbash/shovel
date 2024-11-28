#!/bin/bash
# Download and display a random meme
meme_url=$(curl -s https://meme-api.com/gimme | jq -r '.url')
wget -O /tmp/random_meme.jpg "$meme_url"
xdg-open /tmp/random_meme.jpg
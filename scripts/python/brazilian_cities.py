import requests as req
from bs4 import BeautifulSoup

uri = 'https://en.wikipedia.org/wiki/List_of_municipalities_of_Brazil'
css_query = "#mw-content-text > div.mw-parser-output > table > tbody > tr > td > a"

r = req.get(uri)
soup = BeautifulSoup(r.text,  'html.parser')

texts = []
for el in soup.select(css_query):
  texts.append(el.attrs['href'])
print(texts)
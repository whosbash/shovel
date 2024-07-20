import requests

ip_addresses = [    
    '185.191.126.213',    
    '187.17.152.98',    
    '205.210.31.186',    
    '205.210.31.101',    
    '65.49.1.31',    
    '65.49.1.33',    
    '65.49.1.26',    
    '198.235.24.13',    
    '205.210.31.250',    
    '222.186.13.132',    
    '159.89.144.68',    
    '147.185.132.70',    
    '198.235.24.184',    
    '60.191.125.35',    
    '167.94.146.62',    
    '205.210.31.171',    
    '123.207.248.55',    
    '147.185.132.69',    
    '172.105.128.11',    
    '167.94.145.100',    
    '198.235.24.110',    
    '167.94.145.100',    
    '47.251.72.118',    
    '205.210.31.248',    
    '104.156.155.30',    
    '47.115.214.82',    
    '118.123.105.126'
]

locations = {}
for ip in ip_addresses:
    response = requests.get(f"http://ipinfo.io/{ip}/json")
    
    data = response.json()
    country = data.get('country')
    region = data.get('region')
    city = data.get('city')

    if country in locations:        
        if region in locations[country]:
            if city in locations[country][region]:
                if ip not in locations[country][region][city]:
                    locations[country][region][city].append(ip)
            else:
                locations[country][region][city] = [ip]

        else:
            locations[country][region] = {}
            locations[country][region][city] = [ip]
    else: 
        locations[country] = {}
        locations[country][region] = {}
        locations[country][region][city] = [ip]

    
print(sorted(
    {
        f"{country}, {region}, {city}"
        for country, regions_data in locations.items()
        for region, cities_data in regions_data.items()
        for city, ips in cities_data.items()
    }
))

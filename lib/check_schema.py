import urllib.request
import json

url = "https://jluuobtzylejiahbelgp.supabase.co/rest/v1/product_variants?select=*"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdXVvYnR6eWxlamlhaGJlbGdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3Mjg0NTksImV4cCI6MjA4ODMwNDQ1OX0.ziUtvEdXw3w0yqPpRwk6-rWrIi1qVTKpkZFcxyl7gRE",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdXVvYnR6eWxlamlhaGJlbGdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI3Mjg0NTksImV4cCI6MjA4ODMwNDQ1OX0.ziUtvEdXw3w0yqPpRwk6-rWrIi1qVTKpkZFcxyl7gRE"
}

req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        if data:
            print("Variants Schema keys:", list(data[0].keys()))
        else:
            print("No variants found.")
except Exception as e:
    print(e)

url2 = "https://jluuobtzylejiahbelgp.supabase.co/rest/v1/products?select=*"
req2 = urllib.request.Request(url2, headers=headers)
try:
    with urllib.request.urlopen(req2) as response:
        data = json.loads(response.read().decode())
        if data:
            print("Products Schema keys:", list(data[0].keys()))
        else:
            print("No products found.")
except Exception as e:
    print(e)

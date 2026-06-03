import urllib.request
import json

url = "https://sift-vs4y.onrender.com/api/bot/status?key=sift_secret_key_1337"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        print(json.dumps(data, indent=2))
except Exception as e:
    print("Error:", e)
    if hasattr(e, "read"):
        print("Response:", e.read().decode())

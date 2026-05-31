import urllib.request
import json
import urllib.error

RENDER_API_KEY = "rnd_LMRVLdOeuFVsfDmOZTjYq4noML7A"
SERVICE_ID = "srv-d8d6s0km0tmc73dk7lkg"
DEPLOY_ID = "dep-d8dpbmtckfvc739htlp0"

def try_endpoints():
    endpoints = [
        f"https://api.render.com/v1/services/{SERVICE_ID}/deploys/{DEPLOY_ID}",
    ]
    for url in endpoints:
        req = urllib.request.Request(url, headers={
            "Authorization": f"Bearer {RENDER_API_KEY}",
            "Accept": "application/json"
        })
        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                print(f"URL: {url}")
                print(json.dumps(data, indent=2))
        except urllib.error.HTTPError as he:
            print(f"URL {url} failed with {he.code}: {he.read().decode('utf-8', errors='ignore')}")
        except Exception as e:
            print(f"URL {url} failed: {e}")

if __name__ == "__main__":
    try_endpoints()

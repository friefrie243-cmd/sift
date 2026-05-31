import urllib.request
import json
import sys

RENDER_API_KEY = "rnd_LMRVLdOeuFVsfDmOZTjYq4noML7A"
SERVICE_ID = "srv-d8d6s0km0tmc73dk7lkg"

def check_env_vars():
    url = f"https://api.render.com/v1/services/{SERVICE_ID}/env-vars"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Accept": "application/json"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print(json.dumps(data, indent=2))
    except Exception as e:
        print(f"Error checking env variables: {e}")

if __name__ == "__main__":
    check_env_vars()

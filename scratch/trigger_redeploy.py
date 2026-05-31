import urllib.request
import json
import time

RENDER_API_KEY = "rnd_l0B8nRW7DIIGsiO1110QLrT0yJRg"
SERVICE_ID = "srv-d8d6s0km0tmc73dk7lkg"

def trigger_redeploy():
    url = f"https://api.render.com/v1/services/{SERVICE_ID}/deploys"
    req = urllib.request.Request(url, method="POST", headers={
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Accept": "application/json"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print(json.dumps(data, indent=2))
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    trigger_redeploy()

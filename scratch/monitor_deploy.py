import urllib.request
import json
import time

RENDER_API_KEY = "rnd_LMRVLdOeuFVsfDmOZTjYq4noML7A"
SERVICE_ID = "srv-d8d6s0km0tmc73dk7lkg"

def check_active_deploy():
    url = f"https://api.render.com/v1/services/{SERVICE_ID}/deploys?limit=5"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Accept": "application/json"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data:
                latest = data[0]["deploy"]
                print(f"Deploy ID: {latest['id']}, Status: {latest['status']}, Commit: {latest['commit']['id'][:8]}, Trigger: {latest['trigger']}")
                return latest
    except Exception as e:
        print(f"Error checking deploys: {e}")
    return None

if __name__ == "__main__":
    check_active_deploy()

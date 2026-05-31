import urllib.request
import json
import sys
import time

RENDER_API_KEY = "rnd_LMRVLdOeuFVsfDmOZTjYq4noML7A"
SERVICE_ID = "srv-d8d6s0km0tmc73dk7lkg"

# We check system events for Sift service
def check_events():
    # Render API does not have an open log stream endpoint but we can check service events or deployment history details
    url = f"https://api.render.com/v1/services/{SERVICE_ID}/deploys?limit=20"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Accept": "application/json"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for deploy in data:
                d = deploy.get("deploy", {})
                print(f"Deploy ID: {d.get('id')}, Status: {d.get('status')}, Finished: {d.get('finishedAt')}, Msg: {d.get('commit', {}).get('message', '')[:60]}")
    except Exception as e:
        print(f"Error fetching service events: {e}")

if __name__ == "__main__":
    check_events()

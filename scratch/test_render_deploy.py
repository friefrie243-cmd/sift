import urllib.request
import json

RENDER_API_KEY = "rnd_LMRVLdOeuFVsfDmOZTjYq4noML7A"

def list_services():
    url = "https://api.render.com/v1/services"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Accept": "application/json"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for s in data:
                service = s.get("service", {})
                print(f"Service Name: {service.get('name')}, ID: {service.get('id')}, Repo: {service.get('repo')}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    list_services()

import urllib.request
import json

RENDER_API_KEY = "rnd_l0B8nRW7DIIGsiO1110QLrT0yJRg"
SERVICE_ID = "srv-d8d6s0km0tmc73dk7lkg"

def check_deploys():
    url = f"https://api.render.com/v1/services/{SERVICE_ID}/deploys?limit=5"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Accept": "application/json"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for d in data:
                deploy = d['deploy']
                print(f"Deploy ID: {deploy['id']}")
                print(f"Status: {deploy['status']}")
                print(f"Commit: {deploy.get('commit', {}).get('id')[:8] if deploy.get('commit') else 'N/A'}")
                print(f"Message: {deploy.get('commit', {}).get('message')}")
                print(f"Created At: {deploy['createdAt']}")
                print("-" * 40)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_deploys()

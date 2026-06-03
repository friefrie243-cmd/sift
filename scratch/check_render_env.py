import urllib.request
import json

RENDER_API_KEY = "rnd_l0B8nRW7DIIGsiO1110QLrT0yJRg"
SERVICE_ID = "srv-d8d6s0km0tmc73dk7lkg"

def check_env():
    url = f"https://api.render.com/v1/services/{SERVICE_ID}/env-vars?limit=20"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {RENDER_API_KEY}",
        "Accept": "application/json"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            for item in data:
                env_var = item['envVar']
                # mask value
                val = env_var['value']
                masked_val = val[:4] + "..." + val[-4:] if len(val) > 8 else "..."
                print(f"Key: {env_var['key']}, Value: {masked_val}")
    except Exception as e:
        print(f"Error: {e}")
        if hasattr(e, "read"):
            print("Response:", e.read().decode())

if __name__ == "__main__":
    check_env()

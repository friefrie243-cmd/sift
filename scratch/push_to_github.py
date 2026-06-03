import os
import json
import base64
import urllib.request
import urllib.error

TOKEN = os.getenv("GITHUB_TOKEN", "")
REPO = "friefrie243-cmd/sift"
PROJECT_ROOT = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main"
SIFT_DIR = os.path.join(PROJECT_ROOT, "sift")

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Accept": "application/vnd.github.v3+json",
    "User-Agent": "Sift-Deploy-Script"
}

def make_request(url, method="GET", data=None):
    req = urllib.request.Request(url, method=method, headers=headers)
    if data is not None:
        req.data = json.dumps(data).encode("utf-8")
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            err_data = json.loads(e.read().decode("utf-8"))
        except:
            err_data = e.reason
        return e.code, err_data

def push_file(local_path, repo_path):
    with open(local_path, "rb") as f:
        local_content_bytes = f.read()
    
    # Check if file exists on GitHub
    url = f"https://api.github.com/repos/{REPO}/contents/{repo_path}"
    status, res = make_request(url)
    
    local_base64 = base64.b64encode(local_content_bytes).decode("utf-8")
    
    if status == 200:
        remote_sha = res["sha"]
        # GitHub base64 can contain newlines, strip them for comparison
        remote_base64_clean = res["content"].replace("\n", "").replace("\r", "")
        local_base64_clean = local_base64.replace("\n", "").replace("\r", "")
        
        if remote_base64_clean == local_base64_clean:
            print(f"[~] File {repo_path} is already up to date on GitHub.")
            return True
        else:
            print(f"[*] Updating file {repo_path} on GitHub...")
            data = {
                "message": f"update: sync {repo_path} changes from local suite",
                "content": local_base64,
                "sha": remote_sha
            }
            put_status, put_res = make_request(url, method="PUT", data=data)
            if put_status in [200, 201]:
                print(f"[+] Successfully updated {repo_path}")
                return True
            else:
                print(f"[!] Failed to update {repo_path}: {put_status} - {put_res}")
                return False
    elif status == 404:
        print(f"[*] Creating file {repo_path} on GitHub...")
        data = {
            "message": f"feat: add {repo_path}",
            "content": local_base64
        }
        put_status, put_res = make_request(url, method="PUT", data=data)
        if put_status in [200, 201]:
            print(f"[+] Successfully created {repo_path}")
            return True
        else:
            print(f"[!] Failed to create {repo_path}: {put_status} - {put_res}")
            return False
    else:
        print(f"[!] Error checking {repo_path}: {status} - {res}")
        return False

def main():
    print(f"[*] Scanning {SIFT_DIR} to sync with GitHub repository {REPO}...")
    success_count = 0
    fail_count = 0
    skip_count = 0
    
    # We also sync Dockerfile in root
    dockerfile_path = os.path.join(PROJECT_ROOT, "Dockerfile")
    if os.path.exists(dockerfile_path):
        if push_file(dockerfile_path, "Dockerfile"):
            success_count += 1
        else:
            fail_count += 1

    for root, dirs, files in os.walk(SIFT_DIR):
        # Skip __pycache__
        if "__pycache__" in dirs:
            dirs.remove("__pycache__")
            
        for file in files:
            local_path = os.path.join(root, file)
            # Get path relative to PROJECT_ROOT
            rel_path = os.path.relpath(local_path, PROJECT_ROOT)
            # Normalize to forward slashes for GitHub API
            repo_path = rel_path.replace("\\", "/")
            
            # Skip python cache files
            if repo_path.endswith(".pyc"):
                continue
                
            if push_file(local_path, repo_path):
                success_count += 1
            else:
                fail_count += 1
                
    print(f"\n[+] Sync complete! Successfully processed: {success_count} files. Failed: {fail_count} files.")

if __name__ == "__main__":
    main()

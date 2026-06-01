import random
import asyncio
import logging
import aiohttp

try:
    from curl_cffi import requests as curl_requests
    HAS_CURL_CFFI = True
except ImportError:
    HAS_CURL_CFFI = False

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:127.0) Gecko/20100101 Firefox/127.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36 Edg/126.0.0.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:127.0) Gecko/20100101 Firefox/127.0",
]

IMPERSONATES = ["chrome110", "chrome120", "chrome124", "safari15_5", "safari17_0", "edge120"]

# Roblox-specific headers for CDN and API fetches
ROBLOX_HEADERS = {
    "RBX-Device-Type": "Computer",
    "Accept": "application/json, text/plain, */*",
    "Origin": "https://www.roblox.com",
    "Referer": "https://www.roblox.com/",
}

class AdvancedFetcher:
    @staticmethod
    async def fetch(url: str, retries: int = 3, proxy: str = None, binary: bool = False) -> tuple[bool, str]:
        """
        Attempts to fetch a URL with a multi-strategy approach:
        1. aiohttp (async-native, fast)
        2. curl_cffi with TLS fingerprinting (if available)
        3. Standard requests (final fallback)
        """
        last_error = ""
        is_roblox = any(domain in url.lower() for domain in [
            "roblox.com", "rbxcdn.com", "robloxcdn.com", "rbxassetid.com"
        ])
        
        for attempt in range(retries):
            # Build headers
            ua = random.choice(USER_AGENTS)
            headers = {
                "User-Agent": ua,
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.5",
                "Accept-Encoding": "gzip, deflate, br",
                "Connection": "keep-alive",
                "Upgrade-Insecure-Requests": "1",
                "Sec-Fetch-Dest": "document",
                "Sec-Fetch-Mode": "navigate",
                "Sec-Fetch-Site": "none",
                "Sec-Fetch-User": "?1",
                "sec-ch-ua": '"Chromium";v="126", "Google Chrome";v="126", "Not.A/Brand";v="8"',
                "sec-ch-ua-mobile": "?0",
                "sec-ch-ua-platform": '"Windows"',
            }
            
            # Add Roblox-specific headers if applicable
            if is_roblox:
                headers.update(ROBLOX_HEADERS)
            
            # Strategy 1: aiohttp (async native — fastest)
            try:
                timeout = aiohttp.ClientTimeout(total=20, connect=10)
                connector = aiohttp.TCPConnector(ssl=False) if proxy else None
                async with aiohttp.ClientSession(
                    timeout=timeout,
                    connector=connector,
                    headers=headers
                ) as session:
                    async with session.get(
                        url,
                        proxy=proxy,
                        allow_redirects=True,
                        max_redirects=10
                    ) as response:
                        if response.status == 200:
                            if binary:
                                content = await response.read()
                                return True, content.hex()
                            else:
                                text = await response.text(errors="ignore")
                                return True, text
                        elif response.status in [403, 503]:
                            # Cloudflare or rate limit — fall through to curl_cffi
                            last_error = f"HTTP {response.status} (possibly Cloudflare protected)"
                        else:
                            last_error = f"HTTP status code {response.status}"
            except Exception as aio_err:
                last_error = f"aiohttp error: {str(aio_err)}"

            # Strategy 2: curl_cffi with browser impersonation (bypasses TLS fingerprinting)
            if HAS_CURL_CFFI:
                try:
                    browser = random.choice(IMPERSONATES)
                    
                    def perform_curl():
                        proxies = {"http": proxy, "https": proxy} if proxy else None
                        r = curl_requests.get(
                            url,
                            headers=headers,
                            impersonate=browser,
                            proxies=proxies,
                            timeout=20,
                            allow_redirects=True
                        )
                        return r.status_code, r.text if not binary else r.content.hex()

                    status, text = await asyncio.get_event_loop().run_in_executor(None, perform_curl)
                    if status == 200:
                        return True, text
                    else:
                        last_error = f"HTTP status code {status} (curl_cffi with {browser})"
                except Exception as curl_err:
                    last_error = f"curl_cffi error: {str(curl_err)}"

            # Strategy 3: Standard requests (final fallback)
            if HAS_REQUESTS:
                try:
                    def perform_requests():
                        proxies = {"http": proxy, "https": proxy} if proxy else None
                        r = requests.get(
                            url,
                            headers=headers,
                            proxies=proxies,
                            timeout=20,
                            allow_redirects=True
                        )
                        return r.status_code, r.text if not binary else r.content.hex()

                    status, text = await asyncio.get_event_loop().run_in_executor(None, perform_requests)
                    if status == 200:
                        return True, text
                    else:
                        last_error = f"HTTP status code {status} (requests fallback)"
                except Exception as req_err:
                    last_error = f"requests error: {str(req_err)}"

            # Wait before retry with exponential backoff
            await asyncio.sleep(min(attempt + 1, 3))

        return False, f"Failed to fetch content after {retries} attempts. Last error: {last_error}"

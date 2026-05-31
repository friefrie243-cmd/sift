import random
import asyncio
import logging

try:
    from curl_cffi import requests as curl_requests
    HAS_CURL_CFFI = True
except ImportError:
    HAS_CURL_CFFI = False
    import requests

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
]

IMPERSONATES = ["chrome110", "chrome120", "safari15_5"]

class AdvancedFetcher:
    @staticmethod
    async def fetch(url: str, retries: int = 3, proxy: str = None) -> tuple[bool, str]:
        """
        Attempts to fetch a URL using user-agent rotation and TLS fingerprinting (if curl_cffi is available).
        """
        last_error = ""
        for attempt in range(retries):
            # Select random User-Agent
            headers = {
                "User-Agent": random.choice(USER_AGENTS),
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.5",
                "Referer": "https://linkvertise.com/",
            }

            try:
                if HAS_CURL_CFFI:
                    try:
                        # Select random browser impersonation
                        browser = random.choice(IMPERSONATES)
                        
                        # Run curl_requests in an executor since it is synchronous
                        def perform_curl():
                            proxies = {"http": proxy, "https": proxy} if proxy else None
                            r = curl_requests.get(
                                url,
                                headers=headers,
                                impersonate=browser,
                                proxies=proxies,
                                timeout=15
                            )
                            return r.status_code, r.text

                        status, text = await asyncio.get_event_loop().run_in_executor(None, perform_curl)
                        if status == 200:
                            return True, text
                        else:
                            last_error = f"HTTP status code {status}"
                    except Exception as curl_err:
                        # Fallback to standard requests
                        def perform_requests():
                            proxies = {"http": proxy, "https": proxy} if proxy else None
                            r = requests.get(
                                url,
                                headers=headers,
                                proxies=proxies,
                                timeout=15
                            )
                            return r.status_code, r.text

                        status, text = await asyncio.get_event_loop().run_in_executor(None, perform_requests)
                        if status == 200:
                            return True, text
                        else:
                            last_error = f"HTTP status code {status} (Fallback after curl_cffi error: {curl_err})"
                else:
                    # Fallback to standard requests in executor
                    def perform_requests():
                        proxies = {"http": proxy, "https": proxy} if proxy else None
                        r = requests.get(
                            url,
                            headers=headers,
                            proxies=proxies,
                            timeout=15
                        )
                        return r.status_code, r.text

                    status, text = await asyncio.get_event_loop().run_in_executor(None, perform_requests)
                    if status == 200:
                        return True, text
                    else:
                        last_error = f"HTTP status code {status}"

            except Exception as e:
                last_error = str(e)

            # Wait before retry
            await asyncio.sleep(attempt + 1)

        return False, f"Failed to fetch content after {retries} attempts. Error: {last_error}"

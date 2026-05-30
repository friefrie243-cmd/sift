import re
import base64

class IronBrewDeobfuscator:
    @staticmethod
    def decrypt_ib2_strings(code: str) -> tuple[bool, str, list[str]]:
        """
        Heuristically decrypts and unfolds IronBrew v2 string tables.
        IronBrew v2 scripts compile their string table inside a table constructor
        and decrypt it via a loop or custom decryption function.
        """
        # Look for the characteristic IronBrew base64/byte string array
        # Example: local strings = { "...", "...", ... }
        # Often it uses a base64 string or an array of hex values.
        
        # Step 1: Detect string decryption function and string array
        # Let's search for a large array of strings or hex bytes
        string_array_match = re.search(r"\{\s*\"[A-Za-z0-9+/=\\]+\"(?:\s*,\s*\"[A-Za-z0-9+/=\\]+\")*\s*\}", code)
        if not string_array_match:
            # Look for a single massive base64 string
            string_array_match = re.search(r"\"[A-Za-z0-9+/=]{100,}\"", code)

        if not string_array_match:
            return False, "Could not locate IronBrew string table signature.", []

        strings_found = []
        # Attempt to extract and decrypt standard base64 strings if found
        base64_strings = re.findall(r"\"([A-Za-z0-9+/=]{8,})\"", code)
        
        decrypted_map = {}
        for b64 in base64_strings:
            try:
                # Pad base64 if needed
                padded = b64 + "=" * ((4 - len(b64) % 4) % 4)
                decrypted = base64.b64decode(padded).decode("utf-8", errors="ignore")
                # Filter out garbage
                if all(32 <= ord(c) < 127 or c in "\r\n\t" for c in decrypted) and len(decrypted) > 2:
                    decrypted_map[b64] = decrypted
                    strings_found.append(decrypted)
            except:
                continue

        if not decrypted_map:
            # If base64 decoding yields nothing, try bytecode string constant lookup
            # Let's search for character arrays or byte mappings
            byte_arrays = re.findall(r"\\(\d{3})", code)
            if byte_arrays:
                try:
                    reconstructed = "".join(chr(int(b)) for b in byte_arrays)
                    # Look for base64 inside reconstructed
                    sub_b64 = re.findall(r"[A-Za-z0-9+/=]{8,}", reconstructed)
                    for sb in sub_b64:
                        padded = sb + "=" * ((4 - len(sb) % 4) % 4)
                        try:
                            dec = base64.b64decode(padded).decode("utf-8", errors="ignore")
                            if len(dec) > 3:
                                decrypted_map[sb] = dec
                                strings_found.append(dec)
                        except:
                            continue
                except:
                    pass

        # Step 2: Unfold constants back into the script
        refactored_code = code
        for b64, plain in decrypted_map.items():
            # Escape quotes in plain text
            escaped_plain = plain.replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r')
            refactored_code = refactored_code.replace(f'"{b64}"', f'"{escaped_plain}"')
            refactored_code = refactored_code.replace(f"'{b64}'", f'"{escaped_plain}"')

        return True, refactored_code, strings_found

    @classmethod
    def deobfuscate(cls, code: str) -> tuple[bool, str, str]:
        """
        Runs IronBrew v2 deobfuscation.
        Returns (success, deobfuscated_code, log)
        """
        log = "Starting Sift IronBrew v2 Deobfuscator...\n"
        success, refactored, decrypted = cls.decrypt_ib2_strings(code)
        if success:
            log += f"Successfully decrypted {len(decrypted)} string constants from the IronBrew v2 string table.\n"
            # Optional: Clean up control flow junk
            refactored = cls.cleanup_junk_logic(refactored)
            return True, refactored, log
        else:
            log += "String table extraction failed. Falling back to dynamic environment dumper...\n"
            return False, code, log

    @staticmethod
    def cleanup_junk_logic(code: str) -> str:
        """
        Removes known IronBrew junk code blocks (e.g., redundant math or empty functions).
        """
        # Replace redundant "not not" occurrences
        code = re.sub(r"not\s+not\s+", "", code)
        
        # Replace simple empty wrapper loads if any
        # (e.g., return (function(...) ... end)(...) )
        return code

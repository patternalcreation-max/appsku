#!/usr/bin/env python3
"""Release A.5 source invariants + semantic mirror vectors.

This Linux validator does not claim Swift compilation or byte-for-byte JSONEncoder parity.
The macOS/Xcode CI gate owns those proofs.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
import unicodedata
from urllib.parse import unquote_to_bytes, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SECURITY = ROOT / "Browser" / "SecurityResearch"
FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str) -> None:
    if condition:
        print(f"PASS {name}")
    else:
        FAILURES.append(f"{name}: {detail}")
        print(f"FAIL {name}: {detail}")


def read(name: str) -> str:
    path = SECURITY / name
    return path.read_text(encoding="utf-8") if path.is_file() else ""


@dataclass(frozen=True)
class Asset:
    scheme: str
    domain: str
    path: str = "/*"


def canonical_path(raw: str, *, rule: bool = False) -> tuple[str, bool] | None:
    if not raw.startswith("/") or len(raw.encode()) > 2048:
        return None
    is_prefix = rule and raw.endswith("*")
    if rule:
        if raw.count("*") > 1 or ("*" in raw and not is_prefix):
            return None
        if is_prefix:
            raw = raw[:-1]
    elif "*" in raw:
        return None
    if not re.fullmatch(r"(?:[^%]|%[0-9A-Fa-f]{2})*", raw):
        return None
    encoded = [int(value, 16) for value in re.findall(r"%([0-9A-Fa-f]{2})", raw)]
    if any(value in {0x00, 0x25, 0x2F, 0x5C} for value in encoded):
        return None
    try:
        decoded = unicodedata.normalize("NFC", unquote_to_bytes(raw).decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return None
    if not decoded.startswith("/") or "\\" in decoded or "*" in decoded or "//" in decoded:
        return None
    if any(unicodedata.category(char) == "Cc" for char in decoded):
        return None

    trailing = len(decoded) > 1 and decoded.endswith("/")
    pieces = decoded.split("/")
    if pieces[0] != "":
        return None
    stack: list[str] = []
    for index, piece in enumerate(pieces[1:]):
        is_last = index == len(pieces) - 2
        if piece == "":
            if decoded == "/" and is_last:
                continue
            if trailing and is_last:
                continue
            return None
        if piece == ".":
            continue
        if piece == "..":
            if not stack:
                return None
            stack.pop()
            continue
        stack.append(piece)
    result = "/" + "/".join(stack)
    if trailing and result != "/":
        result += "/"
    return result, is_prefix


def asset_valid(asset: Asset) -> bool:
    if asset.scheme not in {"any", "http", "https"}:
        return False
    domain = asset.domain.lower()
    base = domain[2:] if domain.startswith("*.") else domain
    try:
        base.encode("ascii")
    except UnicodeEncodeError:
        return False
    if not base or len(base.encode()) > 253 or ":" in base or "/" in base:
        return False
    labels = base.split(".")
    if any(not label or len(label) > 63 or label.startswith("-") or label.endswith("-") or not re.fullmatch(r"[a-z0-9-]+", label) for label in labels):
        return False
    return canonical_path(asset.path, rule=True) is not None


def asset_matches(asset: Asset, scheme: str, host: str, path: str) -> bool:
    if not asset_valid(asset) or (asset.scheme != "any" and asset.scheme != scheme):
        return False
    domain = asset.domain.lower()
    if domain.startswith("*."):
        base = domain[2:]
        host_match = host.endswith("." + base) and host != base
    else:
        host_match = host == domain
    if not host_match:
        return False
    rule = canonical_path(asset.path, rule=True)
    if rule is None:
        return False
    rule_path, prefix = rule
    return path.startswith(rule_path) if prefix else path == rule_path


def match(url: str, allowed: list[Asset], denied: list[Asset]) -> str:
    if not all(asset_valid(asset) for asset in denied + allowed):
        return "invalid"
    try:
        parsed = urlsplit(url)
        port = parsed.port
    except ValueError:
        return "invalid"
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username is not None or parsed.password is not None:
        return "invalid"
    try:
        host = parsed.hostname.lower()
        host.encode("ascii")
    except UnicodeEncodeError:
        return "invalid"
    if port is not None and not ((parsed.scheme == "http" and port == 80) or (parsed.scheme == "https" and port == 443)):
        return "invalid"
    normalized = canonical_path(parsed.path or "/")
    if normalized is None:
        return "invalid"
    path, _ = normalized
    if any(asset_matches(asset, parsed.scheme, host, path) for asset in denied):
        return "outOfScope"
    if any(asset_matches(asset, parsed.scheme, host, path) for asset in allowed):
        return "inScope"
    return "neutral"


def mirror_hash(profile: dict) -> str:
    payload = {key: value for key, value in profile.items() if key != "profileHash"}
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return hashlib.sha256(encoded).hexdigest()


def validate_profile(profile: dict, now: datetime) -> str:
    if profile.get("schemaVersion") != 1:
        return "unsupportedSchema"
    if not str(profile.get("programLabel", "")).strip() or not str(profile.get("programType", "")).strip():
        return "missingMetadata"
    if not str(profile.get("operatorDeclaration", "")).strip():
        return "missingDeclaration"
    if not profile.get("inScopeAssets"):
        return "missingScope"
    if not re.fullmatch(r"[0-9a-f]{64}", str(profile.get("policyDocumentHash", ""))):
        return "invalidPolicyDocumentHash"
    budgets = profile.get("budgets", {})
    if any(int(budgets.get(key, 0)) <= 0 for key in ("minute", "total", "concurrent")):
        return "invalidBudgets"
    window = profile.get("testingWindow")
    if window:
        start, end = window["startsAt"], window["endsAt"]
        if start >= end:
            return "invalidTestingWindow"
        if now.timestamp() < start:
            return "testingWindowNotYetActive"
        if now.timestamp() >= end:
            return "testingWindowExpired"
    if profile.get("profileHash") != mirror_hash(profile):
        return "profileHashMismatch"
    return "valid"


profile_src = read("EngagementProfile.swift")
matcher_src = read("EngagementScopeMatcher.swift")
store_src = read("EngagementProfileStore.swift")
status_src = read("EngagementStatus.swift")
required = ["EngagementProfile.swift", "EngagementScopeMatcher.swift", "EngagementProfileStore.swift", "EngagementStatus.swift"]
check("required files", all((SECURITY / name).is_file() for name in required), "missing Release A.5 source")
check("platform-neutral profile", all(token in profile_src for token in ("Codable", "Equatable", "platformRef", "operatorDeclaration", "profileHash")), "profile model fields missing")
check("canonical hash excludes itself", "CanonicalProfile" in profile_src and "profileHash" not in profile_src.split("private struct CanonicalProfile", 1)[1], "profileHash entered canonical payload")
check("stable canonical encoder", ".sortedKeys" in profile_src and ".withoutEscapingSlashes" in profile_src and ".withFractionalSeconds" in profile_src, "stable encoder/date formatting missing")
check("bounded profile", all(token in profile_src for token in ("maximumProfileBytes", "maximumPathBytes", "maximumAssetsPerList", "profileTooLarge")), "profile work is unbounded")
check("iOS15 URLComponents path", "URLComponents(url: url" in matcher_src and "components.percentEncodedPath" in matcher_src and "url.percentEncodedPath" not in matcher_src, "matcher uses unsupported or ambiguous path API")
check("canonical path guard", all(token in matcher_src for token in ("EngagementPathCanonicalizer", "removingPercentEncoding", "decoded != 0x2F", "decoded != 0x5C", "decoded != 0x25", "CharacterSet.controlCharacters", 'segment == ".."')), "encoded separator/control/double-decode/dot canonicalization missing")
check("deny first", matcher_src.find("profile.outOfScopeAssets.first") < matcher_src.find("profile.inScopeAssets.first"), "allow evaluated before deny")
check("wildcard excludes apex", 'host.hasSuffix("." + base) && host != base' in matcher_src, "wildcard implicitly includes apex")
check("default-port and userinfo guard", "components.user == nil" in matcher_src and "components.password == nil" in matcher_src and "isDefaultPort" in matcher_src, "ambiguous URL authority accepted")
check("active immutable hash binding", all(token in store_src for token in ("let profileHash: String", "immutableProfileURL", "profile.profileHash == record.profileHash", "NSRecursiveLock", "boundedData", "boundedData(at: immutableURL) == data")), "draft save or stale immutable content can replace active authority")
check("single-descriptor bounded read", all(token in store_src for token in ("O_NOFOLLOW", "O_NONBLOCK", "Darwin.fstat", "S_IFREG", "Darwin.read", "maximumProfileBytes + 1")) and "Data(contentsOf: url" not in store_src, "file open can block, path is reopened after validation, or read is unbounded")
check("atomic pointer", "recordData.write(to: activeURL" in store_src and "options: .atomic" in store_src, "activation pointer is not atomic")
check("status is neutral", "enum EngagementScopeDisposition" in status_src and "inScope" in status_src and "outOfScope" in status_src and "invalid" in status_src, "status model missing")

allowed = [Asset("https", "example.com"), Asset("any", "*.wild.example", "/api*")]
denied = [Asset("any", "blocked.wild.example"), Asset("any", "example.com", "/admin")]
check("exact host", match("https://example.com/", allowed, denied) == "inScope", "exact host missed")
check("lookalike rejected", match("https://example.com.evil.test/", allowed, denied) == "neutral", "suffix lookalike matched")
check("wildcard apex excluded", match("https://wild.example/api", allowed, denied) == "neutral", "wildcard expanded to apex")
check("wildcard subdomain", match("http://a.wild.example/api/v1", allowed, denied) == "inScope", "wildcard subdomain missed")
check("deny precedence", match("https://blocked.wild.example/api", allowed, denied) == "outOfScope", "deny did not win")
check("encoded unreserved deny", match("https://example.com/%61dmin", allowed, denied) == "outOfScope", "encoded admin bypassed deny")
check("dot-segment deny", match("https://example.com/x/../admin", allowed, denied) == "outOfScope", "dot segment bypassed deny")
check("encoded slash rejected", match("https://example.com/%2fadmin", allowed, denied) == "invalid", "encoded separator accepted")
check("double encoding rejected", match("https://example.com/%2561dmin", allowed, denied) == "invalid", "double-decode ambiguity accepted")
check("backslash rejected", match(r"https://example.com/\admin", allowed, denied) == "invalid", "backslash routing ambiguity accepted")
for encoded_control in ("%C2%80", "%C2%85", "%C2%9F"):
    check(f"C1 control {encoded_control} rejected", match(f"https://example.com/{encoded_control}admin", allowed, denied) == "invalid", "Unicode C1 control bypassed deny")
check("userinfo rejected", match("https://user:pass@example.com/", allowed, denied) == "invalid", "userinfo accepted")
check("nondefault port rejected", match("https://example.com:8443/", allowed, denied) == "invalid", "undeclared port accepted")
exact = [Asset("https", "exact.example", "/api")]
check("exact path", match("https://exact.example/api", exact, []) == "inScope", "exact path missed")
check("exact path not prefix", match("https://exact.example/api-evil", exact, []) == "neutral", "exact path expanded to prefix")

now = datetime.now(timezone.utc)
profile = {
    "schemaVersion": 1,
    "programLabel": "Program",
    "programType": "authorized-testing",
    "policyDocumentHash": "a" * 64,
    "operatorDeclaration": "I declare authorization",
    "inScopeAssets": [{"scheme": "https", "domain": "example.com", "path": "/*"}],
    "budgets": {"minute": 10, "total": 100, "concurrent": 1},
    "testingWindow": {"startsAt": (now - timedelta(hours=1)).timestamp(), "endsAt": (now + timedelta(hours=1)).timestamp()},
    "profileHash": "",
}
profile["profileHash"] = mirror_hash(profile)
check("valid profile mirror", validate_profile(profile, now) == "valid", "valid mirror vector rejected")
for name, mutation, expected in (
    ("bad hash", {**profile, "profileHash": "0" * 64}, "profileHashMismatch"),
    ("blank declaration", {**profile, "operatorDeclaration": "   "}, "missingDeclaration"),
    ("zero budget", {**profile, "budgets": {"minute": 0, "total": 100, "concurrent": 1}}, "invalidBudgets"),
    ("negative budget", {**profile, "budgets": {"minute": 10, "total": -1, "concurrent": 1}}, "invalidBudgets"),
):
    if name not in {"bad hash", "blank declaration"}:
        mutation["profileHash"] = mirror_hash(mutation)
    check(f"{name} mirror", validate_profile(mutation, now) == expected, f"{name} vector escaped")

if FAILURES:
    print(f"FAILED {len(FAILURES)} check(s)")
    sys.exit(1)
print("PASS release-a5 source invariants and semantic mirror vectors (Swift compile pending)")

import Foundation
import WebKit

enum AtomicElementOperation: String, Equatable {
    case fill
    case click
    case select
    case submit

    init?(tool: ToolName) {
        switch tool {
        case .fillSelector: self = .fill
        case .clickSelector: self = .click
        case .selectOption: self = .select
        case .submitForm: self = .submit
        default: return nil
        }
    }
}

struct AtomicElementExecutionResult: Equatable {
    enum Status: String, Equatable { case executed, rejected }
    enum Code: String, Equatable {
        case filled
        case clicked
        case selected
        case submitted
        case invalidArguments
        case pageMismatch
        case targetMissing
        case targetMismatch
        case targetSensitive
        case targetHidden
        case invalidTarget
        case unsupportedOperation
        case webKitFailure
        case malformedResult
    }

    let status: Status
    let code: Code

    static func rejected(_ code: Code) -> AtomicElementExecutionResult {
        AtomicElementExecutionResult(status: .rejected, code: code)
    }
}

/// The sole WebKit adapter for element effects. Validation and effect happen in
/// one default-client-world JavaScript task, with all private data passed as args.
@MainActor
enum AtomicElementExecutor {
    static func execute(
        in webView: WKWebView,
        reference: StableElementReference,
        operation: AtomicElementOperation,
        value: String? = nil
    ) async -> AtomicElementExecutionResult {
        let arguments = reference.atomicExecutorArguments(operation: operation.rawValue, value: value)
        do {
            let raw = try await webView.callAsyncJavaScript(
                functionBody,
                arguments: arguments,
                in: nil,
                contentWorld: WKContentWorld.defaultClient
            )
            return decode(raw)
        } catch {
            return .rejected(.webKitFailure)
        }
    }

    private static func decode(_ raw: Any?) -> AtomicElementExecutionResult {
        guard let object = raw as? [String: Any],
              object.count == 2,
              let statusRaw = object["status"] as? String,
              let codeRaw = object["code"] as? String,
              let status = AtomicElementExecutionResult.Status(rawValue: statusRaw),
              let code = AtomicElementExecutionResult.Code(rawValue: codeRaw) else {
            return .rejected(.malformedResult)
        }
        switch (status, code) {
        case (.executed, .filled), (.executed, .clicked), (.executed, .selected), (.executed, .submitted):
            return AtomicElementExecutionResult(status: status, code: code)
        case (.rejected, .invalidArguments), (.rejected, .pageMismatch),
             (.rejected, .targetMissing), (.rejected, .targetMismatch),
             (.rejected, .targetSensitive), (.rejected, .targetHidden),
             (.rejected, .invalidTarget), (.rejected, .unsupportedOperation),
             (.rejected, .webKitFailure), (.rejected, .malformedResult):
            return AtomicElementExecutionResult(status: status, code: code)
        default:
            return .rejected(.malformedResult)
        }
    }

    private static let functionBody = #"""
    "use strict";
    return (function () {
      const ok = (code) => ({status: "executed", code: code});
      const reject = (code) => ({status: "rejected", code: code});
      const encoder = new TextEncoder();

      function bytePrefix(value, maximum) {
        let output = "";
        let count = 0;
        for (const scalar of String(value)) {
          const width = encoder.encode(scalar).length;
          if (count + width > maximum) break;
          output += scalar;
          count += width;
        }
        return output;
      }

      function normalize(value, maximum) {
        let clean = "";
        let pendingSpace = false;
        for (const scalar of String(value == null ? "" : value)) {
          const codePoint = scalar.codePointAt(0);
          const whitespace = (codePoint >= 0x0009 && codePoint <= 0x000d) || codePoint === 0x0020 ||
            codePoint === 0x00a0 || codePoint === 0x1680 || (codePoint >= 0x2000 && codePoint <= 0x200a) ||
            codePoint === 0x2028 || codePoint === 0x2029 || codePoint === 0x202f || codePoint === 0x205f ||
            codePoint === 0x3000 || codePoint === 0xfeff;
          if (whitespace) {
            pendingSpace = clean.length !== 0;
          } else {
            if (pendingSpace) clean += " ";
            clean += scalar;
            pendingSpace = false;
          }
        }
        return bytePrefix(clean, maximum);
      }

      function asciiLowercase(value) {
        return String(value).replace(/[A-Z]/g, (character) => String.fromCharCode(character.charCodeAt(0) + 32));
      }

      function canonicalPageURL(value) {
        if (typeof value !== "string" || value.length === 0 || encoder.encode(value).length > 4096 || /[\s\\\u0000-\u001f\u007f]/u.test(value)) return null;
        const schemeMatch = /^(https?):\/\//iu.exec(value);
        if (!schemeMatch) return null;
        const authority = value.slice(schemeMatch[0].length).split(/[\/?#]/u, 1)[0];
        if (!authority || /[@%]/u.test(authority) || !/^[\x00-\x7f]+$/u.test(authority)) return null;
        let rawHost;
        let rawPort = "";
        if (authority.startsWith("[")) {
          const close = authority.indexOf("]");
          if (close <= 1) return null;
          rawHost = authority.slice(0, close + 1);
          const suffix = authority.slice(close + 1);
          if (suffix) {
            if (!/^:[0-9]+$/u.test(suffix)) return null;
            rawPort = suffix.slice(1);
          }
        } else {
          const pieces = authority.split(":");
          if (pieces.length > 2 || !pieces[0]) return null;
          rawHost = pieces[0];
          if (pieces.length === 2) {
            if (!/^[0-9]+$/u.test(pieces[1])) return null;
            rawPort = pieces[1];
          }
          if (rawHost.length > 253 || rawHost.startsWith(".") || rawHost.endsWith(".")) return null;
          const labels = rawHost.split(".");
          if (labels.some((label) => !label || label.length > 63 || label.startsWith("-") || label.endsWith("-") || !/^[A-Za-z0-9-]+$/u.test(label))) return null;
        }
        let parsed;
        try { parsed = new URL(value); } catch (_) { return null; }
        if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
        if (parsed.username || parsed.password || !parsed.hostname || !/^[\x00-\x7f]+$/u.test(parsed.hostname)) return null;
        if (asciiLowercase(parsed.hostname) !== asciiLowercase(rawHost)) return null;
        const defaultPort = parsed.protocol === "https:" ? "443" : "80";
        if (rawPort && String(Number(rawPort)) !== defaultPort) return null;
        if (rawPort && (!/^(80|443)$/u.test(rawPort) || rawPort !== defaultPort)) return null;
        parsed.protocol = asciiLowercase(parsed.protocol);
        parsed.hostname = asciiLowercase(parsed.hostname);
        parsed.port = "";
        const canonical = parsed.href;
        if (!canonical || encoder.encode(canonical).length > 4096 || /[\s\\\u0000-\u001f\u007f]/u.test(canonical)) return null;
        return canonical;
      }

      function sha256(value) {
        const bytes = encoder.encode(String(value));
        const bitLength = bytes.length * 8;
        const paddedLength = Math.ceil((bytes.length + 9) / 64) * 64;
        const data = new Uint8Array(paddedLength);
        data.set(bytes);
        data[bytes.length] = 0x80;
        const view = new DataView(data.buffer);
        view.setUint32(paddedLength - 8, Math.floor(bitLength / 0x100000000), false);
        view.setUint32(paddedLength - 4, bitLength >>> 0, false);
        const constants = new Uint32Array([
          0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
          0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
          0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
          0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
          0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
          0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
          0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
          0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
        ]);
        const state = new Uint32Array([
          0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
          0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19
        ]);
        const words = new Uint32Array(64);
        const rotate = (x, n) => (x >>> n) | (x << (32 - n));
        for (let offset = 0; offset < paddedLength; offset += 64) {
          for (let i = 0; i < 16; i += 1) words[i] = view.getUint32(offset + (i * 4), false);
          for (let i = 16; i < 64; i += 1) {
            const s0 = rotate(words[i - 15], 7) ^ rotate(words[i - 15], 18) ^ (words[i - 15] >>> 3);
            const s1 = rotate(words[i - 2], 17) ^ rotate(words[i - 2], 19) ^ (words[i - 2] >>> 10);
            words[i] = (words[i - 16] + s0 + words[i - 7] + s1) >>> 0;
          }
          let a=state[0], b=state[1], c=state[2], d=state[3], e=state[4], f=state[5], g=state[6], h=state[7];
          for (let i = 0; i < 64; i += 1) {
            const sum1 = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25);
            const choice = (e & f) ^ ((~e) & g);
            const temp1 = (h + sum1 + choice + constants[i] + words[i]) >>> 0;
            const sum0 = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22);
            const majority = (a & b) ^ (a & c) ^ (b & c);
            const temp2 = (sum0 + majority) >>> 0;
            h=g; g=f; f=e; e=(d+temp1)>>>0; d=c; c=b; b=a; a=(temp1+temp2)>>>0;
          }
          state[0]=(state[0]+a)>>>0; state[1]=(state[1]+b)>>>0;
          state[2]=(state[2]+c)>>>0; state[3]=(state[3]+d)>>>0;
          state[4]=(state[4]+e)>>>0; state[5]=(state[5]+f)>>>0;
          state[6]=(state[6]+g)>>>0; state[7]=(state[7]+h)>>>0;
        }
        return Array.from(state).map((word) => word.toString(16).padStart(8, "0")).join("");
      }

      function sensitiveClass(haystack, autocomplete) {
        haystack = asciiLowercase(haystack);
        autocomplete = asciiLowercase(autocomplete);
        const autocompleteTokens = new Set(autocomplete.split(" ").filter(Boolean));
        const credentials = ["current-password","new-password","one-time-code","webauthn"];
        const payments = ["cc-name","cc-given-name","cc-additional-name","cc-family-name","cc-number","cc-exp","cc-exp-month","cc-exp-year","cc-csc","cc-type","transaction-amount","transaction-currency"];
        if (credentials.some((token) => autocompleteTokens.has(token))) return "credential";
        if (payments.some((token) => autocompleteTokens.has(token))) return "payment";
        const words = new Set(haystack.split(/[^a-z0-9]+/u).filter(Boolean));
        const credentialWords = ["credential","credentials","password","passwd","passcode","otp","2fa","totp","recovery","pin"];
        const paymentWords = ["payment","card","creditcard","cvv","cvc","csc","pan"];
        const keyWords = ["apikey","api-key","session","cookie","privatekey","private-key","mnemonic","seed","secretkey","signing","wallet","walletseed"];
        const compact = haystack.replace(/[^a-z0-9]/gu, "");
        if (credentialWords.some((word) => words.has(word)) || ["onetimecode","recoverycode"].some((word) => compact.includes(word))) return "credential";
        if (paymentWords.some((word) => words.has(word)) || ["cardnumber","creditcard","securitycode"].some((word) => compact.includes(word))) return "payment";
        if (keyWords.some((word) => words.has(word)) || ["apikey","sessiontoken","sessionid","privatekey","secretkey","walletseed","seedphrase","signingkey"].some((word) => compact.includes(word))) return "keyMaterial";
        return "none";
      }

      function visible(element) {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return rect.width > 0 && rect.height > 0 && style.visibility !== "hidden" && style.display !== "none";
      }

      function canonicalFormAction(form) {
        if (!form) return "";
        try {
          const parsed = new URL(form.action || location.href, location.href);
          if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return "__invalid__";
          if (parsed.username || parsed.password || parsed.port || !parsed.hostname || /[\s\\]/u.test(parsed.hostname)) return "__invalid__";
          return normalize(parsed.href, 4096);
        } catch (_) {
          return "__invalid__";
        }
      }

      function metadata(element) {
        const form = element.tagName && element.tagName.toLowerCase() === "form" ? element : (element.closest ? element.closest("form") : null);
        const aria = normalize(element.getAttribute("aria-label") || "", 512);
        const labelled = normalize((element.labels && element.labels[0] && element.labels[0].innerText) || "", 512);
        const text = normalize((element.innerText || element.getAttribute("aria-label") || "").slice(0, 160), 2048);
        const autocomplete = asciiLowercase(normalize(element.getAttribute("autocomplete") || "", 256));
        const type = asciiLowercase(normalize(element.getAttribute("type") || "", 64));
        const role = asciiLowercase(normalize(element.getAttribute("role") || "", 128));
        const name = normalize(element.getAttribute("name") || "", 256);
        const label = aria || labelled;
        const placeholder = asciiLowercase(normalize(element.getAttribute("placeholder") || "", 512));
        const classificationInput = [type, role, asciiLowercase(name), asciiLowercase(label), placeholder, autocomplete].join(" ");
        return {
          tag: asciiLowercase(normalize(element.tagName || "", 64)),
          type: type,
          role: role,
          name: name,
          label: label,
          normalizedText: text,
          textDigest: sha256(text),
          visible: visible(element),
          sensitiveClass: sensitiveClass(classificationInput, autocomplete),
          formMethod: form ? asciiLowercase(normalize(form.method || "", 16)) : "",
          formAction: canonicalFormAction(form)
        };
      }

      if (typeof privateSelector !== "string" || privateSelector.length === 0 || encoder.encode(privateSelector).length > 4096 ||
          typeof expected !== "object" || expected === null || expected.bindingExecutable !== true || typeof operation !== "string" ||
          typeof operationValue !== "string" || typeof hasOperationValue !== "boolean" || typeof boundOrigin !== "string" ||
          typeof snapshotMarker !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/u.test(snapshotMarker) ||
          typeof boundPageURL !== "string") {
        return reject("invalidArguments");
      }
      if (globalThis.__K3BrowserPrivateSnapshotDocumentBinding_8f6d2a41 !== snapshotMarker) return reject("pageMismatch");
      const expectedPageURL = canonicalPageURL(boundPageURL);
      const livePageURL = canonicalPageURL(location.href);
      if (expectedPageURL === null || expectedPageURL !== boundPageURL || livePageURL !== expectedPageURL) return reject("pageMismatch");
      if (location.origin !== boundOrigin) return reject("pageMismatch");

      let element;
      try { element = document.querySelector(privateSelector); } catch (_) { return reject("invalidArguments"); }
      if (!element) return reject("targetMissing");

      const live = metadata(element);
      const fields = ["tag","type","role","name","label","textDigest","visible","sensitiveClass","formMethod","formAction","normalizedText"];
      if (fields.some((field) => live[field] !== expected[field])) return reject("targetMismatch");
      const payload = [live.tag,live.type,live.role,live.name,live.label,live.textDigest,live.visible?"visible":"hidden",live.sensitiveClass,live.formMethod,live.formAction].join("\u001f");
      if (typeof expected.fingerprint !== "string" || !/^[0-9a-f]{64}$/u.test(expected.fingerprint) || sha256(payload) !== expected.fingerprint) return reject("targetMismatch");
      if (!live.visible) return reject("targetHidden");
      if (live.sensitiveClass !== "none") return reject("targetSensitive");
      if (element.disabled || element.getAttribute("aria-disabled") === "true") return reject("invalidTarget");

      switch (operation) {
        case "fill":
          if (!hasOperationValue || encoder.encode(operationValue).length > 16384 || (live.tag !== "input" && live.tag !== "textarea")) return reject("invalidTarget");
          if (live.type === "hidden" || live.type === "password" || live.type === "file") return reject("targetSensitive");
          element.focus();
          element.value = operationValue;
          element.dispatchEvent(new InputEvent("input", {bubbles: true, inputType: "insertText", data: null}));
          element.dispatchEvent(new Event("change", {bubbles: true}));
          return ok("filled");
        case "click":
          if (hasOperationValue || typeof element.click !== "function") return reject("invalidTarget");
          element.click();
          return ok("clicked");
        case "select":
          if (!hasOperationValue || encoder.encode(operationValue).length > 4096 || live.tag !== "select") return reject("invalidTarget");
          if (!Array.from(element.options || []).some((option) => option.value === operationValue && !option.disabled)) return reject("invalidTarget");
          element.value = operationValue;
          element.dispatchEvent(new Event("input", {bubbles: true}));
          element.dispatchEvent(new Event("change", {bubbles: true}));
          return ok("selected");
        case "submit":
          if (hasOperationValue || live.tag !== "form" || (live.formMethod !== "get" && live.formMethod !== "post") || live.formAction === "" || live.formAction === "__invalid__") return reject("invalidTarget");
          if (typeof element.requestSubmit === "function") element.requestSubmit(); else element.submit();
          return ok("submitted");
        default:
          return reject("unsupportedOperation");
      }
    })();
    """#
}

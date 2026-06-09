# Security Guide — PDF Editor

> Security guidelines, checklists, and incident response for the PDF Editor web application.

## Critical Rule

> **A PDF editor handles untrusted file uploads. Every file from a user is potentially malicious.**

## Threat Model

### 1. Malicious PDF Uploads

**Risk**: Users can upload crafted PDFs designed to exploit parsing vulnerabilities.

**Mitigations**:
- Validate magic bytes: first 5 bytes must be `%PDF-`
- Check MIME type: `application/pdf`
- Check file extension: `.pdf`
- Enforce size limit: 50MB per file
- Process in browser only (no server-side execution)
- Use well-maintained libraries (pdf.js, pdf-lib)

### 2. PDF Bombs (Decompression Bombs)

**Risk**: A small PDF that expands to gigabytes when parsed, causing memory exhaustion.

**Mitigations**:
- Limit maximum page count: 1000 pages
- Set processing timeouts: 30 seconds
- Monitor memory usage during processing
- Use web workers so heavy processing can be terminated
- Catch out-of-memory errors gracefully

> **KNOWN GAP (SEC-002, found 2026-06-07):** `js/viewer.js` `renderAll()` renders
> **every** page of a loaded PDF into its own `<canvas>` with no page-count cap. A
> crafted high-page-count PDF (within the 50 MB size limit) can therefore exhaust
> memory on this 1.6 GiB box — the size check in `upload.js` does not bound page
> count. Severity **low** (purely client-side; only the uploader's own tab is
> affected, no server impact), but it violates the "max 1000 pages" rule above.
> **Compounded 2026-06-08:** `js/thumbnails.js` (TASK-306) now *also* loops
> `1..numPages`, rendering a second canvas per page into the Pages panel — so an
> uncapped high-page-count PDF doubles the canvas/memory footprint. The single
> right fix remains a page-count cap at the **load** boundary in `viewer.js` so
> every downstream consumer (viewer + thumbnails + any future per-page feature) is
> protected at once; per-feature caps would be whack-a-mole.
> **Amplifier FIXED (TASK-316, 2026-06-09 — VERIFIED):** the `renderAll()`
> supersede-guard race is closed. `viewer.js` now re-checks `if (token !==
> renderToken) return;` immediately **after** `await pdfDoc.getPage(pageNum)` and
> again right before `container.appendChild(pageWrap)`, so a superseded (stale)
> render bails without allocating a canvas backing store or mutating the DOM.
> Browser-verified via chrome-devtools MCP: the rapid-zoom repro (`zoomIn×3;
> zoomOut×1`, no awaits) now settles at 1 page / 1 canvas for a 1-page PDF (was
> 4/4), and a harsher `zoomIn×6; zoomOut×4` burst also settles at 1/1. The
> **unbounded multiplication path is therefore gone** — rapid zoom can no longer
> multiply canvas memory by the number of overlapping renders. (Note `thumbnails.js`
> and `search.js` use the same `renderToken` bail-out pattern.)
> **Remaining SEC-002 gap (still LOW):** `viewer.js` `loadDocument()` (the load
> boundary) still imposes **no page-count cap** — a crafted high-page-count PDF
> within the 50 MB size limit renders one canvas per page (plus one thumbnail per
> page) with no `numPages > 1000` guard and no processing timeout. With the race
> fixed this is now a *linear* (one-canvas-per-page) footprint rather than a
> multiplied one, so the DoS risk is reduced but not eliminated on the 1.6 GiB box.
> The single right fix remains a page-count cap at the **load** boundary so every
> downstream consumer (viewer + thumbnails + any future per-page feature) is
> protected at once.
> **Fix (developer task, not security's to implement):** in `viewer.js`, after
> `getDocument(...).promise`, reject when `doc.numPages > 1000` (or render lazily /
> virtualized) and emit an `ERROR` so the new notifications toast tells the user.
> Browser-verify via the (now-restored) chrome-devtools tester before marking DONE.
> **New surface (SEC-002, noted 2026-06-09):** `js/merge.js` (TASK-319) is a second
> load boundary of this same class. Each queued file is validated independently and
> passes the per-file 50 MB check, but there is **no cap on cumulative queued bytes
> and no combined page-count cap** — a user can queue many files (e.g. 10 × ~50 MB),
> then `mergeAndDownload()` loads every file's `arrayBuffer()` plus the base into
> pdf-lib at once, which can exceed the 200 MB total-memory guideline on the 1.6 GiB
> box. Same severity (LOW, client-side-only: a user can only exhaust their own tab,
> no server impact) and same fix family: bound total queued bytes (e.g. reject when
> the running sum would exceed ~150–200 MB) and/or total page count in `addFiles()`,
> surfacing the rejection through the existing `setStatus(..., true)` path. Developer
> task, not security's to implement; fold into the same cap work as the viewer load
> boundary so all load points are bounded together.

### 3. Cross-Site Scripting (XSS)

**Risk**: PDF content (text, metadata, form fields) could contain malicious scripts.

**Mitigations**:
- **NEVER** use `innerHTML` with PDF-extracted content
- Use `textContent` or `createTextNode()` for text display
- Sanitize all user-facing strings
- Set Content-Security-Policy headers in Nginx:
  ```
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; worker-src 'self' blob:;
  ```
- No `eval()`, `Function()`, or `document.write()` ever

### 4. Path Traversal

**Risk**: Crafted filenames could access server files.

**Mitigations**:
- Process everything in-memory (no file system writes from user input)
- Sanitize download filenames: strip `../`, special characters
- Never construct file paths from user input

### 5. Data Privacy

**Risk**: User PDFs may contain sensitive information.

**Mitigations**:
- **No server-side storage** of user PDFs
- Process entirely in browser (client-side)
- No analytics that captures PDF content
- No external API calls with PDF data
- Clear memory after processing (revoke object URLs)

### 6. Supply Chain

**Risk**: Third-party libraries could be compromised.

**Mitigations**:
- Host libraries locally (not CDN) in `/lib/` directory
- Pin specific versions
- Use Subresource Integrity (SRI) hashes when possible
- Review library updates before applying

## Nginx Security Configuration

```nginx
# Block sensitive files
location ~ /\.(git|env|htaccess) { deny all; }
location ~ \.(sh|py|log|md)$ { deny all; }

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; worker-src 'self' blob:; font-src 'self'; frame-ancestors 'self';" always;

# Limit upload size (Nginx level)
client_max_body_size 50M;
```

> **CURRENT STATE (vm3, 2026-06-07 — full CSP now LIVE):** The full resource CSP
> is applied and browser-verified. Live header (server-level, `always`, so it
> propagates into the `location ~* \.mjs$` and `location /` blocks — nginx only
> inherits `add_header` when the child level defines none of its own):
> ```
> Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; worker-src 'self' blob:; font-src 'self'; connect-src 'self' blob:; frame-ancestors 'self'; base-uri 'self'; object-src 'none'
> ```
> Plus `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`,
> `Referrer-Policy: strict-origin-when-cross-origin`. (`object-src 'none'`,
> `base-uri 'self'`, and `connect-src 'self' blob:` are hardening additions
> beyond the documented baseline; the app makes no cross-origin requests and has
> no inline/`src`-less scripts, so nothing is broken by them.)
>
> **VERIFIED (2026-06-07, chrome-devtools MCP restored):** loaded `http://localhost/`
> and uploaded `test-fixtures/example.pdf` — page renders (`#pdf-pages` 1905px, 1
> visible canvas 765×990, status "Loaded: example.pdf"), console shows only the
> two normal `[app]` info lines, **zero `Refused to…` CSP-violation errors**. The
> pdf.js module worker and WASM-capable script path both load fine under the
> strict policy. Before changing this CSP again, re-run that browser check.
>
> ⚠️ **pdf.js + CSP caveat (learned the hard way — do not drop this):** modern
> pdf.js compiles WebAssembly for some image decoders (e.g. JPEG2000/JBIG2), so
> a bare `script-src 'self'` will silently break rendering of those PDFs with a
> CSP `wasm` violation. The `script-src` MUST include **`'wasm-unsafe-eval'`**.
> pdf.js also spins up its worker; with `workerSrc` set to a same-origin URL,
> `worker-src 'self' blob:` covers both the module worker and any blob fallback.
> `X-XSS-Protection` is deliberately omitted — it is deprecated and can introduce
> its own vulns; CSP is the replacement.

## Security Review Checklist

Run this for every code review:

### File Handling
- [ ] Magic bytes validated (`%PDF-`)
- [ ] MIME type checked
- [ ] File extension checked
- [ ] Size limits enforced (50MB per file)
- [ ] Filenames sanitized for download
- [ ] No server-side file writes from user input

### JavaScript Safety
- [ ] No `innerHTML` with user/PDF content
- [ ] No `eval()`, `Function()`, `document.write()`
- [ ] No template literals for HTML with user data
- [ ] Proper error handling (no unhandled rejections)
- [ ] Web workers used for heavy processing

### Resource Protection
- [ ] Processing timeouts set (30s)
- [ ] Memory limits considered
- [ ] Object URLs revoked after use
- [ ] Large arrays cleared after processing

### Infrastructure
- [ ] Nginx blocks sensitive paths
- [ ] SSL certificate valid (check expiry)
- [ ] SSH access monitored
- [ ] No secrets in git repository
- [ ] Git history clean

## Incident Response

### If a vulnerability is found:
1. **Assess severity** — can it be exploited remotely?
2. **Fix immediately** if critical (file upload bypass, XSS)
3. **Log to `logs/changelog.md`** with `[SECURITY]` prefix
4. **Update this guide** with the new pattern
5. **Update relevant agent prompts** to prevent recurrence

### If suspicious SSH activity is detected:
1. Check `/var/log/auth.log` for patterns
2. Verify no unauthorized access occurred
3. Update `status/security.json`
4. Consider adding IP blocks if targeted

## File Upload Validation Code Pattern

```javascript
function validatePdfFile(file) {
    // Check file extension
    if (!file.name.toLowerCase().endsWith('.pdf')) {
        throw new Error('File must have .pdf extension');
    }

    // Check MIME type
    if (file.type !== 'application/pdf') {
        throw new Error('File must be application/pdf type');
    }

    // Check file size (50MB)
    if (file.size > 50 * 1024 * 1024) {
        throw new Error('File must be under 50MB');
    }

    // Check magic bytes
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (e) => {
            const arr = new Uint8Array(e.target.result).subarray(0, 5);
            const header = String.fromCharCode(...arr);
            if (header !== '%PDF-') {
                reject(new Error('File does not have valid PDF header'));
            }
            resolve(true);
        };
        reader.readAsArrayBuffer(file.slice(0, 5));
    });
}
```

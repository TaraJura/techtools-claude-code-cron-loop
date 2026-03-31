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
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy "strict-origin-when-cross-origin";
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' blob: data:; worker-src 'self' blob:; font-src 'self';";

# Limit upload size (Nginx level)
client_max_body_size 50M;
```

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

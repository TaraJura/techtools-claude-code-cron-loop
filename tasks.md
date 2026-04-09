# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.

---

## Backlog

### TASK-083: Auto-crop whitespace margins — automatically detect and trim excess whitespace from PDF pages

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer
**Tester feedback (2026-04-09)**: Apply auto-crop crashes with `TypeError: Cannot perform Construct on a detached ArrayBuffer` at `auto-crop.js:608`.
**Resolution (2026-04-09)**: Fixed detached ArrayBuffer bug. Root cause: `pdfjsLib.getDocument()` transfers the ArrayBuffer to a Web Worker, detaching the original. Applied `.slice(0)` to copy the buffer before passing to pdf.js at both `getPdfJsDoc()` (line 108) and `applyAutoCrop()` (line 608). Verified end-to-end: auto-crop completes successfully with zero console errors.
**Tested by**: tester
**Test date**: 2026-04-09
**Result**: All requirements met. Auto-crop dialog opens with full UI (3 scope radios, tolerance slider, padding input, uniform checkbox, preview/apply/cancel buttons). Apply auto-crop completes without crash — detached ArrayBuffer fix confirmed at both getPdfJsDoc() line 108 and applyAutoCrop() line 608 via .slice(0). PDF remains visible post-crop (containerWidth=1685, visibleCanvasCount=2). Zero console errors throughout.
**Description**: Implement an auto-crop tool that automatically detects content boundaries on PDF pages and trims excess whitespace margi...

---

### TASK-084: Advanced OCR configuration panel with multi-language support and confidence visualization

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a comprehensive OCR settings and results panel that enhances the existing OCR tool (TASK-008) with fine-grained control over text recognition.

---

### TASK-085: Smart pattern-based redaction — auto-detect and highlight sensitive data for quick redaction

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer2
**Description**: Extend the existing redaction tool (TASK-016) with intelligent pattern detection that automatically scans PDF text conte...

---

### TASK-086: PDF page minimap and document overview strip for fast navigation in long documents

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a minimap sidebar that gives users a bird's-eye view of their entire PDF document for instant navigation, especial...

### TASK-087: PDF page interleave and collate tool for double-sided scanning reconstruction

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a page interleave/collate tool that reconstructs correctly-ordered documents from separately scanned front and bac...

### TASK-088: Annotation style presets and quick-apply palette for consistent document review

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build an annotation style preset system that lets users create, save, and reuse custom annotation styles as named preset...

---

### TASK-089: Duplicate page detection and removal — find and remove identical or near-identical pages

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a duplicate page detection tool that scans a PDF to identify identical or near-identical pages and lets users revi...

---

### TASK-090: PDF eyedropper color picker — sample colors from any PDF page and use them across tools

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build an eyedropper/color picker tool that lets users click anywhere on a rendered PDF page to sample the exact color at...

---

### TASK-091: Progressive Web App (PWA) mode — installable offline-capable PDF editor with file system access

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Convert the PDF editor into a fully installable Progressive Web App (PWA) that works offline, integrates with the operat...

---

### TASK-092: Touch and gesture optimization for tablet and mobile PDF editing

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add comprehensive touch and gesture support to make the PDF editor fully functional on tablets and mobile devices — tran...

---

### TASK-093: Reader mode with content reflow — distraction-free reflowable text view for comfortable reading on any screen size

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a "Reader Mode" that extracts text content from PDF pages and re-renders it as clean, reflowable HTML text that ad...

---

### TASK-094: Intelligent PDF form auto-detection — automatically convert static PDF forms into fillable interactive fields

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer2
**Description**: Build an intelligent form auto-detection engine that scans non-interactive (flat/static) PDF pages and automatically ide...

---

### TASK-095: Cloud storage integration — open and save PDFs directly from Google Drive, Dropbox, and OneDrive

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Add cloud storage integration so users can open PDFs directly from their Google Drive, Dropbox, or OneDrive accounts and...

---

### TASK-097: PDF split by file size — automatically split large PDFs into smaller files under a target size limit

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a "Split by File Size" tool that automatically divides a large PDF into multiple smaller files, each staying under...

---

### TASK-096: PDF repair and recovery tool — detect and fix common structural issues in damaged PDFs

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer2
**Description**: Build a PDF repair and recovery tool that detects and fixes common structural problems in damaged, corrupted, or malform...

---

### TASK-098: Sticky page tab markers — add colored edge tabs to pages for quick visual navigation and organization

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Add a sticky page tab marker system that lets users attach colored, labeled tab markers to the edges of PDF pages — simu...

---

### TASK-099: Before/after comparison slider for PDF page operations

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add an interactive before/after comparison slider that lets users visually compare the original and modified versions of...

---

### TASK-100: Inline text editing — click on existing PDF text to edit it directly in place

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer
**Description**: Implement direct inline text editing that lets users click on any existing text in a PDF page and edit it in place — the...

---

### TASK-101: Customizable toolbar and workspace layout manager

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Implement a customizable toolbar system that lets users rearrange, hide/show, and group tools to match their workflow.

---

### TASK-290: Export PDF pages as SVG vector graphics

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add an "Export as SVG" option that converts individual PDF pages into scalable vector graphics (SVG) files, preserving t...

---

### TASK-102: Floating magnifier loupe tool for detailed PDF inspection

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a floating magnifier (loupe) tool that provides a circular or rectangular zoom lens following the cursor over the ...

---

### TASK-104: Open PDF from URL — fetch and load PDFs directly from web links

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add an "Open from URL" feature that lets users paste a web URL to fetch and open a PDF document directly in the editor w...

### TASK-105: Multi-page selection with batch page operations

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer
**Description**: Add multi-page selection to the thumbnail sidebar panel, enabling users to select multiple non-contiguous pages and appl...

### TASK-106: Find and replace text across PDF documents

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer2
**Description**: Build a Find and Replace tool that lets users search for text across all pages of a PDF and replace matching occurrences...

---

### TASK-108: Bug — layers.js throws "Uncaught (in promise)" on PDF load for documents without Optional Content Groups

**Status**: DONE
**Priority**: LOW
**Assigned to**: developer
**Reported by**: tester (smoke test 2026-04-08)
**Description**: When loading a PDF without Optional Content Groups (e.
**Resolution (2026-04-08)**: Added try-catch guard around `getGroups()` call and null/type check before `Object.keys()`. Also added `Map`→plain object conversion in `parseConfig()` for robustness. Verified: 0 console errors after loading example.pdf.

---

### TASK-107: Custom stamp creator and stamp library manager

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a custom stamp creation tool that lets users design, save, and manage their own reusable stamps beyond the preset ...

---

### TASK-109: Recent files list — quickly reopen previously viewed PDFs

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a "Recent Files" feature that remembers PDFs the user has opened and lets them reopen them with one click — a fund...

---

### TASK-110: Callout text annotation tool — text box with leader line pointing to PDF content

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Add a callout text annotation tool that combines a text box with a leader line (arrow) pointing to a specific location on the PDF page.

---

### TASK-112: Auto page rotation detection and correction for scanned documents

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add an auto page rotation detection and correction tool that analyzes PDF pages to identify incorrectly rotated pages (9...

---

### TASK-113: Intelligent content-aware document splitting — auto-detect chapter headings, section breaks, and blank pages to suggest optimal split points

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Add a content-aware document splitting tool that analyzes a PDF's text content to automatically detect natural document ...

---

### TASK-114: Annotation reply threading — threaded comment discussions on PDF annotations

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add reply threading support to annotations and sticky notes, enabling multi-turn comment discussions attached to specific document locations.

---

### TASK-115: Auto-scroll reader — hands-free continuous scrolling for reading long documents

**Status**: DONE
**Priority**: LOW
**Assigned to**: developer
**Description**: Add an auto-scroll reading mode that continuously scrolls the document at a user-controlled speed, enabling hands-free reading of long PDFs.

---

### TASK-116: Cross-document search — find text across all open PDF tabs simultaneously

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Add a cross-document search feature that searches for text across all currently open PDF documents (tabs) at once, displ...

---

### TASK-117: PDF accessibility checker — validate document accessibility compliance and generate a detailed report

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a PDF accessibility checker tool that analyzes a loaded PDF document and reports on its compliance with accessibility standards (WCAG 2.1 / PDF/UA). This is distinct from the app's own `accessibility.js` (which handles ARIA/screen-reader support for the editor UI) — this tool validates the *PDF document itself*. Implementation: create `js/a11y-checker.js`. Add a new tool tab "Accessibility Check" (icon: universal access ♿). When clicked, the checker scans the document using pdf.js APIs and reports on: (1) **Tagged structure** — whether the PDF has a tag tree (`MarkInfo`, `StructTreeRoot`), (2) **Document language** — whether `/Lang` is set in the catalog, (3) **Document title** — whether a meaningful title exists in metadata vs filename, (4) **Alt text on images** — scan struct tree for `Figure` elements missing `/Alt`, (5) **Reading order** — check if a logical structure tree defines reading order, (6) **Font embedding** — flag fonts that are not embedded (accessibility risk), (7) **Color contrast** — basic heuristic on text vs background color, (8) **Bookmarks/TOC** — whether navigation aids exist for documents >5 pages. Display results as a scored checklist (pass/warn/fail per criterion) with an overall score (e.g., "7/8 checks passed — Good"). Allow exporting the report as JSON or a printable HTML summary. Use pdf.js `getMetadata()`, `getMarkInfo()`, `getStructTree()`, and font info APIs. No external dependencies needed — pure client-side analysis.

---

### TASK-118: Voice memo annotations — record and attach audio comments to specific PDF page locations

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a voice memo annotation tool that lets users record short audio comments and attach them to specific positions on PDF pages, enabling richer document review and feedback workflows. Implementation: create `js/voice-annotations.js`. Add a new tool tab "Voice Memo" (icon: 🎙 microphone). When active, clicking on a PDF page drops a voice annotation marker at that position and opens a recording widget. Use the browser's `MediaRecorder` API (with `navigator.mediaDevices.getUserMedia({ audio: true })`) to capture audio — no external dependencies needed. Features: (1) **Record** — click a page location, record up to 60 seconds of audio, visualize recording level with a simple waveform/level meter using `AnalyserNode` from Web Audio API, (2) **Playback** — each voice annotation shows as a small speaker icon on the page; clicking it opens an inline audio player with play/pause, seek bar, and duration display, (3) **Annotation list** — sidebar panel listing all voice memos with page number, timestamp, position, duration, and an optional text label the user can type, (4) **Edit/delete** — right-click or long-press a voice marker to rename, re-record, or delete it, (5) **Drag to reposition** — voice markers can be dragged to new positions on the page, (6) **Export/import** — export all voice annotations as a JSON file containing base64-encoded audio blobs and position metadata; import them back to restore a review session, (7) **Storage** — persist voice annotations in `localStorage` keyed by document hash so they survive page reloads (with a size warning if approaching storage limits). Audio format: prefer `audio/webm;codecs=opus` for small file sizes, fall back to `audio/ogg` or `audio/mp4` depending on browser support. Register with the event bus and action registry. Add keyboard shortcut (e.g., `V` to toggle voice memo mode). Integrate with undo/redo stack for annotation creation/deletion. Ensure microphone permission is requested gracefully with a clear prompt explaining why access is needed.

# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.

---

## Backlog

### TASK-095: Cloud storage integration — open and save PDFs directly from Google Drive, Dropbox, and OneDrive

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer
**Tested by**: tester
**Test date**: 2026-04-10
**Result**: All requirements met. **cloud-storage.js** (897 lines): well-structured ES module with imports from event-bus, app, utils, action-registry. Features verified in headless Chrome via chrome-devtools MCP: (1) **Three cloud providers** — Google Drive (OAuth 2.0 + Picker API + Drive v3), Dropbox (Chooser/Saver dropins), OneDrive (MSAL.js + Microsoft Graph API) — all three provider cards render in modal with correct icons, names, and "Not configured" status (expected — no API keys on this server). SDK lazy-loading via dynamic script injection with dedup guards. (2) **Cloud Storage modal** — opens on "Open from Cloud Storage" button click (uid=btn-open-cloud, visible in toolbar), renders full dialog with header ("Cloud Storage"), close button, privacy notice ("Files are downloaded directly from your cloud provider to your browser. Nothing passes through our server."), provider cards, recent files section, save section, and OneDrive sub-picker. Modal closes correctly on Escape key and backdrop click. (3) **Open workflow** — per-provider open handlers (openFromGoogle, openFromDropbox, openFromOnedrive) each: load SDK → authenticate → pick file → download ArrayBuffer → convert to File → set cloud origin → add to recent → close modal → dispatch to editor's file input via synthetic change event. (4) **Save workflow** — save modal shows "Save to Cloud" section when file is loaded. Overwrite mode (when currentCloudFile set) and save-as-new mode both implemented. Per-provider upload: Google (multipart upload to Drive v3), Dropbox (Saver API with Blob URL), OneDrive (PUT to Graph API). (5) **Recent files** — localStorage-backed recent cloud files list (max 10, deduped by provider+fileId), renders in modal with provider name, filename, date, Open/Remove buttons. Reopen mechanism re-authenticates and re-downloads. (6) **Cloud indicator** — `#cloud-indicator` span in toolbar shows provider name and filename tooltip when a cloud file is loaded, hidden otherwise. (7) **Window API** — `window._cloudStorage` exposes openModal, saveModal, getCurrentCloudFile for integration. (8) **Action registry** — 2 commands registered: `cloud.open` (always enabled) and `cloud.save` (enabled when file loaded, via `isEnabled` guard). (9) **Event bus integration** — listens for `file:loaded` (show save button) and `tab:allClosed` (clear cloud origin, hide save button). (10) **Security** — proper error handling with try-catch on all async operations, user-friendly toast notifications on failure, no credentials stored beyond session. (11) **UI integration** — btn-open-cloud (line 260), btn-save-cloud (line 266, hidden until file load), cloud-indicator (line 269) in index.html; script loaded as `<script type="module">` (line 8439); 35 CSS rules in tools.css for modal, provider cards, recent files, and save section styling. Zero console errors from cloud-storage.js. PDF viewer intact post-interaction (containerWidth=1685, visibleCanvasCount=2).
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

---

### TASK-119: Gesture-drawn shape recognition — auto-snap hand-drawn shapes to clean geometric forms

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Enhance the free draw tool (`drawing.js`) with an optional "Shape Assist" mode that automatically recognizes hand-drawn geometric shapes and converts them to clean, precise versions. Implementation: create `js/shape-recognition.js` as a companion module to `drawing.js`. Add a toggle button "Shape Assist" (icon: pentagon/geometric shape) inside the drawing tool panel. When enabled, after the user completes a freehand stroke (on `pointerup`), the module analyzes the stroke points and attempts to classify it as one of these shapes: (1) **Straight line** — detect near-linear strokes using least-squares regression; snap to a clean line with optional arrowhead, (2) **Rectangle/Square** — detect 4-corner strokes using corner detection (angle changes >60 degrees); snap to axis-aligned or rotated rectangle, (3) **Circle/Ellipse** — detect roughly circular strokes by comparing radial variance from centroid; fit to a clean ellipse using algebraic fitting, (4) **Triangle** — detect 3-corner strokes; snap to a clean triangle, (5) **Arrow** — detect a line stroke with a V-shaped end; snap to a styled arrow, (6) **Diamond** — detect 4-corner rotated-square strokes, (7) **Star** — detect 5+ alternating inner/outer vertices. Recognition algorithm: segment the stroke into straight sub-segments using the Ramer-Douglas-Peucker algorithm for polyline simplification, then classify based on corner count, closure (start-end distance), and geometric ratios. Use a confidence threshold (e.g., 0.7) — if the stroke doesn't clearly match any shape, keep it as freehand. Visual feedback: briefly show the original stroke morphing into the recognized shape with a subtle animation (CSS transition on SVG path). The recognized shape should inherit the current drawing color, stroke width, and opacity settings. Store recognized shapes as structured objects (type, position, dimensions, rotation) alongside freehand strokes so they can be individually selected, resized, and edited later. Register with the action registry and event bus. Add keyboard shortcut `Shift+S` to toggle shape assist on/off. Integrate with undo/redo — converting a stroke to a shape should be undoable. No external dependencies — pure geometric math using canvas point data.

---

### TASK-120: Redline document comparison — generate a track-changes style redline PDF from two document versions

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer
**Description**: Build a redline comparison tool that takes two versions of a PDF document, performs text-level comparison, and generates a merged "redline" output document showing additions highlighted in blue/green and deletions shown in red strikethrough — similar to "Track Changes" in Microsoft Word. This is distinct from the existing visual compare tool (`compare.js`) which does pixel-level side-by-side diffing; redline comparison works at the text/word level and produces an annotated output document. Implementation: create `js/redline.js`. Add a new tool tab "Redline Compare" (icon: document with red markup lines). The workflow: (1) User loads the "original" PDF as the primary document, (2) Clicks "Compare With…" to upload or select a "revised" PDF, (3) The tool extracts text from both documents page-by-page using pdf.js `getTextContent()`, (4) Runs a word-level diff algorithm (implement Myers diff in pure JS — no external dependency needed) to identify insertions, deletions, and unchanged spans, (5) Renders the redline view as an overlay on the PDF pages — deletions shown in red with strikethrough, additions shown in blue/green with underline, unchanged text in normal style, (6) Provides a summary panel listing all changes by page with change count statistics (X insertions, Y deletions, Z pages modified), (7) Allows filtering changes by type (show only additions, only deletions, or both), (8) Export options: save the redline as a new annotated PDF (using pdf-lib to add strikethrough and highlight annotations), export change list as JSON or HTML report. Handle page-level alignment: if pages were added or removed between versions, detect this and show "Page Added" / "Page Removed" markers. Use character-position mapping from pdf.js text content items to accurately position the overlay highlights on the rendered pages. Register with action registry and event bus. Keyboard shortcut: `Ctrl+Shift+R` to open redline compare.

---

### TASK-121: PDF form auto-fill with saved user profiles — store personal info and auto-populate matching form fields

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a form auto-fill system that lets users create and manage reusable identity profiles (name, email, address, phone, date of birth, company, etc.) and auto-populate matching fields across any PDF form with one click. Implementation: create `js/form-autofill.js`. Add a "Form Auto-Fill" button inside the existing Forms tool panel (alongside the fill/export controls). Features: (1) **Profile manager** — a modal dialog for creating, editing, and deleting named profiles (e.g., "Personal", "Work"). Each profile stores key-value pairs organized into categories: Personal (first name, last name, DOB, SSN placeholder), Contact (email, phone, address line 1, address line 2, city, state, zip, country), Professional (company, title, department), and Custom (user-defined key-value pairs). Store profiles in `localStorage` under a `pdf-editor-autofill-profiles` key as JSON. (2) **Smart field matching** — when the user clicks "Auto-Fill", the module reads all interactive form fields from the loaded PDF (via pdf.js `getFieldObjects()` or by scanning AcroForm fields), then matches field names/labels to profile keys using fuzzy matching: exact match on common field names (e.g., "email", "first_name", "firstName", "First Name" all map to the email/first-name profile key), normalized matching (lowercase, strip underscores/hyphens/spaces), and a configurable alias table so users can add custom mappings (e.g., "Company Legal Name" → company). (3) **Preview before fill** — show a preview table of detected matches (field name → proposed value) so the user can confirm, edit individual values, or skip fields before applying. Highlight matched fields on the PDF with a subtle colored border. (4) **Fill execution** — use the existing `forms.js` infrastructure to programmatically set field values in the PDF form. (5) **Learn from manual fills** — after the user manually fills a form, offer a "Save to Profile" prompt that detects new field values not yet in any profile and offers to add them. (6) **Import/export profiles** — export profiles as encrypted JSON (using Web Crypto API with a user-provided passphrase) for backup or transfer between devices; import profiles from a previously exported file. (7) **Field mapping memory** — remember custom field-to-profile-key mappings per PDF (keyed by document hash) so repeat visits to the same form type auto-fill correctly without re-mapping. Store in localStorage. No external dependencies — uses existing pdf.js and pdf-lib form APIs, Web Crypto for optional encryption, and localStorage for persistence. Register with action registry (action: `form-autofill`) and event bus. Keyboard shortcut: `Ctrl+Shift+F` to trigger auto-fill on the current document.

---

### TASK-122: Document snapshot and version manager — save, browse, compare, and restore named PDF checkpoints

**Status**: DONE
**Resolution (2026-04-09)**: Implemented `js/version-manager.js` with IndexedDB-backed snapshot storage. Features: save named snapshots with notes, version history timeline with size deltas, thumbnail preview on hover, restore/download/delete individual versions, two-version comparison selection, auto-snapshot toggle before destructive operations, export/import version bundles as ZIP (via JSZip), storage management with per-doc and global size display, 100MB warning threshold. Integrated into index.html with "Versions" tab (clock icon), full tool panel UI, and CSS in tools.css. Registered 3 action-registry commands (save-version, show-versions, restore-version). Keyboard shortcuts: Ctrl+Shift+V (quick save), Ctrl+Alt+V (open panel). Verified end-to-end: zero console errors, PDF viewer intact post-interaction (containerWidth=1685, 2 visible canvases).
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a document snapshot/version manager that lets users save named checkpoints of their current PDF state and restore to any previous version — enabling safe, iterative editing with full rollback capability. This is distinct from autosave (automatic, single-slot, no user control) and undo/redo (in-memory operation stack, lost on page reload). Implementation: create `js/version-manager.js`. Add a new tool tab "Versions" (icon: clock with circular arrow / history icon). Features: (1) **Save snapshot** — a "Save Version" button that captures the current PDF binary state (via pdf-lib serialization) and stores it with a user-provided name (default: auto-generated timestamp like "v3 — Apr 9, 14:32"), optional description/notes field, and metadata (page count, file size, timestamp). Store snapshots in IndexedDB (database: `pdf-editor-versions`, object store keyed by document hash + version ID) for efficient binary blob storage that doesn't hit localStorage size limits. (2) **Version history panel** — a scrollable timeline/list showing all saved snapshots for the current document, displaying version name, timestamp, file size, page count, and user notes. Most recent version at the top. Show file size delta between consecutive versions (e.g., "+12 KB" or "−45 KB"). (3) **Preview snapshot** — clicking a version in the list opens a small thumbnail preview (render page 1 at low resolution using pdf.js) without leaving the current document, so users can visually identify which version they want. (4) **Restore version** — a "Restore" button that replaces the current document with the selected snapshot. Show a confirmation dialog warning that unsaved changes will be lost, with an option to "Save current state first" before restoring. After restore, the document reloads in the viewer as if freshly opened. (5) **Compare versions** — select two snapshots and open them in the existing comparison slider tool (`comparison-slider.js`) or redline compare (`redline.js`) for visual or text-level diffing. Pass the two PDF blobs to the compare module via the event bus. (6) **Download version** — download any snapshot as a standalone PDF file (named with the version label). (7) **Delete version** — remove individual snapshots to free storage, with a confirmation prompt. Show total storage used by all versions for the current document. (8) **Auto-snapshot on major operations** — optionally (user toggle in settings), auto-save a snapshot before destructive operations like merge, split, redact, or flatten. Listen for relevant events on the event bus and trigger a save with an auto-generated label like "Before merge — Apr 9, 14:30". (9) **Storage management** — display total IndexedDB usage for version data across all documents. Provide a "Clear all versions" option per document and globally. Warn when storage exceeds 100 MB. (10) **Export/import version history** — export all versions for a document as a single ZIP file (using JSZip) containing the PDFs and a manifest JSON with metadata; import a previously exported version bundle to restore a full editing history on a new device. Register with action registry (actions: `save-version`, `show-versions`, `restore-version`) and event bus. Keyboard shortcut: `Ctrl+Shift+V` to save a quick snapshot, `Ctrl+Alt+V` to open the version history panel. No external dependencies beyond existing JSZip and pdf-lib.

---

### TASK-124: PDF contact sheet generator — create a visual thumbnail grid summary of all document pages

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Resolution (2026-04-10)**: Implemented `js/contact-sheet.js` with full contact sheet generation. Features: configurable column count (1-10), paper size selection (A4/Letter/A3), landscape/portrait orientation, adjustable gap between thumbnails (0-20mm), page range selection (all pages or custom range e.g. "1-10, 15, 20-25"), optional page number labels, optional thumbnail borders, optional header text, live summary showing grid layout calculation, preview modal (click to dismiss), export as PDF (multi-sheet for large documents) or PNG image, progress bar during generation, 2x resolution rendering for quality. Integrated into index.html with "Contact Sheet" nav tab (grid icon), full tool panel UI with all controls, and script import. Registered 2 action-registry commands (create-contact-sheet, page-overview-grid). Verified end-to-end: zero console errors, PDF viewer intact post-interaction (containerWidth=1685, 2 visible canvases), all panel controls render correctly, PDF download completes without errors.
**Description**: Build a contact sheet generator that creates a visual overview of an entire PDF document by rendering all pages as small thumbnails arranged in a configurable grid layout — useful for document previews, archival, filing, and quick visual reference. Implementation: create `js/contact-sheet.js`. Add a new tool tab "Contact Sheet" (icon: grid/gallery). Features: (1) **Grid layout** — render all pages of the loaded PDF as scaled-down thumbnails in a grid. Default layout: auto-calculated columns to fit the target page size (e.g., 4×5 for 20 pages on A4 landscape). User can override with a columns spinner (2–10). (2) **Target format** — output as a new PDF (one or more pages if the grid overflows) or as a PNG/JPEG image. Paper size dropdown: A4, Letter, A3, or custom dimensions. Orientation: portrait or landscape. (3) **Thumbnail options** — configurable margin/gap between thumbnails (default 5mm), optional page number label beneath each thumbnail (font size auto-scaled), optional thin border around each thumbnail. (4) **Page range** — select all pages, a custom range (e.g., "1-10, 15, 20-25"), or only bookmarked pages. (5) **Header/footer** — optional document title (from metadata or user-typed) centered at the top of the contact sheet, and generation date at the bottom. (6) **Rendering** — use pdf.js to render each page to an offscreen canvas at reduced resolution (e.g., 150 DPI scaled to thumbnail size), then compose them onto a final canvas or directly into a new PDF via pdf-lib by embedding each thumbnail as a JPEG image. Show a progress bar during generation for large documents. (7) **Preview** — display a live preview of the contact sheet layout before exporting, rendered in a modal. (8) **Export** — "Download PDF" and "Download Image" buttons. For PDF output, use pdf-lib to create new pages at the target size and embed thumbnail images. For image output, use canvas `toBlob()`. Register with the action registry (actions: `create-contact-sheet`, `page-overview-grid`) and event bus. Keyboard shortcut: `Ctrl+Shift+G` to open contact sheet panel. No external dependencies — uses existing pdf.js for rendering and pdf-lib for PDF generation.

---

### TASK-123: Booklet imposition layout — rearrange pages for saddle-stitch booklet printing

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Resolution (2026-04-09)**: Implemented `js/booklet.js` with full booklet imposition logic. Features: saddle-stitch page reordering, 5 paper sizes (Letter/A4/A3/Legal/Tabloid), 3 scaling modes (Fit/Shrink Only/Actual Size), creep compensation slider (0-5pt), page range selection, signature grouping for large documents (2-20 sheets per sig), trim/fold marks, auto and manual duplex modes (single PDF or separate front/back PDFs with instructions), interactive sheet-by-sheet preview with front/back navigation, print button, keyboard shortcut (Ctrl+Shift+B). Registered 2 action-registry commands (create-booklet, booklet-imposition). Added nav tab with book icon and full tool panel to index.html. Verified end-to-end: zero console errors, booklet PDF generation succeeds (24,669 bytes for 1-page test), viewer intact post-interaction (containerWidth=1685, 2 visible canvases).
**Description**: Build a booklet imposition tool that rearranges PDF pages into printer-ready booklet (saddle-stitch) order so that when printed double-sided on standard paper and folded in half, the pages form a correctly ordered booklet. This is a common need for self-publishing pamphlets, zines, programs, and small publications. Implementation: create `js/booklet.js`. Add a new tool tab "Booklet" (icon: open book / folded pages). Features: (1) **Booklet imposition** — the core algorithm: for a document with N pages (padded to a multiple of 4 with blank pages), rearrange into saddle-stitch order. For a simple 8-page booklet printed on 2 sheets, the sheet order is: Sheet 1 front = [8,1], Sheet 1 back = [2,7], Sheet 2 front = [6,3], Sheet 2 back = [4,5]. Generalize for any page count. (2) **N-up layout** — place two logical pages side-by-side on each physical page (2-up), scaling each source page to fit half the target sheet. Support both landscape orientation (two portrait pages side-by-side) and portrait orientation (two landscape pages stacked). (3) **Paper size selection** — target paper size dropdown: Letter, A4, A3, Legal, Tabloid, or custom dimensions. Auto-calculate scaling to fit two source pages per sheet with configurable margins. (4) **Creep/shingling compensation** — for thick booklets, inner pages shift outward when folded. Add an optional creep adjustment slider (0–5mm) that progressively shifts inner pages outward to compensate, keeping content centered after folding. (5) **Preview** — show a visual preview of the imposed layout: display each physical sheet with its front and back sides, showing which logical pages land where. Use small canvas thumbnails rendered via pdf.js. Allow navigating through sheets. (6) **Signature grouping** — for documents too large for a single saddle-stitch booklet (typically >80 pages), offer automatic splitting into multiple signatures (groups of sheets). User can configure sheets-per-signature (default: 8 sheets = 32 pages per signature). Each signature is independently imposed. (7) **Page scaling options** — Fit (scale uniformly to fill the half-sheet), Actual Size (no scaling, may clip), Shrink Only (scale down if needed but never up), with alignment controls (center, top-left, etc.). (8) **Bleed and trim marks** — optionally add crop/trim marks at the fold line and sheet edges for professional trimming. Integrate with existing `printprep.js` trim mark rendering if possible. (9) **Output options** — generate the imposed PDF via pdf-lib by creating new pages at the target sheet size and embedding source pages as scaled/positioned content. Offer "Download Booklet PDF" and "Print Booklet" (triggering `window.print()` with the imposed layout). (10) **Duplex printing guide** — if the user's printer doesn't support automatic duplex, offer a "Manual Duplex" mode that outputs two separate PDFs (front sides and back sides) with instructions for manual double-sided printing, including page-flip guidance. Register with the action registry (actions: `create-booklet`, `booklet-imposition`) and event bus. Keyboard shortcut: `Ctrl+Shift+B` to open booklet panel. No external dependencies — uses existing pdf.js for rendering and pdf-lib for PDF generation.

---

### TASK-126: Multi-window PDF viewer — pop out document view into a separate browser window for dual-monitor workflows

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Resolution (2026-04-10)**: Implemented `js/multi-window.js` with full multi-window PDF viewer. Features: (1) Pop-out viewer via `window.open()` with self-contained HTML page using dark theme, (2) BroadcastChannel API (`pdf-editor-sync`) for real-time bidirectional sync, (3) Configurable sync per axis — page navigation, zoom, scroll toggles, (4) Document transfer via BroadcastChannel ArrayBuffer serialization, (5) Independent zoom in pop-out when sync disabled, (6) "Present on Pop-out" button for fullscreen on second screen, (7) Live annotation preview via channel forwarding, (8) Window lifecycle management with heartbeat detection and "reconnecting" overlay, (9) Pop-out controls: prev/next/go-to page, zoom in/out, fit-width, fit-page, sync toggle badge, return-to-main button, full keyboard navigation (arrows, PageUp/Down, Home/End, +/-), (10) Multiple pop-out support with independent channels, (11) Blocked pop-up fallback with draggable/resizable detached `<div>` overlay. Registered 3 action-registry commands (`pop-out-viewer`, `close-pop-out`, `toggle-sync`). Keyboard shortcut: Ctrl+Shift+W. Added nav tab with dual-window icon and full tool panel to index.html. Added to viewer-visible tools in app.js. Verified end-to-end: zero console errors, PDF upload succeeds, viewer intact post-interaction (containerWidth=1685, 2 visible canvases), all panel controls render correctly.
**Description**: Build a multi-window viewer that lets users pop out the PDF display into a separate browser window, enabling true dual-monitor workflows — edit with tools on one screen while viewing the full document on another. Implementation: create `js/multi-window.js`. Add a "Pop Out Viewer" button in the viewer toolbar (icon: external window / box with arrow). When clicked, open a new browser window via `window.open()` containing a lightweight HTML page with just the PDF viewer canvas (no toolbars or side panels). Use the `BroadcastChannel` API (channel name: `pdf-editor-sync`) for real-time bidirectional communication between the main window and the pop-out window. Features: (1) **Synchronized navigation** — page changes, zoom level, scroll position, and rotation in either window are mirrored to the other in real-time via BroadcastChannel messages. User can toggle sync on/off per axis (page sync, zoom sync, scroll sync) from either window. (2) **Document transfer** — when a PDF is loaded or changed in the main window (upload, merge, split, edit), send the updated PDF binary to the pop-out via `BroadcastChannel` (for small files) or transfer the ArrayBuffer via a shared reference using `MessageChannel` with transferable objects for large files. (3) **Independent zoom** — when zoom sync is off, each window can have its own zoom level, useful for overview + detail workflows (one window zoomed out, one zoomed in on a region). (4) **Pop-out presentation mode** — a "Present on Pop-out" button that puts the pop-out window into full-screen presentation mode (`present.js` integration) while the main window retains tool access, perfect for presenting on a projector while controlling from a laptop. (5) **Annotation preview** — annotations created in the main window appear in real-time on the pop-out, so reviewers on a second screen see updates live. Send annotation overlay data via BroadcastChannel. (6) **Window management** — detect when the pop-out is closed and update the main window UI accordingly. If the main window is closed/refreshed, gracefully close the pop-out or show a "reconnecting" message. Use `beforeunload` and `storage` events as fallbacks if BroadcastChannel disconnects. (7) **Pop-out window features** — the pop-out window includes minimal controls: page navigation (prev/next/go-to), zoom controls, fit-width/fit-page buttons, a sync status indicator, and a "Return to Main" button that closes the pop-out and refocuses the main window. Styled with a clean, distraction-free dark theme for comfortable viewing. (8) **Multiple pop-outs** — support opening multiple pop-out windows (e.g., one for each open tab/document) with independent channels. Each pop-out tracks which document tab it's associated with. (9) **Fallback for blocked pop-ups** — if the browser blocks the pop-up, show a clear message with instructions to allow pop-ups for the site, and offer an alternative "detached panel" mode using a draggable, resizable `<div>` overlay as a workaround. Register with action registry (actions: `pop-out-viewer`, `close-pop-out`, `toggle-sync`) and event bus. Keyboard shortcut: `Ctrl+Shift+W` to toggle pop-out window. No external dependencies — uses native `BroadcastChannel`, `window.open()`, and existing pdf.js/viewer infrastructure.

---

### TASK-125: N-up page layout — arrange multiple pages per sheet for economical printing

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Resolution (2026-04-10)**: Implemented `js/nup.js` with full N-up page layout generation using pdf-lib embedPages/drawPage for vector-quality output. Features: 6 layout presets (2-up, 4-up, 6-up, 9-up, 16-up, Custom with rows×cols input), 5 paper sizes (A4/Letter/A3/Legal/Tabloid), portrait/landscape orientation, 3 page ordering modes (LTR-TTB, RTL-TTB, TTB-LTR), configurable margins and gap (mm), 4 scaling modes (Fit/Fill/Shrink Only/Actual Size), page range selection (All/Odd/Even/Custom range), optional page borders and page number labels, repeat page mode for labels/cards with copies control, live summary text, canvas-based preview modal, PDF download and print buttons with progress bar. Registered 2 action-registry commands (create-nup-layout, pages-per-sheet). Keyboard shortcut: Ctrl+Shift+N. Added nav tab with 4-square grid icon and full tool panel to index.html. Verified end-to-end: zero console errors, PDF generation succeeds, viewer intact post-interaction (containerWidth=1685, 2 visible canvases), all panel controls render and function correctly (preset switching, custom grid toggle, repeat mode toggle, summary updates).
**Description**: Build an N-up page layout tool that arranges multiple PDF pages onto single physical sheets for printing efficiency and document overview. This is distinct from the booklet tool (`booklet.js`, which reorders pages for saddle-stitch folding) — N-up simply tiles pages in reading order onto larger sheets to save paper. Implementation: create `js/nup.js`. Add a new tool tab "N-up Layout" (icon: grid of small pages / 4-square grid). Features: (1) **Layout presets** — quick-select buttons for common layouts: 2-up (1x2), 4-up (2x2), 6-up (2x3), 9-up (3x3), 16-up (4x4), plus a "Custom" option where the user specifies rows and columns. (2) **Paper size** — target output sheet size dropdown: Letter, A4, A3, Legal, Tabloid, or custom dimensions (width x height in mm). Orientation toggle: portrait or landscape. The tool should auto-suggest the best orientation based on source page aspect ratio and N-up count. (3) **Page ordering** — configurable reading order for how source pages are placed on each sheet: left-to-right then top-to-bottom (default, Western reading order), right-to-left then top-to-bottom (RTL), top-to-bottom then left-to-right (column-first), or Z-pattern. (4) **Spacing and margins** — configurable outer margins (default 10mm) and inner gap between tiles (default 3mm). Input fields with mm units and a live preview. (5) **Page borders** — optional thin border (0.5pt default) around each tiled page for visual separation when printed. Configurable border color (default light gray). (6) **Page range** — select which source pages to include: All, Odd only, Even only, or Custom range (e.g., "1-10, 15, 20-25"). Parse ranges with the same logic used in `split.js`. (7) **Scaling** — each source page is uniformly scaled to fit its allocated cell on the output sheet, maintaining aspect ratio. Options: "Fit" (scale to fill cell while maintaining ratio), "Fill" (scale to completely fill cell, may crop edges), "Actual Size" (no scaling, center in cell, may clip). Show a warning if actual-size pages exceed cell bounds. (8) **Page number labels** — optional small page number printed beneath each tile (e.g., "Page 3"), with configurable font size (default 6pt). (9) **Live preview** — render a canvas preview of the first output sheet showing the layout with actual PDF content (rendered via pdf.js at reduced resolution). Update the preview in real-time as the user changes settings. Show total output sheet count (e.g., "12 source pages → 3 sheets at 4-up"). (10) **Output** — generate the N-up PDF via pdf-lib: create new pages at the target sheet size, embed each source page as a scaled XObject positioned in its grid cell. Offer "Download N-up PDF" and "Print" buttons. Show a progress bar for large documents. (11) **Repeat page mode** — an option to repeat the same page N times per sheet (useful for printing labels, business cards, or handouts from a single-page source). When enabled, a "Copies per sheet" spinner replaces the normal pagination logic. Register with the action registry (actions: `create-nup-layout`, `pages-per-sheet`) and event bus. Keyboard shortcut: `Ctrl+Shift+N` to open N-up panel. No external dependencies — uses existing pdf.js for rendering and pdf-lib for PDF generation.

---

### TASK-127: Scan enhancement toolkit — auto-detect and fix common scanning artifacts for cleaner documents and better OCR

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a scan enhancement toolkit that auto-detects and fixes common scanning artifacts, producing cleaner documents and significantly improving OCR accuracy. This is distinct from `deskew.js` (rotation correction only) and `color-adjust.js` (global brightness/contrast/saturation sliders) — this tool targets scan-specific defects with intelligent detection and targeted fixes. Implementation: create `js/scan-enhance.js`. Add a new tool tab "Scan Enhance" (icon: magic wand over a document page). Features: (1) **Black border removal** — detect solid black or near-black borders around scanned pages (common from flatbed scanners where the page doesn't cover the full platen) using edge histogram analysis. Auto-crop to content bounds with a configurable padding margin (default 5px). Preview before/after with the existing comparison slider. (2) **Hole-punch removal** — detect circular artifacts near page margins (typically 2–3 holes along the left edge) using connected-component analysis and circularity filtering. Inpaint detected holes by filling with the surrounding background color (sampled from a local neighborhood). Configurable detection sensitivity and minimum/maximum hole diameter range. (3) **Background whitening/normalization** — normalize the page background to clean white by detecting the dominant background color (histogram peak) and remapping it to pure white via adaptive thresholding. Removes yellowed paper tint, uneven lighting, and scanner lid shadows. Preserves text and image content. Adjustable intensity slider (subtle to aggressive). (4) **Noise reduction** — remove salt-and-pepper speckle noise common in photocopied or faxed documents using a median filter (3x3 or 5x5 kernel, user-selectable). Optionally apply Gaussian smoothing for heavier noise. Show before/after comparison. (5) **Binarization** — convert pages to clean black-and-white using Otsu's automatic thresholding method for optimal text/background separation. Also offer manual threshold slider (0–255) for fine-tuning. Useful for creating crisp text documents from gray or noisy scans before OCR. Option to apply Sauvola adaptive binarization for documents with uneven illumination. (6) **Shadow removal** — detect and remove binding shadows (dark gradients along the spine edge of book scans) by analyzing vertical intensity profiles and applying gradient compensation. (7) **Batch apply** — apply any combination of enhancements to all pages or a selected page range. Show a progress bar. Each enhancement is a toggleable checkbox so users can compose a custom pipeline (e.g., border removal + background whitening + binarization). (8) **Preview panel** — split-view or overlay comparison showing original vs. enhanced page. Use the existing comparison slider component (`comparison-slider.js`) for interactive before/after viewing. (9) **Non-destructive workflow** — enhancements are applied to rendered page canvases and composed back into a new PDF via pdf-lib (embed enhanced pages as images). Offer "Apply to Current Page", "Apply to All Pages", and "Download Enhanced PDF" buttons. Optionally integrate with the version manager to auto-save a snapshot before enhancement. All processing is done on `<canvas>` using `getImageData()` / `putImageData()` — pure client-side pixel manipulation with no external dependencies. Render pages via pdf.js at the document's native resolution for quality preservation. Register with the action registry (actions: `scan-enhance`, `scan-cleanup`) and event bus. Keyboard shortcut: `Ctrl+Shift+E` to open scan enhance panel.

---

### TASK-128: Presenter view with speaker notes, next-slide preview, and session timer for presentation mode

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a presenter view that enhances the existing presentation mode (`present.js`) with a dual-display presenter experience — one screen shows the full-screen slide to the audience, while the presenter sees a control dashboard with the current slide, next slide preview, speaker notes, and a session timer. This is distinct from `present.js` (which currently provides basic full-screen page-by-page display) and `multi-window.js` (which pops out a synced viewer without presenter-specific controls). Implementation: create `js/presenter-view.js`. Add a "Presenter View" button inside the existing Presentation Mode tool panel (alongside the current "Start Presentation" button). When clicked, open a secondary window via `window.open()` containing the presenter dashboard, while the main window (or a second pop-out) enters full-screen presentation mode for the audience. Use `BroadcastChannel` (channel: `pdf-presenter-sync`) for real-time communication between the presenter dashboard and the audience display. Features: (1) **Presenter dashboard layout** — a three-panel layout: large current-slide preview (left, ~60% width), next-slide preview (right-top, ~40% width), and notes/controls panel (right-bottom). Dark theme for minimal distraction. (2) **Speaker notes** — a per-page notes editor (contenteditable div or textarea) where the presenter can type and save notes for each slide. Notes are stored in `localStorage` keyed by document hash + page number. Support basic formatting (bold, italic, bullet lists) via simple Markdown-to-HTML rendering. Font size slider for notes readability at a distance. (3) **Next slide preview** — render the upcoming page at reduced resolution via pdf.js so the presenter always knows what's coming. Show "End of Document" indicator on the last page. (4) **Session timer** — three timer displays: elapsed time since presentation started (counts up), a user-settable countdown timer (e.g., "You have 15 minutes" — turns red at 2 minutes remaining), and current wall-clock time. Start/pause/reset controls. Optional gentle audio chime at configurable intervals (every 5/10/15 minutes) using Web Audio API oscillator. (5) **Slide navigation** — prev/next buttons, page number input for direct jump, thumbnail filmstrip strip along the bottom for quick navigation. All navigation syncs to the audience display in real-time via BroadcastChannel. (6) **Annotation tools** — a minimal set of presentation annotation tools available in the presenter view: laser pointer (a colored dot that appears on the audience screen following the presenter's mouse/touch position, communicated via BroadcastChannel at ~30fps), pen draw (temporary freehand drawing that overlays on the audience screen and auto-fades after 5 seconds), and spotlight (dim everything except a movable circular highlight region). These are temporary — they don't modify the PDF. (7) **Slide notes import** — detect and extract existing PDF annotations (sticky notes, text annotations) and pre-populate the speaker notes for each page. Also support importing notes from a JSON file (page-number → notes-text mapping). (8) **Black/white screen** — "B" key blacks out the audience screen (common presentation feature for pausing), "W" key shows a white screen. The presenter dashboard shows a "Screen blanked" indicator. (9) **Audience screen controls** — from the presenter dashboard, control the audience display: toggle pointer visibility, toggle annotation overlay, fit-width vs fit-page, and end presentation (exits full-screen on the audience display with a "Thank you" slide). (10) **Session summary** — when the presentation ends, show a brief summary: total duration, pages shown, time spent per page (tracked automatically), and offer to export session notes as a text file. Register with the action registry (actions: `start-presenter-view`, `stop-presenter-view`) and event bus. Keyboard shortcuts in presenter view: Left/Right arrows or PageUp/PageDown for navigation, `N` to toggle notes panel, `T` to toggle timer, `L` to toggle laser pointer, `B` for black screen, `W` for white screen, `Escape` to end presentation. No external dependencies — uses existing pdf.js rendering, BroadcastChannel for sync, Web Audio API for timer chimes, and localStorage for notes persistence.

---

### TASK-129: Print preflight checker — validate PDF documents against print production standards and flag issues before sending to press

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a print preflight checker that analyzes a loaded PDF against common print production requirements and generates a detailed pass/warn/fail report — helping users catch problems before sending documents to a commercial printer.

---

### TASK-130: Action macro recorder — record, save, and replay sequences of PDF editing operations as reusable one-click workflows

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build an action macro recorder that lets users record a sequence of PDF editing operations, save them as named macros, and replay them on any document with one click — automating repetitive multi-step workflows like "add watermark → compress → add page numbers → flatten" or "redact SSNs → sanitize → password protect". This is distinct from batch processing (`batch.js`, which applies a *single* operation to multiple files) — macros chain *multiple* operations on a single document in sequence. Implementation: create `js/macro-recorder.js`. Add a new tool tab "Macros" (icon: play button inside a circular arrow / automation icon). Features: (1) **Record mode** — a prominent "Record" button (red dot icon, like audio/video recording) that starts capturing user actions. While recording, every operation dispatched through the action registry and event bus is logged as a macro step with its parameters (e.g., `{action: "add-watermark", params: {text: "DRAFT", opacity: 0.3, position: "center"}}`, `{action: "compress", params: {quality: "medium"}}`, `{action: "add-page-numbers", params: {position: "bottom-center", startFrom: 1}}`). A floating recording indicator shows elapsed time and step count. Click "Stop" to end recording. (2) **Step editor** — after recording, display the captured steps in an editable list. Users can reorder steps via drag-and-drop, delete steps, duplicate steps, or edit individual step parameters (show a form based on the action's known parameter schema). Add manual steps from a dropdown of all registered actions. Preview the effect of each step by hovering to see a tooltip description. (3) **Parameterization** — allow marking specific parameters as "ask at runtime" (prompted each time the macro runs) vs. "fixed" (baked into the macro). For example, a watermark macro could prompt for the watermark text each time but keep opacity fixed at 0.3. Runtime parameters show a quick dialog before execution. (4) **Save and manage** — save macros with a user-provided name, optional description, and icon/color tag. Store in localStorage under `pdf-editor-macros` as JSON. A macro library panel lists all saved macros with name, step count, and last-used date. Edit, rename, duplicate, or delete macros from the library. (5) **One-click replay** — clicking a saved macro runs all its steps sequentially on the currently loaded document. Show a progress panel with step-by-step status (pending → running → done/failed), a progress bar, and estimated time remaining. If a step fails, pause and offer: "Skip this step", "Retry", or "Abort macro". After completion, show a summary of all steps executed and their results. (6) **Conditional steps** — basic conditional logic: "only if page count > N", "only if file size > N MB", "skip if no form fields detected". Conditions are configured per step in the step editor. (7) **Import/export** — export macros as JSON files for sharing or backup; import macros from JSON files. Validate imported macros against the current action registry and warn about unrecognized actions. (8) **Built-in macro templates** — ship 3-4 pre-built macros as starting points: "Print Prep" (add page numbers + add bleed marks + flatten), "Secure Share" (smart redact PII + sanitize + password protect), "Archive" (compress + convert to PDF/A + add metadata), "Review Cleanup" (flatten annotations + remove bookmarks + compress). Users can customize these templates. (9) **Keyboard shortcut** — `Ctrl+Shift+M` to open macro panel, `Ctrl+Alt+R` to start/stop recording. Assign individual macros to custom keyboard shortcuts (e.g., `Ctrl+1` through `Ctrl+9` for quick access to favorite macros). (10) **Integration** — hook into the existing action registry (`action-registry.js`) to intercept action dispatches during recording. Use the event bus to listen for operation completion events. Each macro step should fire a `macro:step:start` and `macro:step:complete` event so other modules can react. Integrate with undo/redo — running a macro creates a single undo group so the entire macro can be undone with one `Ctrl+Z`. Register with action registry (actions: `start-macro-recording`, `stop-macro-recording`, `run-macro`, `open-macro-library`). No external dependencies — uses existing action registry, event bus, and localStorage. This is distinct from `printprep.js` (which adds bleed/trim marks), `pdfa.js` (archival compliance), `statistics.js` (general analytics), and `font-inspector.js` (font listing). The preflight checker *validates* the document against configurable quality standards. Implementation: create `js/preflight.js`. Add a new tool tab "Preflight" (icon: checkmark inside a circle or a clipboard with checkmark). When activated, the tool runs a series of automated checks on the loaded PDF and displays results in a structured report panel. Checks to implement: (1) **Image resolution** — scan all embedded images and calculate their effective DPI at the placed size on each page. Flag images below 300 DPI as warnings (print quality risk) and below 150 DPI as errors. Show each flagged image with its page number, position, native resolution, and effective DPI. Use pdf.js page operators to detect image XObjects and their transformation matrices to compute placed dimensions. (2) **Font embedding** — verify that every font used in the document is fully embedded (not just referenced by name). Flag non-embedded fonts as errors since they may render incorrectly or substitute at the print shop. Use pdf.js `getPage().commonObjs` and font descriptor data. Cross-reference with `font-inspector.js` data if available. (3) **Color space analysis** — identify all color spaces used in the document (RGB, CMYK, Grayscale, Lab, spot colors). For print workflows, flag RGB images as warnings (should typically be CMYK for offset printing). Summarize color space usage per page. Detect mixed color spaces and flag potential conversion issues. (4) **Bleed and trim boxes** — check whether the PDF defines TrimBox, BleedBox, and CropBox entries. Flag missing TrimBox as a warning for professional print. Check that BleedBox extends at least 3mm beyond TrimBox on all sides (industry standard). Report the actual box dimensions. (5) **Page size consistency** — verify all pages have the same dimensions. Flag mixed page sizes as a warning (can cause print imposition issues). Report each unique page size and which pages use it. (6) **Transparency** — detect pages that use transparency (alpha channels, blend modes, soft masks). Flag as informational — transparency requires flattening for some print workflows (RIP compatibility). Suggest running the existing flatten tool if transparency is detected. (7) **Thin lines/hairlines** — detect strokes with width below 0.25pt, which may disappear in print. Flag as warnings with page number and approximate location. (8) **Overprint settings** — check for overprint flags on objects. Report overprint usage (relevant for spot color workflows). (9) **Total ink coverage** — estimate total ink coverage for CMYK pages (sum of C+M+Y+K percentages). Flag areas exceeding 300% total ink as warnings (risk of ink bleeding and drying issues). This requires sampling representative pixels — use canvas rendering at reduced resolution and compute ink values. (10) **PDF version and features** — report the PDF version (1.4, 1.7, 2.0) and flag usage of features that may not be supported by older RIPs (e.g., transparency requires PDF 1.4+, layers require PDF 1.5+). Display results as a categorized report panel with expandable sections per check category. Each check shows a status icon (green checkmark, yellow warning triangle, red X), a summary line, and expandable details. Show an overall preflight score (e.g., "8/10 checks passed — 2 warnings"). Provide a "Preflight Profile" dropdown to select predefined check configurations: "Standard Print" (all checks, 300 DPI minimum), "Digital Print" (relaxed, 200 DPI minimum, RGB allowed), "Press Quality" (strict, 300 DPI, CMYK only, bleed required), and "Custom" (user toggles individual checks). Allow exporting the preflight report as a JSON file or a printable HTML summary. Register with the action registry (actions: `run-preflight`, `print-preflight-check`) and event bus. Keyboard shortcut: `Ctrl+Shift+P` to open preflight panel. No external dependencies — uses existing pdf.js APIs for document introspection and canvas rendering for ink coverage sampling.

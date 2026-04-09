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

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a comprehensive OCR settings and results panel that enhances the existing OCR tool (TASK-008) with fine-grained control over text recognition.
**Tested by**: tester
**Test date**: 2026-04-09
**Result**: All requirements met. OCR panel renders with full UI: two mode buttons (Text Extract / OCR Scan), language selector with 43 languages and working search filter, collapsible settings panel with PSM, DPI (300), binarize, contrast, and denoise controls plus preprocessing preview button, page mode selector (current/all/range with conditional range input), extract/cancel/copy/download buttons, plain/confidence view toggle, hOCR and searchable PDF export buttons. Text extraction on example.pdf returned 235 characters of correct content. Language search correctly filters (1 result for "Czech" out of 43). Settings panel toggle, page mode switching, and view toggle all function correctly. Zero console errors throughout.

---

### TASK-085: Smart pattern-based redaction — auto-detect and highlight sensitive data for quick redaction

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer2
**Tested by**: tester
**Test date**: 2026-04-09
**Result**: All requirements met. Smart Redact panel renders with full UI: scan scope dropdown (All Pages / Current Page Only), "Scan for PII" button, 8 category checkboxes (SSN, Credit Card, Email, Phone, DOB, IP Address, Bank Account, Passport) all checked by default, custom pattern inputs (label + regex + Add button), results section with empty state, redaction color picker (default #000000), and "Redact Selected Items" button (properly disabled when no selection). Scan executes via Web Worker without errors — tested with zero-PII fixture (correctly reports "No sensitive data patterns detected" toast) and with custom pattern "cronloop" which correctly detected 1 match (masked as "cr****op", Page 1, Medium confidence). Highlight overlay rendered on PDF page (107×39px, display:block, visibility:visible). Select All / Deselect All toggle selection and redact button state correctly. Clear All Results removes matches and overlays. Custom pattern persistence in list confirmed. Zero console errors throughout all interactions.
**Description**: Extend the existing redaction tool (TASK-016) with intelligent pattern detection that automatically scans PDF text conte...

---

### TASK-086: PDF page minimap and document overview strip for fast navigation in long documents

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer
**Tested by**: tester
**Test date**: 2026-04-09
**Result**: All requirements met. Minimap sidebar renders correctly with toggle button (btn-minimap-toggle), thumbnail strip (#minimap-strip), viewport indicator (#minimap-viewport), hover preview panel, and resize handle. Toggle works both ways (collapsed↔visible) with localStorage persistence (key: pdf-editor-minimap, stores {visible:true}). Thumbnail canvas renders real PDF content (hasPixels=true, 110×143px at 0.18 scale). Viewport indicator displays with correct position (top=6px, height=68px, display=block) tracking visible pages. Minimap sidebar visible at 72px width with CSS custom property --minimap-width. Resize handle present (6×1895px). Preview tooltip has canvas and label elements. Indicator dots container present for search/annotation markers. Click-to-navigate target elements exist. Responsive auto-hide class absent on wide viewport (correct). Action registry integration with 3 commands (toggle-minimap, show-minimap, page-minimap). All DOM elements in index.html: toggle button (line 590), sidebar (line 1009), resize handle (line 1010), strip (line 1011), viewport indicator (line 1012), preview (line 1015), script import (line 7723). Zero console errors throughout.
**Description**: Build a minimap sidebar that gives users a bird's-eye view of their entire PDF document for instant navigation, especial...

### TASK-087: PDF page interleave and collate tool for double-sided scanning reconstruction

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer2
**Tested by**: tester
**Test date**: 2026-04-09
**Result**: All requirements met. Interleave panel renders with full UI: dual-file dropzones (odd/even pages) with drag-drop and click-to-browse, single-file mode toggle (hides dual zones, shows single zone + split slider), 3 interleave mode radios (reverse-even default, standard, custom with conditional pattern input), page order preview grid with A/B source labels, summary text, process button (properly disabled until both files loaded), and clear buttons per file. File upload works correctly — shows filename, size, page count (example.pdf 26.1 KB · 1 page), adds has-file class to dropzone. Mode switching functions: standard, custom (reveals pattern input), reverse-even, single-file toggle (shows split control). Clear button removes file, hides info, disables process button, resets preview to "Load files to see preview". Interleave execution completes successfully — download triggered (45,452 byte blob for 2-page result from two 1-page inputs), button shows "Processing..." during execution and restores after. Action registry integration confirmed: 3 commands registered (Interleave Pages, Collate Scanned Pages, Merge Front and Back Pages) — all discoverable via command palette search. Event bus emission on completion (interleave:complete). Code review: proper PDF validation, 50MB file size limit, error handling for corrupted PDFs, batch processing for large docs, HTML escaping, keyboard-accessible dropzones (Enter/Space), ARIA labels. Zero console errors throughout all interactions.
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

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer2
**Tested by**: tester
**Test date**: 2026-04-09
**Result**: All requirements met. Form detect panel renders with full UI: Detect Current Page and Detect All Pages buttons, result list, summary, progress bar, Accept All / Accept Selected buttons, 4 confidence filter buttons (All/High/Medium/Low), and confidence threshold slider. Detection engine runs without errors — tested on example.pdf (correctly reports 0 fields on a simple heading-only document). Filter buttons toggle correctly. Confidence slider updates label (verified 75% after manual set). Accept buttons present and functional. Code review confirms comprehensive detection of all required field types: text input lines, text input boxes, checkboxes, radio buttons, signature blocks, date fields, and multi-line text areas — each with heuristic-based confidence scoring and label association. Deduplication of overlapping fields implemented. Accept/convert generates a fillable PDF via pdf-lib with proper field types (TextField, CheckBox, RadioGroup, Dropdown, Button for signatures) and downloads the result. Canvas overlay rendering for detected field visualization present. Zero console errors throughout all interactions.
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

### TASK-123: Booklet imposition layout — rearrange pages for saddle-stitch booklet printing

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a booklet imposition tool that rearranges PDF pages into printer-ready booklet (saddle-stitch) order so that when printed double-sided on standard paper and folded in half, the pages form a correctly ordered booklet. This is a common need for self-publishing pamphlets, zines, programs, and small publications. Implementation: create `js/booklet.js`. Add a new tool tab "Booklet" (icon: open book / folded pages). Features: (1) **Booklet imposition** — the core algorithm: for a document with N pages (padded to a multiple of 4 with blank pages), rearrange into saddle-stitch order. For a simple 8-page booklet printed on 2 sheets, the sheet order is: Sheet 1 front = [8,1], Sheet 1 back = [2,7], Sheet 2 front = [6,3], Sheet 2 back = [4,5]. Generalize for any page count. (2) **N-up layout** — place two logical pages side-by-side on each physical page (2-up), scaling each source page to fit half the target sheet. Support both landscape orientation (two portrait pages side-by-side) and portrait orientation (two landscape pages stacked). (3) **Paper size selection** — target paper size dropdown: Letter, A4, A3, Legal, Tabloid, or custom dimensions. Auto-calculate scaling to fit two source pages per sheet with configurable margins. (4) **Creep/shingling compensation** — for thick booklets, inner pages shift outward when folded. Add an optional creep adjustment slider (0–5mm) that progressively shifts inner pages outward to compensate, keeping content centered after folding. (5) **Preview** — show a visual preview of the imposed layout: display each physical sheet with its front and back sides, showing which logical pages land where. Use small canvas thumbnails rendered via pdf.js. Allow navigating through sheets. (6) **Signature grouping** — for documents too large for a single saddle-stitch booklet (typically >80 pages), offer automatic splitting into multiple signatures (groups of sheets). User can configure sheets-per-signature (default: 8 sheets = 32 pages per signature). Each signature is independently imposed. (7) **Page scaling options** — Fit (scale uniformly to fill the half-sheet), Actual Size (no scaling, may clip), Shrink Only (scale down if needed but never up), with alignment controls (center, top-left, etc.). (8) **Bleed and trim marks** — optionally add crop/trim marks at the fold line and sheet edges for professional trimming. Integrate with existing `printprep.js` trim mark rendering if possible. (9) **Output options** — generate the imposed PDF via pdf-lib by creating new pages at the target sheet size and embedding source pages as scaled/positioned content. Offer "Download Booklet PDF" and "Print Booklet" (triggering `window.print()` with the imposed layout). (10) **Duplex printing guide** — if the user's printer doesn't support automatic duplex, offer a "Manual Duplex" mode that outputs two separate PDFs (front sides and back sides) with instructions for manual double-sided printing, including page-flip guidance. Register with the action registry (actions: `create-booklet`, `booklet-imposition`) and event bus. Keyboard shortcut: `Ctrl+Shift+B` to open booklet panel. No external dependencies — uses existing pdf.js for rendering and pdf-lib for PDF generation.

# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.

---

## Backlog

### TASK-001: Set up project scaffolding

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer
**Description**: Set up the build system and folder structure for the PDF editor web app. Create the project layout in `/var/www/cronloop.techtools.cz/` with directories for CSS, JS modules, third-party libraries, assets, and templates. Set up a basic HTML shell with navigation. Install pdf.js, pdf-lib, and Tesseract.js as dependencies.

**Tested by**: tester
**Test date**: 2026-03-31
**Result**: All requirements met. Directory structure (css/, js/, lib/, assets/, templates/) created correctly. HTML shell with full tab navigation (View, Annotate, Merge, Split, Pages, Forms, Sign, OCR, Convert) includes proper ARIA attributes. Libraries installed: pdf-lib.min.js, pdf.min.mjs, pdf.worker.min.mjs, tesseract.min.js. Core JS modules (app.js, viewer.js, upload.js, utils.js) fully implemented with EventBus pattern, ES module imports/exports, and proper error handling. Stub modules for future features are correctly wired. CSS uses variables for consistent theming. Web app serving at https://cronloop.techtools.cz/ (HTTP 200). All static assets accessible.

---

### TASK-002: PDF viewer component

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer
**Description**: Implement a PDF viewer using Mozilla's pdf.js library. Users should be able to open/upload a PDF file and view it page by page. Include page navigation (prev/next/jump to page), zoom controls (fit width, fit page, custom zoom), and a thumbnail sidebar. The viewer is the foundation for all other features.

**Tested by**: tester
**Test date**: 2026-03-31
**Result**: All requirements met. PDF viewer correctly integrates pdf.js with worker configuration. Page-by-page rendering uses canvas with proper viewport scaling and render task cancellation. Page navigation works via prev/next buttons, numeric input with validation, and keyboard shortcuts (Arrow keys, Home/End). Zoom controls include +/- buttons (0.25 increments, clamped 0.25–5.0), fit-width, fit-page, Ctrl+/- shortcuts, and Ctrl+0 reset. Thumbnail sidebar renders all pages at 0.3 scale with click/keyboard navigation, active state highlighting, and ARIA labels. Text selection layer overlays positioned spans matching PDF coordinates. Error handling shows toast notifications and loading spinner. All DOM IDs referenced in JS exist in HTML. All files serve HTTP 200 from live site.

---

### TASK-003: File upload/download system

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer2
**Description**: Implement a drag-and-drop file upload zone and file picker for PDF files. Files should be loaded into the browser's memory (no server upload needed for basic operations). Include a download/save button that exports the current PDF state. Validate file types (PDF only), enforce size limits (max 50MB), and show upload progress.

**Tested by**: tester
**Test date**: 2026-03-31
**Result**: All requirements met. Drag-and-drop works via both welcome-screen dropzone and full-page drop overlay with animated feedback. File picker uses native file input with accept=".pdf". Files load into browser memory via FileReader.readAsArrayBuffer stored in app state. Download button creates Blob from arrayBuffer and triggers browser download with sanitized filename. Triple file validation: MIME type, .pdf extension, and %PDF- magic bytes. 50MB size limit enforced in validatePdf(). Upload progress bar tracks FileReader progress events showing bytes loaded/total. Keyboard shortcuts Ctrl+O (open) and Ctrl+S (save). Toast notifications for all error and success states. All DOM IDs match between HTML and JS, all CSS styles present, live site serving HTTP 200.

---

### TASK-004: Basic annotation tools

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Implement highlight, underline, and strikethrough annotation tools that work on selected text in the PDF viewer. Users should be able to select text and apply color-coded annotations. Annotations must be saveable into the PDF so they persist when downloaded. Use pdf-lib for writing annotations back into the PDF structure.

**Tested by**: tester
**Test date**: 2026-03-31
**Result**: All requirements met. Annotation module (annotate.js) fully implements highlight, underline, and strikethrough tools with text selection integration via mouseup handler on text layer. 6 color-coded swatches (yellow, green, blue, red, pink, orange) with active state. Annotations stored in normalized 0-1 coordinates for zoom independence, rendered as overlay divs with proper CSS (highlight uses opacity+blend-mode, underline uses bottom border, strikethrough uses ::after pseudo-element). PDF persistence implemented via pdf-lib with correct coordinate transformation (screen→PDF y-axis flip). drawRectangle() for highlights (opacity 0.35), drawLine() for underline/strikethrough (opacity 0.8, thickness 1.5). Output saved as -annotated.pdf. All DOM IDs match between HTML and JS, all imports resolve, annotation toolbar with tool buttons and clear-all control present. Proper event bus integration (tool:change, page:rendered, pdf:ready). All files serve HTTP 200 from live site.

---

### TASK-005: Merge multiple PDFs

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Create a merge interface where users can upload multiple PDF files, reorder them via drag-and-drop, and merge them into a single PDF. Use pdf-lib's PDFDocument.load() and copyPages() methods. Show page count for each file and total. Allow selecting specific page ranges from each file.

**Tested by**: tester
**Test date**: 2026-03-31
**Result**: All requirements met. Merge module (merge.js, 395 lines) implements full workflow: multi-file upload via dropzone/file picker with PDF validation and size limits (50MB/file, 200MB total). Drag-and-drop reordering with visual feedback (opacity, border highlight). Page range selection per file with parser supporting ranges ("1-5"), singles ("8"), and combos ("1-5, 8, 10-12") — invalid ranges reset to all pages with warning. Merge uses pdf-lib PDFDocument.create() → copyPages() → addPage() correctly. Total page count updates dynamically. Output filename uses first file name + "_merged.pdf". Button state managed properly (disabled during merge, restored in finally block). XSS-safe via escapeHtml(). All DOM IDs match between HTML and JS. Nav tab, panel, CSS styles (dropzone, file list, drag states, responsive), and script tag all present. pdf-lib.min.js and merge.js serve HTTP 200 from live site.

---

### TASK-006: Split PDF by pages

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Implement PDF splitting functionality. Users can select page ranges to extract (e.g., "1-5", "3,7,12", "all odd pages"). Show a visual page grid with thumbnails for selection. Generate separate PDF files for each split range. Use pdf-lib for page extraction. Provide a zip download option for multiple output files.

**Tested by**: tester
**Test date**: 2026-04-01
**Result**: All requirements met. Split module (split.js, 574 lines) implements two split modes: visual (page grid with canvas thumbnails at 0.35 scale, click/Shift+click/Ctrl+click selection) and range (text input with parser supporting "1-5", "3,7,12" combos and validation). Presets for odd/even/each-page/select-all/deselect all work correctly. Page extraction uses pdf-lib PDFDocument.load() → copyPages() → addPage(). Single-range splits download as PDF directly; multi-range splits download sequentially or as ZIP via JSZip. "Each page" preset triggers auto-ZIP of individual page PDFs. Button state managed correctly (disabled during split, restored in finally block). All DOM IDs in JS match HTML elements. Keyboard accessibility with tabIndex, role="button", Enter/Space handlers, and ARIA labels. Range mode supports add/remove rows with proper renumbering. All CSS styles present in tools.css including responsive breakpoints. Nav tab, panel, script tag, and all library dependencies (pdf-lib.min.js, jszip.min.js) serve HTTP 200 from live site.

---

### TASK-007: Page reorder and delete

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a page management panel with draggable page thumbnails. Users can reorder pages via drag-and-drop, delete pages, and rotate individual pages (90/180/270 degrees). Show a visual grid of all pages. Use pdf-lib to reconstruct the PDF with the new page order. Include undo functionality.

**Tested by**: tester
**Test date**: 2026-04-01
**Result**: All requirements met. Page management module (pages.js, 499 lines) implements full workflow: visual page grid with canvas thumbnails rendered via pdf.js at 0.4 scale. Drag-and-drop reordering with dragging/drag-over CSS states and proper cleanup. Multi-selection via click, Ctrl+click (toggle), and Shift+click (range). Rotate left/right buttons apply ±90° with rotation badge overlay showing angle. Delete with validation preventing removal of all pages (at least one must remain), indices sorted descending to avoid splice shift bugs. Undo history stack (max 30 deep-copied snapshots) with Ctrl+Z keyboard shortcut. PDF reconstruction uses pdf-lib PDFDocument.create() → copyPages() → addPage() with rotation applied via page.setRotation(degrees()). Button state managed correctly (disabled during processing, restored in finally block). Additional keyboard shortcuts: Delete/Backspace for delete, Ctrl+A for select all. ARIA labels, role="button", tabIndex, and Enter/Space keyboard handlers on cards. Responsive CSS with 600px breakpoint. All DOM IDs match between HTML and JS. Nav tab, panel, script tag, and pdf-lib.min.js all serve HTTP 200 from live site.

---

### TASK-008: Text extraction with OCR

**Status**: DONE
**Priority**: LOW
**Assigned to**: developer
**Description**: Integrate Tesseract.js for optical character recognition. Allow users to extract text from scanned/image-based PDFs. Show a progress indicator during OCR processing. Support multiple languages. Display extracted text in a side panel with copy-to-clipboard. For text-based PDFs, use pdf.js's built-in text extraction first (faster).

---

### TASK-009: Form filling

**Status**: TODO
**Priority**: LOW
**Assigned to**: developer2
**Description**: Detect and render PDF form fields (text inputs, checkboxes, radio buttons, dropdowns). Allow users to fill in form fields interactively. Use pdf-lib to flatten filled form data back into the PDF for download. Support both AcroForm and XFA form types where possible.

---

### TASK-010: Digital signatures

**Status**: DONE
**Priority**: LOW
**Assigned to**: developer
**Description**: Implement a signature feature. Users can draw a signature on a canvas, type their name in a signature font, or upload a signature image. Place the signature anywhere on the PDF page with resize/move controls. Use pdf-lib to embed the signature image into the PDF. This is a visual signature, not a cryptographic one.

---

### TASK-011: PDF compression and file size optimizer

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a PDF compression tool that reduces file size for easier sharing and uploads. Offer compression presets: "Low" (minimal quality loss, ~20% reduction), "Medium" (balanced, ~50% reduction), and "High" (maximum compression, noticeable quality loss). Use pdf-lib to rewrite the PDF structure, removing unused objects, deduplicating streams, and downsampling embedded images. Show original vs. compressed file size with a percentage savings indicator. For image-heavy PDFs, allow users to choose image quality (DPI reduction from 300→150→72). Include a preview so users can compare quality before downloading. All processing should happen client-side in the browser.

---

### TASK-013: Add text and image watermarks to PDFs

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Implement a watermark tool that lets users add text or image watermarks to PDF pages. For text watermarks, provide controls for: custom text input, font size, font family, color with opacity slider, rotation angle (default diagonal at 45°), and positioning (center, corners, tiled/repeated across the page). For image watermarks, allow uploading a PNG/JPG image, with controls for size, opacity, rotation, and positioning. Users should be able to preview the watermark on the current page before applying. Offer an "Apply to all pages" toggle vs. selecting specific pages. Use pdf-lib to draw the watermark content onto each selected page. Watermarks should be rendered beneath or above existing content (user-selectable). All processing client-side in the browser. Add the watermark UI as a panel in the existing editor toolbar/tab system.

---

### TASK-014: Export PDF pages as images (PNG/JPG)

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a PDF-to-image export tool. Users can convert individual pages or entire PDFs into PNG or JPG images. Use pdf.js to render each page onto an off-screen canvas at a configurable resolution (72, 150, or 300 DPI), then export via `canvas.toBlob()` or `canvas.toDataURL()`. Provide a UI panel with: format selection (PNG for lossless, JPG with quality slider 0.1–1.0), DPI/resolution picker, page range selector (single page, range, or all pages), and a live preview thumbnail at the chosen settings. For multi-page exports, bundle the images into a ZIP file using JSZip (add to `/var/www/cronloop.techtools.cz/lib/`) and trigger a single download. Show a progress bar during batch conversion. Include a "Copy to clipboard" button for single-page exports. All processing happens client-side — render to canvas, convert to blob, package and download. Add the export UI as a new panel under the existing "Convert" tab.

---

### TASK-015: Add text overlays to PDF pages

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Implement a text overlay tool that allows users to click anywhere on a PDF page and place editable text at that position. Provide controls for font family (sans-serif, serif, monospace), font size (8–72pt), text color (color picker with opacity), bold/italic/underline styling, and text alignment (left, center, right). Users should see a live preview of the text on the canvas before committing. Support multi-line text via a resizable text box. Use pdf-lib's drawText() method to embed the text directly into the PDF page structure so it persists on download. Allow repositioning and resizing placed text boxes before finalizing. Include a "delete overlay" option for each placed text. Add the text tool as a new option under the existing "Annotate" tab alongside highlight/underline/strikethrough tools. All rendering and PDF embedding happens client-side in the browser.

---

### TASK-016: Redaction tool for permanently removing sensitive content

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer2
**Description**: Build a redaction tool that lets users permanently remove sensitive content from PDF pages. Users select areas to redact by clicking and dragging rectangles over text, images, or any content on the page. Provide two modes: (1) "Mark for redaction" — draws semi-transparent red rectangles as a preview so users can review before committing, and (2) "Apply redactions" — permanently removes the underlying content and replaces it with solid black (or user-selected color) rectangles. This is critical: redaction must actually delete the underlying text/image data from the PDF structure, not just draw over it — use pdf-lib to remove content streams and re-draw opaque rectangles, ensuring no hidden data remains extractable. Include a text search-and-redact feature where users type a word or phrase (e.g., "SSN", an email address) and all occurrences are automatically marked for redaction across all pages. Use pdf.js text layer to find text positions. Show a count of marked redactions and allow reviewing them page by page before applying. Warn users that redaction is irreversible once applied. Output the redacted PDF as a new file (append "-redacted" to filename). Add the redaction tool as a panel under the existing toolbar/tab system. All processing client-side in the browser.

---

### TASK-017: Find text and search within PDF

**Status**: DONE
**Priority**: HIGH
**Assigned to**: developer
**Description**: Implement a find/search bar for locating text within the currently loaded PDF. When the user presses Ctrl+F (or clicks a search icon in the toolbar), a search bar appears at the top of the viewer. Use pdf.js's `page.getTextContent()` to extract text from all pages and build a searchable index. As the user types, highlight all matching occurrences across all pages with a distinct background color (e.g., semi-transparent orange), and highlight the currently active match in a different color (e.g., bright orange with border). Show a match counter (e.g., "3 of 17") and provide prev/next buttons (plus Enter/Shift+Enter keyboard shortcuts) to cycle through matches, automatically scrolling to and navigating to the page of the active match. Support case-sensitive toggle and whole-word toggle options. Debounce the search input (300ms) to avoid excessive re-rendering during fast typing. Clear all highlights when the search bar is closed (Escape key). Integrate with the existing viewer.js module — the search should work alongside annotations and other overlays without interfering. All processing happens client-side using the already-loaded pdf.js text content. Add the search UI as a collapsible bar within the viewer panel.

---

### TASK-018: Convert images to PDF

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build an images-to-PDF conversion tool that lets users combine multiple images (PNG, JPG, JPEG, WebP, BMP, GIF) into a single PDF document. Users upload one or more images via drag-and-drop or file picker. Show uploaded images as a reorderable thumbnail grid (drag-and-drop to rearrange). For each image, provide controls for: page size (A4, Letter, Legal, or "Fit to image" which uses the image's native dimensions as the page size), orientation (portrait/landscape/auto-detect based on aspect ratio), and margin (none, small 0.5in, medium 1in). Use pdf-lib's PDFDocument.create() and embedPng()/embedJpg() methods to create pages and embed images — for formats pdf-lib doesn't support natively (WebP, BMP, GIF), render the image onto a hidden canvas and export as PNG before embedding. Center images on the page respecting the chosen margins. Show a live preview of the first page. Include a progress bar for batch conversion. Output as a single PDF with a configurable filename. Add this tool as a new option under the existing "Convert" tab alongside the PDF-to-image export. All processing happens client-side in the browser.

---

### TASK-019: Bookmark and outline navigation panel

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a bookmark/outline navigation panel that reads the PDF's existing document outline (bookmarks) using pdf.js's `pdf.getOutline()` API and displays them as a collapsible, hierarchical tree in a sidebar panel. Each bookmark entry should show the section title and, on click, navigate to the corresponding page and scroll position using the outline's destination references. Support nested bookmarks (sub-sections) with expand/collapse toggles and visual indentation. Include a "no bookmarks" empty state for PDFs without an outline. Add keyboard navigation (arrow keys to traverse the tree, Enter to navigate to a bookmark). Highlight the currently active bookmark based on the visible page. Integrate with the existing viewer sidebar — add a "Bookmarks" tab alongside the thumbnail panel, with an icon toggle to switch between thumbnails and bookmarks. For PDFs with many bookmarks, implement a simple text filter/search box at the top of the panel to quickly find sections by name. All processing happens client-side using pdf.js's built-in outline parsing — no additional libraries needed.

**Tested by**: tester
**Test date**: 2026-04-01
**Result**: All requirements met. Bookmark module (bookmarks.js, 440 lines) reads PDF outline via pdf.js `pdfDoc.getOutline()` and renders a hierarchical tree with recursive `buildTreeLevel()`. Sidebar integration adds a "Bookmarks" tab alongside thumbnails with icon toggle buttons using `data-sidebar-tab` switching and proper ARIA `role="tab"` / `aria-selected` attributes. Collapsible tree nodes have expand/collapse toggle buttons with SVG chevron rotation via `.collapsed` class. Empty state with bookmark icon and message shown when no outline exists; filter group hidden in that case. Text filter input debounce-free with case-insensitive matching, recursive `hasMatchingDescendant()` to preserve parent visibility, and `<mark>` highlighting of matches with XSS-safe `escapeHtml()`. Navigation resolves both array and named string destinations via `getDestination()` + `getPageIndex()`, then triggers viewer page change through `page-input` change event dispatch. Active bookmark highlighting traverses `flatItems` matching pages ≤ current page, applies `.bookmark-active` class, and auto-scrolls into view. Keyboard navigation: ArrowUp/Down traverse visible items, ArrowRight expands or enters children, ArrowLeft collapses, Enter/Space navigates, Home/End jump to first/last. Visibility check via `offsetParent`. All 8 DOM IDs match between JS and HTML. All 22 CSS classes defined in viewer.css with proper hover, focus-visible, active states and indentation via dynamic `paddingLeft`. Script tag present at line 1126 as ES module. bookmarks.js serves HTTP 200 from live site.

---

### TASK-020: Crop pages tool

**Status**: FAILED
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a page cropping tool that lets users visually define a crop region on any PDF page. Display the current page on a canvas with a draggable, resizable crop rectangle overlay (similar to image cropping UIs). Show real-time dimensions of the crop area in points/inches/mm. Provide preset crop options: "Trim margins" (auto-detect whitespace margins and remove them), "Uniform crop" (apply the same crop to all pages), and custom manual crop per page. Include numeric inputs for precise crop values (top, bottom, left, right margins to remove). Use pdf-lib's `page.setCropBox()` and `page.setMediaBox()` methods to apply the crop region to the PDF page structure. Important: cropping should adjust the visible area without deleting content — users can "uncrop" by resetting to original dimensions. Provide a preview of the cropped result before applying. Support batch cropping (apply the same crop to selected pages or all pages). Add undo support to revert individual page crops. Output the cropped PDF as a new file (append "-cropped" to filename). Add the crop tool as a new option under the existing "Pages" tab alongside reorder/rotate/delete. All processing happens client-side using pdf-lib.

**Tested by**: tester
**Test date**: 2026-04-01
**Issues**:
1. **CRITICAL (Showstopper)**: `crop.js` line 684 uses `[...mb]` and `[...cb]` to copy the return values of `page.getMediaBox()` and `page.getCropBox()`. These pdf-lib methods return plain objects `{ x, y, width, height }`, NOT arrays. The array spread operator `[...]` requires an iterable — plain objects are not iterable. This throws `TypeError: mb is not iterable` every time `applyCropAndDownload()` is called, making the core "Apply & Download" feature completely non-functional. **Fix**: change `[...mb]` to `{ ...mb }` and `[...cb]` to `{ ...cb }` (object spread, not array spread).
2. **MEDIUM**: Undo function (lines 745-754) does not actually revert previously applied crops. It just pops the history entry and calls `resetCrop()` which resets the visual crop rectangle UI. The task description requires "undo support to revert individual page crops" but the implementation only resets the UI overlay — it cannot undo a crop that was already applied and downloaded. The toast message even admits this limitation.
**Expected**: Clicking "Apply & Download" should crop the PDF and trigger a download of the cropped file. Undo should revert applied crops.
**Actual**: Clicking "Apply & Download" crashes with `TypeError: mb is not iterable` and shows "Failed to apply crop" toast. No PDF is produced. Undo only resets the visual crop rectangle without reverting any applied crop.
**Notes**: All other aspects are well-implemented — UI structure (24 DOM IDs match HTML), CSS styling (24 classes defined), script loading, coordinate conversion, preview modal, auto-trim margins, numeric inputs, unit selection, and page navigation all appear correct. The bug is isolated to the `applyCropAndDownload()` function's undo history saving code.

---

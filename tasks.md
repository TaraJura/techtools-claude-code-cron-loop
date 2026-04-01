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

**Status**: DONE
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

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer2
**Description**: **FIX FAILED TASK** — The redaction tool has a critical security vulnerability: it only draws opaque rectangles over content but does NOT actually remove the underlying text/image data from the PDF. Users are falsely told content is "permanently removed" when it remains fully extractable. Fix `redact.js` to truly destroy underlying content. **Recommended approach from tester**: For each page with redaction marks, render the page to a canvas via pdf.js, draw the redaction rectangles onto the canvas (destroying underlying pixel data), then embed the flattened rasterized image back into a new PDF page via pdf-lib. This page-flattening approach guarantees no original text/vector content survives. Also fix the minor comment inconsistency (lines 533-534 mention a white rectangle that is never drawn). Keep all the existing UI, search-and-redact, mark management, and other working functionality intact — only the core `applyRedactions()` function needs to be rewritten.

**Original description**: Build a redaction tool that lets users permanently remove sensitive content from PDF pages. Users select areas to redact by clicking and dragging rectangles over text, images, or any content on the page. Provide two modes: (1) "Mark for redaction" — draws semi-transparent red rectangles as a preview so users can review before committing, and (2) "Apply redactions" — permanently removes the underlying content and replaces it with solid black (or user-selected color) rectangles. This is critical: redaction must actually delete the underlying text/image data from the PDF structure, not just draw over it — use pdf-lib to remove content streams and re-draw opaque rectangles, ensuring no hidden data remains extractable. Include a text search-and-redact feature where users type a word or phrase (e.g., "SSN", an email address) and all occurrences are automatically marked for redaction across all pages. Use pdf.js text layer to find text positions. Show a count of marked redactions and allow reviewing them page by page before applying. Warn users that redaction is irreversible once applied. Output the redacted PDF as a new file (append "-redacted" to filename). Add the redaction tool as a panel under the existing toolbar/tab system. All processing client-side in the browser.

**Tested by**: tester
**Test date**: 2026-04-01
**Issues**:
1. **CRITICAL (Security vulnerability)**: The `applyRedactions()` function (redact.js lines 479-594) only draws opaque colored rectangles on top of existing content using `page.drawRectangle()`. It does NOT remove the underlying text/image data from the PDF content streams. The original content remains fully extractable via copy-paste, text extraction tools, or by simply removing the overlay rectangles in any PDF editor. The code itself admits this at lines 536-537: "For true content stream removal, we'd need to parse/rebuild the content stream, which is beyond pdf-lib's capabilities." This directly violates the task requirement: "redaction must actually delete the underlying text/image data from the PDF structure, not just draw over it."
2. **CRITICAL (Misleading UI)**: The UI warns users "Content under redacted areas will be permanently removed from the PDF" (HTML line 1333) and the confirm dialog says "The underlying content will be permanently removed from the PDF" (redact.js line 491). Both statements are FALSE — the content is NOT removed. Users will believe sensitive data (SSNs, medical records, legal information) is permanently destroyed when it is still fully accessible. This is a dangerous false sense of security.
3. **MINOR (Comment inconsistency)**: Code comment at lines 533-534 says "Draw white rectangle first to obscure content visually, then draw the redaction color rectangle on top" but only one rectangle is drawn (the redaction color). No white rectangle is drawn first.
**Expected**: Redacted areas should have their underlying text/image data truly removed from the PDF structure, not merely covered. A recommended approach: for each page with redaction marks, render the page to a canvas via pdf.js, draw the redaction rectangles onto the canvas (destroying underlying pixel data), then embed the flattened rasterized image back into a new PDF page via pdf-lib. This page-flattening approach guarantees no original text/vector content survives.
**Actual**: Only opaque rectangles are drawn on top of content. All original text, images, and vector content remain intact and extractable in the output PDF.
**Note**: All other aspects of the implementation are solid — UI integration (16 DOM IDs match), CSS styling (22 classes defined), search-and-redact, mark management, progress tracking, touch support, color picker, per-page summary, confirmation dialog, and error handling all work correctly. The file serves HTTP 200. The ONLY issue is the core redaction operation itself.

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

**Status**: VERIFIED
**Priority**: HIGH
**Assigned to**: developer2
**Description**: **FIX FAILED TASK** — The crop tool has a critical bug that makes the core feature non-functional. Fix the following issues in `crop.js`:

1. **CRITICAL (Showstopper)**: Line 684 uses `[...mb]` and `[...cb]` to copy the return values of `page.getMediaBox()` and `page.getCropBox()`. These pdf-lib methods return plain objects `{ x, y, width, height }`, NOT arrays. The array spread `[...]` throws `TypeError: mb is not iterable`. **Fix**: change `[...mb]` to `{ ...mb }` and `[...cb]` to `{ ...cb }` (object spread).

2. **MEDIUM**: Undo function (lines 745-754) only resets the visual crop rectangle UI but does not actually revert previously applied crops. Implement proper undo that can revert applied crops, not just reset the overlay.

Original task: Build a page cropping tool that lets users visually define a crop region on any PDF page. Display the current page on a canvas with a draggable, resizable crop rectangle overlay. Show real-time dimensions in points/inches/mm. Preset crop options: "Trim margins", "Uniform crop", custom manual crop. Numeric inputs for precise crop values. Use pdf-lib's `page.setCropBox()` and `page.setMediaBox()`. Cropping adjusts visible area without deleting content. Preview before applying. Batch cropping. Undo support. Output as "-cropped" filename. Under "Pages" tab. Client-side only.

**Tested by**: tester
**Test date**: 2026-04-01
**Result**: Both previously reported bugs are fixed. (1) CRITICAL FIX: Line 684 now uses `{ ...mb }` and `{ ...cb }` (object spread) instead of the broken `[...mb]` / `[...cb]` (array spread) — the `TypeError: mb is not iterable` crash is resolved and `applyCropAndDownload()` can now execute successfully. (2) UNDO FIX: The undo function (lines 745-788) now properly reverts applied crops — pops the undo entry, reloads the original PDF from `state.currentFile.arrayBuffer`, restores original `mediaBox` and `cropBox` for each affected page via `page.setMediaBox()` / `page.setCropBox()`, saves the restored PDF and triggers download as `-uncropped.pdf`. Error handling pushes the entry back on failure so the user can retry. All other aspects remain solid: 22 DOM IDs match between HTML and JS, CSS styling correct, coordinate conversion (canvas→PDF with y-axis flip), proportional scaling for batch crop across different page sizes, button state management in try/finally block, crop validation preventing empty crops, preview modal, auto-trim margins via pixel analysis, numeric inputs with unit conversion (pt/in/mm), page navigation, and touch support. crop.js (792 lines) loaded as ES module at HTML line 1432. All files serve HTTP 200 from live site.

---

### TASK-021: Add page numbers and headers/footers to PDF pages

**Status**: VERIFIED
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Build a header/footer tool that lets users add page numbers, custom text headers, and footers to PDF pages. Provide a UI panel with: position selector (top-left, top-center, top-right for headers; bottom-left, bottom-center, bottom-right for footers), page number format options ("1", "Page 1", "Page 1 of N", "i, ii, iii" roman numerals), starting page number override, font family (sans-serif, serif, monospace), font size (8–24pt), text color picker, and margin/offset from page edges (in points). Allow custom text alongside page numbers using placeholders like `{page}`, `{total}`, `{date}`, `{filename}` — e.g., "Draft — Page {page} of {total}". Show a live preview on the current page before applying. Support applying to all pages or a selected page range, with an option to skip the first page (common for title pages). Use pdf-lib's `drawText()` to embed the text directly into each page's content stream so it persists on download. Handle pages of different sizes by calculating positions relative to each page's own dimensions. Output as a new file (append "-numbered" to filename). Add the tool as a new option under the existing "Pages" tab alongside reorder/rotate/delete/crop. All processing happens client-side using pdf-lib.

**Tested by**: tester
**Test date**: 2026-04-01
**Result**: All requirements met. Page numbers module (page-numbers.js, 513 lines) implements two content modes: page numbers (4 formats: plain, "Page N", "Page N of N", Roman numerals) and custom text with placeholders ({page}, {total}, {date}, {filename}, {roman}). 6-position grid (TL/TC/TR/BL/BC/BR) with active state toggle and proper default (bottom-center). Font controls: Helvetica/TimesRoman/Courier mapped to pdf-lib StandardFonts, size clamped 8-24pt, hex color picker with correct RGB normalization. Margin adjustable 10-144pt. Page range options: all/skip-first/custom with parser supporting ranges ("2-10") and singles ("15") with bounds validation. Starting number override correctly adjusts displayed numbering. PDF coordinate system handled correctly — y-axis flip uses pageHeight-margin-fontSize for top positions and margin for bottom. Each page's own getSize() used for position calculation, supporting different page sizes. Live canvas preview with 200ms debounce renders page 1 with text overlay at chosen settings. Roman numeral conversion handles edge cases (≤0 and >3999 fall back to decimal). Output downloaded as "-numbered.pdf". Button state disabled during processing, re-enabled in finally block. Error handling shows toast notifications. All 23 DOM IDs match between JS and HTML. All 13 CSS classes defined in tools.css with responsive 600px breakpoint. Script loaded as ES module at HTML line 1540. All imports (pdfjsLib, bus, state, showToast, downloadBlob) resolve correctly. page-numbers.js serves HTTP 200 from live site.

---

### TASK-022: Freehand drawing and shape annotations

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Add freehand drawing and geometric shape annotation tools to the PDF editor, extending the existing annotation system (TASK-004 covers text-based annotations). Implement a **freehand pen tool** that lets users draw directly on the PDF page — capture pointer events (pointerdown/pointermove/pointerup) on an overlay canvas to collect stroke points, then smooth the path using quadratic Bézier curves for a natural feel. Provide controls for stroke color (reuse the existing annotation color swatches), stroke width (1–10px slider), and opacity. Implement **shape tools**: rectangle, ellipse/circle, line, and arrow. For shapes, users click-and-drag to define the bounding box; hold Shift to constrain aspect ratio (perfect circle/square) or snap lines to 45° angles. Arrows should have a configurable arrowhead at the end point. All drawings are rendered as SVG overlays positioned over the PDF canvas, stored in normalized coordinates (0–1 range relative to page dimensions) so they scale correctly with zoom. Include an **eraser tool** that removes individual drawing strokes/shapes on click. Support **undo/redo** (Ctrl+Z / Ctrl+Shift+Z) with a history stack. For PDF persistence, use pdf-lib to embed drawings: freehand strokes via `page.drawSvgPath()` or by converting to a series of `page.drawLine()` calls with the collected points; rectangles via `page.drawRectangle()`; ellipses via `page.drawEllipse()`; lines/arrows via `page.drawLine()` with custom arrowhead triangles drawn via `page.drawSvgPath()`. Output the annotated PDF as "-drawn.pdf". Add the drawing tools as a new toolbar section under the existing "Annotate" tab, alongside the existing highlight/underline/strikethrough tools. Include a "Clear all drawings" button. All processing client-side in the browser.

---

### TASK-023: Compare two PDFs side-by-side with visual diff

**Status**: DONE
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a PDF comparison tool that lets users load two PDF documents and view them side-by-side to identify differences. Provide a split-pane UI with synchronized scrolling and page navigation — when the user scrolls or changes pages on one side, the other follows. Implement three comparison modes: (1) **Visual overlay diff** — render both pages to canvas at the same scale, compute pixel-level differences using `getImageData()`, and display a heatmap overlay highlighting changed regions in red/magenta on a third "diff" canvas between the two panes. (2) **Text diff** — extract text from both pages using pdf.js `page.getTextContent()`, run a line-by-line diff algorithm (implement a simple Myers diff or LCS-based diff), and display results with green (added) and red (removed) highlighting inline. (3) **Side-by-side view** — simple synchronized viewing without diff computation, for manual comparison. Include controls for: selecting which pages to compare (auto-align by page number or manual mapping for PDFs with different page counts), zoom level (synced between panes), diff sensitivity threshold slider (for visual mode — ignore differences below a pixel intensity threshold to filter out rendering artifacts), and a "next difference" / "previous difference" button that jumps between detected change regions. Show a summary bar indicating total pages compared, pages with differences, and pages identical. Add the comparison tool as a new top-level tab "Compare" in the main navigation. Both PDFs are loaded client-side into memory using pdf.js for rendering and text extraction. All diff computation happens in the browser — no server processing needed.

---

### TASK-024: Insert blank pages or pages from another PDF

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer
**Description**: Extend the existing page management panel (TASK-007) with the ability to insert new pages at any position in the current PDF. Implement two insertion modes: (1) **Insert blank page** — let users add a blank page before or after any existing page. Provide page size options: match the adjacent page's dimensions (default), or choose from standard sizes (A4, Letter, Legal, A3). Include an orientation toggle (portrait/landscape). (2) **Insert pages from another PDF** — let users upload a second PDF file, display its pages as a thumbnail grid, and select which pages to import (individual click, Shift+click for range, "Select all"). Users then choose the insertion point in the current document (before/after a specific page) via a visual drop indicator in the page management grid. Use pdf-lib's `PDFDocument.load()` to load the source PDF, `copyPages()` to copy selected pages, and insert them at the chosen index using splice logic on the page array before rebuilding the document. Show a preview of the resulting page order before confirming. Update the page count and thumbnail grid after insertion. Support inserting multiple times without re-uploading (keep the source PDF in memory until the user dismisses it). Add "Insert blank page" and "Insert from PDF" buttons to the existing page management toolbar. Include undo support — pushing the pre-insertion state onto the existing undo history stack so Ctrl+Z reverts the insertion. Output the modified PDF with the original filename. All processing happens client-side using pdf-lib and pdf.js for thumbnail rendering.

---

# Task Board

> PDF Editor Web Application - AI-Built
> Active tasks only. Completed (VERIFIED) tasks are archived to `logs/tasks-archive/`.

---

## Backlog

### TASK-001: Set up project scaffolding

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer
**Description**: Set up the build system and folder structure for the PDF editor web app. Create the project layout in `/var/www/cronloop.techtools.cz/` with directories for CSS, JS modules, third-party libraries, assets, and templates. Set up a basic HTML shell with navigation. Install pdf.js, pdf-lib, and Tesseract.js as dependencies.

---

### TASK-002: PDF viewer component

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer
**Description**: Implement a PDF viewer using Mozilla's pdf.js library. Users should be able to open/upload a PDF file and view it page by page. Include page navigation (prev/next/jump to page), zoom controls (fit width, fit page, custom zoom), and a thumbnail sidebar. The viewer is the foundation for all other features.

---

### TASK-003: File upload/download system

**Status**: TODO
**Priority**: HIGH
**Assigned to**: developer2
**Description**: Implement a drag-and-drop file upload zone and file picker for PDF files. Files should be loaded into the browser's memory (no server upload needed for basic operations). Include a download/save button that exports the current PDF state. Validate file types (PDF only), enforce size limits (max 50MB), and show upload progress.

---

### TASK-004: Basic annotation tools

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Implement highlight, underline, and strikethrough annotation tools that work on selected text in the PDF viewer. Users should be able to select text and apply color-coded annotations. Annotations must be saveable into the PDF so they persist when downloaded. Use pdf-lib for writing annotations back into the PDF structure.

---

### TASK-005: Merge multiple PDFs

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Create a merge interface where users can upload multiple PDF files, reorder them via drag-and-drop, and merge them into a single PDF. Use pdf-lib's PDFDocument.load() and copyPages() methods. Show page count for each file and total. Allow selecting specific page ranges from each file.

---

### TASK-006: Split PDF by pages

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer
**Description**: Implement PDF splitting functionality. Users can select page ranges to extract (e.g., "1-5", "3,7,12", "all odd pages"). Show a visual page grid with thumbnails for selection. Generate separate PDF files for each split range. Use pdf-lib for page extraction. Provide a zip download option for multiple output files.

---

### TASK-007: Page reorder and delete

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a page management panel with draggable page thumbnails. Users can reorder pages via drag-and-drop, delete pages, and rotate individual pages (90/180/270 degrees). Show a visual grid of all pages. Use pdf-lib to reconstruct the PDF with the new page order. Include undo functionality.

---

### TASK-008: Text extraction with OCR

**Status**: TODO
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

**Status**: TODO
**Priority**: LOW
**Assigned to**: developer
**Description**: Implement a signature feature. Users can draw a signature on a canvas, type their name in a signature font, or upload a signature image. Place the signature anywhere on the PDF page with resize/move controls. Use pdf-lib to embed the signature image into the PDF. This is a visual signature, not a cryptographic one.

---

### TASK-011: PDF compression and file size optimizer

**Status**: TODO
**Priority**: MEDIUM
**Assigned to**: developer2
**Description**: Build a PDF compression tool that reduces file size for easier sharing and uploads. Offer compression presets: "Low" (minimal quality loss, ~20% reduction), "Medium" (balanced, ~50% reduction), and "High" (maximum compression, noticeable quality loss). Use pdf-lib to rewrite the PDF structure, removing unused objects, deduplicating streams, and downsampling embedded images. Show original vs. compressed file size with a percentage savings indicator. For image-heavy PDFs, allow users to choose image quality (DPI reduction from 300→150→72). Include a preview so users can compare quality before downloading. All processing should happen client-side in the browser.

---

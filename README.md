<img width="80" height="80" alt="logo-250px" src="https://github.com/user-attachments/assets/3705acee-283f-481b-b4dc-e32a34bb0f16" />

# iSnap

**iSnap** is a lightweight macOS screenshot + instant markup tool built for speed.

It’s designed for live reviews, design calls, and quick feedback loops — capture a region, copy it to the clipboard, save it to disk, and immediately annotate without breaking your flow.

What started as a small frustration-driven side project turned into a fully working tool built through vibe-coding, real use, and iterative tinkering.

## Download

➡️ **[Download iSnap v0.1.0 for macOS](https://github.com/ailaone/iSnap/releases/download/v0.1.0/iSnap-v0.1.0-macos.zip)**

Tested on **macOS Tahoe 26.2**

---

## What iSnap Does

- 📸 **Quick region screenshot capture**
- 📋 **Automatically copies the screenshot to the clipboard**
- 💾 **Automatically saves the original image to disk**
- ✏️ **Instant annotation window**
  - Pen & highlighter  
  - Shapes (rectangles, circles, arrows, lines)  
  - Text  
  - Redaction  
  - Undo / redo
- 🧭 **Menu bar–only app** (no Dock clutter)
- ⌨️ **Global shortcut:** `Cmd + Option + 2`

Screenshots are saved by default to:
~/Pictures/iSnap/

The save location can be **customized in Preferences** if you want to use a different folder.

---

## Basic Workflow

1. Press **Cmd + Option + 2**
2. Drag to select an area  
   *(or click once for fullscreen)*
3. Screenshot is automatically:
   - saved to disk
   - copied to clipboard
4. Annotation window opens automatically
5. Mark up, then save or copy the final image

---

## macOS Version

Developed and tested on:

**macOS Tahoe 26.2**

Other versions may work, but this is the reference environment.

---

## First Launch – Important Note (Gatekeeper)

Because this app is not notarized yet (no Apple Developer account), macOS may show an error like:

> **“iSnap is damaged and can’t be opened.”**

This is a standard Gatekeeper issue and easy to fix.

### Fix (one-time)

1. Open **Terminal**
2. Type the following (with a space at the end):
   ```bash
   xattr -cr
3.	Drag iSnap.app from your Applications folder into the Terminal window (this auto-fills the path)
4.	Press Enter
5.	Open the app again — the error will be gone

If you get stuck, feel free to open an issue or DM me.

---

## Screenshots

**Menu bar icon & capture trigger**

<img width="274" height="166" alt="menu-bar" src="https://github.com/user-attachments/assets/784e1acf-4a5e-4a1e-ba6f-519a5a4c7e70" />

### 

**Selection overlay**

<img width="600" height="388" alt="Overlay" src="https://github.com/user-attachments/assets/96b3fa45-fed1-4a68-89f3-f10decc9d5fd" />

### 

**Annotation toolbar & tools**

<table>
  <tr>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/484789d9-1bd9-4a81-8a6f-35afc583f344" width="420" alt="Pen Tool" />
      <br/><sub>Pen Tool</sub>
    </td>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/4ca6cf9f-336a-4e17-a1a2-398fed0fa37b" width="420" alt="Highlighter Tool" />
      <br/><sub>Highlighter Tool</sub>
    </td>
  </tr>
</table>

<table>
  <tr>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/4bdaea36-9b46-425f-92ef-4de09dc897bb" width="420" alt="Shapes Tool" />
      <br/><sub>Shapes Tool</sub>
    </td>
    <td align="center">
      <img src="https://github.com/user-attachments/assets/1843cf81-7b37-4521-ad4e-549b74539906" width="420" alt="Text Tool" />
      <br/><sub>Text Tool</sub>
    </td>
  </tr>
</table>

### 

**Final annotated output**

<img width="600" height="388" alt="Testing the tools" src="https://github.com/user-attachments/assets/f8d6cbee-2fe2-4d15-948a-a18d3cc1361d" />

⸻

## Status

This is an early but fully functional release.

If there’s enough interest, I may go through the Apple developer process and look into distributing the app on the App Store.

Feedback, bug reports, and feature requests are welcome.

- Please open a **GitHub Issue** for any feedback, bugs or feature requests
- For install help or general questions: **ailadesignllc+isnap@gmail.com**

"""Fill the official SIH 2025 idea template with ZeroTrace. Pointer headings stay."""
import shutil
from copy import deepcopy

from pptx import Presentation
from pptx.oxml.ns import qn
from pptx.util import Emu, Pt

SRC = r"c:\Users\msara\Downloads\SIH2025-IDEA-Presentation-Format.pptx"
DST = r"c:\Users\msara\OneDrive\Desktop\ZeroTrace\ZeroTrace-SIH2025-Idea.pptx"

TEAM = "ZeroTrace"


def delete_slide(prs, index):
    sld_id = prs.slides._sldIdLst[index]
    r_id = sld_id.get(qn("r:id"))
    prs.part.drop_rel(r_id)
    prs.slides._sldIdLst.remove(sld_id)


def set_run(shape, text):
    tf = shape.text_frame
    tf.word_wrap = True
    for p in tf.paragraphs:
        # Drop hard breaks so a single title line does not start blank.
        for br in list(p._p.findall(qn("a:br"))):
            p._p.remove(br)
        if not p.runs:
            continue
        p.runs[0].text = text
        for r in p.runs[1:]:
            r.text = ""
        return


def fill_lines(shape, lines, top, height):
    """lines: (kind, text) kind is 'h' pointer or 'b' bullet."""
    shape.top = Emu(top)
    shape.height = Emu(height)
    shape.width = Emu(10972800)
    shape.left = Emu(500000)
    tf = shape.text_frame
    tf.word_wrap = True
    tf.auto_size = None
    body = tf._txBody
    first = body.find(qn("a:p"))
    rpr = None
    for r in first.findall(qn("a:r")):
        found = r.find(qn("a:rPr"))
        if found is not None:
            rpr = deepcopy(found)
            break
    for p in list(body.findall(qn("a:p"))):
        body.remove(p)

    def add(kind, text):
        p = deepcopy(first)
        for child in list(p):
            if child.tag != qn("a:pPr"):
                p.remove(child)
        pPr = p.find(qn("a:pPr"))
        if pPr is None:
            pPr = p.makeelement(qn("a:pPr"), {})
            p.insert(0, pPr)
        # Tight spacing so six slides stay readable.
        for tag in ("a:spcBef", "a:spcAft"):
            old = pPr.find(qn(tag))
            if old is not None:
                pPr.remove(old)
        spc_bef = p.makeelement(qn("a:spcBef"), {})
        pts = p.makeelement(qn("a:spcPts"), {"val": "8" if kind == "h" else "0"})
        spc_bef.append(pts)
        pPr.append(spc_bef)
        spc_aft = p.makeelement(qn("a:spcAft"), {})
        pts2 = p.makeelement(qn("a:spcPts"), {"val": "2"})
        spc_aft.append(pts2)
        pPr.append(spc_aft)
        run = p.makeelement(qn("a:r"), {})
        props = deepcopy(rpr) if rpr is not None else p.makeelement(qn("a:rPr"), {})
        props.set("lang", "en-US")
        props.set("dirty", "0")
        if "u" in props.attrib:
            del props.attrib["u"]
        if kind == "h":
            props.set("sz", "1600")
            props.set("b", "1")
        else:
            props.set("sz", "1400")
            if "b" in props.attrib:
                del props.attrib["b"]
        latin = props.find(qn("a:latin"))
        if latin is None:
            latin = props.makeelement(qn("a:latin"), {})
            props.append(latin)
        latin.set("typeface", "Arial")
        run.append(props)
        t = props.makeelement(qn("a:t"), {})
        t.text = text
        run.append(t)
        p.append(run)
        body.append(p)

    for kind, text in lines:
        add(kind, text)


def main():
    shutil.copyfile(SRC, DST)
    prs = Presentation(DST)

    s1 = prs.slides[0]
    for sh in s1.shapes:
        if sh.name == "Subtitle 3":
            set_run(sh, "IDEA SUBMISSION")
        if sh.name == "TextBox 9":
            labels = [
                "Problem Statement ID:  [SIH portal]",
                "Problem Statement Title:  On-device file privacy",
                "Theme:  Cybersecurity",
                "PS Category:  Software",
                "Team ID:  [SIH portal]",
                "Team Name:  ZeroTrace",
            ]
            labeled = [p for p in sh.text_frame.paragraphs if p.text.strip()]
            for p, line in zip(labeled, labels):
                pPr = p._p.find(qn("a:pPr"))
                if pPr is not None:
                    pPr.set("algn", "l")
                    ln = pPr.find(qn("a:lnSpc"))
                    if ln is not None:
                        pct = ln.find(qn("a:spcPct"))
                        if pct is not None:
                            pct.set("val", "110000")
                if p.runs:
                    p.runs[0].text = line
                    p.runs[0].font.size = Pt(20)
                    for r in p.runs[1:]:
                        r.text = ""

    bodies = {
        1: [
            ("h", "Proposed Solution (Describe your Idea/Solution/Prototype)"),
            ("b", "On-device app: scan a file, show privacy risks, export a clean copy"),
            ("b", "No upload, no account, no cloud scan of the file"),
            ("b", "Working build: Android release APK and Windows app (v1.0.0)"),
            ("h", "Detailed explanation of the proposed solution"),
            ("b", "User picks a photo, PDF, Office file, or code/config"),
            ("b", "Built-in packs flag GPS/EXIF, file metadata, API keys, and QR tokens"),
            ("b", "Optional packs add face blur, license plates, and document OCR"),
            ("b", "User reviews findings, then saves a clean copy and an optional report"),
            ("h", "How it addresses the problem"),
            ("b", "Shared photos and documents leak location, faces, plates, and secrets"),
            ("b", "Cloud privacy tools send the private file to a server"),
            ("b", "ZeroTrace cleans the file on the device before it is shared"),
            ("h", "Innovation and uniqueness of the solution"),
            ("b", "Core scanners work fully offline from first launch"),
            ("b", "Optional packs are Ed25519-signed and hash-checked before install"),
            ("b", "Rust scan engine plus on-device ONNX, with release tamper checks"),
        ],
        2: [
            ("h", "Technologies to be used (e.g. programming languages, frameworks, hardware)"),
            ("b", "Flutter 3 / Dart 3 for Android and Windows UI"),
            ("b", "Rust engine (zerotrace_engine) via FFI for local scanning"),
            ("b", "ONNX Runtime on device for face, plate, and OCR packs"),
            ("b", "Riverpod + GoRouter; Ed25519 pack signatures; HMAC audit log"),
            ("b", "Keys in Android Keystore / Windows DPAPI. Phone or PC only — no server"),
            ("h", "Methodology and process for implementation (Flow Charts/Images/ working prototype)"),
            ("b", "1. Select file   2. Offline scan   3. Review findings"),
            ("b", "4. Fix / export clean copy   5. History stays on device until deleted"),
            ("b", "Built-in: Privacy Essentials, Metadata Cleaner, Developer Protection, QR Protection"),
            ("b", "Optional marketplace packs download once, then scan offline"),
            ("b", "Prototype status: release-signed Android APK (~95 MB, arm64) already built"),
        ],
        3: [
            ("h", "Analysis of the feasibility of the idea"),
            ("b", "Core product already runs: local scan, review, and export"),
            ("b", "No backend to host. Internet is only for optional pack download"),
            ("b", "Fits a normal phone: built-in packs need no extra model download"),
            ("h", "Potential challenges and risks"),
            ("b", "Face, plate, and OCR detection is not 100% accurate"),
            ("b", "A skilled person can still patch an open APK"),
            ("b", "Optional pack CDN may be unreachable on some networks"),
            ("h", "Strategies for overcoming these challenges"),
            ("b", "User always reviews findings before sharing the clean file"),
            ("b", "Cert pin, engine hash pin, and root/debug checks raise the tamper bar"),
            ("b", "If a pack cannot download, built-in offline scanners still work"),
        ],
        4: [
            ("h", "Potential impact on the target audience"),
            ("b", "People who share photos and documents from a phone"),
            ("b", "Developers who must not leak API keys or tokens in files"),
            ("b", "Users who will not send private files to a cloud scanner"),
            ("b", "Journalists, students, and field staff sharing proof from the device"),
            ("h", "Benefits of the solution (social, economic, environmental, etc.)"),
            ("b", "Social: fewer accidental leaks of location, faces, and identity"),
            ("b", "Economic: no per-file cloud fee; runs on hardware the user already has"),
            ("b", "Trust: no account and a one-tap wipe of scans, exports, packs, and keys"),
            ("b", "Environmental: no always-on server for every file scan"),
        ],
        5: [
            ("h", "Details / Links of the reference and research work"),
            ("b", "EXIF/GPS stays inside shared photos unless it is stripped (JEITA EXIF standard)"),
            ("b", "OWASP — secrets in source, config, and shared files"),
            ("b", "ONNX Runtime — neural inference on the device, not in the cloud"),
            ("b", "Android Keystore — keys stay in hardware-backed storage"),
            ("b", "Ed25519 signatures — pack catalog checked before install"),
            ("b", "ZeroTrace v1.0.0 product build: local sanitization, no scan server"),
        ],
    }

    for idx, lines in bodies.items():
        slide = prs.slides[idx]
        for sh in slide.shapes:
            if sh.name.startswith("Title") and idx == 1:
                set_run(sh, "ZEROTRACE")
            if sh.name.startswith("Oval") and sh.has_text_frame:
                set_run(sh, TEAM)
                for p in sh.text_frame.paragraphs:
                    p.alignment = 1  # center
                    for r in p.runs:
                        r.font.size = Pt(12)
                        r.font.bold = True
            if sh.name == "TextBox 8":
                fill_lines(sh, lines, top=1250000, height=4950000)

    # Template says delete the instructions slide before portal upload. Max 6 slides.
    delete_slide(prs, 6)
    prs.save(DST)
    print("saved", DST, "slides", len(prs.slides))


if __name__ == "__main__":
    main()

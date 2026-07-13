#!/usr/bin/env python3
"""Verify the structure and publication quality of the generated companion PDF."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

EXPECTED_COUNTS = {
    "chapters": (re.compile(r"^\\chapter\{", re.MULTILINE), 50),
    "readable chapters": (re.compile(r"\\label\{chapter-\d{3}\}"), 48),
    "parts": (re.compile(r"^\\part\{", re.MULTILINE), 9),
    "figures": (re.compile(r"^\\begin\{figure\}", re.MULTILINE), 49),
    "exercises": (re.compile(r"^\\begin\{exercisebox\}", re.MULTILINE), 47),
    "worked solutions": (re.compile(r"^\\begin\{solutionstrategy\}", re.MULTILINE), 47),
    "implementation points": (re.compile(r"^\\begin\{implementationpoint\}", re.MULTILINE), 206),
}

FORBIDDEN_LOG_PATTERNS = {
    "fatal LaTeX diagnostics": re.compile(
        r"Undefined control sequence|Missing \$ inserted|Fatal error|Emergency stop|"
        r"Package .* Error|LaTeX Error"
    ),
    "missing glyphs": re.compile(r"Missing character:"),
    "horizontal overflow": re.compile(r"Overfull \\hbox"),
    "vertical overflow": re.compile(r"Overfull \\vbox"),
}

REQUIRED_PDF_TEXT = (
    "Start Here: Build an LLM Inference Engine",
    "Vector Dot Product",
    "Capstone Inference Engine",
    "Anatomy of One Generated Token",
    "Math Primer",
    "Complete canonical listings",
)
MAXIMUM_HORIZONTAL_DIAGRAM_ASPECT_RATIO = 6.0


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manuscript", required=True, type=Path)
    parser.add_argument("--tex", required=True, type=Path)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--pdf", required=True, type=Path)
    parser.add_argument("--published", required=True, type=Path)
    return parser.parse_args()


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def extract_pdf_text(pdf: Path) -> str:
    result = subprocess.run(
        [
            "gs",
            "-q",
            "-dNOPAUSE",
            "-dBATCH",
            "-sDEVICE=txtwrite",
            "-sOutputFile=-",
            str(pdf),
        ],
        check=True,
        capture_output=True,
    )
    return result.stdout.decode("utf-8", errors="replace")


def diagram_coordinate_aspects(tex: str) -> list[float]:
    aspects: list[float] = []
    for body in re.findall(
        r"\\begin\{tikzpicture\}(.*?)\\end\{tikzpicture\}",
        tex,
        flags=re.DOTALL,
    ):
        coordinates = [
            (float(x), float(y))
            for x, y in re.findall(
                r"at \((-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\)",
                body,
            )
        ]
        if not coordinates:
            continue
        xs, ys = zip(*coordinates)
        width = max(xs) - min(xs)
        height = max(ys) - min(ys)
        aspects.append(width / max(height, 0.01))
    return aspects


def main() -> None:
    arguments = parse_arguments()
    failures: list[str] = []

    for path in (
        arguments.manuscript,
        arguments.tex,
        arguments.log,
        arguments.pdf,
        arguments.published,
    ):
        require(path.is_file(), f"Missing artifact: {path}", failures)
    if failures:
        raise SystemExit("\n".join(failures))

    manuscript = arguments.manuscript.read_text(encoding="utf-8")
    tex = arguments.tex.read_text(encoding="utf-8")
    log = arguments.log.read_text(encoding="utf-8", errors="replace")

    require(
        manuscript.count(r"\begin{figure}") == 49,
        "Manuscript does not contain exactly 49 generated diagrams.",
        failures,
    )
    require(
        manuscript.count("## Worked solution") == 47,
        "Manuscript does not contain exactly 47 worked solutions.",
        failures,
    )
    require(
        manuscript.count(r"\appendix") == 1,
        "Manuscript must contain one appendix marker.",
        failures,
    )

    observed_counts: dict[str, int] = {}
    for label, (pattern, expected) in EXPECTED_COUNTS.items():
        observed = len(pattern.findall(tex))
        observed_counts[label] = observed
        require(
            observed == expected,
            f"Expected {expected} {label}; generated {observed}.",
            failures,
        )

    diagram_aspects = diagram_coordinate_aspects(tex)
    require(
        len(diagram_aspects) == EXPECTED_COUNTS["figures"][1],
        "Could not measure every generated diagram.",
        failures,
    )
    require(
        all(aspect <= MAXIMUM_HORIZONTAL_DIAGRAM_ASPECT_RATIO for aspect in diagram_aspects),
        "Generated diagrams contain an unreadably wide layout.",
        failures,
    )

    page_match = re.search(
        r"Output written on .*?\((\d+) pages,\s*(\d+) bytes\)\.",
        log,
    )
    require(page_match is not None, "LuaLaTeX log has no completed PDF record.", failures)
    pages = int(page_match.group(1)) if page_match else 0
    require(pages >= 500, f"Expected a complete book of at least 500 pages; got {pages}.", failures)

    for label, pattern in FORBIDDEN_LOG_PATTERNS.items():
        matches = pattern.findall(log)
        require(not matches, f"LaTeX log contains {len(matches)} {label}.", failures)

    require(
        arguments.pdf.read_bytes() == arguments.published.read_bytes(),
        "Published PDF differs from the verified build PDF.",
        failures,
    )

    try:
        pdf_text = extract_pdf_text(arguments.pdf)
    except (FileNotFoundError, subprocess.CalledProcessError) as error:
        failures.append(f"Ghostscript text extraction failed: {error}")
        pdf_text = ""
    for required_text in REQUIRED_PDF_TEXT:
        require(
            required_text in pdf_text,
            f"PDF text layer is missing: {required_text}",
            failures,
        )

    if failures:
        print("Book verification failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        raise SystemExit(1)

    print(
        "Verified "
        f"{pages} pages, {observed_counts['readable chapters']} readable chapters, "
        f"{observed_counts['figures']} diagrams, "
        f"{observed_counts['worked solutions']} worked solutions, and "
        f"{observed_counts['implementation points']} implementation points."
    )


if __name__ == "__main__":
    main()

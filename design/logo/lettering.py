"""Turn a word into outlines, so a concept can move, cut and recolour its letters.

HarfBuzz joins the Arabic letters and places the marks, and the outlines come
out as SVG path data with their exact bounds.
"""
import os

import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIRS = (os.path.join(HERE, 'fonts'), os.path.join(HERE, '..', 'remake', 'fonts'))
_faces = {}


def _face(name):
    if name not in _faces:
        for folder in FONT_DIRS:
            path = os.path.join(folder, name)
            if os.path.exists(path):
                _faces[name] = hb.Face(hb.Blob.from_file_path(path))
                break
        else:
            raise FileNotFoundError(name)
    return _faces[name]


def _around(boxes):
    return (
        min(b[0] for b in boxes), min(b[1] for b in boxes),
        max(b[2] for b in boxes), max(b[3] for b in boxes),
    )


class Word:
    """One shaped run. `glyphs` keeps each glyph apart, in the order it is drawn, left to right."""

    def __init__(self, glyphs):
        self.glyphs = glyphs
        self.box = _around([glyph['box'] for glyph in glyphs if glyph['box']])

    @property
    def width(self):
        return self.box[2] - self.box[0]

    @property
    def height(self):
        return self.box[3] - self.box[1]


def shape(font_name, text, size, variations=None):
    """Outlines of `text` at `size`, y down, with the baseline at y = 0 and the run starting at x = 0.

    Each glyph comes with its closed shapes apart (`contours`), all of them as one path (`d`),
    its bounds (`box`) and whether it is a mark that sits on another letter (`mark`).
    """
    face = _face(font_name)
    font = hb.Font(face)
    if variations:
        font.set_variations(variations)
    buffer = hb.Buffer()
    buffer.add_str(text)
    buffer.guess_segment_properties()
    hb.shape(font, buffer)
    scale = size / face.upem

    glyphs = []
    x = y = 0
    for info, pos in zip(buffer.glyph_infos, buffer.glyph_positions):
        recording = RecordingPen()
        font.draw_glyph_with_pen(info.codepoint, recording)
        matrix = (scale, 0, 0, -scale, (x + pos.x_offset) * scale, -(y + pos.y_offset) * scale)
        contours = [_outline(part, matrix) for part in _contours(recording.value)]
        glyphs.append({
            'mark': pos.x_advance == 0,
            'contours': contours,
            'd': ' '.join(contour['d'] for contour in contours),
            'box': _around([contour['box'] for contour in contours]) if contours else None,
        })
        x += pos.x_advance
        y += pos.y_advance
    return Word(glyphs)


def _contours(operations):
    """Split a recorded glyph into its closed shapes."""
    parts, current = [], []
    for operation in operations:
        if operation[0] == 'moveTo' and current:
            parts.append(current)
            current = []
        current.append(operation)
    if current:
        parts.append(current)
    return parts


def _outline(operations, matrix):
    recording = RecordingPen()
    recording.value = list(operations)
    svg = SVGPathPen(None, ntos=lambda v: f'{v:.2f}'.rstrip('0').rstrip('.'))
    recording.replay(TransformPen(svg, matrix))
    bounds = BoundsPen(None)
    recording.replay(TransformPen(bounds, matrix))
    return {'d': svg.getCommands(), 'box': bounds.bounds}

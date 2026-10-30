# Text, bytes and selectable units

Values are UTF-8 strings. `Text_Position.character_index` is an AccessKit
character index within the referenced TextRun, not a UTF-8 byte offset. Supply
`node_set_character_lengths` with one byte-length entry per selectable unit
using the application's Unicode segmentation policy. The setter copies the
slice into AccessKit; it does not take its Odin allocation.

The pinned C API stores each length in u8. A selectable unit longer than 255
UTF-8 bytes cannot be represented by this field. Reject or explicitly handle
that case; never silently truncate it or split Unicode units merely to fit.
The binding does not choose grapheme boundaries or import a shaping engine.

A TextField/TextArea owns a child TextRun (or multiple runs). Put text content
in the run value, publish lengths and selection, and keep stable IDs. A
selection contains an anchor and focus position and preserves direction.
Validate indices against the current document revision before applying an
action. Screen-reader focus/navigation and keyboard focus have distinct host
responsibilities; TreeUpdate focus is the keyboard focus within the tree.

Static Label nodes store readable text in their value. Controls store their
accessible name in the label. Suppress decorative or duplicated visual text
at the toolkit layer. The binding neither merges nor retains a second tree.

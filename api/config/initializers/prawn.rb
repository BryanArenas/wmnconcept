# The report renderer uses Prawn's built-in AFM fonts (no bundled TTF). Silence
# the internationalization warning — the PLACEHOLDER report is ASCII, and the
# certified OIR-B1-1802 layout (spec §13) will bring its own embedded font.
require "prawn"
Prawn::Fonts::AFM.hide_m17n_warning = true

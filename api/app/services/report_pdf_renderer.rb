# Renders an inspection's report to PDF bytes with Prawn (spec §9, M6).
#
# IMPORTANT (spec §13): this renders the PLACEHOLDER form schema, NOT the
# certified OIR-B1-1802 layout. OIR fidelity is a legal requirement and the exact
# current form + a known-good sample are required inputs before this is finalized.
# The pipeline (generate → persist → deliver) is what M6 proves out; the visual
# layout is deliberately swappable — everything specific lives in this one class.
require "prawn"
require "prawn/table"

class ReportPdfRenderer
  BRAND_RED = "E11D2A"
  INK = "0A0A0A"
  MUTED = "57534E"
  HAIRLINE = "E7E5E4"

  def initialize(inspection)
    @inspection = inspection
    @property   = inspection.property
    @homeowner  = inspection.homeowner
    @agency     = inspection.agency
    @response   = inspection.inspection_form_response
    @photos     = inspection.inspection_photos.uploaded.order(:created_at)
  end

  # Returns the rendered PDF as a binary string.
  def render
    doc = Prawn::Document.new(page_size: "LETTER", margin: 54)
    build_header(doc)
    build_meta(doc)
    build_placeholder_notice(doc)
    build_form_section(doc)
    build_photos_section(doc)
    build_footer(doc)
    doc.render
  end

  private

  def build_header(doc)
    doc.fill_color BRAND_RED
    doc.text "WINDMITIGATION.NETWORK", size: 14, style: :bold, character_spacing: 1
    doc.fill_color MUTED
    doc.text "Inspection Report", size: 9, character_spacing: 2
    doc.move_down 6
    doc.stroke_color HAIRLINE
    doc.stroke_horizontal_rule
    doc.move_down 16

    doc.fill_color INK
    doc.text "#{type_label} Inspection", size: 20, style: :bold
    doc.fill_color MUTED
    doc.text property_address, size: 11
    doc.fill_color INK
    doc.move_down 16
  end

  def build_meta(doc)
    rows = [
      ["Inspection ID", @inspection.id],
      ["Homeowner", @homeowner.name],
      ["Agency", @agency.name],
      ["Inspector", @inspection.assigned_inspector&.name || "—"],
      ["Scheduled", fmt_time(@inspection.scheduled_at)],
      ["Completed", fmt_time(@inspection.submitted_at)],
      ["Fee", format("$%.2f", @inspection.price_cents / 100.0)]
    ]

    doc.table(rows, width: doc.bounds.width, cell_style: { borders: [:bottom],
                                                           border_color: HAIRLINE,
                                                           padding: [6, 4] }) do
      column(0).font_style = :bold
      column(0).width = 130
      column(0).text_color = MUTED
    end
    doc.move_down 18
  end

  def build_placeholder_notice(doc)
    doc.fill_color MUTED
    doc.text_box(
      "Best-guess schema · placeholder. This layout renders the interim form " \
      "schema and is not the certified OIR-B1-1802 form.",
      at: [0, doc.cursor], width: doc.bounds.width, size: 8, style: :italic
    )
    doc.move_down 22
    doc.fill_color INK
  end

  def build_form_section(doc)
    doc.text "Captured on site", size: 13, style: :bold
    doc.move_down 8

    answers = @response&.responses || {}
    if answers.empty?
      doc.fill_color MUTED
      doc.text "No form responses captured.", size: 10, style: :italic
      doc.fill_color INK
    else
      rows = form_field_rows(answers)
      doc.table(rows, width: doc.bounds.width, cell_style: { borders: [:bottom],
                                                             border_color: HAIRLINE,
                                                             padding: [6, 4], size: 10 }) do
        column(0).font_style = :bold
        column(0).width = 200
        column(0).text_color = MUTED
      end
    end
    doc.move_down 18
  end

  # Prefer the template's field labels/order; fall back to raw keys for any
  # answer not in the template (schema drift resilience).
  def form_field_rows(answers)
    template = @inspection.organization.inspection_form_templates
                          .find_by(inspection_type: @inspection.inspection_type)
    fields = template&.fields || []

    ordered = fields.map do |f|
      [f["label"] || f["key"], present_value(answers[f["key"]])]
    end
    extra_keys = answers.keys - fields.map { |f| f["key"] }
    ordered + extra_keys.map { |k| [k.humanize, present_value(answers[k])] }
  end

  def present_value(value)
    case value
    when nil, "" then "—"
    when Array   then value.join(", ")
    when true    then "Yes"
    when false   then "No"
    else value.to_s
    end
  end

  def build_photos_section(doc)
    doc.text "Photos (#{@photos.size})", size: 13, style: :bold
    doc.move_down 8

    if @photos.empty?
      doc.fill_color MUTED
      doc.text "No photos captured.", size: 10, style: :italic
      doc.fill_color INK
      return
    end

    @photos.each do |photo|
      embed_or_list(doc, photo)
    end
  end

  # Embed the image when the bytes are retrievable; otherwise list a reference
  # line. Stub uploads (dev/test) have no bytes, so listing is the norm there.
  def embed_or_list(doc, photo)
    bytes = fetch_photo_bytes(photo)
    if bytes
      doc.image(StringIO.new(bytes), fit: [220, 220])
      doc.move_down 4
      doc.fill_color MUTED
      doc.text(photo.filename.to_s, size: 8)
      doc.fill_color INK
      doc.move_down 10
    else
      doc.fill_color MUTED
      doc.text "• #{photo.filename || photo.s3_key}", size: 9
      doc.fill_color INK
    end
  rescue Prawn::Errors::UnsupportedImageType, StandardError
    doc.fill_color MUTED
    doc.text "• #{photo.filename || photo.s3_key} (preview unavailable)", size: 9
    doc.fill_color INK
  end

  def fetch_photo_bytes(photo)
    return nil unless ReportStorageService.s3_configured?

    ReportStorageService.read(photo.s3_key)
  end

  def build_footer(doc)
    doc.move_down 24
    doc.stroke_color HAIRLINE
    doc.stroke_horizontal_rule
    doc.move_down 6
    doc.fill_color MUTED
    doc.text "Generated #{fmt_time(Time.current)} · Wind Mitigation Network LLC",
             size: 8
    doc.fill_color INK
  end

  def type_label
    @inspection.inspection_type.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
  end

  def property_address
    [@property.address, @property.city, @property.state, @property.zip].compact.join(", ")
  end

  def fmt_time(time)
    return "—" if time.blank?

    time.in_time_zone(@inspection.organization.timezone.presence || "UTC")
        .strftime("%b %-d, %Y %-l:%M %p")
  end
end

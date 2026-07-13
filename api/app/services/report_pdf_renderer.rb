require "prawn"
require "prawn/table"

class ReportPdfRenderer
  BRAND_RED = "E11D2A"
  INK = "0A0A0A"
  MUTED = "57534E"
  HAIRLINE = "E7E5E4"
  LIGHT_BG = "F5F5F4"

  # OIR-B1-1802 section groupings — keys that belong to each labeled section.
  # Fields not listed here render in a "General" catch-all at the bottom.
  WIND_MIT_SECTIONS = [
    { title: "1. Building Code",            keys: %w[year_built building_code permit_date] },
    { title: "2. Roof Covering",            keys: %w[roof_cover_type roof_cover_fbc_equivalent roof_permit_date] },
    { title: "3. Roof Deck Attachment",      keys: %w[roof_deck_attachment] },
    { title: "4. Roof-to-Wall Attachment",   keys: %w[roof_to_wall_connection] },
    { title: "5. Roof Geometry",            keys: %w[roof_geometry hip_percent] },
    { title: "6. Secondary Water Resistance", keys: %w[swr] },
    { title: "7. Opening Protection",        keys: %w[opening_protection garage_door_braced entry_doors_rated] }
  ].freeze

  def initialize(inspection)
    @inspection = inspection
    @property   = inspection.property
    @homeowner  = inspection.homeowner
    @agency     = inspection.agency
    @response   = inspection.inspection_form_response
    @photos     = inspection.inspection_photos.uploaded.order(:created_at)
    @template   = inspection.organization.inspection_form_templates
                            .find_by(inspection_type: inspection.inspection_type)
  end

  def render
    doc = Prawn::Document.new(page_size: "LETTER", margin: [48, 54, 54, 54])
    build_header(doc)
    build_meta(doc)
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
    doc.text "Uniform Mitigation Verification Inspection Report", size: 9, character_spacing: 1.5
    doc.move_down 6
    doc.stroke_color BRAND_RED
    doc.line_width = 1.5
    doc.stroke_horizontal_rule
    doc.line_width = 1
    doc.move_down 14

    doc.fill_color INK
    doc.text "#{type_label} Inspection Report", size: 18, style: :bold
    doc.move_down 2
    doc.fill_color MUTED
    doc.text property_address, size: 11
    doc.fill_color INK
    doc.move_down 14
  end

  def build_meta(doc)
    rows = [
      ["Inspection ID",  @inspection.id[0..7].upcase],
      ["Homeowner",      @homeowner.name],
      ["Agency",         @agency.name],
      ["Inspector",      @inspection.assigned_inspector&.name || "—"],
      ["License #",      @inspection.assigned_inspector&.license_number || "—"],
      ["Scheduled",      fmt_time(@inspection.scheduled_at)],
      ["Completed",      fmt_time(@inspection.submitted_at)],
      ["Fee",            format("$%.2f", @inspection.price_cents / 100.0)]
    ]

    doc.table(rows, width: doc.bounds.width, cell_style: { borders: [:bottom],
                                                           border_color: HAIRLINE,
                                                           padding: [5, 4],
                                                           size: 10 }) do
      column(0).font_style = :bold
      column(0).width = 120
      column(0).text_color = MUTED
    end
    doc.move_down 18
  end

  def build_form_section(doc)
    answers = @response&.responses || {}
    fields = @template&.fields || []

    if @inspection.inspection_type == "wind_mitigation" && fields.any?
      build_wind_mit_sections(doc, answers, fields)
    else
      build_generic_form(doc, answers, fields)
    end
  end

  def build_wind_mit_sections(doc, answers, fields)
    field_map = fields.index_by { |f| f["key"] }
    rendered_keys = Set.new

    WIND_MIT_SECTIONS.each do |section|
      section_fields = section[:keys].filter_map { |k| field_map[k] }
      next if section_fields.empty?

      section_header(doc, section[:title])
      rows = section_fields.map do |f|
        rendered_keys << f["key"]
        [f["label"] || f["key"].humanize, present_value(answers[f["key"]])]
      end
      section_table(doc, rows)
      doc.move_down 10
    end

    # Remaining fields not in any OIR section
    remaining = fields.reject { |f| rendered_keys.include?(f["key"]) }
    if remaining.any?
      extra_rows = remaining.map do |f|
        [f["label"] || f["key"].humanize, present_value(answers[f["key"]])]
      end
      unless extra_rows.all? { |_, v| v == "—" }
        section_header(doc, "Additional Notes")
        section_table(doc, extra_rows)
        doc.move_down 10
      end
    end
  end

  def build_generic_form(doc, answers, fields)
    section_header(doc, "Inspection Findings")

    if answers.empty? && fields.empty?
      doc.fill_color MUTED
      doc.text "No form responses captured.", size: 10, style: :italic
      doc.fill_color INK
      doc.move_down 14
      return
    end

    rows = form_field_rows(answers, fields)
    section_table(doc, rows)
    doc.move_down 14
  end

  def section_header(doc, title)
    doc.fill_color BRAND_RED
    doc.text title, size: 12, style: :bold
    doc.move_down 4
    doc.stroke_color HAIRLINE
    doc.stroke_horizontal_rule
    doc.move_down 6
    doc.fill_color INK
  end

  def section_table(doc, rows)
    doc.table(rows, width: doc.bounds.width, cell_style: { borders: [:bottom],
                                                           border_color: HAIRLINE,
                                                           padding: [5, 4],
                                                           size: 10 }) do
      column(0).font_style = :bold
      column(0).width = 200
      column(0).text_color = MUTED
      cells.each_with_index do |cell, i|
        cell.background_color = LIGHT_BG if (i / 2).odd?
      end
    end
  end

  def form_field_rows(answers, fields)
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
    doc.start_new_page if doc.cursor < 120
    section_header(doc, "Site Photos (#{@photos.size})")

    if @photos.empty?
      doc.fill_color MUTED
      doc.text "No photos captured.", size: 10, style: :italic
      doc.fill_color INK
      return
    end

    @photos.each_with_index do |photo, i|
      doc.start_new_page if doc.cursor < 100
      embed_or_list(doc, photo, i + 1)
    end
  end

  def embed_or_list(doc, photo, num)
    bytes = fetch_photo_bytes(photo)
    if bytes
      doc.image(StringIO.new(bytes), fit: [240, 240])
      doc.move_down 3
      doc.fill_color MUTED
      doc.text "Photo #{num}: #{photo.filename.to_s}", size: 8
      doc.fill_color INK
      doc.move_down 10
    else
      doc.fill_color MUTED
      doc.text "Photo #{num}: #{photo.filename || photo.s3_key}", size: 9
      doc.fill_color INK
      doc.move_down 4
    end
  rescue Prawn::Errors::UnsupportedImageType, StandardError
    doc.fill_color MUTED
    doc.text "Photo #{num}: #{photo.filename || photo.s3_key} (preview unavailable)", size: 9
    doc.fill_color INK
    doc.move_down 4
  end

  def fetch_photo_bytes(photo)
    return nil unless ReportStorageService.s3_configured?

    ReportStorageService.read(photo.s3_key)
  end

  def build_footer(doc)
    doc.move_down 20
    doc.stroke_color BRAND_RED
    doc.line_width = 1.5
    doc.stroke_horizontal_rule
    doc.line_width = 1
    doc.move_down 6
    doc.fill_color MUTED
    doc.text "Report generated #{fmt_time(Time.current)}", size: 8
    doc.text "Wind Mitigation Network LLC · windmitigation.network", size: 8
    doc.move_down 4
    doc.text "This report is based on a visual inspection of accessible areas only. " \
             "Conditions may exist that were not observed or accessible at the time of inspection.",
             size: 7, style: :italic
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

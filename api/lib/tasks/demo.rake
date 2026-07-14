# Rich demo data so every screen has something to show: inspections spread
# across all §6 states, a timeline that feeds Recent Activity, invoices in a
# few statuses, and pending intake requests. Development only.
#
#   bin/rails demo:load     # reset demo data, then build a fresh set
#   bin/rails demo:reset     # remove demo data (keeps org, staff, agencies, pricing)
#
# Everything hangs off the seeded WMN org from db/seeds.rb, so run seeds first.
namespace :demo do
  desc "Load rich demo data (inspections across all states, invoices, activity)."
  task load: :environment do
    guard!
    data = DemoData.new
    data.reset!
    data.build!
    puts data.summary
  end

  desc "Remove demo-generated data (keeps org, staff, agencies, pricing)."
  task reset: :environment do
    guard!
    DemoData.new.reset!
    puts "Demo data cleared."
  end

  def guard!
    abort "demo tasks are development-only (RAILS_ENV=#{Rails.env})" unless Rails.env.development?
  end
end

# Plain-ActiveRecord demo builder. Sets statuses directly and writes the timeline
# by hand (backdated occurred_at) rather than driving the real transitions — so
# it needs no background worker, no S3, and no Stripe, and stays deterministic.
class DemoData
  LIFECYCLE = %w[created assigned scheduled started submitted approved delivered].freeze

  OWNERS = [
    "Dana Whitfield", "Marcus Reyes", "Priya Nair", "Tobias Lindqvist",
    "Elena Sørensen", "Jamal Carter", "Rosa Delgado", "Wen Li",
    "Grace Okoro", "Henry Beaumont", "Aisha Rahman", "Diego Santos",
    "Nina Petrova", "Samuel Adeyemi", "Clara Nguyen", "Owen Fitzgerald",
    "Beatriz Alves", "Kofi Mensah", "Lena Vogel", "Ravi Chandra"
  ].freeze

  ADDRESSES = [
    ["1420 Coronado Rd", "Fort Myers", "33901", "Lee"],
    ["87 Miramar St", "Cape Coral", "33904", "Lee"],
    ["3310 Del Prado Blvd", "Cape Coral", "33904", "Lee"],
    ["915 SE 47th Ter", "Cape Coral", "33904", "Lee"],
    ["2201 First St", "Fort Myers", "33901", "Lee"],
    ["640 Estero Blvd", "Fort Myers Beach", "33931", "Lee"],
    ["1150 Collier Blvd", "Marco Island", "34145", "Collier"],
    ["788 5th Ave S", "Naples", "34102", "Collier"],
    ["3400 Gulf Shore Blvd", "Naples", "34103", "Collier"],
    ["221 Fleischmann Blvd", "Naples", "34102", "Collier"],
    ["45 Barkley Cir", "Fort Myers", "33907", "Lee"],
    ["9820 Gulf Coast Dr", "Bonita Springs", "34135", "Lee"],
    ["512 Cape Coral Pkwy", "Cape Coral", "33904", "Lee"],
    ["1701 Jackson St", "Fort Myers", "33901", "Lee"],
    ["300 Tower Rd", "Naples", "34113", "Collier"],
    ["77 Vivante Blvd", "Punta Gorda", "33950", "Charlotte"],
    ["4500 Bayshore Dr", "Naples", "34112", "Collier"],
    ["1290 Sanibel Captiva Rd", "Sanibel", "33957", "Lee"],
    ["660 Goodlette Rd", "Naples", "34102", "Collier"],
    ["2800 Winkler Ave", "Fort Myers", "33916", "Lee"]
  ].freeze

  DEMO_INSPECTOR_EMAILS = %w[
    maria.demo@windmitigation.network
    derek.demo@windmitigation.network
  ].freeze

  # How many inspections to place in each state (drives every operational screen).
  DISTRIBUTION = {
    "unassigned"           => 3,
    "assigned"             => 2,
    "scheduled"            => 4,
    "in_progress"          => 2,
    "submitted_for_review" => 3,
    "approved"             => 1,
    "delivered"            => 3
  }.freeze

  def initialize
    @org         = Organization.find_by!(subdomain: "wmn")
    @gulf        = agency!("Gulf Coast Insurance")
    @bayfront    = agency!("Bayfront Realty")
    @coordinator = @org.users.find_by!(role: "coordinator")
    @manager     = @org.users.find_by!(role: "manager")
    @config_by_type = @org.inspection_type_configs.index_by(&:inspection_type)
    @template_by_type = @org.inspection_form_templates.index_by(&:inspection_type)
    @types = @config_by_type.keys
    @cursor = 0
    @counts = Hash.new(0)
  end

  # Remove everything this task creates; leave org, staff, agencies, pricing.
  def reset!
    @org.inspections.destroy_all      # cascades events, photos, form response, report, invoice
    @org.inspection_requests.destroy_all
    @org.properties.destroy_all
    @org.homeowners.destroy_all
    @org.users.where(email: DEMO_INSPECTOR_EMAILS).destroy_all
  end

  def build!
    @inspectors = ensure_inspectors
    build_open_requests   # pending triage + a declined one
    build_inspections     # one accepted request each, across all states
  end

  def summary
    "Demo data loaded: inspections=#{@org.inspections.count} " \
      "(#{DISTRIBUTION.map { |s, _| "#{s}:#{@org.inspections.where(status: s).count}" }.join(' ')}) " \
      "requests=#{@org.inspection_requests.count} invoices=#{@org.invoices.count} " \
      "events=#{@org.inspection_events.count} inspectors=#{@inspectors.size}"
  end

  private

  def agency!(name)
    @org.agencies.find_by!(name: name)
  end

  # Seeded Ivan + two confirmed demo inspectors, so dispatch has real choices.
  def ensure_inspectors
    demo = DEMO_INSPECTOR_EMAILS.each_with_index.map do |email, i|
      @org.users.find_or_create_by!(email: email) do |u|
        u.name = ["Maria Delgado", "Derek Osei"][i]
        u.role = "inspector"
        u.license_number = "HI-#{20_100 + i}"
        u.office = @org.offices.first
        u.active = true
        u.password = "password123"
        u.confirmed_at = Time.current
      end
    end
    (@org.users.where(role: "inspector").to_a + demo).uniq
  end

  # A handful of requests the coordinator still has to triage, plus one declined,
  # so the Requests screen and the dashboard "pending" count aren't empty.
  def build_open_requests
    3.times do
      req = new_request(status: "submitted")
      log_counts(:pending_request)
      req
    end

    # Build as submitted, then decline — decline_reason is required on declined.
    declined = new_request(status: "submitted")
    declined.update!(status: "declined", decline_reason: "Property is outside our service area.")
    log_counts(:declined_request)
  end

  def build_inspections
    DISTRIBUTION.each do |status, n|
      n.times { build_inspection(status) }
    end
  end

  def build_inspection(status)
    request = new_request(status: "accepted")
    type = request.requested_types.first        # spawned inspection matches the request
    config = @config_by_type[type]
    inspector = @inspectors[@counts[:inspection] % @inspectors.size]

    created_at = created_anchor(status)
    scheduled_at = scheduled_time(status, created_at)

    inspection = @org.inspections.create!(
      inspection_request: request,
      agency: request.agency,
      property: request.property,
      homeowner: request.homeowner,
      inspection_type: type,
      price_cents: config.price_cents,
      status: status,
      assigned_inspector: assigned?(status) ? inspector : nil,
      scheduled_at: scheduled_at,
      started_at: timestamp_for(status, "started", created_at, scheduled_at),
      submitted_at: timestamp_for(status, "submitted", created_at, scheduled_at),
      approved_at: timestamp_for(status, "approved", created_at, scheduled_at),
      delivered_at: timestamp_for(status, "delivered", created_at, scheduled_at),
      created_at: created_at,
      updated_at: Time.current
    )

    invoice = build_invoice(inspection, status)
    build_timeline(inspection, status, created_at, scheduled_at, invoice)

    # Captured evidence exists once it's been submitted for review or beyond, so
    # the review pane has form answers + photos to show.
    if lifecycle_index(status) >= 4
      build_form_response(inspection)
      build_photos(inspection)
    end
    build_report(inspection) if status == "delivered"

    @counts[:inspection] += 1
    log_counts(status.to_sym)
    inspection
  end

  # ---- captured evidence -----------------------------------------------------

  def build_form_response(inspection)
    template = @template_by_type[inspection.inspection_type]
    return unless template

    fields = template.schema["fields"] || []
    responses = fields.each_with_object({}) { |f, h| h[f["key"]] = demo_answer(f) }
    inspection.create_inspection_form_response!(organization: @org, responses: responses)
  end

  PHOTO_NAMES = [
    "elevation-front.jpg", "roof-covering.jpg", "roof-deck-attachment.jpg",
    "roof-to-wall.jpg", "opening-protection.jpg", "attic-swr.jpg", "permit-photo.jpg"
  ].freeze

  def build_photos(inspection)
    PHOTO_NAMES.sample(rand(3..5)).each do |name|
      inspection.inspection_photos.create!(
        organization: @org,
        s3_key: "inspections/#{inspection.id}/photos/#{SecureRandom.uuid}.jpg",
        filename: name,
        content_type: "image/jpeg",
        upload_state: "uploaded"
      )
    end
  end

  def demo_answer(field)
    case field["type"]
    when "select"       then (field["options"] || ["N/A"]).sample
    when "multi_select" then Array((field["options"] || []).sample)
    when "boolean"      then [true, false].sample
    when "number"       then demo_number(field["key"].to_s)
    else demo_text(field["key"].to_s)
    end
  end

  def demo_number(key)
    return rand(1978..2019) if key.include?("year") || key.include?("permit")
    return rand(1..25)      if key.include?("age") || key.include?("years") || key.include?("life")
    return [100, 75, 50].sample if key.include?("percent")
    return rand(1200..3800) if key.include?("sqft") || key.include?("area")

    rand(1..12)
  end

  def demo_text(key)
    return ["Clean install, no issues noted.", "Minor wear consistent with age.",
            "Homeowner reports no active leaks."].sample if key.include?("note")

    "Verified on site"
  end

  # ---- requests / properties / homeowners -----------------------------------

  def new_request(status:)
    agency = next_agency
    property = next_property
    homeowner = next_homeowner
    @org.inspection_requests.create!(
      agency: agency,
      property: property,
      homeowner: homeowner,
      submitted_by_agency_user: agency.agency_users.first,
      requested_types: [next_requested_type],
      preferred_dates: ["Weekday mornings", "Any afternoon", "ASAP — closing soon"].sample,
      notes: ["Gate code 4417.", "Dog on site — call ahead.", "Lockbox on front door.", nil].sample,
      status: status
    )
  end

  def next_property
    addr, city, zip, county = ADDRESSES[@cursor % ADDRESSES.size]
    structure = %w[single_family single_family condo commercial hoa_master].sample
    @cursor += 1
    Property.create!(
      organization: @org, address: "#{addr} ##{@cursor}", city: city, state: "FL",
      zip: zip, county: county, structure_type: structure
    )
  end

  def next_homeowner
    name = OWNERS[@counts[:homeowner] % OWNERS.size]
    @counts[:homeowner] += 1
    handle = name.downcase.gsub(/[^a-z]+/, ".")
    @org.homeowners.create!(
      name: name, email: "#{handle}#{@counts[:homeowner]}@example.com",
      phone: "239-555-0#{format('%03d', 100 + @counts[:homeowner])}"
    )
  end

  def next_agency
    (@counts[:agency_pick] += 1).even? ? @gulf : @bayfront
  end

  def next_requested_type
    @types[(@counts[:type_pick] += 1) % @types.size]
  end

  # ---- invoices / reports ----------------------------------------------------

  # Billing happens at scheduling (RequestPaymentJob), so anything scheduled or
  # later carries an invoice. Delivered ones are mostly paid.
  def build_invoice(inspection, status)
    return nil unless %w[scheduled in_progress submitted_for_review approved delivered].include?(status)

    invoice_status = status == "delivered" ? %w[paid paid sent].sample : "sent"
    @org.invoices.create!(
      agency: inspection.agency,
      inspection: inspection,
      amount_cents: InvoiceAmount.for(inspection),
      billing_mode: inspection.agency.billing_mode,
      status: invoice_status,
      due_at: 14.days.from_now
    )
  end

  def build_report(inspection)
    report = @org.reports.create!(
      inspection: inspection,
      s3_key: "demo/reports/#{inspection.id}.pdf",
      generated_at: inspection.approved_at || 2.days.ago,
      delivered_at: inspection.delivered_at
    )
    report.update!(delivered_to: [
      { email: inspection.homeowner.email, role: "homeowner", status: "sent",
        delivered_at: inspection.delivered_at.iso8601 },
      { email: inspection.agency.primary_contact_email, role: "agency", status: "sent",
        delivered_at: inspection.delivered_at.iso8601 }
    ])
    report
  end

  # ---- timeline --------------------------------------------------------------

  def build_timeline(inspection, status, created_at, scheduled_at, invoice)
    reached = LIFECYCLE[0..lifecycle_index(status)]
    steps = reached.size
    reached.each_with_index do |kind, i|
      at = spread_time(created_at, i, steps)
      kind, message, to_status = event_details(kind, inspection, scheduled_at)
      @org.inspection_events.create!(
        inspection: inspection, kind: kind, message: message,
        from_status: (i.zero? ? nil : LIFECYCLE_TO_STATUS[reached[i - 1]]),
        to_status: to_status, occurred_at: at,
        actor_label: actor_for(kind), actor_type: nil, actor_id: nil
      )
    end

    if invoice&.status == "paid"
      @org.inspection_events.create!(
        inspection: inspection, kind: "payment_received",
        message: "Payment received (placeholder) — #{money(invoice.amount_cents)}",
        occurred_at: (inspection.delivered_at || inspection.scheduled_at || Time.current) - 1.hour
      )
    end
  end

  LIFECYCLE_TO_STATUS = {
    "created" => "unassigned", "assigned" => "assigned", "scheduled" => "scheduled",
    "started" => "in_progress", "submitted" => "submitted_for_review",
    "approved" => "approved", "delivered" => "delivered"
  }.freeze

  def event_details(kind, inspection, scheduled_at)
    case kind
    when "created"   then ["created", "Created from agency request", "unassigned"]
    when "assigned"  then ["assigned", "Assigned to #{inspection.assigned_inspector&.name}", "assigned"]
    when "scheduled" then ["scheduled", "Scheduled for #{scheduled_at&.strftime('%b %-d, %-l:%M %p')}", "scheduled"]
    when "started"   then ["started", "Inspection started", "in_progress"]
    when "submitted" then ["submitted", "Submitted for review", "submitted_for_review"]
    when "approved"  then ["approved", "Approved — generating report", "approved"]
    when "delivered" then ["delivered", "Report delivered", "delivered"]
    end
  end

  def actor_for(kind)
    case kind
    when "created" then "Gulf Coast Insurance"
    when "started", "submitted" then "Field inspector"
    when "approved" then @manager.name
    when "delivered", "payment_received" then "System"
    else @coordinator.name
    end
  end

  # ---- timing helpers --------------------------------------------------------

  def lifecycle_index(status)
    { "unassigned" => 0, "assigned" => 1, "scheduled" => 2, "in_progress" => 3,
      "submitted_for_review" => 4, "approved" => 5, "delivered" => 6 }.fetch(status)
  end

  def created_anchor(status)
    days = { "unassigned" => 1, "assigned" => 2, "scheduled" => 3, "in_progress" => 4,
             "submitted_for_review" => 5, "approved" => 7, "delivered" => 10 }.fetch(status)
    (days.days.ago + rand(0..8).hours)
  end

  # Future for scheduled (populates the calendar), recent past otherwise.
  def scheduled_time(status, created_at)
    case status
    when "scheduled"   then (rand(1..6).days.from_now.change(hour: [9, 11, 13, 15].sample))
    when "in_progress" then Time.current.change(hour: 9)
    when "assigned", "unassigned" then nil
    else created_at + 2.days
    end
  end

  def assigned?(status)
    status != "unassigned"
  end

  def timestamp_for(status, phase, created_at, scheduled_at)
    idx = lifecycle_index(status)
    phase_idx = { "started" => 3, "submitted" => 4, "approved" => 5, "delivered" => 6 }.fetch(phase)
    return nil if idx < phase_idx

    base = scheduled_at || created_at
    offsets = { "started" => 0.hours, "submitted" => 3.hours, "approved" => 1.day, "delivered" => 1.day + 2.hours }
    (base.is_a?(Time) ? base : created_at) + offsets.fetch(phase)
  end

  def spread_time(created_at, i, steps)
    return created_at if steps <= 1

    span = (Time.current - created_at)
    created_at + (span * i / steps.to_f)
  end

  def money(cents)
    format("$%.2f", cents / 100.0)
  end

  def log_counts(key)
    @counts[key] += 1
  end
end

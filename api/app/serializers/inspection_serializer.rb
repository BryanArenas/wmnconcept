module InspectionSerializer
  module_function

  def call(inspection)
    {
      id: inspection.id,
      status: inspection.status,
      inspection_type: inspection.inspection_type,
      price_cents: inspection.price_cents,
      agency_id: inspection.agency_id,
      agency_name: inspection.agency.name,
      property_id: inspection.property_id,
      property_address: [inspection.property.address, inspection.property.city]
                          .compact.join(", "),
      homeowner_id: inspection.homeowner_id,
      homeowner_name: inspection.homeowner.name,
      inspection_request_id: inspection.inspection_request_id,
      assigned_inspector_id: inspection.assigned_inspector_id,
      assigned_inspector_name: inspection.assigned_inspector&.name,
      scheduled_at: inspection.scheduled_at,
      started_at: inspection.started_at,
      submitted_at: inspection.submitted_at,
      approved_at: inspection.approved_at,
      delivered_at: inspection.delivered_at,
      rejection_note: inspection.rejection_note,
      # M6 — report/invoice presence flags so detail screens can render the
      # report card + billing line without a second round-trip. The signed
      # download URL is fetched lazily via GET …/report (spec §8.4).
      has_report: inspection.report.present?,
      report_generated_at: inspection.report&.generated_at,
      report_delivered_at: inspection.report&.delivered_at,
      has_invoice: inspection.invoice.present?,
      invoice_amount_cents: inspection.invoice&.amount_cents,
      invoice_status: inspection.invoice&.status,
      created_at: inspection.created_at
    }
  end
end

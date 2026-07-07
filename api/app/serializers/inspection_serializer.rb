module InspectionSerializer
  module_function

  def call(inspection)
    {
      id: inspection.id,
      status: inspection.status,
      inspection_type: inspection.inspection_type,
      price_cents: inspection.price_cents,
      agency_id: inspection.agency_id,
      property_id: inspection.property_id,
      homeowner_id: inspection.homeowner_id,
      inspection_request_id: inspection.inspection_request_id,
      assigned_inspector_id: inspection.assigned_inspector_id,
      scheduled_at: inspection.scheduled_at,
      started_at: inspection.started_at,
      submitted_at: inspection.submitted_at,
      approved_at: inspection.approved_at,
      delivered_at: inspection.delivered_at,
      rejection_note: inspection.rejection_note,
      created_at: inspection.created_at
    }
  end
end

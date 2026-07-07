module InspectionRequestSerializer
  module_function

  def call(req)
    {
      id: req.id,
      status: req.status,
      requested_types: req.requested_types,
      preferred_dates: req.preferred_dates,
      notes: req.notes,
      decline_reason: req.decline_reason,
      agency_id: req.agency_id,
      agency_name: req.agency.name,
      property: property_snippet(req.property),
      homeowner: homeowner_snippet(req.homeowner),
      created_at: req.created_at
    }
  end

  def property_snippet(p)
    { id: p.id, address: p.address, city: p.city, state: p.state, zip: p.zip }
  end

  def homeowner_snippet(h)
    { id: h.id, name: h.name, email: h.email, phone: h.phone }
  end
end

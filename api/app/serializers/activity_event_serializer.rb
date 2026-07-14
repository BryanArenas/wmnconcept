# Row shape for the dashboard Recent Activity feed. Built from an
# InspectionEvent (the append-only §6 timeline) plus a little inspection context
# so each row is self-describing without a follow-up fetch.
module ActivityEventSerializer
  module_function

  def call(event)
    inspection = event.inspection
    property = inspection&.property
    {
      id: event.id,
      kind: event.kind,
      message: event.message,
      actor_label: event.actor_label,
      to_status: event.to_status,
      occurred_at: event.occurred_at.iso8601,
      inspection_id: event.inspection_id,
      property_address: property && [property.address, property.city].compact.join(", ")
    }
  end
end

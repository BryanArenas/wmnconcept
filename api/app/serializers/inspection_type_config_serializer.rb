module InspectionTypeConfigSerializer
  module_function

  def call(config)
    {
      id: config.id,
      inspection_type: config.inspection_type,
      label: config.label,
      price_cents: config.price_cents,
      active: config.active
    }
  end
end

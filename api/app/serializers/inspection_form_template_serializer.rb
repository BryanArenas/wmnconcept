module InspectionFormTemplateSerializer
  module_function

  def call(template)
    {
      id: template.id,
      inspection_type: template.inspection_type,
      schema: template.schema,
      active: template.active,
      position: template.position
    }
  end
end

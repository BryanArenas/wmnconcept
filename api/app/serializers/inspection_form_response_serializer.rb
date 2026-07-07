module InspectionFormResponseSerializer
  module_function

  def call(form_response)
    {
      id: form_response.id,
      inspection_id: form_response.inspection_id,
      responses: form_response.responses,
      updated_at: form_response.updated_at
    }
  end
end

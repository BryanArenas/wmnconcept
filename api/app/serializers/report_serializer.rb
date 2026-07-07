module ReportSerializer
  module_function

  # download_url is computed on demand (signed) by the controller and passed in,
  # since it is short-lived and shouldn't be persisted in a list payload.
  def call(report, download_url: nil)
    {
      id: report.id,
      inspection_id: report.inspection_id,
      filename: File.basename(report.s3_key),
      generated_at: report.generated_at,
      delivered_at: report.delivered_at,
      delivered_to: report.delivered_to,
      download_url:
    }
  end
end

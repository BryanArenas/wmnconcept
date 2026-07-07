# Fires when an inspection enters `approved` (spec §6, §9). Generates the PDF
# report, then hands off to DeliverReportJob which advances the inspection to
# `delivered`. THE INVARIANT (spec §6, §9): an inspection never auto-advances to
# `delivered` without a persisted PDF. On final failure it HOLDS at `approved`
# and the manager is alerted — it must not call `deliver!`.
#
# Body lands in M6 (Opus @ xhigh). Until then this is a safe no-op that holds at
# `approved`, which is exactly the correct default: no PDF pipeline yet ⇒ no
# delivery. Do not shortcut this to `deliver!` to make demos look finished.
class GenerateReportPdfJob < ApplicationJob
  queue_as :default

  # Spec §9: retry 3× with backoff; on final failure alert the manager and hold.
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(inspection)
    Rails.logger.info(
      "[GenerateReportPdfJob] inspection=#{inspection.id} — PDF pipeline lands in M6; " \
      "holding at `approved` (never `delivered` without a PDF)."
    )
    # M6: render PDF → persist Report → DeliverReportJob.perform_later(report)
    # which, on delivery success, calls inspection.deliver!.
  end
end

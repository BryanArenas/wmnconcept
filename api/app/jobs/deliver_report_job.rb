# Fires after a report PDF is generated (spec §9). Emails/links the report to
# every associated party and records a per-recipient delivery ledger in
# `reports.delivered_to`; partial success re-enqueues only the failed recipients.
# On full delivery success it advances the inspection to `delivered` (spec §6
# "(auto)" edge), which in turn fires CreateInvoiceJob.
#
# Body lands in M6. Stubbed as a no-op until the report/delivery models exist.
class DeliverReportJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(report)
    Rails.logger.info(
      "[DeliverReportJob] report=#{report&.id} — delivery pipeline lands in M6."
    )
    # M6: deliver to homeowner + agency; on full success call
    # report.inspection.deliver!
  end
end

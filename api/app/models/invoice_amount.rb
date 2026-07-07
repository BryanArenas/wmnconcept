# The single place invoice amounts are computed (ADR 0002). Kept out of the job
# so the formula is unit-testable and swaps in one edit when the real commission
# terms arrive.
#
#   fixed_rate  → the full inspection fee
#   commission  → commission owed to the agency: price * commission_rate
module InvoiceAmount
  module_function

  def for(inspection)
    agency = inspection.agency
    if agency.billing_commission?
      (inspection.price_cents * agency.commission_rate).round
    else
      inspection.price_cents
    end
  end
end

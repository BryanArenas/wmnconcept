module InvoiceSerializer
  module_function

  def call(invoice)
    {
      id: invoice.id,
      inspection_id: invoice.inspection_id,
      agency_id: invoice.agency_id,
      amount_cents: invoice.amount_cents,
      billing_mode: invoice.billing_mode,
      status: invoice.status,
      stripe_invoice_id: invoice.stripe_invoice_id,
      due_at: invoice.due_at,
      created_at: invoice.created_at
    }
  end
end

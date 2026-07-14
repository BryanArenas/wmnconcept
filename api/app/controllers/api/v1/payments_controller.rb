module Api
  module V1
    # Public placeholder pay page backing the /pay/:id link emailed on scheduling
    # (spec §11 — payment collection is a PLACEHOLDER until the live Stripe
    # account lands). The invoice id is an unguessable UUID, so the link is the
    # capability, exactly like a Stripe-hosted invoice URL. `confirm` simulates a
    # successful payment and is refused once real Stripe is configured, so it can
    # never become a free "mark paid" in production.
    #
    # Inherits ApplicationController (not BaseController): the payer has no session.
    class PaymentsController < ApplicationController
      # GET /api/v1/pay/:id
      def show
        invoice = Invoice.find(params[:id])
        render json: payment_payload(invoice)
      end

      # POST /api/v1/pay/:id/confirm — placeholder settlement, no real charge.
      def confirm
        invoice = Invoice.find(params[:id])

        return render json: payment_payload(invoice) if invoice.status == "paid"

        if StripeGateway.configured?
          return render_error(
            code: "stripe_configured",
            message: "Live payments are enabled — use the Stripe payment link.",
            status: :unprocessable_content
          )
        end

        unless invoice.payable?
          return render_error(
            code: "not_payable",
            message: "This invoice can no longer be paid (status: #{invoice.status}).",
            status: :unprocessable_content
          )
        end

        invoice.mark_paid!
        invoice.inspection.record_event(
          kind: "payment_received",
          message: "Payment received (placeholder) — #{format('$%.2f', invoice.amount_dollars)}"
        )

        render json: payment_payload(invoice.reload)
      end

      private

      def payment_payload(invoice)
        inspection = invoice.inspection
        property = inspection.property
        {
          id: invoice.id,
          amount_cents: invoice.amount_cents,
          status: invoice.status,
          agency_name: invoice.agency.name,
          inspection_type: inspection.inspection_type,
          property_address: [property.address, property.city, property.state, property.zip]
            .compact.join(", "),
          placeholder: !StripeGateway.configured?
        }
      end
    end
  end
end

module Api
  module V1
    # Billing surface (spec §4, §8.5, M7). Read is tenancy-scoped (agency→own,
    # office staff→all); send is staff-only and transitions draft → sent, creates
    # the Stripe invoice, and emails the pay link.
    class InvoicesController < BaseController
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize Invoice
        scope = policy_scope(Invoice).includes(:agency, :inspection)
        scope = scope.where(status: params[:status]) if params[:status].present?
        invoices, next_cursor = paginate(scope)
        render json: {
          data: invoices.map { |i| InvoiceSerializer.call(i) },
          meta: { next_cursor: }
        }
      end

      def show
        invoice = find_scoped_invoice
        authorize invoice
        render json: { data: InvoiceSerializer.call(invoice) }
      end

      # POST /invoices/:id/send — create the Stripe invoice, mark sent, email it.
      # Idempotent-ish: re-sending an already-sent invoice reuses its Stripe id
      # (StripeGateway stub is derived from our id) and re-notifies.
      def send_invoice
        invoice = find_scoped_invoice
        authorize invoice, :send_invoice?

        unless invoice.payable?
          return render_error(
            code: "not_payable",
            message: "Only draft or sent invoices can be sent (status: #{invoice.status}).",
            status: :unprocessable_content
          )
        end

        stripe_invoice_id = StripeGateway.create_invoice(invoice)
        invoice.mark_sent!(stripe_invoice_id:)
        SendInvoiceEmailJob.perform_later(invoice)

        render json: { data: InvoiceSerializer.call(invoice) }
      end

      private

      def find_scoped_invoice
        policy_scope(Invoice).find(params[:id])
      end
    end
  end
end

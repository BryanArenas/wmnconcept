module Api
  module V1
    module Webhooks
      # Inbound Stripe webhooks (spec §4, §9). Public + signature-verified — it
      # inherits ApplicationController (not BaseController) so there is no session
      # auth, and forgery protection is skipped because there is no browser
      # session to protect.
      #
      # The controller does the minimum synchronously: verify, record idempotently
      # in webhook_events, enqueue StripeWebhookJob. A redelivery of an already-
      # recorded event returns 200 without re-enqueuing, so side effects apply
      # exactly once (spec §9 — never double-bill).
      class StripeController < ApplicationController
        skip_forgery_protection

        def create
          payload   = request.body.read
          signature = request.headers["Stripe-Signature"]

          begin
            event = StripeGateway.parse_webhook(payload:, signature:)
          rescue StripeGateway::VerificationError
            return render_error(code: "invalid_signature",
                                message: "Webhook signature verification failed",
                                status: :bad_request)
          rescue JSON::ParserError
            return render_error(code: "invalid_payload",
                                message: "Malformed webhook payload",
                                status: :bad_request)
          end

          external_id = event["id"]
          return head :bad_request if external_id.blank?

          _record, created = WebhookEvent.record(
            provider: "stripe", external_id:, payload: event
          )

          # Only the first delivery enqueues processing; a duplicate is acked 200
          # and dropped (the original event's job applies the side effects).
          StripeWebhookJob.perform_later(_record.id) if created

          head :ok
        end
      end
    end
  end
end

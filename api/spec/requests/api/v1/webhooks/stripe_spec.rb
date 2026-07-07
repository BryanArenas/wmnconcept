require "rails_helper"

# Inbound Stripe webhook endpoint (spec §4, §9). Public + idempotent. In test
# STRIPE_WEBHOOK_SECRET is unset, so payloads are parsed without signature
# verification (the verification path is unit-covered by StripeGateway).
RSpec.describe "API V1 Stripe webhooks", type: :request do
  let(:org)     { create(:organization) }
  let(:agency)  { create(:agency, organization: org) }
  let(:invoice) { create(:invoice, :sent, organization: org, agency: agency) }

  def event_body(id:, intent_id: "pi_x")
    {
      id:,
      type: "payment_intent.succeeded",
      data: { object: { id: intent_id, amount: invoice.amount_cents,
                        metadata: { invoice_id: invoice.id } } }
    }.to_json
  end

  describe "POST /api/v1/webhooks/stripe" do
    it "records the event and enqueues processing (happy path)" do
      expect {
        post "/api/v1/webhooks/stripe", params: event_body(id: "evt_a"),
                                        headers: { "CONTENT_TYPE" => "application/json" }
      }.to change(WebhookEvent, :count).by(1)
        .and have_enqueued_job(StripeWebhookJob)

      expect(response).to have_http_status(:ok)
    end

    it "is idempotent — a redelivered event is not recorded or enqueued twice" do
      post "/api/v1/webhooks/stripe", params: event_body(id: "evt_dup"),
                                      headers: { "CONTENT_TYPE" => "application/json" }

      expect {
        post "/api/v1/webhooks/stripe", params: event_body(id: "evt_dup"),
                                        headers: { "CONTENT_TYPE" => "application/json" }
      }.not_to change(WebhookEvent, :count)

      expect(response).to have_http_status(:ok)
    end

    it "processes the full path to a paid invoice (integration)" do
      perform_enqueued_jobs do
        post "/api/v1/webhooks/stripe", params: event_body(id: "evt_int", intent_id: "pi_int"),
                                        headers: { "CONTENT_TYPE" => "application/json" }
      end

      expect(invoice.reload.status).to eq("paid")
      expect(Payment.where(stripe_payment_intent_id: "pi_int").count).to eq(1)
    end

    it "returns 400 on a malformed payload (edge)" do
      post "/api/v1/webhooks/stripe", params: "not-json",
                                      headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when the event has no id (edge)" do
      post "/api/v1/webhooks/stripe", params: { type: "payment_intent.succeeded" }.to_json,
                                      headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:bad_request)
    end
  end
end

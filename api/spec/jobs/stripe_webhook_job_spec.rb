require "rails_helper"

# The money-correctness core (spec §9, §14). Two independent idempotency layers
# must hold: (1) the same webhook event never applies twice; (2) the same charge
# never creates two Payments even across distinct events.
RSpec.describe StripeWebhookJob, type: :job do
  let(:org)     { create(:organization) }
  let(:agency)  { create(:agency, organization: org) }
  let(:invoice) { create(:invoice, :sent, organization: org, agency: agency, amount_cents: 17_500) }

  def payment_event(external_id:, intent_id:, invoice_id: invoice.id, amount: 17_500)
    {
      "id" => external_id,
      "type" => "payment_intent.succeeded",
      "data" => {
        "object" => {
          "id" => intent_id,
          "amount" => amount,
          "metadata" => { "invoice_id" => invoice_id }
        }
      }
    }
  end

  describe "happy path — records payment and marks the invoice paid" do
    it "creates a Payment and flips the invoice to paid" do
      event = create(:webhook_event, external_id: "evt_1",
                                     payload: payment_event(external_id: "evt_1", intent_id: "pi_1"))

      expect { StripeWebhookJob.perform_now(event.id) }.to change(Payment, :count).by(1)

      expect(invoice.reload.status).to eq("paid")
      payment = Payment.last
      expect(payment.amount_cents).to eq(17_500)
      expect(payment.stripe_payment_intent_id).to eq("pi_1")
      expect(event.reload.processed_at).to be_present
    end
  end

  describe "layer 1 — same event processed twice (webhook_events guard)" do
    it "applies side effects exactly once" do
      event = create(:webhook_event, external_id: "evt_2",
                                     payload: payment_event(external_id: "evt_2", intent_id: "pi_2"))

      StripeWebhookJob.perform_now(event.id)
      expect {
        StripeWebhookJob.perform_now(event.id) # redelivery / retry
      }.not_to change(Payment, :count)

      expect(Payment.where(stripe_payment_intent_id: "pi_2").count).to eq(1)
    end
  end

  describe "layer 2 — two distinct events, same charge (payments unique guard)" do
    it "never double-bills for the same payment intent" do
      e1 = create(:webhook_event, external_id: "evt_3a",
                                  payload: payment_event(external_id: "evt_3a", intent_id: "pi_shared"))
      e2 = create(:webhook_event, external_id: "evt_3b",
                                  payload: payment_event(external_id: "evt_3b", intent_id: "pi_shared"))

      StripeWebhookJob.perform_now(e1.id)
      expect { StripeWebhookJob.perform_now(e2.id) }.not_to change(Payment, :count)

      expect(Payment.where(stripe_payment_intent_id: "pi_shared").count).to eq(1)
      expect(e2.reload.processed_at).to be_present # still marked handled
    end
  end

  describe "edge — event for an unknown invoice" do
    it "marks the event processed without creating a payment" do
      event = create(:webhook_event, external_id: "evt_4",
                                     payload: payment_event(external_id: "evt_4", intent_id: "pi_4",
                                                            invoice_id: SecureRandom.uuid))

      expect { StripeWebhookJob.perform_now(event.id) }.not_to change(Payment, :count)
      expect(event.reload.processed_at).to be_present
    end
  end

  describe "edge — non-payment event type" do
    it "is acknowledged (processed) but has no billing side effect" do
      event = create(:webhook_event, external_id: "evt_5",
                                     payload: { "id" => "evt_5", "type" => "customer.created",
                                                "data" => { "object" => {} } })

      expect { StripeWebhookJob.perform_now(event.id) }.not_to change(Payment, :count)
      expect(event.reload.processed_at).to be_present
    end
  end
end

require "rails_helper"

# End-to-end integration of the three critical journeys (spec §12.8). Each drives
# the real HTTP endpoints in sequence — auth, policies, serializers, the §6 state
# machine, and the §9 jobs — so the whole build is exercised as one flow, not just
# per-action. This is the capstone regression net.
RSpec.describe "Critical journeys", type: :request do
  let(:org) { create(:organization) }

  before do
    create(:inspection_type_config, organization: org, inspection_type: "wind_mitigation",
                                    label: "Wind Mitigation", price_cents: 17_500)
  end

  # ── Journey 1: agency request → coordinator triage → dispatch → field →
  #    review → delivery → invoice. The full company loop (spec §1). ──────────
  describe "Journey 1 — agency request through to delivered report + invoice" do
    it "runs the whole loop across every surface" do
      agency      = create(:agency, organization: org, primary_contact_email: "ops@agency.example")
      agency_user = create(:agency_user, organization: org, agency: agency)
      coordinator = create(:user, :coordinator, organization: org)
      inspector   = create(:user, :inspector, organization: org)
      manager     = create(:user, :manager, organization: org)
      create(:inspection_form_template, :one_required_field,
             organization: org, inspection_type: "wind_mitigation")

      # 1. Agency submits an intake request.
      sign_in_via_omniauth(agency_user)
      post "/api/v1/inspection_requests", params: {
        property: { address: "42 Bayshore", city: "Fort Myers", state: "FL", zip: "33901" },
        homeowner: { name: "Dana Owner", email: "dana@owner.example" },
        inspection_request: { requested_types: ["wind_mitigation"] }
      }
      expect(response).to have_http_status(:created)
      request_id = response.parsed_body.dig("data", "id")

      # 2. Coordinator accepts → one inspection spawned (unassigned).
      sign_in_via_omniauth(coordinator)
      post "/api/v1/inspection_requests/#{request_id}/accept"
      expect(response).to have_http_status(:ok)
      inspection_id = response.parsed_body["inspections"].first["id"]
      expect(response.parsed_body["inspections"].first["status"]).to eq("unassigned")

      # 3. Coordinator assigns + schedules.
      post "/api/v1/inspections/#{inspection_id}/assign",
           params: { inspection: { inspector_id: inspector.id } }
      expect(response.parsed_body.dig("data", "status")).to eq("assigned")
      post "/api/v1/inspections/#{inspection_id}/schedule",
           params: { inspection: { scheduled_at: 2.days.from_now.iso8601 } }
      expect(response.parsed_body.dig("data", "status")).to eq("scheduled")

      # 4. Inspector performs the field capture.
      sign_in_via_omniauth(inspector)
      post "/api/v1/inspections/#{inspection_id}/start"
      expect(response.parsed_body.dig("data", "status")).to eq("in_progress")

      put "/api/v1/inspections/#{inspection_id}/form_response",
          params: { form_response: { responses: { "roof_cover_type" => "shingle" } } }
      expect(response).to have_http_status(:ok)

      post "/api/v1/inspections/#{inspection_id}/photos",
           params: { photo: { filename: "roof.jpg", content_type: "image/jpeg" } }
      photo_id = response.parsed_body.dig("data", "id")
      patch "/api/v1/inspections/#{inspection_id}/photos/#{photo_id}/confirm"
      expect(response).to have_http_status(:ok)

      # 5. Inspector submits — evidence gate satisfied (photo + required field).
      post "/api/v1/inspections/#{inspection_id}/submit"
      expect(response.parsed_body.dig("data", "status")).to eq("submitted_for_review")

      # 6. Manager approves → the report → deliver → invoice pipeline runs.
      sign_in_via_omniauth(manager)
      perform_enqueued_jobs do
        post "/api/v1/inspections/#{inspection_id}/approve"
      end
      expect(response).to have_http_status(:ok)

      inspection = Inspection.find(inspection_id)
      expect(inspection.status).to eq("delivered")
      expect(inspection.report).to be_present
      expect(inspection.report.delivered_at).to be_present
      expect(inspection.invoice).to be_present
      expect(inspection.invoice.amount_cents).to eq(17_500)

      # 7. Agency can now retrieve the delivered report + see the invoice.
      sign_in_via_omniauth(agency_user)
      get "/api/v1/inspections/#{inspection_id}/report"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "download_url")).to be_present

      get "/api/v1/invoices"
      expect(response.parsed_body["data"].size).to eq(1)
    end
  end

  # ── Journey 2: inspector field → submit, including the evidence guard. ──────
  describe "Journey 2 — inspector field capture guards submission on evidence" do
    it "blocks submit until a photo AND required fields exist, then allows it" do
      agency    = create(:agency, organization: org)
      inspector = create(:user, :inspector, organization: org)
      inspection = create(:inspection, :scheduled, organization: org, agency: agency,
                                                    assigned_inspector: inspector)
      create(:inspection_form_template, :one_required_field,
             organization: org, inspection_type: "wind_mitigation")
      sign_in_via_omniauth(inspector)

      post "/api/v1/inspections/#{inspection.id}/start"
      expect(response.parsed_body.dig("data", "status")).to eq("in_progress")

      # No evidence yet → submit is guarded (422 invalid_transition).
      post "/api/v1/inspections/#{inspection.id}/submit"
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_transition")

      # Photo only, required field still missing → still guarded.
      post "/api/v1/inspections/#{inspection.id}/photos",
           params: { photo: { filename: "a.jpg", content_type: "image/jpeg" } }
      photo_id = response.parsed_body.dig("data", "id")
      patch "/api/v1/inspections/#{inspection.id}/photos/#{photo_id}/confirm"
      post "/api/v1/inspections/#{inspection.id}/submit"
      expect(response).to have_http_status(:unprocessable_content)

      # Add the required field → gate opens.
      put "/api/v1/inspections/#{inspection.id}/form_response",
          params: { form_response: { responses: { "roof_cover_type" => "tile" } } }
      post "/api/v1/inspections/#{inspection.id}/submit"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("submitted_for_review")
    end
  end

  # ── Journey 3: manager approve → invoice → send → Stripe webhook → paid. ────
  describe "Journey 3 — approve through invoice send and Stripe payment" do
    it "delivers, invoices, sends, and marks paid on the webhook" do
      agency  = create(:agency, organization: org, primary_contact_email: "ops@agency.example")
      manager = create(:user, :manager, organization: org)
      org_admin = create(:user, :org_admin, organization: org)
      inspection = create(:inspection, :submitted_for_review, organization: org, agency: agency)
      create(:inspection_photo, :uploaded, organization: org, inspection: inspection)

      # Approve → full pipeline → delivered + draft invoice.
      sign_in_via_omniauth(manager)
      perform_enqueued_jobs do
        post "/api/v1/inspections/#{inspection.id}/approve"
      end
      invoice = inspection.reload.invoice
      expect(inspection.status).to eq("delivered")
      expect(invoice.status).to eq("draft")

      # Staff sends the invoice → sent + Stripe id.
      sign_in_via_omniauth(org_admin)
      post "/api/v1/invoices/#{invoice.id}/send"
      expect(response).to have_http_status(:ok)
      expect(invoice.reload.status).to eq("sent")

      # Stripe reports payment → webhook marks the invoice paid, records a Payment.
      event = {
        id: "evt_journey3",
        type: "payment_intent.succeeded",
        data: { object: { id: "pi_journey3", amount: invoice.amount_cents,
                          metadata: { invoice_id: invoice.id } } }
      }.to_json
      perform_enqueued_jobs do
        post "/api/v1/webhooks/stripe", params: event,
                                        headers: { "CONTENT_TYPE" => "application/json" }
      end
      expect(response).to have_http_status(:ok)
      expect(invoice.reload.status).to eq("paid")
      expect(Payment.where(stripe_payment_intent_id: "pi_journey3").count).to eq(1)
    end
  end
end

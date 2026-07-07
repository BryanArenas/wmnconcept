require "rails_helper"

RSpec.describe "API V1 Inspections", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/inspections" do
    it "returns all org inspections for a coordinator (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      agency = create(:agency, organization: org)
      create_list(:inspection, 3, organization: org, agency: agency)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspections"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(3)
      expect(response.parsed_body["meta"]).to have_key("next_cursor")
    end

    it "requires authentication" do
      get "/api/v1/inspections"
      expect(response).to have_http_status(:unauthorized)
    end

    it "agency user sees only their own agency's inspections (tenancy scope)" do
      agency_a = create(:agency, organization: org)
      agency_b = create(:agency, organization: org)
      user_a = create(:agency_user, organization: org, agency: agency_a)
      create(:inspection, organization: org, agency: agency_a)
      create(:inspection, organization: org, agency: agency_b)
      sign_in_via_omniauth(user_a)

      get "/api/v1/inspections"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["agency_id"]).to eq(agency_a.id)
    end

    it "inspector sees only their own assigned inspections (tenancy scope)" do
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      create(:inspection, :assigned, organization: org, agency: agency,
                                     assigned_inspector: inspector)
      create(:inspection, organization: org, agency: agency) # unassigned, different inspector
      sign_in_via_omniauth(inspector)

      get "/api/v1/inspections"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["assigned_inspector_id"]).to eq(inspector.id)
    end
  end

  describe "GET /api/v1/inspections/:id" do
    it "returns the inspection detail (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, organization: org, agency: agency,
                                       inspection_type: "wind_mitigation", price_cents: 17_500)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspections/#{inspection.id}"

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["id"]).to eq(inspection.id)
      expect(data["inspection_type"]).to eq("wind_mitigation")
      expect(data["price_cents"]).to eq(17_500)
    end

    it "requires authentication" do
      agency = create(:agency, organization: org)
      inspection = create(:inspection, organization: org, agency: agency)
      get "/api/v1/inspections/#{inspection.id}"
      expect(response).to have_http_status(:unauthorized)
    end

    it "cannot see an inspection from another org (cross-tenant → 404)" do
      coordinator = create(:user, :coordinator, organization: org)
      other_org = create(:organization)
      other_agency = create(:agency, organization: other_org)
      foreign = create(:inspection, organization: other_org, agency: other_agency)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspections/#{foreign.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/inspections (status filter)" do
    it "returns only inspections matching the requested status" do
      coordinator = create(:user, :coordinator, organization: org)
      agency = create(:agency, organization: org)
      create(:inspection, organization: org, agency: agency, status: "unassigned")
      create(:inspection, :assigned, organization: org, agency: agency)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/inspections", params: { status: "unassigned" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(1)
      expect(response.parsed_body["data"].first["status"]).to eq("unassigned")
    end
  end

  describe "POST /api/v1/inspections/:id/assign" do
    it "assigns an inspector and transitions to assigned (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, organization: org, agency: agency)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspections/#{inspection.id}/assign",
           params: { inspection: { inspector_id: inspector.id } }

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["status"]).to eq("assigned")
      expect(data["assigned_inspector_id"]).to eq(inspector.id)
      expect(data["assigned_inspector_name"]).to eq(inspector.name)
    end

    it "forbids an agency user from assigning (auth failure → 403)" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: agency)
      inspector = create(:user, :inspector, organization: org)
      inspection = create(:inspection, organization: org, agency: agency)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/inspections/#{inspection.id}/assign",
           params: { inspection: { inspector_id: inspector.id } }

      expect(response).to have_http_status(:forbidden)
      expect(inspection.reload).to be_unassigned
    end

    it "returns 422 when trying to assign an already-assigned inspection (edge)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :assigned, organization: org, agency: agency,
                                                  assigned_inspector: inspector)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspections/#{inspection.id}/assign",
           params: { inspection: { inspector_id: inspector.id } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_transition")
    end
  end

  describe "POST /api/v1/inspections/:id/schedule" do
    it "sets scheduled_at and transitions to scheduled (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :assigned, organization: org, agency: agency,
                                                  assigned_inspector: inspector)
      sign_in_via_omniauth(coordinator)
      scheduled_time = 3.days.from_now.change(sec: 0)

      expect {
        post "/api/v1/inspections/#{inspection.id}/schedule",
             params: { inspection: { scheduled_at: scheduled_time.iso8601 } }
      }.to have_enqueued_job(InspectionReminderJob)

      expect(response).to have_http_status(:ok)
      data = response.parsed_body["data"]
      expect(data["status"]).to eq("scheduled")
      expect(data["scheduled_at"]).not_to be_nil
    end

    it "forbids an agency user (auth failure → 403)" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: agency)
      inspector = create(:user, :inspector, organization: org)
      inspection = create(:inspection, :assigned, organization: org, agency: agency,
                                                  assigned_inspector: inspector)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/inspections/#{inspection.id}/schedule",
           params: { inspection: { scheduled_at: 2.days.from_now.iso8601 } }

      expect(response).to have_http_status(:forbidden)
      expect(inspection.reload).to be_assigned
    end

    it "returns 422 when scheduled_at is missing (edge)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :assigned, organization: org, agency: agency,
                                                  assigned_inspector: inspector)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspections/#{inspection.id}/schedule",
           params: { inspection: { scheduled_at: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(inspection.reload).to be_assigned
    end
  end

  describe "POST /api/v1/inspections/:id/start" do
    it "inspector starts their own scheduled inspection (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :scheduled, organization: org, agency: agency,
                                                   assigned_inspector: inspector)
      sign_in_via_omniauth(inspector)

      post "/api/v1/inspections/#{inspection.id}/start"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("in_progress")
    end

    it "inspector cannot start another inspector's inspection (auth failure → 403)" do
      inspector_a = create(:user, :inspector, organization: org)
      inspector_b = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :scheduled, organization: org, agency: agency,
                                                   assigned_inspector: inspector_a)
      sign_in_via_omniauth(inspector_b)

      post "/api/v1/inspections/#{inspection.id}/start"

      # inspector_b can't see inspector_a's inspection (scope) — 404
      expect(response).to have_http_status(:not_found)
    end

    it "coordinator can start on behalf of inspector (edge)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :scheduled, organization: org, agency: agency,
                                                   assigned_inspector: inspector)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspections/#{inspection.id}/start"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("in_progress")
    end
  end

  describe "POST /api/v1/inspections/:id/cancel" do
    it "coordinator cancels an in-progress inspection (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                     assigned_inspector: inspector)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspections/#{inspection.id}/cancel"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("cancelled")
    end

    it "forbids agency users from cancelling (auth failure → 403)" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: agency)
      inspection = create(:inspection, organization: org, agency: agency)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/inspections/#{inspection.id}/cancel"

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 422 when cancelling an already-delivered inspection (edge)" do
      coordinator = create(:user, :coordinator, organization: org)
      inspector = create(:user, :inspector, organization: org)
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :delivered, organization: org, agency: agency,
                                                   assigned_inspector: inspector)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/inspections/#{inspection.id}/cancel"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_transition")
    end
  end

  # --- M5 Field capture -------------------------------------------------------

  describe "GET /api/v1/inspections/:id/form_template" do
    it "returns the form template for the inspection type (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      create(:inspection_form_template, organization: org, inspection_type: "wind_mitigation")
      sign_in_via_omniauth(inspector)

      get "/api/v1/inspections/#{inspection.id}/form_template"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.dig("data", "inspection_type")).to eq("wind_mitigation")
      expect(body.dig("data", "schema", "fields")).to be_an(Array)
    end

    it "returns 401 for unauthenticated request" do
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency)

      get "/api/v1/inspections/#{inspection.id}/form_template"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 when no template is configured for the type" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      sign_in_via_omniauth(inspector)

      get "/api/v1/inspections/#{inspection.id}/form_template"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/inspections/:id/photos" do
    it "creates a pending photo and returns a presigned URL (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      sign_in_via_omniauth(inspector)

      post "/api/v1/inspections/#{inspection.id}/photos",
           params: { photo: { filename: "roof.jpg", content_type: "image/jpeg" } }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body.dig("data", "upload_state")).to eq("pending")
      expect(body["presigned_url"]).to be_present
    end

    it "returns 401 for unauthenticated request" do
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency)

      post "/api/v1/inspections/#{inspection.id}/photos",
           params: { photo: { filename: "roof.jpg", content_type: "image/jpeg" } }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for agency user" do
      agency_user = create(:agency_user, organization: org, agency: create(:agency, organization: org))
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/inspections/#{inspection.id}/photos",
           params: { photo: { filename: "roof.jpg", content_type: "image/jpeg" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/inspections/:id/photos/:photo_id/confirm" do
    it "marks the photo as uploaded (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      photo = create(:inspection_photo, organization: org, inspection: inspection)
      sign_in_via_omniauth(inspector)

      patch "/api/v1/inspections/#{inspection.id}/photos/#{photo.id}/confirm"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "upload_state")).to eq("uploaded")
    end

    it "returns 401 for unauthenticated request" do
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency)
      photo = create(:inspection_photo, organization: org, inspection: inspection)

      patch "/api/v1/inspections/#{inspection.id}/photos/#{photo.id}/confirm"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PUT /api/v1/inspections/:id/form_response" do
    it "upserts form answers (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      sign_in_via_omniauth(inspector)

      put "/api/v1/inspections/#{inspection.id}/form_response",
          params: { form_response: { responses: { "roof_cover_type" => "shingle" } } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "responses", "roof_cover_type")).to eq("shingle")
    end

    it "overwrites existing responses on second PUT" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      create(:inspection_form_response, organization: org, inspection: inspection,
                                        responses: { "old_key" => "old_val" })
      sign_in_via_omniauth(inspector)

      put "/api/v1/inspections/#{inspection.id}/form_response",
          params: { form_response: { responses: { "new_key" => "new_val" } } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "responses")).to eq("new_key" => "new_val")
    end

    it "returns 401 for unauthenticated request" do
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency)

      put "/api/v1/inspections/#{inspection.id}/form_response",
          params: { form_response: { responses: {} } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/inspections/:id/submit" do
    it "transitions in_progress → submitted_for_review when evidence is complete (happy path)" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      # Evidence gate: ≥1 uploaded photo; no template → no form requirement.
      create(:inspection_photo, :uploaded, organization: org, inspection: inspection)
      sign_in_via_omniauth(inspector)

      post "/api/v1/inspections/#{inspection.id}/submit"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("submitted_for_review")
    end

    it "returns 422 when evidence gate fails (no uploaded photo)" do
      inspector = create(:user, :inspector, organization: org)
      agency    = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency,
                                                      assigned_inspector: inspector)
      sign_in_via_omniauth(inspector)

      post "/api/v1/inspections/#{inspection.id}/submit"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_transition")
    end

    it "returns 401 for unauthenticated request" do
      agency = create(:agency, organization: org)
      inspection = create(:inspection, :in_progress, organization: org, agency: agency)

      post "/api/v1/inspections/#{inspection.id}/submit"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end

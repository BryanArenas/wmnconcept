require "rails_helper"

RSpec.describe "API V1 Dashboard", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/dashboard" do
    it "returns real queue counts and recent activity (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)

      # Inspections hang off an already-accepted request so they don't inflate
      # the pending-requests count; one standalone submitted request does.
      accepted = create(:inspection_request, :accepted, organization: org)
      create(:inspection_request, organization: org) # status "submitted" by default
      create(:inspection, organization: org, inspection_request: accepted)                 # unassigned
      create_list(:inspection, 2, :scheduled, organization: org, inspection_request: accepted)
      create(:inspection, :submitted_for_review, organization: org, inspection_request: accepted)

      sign_in_via_omniauth(coordinator)

      get "/api/v1/dashboard"

      expect(response).to have_http_status(:ok)
      stats = response.parsed_body["stats"]
      expect(stats["pending_requests"]).to eq(1)
      expect(stats["unassigned"]).to eq(1)
      expect(stats["scheduled"]).to eq(2)
      expect(stats["awaiting_review"]).to eq(1)
    end

    it "surfaces recent timeline events, newest first" do
      coordinator = create(:user, :coordinator, organization: org)
      insp = create(:inspection, :scheduled, organization: org)
      create(:inspection_event, inspection: insp, organization: org,
                                kind: "scheduled", message: "Scheduled for tomorrow")

      sign_in_via_omniauth(coordinator)

      get "/api/v1/dashboard"

      kinds = response.parsed_body["activity"].map { |e| e["kind"] }
      expect(kinds).to include("scheduled")
    end

    it "does not leak another org's counts (tenancy)" do
      coordinator = create(:user, :coordinator, organization: org)
      other = create(:organization)
      create(:inspection, :scheduled, organization: other)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/dashboard"

      expect(response.parsed_body["stats"]["scheduled"]).to eq(0)
    end

    it "requires authentication" do
      get "/api/v1/dashboard"
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids agency users (auth failure → 403)" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency:)
      sign_in_via_omniauth(agency_user)

      get "/api/v1/dashboard"

      expect(response).to have_http_status(:forbidden)
    end
  end
end

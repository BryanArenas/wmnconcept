require "rails_helper"

RSpec.describe "API V1 Users", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/users" do
    it "returns active org users for a coordinator (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      create(:user, :inspector, organization: org, name: "Pat Inspector")
      _other_org = create(:user, :inspector, organization: create(:organization))
      sign_in_via_omniauth(coordinator)

      get "/api/v1/users"

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["data"].map { |u| u["name"] }
      expect(names).to include("Pat Inspector", coordinator.name)
      expect(names).not_to include(_other_org.name)
      expect(response.parsed_body["meta"]).to have_key("next_cursor")
    end

    it "requires authentication" do
      get "/api/v1/users"
      expect(response).to have_http_status(:unauthorized)
    end

    it "filters by role (inspector only for dispatch dropdown)" do
      coordinator = create(:user, :coordinator, organization: org)
      create(:user, :inspector, organization: org, name: "Iris Inspector")
      sign_in_via_omniauth(coordinator)

      get "/api/v1/users", params: { role: "inspector" }

      expect(response).to have_http_status(:ok)
      roles = response.parsed_body["data"].map { |u| u["role"] }
      expect(roles).to all(eq("inspector"))
      expect(roles).not_to include("coordinator")
    end

    it "forbids agency users (auth failure → 403)" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: agency)
      sign_in_via_omniauth(agency_user)

      get "/api/v1/users"

      expect(response).to have_http_status(:forbidden)
    end

    it "includes pending (unconfirmed) invites when status=all" do
      admin = create(:user, :org_admin, organization: org)
      pending = create(:user, :inspector, organization: org, name: "Newbie",
                                          active: false, confirmed_at: nil)
      sign_in_via_omniauth(admin)

      get "/api/v1/users", params: { status: "all" }

      names = response.parsed_body["data"].map { |u| u["name"] }
      expect(names).to include("Newbie")
      pending_flags = response.parsed_body["data"].find { |u| u["id"] == pending.id }
      expect(pending_flags["pending_invitation"]).to be(true)
    end
  end

  describe "POST /api/v1/users" do
    it "invites an inspector, created inactive/unconfirmed (happy path)" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      expect do
        post "/api/v1/users", params: {
          user: { name: "Ivan Inspector", email: "ivan@windmitigation.network",
                  role: "inspector", license_number: "HI-55555" }
        }
      end.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["invite_url"]).to include("/accept-invite?")
      expect(body["pending_invitation"]).to be(true)

      created = User.find_by(email: "ivan@windmitigation.network")
      expect(created.active).to be(false)
      expect(created.confirmed_at).to be_nil
      expect(created.organization).to eq(org)
    end

    it "requires authentication" do
      post "/api/v1/users", params: { user: { name: "X", email: "x@y.z", role: "inspector" } }
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids a coordinator from provisioning an elevated role (edge → 403)" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      expect do
        post "/api/v1/users", params: {
          user: { name: "Sneaky", email: "sneaky@windmitigation.network", role: "org_admin" }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("forbidden_role")
    end

    it "lets an org_admin provision any role" do
      admin = create(:user, :org_admin, organization: org)
      sign_in_via_omniauth(admin)

      post "/api/v1/users", params: {
        user: { name: "New Manager", email: "mgr@windmitigation.network", role: "manager" }
      }

      expect(response).to have_http_status(:created)
      expect(User.find_by(email: "mgr@windmitigation.network").role).to eq("manager")
    end

    it "forbids agency users from provisioning staff" do
      agency = create(:agency, organization: org)
      agency_user = create(:agency_user, organization: org, agency: agency)
      sign_in_via_omniauth(agency_user)

      post "/api/v1/users", params: {
        user: { name: "X", email: "x@windmitigation.network", role: "inspector" }
      }

      expect(response).to have_http_status(:forbidden)
    end
  end
end

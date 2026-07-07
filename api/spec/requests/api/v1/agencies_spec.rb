require "rails_helper"

RSpec.describe "API V1 Agencies", type: :request do
  let(:org) { create(:organization) }

  describe "GET /api/v1/agencies" do
    it "returns only the caller's own-org agencies (tenancy-scoped)" do
      admin = create(:user, :org_admin, organization: org)
      mine = create(:agency, organization: org, name: "Gulf Coast Insurance")
      _other_org_agency = create(:agency, organization: create(:organization), name: "Out of Tenant")
      sign_in_via_omniauth(admin)

      get "/api/v1/agencies"

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["data"].map { |a| a["name"] }
      expect(names).to contain_exactly("Gulf Coast Insurance")
      expect(names).not_to include("Out of Tenant")
      expect(response.parsed_body["meta"]).to have_key("next_cursor")
    end

    it "forbids non-admin staff (auth failure → 403)" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      get "/api/v1/agencies"

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("forbidden")
    end

    it "requires authentication" do
      get "/api/v1/agencies"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/agencies" do
    it "creates an agency and invites its first partner (org_admin)" do
      admin = create(:user, :org_admin, organization: org)
      sign_in_via_omniauth(admin)

      expect do
        post "/api/v1/agencies", params: {
          agency: {
            name: "Bayfront Realty", type: "real_estate", billing_mode: "fixed_rate",
            primary_contact_email: "ops@bayfront.example"
          },
          agency_user: { name: "Riley Realtor", email: "riley@bayfront.example" }
        }
      end.to change(Agency, :count).by(1).and change(AgencyUser, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "name")).to eq("Bayfront Realty")

      agency = Agency.find(response.parsed_body.dig("data", "id"))
      expect(agency.organization).to eq(org)
      expect(agency.agency_users.pluck(:email)).to eq(["riley@bayfront.example"])
    end

    it "rejects commission billing without a rate (edge → 422 envelope)" do
      admin = create(:user, :org_admin, organization: org)
      sign_in_via_omniauth(admin)

      post "/api/v1/agencies", params: {
        agency: { name: "No Rate Co", type: "insurance", billing_mode: "commission" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      error = response.parsed_body["error"]
      expect(error["code"]).to eq("unprocessable_entity")
      expect(error["details"].map { |d| d["field"] }).to include("commission_rate")
      expect(Agency.count).to eq(0) # transaction rolled back
    end

    it "forbids a coordinator from creating agencies" do
      coordinator = create(:user, :coordinator, organization: org)
      sign_in_via_omniauth(coordinator)

      post "/api/v1/agencies", params: { agency: { name: "Nope" } }

      expect(response).to have_http_status(:forbidden)
      expect(Agency.count).to eq(0)
    end
  end

  describe "POST /api/v1/agencies/:agency_id/agency_users" do
    it "invites a partner into an own-org agency (org_admin)" do
      admin = create(:user, :org_admin, organization: org)
      agency = create(:agency, organization: org)
      sign_in_via_omniauth(admin)

      expect do
        post "/api/v1/agencies/#{agency.id}/agency_users", params: {
          agency_user: { name: "Pat Partner", email: "pat@agency.example" }
        }
      end.to change { agency.agency_users.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "type")).to eq("agency")
    end

    it "cannot invite into another org's agency (cross-tenant → 404)" do
      admin = create(:user, :org_admin, organization: org)
      foreign_agency = create(:agency, organization: create(:organization))
      sign_in_via_omniauth(admin)

      post "/api/v1/agencies/#{foreign_agency.id}/agency_users", params: {
        agency_user: { name: "Intruder", email: "x@evil.example" }
      }

      expect(response).to have_http_status(:not_found)
      expect(foreign_agency.agency_users).to be_empty
    end
  end
end

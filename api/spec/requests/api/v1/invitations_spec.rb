require "rails_helper"

RSpec.describe "API V1 Invitations", type: :request do
  let(:org) { create(:organization) }

  def invited_inspector
    create(:user, :inspector, organization: org, active: false, confirmed_at: nil)
  end

  describe "GET /api/v1/invitations" do
    it "returns the invitee's details for a valid staff token (happy path)" do
      user = invited_inspector
      token = user.generate_token_for(:invitation)

      get "/api/v1/invitations", params: { token:, type: "staff" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["email"]).to eq(user.email)
      expect(response.parsed_body["name"]).to eq(user.name)
      expect(response.parsed_body["organization"]).to eq(org.name)
    end

    it "resolves an agency invitation token" do
      agency = create(:agency, organization: org)
      au = create(:agency_user, organization: org, agency:, active: false, confirmed_at: nil)
      token = au.generate_token_for(:invitation)

      get "/api/v1/invitations", params: { token:, type: "agency" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["email"]).to eq(au.email)
    end

    it "rejects an invalid/garbage token (edge → 422)" do
      get "/api/v1/invitations", params: { token: "not-a-real-token", type: "staff" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_invitation")
    end

    it "rejects an unknown surface type" do
      user = invited_inspector
      token = user.generate_token_for(:invitation)

      get "/api/v1/invitations", params: { token:, type: "martian" }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/invitations/accept" do
    it "sets the password, confirms + activates the account, and signs in (happy path)" do
      user = invited_inspector
      token = user.generate_token_for(:invitation)

      post "/api/v1/invitations/accept",
           params: { token:, type: "staff", password: "sup3rsecret" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["redirect_to"]).to eq("/today")

      user.reload
      expect(user.confirmed_at).to be_present
      expect(user.active).to be(true)
      expect(user.authenticate("sup3rsecret")).to be_truthy
    end

    it "rejects a password shorter than the minimum (edge → 422)" do
      user = invited_inspector
      token = user.generate_token_for(:invitation)

      post "/api/v1/invitations/accept",
           params: { token:, type: "staff", password: "short" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("weak_password")
      expect(user.reload.confirmed_at).to be_nil
    end

    it "rejects an invalid token" do
      post "/api/v1/invitations/accept",
           params: { token: "bogus", type: "staff", password: "sup3rsecret" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_invitation")
    end

    it "is single-use — the token no longer resolves once confirmed" do
      user = invited_inspector
      token = user.generate_token_for(:invitation)

      post "/api/v1/invitations/accept",
           params: { token:, type: "staff", password: "sup3rsecret" }
      expect(response).to have_http_status(:ok)

      # Re-using the same token after confirmation must fail (confirmed_at moved).
      post "/api/v1/invitations/accept",
           params: { token:, type: "staff", password: "an0therpass" }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end

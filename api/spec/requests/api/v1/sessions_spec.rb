require "rails_helper"

RSpec.describe "API V1 Sessions", type: :request do
  describe "GET /auth/:provider/callback (sessions#create)" do
    context "happy path — a provisioned, active staff user" do
      it "establishes the session and redirects into the staff shell" do
        organization = create(:organization)
        user = create(:user, :coordinator, organization: organization,
                                            email: "casey@windmitigation.network")

        sign_in_via_omniauth(user)

        expect(response).to have_http_status(:found)
        expect(response.location).to eq("http://localhost:3000/dashboard")

        # Session round-trip: the cookie set here authenticates the next request.
        get "/api/v1/me"
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("data", "email")).to eq("casey@windmitigation.network")
      end

      it "sends inspectors to the field shell" do
        organization = create(:organization)
        inspector = create(:user, :inspector, organization: organization,
                                              email: "ivan@windmitigation.network")

        sign_in_via_omniauth(inspector)

        expect(response.location).to eq("http://localhost:3000/today")
      end
    end

    context "auth failure — email is not a provisioned WMN account" do
      it "does not sign in and redirects to login with an error" do
        create(:organization) # org exists; the email just isn't a user
        mock_omniauth(email: "stranger@example.com", name: "Stranger")

        get "/auth/google_oauth2/callback"

        expect(response).to have_http_status(:found)
        expect(response.location).to eq("http://localhost:3000/login?error=not_authorized")

        get "/api/v1/me"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "edge — a deactivated user" do
      it "is refused even though the provider authenticated them" do
        organization = create(:organization)
        user = create(:user, :inactive, organization: organization,
                                        email: "former@windmitigation.network")

        sign_in_via_omniauth(user)

        expect(response.location).to eq("http://localhost:3000/login?error=not_authorized")
      end
    end
  end

  describe "DELETE /api/v1/session (sessions#destroy)" do
    it "clears the session (idempotent logout)" do
      organization = create(:organization)
      user = create(:user, :coordinator, organization: organization)
      sign_in_via_omniauth(user)

      delete "/api/v1/session"
      expect(response).to have_http_status(:no_content)

      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /auth/failure (sessions#failure)" do
    it "redirects to login with the provider message" do
      get "/auth/failure", params: { message: "invalid_credentials" }

      expect(response).to have_http_status(:found)
      expect(response.location).to eq("http://localhost:3000/login?error=invalid_credentials")
    end
  end
end

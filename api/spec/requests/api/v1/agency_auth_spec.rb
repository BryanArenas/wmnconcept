require "rails_helper"

# Agency users authenticate through the same OmniAuth callback but resolve to
# the separate agency_users table and land on the partner portal (spec §2).
RSpec.describe "API V1 Agency auth", type: :request do
  let(:org) { create(:organization) }

  it "signs an invited partner into the agency portal" do
    agency = create(:agency, organization: org, name: "Gulf Coast Insurance")
    partner = create(:agency_user, agency: agency, organization: org,
                                   email: "pat@agency.example", name: "Pat Partner")

    sign_in_via_omniauth(partner)

    expect(response).to have_http_status(:found)
    expect(response.location).to eq("http://localhost:3000/agency/dashboard")

    get "/api/v1/me"
    expect(response).to have_http_status(:ok)
    data = response.parsed_body["data"]
    expect(data["type"]).to eq("agency")
    expect(data["email"]).to eq("pat@agency.example")
    expect(data.dig("agency", "name")).to eq("Gulf Coast Insurance")
    expect(data).not_to have_key("role") # agency principals carry no staff role
  end

  it "prefers the staff identity when an email exists in both tables" do
    # Defense-in-depth: separate surfaces, staff resolved first.
    staff = create(:user, :coordinator, organization: org, email: "dual@windmitigation.network")
    agency = create(:agency, organization: org)
    create(:agency_user, agency: agency, organization: org, email: "dual@windmitigation.network")

    sign_in_via_omniauth(staff)

    expect(response.location).to eq("http://localhost:3000/dashboard")
    get "/api/v1/me"
    expect(response.parsed_body.dig("data", "type")).to eq("staff")
  end
end

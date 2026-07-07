require "rails_helper"

RSpec.describe AgencyUser, type: :model do
  describe "validations" do
    it "requires email unique per organization (case-insensitive)" do
      agency = create(:agency)
      create(:agency_user, agency: agency, email: "pat@agency.example")
      dup = build(:agency_user, agency: agency, organization: agency.organization,
                                email: "PAT@agency.example")

      expect(dup).not_to be_valid
      expect(dup.errors[:email]).to be_present
    end
  end

  describe "principal interface" do
    it "identifies as an agency principal with no staff role" do
      agency_user = build(:agency_user)

      expect(agency_user.agency?).to be(true)
      expect(agency_user.staff?).to be(false)
      expect(agency_user.org_admin?).to be(false)
      expect(agency_user.inspector?).to be(false)
    end
  end

  describe ".from_omniauth" do
    let(:organization) { create(:organization) }
    let(:agency) { create(:agency, organization: organization) }
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "google_oauth2", uid: "agency-123",
        info: { email: "pat@agency.example", name: "Pat" }
      )
    end

    it "links the identity to a matching invited partner on first login" do
      partner = create(:agency_user, agency: agency, organization: organization,
                                     email: "pat@agency.example")

      found = described_class.from_omniauth(auth, organization: organization)

      expect(found).to eq(partner)
      expect(found.omniauth_uid).to eq("agency-123")
    end

    it "returns nil for an email with no invited partner" do
      expect(described_class.from_omniauth(auth, organization: organization)).to be_nil
    end

    it "refuses a deactivated partner" do
      create(:agency_user, :inactive, agency: agency, organization: organization,
                                      email: "pat@agency.example")

      expect(described_class.from_omniauth(auth, organization: organization)).to be_nil
    end
  end
end

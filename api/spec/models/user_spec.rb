require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "requires email to be unique per organization (case-insensitive)" do
      org = create(:organization)
      create(:user, organization: org, email: "dup@windmitigation.network")
      dup = build(:user, organization: org, email: "DUP@windmitigation.network")

      expect(dup).not_to be_valid
      expect(dup.errors[:email]).to be_present
    end

    it "allows the same email across different organizations" do
      email = "shared@windmitigation.network"
      create(:user, organization: create(:organization), email: email)
      other = build(:user, organization: create(:organization), email: email)

      expect(other).to be_valid
    end

    it "rejects an unknown role" do
      user = build(:user, role: "wizard")

      expect(user).not_to be_valid
      expect(user.errors[:role]).to be_present
    end
  end

  describe ".from_omniauth" do
    let(:organization) { create(:organization) }
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "google_oauth2", uid: "google-123",
        info: { email: "casey@windmitigation.network", name: "Casey" }
      )
    end

    it "links the identity to a matching provisioned user on first login" do
      user = create(:user, organization: organization, email: "casey@windmitigation.network")

      found = described_class.from_omniauth(auth, organization: organization)

      expect(found).to eq(user)
      expect(found.omniauth_provider).to eq("google_oauth2")
      expect(found.omniauth_uid).to eq("google-123")
    end

    it "finds a returning user by their linked identity" do
      user = create(:user, :with_google_identity, organization: organization,
                                                   omniauth_uid: "google-123")

      expect(described_class.from_omniauth(auth, organization: organization)).to eq(user)
    end

    it "returns nil for an email with no provisioned account" do
      expect(described_class.from_omniauth(auth, organization: organization)).to be_nil
    end

    it "refuses a deactivated user" do
      create(:user, :inactive, organization: organization, email: "casey@windmitigation.network")

      expect(described_class.from_omniauth(auth, organization: organization)).to be_nil
    end
  end
end

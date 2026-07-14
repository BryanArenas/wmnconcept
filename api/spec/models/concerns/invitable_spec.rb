require "rails_helper"

# Behavioral spec for the Invitable concern, exercised through both principals
# that include it (User and AgencyUser).
RSpec.describe Invitable do
  let(:org) { create(:organization) }

  shared_examples "an invitable principal" do
    it "starts pending when unconfirmed" do
      expect(subject.pending_invitation?).to be(true)
      expect(subject.confirmed?).to be(false)
    end

    it "round-trips a valid invitation token" do
      token = subject.generate_token_for(:invitation)
      expect(described_class.from_invitation_token(token)).to eq(subject)
    end

    it "activates and confirms when the password is set" do
      subject.confirm_with_password!("sup3rsecret")

      subject.reload
      expect(subject.confirmed?).to be(true)
      expect(subject.active).to be(true)
      expect(subject.authenticate("sup3rsecret")).to be_truthy
    end

    it "invalidates the token after confirmation (single-use)" do
      token = subject.generate_token_for(:invitation)
      subject.confirm_with_password!("sup3rsecret")

      expect(described_class.from_invitation_token(token)).to be_nil
    end

    it "returns nil for a garbage token" do
      expect(described_class.from_invitation_token("nonsense")).to be_nil
    end
  end

  describe User do
    subject { create(:user, :inspector, organization: org, active: false, confirmed_at: nil) }

    it_behaves_like "an invitable principal"
  end

  describe AgencyUser do
    subject do
      agency = create(:agency, organization: org)
      create(:agency_user, organization: org, agency:, active: false, confirmed_at: nil)
    end

    it_behaves_like "an invitable principal"
  end
end

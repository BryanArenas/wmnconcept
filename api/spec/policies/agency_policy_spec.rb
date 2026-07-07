require "rails_helper"

# The tenancy spine (CLAUDE.md — review hardest). A scoping miss here leaks
# data across agencies/tenants, so these assertions are deliberately explicit.
RSpec.describe AgencyPolicy, type: :policy do
  let(:org) { create(:organization) }
  let(:other_org) { create(:organization) }

  describe "Scope" do
    def resolve_for(principal)
      AgencyPolicy::Scope.new(principal, Agency).resolve
    end

    it "shows staff every agency in their own org, and none from another org" do
      mine = create(:agency, organization: org)
      _theirs = create(:agency, organization: other_org)
      principal = create(:user, :org_admin, organization: org)

      expect(resolve_for(principal)).to contain_exactly(mine)
    end

    it "narrows an agency user to only their own agency" do
      own = create(:agency, organization: org)
      _sibling = create(:agency, organization: org)
      principal = create(:agency_user, agency: own, organization: org)

      expect(resolve_for(principal)).to contain_exactly(own)
    end

    it "never crosses the organization boundary for an agency user" do
      own = create(:agency, organization: org)
      principal = create(:agency_user, agency: own, organization: org)
      # An agency in another org with a colliding id-space still must not appear.
      create(:agency, organization: other_org)

      expect(resolve_for(principal).pluck(:organization_id).uniq).to eq([org.id])
    end
  end

  describe "authorization" do
    let(:agency) { create(:agency, organization: org) }

    it "permits management only for org_admin" do
      expect(described_class.new(create(:user, :org_admin, organization: org), agency).create?).to be(true)
      expect(described_class.new(create(:user, :org_admin, organization: org), Agency).index?).to be(true)
    end

    it "denies management to coordinators, managers, inspectors, and agency users" do
      [
        create(:user, :coordinator, organization: org),
        create(:user, :manager, organization: org),
        create(:user, :inspector, organization: org),
        create(:agency_user, agency: agency, organization: org)
      ].each do |principal|
        policy = described_class.new(principal, agency)
        expect(policy.index?).to be(false), "#{principal.class} should not index agencies"
        expect(policy.create?).to be(false), "#{principal.class} should not create agencies"
      end
    end

    it "lets an agency user see (show) only their own agency" do
      own = create(:agency, organization: org)
      other = create(:agency, organization: org)
      principal = create(:agency_user, agency: own, organization: org)

      expect(described_class.new(principal, own).show?).to be(true)
      expect(described_class.new(principal, other).show?).to be(false)
    end
  end
end

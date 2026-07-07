require "rails_helper"

# Accept-spawns-N is the load-bearing bit of M3 (spec §8.7 / CLAUDE.md — review
# the accept logic hardest). It must snapshot price from config (never guess),
# spawn one inspection per type, and be atomic.
RSpec.describe InspectionRequest, type: :model do
  let(:org) { create(:organization) }

  before do
    create(:inspection_type_config, organization: org,
                                    inspection_type: "wind_mitigation", price_cents: 17_500)
    create(:inspection_type_config, :four_point, organization: org)
  end

  describe "#accept!" do
    it "spawns one unassigned inspection per requested type, snapshotting price" do
      req = create(:inspection_request, :multi_type, organization: org)

      spawned = nil
      expect { spawned = req.accept!(actor: create(:user, :coordinator, organization: org)) }
        .to change(Inspection, :count).by(2)

      expect(req.reload).to be_accepted
      expect(spawned.map(&:inspection_type)).to match_array(%w[wind_mitigation four_point])
      expect(spawned).to all(be_unassigned)

      wind = spawned.find(&:wind_mitigation?)
      expect(wind.price_cents).to eq(17_500)
      expect(wind.agency).to eq(req.agency)
      expect(wind.property).to eq(req.property)
      expect(wind.inspection_events.where(kind: "created")).to be_present
    end

    it "is atomic: a type with no price config aborts the entire accept" do
      # roof_condition is a known type but has no active price config here.
      req = create(:inspection_request, organization: org,
                                        requested_types: %w[wind_mitigation roof_condition])

      expect { req.accept! }.to raise_error(InspectionRequest::MissingPriceError)
      expect(req.reload).to be_submitted
      expect(Inspection.count).to eq(0)
    end

    it "refuses to accept a request that is not submitted" do
      req = create(:inspection_request, :accepted, organization: org)
      expect { req.accept! }.to raise_error(InspectionRequest::InvalidTransition)
    end
  end

  describe "#decline!" do
    it "declines with a stored reason" do
      req = create(:inspection_request, organization: org)
      req.decline!(reason: "Outside service area")

      expect(req.reload).to be_declined
      expect(req.decline_reason).to eq("Outside service area")
    end

    it "requires a reason" do
      req = create(:inspection_request, organization: org)
      expect { req.decline!(reason: "") }.to raise_error(ActiveRecord::RecordInvalid)
      expect(req.reload).to be_submitted
    end
  end

  describe "validations" do
    it "requires at least one requested type" do
      expect(build(:inspection_request, organization: org, requested_types: [])).not_to be_valid
    end

    it "rejects unknown inspection types" do
      expect(build(:inspection_request, organization: org, requested_types: %w[moon_survey]))
        .not_to be_valid
    end
  end
end

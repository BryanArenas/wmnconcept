FactoryBot.define do
  factory :inspection do
    organization
    inspection_request { association(:inspection_request, organization:) }
    # Denormalized from the request; kept in the same tenant.
    agency { inspection_request.agency }
    property { inspection_request.property }
    homeowner { inspection_request.homeowner }
    inspection_type { "wind_mitigation" }
    price_cents { 17_500 }
    # status defaults to :unassigned via AASM.

    # State traits set `status` directly for test setup only — they bypass the §6
    # guards/side effects on purpose. Application code must use the transition
    # methods (assign_to!/schedule_for!/…). The state machine spec drives the
    # real transitions.
    trait :with_inspector do
      assigned_inspector { association(:user, :inspector, organization:) }
    end

    trait :assigned do
      with_inspector
      status { "assigned" }
    end

    trait :scheduled do
      with_inspector
      status { "scheduled" }
      scheduled_at { 3.days.from_now }
    end

    trait :in_progress do
      with_inspector
      status { "in_progress" }
      scheduled_at { 1.day.ago }
      started_at { 2.hours.ago }
    end

    trait :submitted_for_review do
      with_inspector
      status { "submitted_for_review" }
      scheduled_at { 2.days.ago }
      started_at { 2.days.ago }
      submitted_at { 1.day.ago }
    end

    trait :approved do
      submitted_for_review
      status { "approved" }
      approved_at { 1.hour.ago }
    end

    trait :delivered do
      approved
      status { "delivered" }
      delivered_at { 30.minutes.ago }
    end

    trait :reworked do
      in_progress
      rejection_note { "Photos of the roof-to-wall connection were blurry." }
    end

    trait :cancelled do
      status { "cancelled" }
      cancelled_at { 1.hour.ago }
    end
  end
end

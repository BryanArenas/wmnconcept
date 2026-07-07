FactoryBot.define do
  factory :inspection_request do
    organization
    # All associated records share the request's tenant.
    agency { association(:agency, organization:) }
    property { association(:property, organization:) }
    homeowner { association(:homeowner, organization:) }
    submitted_by_agency_user { association(:agency_user, agency:, organization:) }

    requested_types { ["wind_mitigation"] }
    preferred_dates { "Next week, mornings preferred" }
    notes { "Gate code 1234." }
    status { "submitted" }

    trait :multi_type do
      requested_types { %w[wind_mitigation four_point] }
    end

    trait :accepted do
      status { "accepted" }
    end

    trait :declined do
      status { "declined" }
      decline_reason { "Outside service area." }
    end
  end
end

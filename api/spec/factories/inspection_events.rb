FactoryBot.define do
  factory :inspection_event do
    inspection
    organization { inspection.organization }
    kind { "assigned" }
    message { "Assigned to Ivan Inspector" }
    from_status { "unassigned" }
    to_status { "assigned" }
    occurred_at { Time.current }
  end
end

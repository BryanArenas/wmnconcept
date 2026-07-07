FactoryBot.define do
  factory :inspection_photo do
    organization
    inspection
    s3_key { "inspections/#{SecureRandom.uuid}/photos/#{SecureRandom.uuid}.jpg" }
    filename { "photo.jpg" }
    content_type { "image/jpeg" }
    upload_state { "pending" }

    trait :uploaded do
      upload_state { "uploaded" }
    end
  end
end

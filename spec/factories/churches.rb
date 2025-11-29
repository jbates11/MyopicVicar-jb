FactoryBot.define do
  factory :church do
    church_name { "St Mary" }
    place_name  { "Norfolk" }
    location    { "Norfolk" }
    association :place
  end
end

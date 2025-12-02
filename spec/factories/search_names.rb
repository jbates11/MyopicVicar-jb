FactoryBot.define do
  factory :search_name do
    first_name { "Adam" }
    last_name  { "Applebee" }
    role       { "child" }
    gender     { "m" }
    type       { "primary" }
    origin     { "transcript" }

    # Prevent FactoryBot from trying to persist this standalone
    to_create { |instance| instance }
  end
end

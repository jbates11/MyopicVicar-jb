FactoryBot.define do
  factory :userid_detail do
    # userid {"user1"}
    sequence(:userid) { |n| "user#{n}" }
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { 'password1234' }
    password_confirmation { 'password1234' }
    # syndicate { 'Oxfordshire - Eric Booker' }
    syndicate { 'SyndicateA' }
    person_role { 'transcriber' }
    sequence(:person_forename) { |n| "forename#{n}" }
    sequence(:person_surname) { |n| "surname#{n}" }
    # person_forename { 'arron' }
    # person_surname { 'summers' }
    skill_level { 'Unspecified' }
    active { 'true' }
    email_address_last_confirmned { Time.now }
    # email_address_last_confirmned { '2025-09-25 19:28:59' }
    # optional
    email_address_valid { true }
    county_groups { ["DEV"] }
    no_processing_messages { false }
  end
end

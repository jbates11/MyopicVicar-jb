require 'rails_helper'

class First
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  field :name, type: String

  has_many :seconds, dependent: :destroy
  has_many :thirds, dependent: :destroy

  validates_uniqueness_of :name
  validates_presence_of :name

end

class Second
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  field :name, type: String

  belongs_to :first
  has_and_belongs_to_many :thirds
end

class Third
  include Mongoid::Document
  include Mongoid::Timestamps::Short

  field :name, type: String

  validates_presence_of :name
  validates_format_of :name, without: /\/|\\|\&|\?|\s/

  has_and_belongs_to_many :seconds
  belongs_to :first
end

FactoryBot.define do
  factory :first do
    sequence(:name){ |i| "First_name_#{i}" }
  end
end

FactoryBot.define do
  factory :second do
    sequence(:name){ |i| "Second_name_#{i}" }
  end
 end

FactoryBot.define do
  factory :third do
    sequence(:name){ |i| "Third_name_#{i}" }
  end
end

RSpec.describe First, type: :model do
  # Must clean database before running test a second time
  before do
    Mongoid::Clients.default[ 'firsts' ].drop # delete collection
    Mongoid::Clients.default[ 'seconds' ].drop # delete collection
    Mongoid::Clients.default[ 'thirds' ].drop # delete collection
  end

  after do
    Mongoid::Clients.default[ 'firsts' ].delete_many # delete all records
    Mongoid::Clients.default[ 'seconds' ].delete_many # delete all records
    Mongoid::Clients.default[ 'thirds' ].delete_many # delete all records
  end

  let(:first) { create(:first) }
  let(:second_1) { create(:second, first: first) }
  let(:second_2) { create(:second, first: first) }
  let(:thirds_1000) { create_list(:third, 1000, first: first, seconds: [second_1, second_2]) }

  it 'checks 1000 thirds insertion' do
    start_time = Time.now.utc
    thirds_1000
    puts "[#{Mongoid::VERSION}]: #{Time.now.utc - start_time} seconds"
  end

end

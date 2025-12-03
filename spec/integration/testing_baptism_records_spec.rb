require 'rails_helper'
require Rails.root.join('lib/freereg1_translator')

describe 'Baptism SearchName population' do
  let(:place) { create(:place, place_name: 'Guildford', chapman_code: 'ESS') }
  let(:church) { create(:church, place: place) }
  let(:register) { create(:register, church: church, register_type: 'Baptism') }
  let(:file) { create(:freereg1_csv_file, :baptism_file, register: register) }
  let(:entry) { create(:freereg1_csv_entry, :baptism_with_witnesses, freereg1_csv_file: file) }

  it 'creates complete SearchRecord with all names' do
    search_params = Freereg1Translator.translate(file, entry)
    record = build(:search_record, :baptism_with_witnesses, freereg1_csv_entry: entry, place: place)
    record.transform

    record.save! # must make record persistent for count method to work

    # ap record.search_names
    # puts "Count: #{record.search_names.count}"

    expect(record.search_names.count).to be >= 5
    expect(record.search_names.map(&:role)).to include('ba', 'f', 'm', 'wt')
  end
end

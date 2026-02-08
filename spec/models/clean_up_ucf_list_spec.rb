require 'rails_helper'

RSpec.describe Freereg1CsvEntry, type: :model do
  describe '#clean_up_ucf_list' do
    let(:file_ucf_list) { [] }
    let(:place_ucf_list) { {} }
    let(:proceed) { true }

    let(:place) { create(:place, ucf_list: place_ucf_list) }
    let(:file)  { create(:freereg1_csv_file, ucf_list: file_ucf_list) }
    let(:entry) { create(:freereg1_csv_entry, freereg1_csv_file: file, search_record: search_record) }
    let(:search_record) { create(:search_record) }

    let(:file_key) { file.id.to_s }
    let(:search_record_id) { search_record.id.to_s }

    before do
      # Stub location_from_file → [proceed, place, church, register]
      allow(file).to receive(:location_from_file).and_return([proceed, place, nil, nil])
    end

    # --------------------------------------------------------------------
    # EARLY RETURNS
    # --------------------------------------------------------------------

    context 'when file is missing' do
      let(:entry) { create(:freereg1_csv_entry, freereg1_csv_file: nil) }

      it 'returns early and performs no updates' do
        expect(Freereg1CsvFile).not_to receive(:where)
        entry.clean_up_ucf_list
      end
    end

    context 'when search_record is missing' do
      let(:entry) { create(:freereg1_csv_entry, freereg1_csv_file: file, search_record: nil) }

      it 'returns early and performs no updates' do
        expect(Freereg1CsvFile).not_to receive(:where)
        entry.clean_up_ucf_list
      end
    end

    # --------------------------------------------------------------------
    # FILE-LEVEL CLEANUP
    # --------------------------------------------------------------------

    context 'file-level cleanup' do
      let(:proceed) { false }
      let(:place_ucf_list) { {} }
      let(:file_ucf_list) { [search_record_id, 'other-id'] }

      it 'removes the search_record ID from file.ucf_list atomically' do
        entry.clean_up_ucf_list

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_list).to eq(['other-id'])
      end

      it 'sets ucf_updated to today' do
        entry.clean_up_ucf_list

        fresh_file = Freereg1CsvFile.find(file.id)
        expect(fresh_file.ucf_updated).to eq(Time.zone.today)
      end
    end

    # --------------------------------------------------------------------
    # PLACE-LEVEL CLEANUP
    # --------------------------------------------------------------------

    context 'place-level cleanup' do
      let(:proceed) { true }

      let(:file_ucf_list) { [] }
      let(:place_ucf_list) do
        { file_key => [search_record_id, 'other-id'] }
      end

      it 'removes the search_record ID from place.ucf_list[file_key]' do
        entry.clean_up_ucf_list

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list[file_key]).to eq(['other-id'])
      end
    end

    context 'when place.ucf_list does not contain the file key' do
      let(:proceed) { true }
      let(:file_ucf_list) { [] }
      let(:place_ucf_list) { {} }

      it 'does nothing and does not raise errors' do
        expect { entry.clean_up_ucf_list }.not_to raise_error

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list).to eq({})
      end
    end

    context 'when proceed is false' do
      let(:proceed) { false }
      let(:file_ucf_list) { [] }
      let(:place_ucf_list) do
        { file_key => [search_record_id] }
      end

      it 'skips place-level cleanup' do
        entry.clean_up_ucf_list

        fresh_place = Place.find(place.id)
        expect(fresh_place.ucf_list[file_key]).to eq([search_record_id])
      end
    end
  end
end

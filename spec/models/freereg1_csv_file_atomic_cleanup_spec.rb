require "rails_helper"

RSpec.describe Freereg1CsvFile, type: :model do
  describe '#clean_up_place_ucf_list_atomic' do
    let(:place) { FactoryBot.create(:place, data_present: true) }
    let(:church) { FactoryBot.create(:church, place: place) }
    let(:register) { FactoryBot.create(:register, church: church) }
    let(:file) { FactoryBot.create(:freereg1_csv_file, register: register) }

    before do
      # Initialize place with ucf_list containing this file
      place.update(
        ucf_list: { file.id.to_s => %w[rec1 rec2 rec3] },
        ucf_list_file_count: 1,
        ucf_list_record_count: 3
      )
      place.reload  # ensures fresh_place sees the correct data
    end

    it 'atomically removes file from place ucf_list' do
      expect(place.ucf_list.key?(file.id.to_s)).to be true
      
      file.clean_up_place_ucf_list_atomic
      place.reload
      
      expect(place.ucf_list.key?(file.id.to_s)).to be false
    end

    it 'decrements file count by exactly 1' do
      expect(place.ucf_list_file_count).to eq 1
      
      file.clean_up_place_ucf_list_atomic
      place.reload
      
      expect(place.ucf_list_file_count).to eq 0
    end

    it 'decrements record count by the correct amount' do
      expect(place.ucf_list_record_count).to eq 3
      
      file.clean_up_place_ucf_list_atomic
      place.reload
      
      expect(place.ucf_list_record_count).to eq 0
    end

    it 'is idempotent (calling twice causes no error)' do
      file.clean_up_place_ucf_list_atomic
      expect { file.clean_up_place_ucf_list_atomic }.not_to raise_error
      
      place.reload
      expect(place.ucf_list_file_count).to eq 0
      expect(place.ucf_list_record_count).to eq 0
    end

    it 'clears the file own ucf_list' do
      file.update(ucf_list: %w[rec1 rec2])
      file.clean_up_place_ucf_list_atomic
      file.reload
      
      expect(file.ucf_list).to be_empty
    end

    it 'logs the cleanup success' do
      allow(Rails.logger).to receive(:info)
      
      file.clean_up_place_ucf_list_atomic
      
      expect(Rails.logger).to have_received(:info).with(
        include("Atomic cleanup complete")
      )
    end

    it 'raises and logs errors' do
      allow(Place).to receive(:where).and_raise(StandardError.new("DB error"))
      allow(Rails.logger).to receive(:error)

      expect { file.clean_up_place_ucf_list_atomic }.to raise_error(StandardError)
      expect(Rails.logger).to have_received(:error).with(include("Atomic cleanup failed"))
    end
    
    it 'returns early if file not persisted' do
      new_file = build(:freereg1_csv_file, register: register)
      expect(Place.collection).not_to receive(:update_one)
      
      new_file.clean_up_place_ucf_list_atomic
    end
  end
end

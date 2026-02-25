require "rails_helper"

RSpec.describe Place, type: :model do
  describe '#apply_ucf_batch_changes' do
    let(:place) { FactoryBot.create(:place, ucf_list: {}) }
    let(:file_id_str) { "file_123" }
    let(:sr_id_1) { BSON::ObjectId.new }
    let(:sr_id_2) { BSON::ObjectId.new }
    let(:sr_id_3) { BSON::ObjectId.new }

    context 'when adding records to empty list' do
      let(:changes) { { add: Set.new([sr_id_1, sr_id_2]), remove: Set.new } }

      it 'adds records to ucf_list[file_id]' do
        place.apply_ucf_batch_changes(file_id_str, changes)
        place.reload

        expect(place.ucf_list[file_id_str]).to include(sr_id_1, sr_id_2)
      end

      it 'increments file_count' do
        place.apply_ucf_batch_changes(file_id_str, changes)
        place.reload

        expect(place.ucf_list_file_count).to eq(1)
      end
    end

    context 'when removing records' do
      before do
        place.update(
          ucf_list: { file_id_str => [sr_id_1, sr_id_2, sr_id_3] },
          ucf_list_file_count: 1,
          ucf_list_record_count: 3
        )
      end

      let(:changes) { { add: Set.new, remove: Set.new([sr_id_2]) } }

      it 'removes specified records' do
        place.apply_ucf_batch_changes(file_id_str, changes)
        place.reload

        expect(place.ucf_list[file_id_str]).to include(sr_id_1, sr_id_3)
        expect(place.ucf_list[file_id_str]).not_to include(sr_id_2)
      end

      it 'updates record count correctly' do
        place.apply_ucf_batch_changes(file_id_str, changes)
        place.reload

        expect(place.ucf_list_record_count).to eq(2)
      end
    end

    context 'when no changes provided' do
      let(:changes) { { add: Set.new, remove: Set.new } }

      it 'does not update Place' do
        expect(Place.collection).not_to receive(:update_one)
        place.apply_ucf_batch_changes(file_id_str, changes)
      end
    end

    context 'when error occurs during atomic update' do
      let(:changes) { { add: Set.new([sr_id_1]), remove: Set.new } }
      
      # 1. Use let! to ensure the record is saved to the DB normally first
      let!(:place) { FactoryBot.create(:place, ucf_list: {}) }

      before do
        # 2. Grab the REAL collection object
        real_collection = Place.collection
        
        # 3. Stub the class method to return that real collection
        allow(Place).to receive(:collection).and_return(real_collection)
        
        # 4. Partial double: Only hijack the update_one method on the real object
        allow(real_collection).to receive(:update_one).and_raise(StandardError.new("DB error"))
      end

      it 'logs error and raises' do
        expect(Rails.logger).to receive(:error).with(include("Batch update failed"))
        expect { place.apply_ucf_batch_changes(file_id_str, changes) }.to raise_error(StandardError, "DB error")
      end
    end

  end
end

require 'rails_helper'

RSpec.describe Place, type: :model do
  describe '.extract_ucf_records' do
    let(:logger) { Rails.logger }

    before do
      allow(logger).to receive(:info)
    end

    context 'logging' do
      it 'logs the operation with the given place_ids' do
        place = create(:place)
        place_ids = [place.id]

        described_class.extract_ucf_records(place_ids)

        expect(logger).to have_received(:info).with(
          "UCF: Operation | action: extract_ucf_records | place_ids: #{place_ids}"
        )
      end
    end

    context 'when place_ids is blank' do
      it 'returns an empty array for nil' do
        result = described_class.extract_ucf_records(nil)

        expect(result).to eq([])
      end

      it 'returns an empty array for an empty array' do
        result = described_class.extract_ucf_records([])

        expect(result).to eq([])
      end
    end

    context 'when place_ids are provided' do
      context 'and no matching places exist' do
        it 'returns an empty array' do
          unknown_id = BSON::ObjectId.new

          result = described_class.extract_ucf_records([unknown_id])

          expect(result).to eq([])
        end
      end

      context 'and matching places exist' do
        context 'when ucf_list is blank' do
          it 'skips places with blank ucf_list' do
            place = create(:place, ucf_list: {})
            place_ids = [place.id]

            result = described_class.extract_ucf_records(place_ids)

            expect(result).to eq([])
          end
        end

        context 'when ucf_list contains record IDs grouped by keys' do
          it 'returns all record IDs from a single place, flattened' do
            place = create(:place)
            group_1_ids = [BSON::ObjectId.new, BSON::ObjectId.new]
            group_2_ids = [BSON::ObjectId.new]
            place.update_attributes!(
              ucf_list: {
                SecureRandom.hex(12) => group_1_ids,
                SecureRandom.hex(12) => group_2_ids
              }
            )

            fresh_place = Place.find(place.id)
            place_ids = [fresh_place.id]

            result = described_class.extract_ucf_records(place_ids)

            expect(result).to match_array(group_1_ids + group_2_ids)
            expect(result).to all(be_a(BSON::ObjectId))
          end

          it 'returns all record IDs from multiple places, flattened' do
            place_1 = create(:place)
            place_2 = create(:place)

            place_1_group_ids = [BSON::ObjectId.new, BSON::ObjectId.new]
            place_2_group_ids = [BSON::ObjectId.new]

            place_1.update_attributes!(
              ucf_list: { SecureRandom.hex(12) => place_1_group_ids }
            )
            place_2.update_attributes!(
              ucf_list: { SecureRandom.hex(12) => place_2_group_ids }
            )

            fresh_place_1 = Place.find(place_1.id)
            fresh_place_2 = Place.find(place_2.id)

            place_ids = [fresh_place_1.id, fresh_place_2.id]

            result = described_class.extract_ucf_records(place_ids)

            expect(result).to match_array(
              place_1_group_ids + place_2_group_ids
            )
          end

          it 'ignores nil or empty record groups inside ucf_list' do
            place = create(:place)
            valid_ids = [BSON::ObjectId.new, BSON::ObjectId.new]

            place.update_attributes!(
              ucf_list: {
                SecureRandom.hex(12) => valid_ids,
                SecureRandom.hex(12) => nil,
                SecureRandom.hex(12) => []
              }
            )

            fresh_place = Place.find(place.id)
            place_ids = [fresh_place.id]

            result = described_class.extract_ucf_records(place_ids)

            expect(result).to match_array(valid_ids)
          end
        end
      end
    end
  end
end

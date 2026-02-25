require 'rails_helper'

RSpec.describe Place, type: :model do
  describe "atomic counter updates" do
    let(:place) { create(:place) }
    let(:file_id) { "file_123" }
    let(:record_id_1) { "record_001" }
    let(:record_id_2) { "record_002" }

    describe "#add_ucf_record" do
      context "adding first record to a file" do
        it "adds record and increments both counters" do
          expect {
            place.add_ucf_record(file_id, record_id_1)
          }.to change { place.ucf_list_record_count }.by(1)
           .and change { place.ucf_list_file_count }.by(1)
        end

        it "stores the record in the correct file's array" do
          place.add_ucf_record(file_id, record_id_1)
          expect(place.ucf_list[file_id]).to include(record_id_1)
        end
      end

      context "adding subsequent records to same file" do
        before { place.add_ucf_record(file_id, record_id_1) }

        it "increments record count but not file count" do
          expect {
            place.add_ucf_record(file_id, record_id_2)
          }.to change { Place.find(place.id).ucf_list_record_count }.by(1)
          .and change { Place.find(place.id).ucf_list_file_count }.by(0)
        end
      end

      context "adding duplicate record" do
        before { place.add_ucf_record(file_id, record_id_1) }

        it "does not increment counters" do
          expect {
            place.add_ucf_record(file_id, record_id_1)
          }.to change { Place.find(place.id).ucf_list_record_count }.by(0)
          .and change { Place.find(place.id).ucf_list_file_count }.by(0)
        end
      end
    end

    describe "#remove_ucf_record" do
      context "removing a record that exists" do
        before do
          place.add_ucf_record(file_id, record_id_1)
          place.add_ucf_record(file_id, record_id_2)
        end

        it "decrements record count but not file count" do
          expect {
            place.remove_ucf_record(file_id, record_id_1)
          }.to change { Place.find(place.id).ucf_list_record_count }.by(-1)
          .and change { Place.find(place.id).ucf_list_file_count }.by(0)
        end

        it "removes the record from the array" do
          place.remove_ucf_record(file_id, record_id_1)
          expect(place.ucf_list[file_id]).not_to include(record_id_1)
        end
      end

      context "removing the last record from a file" do
        before { place.add_ucf_record(file_id, record_id_1) }

        it "decrements both counters" do
          expect {
            place.remove_ucf_record(file_id, record_id_1)
          }.to change { place.ucf_list_record_count }.by(-1)
           .and change { place.ucf_list_file_count }.by(-1)
        end

        it "deletes the file key from ucf_list" do
          place.remove_ucf_record(file_id, record_id_1)
          expect(place.ucf_list).not_to have_key(file_id)
        end
      end

      context "removing a record that doesn't exist" do
        it "does not decrement any counters" do
          expect {
            place.remove_ucf_record(file_id, record_id_1)
          }.to change { Place.find(place.id).ucf_list_record_count }.by(0)
          .and change { Place.find(place.id).ucf_list_file_count }.by(0)
      end
      end
    end

    describe "atomic counter consistency" do
      it "maintains correct record count across multiple adds/removes" do
        # Add 5 records
        5.times { |i| place.add_ucf_record(file_id, "record_#{i}") }
        expect(place.ucf_list_record_count).to eq(5)
        expect(place.ucf_list_file_count).to eq(1)

        # Remove 3 records
        3.times { |i| place.remove_ucf_record(file_id, "record_#{i}") }
        expect(place.ucf_list_record_count).to eq(2)
        expect(place.ucf_list_file_count).to eq(1)

        # Remove last 2 records (should delete file too)
        place.remove_ucf_record(file_id, "record_3")
        place.remove_ucf_record(file_id, "record_4")
        expect(place.ucf_list_record_count).to eq(0)
        expect(place.ucf_list_file_count).to eq(0)
      end

      it "matches manual calculations after operations" do
        file_id_2 = "file_456"

        place.add_ucf_record(file_id, "r1")
        place.add_ucf_record(file_id, "r2")
        place.add_ucf_record(file_id_2, "r3")

        # Manual calculation
        expected_records = place.ucf_list.values.flatten.size
        expected_files   = place.ucf_list.keys.size

        expect(place.ucf_list_record_count).to eq(expected_records)
        expect(place.ucf_list_file_count).to eq(expected_files)
      end
    end
  end
end

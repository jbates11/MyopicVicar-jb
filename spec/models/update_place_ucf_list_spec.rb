require "rails_helper"

RSpec.describe Freereg1CsvEntry, type: :model do
  let(:entry) { create(:freereg1_csv_entry) }

  let(:place) { create(:place, ucf_list: initial_place_ucf) }
  let(:file)  { create(:freereg1_csv_file, ucf_list: initial_file_ucf) }

  let(:initial_place_ucf) { {} }
  let(:initial_file_ucf)  { [] }

  let(:search_record) { create(:search_record, id: "SR1") }
  let(:old_search_record) { nil }

  before do
    # The model expects `search_record` to be available as a method
    allow(entry).to receive(:search_record).and_return(search_record)
    allow(search_record).to receive(:contains_wildcard_ucf?).and_return(search_record_has_ucf)
  end

  describe "#update_place_ucf_list" do

    # -------------------------------------------------------------------------
    # CASE C — NEW UCF LIST
    # -------------------------------------------------------------------------
    context "Case C — new UCF list (file not in place, search_record has UCF)" do
      let(:search_record_has_ucf) { true }

      it "creates a new UCF list for the file and updates both models" do
        entry.update_place_ucf_list(place, file, old_search_record)

        expect(place.ucf_list[file.id.to_s]).to eq(["SR1"])
        expect(file.ucf_list).to eq(["SR1"])
      end
    end

    # -------------------------------------------------------------------------
    # CASE A — ADD UCF
    # -------------------------------------------------------------------------
    context "Case A — add UCF (file already in place, search_record has UCF)" do
      let(:search_record_has_ucf) { true }
      let(:initial_place_ucf) { { file.id.to_s => [] } }

      it "adds the search_record ID to both lists" do
        entry.update_place_ucf_list(place, file, old_search_record)

        expect(place.ucf_list[file.id.to_s]).to eq(["SR1"])
        expect(file.ucf_list).to eq(["SR1"])
      end
    end

    # -------------------------------------------------------------------------
    # CASE B — REMOVE UCF
    # -------------------------------------------------------------------------
    context "Case B — remove UCF (file in place, search_record has no UCF)" do
      let(:search_record_has_ucf) { false }
      let(:initial_place_ucf) { { file.id.to_s => ["SR1"] } }
      let(:initial_file_ucf)  { ["SR1"] }

      it "removes the search_record ID from both lists" do
        entry.update_place_ucf_list(place, file, old_search_record)

        expect(place.ucf_list[file.id.to_s]).to eq([])
        expect(file.ucf_list).to eq([])
      end
    end

    # -------------------------------------------------------------------------
    # CASE 0 — NO CHANGE
    # -------------------------------------------------------------------------
    context "Case 0 — no change (file not in place AND search_record has no UCF)" do
      let(:search_record_has_ucf) { false }

      it "does nothing" do
        expect {
          entry.update_place_ucf_list(place, file, old_search_record)
        }.not_to change { [place.ucf_list, file.ucf_list] }
      end
    end

    # -------------------------------------------------------------------------
    # FAILURE INJECTION — FILE SAVE FAILURE
    # -------------------------------------------------------------------------
    context "Rollback behavior when file.save! fails" do
      let(:search_record_has_ucf) { true }

      before do
        allow(file).to receive(:save!).and_raise(Mongoid::Errors::Validations.new(file))
      end

      it "restores original state for both place and file" do
        before_state = [place.ucf_list.deep_dup, file.ucf_list.deep_dup]

        begin
          entry.update_place_ucf_list(place, file, old_search_record)
        rescue
          # swallow error for test
        end

        after_state = [(place.class.find(place.id)).ucf_list, (file.class.find(file.id)).ucf_list]

        expect(after_state).to eq(before_state)
      end
    end

    # -------------------------------------------------------------------------
    # FAILURE INJECTION — PLACE SAVE FAILURE
    # -------------------------------------------------------------------------
    context "Rollback behavior when place.save! fails" do
      let(:search_record_has_ucf) { true }

      before do
        allow(place).to receive(:save!).and_raise(Mongoid::Errors::Validations.new(place))
      end

      it "restores original state for both place and file" do
        before_state = [place.ucf_list.deep_dup, file.ucf_list.deep_dup]

        begin
          entry.update_place_ucf_list(place, file, old_search_record)
        rescue
          # swallow error
        end

        after_state = [(place.class.find(place.id)).ucf_list, (file.class.find(file.id)).ucf_list]

        expect(after_state).to eq(before_state)
      end
    end
  end
end

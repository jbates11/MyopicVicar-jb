require "rails_helper"

RSpec.describe SearchQuery, type: :model do
  describe "#search_ucf" do
    let(:search_query) { create(:search_query) }
    let(:search_result) { search_query.search_result }  # embedded, never created standalone

    # ------------------------------------------------------------------
    # Mongoid-safe fresh reads (no reload)
    # ------------------------------------------------------------------
    def fresh_query
      SearchQuery.find(search_query.id)
    end

    def fresh_result
      SearchQuery.find(search_query.id).search_result
    end

    # ------------------------------------------------------------------
    # Guard Clause Tests
    # ------------------------------------------------------------------
    context "when place_ids is missing" do
      before { allow(search_query).to receive(:place_ids).and_return(nil) }

      it "returns false and does not raise" do
        expect(search_query.search_ucf).to eq(false)

        q = fresh_query
        expect(q.ucf_filtered_count).to be_nil
        expect(q.runtime_ucf).to be_nil
      end
    end

    context "when search_result is missing" do
      before { search_query.update(search_result: nil) }

      it "returns false and does not attempt processing" do
        expect(search_query.search_ucf).to eq(false)

        q = fresh_query
        expect(q.ucf_filtered_count).to be_nil
      end
    end

    # ------------------------------------------------------------------
    # Successful Pipeline
    # ------------------------------------------------------------------
    context "when all dependencies are present" do
      let(:place_ids) { [BSON::ObjectId.new, BSON::ObjectId.new] }

      before do
        allow(search_query).to receive(:place_ids).and_return(place_ids)

        allow(Place).to receive(:extract_ucf_records)
          .with(place_ids)
          .and_return([
            double(id: BSON::ObjectId.new),
            double(id: BSON::ObjectId.new)
          ])

        allow(search_query).to receive(:filter_ucf_records)
          .and_return([double(id: BSON::ObjectId.new)])
      end

      it "stores filtered IDs on search_result" do
        search_query.search_ucf

        result = fresh_result
        expect(result.ucf_records).to be_present
        expect(result.ucf_records.size).to eq(1)
      end

      it "updates ucf_filtered_count" do
        search_query.search_ucf

        q = fresh_query
        expect(q.ucf_filtered_count).to eq(1)
      end

      it "sets runtime_ucf to a numeric value" do
        search_query.search_ucf

        q = fresh_query

        expect(q.runtime_ucf).to be_a(Numeric)
        expect(q.runtime_ucf).to be >= 0
      end

      it "returns true on success" do
        expect(search_query.search_ucf).to eq(true)
      end
    end

    # ------------------------------------------------------------------
    # Error Handling
    # ------------------------------------------------------------------
    context "when extract_ucf_records raises an error" do
      before do
        allow(search_query).to receive(:place_ids).and_return([BSON::ObjectId.new])
        allow(Place).to receive(:extract_ucf_records).and_raise(StandardError.new("boom"))
        allow(search_query).to receive(:filter_ucf_records).and_return([])
      end

      it "rescues and continues with empty records" do
        expect { search_query.search_ucf }.not_to raise_error

        q = fresh_query
        expect(q.ucf_filtered_count).to eq(0)
      end
    end

    context "when filter_ucf_records raises an error" do
      before do
        allow(search_query).to receive(:place_ids).and_return([BSON::ObjectId.new])
        allow(Place).to receive(:extract_ucf_records).and_return([double(id: BSON::ObjectId.new)])
        allow(search_query).to receive(:filter_ucf_records).and_raise(StandardError.new("bad filter"))
      end

      it "rescues and treats filtered list as empty" do
        expect { search_query.search_ucf }.not_to raise_error

        q = fresh_query
        expect(q.ucf_filtered_count).to eq(0)
      end
    end

    # ------------------------------------------------------------------
    # Save Failure
    # ------------------------------------------------------------------
    context "when save fails" do
      before do
        allow(search_query).to receive(:place_ids).and_return([BSON::ObjectId.new])
        allow(Place).to receive(:extract_ucf_records).and_return([])
        allow(search_query).to receive(:filter_ucf_records).and_return([])
        allow(search_query).to receive(:save).and_return(false)
      end

      it "returns false" do
        expect(search_query.search_ucf).to eq(false)
      end
    end
  end
end

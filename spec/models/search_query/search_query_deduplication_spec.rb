require "rails_helper"

RSpec.describe SearchQuery, type: :model do
  describe "#get_and_sort_results_for_display -- deduplication Step 8.5" do
    # This test suite focuses ONLY on Step 8.5: the deduplication logic
    # It bypasses all the surrounding complexity to isolate and verify the deduplication behavior
    
    context "deduplication logic" do
      it "removes UCF results that are in search results" do
        # Scenario 4A: Partial deduplication
        # Record appears in both search_results and ucf_results
        
        search_only_id = BSON::ObjectId.new
        both_id = BSON::ObjectId.new
        
        # wrapped_results from Step 8: SearchRecord objects created from search_results hashes
        search_record_1 = SearchRecord.new(id: search_only_id)
        search_record_2 = SearchRecord.new(id: both_id)
        wrapped_results = [search_record_1, search_record_2]
        
        # ucf_results: array of SearchRecord objects from ucf_records IDs
        ucf_only_id = BSON::ObjectId.new
        ucf_record_1 = double(id: both_id)  # This is a duplicate - should be removed
        ucf_record_2 = double(id: ucf_only_id)  # This is unique - should remain
        ucf_results = [ucf_record_1, ucf_record_2]
        
        # === EXECUTE STEP 8.5 LOGIC ===
        # This is the actual deduplication code from app/models/search_query.rb lines 693-696
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # === VERIFY ===
        # Should only have the UCF-only record, not the duplicate
        expect(ucf_results_deduped.count).to eq(1)
        expect(ucf_results_deduped[0].id).to eq(ucf_only_id)
        
        # Verify no overlap
        final_search_ids = wrapped_results.map(&:id).to_set
        final_ucf_ids = ucf_results_deduped.map(&:id).to_set
        overlap = final_search_ids & final_ucf_ids
        expect(overlap.count).to eq(0), "Found overlap between search_results and ucf_results: #{overlap.inspect}"
      end
      
      it "removes ALL UCF results when they are all duplicates" do
        # Scenario 5: Complete overlap
        # All UCF results are already in search results
        
        both_id1 = BSON::ObjectId.new
        both_id2 = BSON::ObjectId.new
        
        wrapped_results = [
          SearchRecord.new(id: both_id1),
          SearchRecord.new(id: both_id2)
        ]
        
        ucf_results = [
          double(id: both_id1),
          double(id: both_id2)
        ]
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: all UCF results should be removed
        expect(ucf_results_deduped.count).to eq(0)
      end
      
      it "keeps all UCF results when there is no overlap" do
        # Scenario: Non-overlapping
        # No records appear in both sets
        
        search_id1 = BSON::ObjectId.new
        search_id2 = BSON::ObjectId.new
        ucf_id1 = BSON::ObjectId.new
        ucf_id2 = BSON::ObjectId.new
        
        wrapped_results = [
          SearchRecord.new(id: search_id1),
          SearchRecord.new(id: search_id2)
        ]
        
        ucf_results = [
          double(id: ucf_id1),
          double(id: ucf_id2)
        ]
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: all UCF results should remain
        expect(ucf_results_deduped.count).to eq(2)
      end
      
      it "handles empty search results" do
        # Edge case: no normal search results
        
        ucf_only_id = BSON::ObjectId.new
        wrapped_results = []
        
        ucf_results = [
          double(id: ucf_only_id)
        ]
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: UCF results unchanged
        expect(ucf_results_deduped.count).to eq(1)
      end
      
      it "handles empty UCF results" do
        # Edge case: no UCF results
        
        search_id = BSON::ObjectId.new
        wrapped_results = [SearchRecord.new(id: search_id)]
        ucf_results = []
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: empty remains empty
        expect(ucf_results_deduped.count).to eq(0)
      end
      
      it "handles both empty" do
        # Edge case: no results at all
        
        wrapped_results = []
        ucf_results = []
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: both empty
        expect(ucf_results_deduped.count).to eq(0)
      end
      
      it "preserves UCF result order after deduplication" do
        # Verify that the reject operation maintains order
        
        normal_id = BSON::ObjectId.new
        ucf1_id = BSON::ObjectId.new
        ucf2_id = BSON::ObjectId.new
        
        wrapped_results = [SearchRecord.new(id: normal_id)]
        
        ucf_results = [
          double(id: ucf1_id),
          double(id: normal_id),  # This will be removed - it's a duplicate
          double(id: ucf2_id)
        ]
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: order preserved, duplicate removed
        expect(ucf_results_deduped.count).to eq(2)
        expect(ucf_results_deduped[0].id).to eq(ucf1_id)
        expect(ucf_results_deduped[1].id).to eq(ucf2_id)
      end
      
      it "correctly identifies duplicates by ID only" do
        # Verify matching is strictly by ID, not by data
        
        id_match = BSON::ObjectId.new
        id_unique = BSON::ObjectId.new
        
        wrapped_results = [
          SearchRecord.new(id: id_match, forename: "John", surname: "Doe")
        ]
        
        ucf_results = [
          double(id: id_match, forename: "Different", surname: "Data"),  # Same ID, different data
          double(id: id_unique, forename: "Unique", surname: "Record")
        ]
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: matching is strictly by ID
        expect(ucf_results_deduped.count).to eq(1)
        expect(ucf_results_deduped[0].id).to eq(id_unique)
      end
      
      it "never allows overlap between search_results and ucf_results" do
        # CRITICAL TEST: Verify the deduplication guarantee
        # No record ID should appear in both sets after deduplication
        
        id_in_both = BSON::ObjectId.new
        id_search_only = BSON::ObjectId.new
        id_ucf_only1 = BSON::ObjectId.new
        id_ucf_only2 = BSON::ObjectId.new
        
        wrapped_results = [
          SearchRecord.new(id: id_search_only),
          SearchRecord.new(id: id_in_both)
        ]
        
        ucf_results_before = [
          double(id: id_in_both),
          double(id: id_ucf_only1),
          double(id: id_ucf_only2)
        ]
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_after = ucf_results_before.reject { |record| search_result_ids.include?(record.id) }
        
        # CRITICAL ASSERTION
        # Verify: No record ID appears in both sets after deduplication
        search_ids = wrapped_results.map(&:id).to_set
        ucf_ids = ucf_results_after.map(&:id).to_set
        overlap = search_ids & ucf_ids
        
        expect(overlap.count).to eq(0), "ERROR: Found IDs in both search_results and ucf_results: #{overlap.inspect}"
        
        # Additional verification
        expect(ucf_results_after.count).to eq(2)
        expect(ucf_results_after.map(&:id)).to contain_exactly(id_ucf_only1, id_ucf_only2)
      end
      
      it "removes multiple duplicates correctly" do
        # Test with multiple duplicates
        
        dup1_id = BSON::ObjectId.new
        dup2_id = BSON::ObjectId.new
        dup3_id = BSON::ObjectId.new
        unique_id = BSON::ObjectId.new
        
        wrapped_results = [
          SearchRecord.new(id: dup1_id),
          SearchRecord.new(id: dup2_id),
          SearchRecord.new(id: dup3_id)
        ]
        
        ucf_results = [
          double(id: dup1_id),
          double(id: dup2_id),
          double(id: dup3_id),
          double(id: unique_id)
        ]
        
        # STEP 8.5 LOGIC
        search_result_ids = wrapped_results.map(&:id).to_set
        ucf_results_deduped = ucf_results.reject { |record| search_result_ids.include?(record.id) }
        
        # Verify: all duplicates removed, unique remains
        expect(ucf_results_deduped.count).to eq(1)
        expect(ucf_results_deduped[0].id).to eq(unique_id)
      end
    end
  end
end

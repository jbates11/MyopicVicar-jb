require "rails_helper"
require "fileutils"

RSpec.describe FreeregCsvUpdateTaskRunner, type: :service do
  isolate_tmp_per_example

  let(:service) { FreeregCsvUpdateTaskRunner.new }

  # ---------------------------------------------------------
  # REAL METHOD OVERRIDES FOR PROCESSOR
  # ---------------------------------------------------------

  before do
    class NewFreeregCsvUpdateProcessor
      class << self
        attr_accessor :activated, :processed, :lock_checked, :lock_status, :lock_created
      end

      def self.activate_project(*args)
        self.activated = args
      end

      def self.process_activate_project(*args)
        self.processed = args
      end

      def self.check_file_lock_status
        self.lock_checked = true
        self.lock_status
      end

      def self.create_rake_lock_file
        self.lock_created = true
        FileUtils.touch(Rails.root.join("tmp", "processing_rake_lock_file.txt"))
      end
    end
  end

  # ---------------------------------------------------------
  # 1. INDIVIDUAL PROCESSING
  # ---------------------------------------------------------
  context "when type is individual" do
    it "executes activate_project and returns success" do
      result = service.run_rake_equivalent(
        search_record: "create_search_records",
        type: "individual",
        force: "no",
        range: "USER001/test.csv"
      )

      expect(result.was_executed).to eq(true)
      expect(NewFreeregCsvUpdateProcessor.activated).to eq(
        ["create_search_records", "individual", "no", "USER001/test.csv"]
      )
    end
  end

  # ---------------------------------------------------------
  # 2. EXISTING LOCK FILE — LOCKED
  # ---------------------------------------------------------
  context "when lock file exists and lock is active" do
    before do
      FileUtils.touch(@processing_lock)

      class NewFreeregCsvUpdateProcessor
        self.lock_status = true
      end
    end

    it "continues processing" do
      result = service.run_rake_equivalent(
        search_record: "create_search_records",
        type: "range",
        force: "no",
        range: "USER001/test.csv"
      )

      expect(result.was_executed).to eq(true)
      expect(NewFreeregCsvUpdateProcessor.processed).to eq(
        ["create_search_records", "range", "no", "USER001/test.csv"]
      )
    end
  end

  # ---------------------------------------------------------
  # 3. EXISTING LOCK FILE — NOT LOCKED
  # ---------------------------------------------------------
  context "when lock file exists but lock is NOT active" do
    before do
      FileUtils.touch(@processing_lock)

      class NewFreeregCsvUpdateProcessor
        self.lock_status = nil
      end
    end

    it "exits without processing" do
      result = service.run_rake_equivalent(
        search_record: "create_search_records",
        type: "range",
        force: "no",
        range: "USER001/test.csv"
      )

      expect(result.was_executed).to eq(false)
      expect(NewFreeregCsvUpdateProcessor.processed).to be_nil
    end
  end

  # ---------------------------------------------------------
  # 4. NEW RANGE PROCESSING (NO LOCK FILE)
  # ---------------------------------------------------------
  context "when no lock file exists" do
    before do
      FileUtils.rm_f(@processing_lock)
    end

    it "creates lock file and processes" do
      result = service.run_rake_equivalent(
        search_record: "create_search_records",
        type: "range",
        force: "no",
        range: "USER001/test.csv"
      )

      expect(result.was_executed).to eq(true)
      expect(File.exist?(@processing_lock)).to eq(true)
      expect(NewFreeregCsvUpdateProcessor.processed).to eq(
        ["create_search_records", "range", "no", "USER001/test.csv"]
      )
    end
  end

  # ---------------------------------------------------------
  # 5. UNEXPECTED ERROR HANDLING
  # ---------------------------------------------------------
  context "when an unexpected error occurs" do
    before do
      class NewFreeregCsvUpdateProcessor
        def self.activate_project(*)
          raise StandardError, "boom"
        end
      end
    end

    it "returns failure and cleans lock files" do
      FileUtils.touch(@processing_lock)
      FileUtils.touch(@initiation_lock)

      result = service.run_rake_equivalent(
        search_record: "create_search_records",
        type: "individual",
        force: "no",
        range: "USER001/test.csv"
      )

      expect(result.was_executed).to eq(false)
      expect(result.error).to be_a(StandardError)
      expect(File.exist?(@processing_lock)).to eq(false)
      expect(File.exist?(@initiation_lock)).to eq(false)
    end
  end
end

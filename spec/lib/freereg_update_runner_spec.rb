require "rails_helper"
require Rails.root.join("lib/build/freereg_update_runner")
require Rails.root.join("lib/new_freereg_csv_update_processor")

RSpec.describe Build::FreeregUpdateRunner do
  let(:args) do
    OpenStruct.new(
      search_record: "abc.csv",
      type: type,
      force: "force_rebuild",
      range: "k"
    )
  end

  let(:runner) { described_class.new(args) }

  let(:lock_file)      { Rails.root.join("tmp/processing_rake_lock_file.txt") }
  let(:init_lock_file) { Rails.root.join("tmp/processor_initiation_lock_file.txt") }

  before do
    # Ensure a clean slate for each example
    FileUtils.rm_f(lock_file)
    FileUtils.rm_f(init_lock_file)

    # Stub processor methods so we don't run real logic/method
    # Just accept the CALL and return `nil`
    # This checks that your runner called the method - without running the real implementation
    allow(NewFreeregCsvUpdateProcessor).to receive(:activate_project)
    allow(NewFreeregCsvUpdateProcessor).to receive(:process_activate_project)
    allow(NewFreeregCsvUpdateProcessor).to receive(:create_rake_lock_file)
    allow(NewFreeregCsvUpdateProcessor).to receive(:check_file_lock_status)
  end

  # -------------------------------------------------------------------
  # INDIVIDUAL MODE
  # -------------------------------------------------------------------
  context "when type is 'individual'" do
    let(:type) { "individual" }

    it "calls activate_project with correct arguments" do
      runner.run

      expect(NewFreeregCsvUpdateProcessor).to have_received(:activate_project)
        .with("abc.csv", "individual", "force_rebuild", "k")
    end

    it "does not create or check lock files" do
      runner.run

      expect(NewFreeregCsvUpdateProcessor).not_to have_received(:create_rake_lock_file)
      expect(NewFreeregCsvUpdateProcessor).not_to have_received(:check_file_lock_status)
    end
  end

  # -------------------------------------------------------------------
  # LOCK FILE EXISTS
  # -------------------------------------------------------------------
  context "when lock file exists" do
    let(:type) { "range" }

    before do
      FileUtils.touch(lock_file)
    end

    context "and lock status is present" do
      before do
        allow(NewFreeregCsvUpdateProcessor).to receive(:check_file_lock_status).and_return(true)
      end

      it "processes the project" do
        runner.run

        expect(NewFreeregCsvUpdateProcessor).to have_received(:process_activate_project)
          .with("abc.csv", "range", "force_rebuild", "k")
      end
    end

    context "and lock status is NOT present" do
      before do
        allow(NewFreeregCsvUpdateProcessor).to receive(:check_file_lock_status).and_return(nil)
      end

      it "does not process the project" do
        runner.run

        expect(NewFreeregCsvUpdateProcessor).not_to have_received(:process_activate_project)
      end
    end
  end

  # -------------------------------------------------------------------
  # NO LOCK FILE
  # -------------------------------------------------------------------
  context "when no lock file exists" do
    let(:type) { "range" }

    it "creates a new lock file and processes the project" do
      runner.run

      expect(NewFreeregCsvUpdateProcessor).to have_received(:create_rake_lock_file)
      expect(NewFreeregCsvUpdateProcessor).to have_received(:process_activate_project)
    end
  end

  # -------------------------------------------------------------------
  # EXCEPTION HANDLING
  # -------------------------------------------------------------------
  context "when an exception occurs" do
    let(:type) { "range" }

    before do
      # Force the runner into the branch that calls process_project
      allow(NewFreeregCsvUpdateProcessor).to receive(:check_file_lock_status).and_return(true)

      # Make process_activate_project raise an exception inside that branch
      allow(NewFreeregCsvUpdateProcessor).to receive(:process_activate_project)
        .and_raise(StandardError.new("boom"))

      # Create both lock files so the rescue block has something to clean up
      FileUtils.touch(lock_file)
      FileUtils.touch(init_lock_file)
    end

    it "removes both lock files" do
      runner.run rescue nil

      expect(File.exist?(lock_file)).to eq(false)
      expect(File.exist?(init_lock_file)).to eq(false)
    end
  end

  # -------------------------------------------------------------------
  # LOGGING
  # -------------------------------------------------------------------
  context "logging" do
    let(:type) { "individual" }

    it "prints log messages to stdout" do
      expect { runner.run }.to output(/FREEREG:CSV_PROCESSING:/).to_stdout
    end
  end
end

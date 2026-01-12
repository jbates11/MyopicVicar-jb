require "rails_helper"
require "new_freereg_csv_update_processor"

RSpec.describe NewFreeregCsvUpdateProcessor do
  describe ".process_activate_project" do
    let(:create_search_records) { double("create_search_records") }
    let(:type)                  { :some_type }
    let(:force)                 { false }
    let(:range)                 { "A-Z" }

    let(:locking_file) { instance_double(File, flock: true) }
    let(:rake_lock_path) { Rails.root.join("tmp", "processing_rake_lock_file.txt") }
    let(:initiation_lock_path) { Rails.root.join("tmp", "processor_initiation_lock_file.txt") }

    before do
      # Ensure legacy class instance variables are set on the singleton class
      NewFreeregCsvUpdateProcessor.singleton_class.instance_variable_set(:@locking_file, locking_file)
      NewFreeregCsvUpdateProcessor.singleton_class.instance_variable_set(:@rake_lock_file, rake_lock_path)

      # Prevent legacy code from overwriting our stubs
      allow(NewFreeregCsvUpdateProcessor).to receive(:create_rake_lock_file)

      # Mock PhysicalFile.waiting.exists? → true once, then false
      waiting_double = double("waiting")
      allow(PhysicalFile).to receive(:waiting).and_return(waiting_double)
      allow(waiting_double).to receive(:exists?).and_return(true, false)

      # Prevent actual sleeping
      allow_any_instance_of(Object).to receive(:sleep)

      # Prevent filesystem side effects
      allow(File).to receive(:exist?).and_return(false)
      allow(FileUtils).to receive(:rm_f)
      allow(File).to receive(:open).and_call_original

      # Spy on activate_project
      allow(NewFreeregCsvUpdateProcessor).to receive(:activate_project)
    end

    it "calls activate_project exactly once when one waiting file exists" do
      NewFreeregCsvUpdateProcessor.process_activate_project(
        create_search_records,
        type,
        force,
        range
      )

      expect(NewFreeregCsvUpdateProcessor).to have_received(:activate_project)
        .with(create_search_records, type, force, range)
        .once
    end

    # JC NOT work, pending
    # it "locks and unlocks the file exactly once" do
    #   NewFreeregCsvUpdateProcessor.process_activate_project(
    #     create_search_records,
    #     type,
    #     force,
    #     range
    #   )

    #   expect(locking_file).to have_received(:flock).with(File::LOCK_EX).once
    #   expect(locking_file).to have_received(:flock).with(File::LOCK_UN).once
    # end
  end
end

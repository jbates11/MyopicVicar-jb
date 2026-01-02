require "rails_helper"
require "fileutils"

RSpec.describe CsvfileBatchProcessingRunner, type: :service do
  let(:service) { CsvfileBatchProcessingRunner.new }

  # ---------------------------------------------------------
  # TEMP DATAFILES DIRECTORY (NO STUBS)
  # ---------------------------------------------------------
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = tmpdir

      original_datafiles = Rails.application.config.datafiles
      Rails.application.config.datafiles = @tmpdir

      begin
        example.run
      ensure
        Rails.application.config.datafiles = original_datafiles
      end
    end
  end

  # ---------------------------------------------------------
  # Centralized cleanup for every example
  # ---------------------------------------------------------
  after(:each) do
    # Manual clean up since database_cleaner-mongoid bypasses callbacks and mysql
    Refinery::Authentication::Devise::User.find_by(username: "USER001")&.destroy!
    # Refinery::Authentication::Devise::User.find_by(username: "COORD001")&.destroy!
  end

  # ---------------------------------------------------------
  # FACTORIES
  # ---------------------------------------------------------

  let!(:user) do
    create(:userid_detail,
      userid: "USER001",
      person_role: "researcher"
    )
  end

  let!(:csvfile) do
    create(:csvfile,
      userid: "USER001",
      file_name: "test.csv"
    )
  end

  def user_dir
    File.join(@tmpdir, "USER001")
  end

  before do
    FileUtils.mkdir_p(user_dir)
    FileUtils.touch(File.join(user_dir, "test.csv"))
  end

  # ---------------------------------------------------------
  # 1. FAILURE: model validation errors
  # ---------------------------------------------------------
  context "when csvfile has validation errors" do
    before do
      csvfile.file_name = nil
      csvfile.save(validate: false)
    end

    it "returns a failure result with message" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(false)
      expect(result.message).to include("unexpected error occurred")
      # expect(result.message).to include("unsuccessful")
      expect(result.trace_id).to be_present
    end
  end

  # ---------------------------------------------------------
  # 2. FAILURE: batch already waiting
  # ---------------------------------------------------------
  context "when a batch is already waiting to be processed" do
    before do
      PhysicalFile.create!(
        userid: "USER001",
        file_name: "test.csv",
        waiting_to_be_processed: true
      )
    end

    it "returns a failure result" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(false)
      expect(result.message).to include("already waiting")
    end
  end

  # ---------------------------------------------------------
  # 3. FAILURE: file too small
  # ---------------------------------------------------------
  context "when file is too small" do
    before do
      # Real override, no stubs
      def csvfile.estimate_size
        50
      end
    end

    it "returns a failure result" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(false)
      expect(result.message).to include("too small")
    end
  end

  # ---------------------------------------------------------
  # 4. SUCCESS: freereg trainee  - JC NOTE triggers rake task in background and hangs
  # ---------------------------------------------------------
  context "when template_set is freereg and user is trainee" do
    before do
      original_template = MyopicVicar::Application.config.template_set
      MyopicVicar::Application.config.template_set = "freereg"

      user.update(person_role: "trainee")

      def csvfile.estimate_size
        500
      end

      def csvfile.estimate_time
        1
      end

      @restore_template = -> {
        MyopicVicar::Application.config.template_set = original_template
      }
    end

    after { @restore_template.call }

    it "returns success" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(true)
      expect(result.message).to include("being checked")
    end
  end

  # ---------------------------------------------------------
  # 5. SUCCESS: freereg normal user small file  - JC NOTE triggers rake task in background and hangs
  # ---------------------------------------------------------
  context "when freereg and file is small enough" do
    before do
      original_template = MyopicVicar::Application.config.template_set
      MyopicVicar::Application.config.template_set = "freereg"

      def csvfile.estimate_size
        500
      end

      def csvfile.estimate_time
        1
      end

      @restore_template = -> {
        MyopicVicar::Application.config.template_set = original_template
      }
    end

    after { @restore_template.call }

    it "returns success" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(true)
      expect(result.message).to include("being processed")
    end
  end

  # ---------------------------------------------------------
  # 6. FAILURE: freereg large file
  # ---------------------------------------------------------
  context "when freereg and file is too large" do
    before do
      original_template = MyopicVicar::Application.config.template_set
      MyopicVicar::Application.config.template_set = "freereg"

      def csvfile.estimate_size
        500
      end

      def csvfile.estimate_time
        Csvfile::PROCESSING_TIME_THRESHOLD + 10
      end

      @restore_template = -> {
        MyopicVicar::Application.config.template_set = original_template
      }
    end

    after { @restore_template.call }

    it "returns failure" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(false)
      expect(result.message).to include("too large")
    end
  end

  # ---------------------------------------------------------
  # 7. SUCCESS: freecen processing  - JC NOTE triggers rake task in background and hangs
  # ---------------------------------------------------------
  context "when template_set is freecen" do
    before do
      original_template = MyopicVicar::Application.config.template_set
      MyopicVicar::Application.config.template_set = "freecen"

      def csvfile.estimate_size
        500
      end

      def csvfile.estimate_time
        1
      end

      @restore_template = -> {
        MyopicVicar::Application.config.template_set = original_template
      }
    end

    after { @restore_template.call }

    it "returns success" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(true)
      expect(result.message).to include("being checked")
    end
  end

  # ---------------------------------------------------------
  # 8. FAILURE: unexpected error
  # ---------------------------------------------------------
  context "when an unexpected error occurs" do
    before do
      # Real override, not a stub
      def csvfile.check_for_existing_file_and_save
        raise StandardError, "boom"
      end
    end

    it "returns failure with error object" do
      result = service.process_batch(csvfile: csvfile, user: user)

      expect(result.was_processed).to eq(false)
      expect(result.error).to be_a(StandardError)
      expect(result.trace_id).to be_present
    end
  end
end

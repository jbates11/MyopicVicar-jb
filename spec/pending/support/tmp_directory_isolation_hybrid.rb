module TmpDirectoryIsolationHybrid
  #
  # GROUP-LEVEL DSL: usable at top of `describe`
  #
  def isolate_tmp_per_example
    around(:each) do |example|
      Dir.mktmpdir("rspec_example_tmp") do |example_tmp|
        RSpec.configuration.example_tmp = example_tmp

        # Replace suite tmp symlink target with example tmp
        FileUtils.rm_f(RSpec.configuration.suite_tmp)
        FileUtils.ln_s(example_tmp, RSpec.configuration.suite_tmp)

        begin
          example.run
        ensure
          # Restore suite tmp symlink target
          FileUtils.rm_f(RSpec.configuration.suite_tmp)
          FileUtils.ln_s(RSpec.configuration.suite_tmp, Rails.root.join("tmp"))
        end
      end
    end
  end

  #
  # INSTANCE HELPERS (usable inside `it`)
  #
  def suite_tmp
    RSpec.configuration.suite_tmp
  end

  def example_tmp
    RSpec.configuration.example_tmp
  end

  def current_tmp
    example_tmp || suite_tmp
  end

  def processing_lock_path
    File.join(current_tmp, "processing_rake_lock_file.txt")
  end

  def initiation_lock_path
    File.join(current_tmp, "processor_initiation_lock_file.txt")
  end
end

#
# SUITE-LEVEL ISOLATION (must be on RSpec configuration)
#
RSpec.configure do |config|
  #
  # Define suite-level settings
  #
  config.add_setting :suite_tmp
  config.add_setting :real_tmp_path
  config.add_setting :backup_tmp_path
  config.add_setting :example_tmp

  #
  # Make DSL available at group level
  #
  config.extend TmpDirectoryIsolationHybrid

  #
  # Make instance helpers available inside examples
  #
  config.include TmpDirectoryIsolationHybrid

  #
  # SUITE SETUP
  #
  config.before(:suite) do
    config.suite_tmp = Dir.mktmpdir("rspec_suite_tmp")

    config.real_tmp_path   = Rails.root.join("tmp")
    config.backup_tmp_path = Rails.root.join("tmp_original_before_suite")

    # Backup real tmp
    FileUtils.mv(config.real_tmp_path, config.backup_tmp_path) if File.exist?(config.real_tmp_path)

    # Replace Rails tmp with symlink to suite tmp
    FileUtils.mkdir_p(config.real_tmp_path.parent)
    FileUtils.ln_s(config.suite_tmp, config.real_tmp_path)
  end

  #
  # SUITE TEARDOWN
  #
  config.after(:suite) do
    # Remove symlink
    FileUtils.rm_f(config.real_tmp_path)

    # Restore original tmp
    FileUtils.mv(config.backup_tmp_path, config.real_tmp_path) if File.exist?(config.backup_tmp_path)

    # Remove suite tmp
    FileUtils.rm_rf(config.suite_tmp) if config.suite_tmp && Dir.exist?(config.suite_tmp)
  end
end

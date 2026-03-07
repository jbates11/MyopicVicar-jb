require "awesome_print"

# Global AP defaults for the test suite
AwesomePrint.defaults = {
  indent: -2,            # Align keys
  index: false,          # Hide array indices
  sort_keys: true,       # Alphabetize hash keys
  color: {
    hash: :pale,
    class: :yellow,
    string: :green
  }
}

# Simple, consistent debug wrapper
module DebugPrintHelper
  def ap_debug(obj, options = {})
    puts "\n" + "DEBUG OUTPUT".center(80, "-")
    ap obj, options
    puts "-" * 80 + "\n"
  end
end

RSpec.configure do |config|
  config.include DebugPrintHelper
end

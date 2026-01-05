require 'awesome_print'

# Safe pretty-print for Mongoid documents
module MongoidDebugHelper
  def mongoid_ap(document, options = {})
    if document.respond_to?(:attributes)
      # Print raw Mongoid attributes to avoid AR hooks
      ap document.attributes, options.merge(raw: true)
    else
      ap document, options.merge(raw: true)
    end
  end
end

RSpec.configure do |config|
  config.include MongoidDebugHelper
end

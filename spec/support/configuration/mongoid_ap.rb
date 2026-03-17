require 'awesome_print'

# Safe pretty-print for Mongoid documents
# avoids AP’s known limitation with deep nested Mongoid relations.
# place > church > register > file
module MongoidDebugHelper
  def mongoid_ap(object, options = {})
    effective_options = { raw: true }.merge(options)

    payload =
      case
      when mongoid_document?(object)
        object.attributes
      when enumerable_of_mongoid?(object)
        object.map(&:attributes)
      else
        object
      end

    ap payload, effective_options
  end

  private

  def mongoid_document?(obj)
    obj.respond_to?(:attributes)
  end

  def enumerable_of_mongoid?(obj)
    obj.is_a?(Enumerable) &&
      obj.any? &&
      obj.first.respond_to?(:attributes)
  end
end

RSpec.configure do |config|
  config.include MongoidDebugHelper
end

class SearchName
  include Mongoid::Document
  field :first_name, type: String
  field :last_name, type: String
  field :origin, type: String
  field :role, type: String
  field :gender, type: String #m=male, f=female, nil=not specified
  field :type, type: String

  embedded_in :search_record

  # def contains_wildcard_ucf?
  #   result = UcfTransformer.contains_wildcard_ucf?(self.first_name) || UcfTransformer.contains_wildcard_ucf?(self.last_name)
  #   result
  # end

  def contains_wildcard_ucf?
    Rails.logger.info "\n\n[SearchName] Checking SearchName #{id} for wildcard UCFs..."

    # Collect flags for both names
    flags = {
      first_name: UcfTransformer.contains_wildcard_ucf?(first_name),
      last_name:  UcfTransformer.contains_wildcard_ucf?(last_name)
    }

    # Log results for each name
    flags.each do |field, flagged|
      Rails.logger.info "[SearchName] Log results for each name #{field.to_s.humanize} '#{send(field)}' flagged? #{flagged}"
    end

    # Determine overall result
    result = flags.values.any?

    if result
      Rails.logger.info "*** [SearchName] Wildcard UCF detected in SearchName _id: #{id}"
      Rails.logger.info "[SearchName] SearchName details:\n#{self.ai}\n"
    else
      Rails.logger.info "--- [SearchName] No wildcard UCF detected in SearchName _id: #{id}\n"
    end

    result
  end

end

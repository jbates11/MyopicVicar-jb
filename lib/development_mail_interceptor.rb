class DevelopmentMailInterceptor
  def self.delivering_email(message)
    message.subject = "Trapped message #{message.to} #{message.subject}"
    message.to = 'abc@example.com'
  end
end

class M3LogFileParser::Request < Struct.new(:datetime, :pid, :domain)
  attr_accessor :messages, :current_severity, :stacktrace
  delegate :push, to: :messages

  SEVERITIES = {
    "D" => 1,
    "I" => 2,
    "W" => 3,
    "E" => 4,
    "F" => 5,
    "U" => 6,
  }

  def initialize(*args)
    super
    self.messages = []
    self.current_severity = "D"
    self.stacktrace = []
  end

  def severity(new_severity)
    self.current_severity = new_severity if SEVERITIES[new_severity] > SEVERITIES[current_severity]
  end

  def info?
    current_severity == "I"
  end

  def warn?
    current_severity == "W"
  end

  def error?
    current_severity == "E"
  end

  def fatal?
    current_severity == "F"
  end

  def type
    if stacktrace.blank?
      nil
    elsif stacktrace.first.match("ActiveRecord::RecordNotFound")
      :record_not_found
    elsif stacktrace.first.match("ActionController::RoutingError")
      :routing_error
    elsif stacktrace.first.match(/^ActionController::UnknownFormat/)
      :unknown_format
    elsif stacktrace.first.match(/^ActionController::InvalidAuthenticityToken/)
      :invalid_authenticity_token
    else
      nil
    end
  end

  def ip
    messages.first.gsub(/.*\s(.+)\sat\s.+\s.+\s.+$/, '\1')
  end

  def to_s
    if type.in? [:routing_error, :unknown_format, :record_not_found, :invalid_authenticity_token]
      messages.first.gsub(/.*"([^"]*)".*/, '\1')
    else
      stacktrace.first || messages.first
    end
  end
end

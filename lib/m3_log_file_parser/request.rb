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
    if match_error("ActiveRecord::RecordNotFound")
      :record_not_found
    elsif match_error("ActionController::RoutingError")
      :routing_error
    elsif match_error("ActionController::UnknownFormat")
      :unknown_format
    elsif match_error("ActionController::InvalidAuthenticityToken")
      :invalid_authenticity_token
    elsif match_error("ActionController::BadRequest")
      :bad_request
    else
      nil
    end
  end

  def match_error(error)
    messages.any? { |message| message.match(error) } || stacktrace.first&.match(error)
  end

  def ip
    messages.first.gsub(/.*\s(.+)\sat\s.+\s.+\s.+$/, '\1')
  end

  def to_s
    if type.in? [:routing_error, :unknown_format, :record_not_found, :invalid_authenticity_token]
      messages.first.gsub(/.*"([^"]*)".*/, '\1')
    else
      messages.reject do |message|
        message.starts_with?("Started ") ||
        message.starts_with?("Processing by ") ||
        message.starts_with?("Parameters: ") ||
        message.starts_with?("Completed ") ||
        message.starts_with?("Rendering ") ||
        message.starts_with?("Redirected to") ||
        message.starts_with?("Rendered ")
      end.first || stacktrace.first
    end
  end

  def with_info
    sprintf("%-15s%s", datetime[5..18], to_s)
  end
end

require 'net/smtp'
require 'ostruct'

class M3LogFileParser::Worker < Struct.new(:file_path)
  OUTPUT_LEVELS = { fatal: 4, error: 3, warn: 2, info: 1, all: 0 }
  attr_accessor :requests, :line_mode, :error_output, :mail_count, :defined_errors, :fatal_errors

  def initialize(*args)
    super
    self.requests = {}
    self.error_output = []
    self.mail_count = 0
  end

  def mail_sent
    self.mail_count += 1
  end

  def defined_error_types
    %i{routing_error unknown_format record_not_found invalid_authenticity_token bad_request}
  end

  def perform(output_level=nil)
    parse

    self.fatal_errors = []
    self.defined_errors = {}

    fatal_requests.each do |fatal_request|
      if fatal_request.type.in?(defined_error_types)
        defined_errors[fatal_request.type] ||= {}
        defined_errors[fatal_request.type][fatal_request.to_s] ||= []
        defined_errors[fatal_request.type][fatal_request.to_s].push(fatal_request.ip)
      else
        self.fatal_errors.push(fatal_request)
      end
    end

    puts generate_message if current_level >= OUTPUT_LEVELS.fetch(output_level, 4)
  end

  def file
    @file ||= File.open(file_path)
  end

  def parse
    file.read.split("\n").each do |line|
      self.error_output.push(M3LogFileParser::LineParser.new(self, line).perform)
    end
  end

  def fatal_requests
    requests.values.select(&:fatal?)
  end

  def error_requests
    requests.values.select(&:error?)
  end

  def warn_requests
    requests.values.select(&:warn?)
  end

  def current_level
    return 2 if warn_requests.any?
    return 3 if error_requests.any?
    return 4 if fatal_errors.any?
    0
  end

  def generate_message
    message = ""
    if fatal_errors.present?
      message += "FATALS:\n"
      message += fatal_errors.join("\n")
      message += "\n\n"
    end

    if error_requests.present?
      message += "ERRORS:\n"
      message += error_requests.join("\n")
      message += "\n\n"
    end

    %i{routing_error unknown_format record_not_found invalid_authenticity_token bad_request}

    defined_error_types.each do |error_type|
      if defined_errors[error_type].present?
        message += "#{error_type}:\n"
        defined_errors[error_type].sort_by {|text, ips| ips.length }.reverse_each do |text, ips|
          message += "#{ips.length}x #{text} #{ips.join(", ")}\n"
        end
        message += "\n\n"
      end
    end

    if warn_requests.present?
      message += "WARNINGS:\n"

      warn_requests.group_by(&:to_s).each { |a, b| message += "#{b.length}x: #{a}\n" }
      message += "\n\n"
    end

    if error_output.reject(&:blank?).present?
      message += "Nicht zugeordnet:\n"
      message += error_output.reject(&:blank?).join("\n")
      message += "\n\n"
    end

    if mail_count > 0
      message += "#{mail_count} mails sent\n\n"
    end

    message
  end
end
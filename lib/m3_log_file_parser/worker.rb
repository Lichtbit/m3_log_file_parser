require 'net/smtp'
require 'ostruct'

class M3LogFileParser::Worker < Struct.new(:file_path)
  attr_accessor :requests, :line_mode, :error_output, :mail_count,
    :routing_errors, :format_errors, :record_not_found_errors, :fatal_errors

  def initialize(*args)
    super
    self.requests = {}
    self.error_output = []
    self.mail_count = 0
  end

  def mail_sent
    self.mail_count += 1
  end

  def perform
    self.parse

    self.routing_errors = {}
    self.format_errors = {}
    self.record_not_found_errors = {}

    self.fatal_errors = []
    fatal_requests.each do |fatal_request|
      if fatal_request.type == :routing_error
        self.routing_errors[fatal_request.to_s] ||= []
        self.routing_errors[fatal_request.to_s].push(fatal_request.ip)
      elsif fatal_request.type == :unknown_format
        self.format_errors[fatal_request.to_s] ||= []
        self.format_errors[fatal_request.to_s].push(fatal_request.ip)
      elsif fatal_request.type == :record_not_found
        self.record_not_found_errors[fatal_request.to_s] ||= []
        self.record_not_found_errors[fatal_request.to_s].push(fatal_request.ip)
      else
        self.fatal_errors.push(fatal_request)
      end
    end
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

    if routing_errors.present?
      message += "RoutingErrors:\n"
      routing_errors.sort_by {|text, ips| ips.length }.reverse_each do |text, ips|
        message += "#{ips.length}x #{text} #{ips.join(", ")}\n"
      end
      message += "\n\n"
    end

    if record_not_found_errors.present?
      message += "RecordNotFound:\n"
      record_not_found_errors.sort_by {|text, ips| ips.length }.reverse_each do |text, ips|
        message += "#{ips.length}x #{text} #{ips.join(", ")}\n"
      end
      message += "\n\n"
    end

    if format_errors.present?
      message += "FormatErrors:\n"
      format_errors.sort_by {|text, ips| ips.length }.reverse_each do |text, ips|
        message += "#{ips.length}x #{text} #{ips.join(", ")}\n"
      end
      message += "\n\n"
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
# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phonenumber(phonenumber)
  phonenumber.gsub!(/\D/, '')

  if phonenumber.length == 10
    phonenumber
  elsif phonenumber.length == 11 && phonenumber[0] == '1'
    phonenumber = phonenumber[1..10]
  else
    phonenumber = "#{phonenumber} is not valid!"
  end

  area_code = phonenumber[0..2]
  prefix = phonenumber[3..5]
  line_number = phonenumber[6..phonenumber.length - 1]
  phonenumber = "(#{area_code}) #{prefix} #{line_number}"
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    )
    legislators = legislators.officials

    legislator_names = legislators.map(&:name)

    legislators_string = legislator_names.join(', ')
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def frequency_count(hours)
  hours.max_by { |hour| hours.count(hour) }
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

regdate_hours = []
regdate_days = []
optimal_hour = nil
optimal_day = nil
week = { 0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday',
         6 => 'Saturday' }

contents.each do |row|
  id = row[0]

  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  phonenumber = clean_phonenumber(row[:homephone])

  regdate_hours << DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M').hour

  regdate_days << DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M').wday

  optimal_hour = frequency_count(regdate_hours)

  optimal_day = week[frequency_count(regdate_days)]

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

puts "The optimal day of the week and hour of the day to run ads: #{optimal_day} at #{optimal_hour}."

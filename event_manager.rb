require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

# file paths
file_path = File.expand_path('event_attendees.csv', __dir__)
key_path = File.expand_path('secret.key', __dir__)
form_letter_path = File.expand_path('form_letter.erb', __dir__)

civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
civic_info.key = File.read(key_path).strip
template_letter = File.read(form_letter_path)
erb_template = ERB.new template_letter

puts 'Event Manager Initialized!'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  clean_num = phone_number.gsub(/\D/, '')
  if clean_num.length == 10
    clean_num.to_s
  elsif clean_num.length == 11 && clean_num[0] == '1'
    clean_num.to_s[1..]
  else
    "Invalid"
  end
end

def string_to_time(time_string)
  time_object = Time.strptime(time_string, "%m/%d/%y %H:%M")
  return time_object
end

def most_frequent_days(date, days)
  day = date.wday
  days[day] += 1
end

def most_frequent_hours(time, hours)
  hour = time.hour
  hours[hour] += 1
end

def most_frequent(hash)
  max_value = hash.values.max
  return hash.select { |key, value| value == max_value }.keys
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    )
    legislators = legislators.officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  # Ensure the path is relative to the event_manager directory
  output_dir = File.expand_path('output', __dir__)

  Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
  filename = File.join(output_dir, "thanks_#{id}.html")

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

if File.exist?(file_path)
  hours = Hash.new(0)
  days = Hash.new(0)
  day_names = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]

  contents = CSV.open(file_path, headers: true, header_converters: :symbol)
  contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    regdate = string_to_time(row[:regdate])
    day = regdate.to_date
    most_frequent_hours(regdate, hours)
    most_frequent_days(day, days)
    phone_number = clean_phone_number(row[:homephone])
    legislators = legislators_by_zipcode(zipcode)

    #form_letter = erb_template.result(binding)
    #save_thank_you_letter(id,form_letter)
  end 
  most_frequent_hours = most_frequent(hours)
  most_frequent_days = most_frequent(days)

  puts "Most frequent hours of registration are: #{most_frequent_hours.join(':00, ')}:00"
  puts "Most frequent days of registration are: #{most_frequent_days.map { |day| day_names[day] }.join(', ')}"
else
  puts "File not found! Looking for: #{file_path}"
end
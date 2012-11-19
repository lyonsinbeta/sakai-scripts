# single.csv MUST include headers: site_id, id, role
# training.csv (if used) must include a header for username

require 'optparse'
require 'savon'
require 'csv'
require './config.rb'

options = {}
OptionParser.new do |opts|
  opts.banner = "\nThanks for supporting open source software."
  opts.on('-v', '--verify', "Verifies an instructor has completed training before activating") do |v|
    options[:verify] = v
  end
  opts.on('-h', '--help', 'Displays help') do
    puts opts
	exit
  end
end.parse!

course_list = []

if options[:verify]
  begin
    sakai_trained = []
    CSV.foreach(training_csv, {:headers => true, :header_converters => :symbol}) do |trained|
      sakai_trained << trained[:username].downcase
    end
  rescue
    abort 'Error opening training.csv'
  end
  abort 'The training.csv appears to be empty.' if sakai_trained.empty? 
end 
 
CSV.foreach(activation_csv, {:headers => true, :header_converters => :symbol}) do |row|
  row << 'Untrained' if sakai_trained && !sakai_trained.include?(row[:id].downcase)
  course_list << row
end

if course_list.empty?
  abort 'Input csv appears to be empty.'
end

login = Savon::Client.new(login_wsdl)
  login.http.auth.ssl.verify_mode = :none

begin
  session = login.request(:login) do
    soap.body = { :id => soap_user, :pw => soap_pwd }
  end
rescue
  abort 'Login failed.'
end

soapClient   = Savon::Client.new(script_wsdl)
  soapClient.http.auth.ssl.verify_mode = :none
soapLSClient = Savon::Client.new(longsight_wsdl) 
  soapLSClient.http.auth.ssl.verify_mode = :none

course_list.each do |course|
  unless course.fields.include?('Untrained')
    response = soapClient.request(:add_member_to_site_with_role) do
      soap.body = { :sessionid => session[:login_response][:login_return],
                    :siteid    => course[:site_id],
                    :eid       => course[:id],
                    :roleid    => course[:role] }
    end
    
    if response[:add_member_to_site_with_role_response][:add_member_to_site_with_role_return] =~ /null/
      course << 'Returned error'
    end
  end
end

time = Time.now  
t = time.strftime("%Y-%m-%d %H%M%S")
  
CSV.open("Courses activated #{t}.csv", 'w') { |csv| csv << ['site_id', 'instructor'] }
CSV.open("Courses activated #{t}.csv", 'a') do |csv| 
  course_list.each { |course| csv << course } 
end

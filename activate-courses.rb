# .csv MUST include headers in the order of
# siteid, userid of instructor

require 'optparse'
require 'savon'
require 'csv'

host           = ''
soap_user      = ''
soap_pwd       = '' 
activation_csv = ARGV[0] || 'single.csv'

login_wsdl     = "#{host}/sakai-axis/SakaiLogin.jws?wsdl"
script_wsdl    = "#{host}/sakai-axis/SakaiScript.jws?wsdl"
longsight_wsdl = "#{host}/sakai-axis/WSLongsight.jws?wsdl"

def verify_course(course, session)
  response = soapLSClient.request(:longsight_site_exists) do
	soap.body = { :sessionid => session[:login_response][:login_return],
                  :siteid    => course[0] }
  end
  
  if response[:longsight_site_exists_response][:longsight_site_exists_return] == false
	course << 'No such course'
  end
  
  return course
end

options = {}
OptionParser.new do |opts|
  opts.banner = "\nThanks for supporting open source software."

  opts.on('-v', '--verify', "Use this option if you're not positive all siteid's in your csv exist.") do |v|
	options[:verify] = v
  end

  opts.on('-h', '--help', 'Displays help') do
	puts opts
	exit
  end
end.parse!

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
  
courses_to_activate = []

CSV.foreach(activation_csv, {:headers => true}) do |row|
  options[:verify] ? courses_to_activate << verify_course(row, session) : courses_to_activate << row
end

courses_to_activate.each do |course|

  unless course.include? 'No such course'
    response = soapLSClient.request(:add_inactive_member_to_site_with_role) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                    :siteid    => course[0],
                    :eid       => course[1],
                    :roleid    => 'Instructor' }
    end 

    response = soapLSClient.request(:set_member_status) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                    :siteid    => course[0],
                    :eid       => course[1],
                    :active    => true }
    end
  end
end

unless courses_to_activate.empty?
  CSV.open('Courses activated report.csv', 'w') { |csv| csv << ['siteid', 'instructor id'] }
  CSV.open('Courses activated report.csv', 'a') do |csv| 
    courses_to_activate.each { |course| csv << course } 
  end
end
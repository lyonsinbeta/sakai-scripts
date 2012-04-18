# .csv MUST include headers in the order of
# siteid, userid of instructor

require 'savon'
require 'csv'

host           = ''
usr            = ''
pwd            = '' 
activation_csv = ARGV[0] || 'single.csv'

login_wsdl     = "#{host}/sakai-axis/SakaiLogin.jws?wsdl"
script_wsdl    = "#{host}/sakai-axis/SakaiScript.jws?wsdl"
longsight_wsdl = "#{host}/sakai-axis/WSLongsight.jws?wsdl"

login = Savon::Client.new(login_wsdl)
login.http.auth.ssl.verify_mode = :none

session = login.request(:login) do
  soap.body = { :id => usr, :pw => pwd }
end

soapClient   = Savon::Client.new(script_wsdl)
soapClient.http.auth.ssl.verify_mode = :none
soapLSClient = Savon::Client.new(longsight_wsdl)
soapLSClient.http.auth.ssl.verify_mode = :none
  
courses_to_activate = []

CSV.foreach(activation_csv, {:headers => true}) do |row|

  response = soapLSClient.request(:longsight_site_exists) do
	soap.body = { :sessionid => session[:login_response][:login_return],
                  :siteid    => row[0] }
  end
  
  if response[:longsight_site_exists_response][:longsight_site_exists_return] == true
	courses_to_activate << [row[0], row[1]]
  else
    courses_to_activate << [row[0], row[1], "No such course"]
  end
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
  CSV.open("Courses activated report.txt", 'w') { |csv| csv << ["siteid", "instructor id"] }
  CSV.open("Courses activated report.txt", 'a') do |csv| 
    courses_to_activate.each { |course| csv << course } 
  end
end
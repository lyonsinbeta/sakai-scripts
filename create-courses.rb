# .csv MUST include headers in the order of 
# siteid, Site Title, userid of instructor

require 'optparse'
require 'savon'
require 'csv'

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

host               = ''
soap_user          = ''
soap_pwd           = ''
term               = ''
create_courses_csv = ARGV[0] || 'create-course.csv'
training_csv       = 'training.csv' 

default_tools = { 'Syllabus'        => 'sakai.syllabus',
                  'Calendar'        => 'sakai.summary.calendar', 
                  'Announcements'   => 'sakai.announcements', 
                  'Lesson Builder'  => 'sakai.lessonbuildertool', 
                  'Assignment2'     => 'sakai.assignment2', 
                  'Tests & Quizzes' => 'sakai.samigo', 
                  'Forums'          => 'sakai.forums', 
                  'Messages'        => 'sakai.messages', 
                  'Gradebook'       => 'sakai.gradebook.tool', 
                  'Roster'          => 'sakai.site.roster', 
                  'Statistics'      => 'sakai.sitestats', 
                  'User Activity'   => 'seminole.useractivity', 
                  'Section Info'    => 'sakai.sections', 
                  'Site Info'       => 'sakai.siteinfo' }

login_wsdl     = "#{host}/sakai-axis/SakaiLogin.jws?wsdl"
script_wsdl    = "#{host}/sakai-axis/SakaiScript.jws?wsdl"
longsight_wsdl = "#{host}/sakai-axis/WSLongsight.jws?wsdl"

course_list = []

if options[:verify]
  begin
    sakai_trained = []
    CSV.foreach(training_csv, {:headers => true}) do |trained|
      sakai_trained << trained[0].to_s.downcase
    end
  rescue
    abort 'Error opening training.csv'
  end
  abort 'The training.csv appears to be empty.' if sakai_trained.empty? 
end 
 
CSV.foreach(create_courses_csv, {:headers => true}) do |row|
  row << 'Untrained' if sakai_trained && !sakai_trained.include?(row[1].downcase)
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
  response = soapClient.request(:add_new_site) do
	soap.body = { :sessionid   => session[:login_response][:login_return],
                  :siteid      => course[0],
                  :title       => course[1],
                  :description => '',
                  :shortdesc   => '',
                  :iconurl     => '',
                  :infourl     => '',
                  :joinable    => false,
                  :joinerrole  => 'Student',
                  :published   => false,
                  :publicview  => false,
                  :skin        => '',
                  :type        => 'course' }
  end

  response = soapClient.request(:set_site_property) do
	soap.body = { :sessionid => session[:login_response][:login_return],
                  :siteid    => course[0],
                  :propname  => 'term',
                  :propvalue => term }
  end

# Loop to add default tools

  default_tools.each_pair do |tool_name, tool_id|
  	req = soapClient.request(:add_new_page_to_site) do
		soap.body = { :sessionid  => session[:login_response][:login_return],
                        :siteid     => course[0],
                        :pagetitle  => tool_name,
                        :pagelayout => 2 }
	end

  	req = soapClient.request(:add_new_tool_to_page) do
		soap.body = { :sessionid   => session[:login_response][:login_return],
                        :siteid      => course[0],
                        :pagetitle   => tool_name,
                        :tooltitle   => tool_name,
                        :toolid      => tool_id,
                        :layouthints => '0,0' }
	end
  end

# Home begin
# This whole part is to setup the complicated, multi-tooled 'Home'

  req = soapClient.request(:add_new_page_to_site) do
	  soap.body = { :sessionid  => session[:login_response][:login_return],
                     :siteid     => course[0],
                     :pagetitle  => 'Home',
                     :pagelayout => 1 }
  end

  req = soapLSClient.request(:add_config_property_to_page) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => course[0],
                     :pagetitle => 'Home',
                     :propname  => 'is_home_page',
                     :propvalue => 'true' }
  end

  req = soapClient.request(:add_new_tool_to_page) do
	  soap.body = { :sessionid   => session[:login_response][:login_return],
                     :siteid      => course[0],
                     :pagetitle   => 'Home',
                     :tooltitle   => 'Site Information Display',
                     :toolid      => 'sakai.iframe.site',
                     :layouthints => '0,0' }
  end

  req = soapClient.request(:add_config_property_to_tool) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => course[0],
                     :pagetitle => 'Home',
                     :tooltitle => 'Worksite Information',
                     :propname  => 'special',
                     :propvalue => 'worksite' }
  end

  req = soapClient.request(:add_new_tool_to_page) do
	  soap.body = { :sessionid   => session[:login_response][:login_return],
                     :siteid      => course[0],
                     :pagetitle   => 'Home',
                     :tooltitle   => 'Recent Announcements',
                     :toolid      => 'sakai.synoptic.announcement',
                     :layouthints => '0,1' }
  end

# Remove creator of site and add correct instructor

  req = soapClient.request(:remove_member_from_site) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => course[0],
                     :userid    => soap_user }
  end

  req = soapClient.request(:add_member_to_site_with_role) do
      soap.body = { :sessionid => session[:login_response][:login_return],
                    :siteid    => course[0],
                    :eid       => course[2],
                    :roleid    => 'Instructor' }
    end
  end
end

time = Time.now  
t = time.strftime("%Y-%m-%d %H%M%S")
  
CSV.open("Courses created #{t}.csv", 'w') { |csv| csv << ['siteid', 'site title', 'instructor'] }
CSV.open("Courses created #{t}.csv", 'a') do |csv| 
  course_list.each { |course| csv << course } 
end
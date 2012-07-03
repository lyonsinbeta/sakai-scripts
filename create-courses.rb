# .csv MUST include headers

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
create_courses_csv = ARGV[0] || 'create-courses.csv'
training_csv       = 'training.csv' 

default_tools = { 'Syllabus'        => 'sakai.syllabus',
                  'Calendar'        => 'sakai.schedule', 
                  'Announcements'   => 'sakai.announcements', 
                  'Lessons'         => 'sakai.lessonbuildertool', 
                  'Assignments'     => 'sakai.assignment2', 
                  'Tests & Quizzes' => 'sakai.samigo', 
                  'Forums'          => 'sakai.forums', 
                  'Messages'        => 'sakai.messages', 
                  'Gradebook'       => 'sakai.gradebook.tool', 
                  'Roster'          => 'sakai.site.roster',
                  'Resources'       => 'sakai.resources', 
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
    CSV.foreach(training_csv, {:headers => true, :header_converters => :symbol}) do |trained|
      sakai_trained << trained[:username].downcase
    end
  rescue
    abort 'Error opening training.csv'
  end
  abort 'The training.csv appears to be empty.' if sakai_trained.empty? 
end 
 
CSV.foreach(create_courses_csv, {:headers => true, :header_converters => :symbol}) do |row|
  row << 'Untrained' if sakai_trained && !sakai_trained.include?(row[:instructor].downcase)
  course_list << row.to_hash
end

# Removes two unnecessary columns and any rows with a :status
course_list.each { |course| course.delete_if { |k| k == :child_class_number }}
course_list.each { |course| course.delete_if { |k| k =~ /(sql)/ }}
course_list.delete_if { |course| course[:status] != nil }
# Removes duplicate rows
course_list.uniq!

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
  unless course.include?('Untrained')
  response = soapClient.request(:add_new_site) do
	soap.body = { :sessionid   => session[:login_response][:login_return],
                  :siteid      => course[:parent_site_id],
                  :title       => course[:title],
                  :description => '',
                  :shortdesc   => '',
                  :iconurl     => '',
                  :infourl     => '',
                  :joinable    => false,
                  :joinerrole  => 'Instructor',
                  :published   => false,
                  :publicview  => false,
                  :skin        => '',
                  :type        => 'course' }
  end

  response = soapClient.request(:set_site_property) do
	soap.body = { :sessionid => session[:login_response][:login_return],
                  :siteid    => course[:parent_site_id],
                  :propname  => 'term',
                  :propvalue => term }
  end

# Loop to add default tools

  default_tools.each_pair do |tool_name, tool_id|
  	req = soapClient.request(:add_new_page_to_site) do
		soap.body = { :sessionid  => session[:login_response][:login_return],
                        :siteid     => course[:parent_site_id],
                        :pagetitle  => tool_name,
                        :pagelayout => 2 }
	end

  	req = soapClient.request(:add_new_tool_to_page) do
		soap.body = { :sessionid   => session[:login_response][:login_return],
                        :siteid      => course[:parent_site_id],
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
                     :siteid     => course[:parent_site_id],
                     :pagetitle  => 'Home',
                     :pagelayout => 1 }
  end

  req = soapLSClient.request(:add_config_property_to_page) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => course[:parent_site_id],
                     :pagetitle => 'Home',
                     :propname  => 'is_home_page',
                     :propvalue => 'true' }
  end

  req = soapClient.request(:add_new_tool_to_page) do
	  soap.body = { :sessionid   => session[:login_response][:login_return],
                     :siteid      => course[:parent_site_id],
                     :pagetitle   => 'Home',
                     :tooltitle   => 'Site Information Display',
                     :toolid      => 'sakai.iframe.site',
                     :layouthints => '0,0' }
  end

  req = soapClient.request(:add_config_property_to_tool) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => course[:parent_site_id],
                     :pagetitle => 'Home',
                     :tooltitle => 'Worksite Information',
                     :propname  => 'special',
                     :propvalue => 'worksite' }
  end

  req = soapClient.request(:add_new_tool_to_page) do
	  soap.body = { :sessionid   => session[:login_response][:login_return],
                     :siteid      => course[:parent_site_id],
                     :pagetitle   => 'Home',
                     :tooltitle   => 'Recent Announcements',
                     :toolid      => 'sakai.synoptic.announcement',
                     :layouthints => '0,1' }
  end

# Remove creator of site and add correct instructor

  req = soapClient.request(:remove_member_from_site) do
	  soap.body = { :sessionid => session[:login_response][:login_return],
                     :siteid    => course[:parent_site_id],
                     :userid    => soap_user }
  end

  req = soapClient.request(:add_member_to_site_with_role) do
      soap.body = { :sessionid => session[:login_response][:login_return],
                    :siteid    => course[:parent_site_id],
                    :eid       => course[:instructor],
                    :roleid    => 'Instructor' }
    end
  end
end
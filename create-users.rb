require 'savon'

host           = ''
soap_user      = ''
soap_pwd       = '' 

login_wsdl     = "#{host}/sakai-axis/SakaiLogin.jws?wsdl"
script_wsdl    = "#{host}/sakai-axis/SakaiScript.jws?wsdl"


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

i = 1 
 
until i == 201 do 
  if i.to_s.length == 1
    user_num = "00#{i}"
  elsif i.to_s.length == 2
    user_num = "0#{i}"
  else
    user_num = i.to_s
  end
  soapClient.request(:add_new_user) do
    soap.body = { :sessionid => session[:login_response][:login_return],
                  :id        => "user#{user_num}",
                  :eid       => "user#{user_num}",
                  :firstname => 'User Account',
                  :lastname  => "#{user_num}",
                  :email     => '',
                  :type      => 'Student',
                  :password  => "user#{user_num}"	}
  end
  
  i += 1
end

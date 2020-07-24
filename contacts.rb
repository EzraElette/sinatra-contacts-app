require 'bcrypt'
require 'date'
require 'erubis'
require 'fileutils'
require 'sinatra'
require 'sinatra/reloader'
require 'yaml'
require_relative 'states'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do

  def month_names
    Date::MONTHNAMES[1..12]
  end

  def contact_relationships
    %w(business family friend school work other)
  end
end

before do
  params.each { |k, v| params[k] = escape_html(v) }
end

def escape_html(html)
  Rack::Utils.escape_html(html)
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def user_list
  user_list = YAML.load_file('users.yml')
  user_list ? user_list : {}
end

def verify_credentials(username, password)
  return false if user_list[username].nil? || password.empty?
  BCrypt::Password.new(user_list[username]) == password
end

def signed_in?
  return false unless user_list
  user_list.keys.include?(session[:username])
end

def require_signed_in_user(session)
  unless signed_in?
    session[:error] = 'You must be signed in to do that.'
    redirect '/login'
  end
end

def verify_username(username)
  users = user_list.keys

  if users.include?(username)
    session[:error] = "That username is taken."
    redirect '/signup'
  elsif username !~ /[\w]+{3,20}/
    session[:error] = "Username must be between 3 and 20 alphanumeric characters. You may also use dashes and underscores."
    redirect '/signup'
  end
end

def error_for_password(pass1, pass2)
  if pass1 != pass2
    "Passwords must match"
  elsif !(10..25).cover?(pass1.length)
    "Passwords must be between 10 and 25 characters."
  end
end

def user_file_path(user)
  File.join(data_path, user + '.yml')
end

def load_contacts_for(user)
  filename = user_file_path(user)
  YAML.load_file(filename)['contacts']
end

def get_info_for(contact)
  load_contacts_for(session[:username])[contact]
end

def verify_name(name)
  if name.empty? || name !~ /[\w]+/
    session[:error] = "A name must be included."
    redirect '/add'
  end
end

def index_contacts(contacts)
  return_hash = {}
  contacts.sort.each do |name, info|
    if return_hash.keys.include?(name[0])
      return_hash[name[0].upcase][name] = info
    else
      return_hash[name[0].upcase] = {}
      return_hash[name[0].upcase][name] = info
    end
  end
  return_hash.sort
end

def verify_contact_exists(contact)
  redirect '/' unless load_contacts_for(session[:username]).include?(contact)
end

get '/login' do
  erb :login
end

post '/login' do
  username = escape_html(params[:username])
  password = escape_html(params[:password])

  if verify_credentials(username, password)
    session[:username] = username
    session[:success] = "Welcome"
    redirect '/'
  else
    session[:error] = "Invalid username or password."
    status 422
    erb :login
  end
end

post '/logout' do
  session.delete(:username)
  session[:success] = 'You have been signed out.'
  redirect '/login'
end

get '/signup' do
  erb :signup
end

post '/signup' do
  params.each { |k, v| params[k] = escape_html(v) }
  username = params[:username]
  password1 = params[:password1]
  password2 = params[:password2]
  error = error_for_password(password1, password2)

  verify_username(username)

  if error
    session[:error] = error
    redirect '/signup'
  else
    hashed_password = BCrypt::Password.create(password1)
    filename = File.basename(username) + '.yml'
    contacts_list_path = File.join(data_path, filename)
    File.write(contacts_list_path, "---\ncontacts: {}")
    File.open('users.yml', 'a') { |file| file.write "\n'#{ username }': '#{ hashed_password }'" }
    session[:success] = "Your account has been created. You may now log in."
    redirect '/login'
  end
end

get '/' do
  require_signed_in_user(session)
  group = params[:relationship]
  if group
    contacts = load_contacts_for(session[:username]).select { |name, info| info[:relationship] == group }
  else
    contacts = load_contacts_for(session[:username])
  end

  @index_contacts = index_contacts(contacts)
  erb :index
end

get '/add' do
  require_signed_in_user(session)

  erb :add
end

post '/add' do
  require_signed_in_user(session)
  params.each { |k, v| params[k] = escape_html(v) }
  firstname = params[:firstname]
  lastname = params[:lastname]
  full_name = [params[:firstname], params[:lastname]].join(' ')
  verify_name(full_name)
  birthday = [params[:birthmonth], params[:birthday], params[:birthyear]].join(' ')
  relationship = params[:relationship]
  phone_number = params[:phone]
  email = params[:email]
  address = [params[:address], params[:city], params[:state], params[:zipcode]].join(' ')

  contact = {
    "firstname": firstname, 'lastname': lastname, "birthday": params[:birthday], 'birthmonth': params[:birthmonth],
    'birthyear': params[:birthyear], "relationship": params[:relationship],
    "number": phone_number, "email": email, "address": params[:address], 'city': params[:city],
    'state': params[:state], 'zipcode': params[:zipcode]
  }

  output = YAML.load_file(user_file_path(session[:username]))
  output['contacts'][full_name.split.join('_')] = contact
  File.write(user_file_path(session[:username]), YAML.dump(output))

  session[:success] = "#{full_name} has been added to your contacts."
  redirect '/'
end

get '/:contact' do
  require_signed_in_user(session)
  verify_contact_exists(params[:contact])
  params.each { |k, v| params[k] = escape_html(v) }
  @contact_link = params[:contact]
  @contact = get_info_for(params[:contact])
  @name = [@contact[:firstname], @contact[:lastname]].join(' ')
  @address = [@contact[:address], @contact[:city], @contact[:state], @contact[:zipcode]].join(', ')
  @birthday = [@contact[:birthmonth], @contact[:birthday], @contact[:birthyear]].join(', ')
  @number = @contact[:number]
  @email = @contact[:email]
  @relationship = @contact[:relationship]
  erb :contact
end

get '/:contact/edit' do
  require_signed_in_user(session)
  @contact = get_info_for(params[:contact])

  erb :edit
end

post '/:contact' do
  require_signed_in_user(session)
  params.each { |k, v| params[k] = escape_html(v) }
  firstname = params[:firstname]
  lastname = params[:lastname]
  full_name = [params[:firstname], params[:lastname]].join(' ')
  verify_name(full_name)
  birthday = [params[:birthmonth], params[:birthday], params[:birthyear]].join(' ')
  relationship = params[:relationship]
  phone_number = params[:phone]
  email = params[:email]
  address = [params[:address], params[:city], params[:state], params[:zipcode]].join(' ')

  contact = {
    "firstname": firstname, 'lastname': lastname, "birthday": params[:birthday], 'birthmonth': params[:birthmonth],
    'birthyear': params[:birthyear], "relationship": params[:relationship],
    "number": phone_number, "email": email, "address": params[:address], 'city': params[:city],
    'state': params[:state], 'zipcode': params[:zipcode]
  }
  output = YAML.load_file(user_file_path(session[:username]))
  output['contacts'].delete(params[:contact])
  output['contacts'][full_name.split.join('_')] = contact
  File.write(user_file_path(session[:username]), YAML.dump(output))

  session[:success] = "#{full_name} has been updated."
  redirect "/#{ full_name.split.join('_')}"
end

post '/:contact/delete' do
  require_signed_in_user(session)
  params.each { |k, v| params[k] = escape_html(v) }
  contact = params[:contact]
  output = YAML.load_file(user_file_path(session[:username]))
  output['contacts'].delete(contact)
  File.write(user_file_path(session[:username]), YAML.dump(output))
  redirect '/'
end

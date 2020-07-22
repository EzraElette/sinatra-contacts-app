require 'sinatra'
require 'sinatra/reloader'
require 'erubis'
require 'bcrypt'
require 'yaml'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def user_list
  YAML.load_file('users.yml')
end

def verify_credentials(username, password)
  return false if username.empty? || password.empty?
  BCrypt::Password.new(user_list[username]) == password
end

def signed_in?
  user_list.keys.include?(session[:username])
end

def require_signed_in_user(session)
  unless signed_in?
    session[:error] = 'You must be signed in to do that.'
    redirect '/'
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

get '/login' do
  erb :login
end

post '/login' do
  username = params[:username]
  password = params[:password]

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

get '/signup' do
  erb :signup
end

post '/signup' do
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
    File.open('users.yml', 'a') { |file| file.write "\n'#{ username }': '#{ hashed_password }'" }
    session[:success] = "Your account has been created. You may now log in."
    redirect '/login'
  end
end

get '/' do
  require_signed_in_user(session)
  # load_contacts_for(session[:user])
  erb :index
end
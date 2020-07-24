ENV['RACK_ENV'] = 'test'

require 'fileutils'
require 'minitest'
require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'
Minitest::Reporters.use!

require_relative '../contacts'

class ContactsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
    File.write('users.yml', "'admin': '#{BCrypt::Password.create('secret')}'")
    File.write(File.join(data_path, 'admin.yml'), "---\ncontacts: {}")
  end

  def teardown
    FileUtils.rm_rf(data_path)
    FileUtils.rm_f('users.yml')
  end

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { 'rack.session' => { username: 'admin' }}
  end

  def test_login_redirect
    get '/'

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_equal 200, last_response.status

    assert_includes last_response.body, '<button type="submit"'
  end

  def test_login
    post '/login', { username: 'admin', password: 'secret' }

    assert_equal 302, last_response.status
    assert_equal 'Welcome', session[:success]
  end

  def test_empty_login
    post '/login', { username: '', password: '' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid username or password.'
  end

  def test_invalid_login
    post '/login', { username: 'invalid', password: 'invalid' }

    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Invalid username or password.'
  end

  def test_signup_page
    get '/signup'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Sign Up'
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_signup
    post '/signup', { username: 'ezra', password1: 'password123', password2: 'password123'}

    assert_equal 302, last_response.status
    assert_equal "Your account has been created. You may now log in.", session[:success]

    post '/login', { username: 'ezra', password: 'password123' }

    assert_equal 302, last_response.status
    assert_equal "Welcome", session[:success]
  end

  def test_signup_bad_usernames
    post '/signup', { username: '', password1: 'password123', password2: 'password123'}

    assert_equal 302, last_response.status
    assert_equal "Username must be between 3 and 20 alphanumeric characters. You may also use dashes and underscores.", session[:error]

    post '/signup', { username: 'thisisalongusernamechosentonotbecompatiblewiththeapplication', password1: 'password123', password2: 'password123'}

    assert_equal 302, last_response.status
    assert_equal "Username must be between 3 and 20 alphanumeric characters. You may also use dashes and underscores.", session[:error]
  end

  def test_signup_bad_passwords
    post '/signup', { username: 'availableusername', password1: 'password123', password2: 'completelydifferent'}

    assert_equal 302, last_response.status
    assert_equal 'Passwords must match', session[:error]

    post '/signup', { username: 'availableusername', password1: 'password123456789011121314151617181920', password2: 'password123456789011121314151617181920'}

    assert_equal 302, last_response.status
    assert_equal 'Passwords must be between 10 and 25 characters.', session[:error]

    post '/signup', { username: 'availableusername', password1: 'abc', password2: 'abc'}

    assert_equal 302, last_response.status
    assert_equal 'Passwords must be between 10 and 25 characters.', session[:error]

  end

  def test_add_form
    contact = {
      firstname: 'Ezra',
      lastname: 'Ellette',
      birthmonth: 'December',
      birthday: '15',
      birthyear: '2000',
      relationship: 'family',
      phone: '5555551234',
      email: 'ezraemail@gmail',
      address: '33 Shark Ave',
      city: 'Spiny',
      state: 'RI',
      zipcode: '90222'
    }

    post '/add', contact, admin_session

    assert_equal 302, last_response.status
    assert_equal "Ezra Ellette has been added to your contacts.", session[:success]

    get '/Ezra_Ellette', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "name: Ezra"
  end
end
# rubocop:disable Style/StringLiterals

require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "pry" if development?

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def users
  if ENV["RACK_ENV"] == "test"
    YAML.load_file('test/users.yaml')
  else
    YAML.load_file('users.yaml')
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_md(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_md(content)
  end
end

def user_signed_in?
  session.key? :username
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  @username = session[:username]
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  # credentials = load_user_credentials
  @username = params[:username]
  password = params[:password]

  if users.key?(@username) && users[@username] == password
    session[:username] = @username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/new" do
  require_signed_in_user
  erb :new
end

post "/" do
  require_signed_in_user

  filename = params[:filename].strip
  if filename.end_with?(".txt", ".md")
    File.new(File.join(data_path, filename), "w")
    session[:message] = "#{filename} was created."
    redirect "/"
  else
    session[:message] = "That's not a valid file name."
    status 422
    erb :new
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])
  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{File.basename(file_path)} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  if File.exist?(file_path)
    @filename = params[:filename]
    @content = File.read(file_path)
    erb :edit
  else
    session[:message] = "#{File.basename(file_path)} does not exist."
    redirect "/"
  end
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete file_path

  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

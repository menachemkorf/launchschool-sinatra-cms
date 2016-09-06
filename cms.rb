# rubocop:disable Style/StringLiterals

require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"
require "pry" if development?
require "fileutils"

configure do
  enable :sessions
  set :session_secret, 'secret'
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

def valid_credentials?(username, password)
  credentials = load_user_credentials
  if credentials.key? username
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def valid_filename?(file)
  file.end_with?(".txt", ".md")
end

def unique_filename?(file)
  !all_files.include?(file)
end

def all_files
  pattern = File.join(data_path, "*")
  Dir.glob(pattern).map do |path|
    File.basename(path)
  end
end

get "/" do
  @username = session[:username]
  @files = all_files
  erb :index
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  @username = params[:username]
  password = params[:password]

  if valid_credentials?(@username, password)
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
  if valid_filename?(filename) && unique_filename?(filename)
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

  if valid_filename?(params[:new_filename]) && (unique_filename?(params[:new_filename]) || params[:filename] == params[:new_filename])
    File.rename(file_path, File.join(data_path, params[:new_filename]))
    file_path = File.join(data_path, params[:new_filename])
    File.write(file_path, params[:content])
    session[:message] = "#{params[:new_filename]} has been updated."
    redirect "/"
  else
    @filename = params[:filename]
    @content = params[:content]
    session[:message] = "That's not a valid file name."
    status 422
    erb :edit
  end
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete file_path

  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

post "/:filename/copy" do
  require_signed_in_user

  src_path = File.join(data_path, params[:filename])
  dest_path = File.join(data_path, "dup_#{params[:filename]}")

  FileUtils.cp(src_path, dest_path)

  session[:message] = "#{params[:filename]} has been duplicated."
  redirect "/"
end





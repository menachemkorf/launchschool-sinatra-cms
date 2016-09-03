# rubocop:disable Style/StringLiterals

ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write content
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin"} }
  end

  def test_index
    create_document("history.txt")
    create_document("about.md")

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "history.txt"
    assert_includes last_response.body, "about.md"
  end

  def test_viewing_text_document
    content = "1993 - Yukihiro Matsumoto dreams up Ruby.\n1995 - Ruby 0.95 released.\n1996 - Ruby 1.0 released."
    create_document("history.txt", content)

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "1995 - Ruby 0.95 released."
  end

  def test_document_not_found
    document_name = "not_found.txt"
    get "/#{document_name}"

    assert_equal 302, last_response.status
    assert_equal "#{document_name} does not exist.", session[:message]
  end

  def test_viewing_markdown_document
    create_document("about.md", "# An h1 header")

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>An h1 header</h1>"
  end

  def test_edit_document
    create_document("changes.txt")

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_update_document
    post "/changes.txt", { content: "new content" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_update_document_signed_out
    post "/changes.txt"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_viewing_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_create_new_document
    post "/", { filename: "test.txt" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:message]
  end

  def test_create_new_document_without_filename
    post "/", { filename: "" }, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "That's not a valid file name."
  end

  def test_create_document_signed_out
    post "/", { filename: "test.txt" }

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_delete_document
    create_document("test.txt")

    get "/", {}, admin_session

    assert_includes last_response.body, "test.txt"
    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_delete_document_signed_out
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signup
    post "/users/signin", { username: 'admin', password: 'secret' }

    assert_equal 302, last_response.status
    assert_equal "admin", session[:username]
    assert_equal "Welcome!", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "You are signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", { username: '', password: '' }

    assert_equal 422, last_response.status
    assert_equal nil, session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, admin_session

    post "/users/signout"
    get last_response["Location"]

    assert_equal nil, session[:username]
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end
end

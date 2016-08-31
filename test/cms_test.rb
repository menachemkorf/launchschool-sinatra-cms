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

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write content
    end
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
    get last_response["Location"]
    assert_equal "http://example.org/", last_request.url
    assert_equal 200, last_response.status
    assert_includes last_response.body, "#{document_name} does not exist."

    get "/"
    refute_includes last_response.body, "#{document_name} does not exist."
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

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_update_document
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated."

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end

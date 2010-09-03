require 'helper'

class TestRubyArchive < Test::Unit::TestCase
  should "load the file from within the archive" do
    require 'archive.zip!/does_it_work'
    flunk "It didn't work" if did_it_work? != 'yes'
  end
end

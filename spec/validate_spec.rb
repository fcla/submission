require 'daitss/proc/wip/validation'
require 'daitss/config'
require 'daitss/proc/workspace'
require 'helper.rb'
require 'constants'

require 'daitss/db/ops'

describe Wip do

  before(:each) do
    Daitss::CONFIG.load_from_env

    DataMapper.setup(:default, Daitss::CONFIG['database-url'])
    DataMapper.auto_migrate!

    @workspace = Workspace.new Daitss::CONFIG['workspace']

    @account = add_account "ACT", "ACT"
    add_project @account, "PRJ", "PRJ"
 end

  after(:each) do
    FileUtils.rm_rf File.join(@workspace.path, "E0000199Y_L35FP3")
  end

  # extracts wip to workspace, returns path to wip
  def extract_wip_to_workspace wip_path
    zip_command = `which unzip`.chomp
    raise "unzip utility not found on this system!" if zip_command =~ /not found/

    output = `#{zip_command} -o #{wip_path} -d #{@workspace.path} 2>&1`
    raise "zip returned non-zero exit status: #{output}" unless $?.exitstatus == 0

    # all test wips share this IEID
    return File.join @workspace.path, "E0000199Y_L35FP3"
  end

  it "should validate a valid wip account" do
    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.package_account_valid?.should == true
  end

  it "should not validate an invalid wip account" do
    wip_path = extract_wip_to_workspace INVALID_ACCOUNT
    wip = Wip.new wip_path

    wip.package_account_valid?.should == false
  end

  it "should validate a valid wip project" do
    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.package_project_valid?.should == true
  end

  it "should not validate an invalid wip project" do
    wip_path = extract_wip_to_workspace INVALID_PROJECT
    wip = Wip.new wip_path

    wip.package_project_valid?.should == false
  end

  it "should validate a package-submitter match" do
    agent = add_operator @account

    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.package_account_matches_agent?(agent).should == true
  end

  it "should validate a package-submitter mismatch if submitter is operator" do
    account = add_account "FOO", "FOO"
    agent = add_operator account

    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.package_account_matches_agent?(agent).should == true
  end

  it "should not validate a package-submitter mismatch if submitter is contact" do
    account = add_account "FOO", "FOO"
    agent = add_contact account

    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.package_account_matches_agent?(agent).should == false
  end

  it "should be able to confirm the existence of a content file" do
    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.content_file_exists?.should == true
  end

  it "should correctly tell when a described content file does not exist" do
    wip_path = extract_wip_to_workspace MISSING_CONTENT_FILE
    wip = Wip.new wip_path

    wip.content_file_exists?.should == false
  end

  it "should correctly tell when a content file exists, but is not described" do
    wip_path = extract_wip_to_workspace UNDESCRIBED_CONTENT_FILE
    wip = Wip.new wip_path

    wip.content_file_exists?.should == false
  end

  it "should correctly tell when a described content file does not exist" do
    wip_path = extract_wip_to_workspace MISSING_UNDESCRIBED_CONTENT_FILE
    wip = Wip.new wip_path

    wip.content_file_exists?.should == false
  end

  it "should be able to confirm that all datafile checksums match" do
    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == true
  end

  it "should catch an md5 datafile mismatch" do
    wip_path = extract_wip_to_workspace MD5_MISMATCH
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == false
    wip.metadata["checksum_failures"].should == "ateam.tiff - expected: 905ae75bc4595521e350564c90a56d28 computed: 805ae75bc4595521e350564c90a56d28; "
  end

  it "should catch a sha1 datafile mismatch" do
    wip_path = extract_wip_to_workspace SHA1_MISMATCH
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == false
    wip.metadata["checksum_failures"].should == "ateam.tiff - expected: 905ae75bc4595521e350564c90a56d28 computed: cd6244779b6f21b7000b55403d9451cf87f1bf1b; "
  end

  it "should pass checksum check when checksum data is missing from sip descriptor" do
    wip_path = extract_wip_to_workspace MISSING_CHECKSUM_DATA
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == true
  end

  it "should pass checksum check when checksum type is not MD5 or SHA-1" do
    wip_path = extract_wip_to_workspace UNKNOWN_CHECKSUM_TYPE
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == true
  end

  it "should pass checksum check when checksum type cannot be inferred" do
    wip_path = extract_wip_to_workspace CANT_INFER_CHECKSUM_TYPE
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == true
  end

  it "should infer sha1 checksums and catch mismatch when checksum type is missing and length is 40" do
    wip_path = extract_wip_to_workspace INFER_SHA1
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == false
    wip.metadata["checksum_failures"].should == "ateam.tiff - expected: 95ae75bc4595521e350564c90a56d2a000000008 computed: cd6244779b6f21b7000b55403d9451cf87f1bf1b; "
  end

  it "should infer md5 checksums and catch mismatch when checksum type is missing and length is 32" do
    wip_path = extract_wip_to_workspace INFER_MD5
    wip = Wip.new wip_path

    wip.content_file_checksums_match?.should == false
    wip.metadata["checksum_failures"].should == "ateam.tiff - expected: 905ae75bc4595521e350564c90a56d28 computed: 805ae75bc4595521e350564c90a56d28; "
  end

  it "should validate package names" do
    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.package_name_valid?.should == true
  end

  it "should validate package names (case start with dot)" do
    wip_path = extract_wip_to_workspace PACKAGE_NAME_STARTS_DOT
    wip = Wip.new wip_path

    wip.package_name_valid?.should == false
  end

  it "should validate package names (case space char)" do
    wip_path = extract_wip_to_workspace PACKAGE_NAME_HAS_SPACE
    wip = Wip.new wip_path

    wip.package_name_valid?.should == false
  end

  it "should validate package names (case quote char)" do
    wip_path = extract_wip_to_workspace PACKAGE_NAME_HAS_QUOTE
    wip = Wip.new wip_path

    wip.package_name_valid?.should == false
  end

  it "should validate package names (case length > 32)" do
    wip_path = extract_wip_to_workspace PACKAGE_NAME_LONG
    wip = Wip.new wip_path

    wip.package_name_valid?.should == false
  end

  it "should validate datafile names" do
    wip_path = extract_wip_to_workspace NORMAL_WIP
    wip = Wip.new wip_path

    wip.content_files_have_valid_names?.should == true
  end

  it "should not validate invalid datafile names" do
    wip_path = extract_wip_to_workspace INVALID_DATAFILE_NAME
    wip = Wip.new wip_path

    wip.content_files_have_valid_names?.should == false
  end
end
